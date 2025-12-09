#import "CompletionManager.h"
#import "FileManager.h"
#import "MSScoredString.h"
#import "SpeechManager.h"
@import AppKit;

@implementation CompletionManager

+ (NSString*)normalizeToken:(NSString*)t {
    return t.lowercaseString;
}

// Strip common punctuation and return and array of normalized words. This is a lossy function.
+ (NSArray<NSString*>*)tokenizeIntoWords:(NSString*)string {
    // Interesting tokenizations: split on -, strip ',!.
    string = [string stringByReplacingOccurrencesOfString:@"'" withString:@""];
    string = [string stringByReplacingOccurrencesOfString:@"’" withString:@""]; // dreaded "smart" apostrophe.
    string = [string stringByReplacingOccurrencesOfString:@"," withString:@""];
    string = [string stringByReplacingOccurrencesOfString:@"." withString:@""];
    string = [string stringByReplacingOccurrencesOfString:@"!" withString:@""];
    string = [string stringByReplacingOccurrencesOfString:@"?" withString:@""];
    // FIXME: hyphens and apostrophes need to be expanded to (token, pos) to help with scoring, but
    // let's not get too far ahead.
    string = [string stringByReplacingOccurrencesOfString:@"-" withString:@" "];
    NSMutableArray* tokens = [NSMutableArray arrayWithCapacity:16];
    for (NSString* t in [string componentsSeparatedByString:@" "]) {
        if (t.length) {
            [tokens addObject:[self normalizeToken:t]];
        }
    }
    return tokens;
}

// Returns and array of words, spaces and punctuation that can be returned to the original
// string with componentsJoinedByString:@"". This is a lossless function.
+ (NSArray<NSString*>*)tokenizeText:(NSString*)text {
    NSMutableArray* chars = [NSMutableArray array];
    NSMutableArray* tokens = [NSMutableArray array];

    [text enumerateSubstringsInRange:NSMakeRange(0, [text length])
                             options:NSStringEnumerationByComposedCharacterSequences
                          usingBlock:^(NSString* inSubstring, NSRange inSubstringRange, NSRange inEnclosingRange,
                                       BOOL* outStop) {
                            [chars addObject:inSubstring];
                          }];

    int start = 0;
    int pos = 0;
    for (NSString* ch in chars) {
        if ([[ch stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" .,!?-"]]
                isEqualToString:@""]) {
            int len = pos - start;
            if (len > 0) {
                [tokens addObject:[[chars subarrayWithRange:NSMakeRange(start, len)] componentsJoinedByString:@""]];
            }
            [tokens addObject:ch];
            start = pos + 1;
        }
        pos++;
    }
    int len = pos - start;
    if (len > 0) {
        [tokens addObject:[[chars subarrayWithRange:NSMakeRange(start, len)] componentsJoinedByString:@""]];
    }
    return tokens;
}

- (void)awakeFromNib {
    // Make sure our window always draws over the text view.
    [window setLevel:NSPopUpMenuWindowLevel];
    // Wait to init until the defaults are initialized.
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"enableCorrectorPlugin"]) {
        [self nlpProc];
    }
}

- (MSJSONRPCProcess*)nlpProc {
    if (_nlpProc == nil) {
        NSString* scriptPath = [[NSBundle mainBundle] pathForResource:@"MavisCorrector" ofType:@"plugin"];
        if (!scriptPath) {
            return nil;
        }
        scriptPath = [scriptPath stringByAppendingPathComponent:@"Contents/MacOS/MavisCorrector"];
        NSArray* args = @[
            // We are going to use HTTP instead of JSON-over-STDIO so we can share with iOS
            @"--http-service", @"--http-port=62044", @"--extra-proper-nouns",
            [[FileManager sharedInstance] properNounsFile]
        ];
        _nlpProc = [[MSJSONRPCProcess alloc] initProcessWithPath:scriptPath arguments:args];
    }
    return _nlpProc;
}

