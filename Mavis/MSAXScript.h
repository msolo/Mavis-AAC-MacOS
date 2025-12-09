#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>

NS_ASSUME_NONNULL_BEGIN

// Attributes missing from public headers.
#define kAXAttributedDescriptionAttribute CFSTR("AXAttributedDescription")
#define kAXChildrenInNavigationOrderAttributes CFSTR("AXChildrenInNavigationOrder")

@interface MSAXObject : NSObject {
    id ref;
}
+ (MSAXObject*)objWithRef:(AXUIElementRef)_ref;

- (MSAXObject*)initWithRef:(id)ref;
- (NSArray<MSAXObject*>*)asArray;
- (NSString*)asString;
- (AXUIElementRef)asAXElement;
- (CGPoint)toCGPoint;

- (MSAXObject*)getFirstFrom:(CFStringRef)arrayName
               withAttrName:(CFStringRef)name
                     andVal:(NSString*)val
                recursively:(BOOL)recursively;
- (MSAXObject*)getAttrByName:(CFStringRef)name;
- (MSAXObject*)getAttrValueByName:(CFStringRef)name;
- (void)perform:(CFStringRef)action;

@end

@interface MSAXScript : NSObject
+ (void)enableScripting;
+ (MSAXObject*)fromApplicationBundle:(NSString*)ident;
+ (MSAXObject*)from:(MSAXObject*)element getAttrByName:(CFStringRef)name;
+ (MSAXObject*)from:(MSAXObject*)element
       getFirstFrom:(CFStringRef)arrayName
       withAttrName:(CFStringRef)name
             andVal:(NSString*)val
        recursively:(BOOL)recursively;
+ (void)performClickAtPoint:(CGPoint)p;
+ (void)log:(MSAXObject*)element withHint:(NSString*)hint;
+ (void)moveMouseToPoint:(CGPoint)p;
+ (CGPoint)getMousePoint;

@end

NS_ASSUME_NONNULL_END
