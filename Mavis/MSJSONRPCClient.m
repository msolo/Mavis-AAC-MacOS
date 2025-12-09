#import "MSJSONRPCClient.h"

@implementation MSJSONRPCClient {
    NSURL* _baseURL;
}

- (instancetype)initWithBaseURL:(NSURL*)baseURL {
    self = [super init];
    if (self) {
        _baseURL = baseURL;
        NSURLSessionConfiguration* configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        configuration.HTTPShouldUsePipelining = YES;   // Enable persistent connections
        configuration.timeoutIntervalForRequest = 3.0; // Set timeout for requests

        // Create session with configuration
        self.session = [NSURLSession sessionWithConfiguration:configuration];
    }
    return self;
}

- (NSURL*)buildURLWithPath:(NSString*)path parameters:(NSDictionary*)parameters {
    NSURLComponents* components = [NSURLComponents componentsWithURL:[_baseURL URLByAppendingPathComponent:path]
                                             resolvingAgainstBaseURL:NO];

    NSMutableArray<NSURLQueryItem*>* queryItems = [NSMutableArray array];
    for (NSString* key in parameters) {
        NSURLQueryItem* queryItem = [NSURLQueryItem queryItemWithName:key value:parameters[key]];
        [queryItems addObject:queryItem];
    }
    components.queryItems = queryItems;
    return components.URL;
}

- (void)sendAsyncRequestToEndpoint:(NSString*)endpoint
                    withParameters:(NSDictionary*)params
                    withCompletion:(void (^)(NSDictionary* jsonResponse, NSError* error))completion {
    NSURL* url = [self buildURLWithPath:endpoint parameters:params];

    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"GET";

    [[_session dataTaskWithRequest:request
                 completionHandler:^(NSData* data, NSURLResponse* response, NSError* error) {
                   if (error) {
                       completion(nil, error);
                       return;
                   }

                   NSError* jsonError;
                   NSDictionary* jsonResponse = [NSJSONSerialization JSONObjectWithData:data
                                                                                options:0
                                                                                  error:&jsonError];
                   if (jsonError) {
                       completion(nil, jsonError);
                   } else {
                       completion(jsonResponse, nil);
                   }
                 }] resume];
}

- (NSDictionary*)sendSyncRequestToEndpoint:(NSString*)endpoint
                            withParameters:(NSDictionary*)params
                                   timeout:(NSInteger)timeoutInMillis
                                     error:(NSError**)error {
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

    __block NSDictionary* jsonResponse = nil;
    __block NSError* requestError = nil;

    [self sendAsyncRequestToEndpoint:endpoint
                      withParameters:(NSDictionary*)params
                      withCompletion:^(NSDictionary* response, NSError* err) {
                        jsonResponse = response;
                        requestError = err;
                        dispatch_semaphore_signal(semaphore);
                      }];

    // Wait for the semaphore signal with a timeout in milliseconds
    dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, timeoutInMillis * NSEC_PER_MSEC);
    if (dispatch_semaphore_wait(semaphore, timeout) != 0) {
        if (error) {
            *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorTimedOut userInfo:nil];
        }
        return nil;
    }

    if (error) {
        *error = requestError;
    }
    return jsonResponse;
}

- (id)callMethod:(NSString*)method withArgs:(NSDictionary*)args timeout:(NSInteger)timeout error:(NSError**)error {
    NSDictionary* reply = [self sendSyncRequestToEndpoint:method withParameters:args timeout:timeout error:error];
    if (*error != nil) {
        return nil;
    }
    if (reply[@"error"] != [NSNull null]) {
        *error = [NSError errorWithDomain:@"MavisError" code:1 userInfo:@{@"JSONRPCClientError": reply[@"error"]}];
    }
    return reply[@"return"];
}

@end