- (MSJSONRPCClient*)nlpClient {
    if (_nlpClient == nil) {
        _nlpClient = [[MSJSONRPCClient alloc] initWithBaseURL:[NSURL URLWithString:@"http://localhost:62044"]];
    }
    return _nlpClient;
}

- (void)readFiles {
    FileManager* fm = [FileManager sharedInstance];
    NSArray* l = [fm readFileAsStringArray:fm.phrasesFile];
    if (l != nil) {
        self.phrases = l;
    }

    if (l != nil || self.phrases.count == 0) {
        // FIXME: Feels sloppy/expensive to recompute this every time.
        // It's not correct to only merge this when the phrases change.
        // Realistically, phrase changing is probably way more likely than soundbites.
        NSArray<NSString*>* soundbites = [[SpeechManager sharedInstance] soundbites];
        NSMutableSet<NSString*>* set = [NSMutableSet setWithArray:self.phrases];
        [set addObjectsFromArray:soundbites];
        self.phrases = [[set allObjects] sortedArrayUsingSelector:@selector(compare:)];

        // Scan all out phrases and soundbites so we don't accidentally consider them misspelled.
        set = [NSMutableSet set];
        for (NSString* phrase in self.phrases) {
            [set addObjectsFromArray:[CompletionManager tokenizeText:phrase]];
        }
        NSMutableSet* missingWords = [NSMutableSet set];
        for (NSString* word in set) {
            NSInteger wordCount;
            NSRange r = [[NSSpellChecker sharedSpellChecker] checkSpellingOfString:word
                                                                        startingAt:0
                                                                          language:@"en"
                                                                              wrap:NO
                                                            inSpellDocumentWithTag:0
                                                                         wordCount:&wordCount];
            if (r.location != NSNotFound) {
                [missingWords addObject:word];
            }
        }
        if (missingWords.count) {
            NSLog(@"add missing words to dictionary: %@", missingWords);
            for (NSString* word in missingWords) {
                [[NSSpellChecker sharedSpellChecker] learnWord:word];
            }
        }
    }
}

- (NSArray<NSAttributedString*>*)completions:(NSArray<NSString*>*)words
                            forPartialString:(NSString*)str
                                 withContext:(NSString*)context {
    [self readFiles];

    // context is the whole message
    // str is probably the last token, which is probably partial (but not
    // necessarily), but could also be the whole context.
    NSArray* qtokens = [CompletionManager tokenizeIntoWords:str];

    if (qtokens.count == 0) {
        return [self styleCompletions:self.phrases forText:context highlightDifferences:NO];
    }
    if ([qtokens.lastObject isEqual:@"z"]) {
        return [self styleCompletions:[[SpeechManager sharedInstance] soundbites]
                              forText:context
                 highlightDifferences:NO];
    }

    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"enableCorrectorPlugin"]) {
        NSError* error;
        NSArray<NSString*>* corrections;
        corrections = [[self nlpClient] callMethod:@"correct" withArgs:@{@"text": context} timeout:3000 error:&error];
        if (error != nil) {
            NSLog(@"error with nlp corrections: %@", error);
            originalRange = NSMakeRange(0, originalText.length);
            return [self styleCompletions:words forText:context highlightDifferences:NO];
        }
        if (corrections != nil && corrections.count) {
            originalRange = NSMakeRange(0, originalText.length);
            return [self styleCompletions:corrections forText:context highlightDifferences:YES];
        }
    }
    if ([str isEqual:context]) {
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"logQueryScores"]) {
            NSLog(@"qtokens: %@", [qtokens componentsJoinedByString:@","]);
        }
        NSArray<NSString*>* sl = [self scoreStrings:self.phrases against:str];
        return [self styleCompletions:sl forText:str highlightDifferences:NO];
    }
    // As a last resort return the words we started with.
    return [self styleCompletions:words forText:str highlightDifferences:NO];
}

