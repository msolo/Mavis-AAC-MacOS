#import "AppDelegate.h"
#import "AudioManager.h"
#import "CompletionManager.h"
#import "FaceTimeIntegration.h"
#import "FileManager.h"
#import "MSAXScript.h"
#import "MSScoredString.h"
#import "MSTextView.h"
#import "SoundCzech.h"
#import "SpeechManager.h"
#import "UpdateManager.h"
#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/QuartzCore.h>

static NSArray<NSString*>* commonAbbreviations;

@implementation AppDelegate

+ (void)initialize {
    commonAbbreviations = @[
        // this is the tyranny of clang-fmt. This should be on single lines to diff easily.
        @"a.m", @"ave", @"blvd", @"capt", @"co",  @"col", @"corp", @"dr", @"e.g", @"est", @"etc",
        @"gen", @"i.e", @"inc",  @"jr",   @"lt",  @"ltd", @"maj",  @"mr", @"mrs", @"ms",  @"mt",
        @"no",  @"p.m", @"prof", @"rd",   @"rev", @"sgt", @"sr",   @"st", @"vol", @"vs",
    ];
}

+ (void)errorAlertWithMessage:(NSString*)msg andInfo:(NSString*)info {
    NSAlert* alert = [[NSAlert alloc] init];
    alert.alertStyle = NSAlertStyleCritical;
    alert.messageText = msg;
    alert.informativeText = info;
    [alert addButtonWithTitle:@"OK"];
    NSLog(@"%@: %@", msg, info);
    [alert runModal];
}

- (void)redirectNSLogToFile:(NSString*)logPath {
    // NOTE: We don't want this to work when run under the Xcode, and this behavior has changed between Xcode versions.
    if ([[[NSProcessInfo processInfo] environment] objectForKey:@"__XCODE_BUILT_PRODUCTS_DIR_PATHS"] != nil) {
        return;
    }
    NSLog(@"redirecting stderr to %@", logPath);
    FILE* f = freopen([logPath fileSystemRepresentation], "a+", stderr);
    if (f == NULL) {
        NSLog(@"unable to reopen log: %d", errno);
    }
}
- (CompletionManager*)completionManager {
    return completionManager;
}

- (void)setVoice:(AVSpeechSynthesisVoice*)voice {
    _voice = voice;
    [[NSUserDefaults standardUserDefaults] setObject:voice.identifier forKey:@"speakingVoiceIdentifier"];
}

// NOTE: This gets called many times, particularly by NSTableView cells.
- (void)awakeFromNib {
    // NSLog(@"awake app delegate");
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{
        @"bellVolume": @1.0,
        @"correctOnSpellingErrors": @YES,
        @"enableCorrectorPlugin": @NO,
        @"enableDynamicSpeakingVolume": @NO,
        @"enableNoisyTyping": @YES,
        @"enableNoiseMonitor": @NO,
        @"enableSoundbites": @YES,
        @"emergencyMessagesContent": @"📣🐰",
        @"emergencyMessagesContact": @"",
        @"fontSize": [NSNumber numberWithFloat:[NSFont systemFontSize]],
        @"forcefulBellVolume": @1.0,
        @"ignoreUselessKeys": @YES,
        @"keyClickVolume": @1.0,
        @"soundbiteVolume": @1.0,
        @"speakSentencesAutomatically": @NO,
        @"speakingRate": @0.5,
        @"speakingVolume": @0.5,
        @"speakingPitch": @1.0,
        @"speakingSystemVolumeLevel": @0.8125,
        @"speakingVoiceIdentifier": @"",
        @"speakingHistoryItems": @[
            @"At no point in your rambling, incoherent response was there anything that could even be considered a rational thought. Everyone in this room is now dumber for having listened to it.",
            @"And now a word from our sponsors.",
        ],
    }];

    // Fixup script text view.
    scriptTextView.usesAdaptiveColorMappingForDarkAppearance = YES;

    NSFont* font = [NSFont systemFontOfSize:[[NSUserDefaults standardUserDefaults] floatForKey:@"fontSize"]];
    NSMutableParagraphStyle* style = [[NSMutableParagraphStyle alloc] init];
    CGFloat lineHeight = [[[NSLayoutManager alloc] init] defaultLineHeightForFont:font];
    style.paragraphSpacing = 1.0 * lineHeight;
    NSDictionary* attrs = @{
        NSParagraphStyleAttributeName: style,
        NSFontAttributeName: font,
    };

    [[scriptTextView textStorage] setAttributes:attrs range:NSMakeRange(0, [[scriptTextView textStorage] length])];
    scriptTextView.typingAttributes = attrs;
}

