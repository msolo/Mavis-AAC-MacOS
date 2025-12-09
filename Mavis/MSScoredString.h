#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MSScoredString : NSObject

@property NSString* string;
@property float score;

- (MSScoredString*)initWithString:(NSString*)s andScore:(float)score;
- (NSComparisonResult)compareAsc:(MSScoredString*)s;
- (NSComparisonResult)compareDesc:(MSScoredString*)s;

@end

NS_ASSUME_NONNULL_END
