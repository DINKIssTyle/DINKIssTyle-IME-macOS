#import "DKSTHanjaDictionary.h"
#import "DKSTConstants.h"

@implementation DKSTHanjaDictionary {
    NSDictionary *_dictionary;
}

+ (instancetype)sharedDictionary {
    static DKSTHanjaDictionary *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[self alloc] init];
    });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        
        // Load from hanja.txt in bundle
        NSString *path = [[NSBundle mainBundle] pathForResource:@"hanja" ofType:@"txt"];
        DKSTLog(@"Loading Hanja dictionary from: %@", path);
        
        if (path) {
            NSError *error = nil;
            NSString *content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
            if (content) {
                NSArray *lines = [content componentsSeparatedByString:@"\n"];
                for (NSString *line in lines) {
                    if ([line length] == 0) continue;
                    
                    // Format: Hangul:Hanja1,Hanja2,...
                    NSArray *parts = [line componentsSeparatedByString:@":"];
                    if ([parts count] == 2) {
                        NSString *key = [parts objectAtIndex:0];
                        NSString *valuesStr = [parts objectAtIndex:1];
                        NSArray *values = [valuesStr componentsSeparatedByString:@","];
                        
                        // Trim whitespace
                        NSMutableArray *trimmedValues = [NSMutableArray array];
                        for (NSString *v in values) {
                            NSString *trimmed = [v stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                            if ([trimmed length] > 0) {
                                [trimmedValues addObject:trimmed];
                            }
                        }
                        
                        if ([trimmedValues count] > 0) {
                            [dict setObject:trimmedValues forKey:key];
                        }
                    }
                }
            } else {
                DKSTLog(@"Failed to read hanja.txt: %@", error);
            }
        }
        
        // Use parsed dictionary, or empty if failed
        _dictionary = [dict copy]; // Helper makes it immutable
        
        // If file load failed or was empty, maybe fallback?
        // For now, let's just log.
        DKSTLog(@"Loaded %lu Hanja entries", (unsigned long)[_dictionary count]);
    }
    return self;
}

- (NSArray *)hanjaForHangul:(NSString *)hangul {
    return [_dictionary objectForKey:hangul];
}

- (void)dealloc {
    [_dictionary release];
    [super dealloc];
}

@end