- (void)defaultsDidChange {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"enableNoiseMonitoring"] ||
        [[NSUserDefaults standardUserDefaults] boolForKey:@"enableDynamicSpeakingVolume"]) {
        [self startNoiseMonitor];
    } else {
        [self stopNoiseMonitor];
    }
}

- (void)applicationDidFinishLaunching:(NSNotification*)aNotification {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(defaultsDidChange)
                                                 name:NSUserDefaultsDidChangeNotification
                                               object:nil];

    [[window windowController] setShouldCascadeWindows:NO]; // Tell the controller to not cascade its windows.
    [window setFrameAutosaveName:@"Mavis AAC"];             // Specify the autosave name for the window.

    // Ask for necessary permissions.
    [MSAXScript enableScripting];

    self.history =
        [NSMutableArray arrayWithArray:[[NSUserDefaults standardUserDefaults] objectForKey:@"speakingHistoryItems"]];

    [self redirectNSLogToFile:[[FileManager sharedInstance] userPath:@"console.log"]];

    if (@available(macOS 14, *)) {
        if ([AVSpeechSynthesizer personalVoiceAuthorizationStatus] !=
            AVSpeechSynthesisPersonalVoiceAuthorizationStatusAuthorized) {
            [AVSpeechSynthesizer requestPersonalVoiceAuthorizationWithCompletionHandler:^(
                                     AVSpeechSynthesisPersonalVoiceAuthorizationStatus status) {
              [self loadVoices];
            }];
        } else {
            [self loadVoices];
        }
    } else {
        [self loadVoices];
    }

    [historyTableView reloadData];
    [historyTableView scrollRowToVisible:(self.history).count - 1];
    [historyTableView deselectAll:nil];

    // TODO: mainWindow causes a crash for some reason.
    // [window makeMainWindow];
    [window makeKeyWindow];
    [window makeFirstResponder:sayTextView];

    [UpdateManager scheduleUpdateCheck:NO];

    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"enableDynamicSpeakingVolume"] ||
        [[NSUserDefaults standardUserDefaults] boolForKey:@"enableNoiseMonitoring"]) {
        [self startNoiseMonitor];
    };
}

- (void)loadVoices {
    SpeechManager* sm = [SpeechManager sharedInstance];
    self.voices = [sm getVoices];
    self.voice = [sm defaultVoice];
    if (self.voices.count == 1 && self.voice.quality == AVSpeechSynthesisVoiceQualityDefault) {
        [self voiceInstallAlert];
    }
}

- (void)voiceInstallAlert {
    NSAlert* alert = [[NSAlert alloc] init];
    alert.showsHelp = YES;
    alert.helpAnchor = @"default-voice-warning";
    alert.alertStyle = NSAlertStyleInformational;
    [alert setDelegate:self];
    [alert setMessageText:@"Default Voice Warning"];
    [alert setInformativeText:@"Mavis will use a default voice since no high quality voices are installed.\n\nWould "
                              @"you like to install some high quality voices now?"];

    [alert addButtonWithTitle:@"Take Me To Settings"];
    [alert addButtonWithTitle:@"Skip"];
    [alert beginSheetModalForWindow:window
                  completionHandler:^(NSModalResponse response) {
                    if (response == NSAlertFirstButtonReturn) {
                        // "Take Me To Settings" button clicked
                        // Sadly, this US not really useful
                        NSURL* url = [NSURL
                            URLWithString:@"x-apple.systempreferences:com.apple.preference.universalaccess?LiveSpeech"];
                        [[NSWorkspace sharedWorkspace] openURL:url];
                        [AppDelegate showManageVoices];
                    }
                  }];
}

