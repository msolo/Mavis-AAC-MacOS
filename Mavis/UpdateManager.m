#import "UpdateManager.h"
@import AppKit;

@implementation UpdateManager

+ (NSComparisonResult)compareVersion:(NSString*)va withVersion:(NSString*)vb {
    va = [va stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    vb = [vb stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    NSMutableArray<NSString*>* vat = [[va componentsSeparatedByString:@"."] mutableCopy];
    NSMutableArray<NSString*>* vbt = [[vb componentsSeparatedByString:@"."] mutableCopy];
    NSInteger maxL = MAX(vat.count, vbt.count);
    while (vat.count < maxL) {
        [vat addObject:@"0"];
    }
    while (vbt.count < maxL) {
        [vbt addObject:@"0"];
    }
    for (int i = 0; i < maxL; i++) {
        NSInteger a = vat[i].integerValue;
        NSInteger b = vbt[i].integerValue;
        if (a < b) {
            return NSOrderedAscending;
        }
        if (a > b) {
            return NSOrderedDescending;
        }
    }
    return NSOrderedSame;
}

+ (void)updateCheckAgainstPublishedVersion:(NSString*)publishedVersion notifyAlways:(BOOL)notifyAlways {
    NSDictionary* infoDictionary = [[NSBundle mainBundle] infoDictionary];
    NSString* clientVersion = infoDictionary[@"CFBundleShortVersionString"];

    BOOL needsUpdate = ([UpdateManager compareVersion:clientVersion
                                          withVersion:publishedVersion] == NSOrderedAscending);
    if (!needsUpdate) {
        if (notifyAlways) {
            dispatch_async(dispatch_get_main_queue(), ^{
              NSAlert* alert = [[NSAlert alloc] init];
              [alert setAlertStyle:NSAlertStyleInformational];
              [alert setMessageText:@"No new update for Mavis AAC."];
              [alert setInformativeText:[NSString stringWithFormat:@"Version %@", clientVersion]];
              [alert addButtonWithTitle:@"Cancel"];
              [alert runModal];
            });
        }
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
      NSAlert* alert = [[NSAlert alloc] init];
      [alert setAlertStyle:NSAlertStyleInformational];
      [alert setMessageText:@"There is a new update for Mavis AAC!"];
      [alert setInformativeText:[NSString stringWithFormat:@"Version %@", publishedVersion]];
      [alert addButtonWithTitle:@"Cancel"];
      [alert addButtonWithTitle:@"Download"];

      NSInteger button = [alert runModal];
      NSString* s =
          [NSString stringWithFormat:@"https://github.com/msolo/Mavis/releases/latest/Mavis-%@.zip", publishedVersion];
      NSURL* dlUrl = [NSURL URLWithString:s];
      if (button == NSAlertSecondButtonReturn) {
          [[NSWorkspace sharedWorkspace] openURL:dlUrl];
      }
    });
}

+ (void)scheduleUpdateCheck:(BOOL)showNoUpdate {
    NSURLSession* session = [NSURLSession sharedSession];
    NSURL* url = [NSURL URLWithString:@"https://lazybearlabs.com/apps/mavis-aac/macos/version.txt"];
    NSURLSessionDataTask* dataTask =
        [session dataTaskWithURL:url
               completionHandler:^(NSData* data, NSURLResponse* response, NSError* error) {
                 if (error) {
                     NSLog(@"scheduleUpdateCheck error: %@", error);
                     return;
                 }

                 if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
                     NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)response;
                     if (httpResponse.statusCode != 200) {
                         error = [NSError errorWithDomain:@"HTTPError" code:httpResponse.statusCode userInfo:nil];
                         NSLog(@"scheduleUpdateCheck error: %@", error);
                         return;
                     }
                 }

                 if (!data) {
                     error = [NSError errorWithDomain:@"NoDataError" code:0 userInfo:nil];
                     NSLog(@"scheduleUpdateCheck error: %@", error);
                     return;
                 }
                 NSString* publishedVersion = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

                 [self updateCheckAgainstPublishedVersion:publishedVersion notifyAlways:showNoUpdate];
               }];

    [dataTask resume];
}

@end