- (NSArray<NSString*>*)scoreStrings:(NSArray<NSString*>*)strings against:(NSString*)str {
    NSMutableArray* scored = [NSMutableArray arrayWithCapacity:10];

    NSArray* qTokens = [CompletionManager tokenizeIntoWords:str];
    for (NSString* s in strings) {
        NSArray* words = [CompletionManager tokenizeIntoWords:s];
        float score = 0.0;
        for (int j = 0; j < qTokens.count; j++) {
            NSString* t = qTokens[j];
            NSInteger idx = [words indexOfObject:t];
            if (idx != NSNotFound) {
                // Token matched a word.
                score += 1.0;
            } else {
                for (int wi = 0; wi < words.count; wi++) {
                    if ([words[wi] hasPrefix:t]) {
                        // Token matched a word prefix
                        idx = wi;
                        score += 0.5;
                        break;
                    }
                }
            }
            if (idx == j) {
                // Matched token position
                score += 1.0;
            }
        }

        if (score > 0) {
            if ([[NSUserDefaults standardUserDefaults] boolForKey:@"logQueryScores"]) {
                NSLog(@"pscore: %f %@ ", score, [words componentsJoinedByString:@","]);
            }
            [scored addObject:[[MSScoredString alloc] initWithString:s andScore:score]];
        }
    }
    if (scored.count) {
        [scored sortUsingSelector:@selector(compareDesc:)];
        NSMutableArray* sl = [NSMutableArray arrayWithCapacity:10];
        for (MSScoredString* ss in scored) {
            [sl addObject:ss.string];
        }
        return sl;
    }
    return scored;
}

- (void)logString:(NSString*)s withInputKeystrokes:(NSString*)keystrokes withAnnotations:(NSDictionary*)dict {
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"logChatHistory"]) {
        return;
    }

    NSDateFormatter* RFC3339DateFormatter = [[NSDateFormatter alloc] init];
    RFC3339DateFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    RFC3339DateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZZZZZ";
    RFC3339DateFormatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];

    NSString* ts = [RFC3339DateFormatter stringFromDate:NSDate.now];

    NSMutableDictionary* rec = [NSMutableDictionary dictionaryWithDictionary:@{
        @"text": s,
        @"keystrokes": keystrokes,
        @"timestamp": ts,
    }];

    [rec setValuesForKeysWithDictionary:dict];

    NSError* err;
    NSData* data = [NSJSONSerialization dataWithJSONObject:rec options:0 error:&err];
    if (err != nil) {
        NSLog(@"error serializing JSON: %@", err);
    }

    NSString* path = [[FileManager sharedInstance] userPath:@"log.jsonl"];
    NSFileManager* fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:path]) {
        [fileManager createFileAtPath:path contents:nil attributes:nil];
    }

    // Open file for appending
    NSFileHandle* fileHandle = [NSFileHandle fileHandleForWritingAtPath:path];
    if (fileHandle == nil) {
        NSLog(@"Failed to open file for writing: %@", path);
        return;
    }

    [fileHandle seekToEndOfFile];
    [fileHandle writeData:data];
    [fileHandle writeData:[@"\n" dataUsingEncoding:NSUTF8StringEncoding]];
    [fileHandle closeFile];
}

- (void)positionWindow:(NSWindow*)myWin belowView:(NSView*)myView withHeight:(CGFloat)windowHeight {
    if (windowHeight == 0) {
        // Get the height of the window to calculate the new origin for myWin
        windowHeight = myWin.frame.size.height;
    }

    // Get the window that contains the view
    NSWindow* viewWindow = myView.window;

    // Convert the bottom left corner of the view to screen coordinates
    NSRect viewFrameInWindow = [myView convertRect:myView.bounds toView:nil]; // View's coordinates in window
    NSPoint viewBottomLeftInWindow = NSMakePoint(viewFrameInWindow.origin.x, viewFrameInWindow.origin.y);
    NSPoint viewBottomLeftInScreen =
        [viewWindow convertRectToScreen:(NSRect){viewBottomLeftInWindow, NSZeroSize}].origin;

    // Set the new position for myWin, making the top-left corner of myWin at the bottom-left of myView
    NSPoint newOrigin = NSMakePoint(viewBottomLeftInScreen.x, viewBottomLeftInScreen.y - windowHeight);

    NSRect newFrame = NSMakeRect(newOrigin.x, newOrigin.y, myView.bounds.size.width, windowHeight);
    // Move the window and resize if necessary
    [myWin setFrame:newFrame display:YES];
}