// This clearly needs to be changes every major OS release.
+ (void)showManageVoices {
    if (@available(macOS 15, *)) {
        return [AppDelegate showManageVoicesOS15];
    }
}

+ (void)showManageVoicesOS15 {
    NSURL* url = [[NSBundle mainBundle] URLForResource:@"showManageVoices" withExtension:@"scpt"];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
      NSDictionary* errDict;

      NSAppleScript* script = [[NSAppleScript alloc] initWithContentsOfURL:url error:&errDict];
      if (errDict != nil) {
          NSLog(@"error loading script showManageVoices: %@", errDict);
          return;
      }

      [script executeAndReturnError:&errDict];
      if (errDict != nil) {
          NSLog(@"error during showManageVoices: %@", errDict);
      }
    });
}

- (BOOL)alertShowHelp:(NSAlert*)alert {
    [[NSWorkspace sharedWorkspace]
        openURL:[NSURL URLWithString:[@"https://lazybearlabs.com/apps/mavis-aac/macos/help.html"
                                         stringByAppendingFormat:@"#%@", alert.helpAnchor]]];
    return YES;
}

- (void)startNoiseMonitor {
    if (noiseMonitor != nil) {
        return;
    }
    noiseMonitor = [[SoundLevelMonitor alloc] init];
    [noiseMonitor startMonitoring];
    self.noiseTimer = [NSTimer scheduledTimerWithTimeInterval:2.0
                                                       target:self
                                                     selector:@selector(updateNoiseLevel)
                                                     userInfo:nil
                                                      repeats:YES];
}

- (void)stopNoiseMonitor {
    if (noiseMonitor == nil) {
        return;
    }
    [self.noiseTimer invalidate];
    self.noiseTimer = nil;

    [noiseMonitor stopMonitoring];
    noiseMonitor = nil;
}

- (void)updateNoiseLevel {
    float noise = [noiseMonitor averageAverageAudioLevel];
    noiseDisplay.intValue = (int)noise;
    [noiseMonitor reset];
}

- (BOOL)applicationSupportsSecureRestorableState:(NSApplication*)app {
    return YES;
}

// Click through Control Center when FaceTime is running.
// Initiate window sharing with our special empty window to send
// synthesized audio over FaceTime.
- (IBAction)startSharePlay:(id)sender {
    [FaceTimeIntegration startSharePlay:sharePlayWindow];
}

- (IBAction)stopSharePlay:(id)sender {
    [FaceTimeIntegration stopSharePlay:sharePlayWindow];
}

- (IBAction)ringBell:(id)sender {
    NSURL* soundEffect = [[NSBundle mainBundle] URLForResource:@"Bell" withExtension:@".m4a" subdirectory:@"Sounds"];
    if (soundEffect) {
        float vol = [[NSUserDefaults standardUserDefaults] floatForKey:@"bellVolume"];
        [[AudioManager sharedInstance] playAudioFromFile:soundEffect volume:vol];
    }
}

- (IBAction)ringForcefulBell:(id)sender {
    NSURL* soundEffect = [[NSBundle mainBundle] URLForResource:@"Reception Bell"
                                                 withExtension:@".m4a"
                                                  subdirectory:@"Sounds"];
    if (soundEffect) {
        float vol = [[NSUserDefaults standardUserDefaults] floatForKey:@"forcefulBellVolume"];
        [[AudioManager sharedInstance] playAudioFromFile:soundEffect volume:vol];
    }
}

NSString* removeNonDigits(NSString* input) {
    NSCharacterSet* nonDigits = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
    NSString* digitsOnly = [[input componentsSeparatedByCharactersInSet:nonDigits] componentsJoinedByString:@""];
    return digitsOnly;
}

