#import "FaceTimeIntegration.h"
#import "MSAXScript.h"

@import AppKit;

@implementation FaceTimeIntegration

NSString* faceTimeBundleId = @"com.apple.FaceTime";

+ (FaceTimeIntegration*)sharedInstance {
    static FaceTimeIntegration* sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (void)startBackground {
    if (backgroundRunning) {
        NSLog(@"Programmer error, duplicate call to background running");
        return;
    }

    activity =
        [[NSBackgroundActivityScheduler alloc] initWithIdentifier:@"com.lazybearlabs.MavisAAC.FaceTimeCallWatcher"];
    activity.repeats = YES;
    activity.qualityOfService = NSOperationQualityOfServiceUserInteractive;
    activity.interval = 15;
    activity.tolerance = 5;

    NSWorkspace* workspace = [NSWorkspace sharedWorkspace];
    NSNotificationCenter* notificationCenter = [workspace notificationCenter];

    [notificationCenter addObserver:self
                           selector:@selector(applicationLaunched:)
                               name:NSWorkspaceDidLaunchApplicationNotification
                             object:nil];

    [notificationCenter addObserver:self
                           selector:@selector(applicationTerminated:)
                               name:NSWorkspaceDidTerminateApplicationNotification
                             object:nil];

    for (NSRunningApplication* app in [workspace runningApplications]) {
        if ([[app bundleIdentifier] isEqual:faceTimeBundleId]) {
            [self faceTimeStarted];
            break;
        }
    }

    backgroundRunning = YES;
}

- (void)faceTimeStarted {
    NSLog(@"facetimeStarted");
    isFaceTimeRunning = YES;

    [activity scheduleWithBlock:^(NSBackgroundActivityCompletionHandler completion) {
      BOOL hasCall = [FaceTimeIntegration hasActiveCall];
      NSLog(@"check for active FaceTime call: %d", hasCall);
      completion(NSBackgroundActivityResultFinished);
    }];
}

- (void)faceTimeEnded {
    NSLog(@"facetimeEnded");
    isFaceTimeRunning = NO;
    [activity invalidate];
}

- (BOOL)isFaceTimeRunning {
    return isFaceTimeRunning;
}

- (void)applicationLaunched:(NSNotification*)notification {
    NSDictionary* userInfo = [notification userInfo];
    NSRunningApplication* app = userInfo[NSWorkspaceApplicationKey];

    if ([[app bundleIdentifier] isEqualToString:faceTimeBundleId]) {
        [self faceTimeStarted];
    }
}

- (void)applicationTerminated:(NSNotification*)notification {
    NSDictionary* userInfo = [notification userInfo];
    NSRunningApplication* app = userInfo[NSWorkspaceApplicationKey];

    if ([[app bundleIdentifier] isEqualToString:faceTimeBundleId]) {
        [self faceTimeEnded];
    }
}

// Click through Control Center when FaceTime is running.
// Initiate window sharing with our special empty window to send
// synthesized audio over FaceTime.
+ (void)startSharePlay:(NSWindow*)sharePlayWindow {
    if (@available(macOS 14, *)) {
        return [FaceTimeIntegration startSharePlayMacOS14:sharePlayWindow];
    }
    return [FaceTimeIntegration startSharePlayMacOS13:sharePlayWindow];
}

+ (void)startSharePlayMacOS14:(NSWindow*)sharePlayWindow {
    NSLog(@"startSharePlay");
    [sharePlayWindow setIsVisible:YES];

    NSURL* url = [[NSBundle mainBundle] URLForResource:@"startSharePlay" withExtension:@"scpt"];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
      NSDictionary* errDict;

      NSAppleScript* script = [[NSAppleScript alloc] initWithContentsOfURL:url error:&errDict];
      if (errDict != nil) {
          NSLog(@"error during startSharePlay: %@", errDict);
      }

      [script executeAndReturnError:&errDict];
      if (errDict != nil) {
          NSLog(@"error during startSharePlay: %@", errDict);
      }
    });
}

