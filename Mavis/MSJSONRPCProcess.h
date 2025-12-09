#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MSJSONRPCProcess : NSObject
@property (strong, nonatomic) NSTask* task;
@property (strong, readonly) NSFileHandle* inputHandle;
@property (strong, readonly) NSFileHandle* outputHandle;

- (MSJSONRPCProcess*)initProcessWithPath:(NSString*)processPath arguments:(NSArray<NSString*>*)arguments;
//- (NSDictionary*)recvMessageWithError:(NSError**)error;
//- (NSError*)sendMessage:(NSDictionary *)message;
- (id)callMethod:(NSString*)method withArgs:(NSDictionary*)args error:(NSError**)error;
@end

NS_ASSUME_NONNULL_END