NSString* detectPhoneNumber(NSString* phoneNumber) {
    // Use NSDataDetector to format the phone number
    NSDataDetector* detector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypePhoneNumber error:nil];
    NSArray<NSTextCheckingResult*>* matches = [detector matchesInString:phoneNumber
                                                                options:0
                                                                  range:NSMakeRange(0, [phoneNumber length])];

    if (matches.count > 0) {
        NSTextCheckingResult* result = matches.firstObject;
        NSString* phone = removeNonDigits([result phoneNumber]);
        if (phone.length != 11) {
            phone = [@"1" stringByAppendingString:phone];
        }
        NSString* fmtPhone = [NSString stringWithFormat:@"+1 (%@) %@-%@", [phone substringWithRange:NSMakeRange(1, 3)],
                                                        [phone substringWithRange:NSMakeRange(4, 3)],
                                                        [phone substringWithRange:NSMakeRange(7, 4)]];
        return fmtPhone;
    }
    return nil;
}

- (IBAction)sendSMS:(id)sender {
    NSString* contact = [[NSUserDefaults standardUserDefaults] stringForKey:@"emergencyMessagesContact"];

    // Messages does zero to normalize phone number, so we have to do it.
    NSString* phoneContact = detectPhoneNumber(contact);
    if (phoneContact != nil) {
        contact = phoneContact;
    }
    NSString* content = [[NSUserDefaults standardUserDefaults] stringForKey:@"emergencyMessagesContent"];
    if ([content isEqual:@""]) {
        content = @"Mavis is sending a distress call.";
    }
    if ([contact isEqual:@""]) {
        [AppDelegate errorAlertWithMessage:@"Failed Sending SMS"
                                   andInfo:@"No emergency Messages contact was configured."];
    }
    NSString* scriptText =
        [NSString stringWithFormat:@"tell application \"Messages\" to send \"%@\" to buddy \"%@\"", content, contact];
    NSAppleScript* script = [[NSAppleScript alloc] initWithSource:scriptText];
    NSDictionary* errDict;
    [script executeAndReturnError:&errDict];
    if (errDict != nil) {
        NSLog(@"error during sendSMS: %@", errDict);
        [AppDelegate errorAlertWithMessage:@"Failed Sending SMS" andInfo:@"Please try again and notify the author."];
    }
    scriptText = @"tell application \"Messages\" to activate";
    script = [[NSAppleScript alloc] initWithSource:scriptText];
    [script executeAndReturnError:&errDict];
    if (errDict != nil) {
        NSLog(@"error trying to activate Messages: %@", errDict);
    }
}

- (void)openFileWithTextEdit:(NSString*)path {
    if (![NSFileManager.defaultManager fileExistsAtPath:path]) {
        [NSFileManager.defaultManager createFileAtPath:path contents:nil attributes:nil];
    }
    [[NSWorkspace sharedWorkspace] openURL:[NSURL fileURLWithPath:path]];
}

- (IBAction)openPhraseList:(id)sender {
    [self openFileWithTextEdit:FileManager.sharedInstance.phrasesFile];
}

- (IBAction)openSoundbites:(id)sender {
    NSError* err;
    NSString* dirPath = [[FileManager sharedInstance] userPath:@"soundbites"];
    [[NSFileManager defaultManager] createDirectoryAtPath:dirPath
                              withIntermediateDirectories:NO
                                               attributes:nil
                                                    error:&err];
    if (err != nil) {
        NSLog(@"dir create failed: err %@", err);
        return;
    }
    [[NSWorkspace sharedWorkspace] openURL:[NSURL fileURLWithPath:dirPath]];
}

- (IBAction)openPronunciationList:(id)sender {
    [self openFileWithTextEdit:FileManager.sharedInstance.pronunciationsFile];
}

- (IBAction)openProperNounsList:(id)sender {
    [self openFileWithTextEdit:FileManager.sharedInstance.properNounsFile];
}

- (IBAction)sayLineAction:(id)sender {
    NSAttributedString* as = [scriptTextView.textStorage attributedSubstringFromRange:[scriptTextView selectedRange]];
    [sayTextView setString:as.string];
    [self sayAction:sender];
}

