#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@protocol MSTableViewDelegate <NSTableViewDelegate>
@optional
- (void)accept:(id)sender;
- (void)cancel:(id)sender;
@end

@interface MSTableView : NSTableView

@end

NS_ASSUME_NONNULL_END
