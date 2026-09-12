#import "../Sources/InputController+Private.h"
#import "../Sources/DKSTConstants.h"

// A text client that models both committed and marked text in one document.
@interface DKSTRecoveryClient : NSObject
@property(nonatomic, retain) NSMutableString *text;
@property NSRange selection;
@property NSRange mark;
@property BOOL rejectNextInsert;
@property BOOL corruptNextInsert;
@property BOOL hideMarkedRange;
@property BOOL throwMarkedRange;
@end
@implementation DKSTRecoveryClient
- (id)init {
  if ((self = [super init])) {
    self.text = [NSMutableString string];
    self.mark = NSMakeRange(NSNotFound, 0);
  }
  return self;
}
- (void)dealloc { [_text release]; [super dealloc]; }
- (NSString *)bundleIdentifier { return @"com.example.RecoveryTest"; }
- (NSRange)selectedRange { return self.selection; }
- (NSRange)markedRange {
  if (self.throwMarkedRange) [NSException raise:@"Unavailable" format:@"marked range unavailable"];
  return self.hideMarkedRange ? NSMakeRange(NSNotFound, 0) : self.mark;
}
- (NSAttributedString *)attributedSubstringFromRange:(NSRange)range {
  if (self.mark.location != NSNotFound) return nil;
  return [[[NSAttributedString alloc] initWithString:[self.text substringWithRange:range]] autorelease];
}
- (NSRange)resolvedRange:(NSRange)range {
  if (range.location != NSNotFound) return range;
  return self.mark.location != NSNotFound ? self.mark : self.selection;
}
- (void)insertText:(id)value replacementRange:(NSRange)range {
  if (self.rejectNextInsert) {
    self.rejectNextInsert = NO;
    [NSException raise:@"RejectedInsert" format:@"injected before document mutation"];
  }
  NSString *text = [value isKindOfClass:[NSAttributedString class]] ? [value string] : value;
  range = [self resolvedRange:range];
  [self.text replaceCharactersInRange:range withString:text];
  if (self.corruptNextInsert && text.length) {
    self.corruptNextInsert = NO;
    [self.text replaceCharactersInRange:NSMakeRange(range.location, 1) withString:@"X"];
  }
  self.selection = NSMakeRange(range.location + text.length, 0);
  self.mark = NSMakeRange(NSNotFound, 0);
}
- (void)setMarkedText:(id)value selectionRange:(NSRange)selection replacementRange:(NSRange)range {
  NSString *text = [value isKindOfClass:[NSAttributedString class]] ? [value string] : value;
  range = [self resolvedRange:range];
  [self.text replaceCharactersInRange:range withString:text];
  self.mark = text.length ? NSMakeRange(range.location, text.length) : NSMakeRange(NSNotFound, 0);
  self.selection = NSMakeRange(range.location + selection.location, selection.length);
}
@end

@interface DKSTRecoveryController : InputController
- (id)initWithClient:(id)client marked:(BOOL)marked;
- (void)typeKey:(unsigned short)key client:(id)client;
- (void)checkNextInsert;
- (void)chooseHanja:(NSString *)candidate source:(NSString *)source range:(NSRange)range client:(id)client;
@end
@implementation DKSTRecoveryController
- (id)initWithClient:(id)client marked:(BOOL)marked {
  if ((self = [super init])) {
    engine = [[DKSTHangul alloc] init];
    _compositionState = [[DKSTCompositionState alloc] init];
    _markedTextCommittedPrefix = [[NSMutableString alloc] init];
    _directInputComposedRange = NSMakeRange(NSNotFound, 0);
    _markedReplacementRange = NSMakeRange(NSNotFound, 0);
    _selectedTextRange = NSMakeRange(NSNotFound, 0);
    _lastClientSelectedRange = NSMakeRange(NSNotFound, 0);
    _lastInputClient = client;
    _useMarkedTextForClient = marked;
    _useMarkedTextForAllApps = marked;
  }
  return self;
}
- (id)textDocument { return nil; }
- (void)typeKey:(unsigned short)key client:(id)client {
  NSEvent *event = [NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint
      modifierFlags:0 timestamp:0 windowNumber:0 context:nil characters:@""
      charactersIgnoringModifiers:@"" isARepeat:NO keyCode:key];
  NSCAssert([self handleEventInEditTransaction:event client:client], @"key was not handled");
}
- (void)checkNextInsert { _compositionState.shouldCheckInsertionError = YES; }
- (void)chooseHanja:(NSString *)candidate source:(NSString *)source range:(NSRange)range client:(id)client {
  _selectedTextRange = range;
  [_currentHanjaCandidates release];
  _currentHanjaCandidates = [[NSArray alloc] initWithObjects:candidate, source, nil];
  [self commitCandidate:candidate client:client];
}
// Isolate prefix range tests from installed/user dictionary contents.
- (NSString *)firstHanjaDictionaryMatchInText:(NSString *)text startIndex:(NSUInteger *)index {
  if (index) *index = 0;
  return text;
}
@end