- (NSRange)unspokenTextRange {
    NSTextStorage* ts = sayTextView.textStorage;
    NSRange attrRange;
    NSRange allRange = NSMakeRange(0, ts.length);
    NSDictionary<NSAttributedStringKey, id>* attrs;
    attrs = [ts attributesAtIndex:0 longestEffectiveRange:&attrRange inRange:allRange];

    NSRange sayRange;
    if (NSEqualRanges(attrRange, allRange)) {
        if ([attrs[@"Mavis"] isEqualTo:@"spoken"]) {
            // Everything has been spoken.
            return NSMakeRange(0, 0);
        }
        // Nothing spoken yet.
        sayRange = allRange;
    } else {
        sayRange = NSMakeRange(attrRange.length, ts.length - attrRange.length);
    }
    return sayRange;
}

- (IBAction)electricPunctuation:(id)sender {
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"speakSentencesAutomatically"]) {
        return;
    }

    NSRange sayRange = [self unspokenTextRange];
    NSString* sayStr = [[sayTextView.textStorage attributedSubstringFromRange:sayRange] string];
    NSArray<NSString*>* tokens = [CompletionManager tokenizeText:sayStr];
    NSString* punc = tokens[tokens.count - 2];
    if ([punc isEqual:@"."] && tokens.count > 2) {
        // Don't trigger on common abbreviations.
        NSString* lastToken = [tokens[tokens.count - 3] lowercaseString];
        // Ignore if this is a well-know abbreviation.
        // We just shouldn't even bother with these, it's not helpful to type them,
        // but maybe this will help once in a while.
        if ([commonAbbreviations containsObject:lastToken]) {
            return;
        }
    }

    NSMutableDictionary* attrs = [[sayTextView.textStorage attributesAtIndex:0 effectiveRange:NULL] mutableCopy];
    [attrs setValue:@"spoken" forKey:@"Mavis"];
    [sayTextView.textStorage setAttributes:attrs range:sayRange];
    [self say:sayStr];
}

- (void)say:(NSString*)text {
    float volume = [[NSUserDefaults standardUserDefaults] floatForKey:@"speakingVolume"];
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"enableDynamicSpeakingVolume"]) {
        volume = [SpeechManager voiceVolumeForNoise:noiseDisplay.floatValue];
        float originalSysVolume = getSystemVolume();
        float speakingSysVolume = [[NSUserDefaults standardUserDefaults] floatForKey:@"speakingSystemVolumeLevel"];
        NSLog(@"Current volume: %f, reset to %f with speaking vol: %4.3f", originalSysVolume, speakingSysVolume,
              volume);
        setSystemVolume(speakingSysVolume);
    }

    [[SpeechManager sharedInstance] say:text
                              withVoice:self.voice
                               withRate:[[NSUserDefaults standardUserDefaults] floatForKey:@"speakingRate"]
                                  Pitch:[[NSUserDefaults standardUserDefaults] floatForKey:@"speakingPitch"]
                                 Volume:volume];
}