+ (void)startSharePlayMacOS13:(NSWindow*)sharePlayWindow {
    @try {
        [sharePlayWindow setIsVisible:YES];

        MSAXObject* ccApp = [MSAXScript fromApplicationBundle:@"com.apple.controlcenter"];

        // get menu bar item and click it to open the window for FaceTime sharing options.
        MSAXObject* menuBar = [ccApp getAttrByName:kAXExtrasMenuBarAttribute];
        if (menuBar == nil) {
            return [FaceTimeIntegration errorAlertWithInfo:@"Unable to get menu bar."];
        }
        MSAXObject* menuBarItem = [menuBar getFirstFrom:kAXVisibleChildrenAttribute
                                           withAttrName:kAXIdentifierAttribute
                                                 andVal:@"com.apple.menuextra.audiovideo"
                                            recursively:NO];
        if (menuBarItem == nil) {
            return [FaceTimeIntegration errorAlertWithInfo:@"Unable to get menu bar item."];
        }
        // Show Control Center for Facetime.
        [menuBarItem perform:kAXPressAction];

        usleep(50 * 1000);

        // Show FaceTime sharing options
        MSAXObject* ccWindow = [ccApp getAttrByName:kAXMainWindowAttribute];
        if (ccWindow == nil) {
            return [FaceTimeIntegration errorAlertWithInfo:@"Unable to get window."];
        }

        MSAXObject* shareButton = [ccWindow getFirstFrom:kAXChildrenAttribute
                                            withAttrName:kAXIdentifierAttribute
                                                  andVal:@"facetime-share-toggle"
                                             recursively:YES];
        if (shareButton == nil) {
            return [FaceTimeIntegration errorAlertWithInfo:@"Unable to get \"SharePlay\" button."];
        }

        [shareButton perform:kAXPressAction];

        usleep(50 * 1000);

        // Select share window
        MSAXObject* shareWindowButton = [ccWindow getFirstFrom:kAXChildrenAttribute
                                                  withAttrName:kAXAttributedDescriptionAttribute
                                                        andVal:@"Window"
                                                   recursively:YES];
        if (shareWindowButton == nil) {
            return [FaceTimeIntegration errorAlertWithInfo:@"Unable to get \"Share Window\" button."];
        }
        [shareWindowButton perform:kAXPressAction];

        usleep(50 * 1000);

        // Bring our special window to the front.
        MSAXObject* mavisApp = [MSAXScript fromApplicationBundle:@"com.lazybearlabs.MavisAAC"];
        MSAXObject* mavisSharePlayWindow = [mavisApp getFirstFrom:kAXWindowsAttribute
                                                     withAttrName:kAXTitleAttribute
                                                           andVal:@"Mavis AAC SharePlay"
                                                      recursively:NO];
        [mavisSharePlayWindow perform:kAXRaiseAction];

        usleep(50 * 1000);

        // This should have been a nicer more reliable way,
        // but I can't seem to traverse the AXGroup element to it's children.
        //        CGPoint mavisWinPos = [[mavisSharePlayWindow getAttrByName:kAXPositionAttribute] toCGPoint];
        //
        //        // Find the window overlapping ours and click the only button in it.
        //        NSArray<MSAXObject*>* ccWindows = [[ccApp getAttrByName:kAXWindowsAttribute] asArray];
        //        for (MSAXObject* win in ccWindows) {
        //            CGPoint p = [[win getAttrByName:kAXPositionAttribute] toCGPoint];
        //            if (CGPointEqualToPoint(mavisWinPos, p)) {
        //                [win perform:kAXRaiseAction];
        //                usleep(100000);
        //
        //                [MSAXScript log:win withHint:@"window overlay"];
        //                MSAXObject* group = [[[win getAttrByName:kAXChildrenInNavigationOrder] asArray] firstObject];
        //                [MSAXScript log:group withHint:@"First child"];
        //
        ////                MSAXObject* groupChild = [group getAttrByName:kAXTopLevelUIElementAttribute];
        //                // kAXChildrenAttribute
        //                MSAXObject* groupChild = [[[group getAttrByName:kAXChildrenInNavigationOrder] asArray]
        //                firstObject]; [MSAXScript log:groupChild withHint:@"group child"];
        //
        ////                MSAXObject* shareThisWindowButton = [win getFirstFrom:kAXChildrenAttribute
        /// withAttrName:kAXAttributedDescription andVal:@"Share This Window" recursively:YES];
        //                MSAXObject* shareThisWindowButton = [win getFirstFrom:kAXChildrenInNavigationOrder
        //                withAttrName:kAXRoleAttribute andVal:(NSString*)kAXButtonRole recursively:YES];
        //
        //                [MSAXScript log:shareThisWindowButton withHint:@"window overlay button"];
        //
        //                [shareThisWindowButton perform:kAXPressAction];
        //                break;
        //            }
        //        }

        NSPoint userMousePos = [MSAXScript getMousePoint];

        // Emulate a couple of clicks in the title bar of our window.
        // We need a very basic click so that Control Center or whatever draws the
        // window selection highlight can intercept the click.
        CGPoint p = [[mavisSharePlayWindow getAttrByName:(CFStringRef) @"AXActivationPoint"] toCGPoint];

        // Fake a bit of drag, otherwise the window doesn't notice it's being selected.
        [MSAXScript performClickAtPoint:p];
        usleep(50 * 100);
        p.x++;
        [MSAXScript performClickAtPoint:p];

        usleep(100 * 100);

        // Close Control Center.
        [menuBarItem perform:kAXPressAction];
        // Reset mouse to original position.
        [MSAXScript moveMouseToPoint:userMousePos];
    } @catch (NSException* exception) {
        NSLog(@"exception during startSharePlay %@", exception);
    }
}

