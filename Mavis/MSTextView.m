#import "MSTextView.h"
#import "AppDelegate.h"
#import "AudioManager.h"
#import "CompletionManager.h"

@import Carbon;

@implementation MSTextView

@dynamic delegate;

// Fix default behaviors.
- (void)awakeFromNib {
    self.usesAdaptiveColorMappingForDarkAppearance = YES;
    if (rawStringInput == nil) {
        rawStringInput = [[NSMutableString alloc] init];
    }
}

- (NSString*)rawStringInput {
    return [rawStringInput copy];
}

// Behave more like NSTextField. If we use .string, it's a reference
// that continues to be modified.
- (NSString*)stringValue {
    return self.textStorage.string.copy;
}

// Override so we clear out the rawInput
- (void)setString:(NSString*)s {
    super.string = s;
    [rawStringInput setString:s];
}

// Override the completion range so that when we have an empty word completion, we
// instead try to complete based on the whole phrase.
- (NSRange)rangeForUserCompletion {
    NSRange r = [super rangeForUserCompletion];
    if (r.length == 0) {
        r = NSMakeRange(0, self.string.length);
    }
    return r;
}

- (void)complete:(id)sender {
    AppDelegate* appDelegate = (AppDelegate*)[[NSApplication sharedApplication] delegate];
    [[appDelegate completionManager] showCompletions:self];
}

- (void)keyDown:(NSEvent*)evt {
    // cModified will yield ("", "é") for (option-e, e)
    // NSString* cModified = [evt characters];

    // Modifiers seem to be control/option
    NSString* logStr = [evt charactersIgnoringModifiers];

    switch (evt.keyCode) {
        case kVK_Return:
            logStr = @"<ret>";
            break;
        case kVK_Delete:
            if ((NSEventModifierFlagOption & evt.modifierFlags) == NSEventModifierFlagOption) {
                logStr = @"<del-word>";
            } else {
                logStr = @"<del>";
            }
            break;
        case kVK_Tab:
            logStr = @"<tab>";
            break;
        case kVK_UpArrow:
            logStr = @"<up>";
            break;
        case kVK_DownArrow:
            logStr = @"<down>";
            break;
        case kVK_LeftArrow:
            logStr = @"<left>";
            break;
        case kVK_RightArrow:
            logStr = @"<right>";
            break;
        case kVK_ANSI_0:
        case kVK_ANSI_9:
        case kVK_ANSI_8:
        case kVK_ANSI_7:
        case kVK_ANSI_6:
        case kVK_ANSI_5:
        case kVK_ANSI_4:
        case kVK_ANSI_3:
        case kVK_ANSI_2:
        case kVK_ANSI_1:
            if (((NSEventModifierFlagOption | NSEventModifierFlagShift) & evt.modifierFlags)) {
                break;
            }
            if (![[NSUserDefaults standardUserDefaults] boolForKey:@"ignoreNumberKeys"]) {
                break;
            }
        case kVK_ANSI_LeftBracket:
        case kVK_ANSI_RightBracket:
        case kVK_ANSI_Backslash:
        case kVK_ANSI_Semicolon:
        case kVK_ANSI_Equal:
        case kVK_ANSI_Grave:
            // These keys don't convey any spoken meaning, but they often look like
            // typos to the eye so they can be classified as noise.
            if ([[NSUserDefaults standardUserDefaults] boolForKey:@"ignoreUselessKeys"]) {
                return;
            }
            break;
    }

    [rawStringInput appendString:logStr];
    [super keyDown:evt];

    if ((NSEventModifierFlagOption & evt.modifierFlags) == 0) {
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"enableNoisyTyping"]) {
            NSURL* soundEffect = [[NSBundle mainBundle] URLForResource:@"Tock"
                                                         withExtension:@".caf"
                                                          subdirectory:@"Sounds"];
            if (soundEffect) {
                float vol = [[NSUserDefaults standardUserDefaults] floatForKey:@"keyClickVolume"];
                [[AudioManager sharedInstance] playAudioFromFile:soundEffect volume:vol];
            }
        }
    }
}

- (void)keyUp:(NSEvent*)evt {
    if (evt.keyCode == kVK_Space) {
        // This is sloppy, but no telling if this feature will even be used.
        if ([self.textStorage.string hasSuffix:@". "] || [self.textStorage.string hasSuffix:@"! "] ||
            [self.textStorage.string hasSuffix:@"? "]) {
            if (self.delegate) {
                [self.delegate electricPunctuation:self];
            }
        }
    }
    [super keyUp:evt];
}

@end
