#import "MSScoredString.h"

// Record a score with a string to enable sorting a list.
@implementation MSScoredString

- (MSScoredString*)initWithString:(NSString*)s andScore:(float)score {
    self.string = s;
    self.score = score;
    return self;
}

- (NSComparisonResult)compareAsc:(MSScoredString*)s {
    if (self.score < s.score) {
        return NSOrderedAscending;
    } else if (self.score > s.score) {
        return NSOrderedDescending;
    } else {
        return NSOrderedSame;
    }
}

- (NSComparisonResult)compareDesc:(MSScoredString*)s {
    return -[self compareAsc:s];
}

- (NSString*)description {
    return [NSString stringWithFormat:@"%@:%4.2f", self.string, self.score];
}
@end
