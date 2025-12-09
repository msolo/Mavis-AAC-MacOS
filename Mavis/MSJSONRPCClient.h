#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MSJSONRPCClient : NSObject

@property (strong, nonatomic) NSURLSession* session;

- (instancetype)initWithBaseURL:(NSURL*)baseURL;
//- (void)sendAsyncRequestToEndpoint:(NSString *)endpoint withParameters:(NSDictionary*)params withCompletion:(void
//(^)(NSDictionary *jsonResponse, NSError *error))completion;
//- (NSDictionary*)sendSyncRequestToEndpoint:(NSString *)endpoint withParameters:(NSDictionary*)params
// timeout:(NSInteger)timeoutInMillis error:(NSError **)error;
- (id)callMethod:(NSString*)method withArgs:(NSDictionary*)args timeout:(NSInteger)timeout error:(NSError**)error;

@end

NS_ASSUME_NONNULL_END