+ (void)stopSharePlay:(NSWindow*)sharePlayWindow {
    NSLog(@"stopSharePlay");
    [sharePlayWindow setIsVisible:NO];
}

// FIXME: this should be reflected in the app delegate and used to disable menu item.
// FIXME: this is just not reliable enough, the heuristics are very weak.
+ (BOOL)hasActiveCall {
    int pid = [FaceTimeIntegration pidForProcessWithName:@"avconferenced"];
    if (pid) {
        float cpuPct = [FaceTimeIntegration cpuUsageForProcessWithPID:pid];
        if (cpuPct > 10.0) {
            return YES;
        }
    }
    return NO;
}

+ (int)pidForProcessWithBundleIdentifier:(NSString*)bundleIdentifier {
    NSWorkspace* workspace = [NSWorkspace sharedWorkspace];
    NSArray* runningApps = [workspace runningApplications];

    // Iterate through the running applications
    for (NSRunningApplication* app in runningApps) {
        // Check if the bundle identifier matches
        if ([[app bundleIdentifier] isEqualToString:bundleIdentifier]) {
            return [app processIdentifier];
        }
    }
    return 0;
}

+ (int)pidForProcessWithName:(NSString*)name {
    NSTask* task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/pgrep";
    task.arguments = @[name];

    // Create a pipe to capture the output
    NSPipe* pipe = [NSPipe pipe];
    task.standardOutput = pipe;

    // Launch the task
    [task launch];

    // Read the output
    NSFileHandle* file = [pipe fileHandleForReading];
    NSData* data = [file readDataToEndOfFile];
    [task waitUntilExit];

    // Convert the output to a string
    NSString* output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

    // Split the output into lines
    NSArray* lines = [output componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];

    // The first line is the header, the second line is the CPU usage value
    if ([lines count] > 0) {
        NSString* pid = lines[0];
        return [[pid stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] intValue];
    }

    return 0;
}

+ (float)cpuUsageForProcessWithPID:(int)pid {
    NSTask* task = [[NSTask alloc] init];
    task.launchPath = @"/bin/ps";
    task.arguments = @[@"-p", [NSString stringWithFormat:@"%d", pid], @"-o", @"%cpu"];

    // Create a pipe to capture the output
    NSPipe* pipe = [NSPipe pipe];
    task.standardOutput = pipe;

    // Launch the task
    [task launch];

    // Read the output
    NSFileHandle* file = [pipe fileHandleForReading];
    NSData* data = [file readDataToEndOfFile];
    [task waitUntilExit];

    // Convert the output to a string
    NSString* output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

    // Split the output into lines
    NSArray* lines = [output componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];

    // The first line is the header, the second line is the CPU usage value
    if ([lines count] > 1) {
        NSString* cpuUsage = lines[1];
        return [[cpuUsage stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] floatValue];
    }

    return 0.0;
}

+ (void)errorAlertWithInfo:(NSString*)info {
    NSAlert* alert = [[NSAlert alloc] init];
    NSString* msg = @"FaceTime Scripting Error";
    alert.messageText = msg;
    alert.informativeText = info;
    [alert addButtonWithTitle:@"OK"];
    NSLog(@"%@: %@", msg, info);
    [alert runModal];
}

@end
