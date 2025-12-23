#import "DKSTHanjaDictionary.h"

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
        // Initialize with sample data
        // In a real app, load from a file.
        _dictionary = @{
            @"한": @[@"韓 (한국 한)", @"漢 (한수 한)", @"汗 (땀 한)", @"限 (한할 한)"],
            @"국": @[@"國 (나라 국)", @"局 (판 국)", @"菊 (국화 국)"],
            @"대": @[@"大 (큰 대)", @"代 (대신할 대)", @"待 (기다릴 대)", @"對 (대할 대)"],
            @"한글": @[@"한글 (우리 글자)"],
            @"대한민국": @[@"大韓民國"]
        };
        [_dictionary retain];
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