static void Check(BOOL value, NSString *message) {
  if (!value) { NSLog(@"FAIL: %@", message); exit(1); }
}

static void TestRecovery(BOOL corrupt) {
  DKSTRecoveryClient *client = [[DKSTRecoveryClient alloc] init];
  DKSTRecoveryController *controller = [[DKSTRecoveryController alloc] initWithClient:client marked:NO];
  for (NSNumber *key in @[@(kDKSTKeyCodeR), @(kDKSTKeyCodeK), @(kDKSTKeyCodeS)]) {
    [controller typeKey:key.unsignedShortValue client:client];
  }
  Check([client.text isEqualToString:@"간"], @"setup did not compose 간");
  client.rejectNextInsert = !corrupt;
  client.corruptNextInsert = corrupt;
  [controller checkNextInsert];
  [controller typeKey:kDKSTKeyCodeK client:client];
  Check([client.text isEqualToString:@"가나"], @"fallback lost or duplicated a syllable");
  [controller typeKey:kDKSTKeyCodeS client:client];
  Check([client.text isEqualToString:@"가난"], @"composition after fallback was incorrect");
  [controller commitComposition:client];
  Check([client.text isEqualToString:@"가난"], @"commit repeated the recovered prefix");
  [controller release]; [client release];
}

static void TestMarkedHanja(void) {
  DKSTRecoveryClient *client = [[DKSTRecoveryClient alloc] init];
  [client.text setString:@"앞 "];
  client.selection = NSMakeRange(2, 0);
  DKSTRecoveryController *controller = [[DKSTRecoveryController alloc] initWithClient:client marked:YES];
  [controller typeKey:kDKSTKeyCodeR client:client];
  [controller typeKey:kDKSTKeyCodeK client:client];
  NSRange range;
  NSString *source = [controller hangulTextForHanjaConversion:client range:&range];
  Check(NSEqualRanges(range, NSMakeRange(2, 1)), @"Hanja target was not the live mark");
  client.hideMarkedRange = YES;
  [controller hangulTextForHanjaConversion:client range:&range];
  Check(range.location == NSNotFound, @"unknown mark defaulted to document start");
  Check(![controller showHanjaCandidatesForText:source replacementRange:range client:client], @"unknown range opened candidates");
  client.hideMarkedRange = NO;
  client.throwMarkedRange = YES;
  Check([controller compositionReplacementRange:client].location == NSNotFound, @"exception produced a replacement range");
  client.throwMarkedRange = NO;
  [controller chooseHanja:@"家" source:source range:NSMakeRange(2, 1) client:client];
  Check([client.text isEqualToString:@"앞 家"], @"Hanja overwrote preceding text");
  [controller release]; [client release];
}

static void TestMarkedPrefix(void) {
  DKSTRecoveryClient *client = [[DKSTRecoveryClient alloc] init];
  [client.text setString:@"앞 "];
  client.selection = NSMakeRange(2, 0);
  DKSTRecoveryController *controller = [[DKSTRecoveryController alloc] initWithClient:client marked:YES];
  for (NSNumber *key in @[@(kDKSTKeyCodeR), @(kDKSTKeyCodeK), @(kDKSTKeyCodeS), @(kDKSTKeyCodeK)]) {
    [controller typeKey:key.unsignedShortValue client:client];
  }
  NSRange range;
  NSString *source = [controller hangulTextForHanjaConversion:client range:&range];
  Check(NSEqualRanges(range, NSMakeRange(2, 2)), @"prefix range did not include committed syllable");
  [controller chooseHanja:@"假名" source:source range:range client:client];
  Check([client.text isEqualToString:@"앞 假名"], @"prefix conversion damaged surrounding text");
  [controller release]; [client release];
}

int main(void) {
  @autoreleasepool {
    TestRecovery(NO);
    TestRecovery(YES);
    TestMarkedHanja();
    TestMarkedPrefix();
  }
  return 0;
}