- (NSArray<NSAttributedString*>*)styleCompletions:(NSArray<NSString*>*)completions
                                          forText:(NSString*)text
                             highlightDifferences:(BOOL)shouldHighlight {
    NSMutableArray<NSAttributedString*>* fancyCompletions = [NSMutableArray arrayWithCapacity:completions.count];
    if (!shouldHighlight) {
        for (NSString* s in completions) {
            [fancyCompletions addObject:[[NSAttributedString alloc] initWithString:s
                                                                        attributes:[self defaultStringAttrs]]];
        }
        return fancyCompletions;
    }
    NSDictionary* highlightAttrs = @{
        NSFontAttributeName: [self defaultFont],
        NSUnderlineStyleAttributeName: [NSNumber numberWithInt:NSUnderlinePatternSolid | NSUnderlineStyleSingle],
        NSUnderlineColorAttributeName: [NSColor redColor],
    };

    NSAttributedString* aSpace = [[NSAttributedString alloc] initWithString:@" "];

    // It's very hard to spot corrections make against the original, so highlight them.
    NSArray<NSString*>* originalWords = [originalText componentsSeparatedByString:@" "];
    for (NSString* cText in completions) {
        NSMutableAttributedString* aStr = [[NSMutableAttributedString alloc] init];
        NSArray<NSString*>* cWords = [cText componentsSeparatedByString:@" "];
        BOOL first = YES;
        for (NSString* w in cWords) {
            if (!first) {
                [aStr appendAttributedString:aSpace];
            } else {
                first = NO;
            }
            NSDictionary* attrs = [self defaultStringAttrs];
            if (![originalWords containsObject:w]) {
                attrs = highlightAttrs;
            }
            [aStr appendAttributedString:[[NSAttributedString alloc] initWithString:w attributes:attrs]];
        }
        [fancyCompletions addObject:aStr];
    }
    return fancyCompletions;
}

- (void)showCompletions:(MSTextView*)_textView {
    textView = _textView;

    // FIXME: apparently i should have done this in an NSPopover
    NSRange completionRange = [textView rangeForUserCompletion];
    NSString* partialString = [[textView stringValue] substringWithRange:completionRange];

    originalSelection = [_textView selectedRange];
    originalRange = completionRange;
    originalText = [[textView stringValue] copy];

    NSInteger idx;
    NSArray<NSString*>* words = [textView completionsForPartialWordRange:completionRange indexOfSelectedItem:&idx];
    NSString* context = [textView stringValue];
    attributedCompletions = [self completions:words forPartialString:partialString withContext:context];

    [tableView deselectAll:nil];
    [tableView reloadData];
    tableView.needsLayout = true;
    [tableView layoutSubtreeIfNeeded];

    if (attributedCompletions.count) {
        CGFloat lineHeight = [tableView.delegate tableView:tableView heightOfRow:0];
        CGFloat height = MIN(tableView.fittingSize.height, lineHeight * 10);
        [self positionWindow:window belowView:textView withHeight:height];
        // Set selection after window is visible, otherwise no notifcation of selection change is fired.
        [tableView scrollRowToVisible:0];
        [tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];

        [window makeKeyAndOrderFront:nil];
        [window setIsVisible:YES];
    }
}

- (NSFont*)defaultFont {
    return [NSFont systemFontOfSize:[[NSUserDefaults standardUserDefaults] floatForKey:@"fontSize"]];
}

- (NSDictionary*)defaultStringAttrs {
    return @{
        NSFontAttributeName: [self defaultFont],
    };
}

