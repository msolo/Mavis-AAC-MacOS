#import "SpeechManager.h"
#import "AudioManager.h"
#import "CompletionManager.h"
#import "FileManager.h"
#import "SoundCzech.h"

@implementation SpeechManager {
    AVSpeechSynthesizer* synth;
    NSDictionary<NSString*, NSURL*>* _soundbiteMap;
    NSArray<NSString*>* _soundbites;
}

+ (SpeechManager*)sharedInstance {
    static SpeechManager* sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (SpeechManager*)init {
    self = [super init];
    synth = [[AVSpeechSynthesizer alloc] init];
    return self;
}

- (NSArray<AVSpeechSynthesisVoice*>*)getVoices {
    NSMutableArray* va = [[NSMutableArray alloc] init];

    AVSpeechSynthesisVoice* personalVoice;
    // If nothing high quality is installed, show something.
    AVSpeechSynthesisVoice* fallbackVoice;

    for (AVSpeechSynthesisVoice* v in [AVSpeechSynthesisVoice speechVoices]) {
        if (@available(macOS 14, *)) {
            if (v.voiceTraits == AVSpeechSynthesisVoiceTraitIsPersonalVoice) {
                personalVoice = v;
            }
        }
        if ([v.language hasPrefix:@"en"]) {
            if (v.quality != AVSpeechSynthesisVoiceQualityDefault) {
                NSLog(@"voice %@", v);
                [va addObject:v];
            } else if (fallbackVoice == nil) {
                fallbackVoice = v;
            }
        }
    }
    if (personalVoice != nil && ![va containsObject:personalVoice]) {
        [va addObject:personalVoice];
    }

    if (va.count == 0) {
        [va addObject:fallbackVoice];
    }

    return va;
}

- (AVSpeechSynthesisVoice*)defaultVoice {
    NSString* vid = [[NSUserDefaults standardUserDefaults] objectForKey:@"speakingVoiceIdentifier"];
    AVSpeechSynthesisVoice* voice = [AVSpeechSynthesisVoice voiceWithIdentifier:vid];

    if (voice != nil) {
        return voice;
    }

    // If we have a personal voice, use that.
    NSArray<AVSpeechSynthesisVoice*>* voices = [self getVoices];
    for (AVSpeechSynthesisVoice* v in voices) {
        if (@available(macOS 14, *)) {
            if (v.voiceTraits == AVSpeechSynthesisVoiceTraitIsPersonalVoice) {
                return v;
            }
        }
    }

    if (voices.count > 0) {
        return voices.lastObject;
    }

    return nil;
}

- (NSString*)fixProunciations:(NSString*)text {
    NSArray<NSString*>* l =
        [[FileManager sharedInstance] readFileAsStringArray:[FileManager sharedInstance].pronunciationsFile];
    if (l != nil) {
        NSMutableDictionary<NSString*, NSString*>* md = [[NSMutableDictionary alloc] init];
        for (NSString* line in l) {
            NSArray<NSString*>* fields = [line componentsSeparatedByString:@"|"];
            NSString* k =
                [[fields[0] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet] lowercaseString];
            NSString* v = [fields[1] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
            md[k] = v;
        }
        self.pronunciationMap = md;
    }

    NSMutableArray<NSString*>* tokens = [[CompletionManager tokenizeText:text] mutableCopy];
    for (int i = 0; i < tokens.count; i++) {
        NSString* t = [tokens[i] lowercaseString];
        NSString* tnew = [self.pronunciationMap valueForKey:t];
        if (tnew != nil) {
            tokens[i] = tnew;
        }
    }
    return [tokens componentsJoinedByString:@""];
}

- (NSString*)fixSynthBugs:(NSString*)text {
    // A trailing backslash causes the string to not be uttered. I can't imagine what this is for.
    text = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    text = [text stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\\"]];
    return text;
}

- (void)say:(NSString*)text
    withVoice:(AVSpeechSynthesisVoice*)voice
     withRate:(float)rate
        Pitch:(float)pitch
       Volume:(float)volume {
    if (text.length == 0) {
        if ([synth isSpeaking]) {
            [synth stopSpeakingAtBoundary:AVSpeechBoundaryImmediate];
        }
    }

    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"enableSoundbites"]) {
        NSURL* soundBite = [self matchingSoundBiteFile:text];
        if (soundBite) {
            // FIXME: this is not supposed to work, but the documentation for this is poor,
            // I'm not even sure what to make of it. Setting this to 4.0 seems to raise the volume "enough"
            float vol = [[NSUserDefaults standardUserDefaults] floatForKey:@"soundbiteVolume"];
            NSLog(@"play soundbite: %@ volume: %f", soundBite, vol);
            [[AudioManager sharedInstance] playAudioFromFile:soundBite volume:vol];
            return;
        }
    }

    // Do a little preprocessing.
    text = [self fixProunciations:text];
    text = [self fixSynthBugs:text];

    AVSpeechUtterance* utt = [AVSpeechUtterance speechUtteranceWithString:text];
    if (@available(macOS 13, *)) {
        // FIXME: hack to test out SSML
        if ([text hasPrefix:@"<"]) {
            utt = [AVSpeechUtterance speechUtteranceWithSSMLRepresentation:text];
        }
    }

    if ([synth isSpeaking]) {
        [synth stopSpeakingAtBoundary:AVSpeechBoundaryImmediate];
        // Give a small gap so people can notice!
        utt.preUtteranceDelay = 0.300;
    }

    utt.rate = rate;
    utt.pitchMultiplier = pitch;
    utt.voice = voice;
    utt.volume = volume;
    [synth speakUtterance:utt];
}

// FIXME: can we use output stream to get output in decibels?
// Return a reasonable guess at appropriate voice volume based on noise factors.
+ (float)voiceVolumeForNoise:(float)noise {
    // According to the midi manager, 0->1 is -63.5dB -> 0dB in 0.0625 increments (1/16ths)
    // Noise range seems to be -67 to ~+30. This is supposedly dB, but I can't really tell.
    // 1 0.5 0.25 0.125 0.0625 0.03125 0.015625
    // Dead silence is ~ -60
    // Typical burble at the house not doing much is ~ -45
    // Typical burble at the dental office is ~ -40
    // When active speaking is going on, it looks like it might be ~35 - -30.
    // When typing on the keyboard the background avg is ~35 as well.
    // Rubbing on the microphone input is almost +30.
    //    float minVolume = 0.015;
    //    float minNoiseLevel = -67.0;
    //    float maxNoiseLevel = 30.0;
    //    float noiseRange = maxNoiseLevel - minNoiseLevel;
    //    Per the MIDI setup tool, this is the dB level from 0 -> 1 in 0.0625 increments.
    //    -63.5
    //    -47.6
    //    -41.05
    //    -36
    //    -31.75
    //    -28
    //    -24.6
    //    -21.5
    //    -18.6
    //    -15.88
    //    -13.3
    //    -10.85
    //    -8.5
    //    -6.26
    //    -4.1
    //    -2
    //    0
    float vol = 0; //(noise - minNoiseLevel) / noiseRange;

    if (noise < -50) {
        vol = 0.015;
    } else if (noise < -40) {
        vol = 0.03;
    } else if (noise < -30) {
        vol = 0.06;
    } else if (noise < -20) {
        vol = 0.12;
    } else if (noise < -10) {
        vol = 0.25;
    } else if (noise < 0) {
        vol = 0.5;
    } else {
        vol = 1;
    }
    vol = MIN(1.0f, vol * 2);
    return vol;
}

- (NSString*)normalizeBite:(NSString*)bite {
    bite = [bite stringByReplacingOccurrencesOfString:@"’" withString:@"'"]; // dreaded "smart" apostrophe.
    // Remove trailing period, but retain ! and ? in case they indicate some exitement.
    return [[[bite lowercaseString] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet]
        stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"."]];
}

