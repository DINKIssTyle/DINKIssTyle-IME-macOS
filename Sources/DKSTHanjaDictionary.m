#import "DKSTHanjaDictionary.h"
#import "DKSTConstants.h"
#import <dlfcn.h>

typedef const void *DKSTIDXIndexRef;
typedef void (*DKSTIDXHitCallback)(DKSTIDXIndexRef index,
                                   const UInt8 *recordData, long recordLength,
                                   UInt8 recordType, void *context);
typedef DKSTIDXIndexRef (*DKSTIDXCreateIndexObjectFunc)(CFAllocatorRef allocator,
                                                        CFURLRef url,
                                                        CFStringRef name);
typedef void (*DKSTIDXSetSearchStringFunc)(DKSTIDXIndexRef index,
                                           CFStringRef searchString,
                                           CFStringRef searchType);
typedef void (*DKSTIDXPerformSearchFunc)(DKSTIDXIndexRef index,
                                         DKSTIDXHitCallback callback,
                                         void *context);

static void DKSTAppleHanjaHitCallback(DKSTIDXIndexRef index,
                                      const UInt8 *recordData,
                                      long recordLength, UInt8 recordType,
                                      void *context) {
    if (!recordData || recordLength <= 0 || !context) {
        return;
    }

    CFStringRef candidate = CFStringCreateWithBytes(
        kCFAllocatorDefault, recordData, recordLength, kCFStringEncodingUTF16BE,
        false);
    if (!candidate) {
        return;
    }

    [(NSMutableArray *)context addObject:(NSString *)candidate];
    CFRelease(candidate);
}

@interface DKSTHanjaDictionary ()
- (NSDictionary *)dictionaryFromBundledHanjaFileWithLogPrefix:(NSString *)prefix;
- (BOOL)appleHanjaDictionaryEnabled;
- (NSArray *)appleHanjaForHangul:(NSString *)hangul;
- (NSArray *)appleRawMatchesForSearchString:(NSString *)searchString;
- (NSString *)appleAnnotationForCandidate:(NSString *)candidate
                             sourceHangul:(NSString *)sourceHangul;
- (NSString *)formattedAppleCandidate:(NSString *)candidate
                          sourceHangul:(NSString *)sourceHangul;
- (BOOL)openAppleHanjaDictionaryIfNeeded;
@end

@implementation DKSTHanjaDictionary {
    NSDictionary *_dictionary;
    void *_dictionaryServicesHandle;
    DKSTIDXIndexRef _appleHanjaIndex;
    DKSTIDXCreateIndexObjectFunc _IDXCreateIndexObject;
    DKSTIDXSetSearchStringFunc _IDXSetSearchString;
    DKSTIDXPerformSearchFunc _IDXPerformSearch;
    CFStringRef _IDXSearchExactMatch;
    BOOL _triedAppleHanjaDictionary;
    NSCache *_appleRawMatchCache;
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
        _dictionary =
            [[self dictionaryFromBundledHanjaFileWithLogPrefix:@"Loading"] retain];
        _appleRawMatchCache = [[NSCache alloc] init];
        [_appleRawMatchCache setCountLimit:500];

        DKSTLog(@"Loaded %lu Hanja entries", (unsigned long)[_dictionary count]);
    }
    return self;
}

- (void)reloadDictionary {
    DKSTLog(@"Reloading Hanja dictionary...");
    NSDictionary *dict =
        [self dictionaryFromBundledHanjaFileWithLogPrefix:@"Reloading"];
    NSDictionary *oldDict = _dictionary;
    _dictionary = [dict retain];
    [oldDict release];
    [_appleRawMatchCache removeAllObjects];
    DKSTLog(@"Reloaded %lu Hanja entries", (unsigned long)[_dictionary count]);
}

