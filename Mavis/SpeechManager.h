#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SpeechManager : NSObject
@property NSDictionary<NSString*, NSString*>* pronunciationMap;
@property (nonatomic, getter=soundbiteMap, readonly) NSDictionary<NSString*, NSURL*>* soundbiteMap;
@property (nonatomic, getter=soundbites, readonly) NSArray<NSString*>* soundbites;

+ (SpeechManager*)sharedInstance;
+ (float)voiceVolumeForNoise:(float)noise;

- (NSArray<AVSpeechSynthesisVoice*>*)getVoices;
- (AVSpeechSynthesisVoice*)defaultVoice;
- (void)say:(NSString*)text
    withVoice:(AVSpeechSynthesisVoice*)voice
     withRate:(float)rate
        Pitch:(float)pitch
       Volume:(float)volume;

@end

NS_ASSUME_NONNULL_END
