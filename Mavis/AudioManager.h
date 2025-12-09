#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AudioManager : NSObject

+ (AudioManager*)sharedInstance;

- (void)playAudioFromFile:(NSURL*)fileURL volume:(float)volume;

@end

NS_ASSUME_NONNULL_END
