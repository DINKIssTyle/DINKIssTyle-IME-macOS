#import <Foundation/Foundation.h>

@interface DKSTHanjaDictionary : NSObject

+ (instancetype)sharedDictionary;
- (NSArray *)hanjaForHangul:(NSString *)hangul;
- (NSString *)insertionTextForCandidate:(NSString *)candidate sourceHangul:(NSString *)hangul;
+ (NSString *)insertionTextForLocalCandidate:(NSString *)candidate;
- (void)reloadDictionary;

@end