- (NSDictionary *)dictionaryFromBundledHanjaFileWithLogPrefix:(NSString *)prefix {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    NSString *path =
        [[NSBundle bundleForClass:[self class]] pathForResource:@"hanja" ofType:@"txt"];
    DKSTLog(@"%@ Hanja dictionary from: %@", prefix, path);

    if (path) {
        NSError *error = nil;
        NSString *content = [NSString stringWithContentsOfFile:path
                                                     encoding:NSUTF8StringEncoding
                                                        error:&error];
        if (content) {
            NSArray *lines = [content componentsSeparatedByString:@"\n"];
            for (NSString *line in lines) {
                if ([line length] == 0)
                    continue;
                NSRange colonRange = [line rangeOfString:@":"];
                if (colonRange.location != NSNotFound) {
                    NSString *key = [line substringToIndex:colonRange.location];
                    NSString *valuesStr = [line substringFromIndex:colonRange.location + 1];
                    NSArray *values =
                        [valuesStr componentsSeparatedByString:@","];
                    NSMutableArray *trimmedValues = [NSMutableArray array];
                    for (NSString *v in values) {
                        NSString *trimmed = [v
                            stringByTrimmingCharactersInSet:
                                [NSCharacterSet whitespaceCharacterSet]];
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

    return [[dict copy] autorelease];
}

- (NSArray *)hanjaForHangul:(NSString *)hangul {
    NSArray *localCandidates = [_dictionary objectForKey:hangul];
    if (![self appleHanjaDictionaryEnabled]) {
        return localCandidates;
    }

    NSArray *appleCandidates = [self appleHanjaForHangul:hangul];
    if ([appleCandidates count] == 0) {
        return localCandidates;
    }

    NSMutableArray *merged = [NSMutableArray array];
    NSMutableSet *seenCandidates = [NSMutableSet set];
    for (NSString *candidate in localCandidates) {
        if ([candidate length] > 0 && ![seenCandidates containsObject:candidate]) {
            [merged addObject:candidate];
            [seenCandidates addObject:candidate];
        }
    }
    for (NSString *candidate in appleCandidates) {
        if ([candidate length] > 0 && ![seenCandidates containsObject:candidate]) {
            [merged addObject:candidate];
            [seenCandidates addObject:candidate];
        }
    }
    return merged;
}

- (BOOL)appleHanjaDictionaryEnabled {
    NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];
    if ([standardDefaults objectForKey:kDKSTUseAppleHanjaDictionaryKey]) {
        return [standardDefaults boolForKey:kDKSTUseAppleHanjaDictionaryKey];
    }

    static NSUserDefaults *suiteDefaults = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        suiteDefaults = [[NSUserDefaults alloc] initWithSuiteName:kDKSTBundleID];
    });
    if ([suiteDefaults objectForKey:kDKSTUseAppleHanjaDictionaryKey]) {
        return [suiteDefaults boolForKey:kDKSTUseAppleHanjaDictionaryKey];
    }
    return YES;
}

- (NSArray *)appleHanjaForHangul:(NSString *)hangul {
    NSArray *rawCandidates = [self appleRawMatchesForSearchString:hangul];
    if ([rawCandidates count] == 0) {
        return nil;
    }

    NSMutableArray *formattedCandidates = [NSMutableArray array];
    NSMutableSet *seenCandidates = [NSMutableSet set];
    for (NSString *candidate in rawCandidates) {
        NSString *formatted = [self formattedAppleCandidate:candidate
                                               sourceHangul:hangul];
        if ([formatted length] > 0 && ![seenCandidates containsObject:formatted]) {
            [formattedCandidates addObject:formatted];
            [seenCandidates addObject:formatted];
        }
    }
    return formattedCandidates;
}

- (NSArray *)appleRawMatchesForSearchString:(NSString *)searchString {
    if ([searchString length] == 0 || ![self openAppleHanjaDictionaryIfNeeded]) {
        return nil;
    }

    NSArray *cachedResults = [_appleRawMatchCache objectForKey:searchString];
    if (cachedResults) {
        return cachedResults;
    }

    NSMutableArray *results = [NSMutableArray array];
    @try {
        _IDXSetSearchString(_appleHanjaIndex, (CFStringRef)searchString,
                            _IDXSearchExactMatch);
        _IDXPerformSearch(_appleHanjaIndex, DKSTAppleHanjaHitCallback, results);
    } @catch (NSException *exception) {
        DKSTLog(@"Apple Hanja lookup failed: %@", exception);
    }
    NSArray *immutableResults = [[results copy] autorelease];
    [_appleRawMatchCache setObject:immutableResults forKey:searchString];
    return immutableResults;
}

- (NSString *)appleAnnotationForCandidate:(NSString *)candidate
                             sourceHangul:(NSString *)sourceHangul {
    NSArray *definitions = [self appleRawMatchesForSearchString:candidate];
    if ([definitions count] == 0) {
        return sourceHangul;
    }

    NSString *definition = [definitions objectAtIndex:0];
    NSMutableArray *annotations = [NSMutableArray array];
    NSString *sourceMarker =
        [NSString stringWithFormat:@"<%@>", sourceHangul ? sourceHangul : @""];

    for (NSString *component in
         [definition componentsSeparatedByString:@", "]) {
        NSString *cleaned =
            [[component stringByReplacingOccurrencesOfString:sourceMarker
                                                  withString:@""]
                stringByTrimmingCharactersInSet:
                    [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        cleaned = [cleaned stringByReplacingOccurrencesOfString:@"<[^>]*>"
                                                     withString:@""
                                                        options:NSRegularExpressionSearch
                                                          range:NSMakeRange(0, [cleaned length])];
        cleaned = [cleaned stringByTrimmingCharactersInSet:
                               [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([cleaned length] > 0 && ![annotations containsObject:cleaned]) {
            [annotations addObject:cleaned];
        }
    }

    if ([annotations count] == 0) {
        return sourceHangul;
    }
    return [annotations componentsJoinedByString:@", "];
}

- (NSString *)formattedAppleCandidate:(NSString *)candidate
                          sourceHangul:(NSString *)sourceHangul {
    if ([candidate length] == 0) {
        return nil;
    }

    NSString *annotation = [self appleAnnotationForCandidate:candidate
                                               sourceHangul:sourceHangul];
    if ([annotation length] == 0 || [annotation isEqualToString:candidate]) {
        return candidate;
    }
    return [NSString stringWithFormat:@"%@ %@", candidate, annotation];
}

- (BOOL)openAppleHanjaDictionaryIfNeeded {
    if (_appleHanjaIndex) {
        return YES;
    }
    if (_triedAppleHanjaDictionary) {
        return NO;
    }
    _triedAppleHanjaDictionary = YES;

    _dictionaryServicesHandle = dlopen(
        "/System/Library/Frameworks/CoreServices.framework/Frameworks/"
        "DictionaryServices.framework/DictionaryServices",
        RTLD_LAZY | RTLD_LOCAL);
    if (!_dictionaryServicesHandle) {
        DKSTLog(@"DictionaryServices unavailable: %s", dlerror());
        return NO;
    }

    _IDXCreateIndexObject = (DKSTIDXCreateIndexObjectFunc)dlsym(
        _dictionaryServicesHandle, "IDXCreateIndexObject");
    _IDXSetSearchString = (DKSTIDXSetSearchStringFunc)dlsym(
        _dictionaryServicesHandle, "IDXSetSearchString");
    _IDXPerformSearch = (DKSTIDXPerformSearchFunc)dlsym(
        _dictionaryServicesHandle, "IDXPerformSearch");
    CFStringRef *exactMatchPtr =
        (CFStringRef *)dlsym(_dictionaryServicesHandle, "kIDXSearchExactMatch");

    if (!_IDXCreateIndexObject || !_IDXSetSearchString || !_IDXPerformSearch ||
        !exactMatchPtr || !*exactMatchPtr) {
        DKSTLog(@"DictionaryServices IDX symbols unavailable");
        return NO;
    }
    _IDXSearchExactMatch = *exactMatchPtr;

    NSString *dictionaryPath = @"/System/Library/Input Methods/KoreanIM.app/Contents/PlugIns/KIM_Extension.appex/Contents/Resources/HanjaTool.app/Contents/Resources/KoreanSystemDictionary.dictionary";
    if (![[NSFileManager defaultManager] fileExistsAtPath:dictionaryPath]) {
        DKSTLog(@"Apple Hanja dictionary not found at %@", dictionaryPath);
        return NO;
    }

    NSURL *dictionaryURL = [NSURL fileURLWithPath:dictionaryPath isDirectory:YES];
    _appleHanjaIndex =
        _IDXCreateIndexObject(kCFAllocatorDefault, (CFURLRef)dictionaryURL, NULL);
    if (!_appleHanjaIndex) {
        DKSTLog(@"Failed to open Apple Hanja dictionary");
        return NO;
    }

    DKSTLog(@"Apple Hanja dictionary opened");
    return YES;
}

- (void)dealloc {
    if (_appleHanjaIndex) {
        CFRelease(_appleHanjaIndex);
        _appleHanjaIndex = NULL;
    }
    if (_dictionaryServicesHandle) {
        dlclose(_dictionaryServicesHandle);
        _dictionaryServicesHandle = NULL;
    }
    [_dictionary release];
    [_appleRawMatchCache release];
    [super dealloc];
}

@end
