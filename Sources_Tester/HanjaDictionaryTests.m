#import "../Sources/InputController+Private.h"
#import "../Sources/DKSTHanjaDictionary.h"
#import <objc/runtime.h>

static void Assert(BOOL condition, NSString *message) {
  if (!condition) { NSLog(@"FAIL: %@", message); exit(1); }
}

@interface DKSTHanjaDictionary (TestNotification)
- (void)dictionaryDidChange:(NSNotification *)notification;
@end
@interface FixtureDictionary : DKSTHanjaDictionary
@property NSUInteger reloadCount;
@end
@implementation FixtureDictionary
- (NSDictionary *)dictionaryFromBundledHanjaFileWithLogPrefix:(NSString *)prefix {
  return @{@"인사": @[@"안녕하세요 반갑습니다", @"( ͡° ice ͡°)",
                       @"ᄒᆞᆫ글 (아래아한글)", @"여러 단어 (설명 (중첩))"],
           @"원문 (설명)": @[@"원문 (설명)"]};
}
- (BOOL)appleHanjaDictionaryEnabled { return YES; }
- (NSArray *)appleRawMatchesForSearchString:(NSString *)source {
  return [source isEqualToString:@"한"] ? @[@"漢", @"raw with spaces"] : @[];
}
- (NSString *)appleAnnotationForCandidate:(NSString *)candidate sourceHangul:(NSString *)source {
  return @"한";
}
- (void)reloadDictionary { self.reloadCount++; [super reloadDictionary]; }
@end

static FixtureDictionary *fixture;
static id FixtureSharedDictionary(id object, SEL selector) { return fixture; }

@interface CandidatePanel : NSObject
@end
@implementation CandidatePanel
- (void)updateCandidates {}
- (void)show:(NSInteger)hint {}
- (NSInteger)candidateIdentifierAtLineNumber:(NSInteger)line { return NSNotFound; }
- (void)hide {}
@end

@interface CandidateClient : NSObject
@property(nonatomic, copy) NSString *inserted;
@end
@implementation CandidateClient
- (void)insertText:(id)value replacementRange:(NSRange)range {
  Assert(NSEqualRanges(range, NSMakeRange(0, 2)), @"candidate replacement lost its original range");
  self.inserted = value;
}
- (void)dealloc { [_inserted release]; [super dealloc]; }
@end

@interface CandidateController : InputController
- (id)initWithPanel:(id)panel;
@end
@implementation CandidateController
- (id)initWithPanel:(id)panel {
  if ((self = [super init])) {
    engine = [[DKSTHangul alloc] init];
    _compositionState = [[DKSTCompositionState alloc] init];
    _markedTextCommittedPrefix = [[NSMutableString alloc] init];
    _candidates = panel;
    _directInputComposedRange = NSMakeRange(NSNotFound, 0);
    _markedReplacementRange = NSMakeRange(NSNotFound, 0);
  }
  return self;
}
@end

int main(void) {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  fixture = [[FixtureDictionary alloc] init];
  NSArray *local = [fixture hanjaForHangul:@"인사"];
  Assert([[fixture insertionTextForCandidate:local[0] sourceHangul:@"인사"]
      isEqualToString:@"안녕하세요 반갑습니다"], @"phrase was truncated");
  Assert([[fixture insertionTextForCandidate:local[1] sourceHangul:@"인사"]
      isEqualToString:@"( ͡° ice ͡°)"], @"emoticon was truncated");
  Assert([[fixture insertionTextForCandidate:local[2] sourceHangul:@"인사"]
      isEqualToString:@"ᄒᆞᆫ글"], @"legacy annotation was inserted as text");
  Assert([[fixture insertionTextForCandidate:local[3] sourceHangul:@"인사"]
      isEqualToString:@"여러 단어"], @"nested legacy annotation was not removed");
  Assert([[DKSTHanjaDictionary insertionTextForLocalCandidate:@"value (literal) suffix"]
      isEqualToString:@"value (literal) suffix"], @"non-annotation parentheses were removed");
  Assert([[DKSTHanjaDictionary insertionTextForLocalCandidate:@"value (unclosed"]
      isEqualToString:@"value (unclosed"], @"unclosed parentheses were removed");
  NSArray *apple = [fixture hanjaForHangul:@"한"];
  Assert([[fixture insertionTextForCandidate:apple[0] sourceHangul:@"한"] isEqualToString:@"漢"],
      @"Apple annotation was inserted");
  Assert([[fixture insertionTextForCandidate:apple[1] sourceHangul:@"한"] isEqualToString:@"raw with spaces"],
      @"Apple insertion value with spaces was truncated");

  Method method = class_getClassMethod([DKSTHanjaDictionary class], @selector(sharedDictionary));
  IMP original = method_setImplementation(method, (IMP)FixtureSharedDictionary);
  CandidatePanel *panel = [[[CandidatePanel alloc] init] autorelease];
  CandidateClient *client = [[[CandidateClient alloc] init] autorelease];
  CandidateController *controller = [[[CandidateController alloc] initWithPanel:panel] autorelease];
  for (NSString *display in local) {
    NSString *expected = [fixture insertionTextForCandidate:display sourceHangul:@"인사"];
    Assert([controller showHanjaCandidatesForText:@"인사" replacementRange:NSMakeRange(0, 2) client:client],
        @"candidate list did not open");
    // A later lookup/reload must not destroy insertion metadata of an already
    // displayed candidate list. The controller owns a stable snapshot.
    [fixture reloadDictionary];
    [controller commitCandidate:display client:client];
    Assert([client.inserted isEqualToString:expected], @"candidate selection changed its insertion value");
  }
  Assert([controller showHanjaCandidatesForText:@"한" replacementRange:NSMakeRange(0, 2) client:client],
      @"Apple candidate list did not open");
  [fixture reloadDictionary];
  [controller commitCandidate:@"raw with spaces 한" client:client];
  Assert([client.inserted isEqualToString:@"raw with spaces"],
      @"displayed Apple candidate lost its insertion text after reload");
  [controller showHanjaCandidatesForText:@"원문 (설명)" replacementRange:NSMakeRange(0, 2) client:client];
  [controller commitCandidate:@"원문 (설명)" client:client];
  Assert([client.inserted isEqualToString:@"원문 (설명)"],
      @"original-text choice lost its annotation-like suffix");
  method_setImplementation(method, original);

  fixture.reloadCount = 0;
  [fixture dictionaryDidChange:nil];
  [fixture dictionaryDidChange:nil];
  [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
  Assert(fixture.reloadCount == 1, @"back-to-back notifications parsed the dictionary more than once");
  [fixture release];
  [pool drain];
  return 0;
}