- (void)_reloadSoundbites {
    NSArray<NSString*>* validExtensions = @[@"m4a", @"wav"];
    NSString* dir = [[FileManager sharedInstance] userPath:@"soundbites"];
    NSArray<NSString*>* files = [[FileManager sharedInstance] readDir:dir];
    if (files != nil) {
        NSMutableArray<NSString*>* bites = [[NSMutableArray alloc] init];
        NSMutableDictionary<NSString*, NSURL*>* biteFileMap = [[NSMutableDictionary alloc] init];
        for (NSString* f in files) {
            if (![validExtensions containsObject:[f pathExtension]]) {
                continue;
            }
            NSString* bite = [[f lastPathComponent] stringByDeletingPathExtension];
            [bites addObject:bite];
            bite = [self normalizeBite:bite];
            NSURL* fu = [NSURL fileURLWithPathComponents:@[dir, f]];
            biteFileMap[bite] = fu;
        }
        [bites sortUsingSelector:@selector(compare:)];
        _soundbites = bites;
        _soundbiteMap = biteFileMap;
    }
}

- (NSDictionary<NSString*, NSURL*>*)soundbiteMap {
    [self _reloadSoundbites];
    return _soundbiteMap;
}

- (NSArray<NSString*>*)soundbites {
    [self _reloadSoundbites];
    return _soundbites;
}

- (NSURL*)matchingSoundBiteFile:(NSString*)text {
    // FIXME: not sure how to make this better yet.
    return self.soundbiteMap[[self normalizeBite:text]];
}

@end
