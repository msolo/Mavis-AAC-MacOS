#import "MSIsNotEmptyString.h"

@implementation MSIsNotEmptyString

+ (void)initialize {
    [NSValueTransformer setValueTransformer:[[MSIsNotEmptyString alloc] init] forName:@"MSIsNotEmptyString"];
}

+ (Class)transformedValueClass {
    return [NSNumber class];
}

+ (BOOL)allowsReverseTransformation {
    return NO;
}

- (id)transformedValue:(id)value {
    return [NSNumber numberWithBool:![@"" isEqual:value]];
}

@end