- (IBAction)sayAction:(id)sender {
    NSString* say = sayTextView.stringValue;
    if (say.length == 0) {
        [self say:say];
        return;
    }

    if (!triggeredAutocompleteAutomatically &&
        [[NSUserDefaults standardUserDefaults] boolForKey:@"correctOnSpellingErrors"] &&
        [[NSUserDefaults standardUserDefaults] boolForKey:@"enableCorrectorPlugin"]) {
        // If there are spelling/grammar errors, automatically trigger completion.
        NSInteger wordCount;
        NSOrthography* ort;
        NSArray<NSTextCheckingResult*>* results = [[NSSpellChecker sharedSpellChecker]
                       checkString:say
                             range:NSMakeRange(0, say.length)
                             types:NSTextCheckingTypeSpelling | NSTextCheckingTypeCorrection | NSTextCheckingTypeGrammar
                           options:nil
            inSpellDocumentWithTag:0
                       orthography:&ort
                         wordCount:&wordCount];

        if (results.count) {
            // Make sure we don't get stuck in autocompelete hell.
            triggeredAutocompleteAutomatically = YES;
            [sayTextView complete:sender];
            return;
        }
    }
    // coalesce identical history
    [_history removeObject:say];
    [_history addObject:say];
    while (_history.count > 10) {
        [_history removeObjectAtIndex:0];
    }

    [historyTableView reloadData];

    // NOTE: reloadData is a hammer, there might be more subtle things,
    // but I'm not sure they are necessary.
    //    [NSAnimationContext beginGrouping];
    //    [NSAnimationContext currentContext].duration = 0;
    //    [historyTableView noteHeightOfRowsWithIndexesChanged:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0,
    //    (self.history).count)]]; [NSAnimationContext endGrouping];

    // FIXME: this is probably not super efficient, but NSUserDefaults was probably not intended for use as a very slow
    // ring buffer.
    [[NSUserDefaults standardUserDefaults] setObject:self.history forKey:@"speakingHistoryItems"];

    say = [say substringWithRange:[self unspokenTextRange]];
    [self say:say];

    NSDictionary* ann;
    if (noiseMonitor != nil) {
        ann = @{
            @"systemSoundLevel": [NSNumber numberWithFloat:getSystemVolume()],
            @"noiseLevel": [NSNumber numberWithFloat:[noiseDisplay floatValue]],
        };
    }

    [completionManager logString:[sayTextView stringValue]
             withInputKeystrokes:[sayTextView rawStringInput]
                 withAnnotations:ann];

    sayTextView.string = @"";
    [historyTableView scrollRowToVisible:(self.history).count - 1];
    [historyTableView deselectAll:sender];
    triggeredAutocompleteAutomatically = NO;
}

- (IBAction)sayAgain:(id)sender {
    if ([sayTextView.string isEqualToString:@""]) {
        if (self.history.count == 0) {
            return;
        }
        [self selectHistoryItem:(self.history.count - 1)];
    }
    return [self sayAction:sender];
}

- (void)selectHistoryItem:(NSInteger)idx {
    if (idx < 0 || idx >= (self.history).count) {
        return;
    }
    NSIndexSet* indexSet = [NSIndexSet indexSetWithIndex:idx];
    [historyTableView selectRowIndexes:indexSet byExtendingSelection:NO];
    [historyTableView scrollRowToVisible:idx];
    sayTextView.string = (self.history)[idx];
}

- (IBAction)checkForUpdates:(id)sender {
    [UpdateManager scheduleUpdateCheck:YES];
}

- (void)incrementFontSize:(CGFloat)x {
    CGFloat size = [[NSUserDefaults standardUserDefaults] floatForKey:@"fontSize"];
    size += x;
    [[NSUserDefaults standardUserDefaults] setFloat:size forKey:@"fontSize"];
    [historyTableView reloadData];
}

- (IBAction)biggerFontSize:(id)sender {
    [self incrementFontSize:1.0];
}

- (IBAction)smallerFontSize:(id)sender {
    [self incrementFontSize:-1.0];
}

- (IBAction)deleteSelectedHistoryItem:(id)sender {
    // Delete whatever was composed to more-or-less mirror default text editting behavior.
    if (![sayTextView.string isEqualToString:@""]) {
        sayTextView.string = @"";
    } else if (historyTableView.selectedRow >= 0 && historyTableView.selectedRow < self.history.count) {
        [self.history removeObjectAtIndex:historyTableView.selectedRow];
        [historyTableView reloadData];
        [[NSUserDefaults standardUserDefaults] setObject:self.history forKey:@"speakingHistoryItems"];
    }
}

- (IBAction)clearAllHistoryItems:(id)sender {
    [self.history removeAllObjects];
    [historyTableView reloadData];
    [[NSUserDefaults standardUserDefaults] setObject:self.history forKey:@"speakingHistoryItems"];
}

- (IBAction)selectNextHistoryItem:(id)sender {
    NSInteger idx = historyTableView.selectedRow;
    idx++;

    [self selectHistoryItem:idx];
}

- (IBAction)selectPreviousHistoryItem:(id)sender {
    NSInteger idx = historyTableView.selectedRow;
    if (idx < 0) {
        idx = (self.history).count - 1;
    } else {
        idx--;
    }

    [self selectHistoryItem:idx];
}

- (IBAction)exportLogs:(id)sender {
    [FileManager.sharedInstance exportLogs];
}

