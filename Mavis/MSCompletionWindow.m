#import "MSCompletionWindow.h"

@implementation MSCompletionWindow

- (void)resignKeyWindow {
    [super resignKeyWindow];
    if ([self.delegate respondsToSelector:@selector(cancel:)]) {
        [(id)self.delegate cancel:self];
        return;
    }
}

- (BOOL)canBecomeKeyWindow {
    return YES;
}

@end
