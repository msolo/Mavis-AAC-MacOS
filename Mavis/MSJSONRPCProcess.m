#import "MSJSONRPCProcess.h"

@implementation MSJSONRPCProcess

- (MSJSONRPCProcess*)initProcessWithPath:(NSString*)processPath arguments:(NSArray<NSString*>*)arguments {
    self = [super init];
    self.task = [[NSTask alloc] init];

    self.task.launchPath = processPath;
    self.task.arguments = arguments;
    self.task.standardInput = [NSPipe pipe];
    self.task.standardOutput = [NSPipe pipe];

    _inputHandle = [self.task.standardInput fileHandleForWriting];
    _outputHandle = [self.task.standardOutput fileHandleForReading];

    // Launch the task
    [self.task launch];
    return self;
}

- (NSError*)sendMessage:(NSDictionary*)message {
    NSError* error;
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:message options:0 error:&error];
    if (error) {
        return error;
    }
    [self.inputHandle writeData:jsonData];
    [self.inputHandle writeData:[@"\n" dataUsingEncoding:NSUTF8StringEncoding]];
    return nil;
}

- (NSDictionary*)recvMessageWithError:(NSError**)error {
    NSData* lineData = [self readLineFromOutput];
    if (!lineData) {
        return nil;
    }

    NSDictionary* jsonDict = [NSJSONSerialization JSONObjectWithData:lineData options:0 error:error];
    if (!jsonDict) {
        return nil;
    }

    return jsonDict;
}

- (NSData*)readLineFromOutput {
    NSData* data = [self.outputHandle availableData];
    if (data.length > 0) {
        const char* bytes = data.bytes;
        if (bytes[data.length - 1] == '\n') {
            return data;
        }
    }

    // FIXME: this is awful
    NSMutableData* lineData = [data mutableCopy];
    NSData* newLineData = [@"\n" dataUsingEncoding:NSUTF8StringEncoding];
    NSData* charData = nil;
    while ((charData = [self.outputHandle readDataOfLength:1]) && [charData length] > 0) {
        [lineData appendData:charData];
        if ([charData isEqualToData:newLineData]) {
            break;
        }
    }
    return [lineData length] > 0 ? lineData : nil;
}

- (id)callMethod:(NSString*)method withArgs:(NSDictionary*)args error:(NSError**)error {
    NSDictionary* msg = @{@"method": method, @"args": args};
    *error = [self sendMessage:msg];
    if (*error != nil) {
        return nil;
    }
    NSDictionary* reply = [self recvMessageWithError:error];
    if (*error != nil) {
        return nil;
    }
    if (reply[@"error"] != [NSNull null]) {
        *error = [NSError errorWithDomain:@"MavisError" code:1 userInfo:@{@"JSONRPCProcessError": reply[@"error"]}];
    }
    return reply[@"return"];
}

@end