- (IBAction)uploadLogs:(id)sender {
    [FileManager.sharedInstance uploadLogs];
}

- (IBAction)showHelp:(id)sender {
    NSURL* url = [[NSBundle mainBundle] URLForResource:@"help" withExtension:@"html" subdirectory:@"Help"];
    [[NSWorkspace sharedWorkspace] openURL:url];
}

- (IBAction)showMavisScript:(id)sender {
    [scriptWindow setIsVisible:YES];
    [scriptWindow makeKeyAndOrderFront:sender];
}

- (IBAction)showMavis:(id)sender {
    [window setIsVisible:YES];
    [window makeKeyAndOrderFront:sender];
}

- (IBAction)showPreferences:(id)sender {
    [prefsWindow setIsVisible:YES];
    [prefsWindow makeKeyWindow];
}

#pragma mark - Text View

//- (NSArray<NSString*>*)textView:(NSTextView*)textView
//                    completions:(NSArray<NSString*>*)words
//            forPartialWordRange:(NSRange)charRange
//            indexOfSelectedItem:(NSInteger*)index {
//    NSString* partial = [textView.string substringWithRange:charRange];
//    NSArray* wl = [completionManager completions:words forPartialString:partial withContext:textView.string];
//    NSLog(@"complete: %@ '%@' -> %@", textView.string, partial, [wl componentsJoinedByString:@", "]);
//    return wl;
//}

- (BOOL)textView:(NSTextView*)textView doCommandBySelector:(SEL)commandSelector {
    // FIXME(msolo) Seems a bit janky to check which text view - too many text views are using the same delegate.
    if (textView != sayTextView) {
        return NO;
    }

    BOOL result = NO;
    if (commandSelector == @selector(insertTab:)) {
        // tab action: trigger completion.
        [textView complete:nil];
        result = YES;
    } else if (commandSelector == @selector(insertNewline:)) {
        // Send action on newline.
        [self sayAction:nil];
        result = YES;
    }
    return result;
}

- (void)textDidChange:(NSNotification*)notification {
    if (triggeredAutocompleteAutomatically) {
        if ([@"" isEqual:sayTextView.stringValue]) {
            // Reset if the selection is cleared.
            triggeredAutocompleteAutomatically = NO;
        }
    }
}

- (NSMenu*)textView:(NSTextView*)view menu:(NSMenu*)menu forEvent:(NSEvent*)event atIndex:(NSUInteger)charIndex {
    // FIXME(msolo) Seems a bit janky to check which text view - too many text views are using the same delegate.
    if (view != scriptTextView) {
        return menu;
    }

    // Avoid the clutter of plugins - most are not useful anyway.
    speakContextMenu.allowsContextMenuPlugIns = NO;
    [scriptTextView selectLine:nil];
    [scriptTextView setSelectedRange:[scriptTextView selectionRangeForProposedRange:[scriptTextView selectedRange]
                                                                        granularity:NSSelectByParagraph]];
    return speakContextMenu;
}

#pragma mark - Table View

// MSTableView will send this message to its delegate when the return key is pressed.
- (void)insertNewline:(id)sender {
    [self sayAction:nil];
}

- (void)tableViewColumnDidResize:(NSNotification*)evt {
    // FIXME: The rendering isn't correct when simply noting the changed heights.
    // Forcing a reload works for now; good thing the data source is tiny.
    // [historyTableView noteHeightOfRowsWithIndexesChanged:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0,
    // (self.history).count)]];
    [historyTableView reloadData];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView*)tableView {
    return self.history.count;
}

- (id)tableView:(NSTableView*)tableView objectValueForTableColumn:(NSTableColumn*)tableColumn row:(NSInteger)row {
    return [[NSAttributedString alloc]
        initWithString:self.history[row]
            attributes:@{
                NSFontAttributeName:
                    [NSFont systemFontOfSize:[[NSUserDefaults standardUserDefaults] floatForKey:@"fontSize"]]
            }];
}

