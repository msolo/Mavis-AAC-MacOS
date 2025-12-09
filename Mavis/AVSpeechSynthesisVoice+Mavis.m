#import "AVSpeechSynthesisVoice+Mavis.h"

@implementation AVSpeechSynthesisVoice (Mavis)

// Some voices have names, some don't.
// Most have a "name" as the last component of the ID. Interns?
- (NSString*)mvs_uiName {
    if (self.name.length > 0) {
        return self.name;
    }
    return [self.identifier componentsSeparatedByString:@"."].lastObject;
}

@end
