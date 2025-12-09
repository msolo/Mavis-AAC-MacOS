@import Foundation;
@import AppKit;

NS_ASSUME_NONNULL_BEGIN

@interface FaceTimeIntegration : NSObject {
    BOOL backgroundRunning;
    BOOL isFaceTimeRunning;
    NSBackgroundActivityScheduler* activity;
}

+ (FaceTimeIntegration*)sharedInstance;

- (void)startBackground;

+ (void)startSharePlay:(NSWindow*)sharePlayWindow;
+ (void)stopSharePlay:(NSWindow*)sharePlayWindow;

+ (void)errorAlertWithInfo:(NSString*)info;

+ (int)pidForProcessWithBundleIdentifier:(NSString*)bundleIdentifier;

@end

NS_ASSUME_NONNULL_END