- (void)tableViewSelectionDidChange:(NSNotification*)notification {
    if (historyTableView.selectedRow >= 0 && historyTableView.selectedRow < self.history.count) {
        sayTextView.string = self.history[historyTableView.selectedRow];
    } else {
        sayTextView.string = @"";
    }
}

- (CGFloat)tableView:(NSTableView*)tableView heightOfRow:(NSInteger)row {
    CGFloat minimumMargin = 8.0;
    CGFloat minimumHeight = tableView.rowHeight;
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

#pragma mark - Core Data stack

@synthesize persistentContainer = _persistentContainer;

- (NSPersistentContainer*)persistentContainer {
    // The persistent container for the application. This implementation creates and returns a container, having loaded
    // the store for the application to it.
    @synchronized(self) {
        if (_persistentContainer == nil) {
            _persistentContainer = [[NSPersistentContainer alloc] initWithName:@"Mavis"];
            [_persistentContainer loadPersistentStoresWithCompletionHandler:^(
                                      NSPersistentStoreDescription* storeDescription, NSError* error) {
              if (error != nil) {
                  // Replace this implementation with code to handle the error appropriately.
                  // abort() causes the application to generate a crash log and terminate. You should not use this
                  // function in a shipping application, although it may be useful during development.

                  /*
                   Typical reasons for an error here include:
                   * The parent directory does not exist, cannot be created, or disallows writing.
                   * The persistent store is not accessible, due to permissions or data protection when the device is
                   locked.
                   * The device is out of space.
                   * The store could not be migrated to the current model version.
                   Check the error message to determine what the actual problem was.
                  */
                  NSLog(@"Unresolved error %@, %@", error, error.userInfo);
                  abort();
              }
            }];
        }
    }

    return _persistentContainer;
}

#pragma mark - Core Data Saving and Undo support

- (IBAction)saveAction:(id)sender {
    // Performs the save action for the application, which is to send the save: message to the application's managed
    // object context. Any encountered errors are presented to the user.
    NSManagedObjectContext* context = self.persistentContainer.viewContext;

    if (![context commitEditing]) {
        NSLog(@"%@:%@ unable to commit editing before saving", [self class], NSStringFromSelector(_cmd));
    }

    NSError* error = nil;
    if (context.hasChanges && ![context save:&error]) {
        // Customize this code block to include application-specific recovery steps.
        [[NSApplication sharedApplication] presentError:error];
    }
}

- (NSUndoManager*)windowWillReturnUndoManager:(NSWindow*)window {
    // Returns the NSUndoManager for the application. In this case, the manager returned is that of the managed object
    // context for the application.
    return self.persistentContainer.viewContext.undoManager;
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication*)sender {
    // Save changes in the application's managed object context before the application terminates.
    NSManagedObjectContext* context = self.persistentContainer.viewContext;

    if (![context commitEditing]) {
        NSLog(@"%@:%@ unable to commit editing to terminate", [self class], NSStringFromSelector(_cmd));
        return NSTerminateCancel;
    }

    if (!context.hasChanges) {
        return NSTerminateNow;
    }

    NSError* error = nil;
    if (![context save:&error]) {

        // Customize this code block to include application-specific recovery steps.
        BOOL result = [sender presentError:error];
        if (result) {
            return NSTerminateCancel;
        }

        NSString* question = NSLocalizedString(@"Could not save changes while quitting. Quit anyway?",
                                               @"Quit without saves error question message");
        NSString* info =
            NSLocalizedString(@"Quitting now will lose any changes you have made since the last successful save",
                              @"Quit without saves error question info");
        NSString* quitButton = NSLocalizedString(@"Quit anyway", @"Quit anyway button title");
        NSString* cancelButton = NSLocalizedString(@"Cancel", @"Cancel button title");
        NSAlert* alert = [[NSAlert alloc] init];
        alert.messageText = question;
        alert.informativeText = info;
        [alert addButtonWithTitle:quitButton];
        [alert addButtonWithTitle:cancelButton];

        NSInteger answer = [alert runModal];

        if (answer == NSAlertSecondButtonReturn) {
            return NSTerminateCancel;
        }
    }

    return NSTerminateNow;
}

@end
