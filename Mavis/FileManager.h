#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FileManager : NSObject {
    NSMutableDictionary* modDateByPath;
}

+ (FileManager*)sharedInstance;

- (NSString*)phrasesFile;
- (NSString*)pronunciationsFile;
- (NSString*)properNounsFile;

- (NSString*)userPath:(NSString*)s;

- (NSString*)readFileData:(NSString*)path;
- (NSArray<NSString*>*)readFileAsStringArray:(NSString*)path;
- (NSDictionary<NSString*, id>*)readFileAsJSON:(NSString*)path;

- (NSArray*)readDir:(NSString*)dirPath;

- (void)exportLogs;
- (void)uploadLogs;

@end

NS_ASSUME_NONNULL_END
