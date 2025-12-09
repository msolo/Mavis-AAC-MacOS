#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@protocol MSTextViewDelegate <NSTextViewDelegate>
@optional
- (void)electricPunctuation:(id)sender;
@end

@interface MSTextView : NSTextView {
    NSMutableString* rawStringInput;
}

@property (atomic, weak) id<MSTextViewDelegate> delegate;

- (NSString*)rawStringInput;
- (NSString*)stringValue;

@end

NS_ASSUME_NONNULL_END
