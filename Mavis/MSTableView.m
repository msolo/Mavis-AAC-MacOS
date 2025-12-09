#import "MSTableView.h"
@import Carbon;

@implementation MSTableView

// Trap Return key and forward insertNewline to the delegate.
// There must be a better way, but I can't seem to find it.
- (void)keyDown:(NSEvent*)evt {
    if (evt.keyCode == kVK_Return) {
        if ([self.delegate respondsToSelector:@selector(insertNewline:)]) {
            [(id)self.delegate insertNewline:self];
            return;
        }
        if ([self.delegate respondsToSelector:@selector(accept:)]) {
            [(id)self.delegate accept:self];
            return;
        }
    }
    if (evt.keyCode == kVK_Escape && [self.delegate respondsToSelector:@selector(cancel:)]) {
        [(id)self.delegate cancel:self];
        return;
    }
    if (evt.keyCode == kVK_Delete && [self.delegate respondsToSelector:@selector(cancel:)]) {
        [(id)self.delegate cancel:self];
        return;
    }
    [super keyDown:evt];
}

@end
