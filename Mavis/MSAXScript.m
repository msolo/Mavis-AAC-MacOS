#import "MSAXScript.h"

// Quick and dirty interface to scripting AX compontents.
@implementation MSAXObject

- (MSAXObject*)initWithRef:(id)_ref {
    ref = _ref;
    return self;
}

+ (MSAXObject*)objWithRef:(AXUIElementRef)_ref {
    return [[MSAXObject alloc] initWithRef:(__bridge id)_ref];
}

- (NSArray*)asArray {
    NSArray* refs = (NSArray*)ref;
    NSMutableArray* oRefs = [NSMutableArray arrayWithCapacity:refs.count];
    for (id ref in refs) {
        [oRefs addObject:[[MSAXObject alloc] initWithRef:ref]];
    }
    return oRefs;
}

- (NSString*)asString {
    return (NSString*)ref;
}

- (AXUIElementRef)asAXElement {
    return (__bridge AXUIElementRef)ref;
}

- (NSString*)description {
    if (ref != nil) {
        return [NSString stringWithFormat:@"MSAX ref %@", [ref description]];
    }
    return [NSString stringWithFormat:@"MSAX ref nil"];
}

- (CGPoint)toCGPoint {
    CGPoint p;
    AXValueGetValue((AXValueRef)ref, kAXValueTypeCGPoint, &p);
    return p;
}

- (MSAXObject*)getFirstFrom:(CFStringRef)arrayName
               withAttrName:(CFStringRef)name
                     andVal:(NSString*)val
                recursively:(BOOL)recursively {
    return [MSAXScript from:self getFirstFrom:arrayName withAttrName:name andVal:val recursively:recursively];
}

- (MSAXObject*)getAttrByName:(CFStringRef)name {
    id val = [MSAXScript from:self getAttrByName:name];
    return val;
}

- (NSArray*)getAttrNames {
    CFArrayRef names;
    AXError err = AXUIElementCopyAttributeNames([self asAXElement], &names);
    if (err != kAXErrorSuccess && err != kAXErrorNoValue) {
        NSLog(@"error fetching names on element %@", self);
        return nil;
    }
    return (__bridge NSArray*)names;
}
- (void)perform:(CFStringRef)action {
    AXError err = AXUIElementPerformAction([self asAXElement], action);
    if (err != kAXErrorSuccess) {
        NSLog(@"error performing action %@ on element %@: err %d", action, self, err);
    }
}

- (MSAXObject*)getAttrValueByName:(CFStringRef)name {
    AXUIElementRef val = NULL;
    AXUIElementCopyAttributeValue([self asAXElement], name, (CFTypeRef*)&val);
    return [MSAXObject objWithRef:val];
}

@end

@implementation MSAXScript

+ (void)enableScripting {
    NSDictionary* options = @{(__bridge NSString*)kAXTrustedCheckOptionPrompt: @YES};
    BOOL accessEnabled = AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options);
    if (!accessEnabled) {
        NSLog(@"Scripting access not enabled");
    } else {
        NSLog(@"Scripting access granted");
    }
}

+ (MSAXObject*)fromApplicationBundle:(NSString*)ident {
    NSRunningApplication* app = [[NSRunningApplication runningApplicationsWithBundleIdentifier:ident] firstObject];
    AXUIElementRef axApp = AXUIElementCreateApplication(app.processIdentifier);
    return [MSAXObject objWithRef:axApp];
}

+ (MSAXObject*)from:(MSAXObject*)element getAttrByName:(CFStringRef)name {
    CFTypeRef attr;
    AXError err = AXUIElementCopyAttributeValue([element asAXElement], name, &attr);
    if (err != kAXErrorSuccess && err != kAXErrorNoValue && err != kAXErrorAttributeUnsupported) {
        NSLog(@"error %d fetching attr %@ on element %@", err, name, element);
        return nil;
    }
    return [MSAXObject objWithRef:attr];
}

+ (MSAXObject*)from:(MSAXObject*)element
       getFirstFrom:(CFStringRef)arrayName
       withAttrName:(CFStringRef)name
             andVal:(NSString*)val
        recursively:(BOOL)recursively {
    NSArray<MSAXObject*>* el = [[MSAXScript from:element getAttrByName:arrayName] asArray];
    //    NSLog(@"get array %@ %@", arrayName, [el componentsJoinedByString:@", "]);
    for (MSAXObject* axEl in el) {
        MSAXObject* axVal = [axEl getAttrByName:name];
        NSString* strVal = [axVal asString];
        // Special case NSAttributedString
        if ([((__bridge NSString*)name) isEqual:@"AXAttributedDescription"]) {
            strVal = [(NSAttributedString*)strVal string];
        }

        if ([strVal isEqual:val]) {
            return axEl;
        }
        if (recursively) {
            id rEl = [MSAXScript from:axEl getFirstFrom:arrayName withAttrName:name andVal:val recursively:recursively];
            if (rEl != nil) {
                return rEl;
            }
        }
    }
    return nil;
}

+ (void)log:(MSAXObject*)element withHint:(NSString*)hint {
    id attrRole = [element getAttrByName:kAXRoleAttribute];
    id attrId = [element getAttrByName:kAXIdentifierAttribute];
    id attrTitle = [element getAttrByName:kAXTitleAttribute];
    id attrDesc = [element getAttrByName:kAXDescriptionAttribute];
    id attrAttributedDesc = [element getAttrByName:(CFStringRef) @"AXAttributedDescription"];
    NSArray* names = [element getAttrNames];
    NSLog(@"log element %@: %@ role:%@ id:%@ title:%@ desc:%@ attrDesc:%@", hint, element, attrRole, attrId, attrTitle,
          attrDesc, attrAttributedDesc);
    NSLog(@"names: %@", [names componentsJoinedByString:@", "]);
}

+ (void)performClickAtPoint:(CGPoint)p {
    // Left button down
    CGEventRef leftDown = CGEventCreateMouseEvent(NULL, kCGEventLeftMouseDown, p, kCGMouseButtonLeft);
    CGEventPost(kCGHIDEventTap, leftDown);
    CFRelease(leftDown);

    usleep(15000); // Improve reliability

    // Left button up
    CGEventRef leftUp = CGEventCreateMouseEvent(NULL, kCGEventLeftMouseUp, p, kCGMouseButtonLeft);
    CGEventPost(kCGHIDEventTap, leftUp);
    CFRelease(leftUp);
}

+ (void)moveMouseToPoint:(CGPoint)p {
    // Left button down
    CGEventRef leftDown = CGEventCreateMouseEvent(NULL, kCGEventMouseMoved, p, 0);
    CGEventPost(kCGHIDEventTap, leftDown);
    CFRelease(leftDown);
}

+ (CGPoint)getMousePoint {
    CGEventRef ourEvent = CGEventCreate(NULL);
    CGPoint point = CGEventGetLocation(ourEvent);
    CFRelease(ourEvent);
    return point;
}
@end