- (void)updateCompletion:(NSString*)str {
    NSMutableString* newStr = originalText.mutableCopy;
    [newStr replaceCharactersInRange:originalRange withString:str];
    [textView setString:newStr];
    NSRange newRange = NSMakeRange(originalRange.location, str.length);
    [textView setSelectedRange:newRange];
}

- (IBAction)accept:(id)sender {
    [window setIsVisible:NO];
    [textView setSelectedRange:NSMakeRange(textView.string.length, 0)];

    NSMutableArray* completions = [NSMutableArray arrayWithCapacity:attributedCompletions.count];
    for (NSAttributedString* s in attributedCompletions) {
        [completions addObject:[s string]];
    }
    [self logString:[textView stringValue]
        withInputKeystrokes:[textView rawStringInput]
            withAnnotations:@{
                @"completeAccepted": @YES,
                @"completionText": originalText,
                @"completions": completions,
            }];
}

// FIXME: Fugly. Cancel must be idempotent. Due to the way the completion window is resigned,
// a cancel: call is always sent, even if an accept: was just sent.
- (IBAction)cancel:(id)sender {
    if (!window.isVisible) {
        // Suppress duplicate event. Too lazy to fix.
        return;
    }
    NSMutableArray* completions = [NSMutableArray arrayWithCapacity:attributedCompletions.count];
    for (NSAttributedString* s in attributedCompletions) {
        [completions addObject:[s string]];
    }
    [self logString:originalText
        withInputKeystrokes:[textView rawStringInput]
            withAnnotations:@{
                @"completeAccepted": @NO,
                @"completionText": originalText,
                @"completions": completions,
            }];
    [self updateCompletion:originalText];
    [textView setSelectedRange:originalSelection];
    [window setIsVisible:NO];
}

#pragma mark - Table View

- (void)tableViewColumnDidResize:(NSNotification*)evt {
    // FIXME: The rendering isn't correct when simply noting the changed heights.
    // Forcing a reload works for now; good thing the data source is tiny.
    [tableView reloadData];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView*)tableView {
    return attributedCompletions.count;
}

- (id)tableView:(NSTableView*)tableView objectValueForTableColumn:(NSTableColumn*)tableColumn row:(NSInteger)row {
    return attributedCompletions[row];
}

- (void)tableViewSelectionDidChange:(NSNotification*)notification {
    if (tableView.selectedRow >= 0 && tableView.selectedRow < attributedCompletions.count) {
        [self updateCompletion:attributedCompletions[tableView.selectedRow].string];
    } else {
        [self updateCompletion:originalText];
    }
}

- (CGFloat)tableView:(NSTableView*)tableView heightOfRow:(NSInteger)row {
    CGFloat minimumMargin = 8.0;
    //    CGFloat minimumHeight = tableView.rowHeight;
    CGFloat minimumHeight = [[NSUserDefaults standardUserDefaults] floatForKey:@"fontSize"];
    NSTableColumn* column = tableView.tableColumns.firstObject;
    NSAttributedString* content = [self tableView:tableView objectValueForTableColumn:nil row:row];

    CGFloat height = minimumHeight;
    // if we have some content, see if we need to go beyond the minimum height
    if (content != nil && content.length > 0) {
        NSTextFieldCell* cell = column.dataCell;
        CGFloat margin = MAX(minimumMargin, ceilf(minimumHeight - cell.font.boundingRectForFont.size.height));
        cell.wraps = YES;
        cell.lineBreakMode = NSLineBreakByWordWrapping;
        cell.truncatesLastVisibleLine = NO;
        cell.objectValue = content;
        NSRect rect = NSMakeRect(0.0, 0.0, column.width, CGFLOAT_MAX);
        height = [cell cellSizeForBounds:rect].height + margin;
        if (height < minimumHeight) {
            height = minimumHeight; // ensure minimum
        }
        height = ceilf(height);
        // NSLog(@"rowHeight: %@ %fh %fmin %fmargin", content, height, minimumHeight, margin);
    }
    return height;
}

@end
