#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface UpdateManager : NSObject

+ (void)scheduleUpdateCheck:(BOOL)showNoUpdate;

@end

NS_ASSUME_NONNULL_END
