#import <Foundation/Foundation.h>

@interface DKSTHanjaDictionary : NSObject

+ (instancetype)sharedDictionary;
- (NSArray *)hanjaForHangul:(NSString *)hangul;

@end
