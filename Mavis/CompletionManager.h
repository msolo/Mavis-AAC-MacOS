#import "MSJSONRPCClient.h"
#import "MSJSONRPCProcess.h"
#import "MSTextView.h"
#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface CompletionManager : NSObject <NSTableViewDataSource> {
    MSJSONRPCProcess* _nlpProc;
    MSJSONRPCClient* _nlpClient;

    NSArray<NSAttributedString*>* attributedCompletions;
    MSTextView* textView;
    NSString* originalText;
    NSRange originalRange;     // what was the original span of completing words?
    NSRange originalSelection; // where was the carat when we started?

    IBOutlet NSTableView* tableView;
    IBOutlet NSWindow* window;
}

@property NSArray<NSString*>* phrases;

- (void)logString:(NSString*)s withInputKeystrokes:(NSString*)keystrokes withAnnotations:(NSDictionary*)dict;

+ (NSArray<NSString*>*)tokenizeText:(NSString*)text;
+ (NSArray<NSString*>*)tokenizeIntoWords:(NSString*)string;

- (NSArray<NSAttributedString*>*)completions:(NSArray<NSString*>*)words
                            forPartialString:(NSString*)str
                                 withContext:(NSString*)context;
- (void)showCompletions:(MSTextView*)textView;

- (IBAction)accept:(id)sender;
- (IBAction)cancel:(id)sender;

@end

NS_ASSUME_NONNULL_END
