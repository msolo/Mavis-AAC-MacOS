#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@protocol MSCompletionDelegate
@optional
- (void)accept:(id)sender;
- (void)cancel:(id)sender;
@end

@interface MSCompletionWindow : NSWindow

@end

NS_ASSUME_NONNULL_END
