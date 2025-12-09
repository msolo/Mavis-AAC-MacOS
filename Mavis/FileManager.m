#import "FileManager.h"

@implementation FileManager

+ (FileManager*)sharedInstance {
    static FileManager* sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (NSString*)phrasesFile {
    return [self userPath:@"phrases.txt"];
}

- (NSString*)pronunciationsFile {
    return [self userPath:@"pronunciations.txt"];
}

- (NSString*)properNounsFile {
    return [self userPath:@"proper-nouns.txt"];
}

- (id)init {
    modDateByPath = [[NSMutableDictionary alloc] init];
    return self;
}

- (BOOL)isSandboxingEnabled {
    return [NSProcessInfo processInfo].environment[@"APP_SANDBOX_CONTAINER_ID"] != nil;
}

- (NSString*)userPath:(NSString*)p {
    return [[NSString stringWithFormat:@"~/Library/Application Support/Mavis AAC/%@", p] stringByExpandingTildeInPath];
}

// FIXME: rename so we know this is cached.
- (NSString*)readFileData:(NSString*)path {
    NSError* err;
    NSString* txt;
    NSDate* modDate;
    NSDictionary* attr = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:&err];
    if (err == nil) {
        modDate = attr[NSFileModificationDate];
        if ([modDateByPath[path] isEqual:modDate]) {
            return nil;
        }

        txt = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&err];
    }
    if (err != nil) {
        if ([err code] != NSFileReadNoSuchFileError) {
            // Something unusual, so log.
            NSLog(@"error loading file %@: %@", path, err);
        }
        return nil;
    }
    modDateByPath[path] = modDate;
    return txt;
}

// FIXME: rename so we know this is cached.
- (NSArray<NSString*>*)readFileAsStringArray:(NSString*)path {
    NSString* txt = [self readFileData:path];
    if (txt == nil) {
        return nil;
    }
    NSMutableArray* sl = [NSMutableArray arrayWithCapacity:100];
    for (NSString* s in [txt componentsSeparatedByString:@"\n"]) {
        if (s.length) {
            [sl addObject:s];
        }
    }
    return sl;
}

- (NSDictionary<NSString*, id>*)readFileAsJSON:(NSString*)path {
    NSError* err;
    NSString* txt = [self readFileData:path];
    if (txt == nil) {
        return nil;
    }

    NSDictionary* jsObj = [NSJSONSerialization JSONObjectWithData:[txt dataUsingEncoding:NSUTF8StringEncoding]
                                                          options:0
                                                            error:&err];
    if (err != nil) {
        NSLog(@"error parsing JSON file %@: %@", path, err);
        return nil;
    }
    return jsObj;
}

- (void)exportLogs {
    NSArray* inputs =
        @[self.phrasesFile, self.pronunciationsFile, [self userPath:@"log.jsonl"], [self userPath:@"console.log"]];

    NSString* zipFilePath = [self userPath:@"export.zip"];
    [[NSFileManager defaultManager] removeItemAtPath:zipFilePath error:nil];
    // Create a zip archive using NSTask
    NSTask* task = [[NSTask alloc] init];
    NSString* cmd = @"/usr/bin/zip";
    NSMutableArray* args = [NSMutableArray arrayWithArray:@[@"-j", zipFilePath]];
    [args addObjectsFromArray:inputs];
    [task setLaunchPath:cmd];
    [task setArguments:args];
    [task launch];
    [task waitUntilExit];
    int status = [task terminationStatus];
    if (status != 0) {
        // FIXME: throw an error to show dialog.
        NSLog(@"Task failed: err %d %@ %@", status, cmd, [args componentsJoinedByString:@" "]);
    }
}

- (void)unzipFile:(NSString*)zipFilePath toDirectory:(NSString*)dirPath {
    NSError* err;
    [[NSFileManager defaultManager] removeItemAtPath:dirPath error:&err];
    if (err != nil) {
        NSLog(@"unzip failed: err %@", err);
        return;
    }

    [[NSFileManager defaultManager] createDirectoryAtPath:dirPath
                              withIntermediateDirectories:NO
                                               attributes:nil
                                                    error:&err];
    if (err != nil) {
        NSLog(@"unzip failed: err %@", err);
        return;
    }

    NSTask* task = [[NSTask alloc] init];
    NSString* cmd = @"/usr/bin/unzip";
    NSMutableArray* args = [NSMutableArray arrayWithArray:@[@"-d", dirPath, zipFilePath]];
    [task setLaunchPath:cmd];
    [task setArguments:args];
    [task launch];
    [task waitUntilExit];
    int status = [task terminationStatus];
    if (status != 0) {
        // FIXME: throw an error to show dialog.
        NSLog(@"Task failed: err %d %@ %@", status, cmd, [args componentsJoinedByString:@" "]);
    }
}

- (NSArray<NSString*>*)readDir:(NSString*)path {
    NSError* err;
    NSDate* modDate;
    NSArray<NSString*>* dirList;
    NSDictionary* attr = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:&err];
    if (err == nil) {
        modDate = attr[NSFileModificationDate];
        if ([modDateByPath[path] isEqual:modDate]) {
            return nil;
        }

        dirList = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:&err];
    }
    if (err != nil) {
        if ([err code] != NSFileReadNoSuchFileError) {
            // Something unusual, so log.
            NSLog(@"error reading dir %@: %@", path, err);
        }
        return nil;
    }
    modDateByPath[path] = modDate;
    return dirList;
}

- (void)uploadLogs {
    [self exportLogs];
    [self sendFileWithURL:[NSURL URLWithString:@"https://api.lazybearlabs.com/apps/mavis/upload/export.zip"]
               fileAtPath:[self userPath:@"export.zip"]];
}

- (void)sendFileWithURL:(NSURL*)url fileAtPath:(NSString*)filePath {
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"PUT"];

    NSURLSession* session = [NSURLSession sharedSession];
    NSURLSessionUploadTask* task =
        [session uploadTaskWithRequest:request
                              fromFile:[NSURL fileURLWithPath:filePath]
                     completionHandler:^(NSData* data, NSURLResponse* response, NSError* error) {
                       NSInteger code = ((NSHTTPURLResponse*)response).statusCode;
                       if (error) {
                           NSLog(@"Error sending file: %@", error);
                       } else if (code < 200 || code >= 400) {
                           // FIXME: throw an error to show dialog.
                           NSLog(@"Error sending file: %ld", code);
                       }
                     }];

    [task resume];
}

@end
