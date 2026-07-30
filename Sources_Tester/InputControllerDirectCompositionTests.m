#import "../Sources/InputController+Private.h"
#import "../Sources/DKSTConstants.h"

@interface DKSTDirectClient : NSObject {
  NSMutableString *_text;
  NSString *_bundleID;
  NSRange _selectedRange;
  NSUInteger _markedCallCount;
  BOOL _overrideSelectedRangeAfterNextInsert;
  BOOL _hasSelectedRangeOverride;
  NSRange _selectedRangeOverride;
  BOOL _corruptNextInsert;
}
- (id)initWithBundleIdentifier:(NSString *)bundleIdentifier;
- (NSString *)text;
- (void)selectSuggestion:(NSString *)suggestion;
- (void)replaceTextWithSuggestion:(NSString *)suggestion;
- (void)setText:(NSString *)text selectedRange:(NSRange)selectedRange;
- (void)setSelectedRange:(NSRange)selectedRange;
- (void)deleteSelection;
- (void)insertLineBreak;
- (void)corruptNextInsert;
- (void)reportSelectedRange:(NSRange)range afterNextInsert:(BOOL)enabled;
- (void)clearSelectedRangeOverride;
- (NSUInteger)markedCallCount;
@end

@implementation DKSTDirectClient

- (id)initWithBundleIdentifier:(NSString *)bundleIdentifier {
  self = [super init];
  if (self) {
    _text = [[NSMutableString alloc] init];
    _bundleID = [bundleIdentifier copy];
    _selectedRange = NSMakeRange(0, 0);
  }
  return self;
}

- (void)dealloc {
  [_text release];
  [_bundleID release];
  [super dealloc];
}

- (NSString *)text {
  return _text;
}

- (NSString *)bundleIdentifier {
  return _bundleID;
}

- (NSRange)selectedRange {
  if (_hasSelectedRangeOverride) {
    return _selectedRangeOverride;
  }
  return _selectedRange;
}

- (NSAttributedString *)attributedSubstringFromRange:(NSRange)range {
  return [[[NSAttributedString alloc]
      initWithString:[_text substringWithRange:range]] autorelease];
}

- (void)insertText:(id)value replacementRange:(NSRange)replacementRange {
  NSString *string = [value isKindOfClass:[NSAttributedString class]]
                         ? [(NSAttributedString *)value string]
                         : value;
  NSRange range = replacementRange;
  if (range.location == NSNotFound) {
    range = _selectedRange;
  }
  [_text replaceCharactersInRange:range withString:string];
  if (_corruptNextInsert && [string length] > 0) {
    _corruptNextInsert = NO;
    [_text replaceCharactersInRange:NSMakeRange(range.location, 1)
                         withString:@"X"];
  }
  _selectedRange = NSMakeRange(range.location + [string length], 0);
  if (_overrideSelectedRangeAfterNextInsert) {
    _overrideSelectedRangeAfterNextInsert = NO;
    _hasSelectedRangeOverride = YES;
  }
}

- (void)setMarkedText:(id)value
       selectionRange:(NSRange)selectionRange
      replacementRange:(NSRange)replacementRange {
  (void)value;
  (void)selectionRange;
  (void)replacementRange;
  _markedCallCount++;
}

- (void)selectSuggestion:(NSString *)suggestion {
  NSUInteger start = _selectedRange.location;
  [_text insertString:suggestion atIndex:start];
  _selectedRange = NSMakeRange(start, [suggestion length]);
}

- (void)replaceTextWithSuggestion:(NSString *)suggestion {
  [_text setString:suggestion];
  _selectedRange = NSMakeRange(0, [suggestion length]);
}

- (void)setText:(NSString *)text selectedRange:(NSRange)selectedRange {
  [_text setString:text];
  _selectedRange = selectedRange;
}

- (void)setSelectedRange:(NSRange)selectedRange {
  _selectedRange = selectedRange;
}

- (void)deleteSelection {
  if (_selectedRange.location == NSNotFound || _selectedRange.length == 0) {
    return;
  }
  NSUInteger location = _selectedRange.location;
  [_text deleteCharactersInRange:_selectedRange];
  _selectedRange = NSMakeRange(location, 0);
}

- (void)insertLineBreak {
  [_text replaceCharactersInRange:_selectedRange withString:@"\n"];
  _selectedRange = NSMakeRange(_selectedRange.location + 1, 0);
}

- (void)corruptNextInsert {
  _corruptNextInsert = YES;
}

- (void)reportSelectedRange:(NSRange)range afterNextInsert:(BOOL)enabled {
  _selectedRangeOverride = range;
  _overrideSelectedRangeAfterNextInsert = enabled;
}

- (void)clearSelectedRangeOverride {
  _hasSelectedRangeOverride = NO;
}

- (NSUInteger)markedCallCount {
  return _markedCallCount;
}

@end

@interface DKSTDirectControllerProbe : InputController
- (void)processKeyCodeForTest:(unsigned short)keyCode client:(id)client;
- (BOOL)tryKeyCodeForTest:(unsigned short)keyCode client:(id)client;
- (void)finishForTest:(id)client;
- (BOOL)usesMarkedFallbackForTest;
- (void)setDirectRangeForTest:(NSRange)range;
- (void)setLastSelectedRangeForTest:(NSRange)range;
- (BOOL)handleBackspaceForTest:(id)client;
@end

@implementation DKSTDirectControllerProbe

- (id)init {
  self = [super init];
  if (self) {
    engine = [[DKSTHangul alloc] init];
    _compositionState = [[DKSTCompositionState alloc] init];
    _forcedMarkedTextBundleIDs = [[NSMutableSet alloc] init];
    _markedTextCommittedPrefix = [[NSMutableString alloc] init];
    _directInputComposedRange = NSMakeRange(NSNotFound, 0);
    _markedReplacementRange = NSMakeRange(NSNotFound, 0);
    _lastClientSelectedRange = NSMakeRange(NSNotFound, 0);
    _useMarkedTextForClient = NO;
  }
  return self;
}

- (void)processKeyCodeForTest:(unsigned short)keyCode client:(id)client {
  NSCAssert([self tryKeyCodeForTest:keyCode client:client],
            @"direct composition update failed");
}

- (BOOL)tryKeyCodeForTest:(unsigned short)keyCode client:(id)client {
  [self prepareForInputClient:client];
  BOOL processed = [engine processCode:keyCode modifiers:0];
  NSCAssert(processed, @"test key was not handled by Hangul engine");
  return [self updateDirectComposition:client];
}

- (void)finishForTest:(id)client {
  [self commitComposition:client];
}

- (BOOL)usesMarkedFallbackForTest {
  return _useMarkedTextForClient;
}

- (void)setDirectRangeForTest:(NSRange)range {
  _directInputComposedRange = range;
}

- (void)setLastSelectedRangeForTest:(NSRange)range {
  _lastClientSelectedRange = range;
}

- (BOOL)handleBackspaceForTest:(id)client {
  NSEvent *event =
      [NSEvent keyEventWithType:NSEventTypeKeyDown
                       location:NSZeroPoint
                  modifierFlags:0
                      timestamp:0
                   windowNumber:0
                        context:nil
                     characters:@"\b"
    charactersIgnoringModifiers:@"\b"
                      isARepeat:NO
                        keyCode:kDKSTKeyCodeBackspace];
  return [self handleEventInEditTransaction:event client:client];
}

@end

static void DKSTAssert(BOOL condition, NSString *message) {
  if (!condition) {
    NSLog(@"FAIL: %@", message);
    exit(1);
  }
}

static void DKSTAssertScalars(NSString *text, const unichar *expected,
                              NSUInteger count, NSString *message) {
  if ([text length] != count) {
    DKSTAssert(NO, message);
  }
  for (NSUInteger index = 0; index < count; index++) {
    if ([text characterAtIndex:index] != expected[index]) {
      DKSTAssert(NO, message);
    }
  }
}

int main(void) {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  DKSTDirectControllerProbe *calendarController =
      [[DKSTDirectControllerProbe alloc] init];
  DKSTDirectClient *calendarClient = [[DKSTDirectClient alloc]
      initWithBundleIdentifier:@"com.apple.iCal"];

  [calendarController processKeyCodeForTest:kDKSTKeyCodeQ
                                      client:calendarClient];
  const unichar bieup[] = {0x3142};
  DKSTAssertScalars([calendarClient text], bieup, 1,
                    @"initial consonant was not stored as compatibility Jamo");

  // Calendar can briefly keep reporting its pre-autofill selection after the
  // insertion has succeeded. That observation must not switch the controller
  // to marked text.
  [calendarClient reportSelectedRange:NSMakeRange(50, 0)
                      afterNextInsert:YES];
  [calendarController processKeyCodeForTest:kDKSTKeyCodeK
                                      client:calendarClient];
  const unichar ba[] = {0xBC14};
  DKSTAssertScalars([calendarClient text], ba, 1,
                    @"Calendar active syllable was not NFC");
  DKSTAssert([calendarClient markedCallCount] == 0,
             @"asynchronous cursor lag switched Calendar to marked text");
  [calendarClient clearSelectedRangeOverride];

  [calendarController processKeyCodeForTest:kDKSTKeyCodeR
                                      client:calendarClient];
  DKSTAssert([[calendarClient text] isEqualToString:@"박"],
             @"Calendar syllable did not remain NFC");

  // A completion can expose a selected suffix after inlineRange. The next
  // direct update must replace both the active syllable and the suffix.
  [calendarClient selectSuggestion:@"노민"];
  [calendarController processKeyCodeForTest:kDKSTKeyCodeS
                                      client:calendarClient];
  DKSTAssert([[calendarClient text] isEqualToString:@"박ㄴ"],
             @"selected completion suffix was not replaced atomically");

  const unsigned short remaining[] = {
      kDKSTKeyCodeH, kDKSTKeyCodeA, kDKSTKeyCodeL, kDKSTKeyCodeS,
  };
  for (NSUInteger index = 0;
       index < sizeof(remaining) / sizeof(remaining[0]); index++) {
    [calendarController processKeyCodeForTest:remaining[index]
                                        client:calendarClient];
  }

  [calendarController finishForTest:calendarClient];
  DKSTAssert([[calendarClient text] isEqualToString:@"박노민"],
             @"Calendar direct input did not finish as NFC 박노민");
  DKSTAssert([calendarClient markedCallCount] == 0,
             @"direct input unexpectedly switched to marked composition");

  [calendarClient release];
  [calendarController release];

  DKSTDirectControllerProbe *siriController =
      [[DKSTDirectControllerProbe alloc] init];
  DKSTDirectClient *siriClient = [[DKSTDirectClient alloc]
      initWithBundleIdentifier:@"com.apple.campo"];

  [siriController processKeyCodeForTest:kDKSTKeyCodeE client:siriClient];
  // The candidate can include and rewrite the active inline character rather
  // than merely appending a suffix.
  [siriClient replaceTextWithSuggestion:@"다음 사전"];
  [siriController processKeyCodeForTest:kDKSTKeyCodeK client:siriClient];
  const unichar da[] = {0xB2E4};
  DKSTAssertScalars([siriClient text], da, 1,
                    @"Siri candidate including inlineRange was not replaced");

  const unsigned short daeumRemaining[] = {
      kDKSTKeyCodeD, kDKSTKeyCodeM, kDKSTKeyCodeA,
  };
  for (NSUInteger index = 0;
       index < sizeof(daeumRemaining) / sizeof(daeumRemaining[0]); index++) {
    [siriController processKeyCodeForTest:daeumRemaining[index]
                                    client:siriClient];
  }
  [siriController finishForTest:siriClient];
  DKSTAssert([[siriClient text] isEqualToString:@"다음"],
             @"Siri direct input did not finish as NFC 다음");
  DKSTAssert([siriClient markedCallCount] == 0,
             @"Siri candidate selection caused marked-text clearing");

  [siriClient release];
  [siriController release];

  DKSTDirectControllerProbe *wordController =
      [[DKSTDirectControllerProbe alloc] init];
  DKSTDirectClient *wordClient = [[DKSTDirectClient alloc]
      initWithBundleIdentifier:@"com.microsoft.Word"];

  [wordController processKeyCodeForTest:kDKSTKeyCodeD client:wordClient];
  const unichar ieung[] = {0x3147};
  DKSTAssertScalars([wordClient text], ieung, 1,
                    @"Word initial consonant was not compatibility Jamo");

  [wordController processKeyCodeForTest:kDKSTKeyCodeK client:wordClient];
  const unichar ah[] = {0xC544};
  DKSTAssertScalars([wordClient text], ah, 1,
                    @"Word active syllable 아 was split into Jamo");

  [wordController processKeyCodeForTest:kDKSTKeyCodeS client:wordClient];
  const unichar an[] = {0xC548};
  DKSTAssertScalars([wordClient text], an, 1,
                    @"Word active syllable 안 was split into Jamo");

  const unsigned short annyeonghaseyoRemaining[] = {
      kDKSTKeyCodeS, kDKSTKeyCodeU, kDKSTKeyCodeD,
      kDKSTKeyCodeG, kDKSTKeyCodeK, kDKSTKeyCodeT,
      kDKSTKeyCodeP, kDKSTKeyCodeD, kDKSTKeyCodeY,
  };
  for (NSUInteger index = 0;
       index < sizeof(annyeonghaseyoRemaining) /
                   sizeof(annyeonghaseyoRemaining[0]);
       index++) {
    [wordController
        processKeyCodeForTest:annyeonghaseyoRemaining[index]
                       client:wordClient];
  }
  [wordController finishForTest:wordClient];
  DKSTAssert([[wordClient text] isEqualToString:@"안녕하세요"],
             @"Word direct input did not finish as 안녕하세요");

  [wordClient release];
  [wordController release];

  // The same range behavior must work for a future client without adding its
  // bundle identifier to the input method.
  DKSTDirectControllerProbe *futureController =
      [[DKSTDirectControllerProbe alloc] init];
  DKSTDirectClient *futureClient = [[DKSTDirectClient alloc]
      initWithBundleIdentifier:@"com.example.FutureCompletion"];
  [futureController processKeyCodeForTest:kDKSTKeyCodeE client:futureClient];
  [futureClient replaceTextWithSuggestion:@"다음 검색"];
  [futureController processKeyCodeForTest:kDKSTKeyCodeK client:futureClient];
  DKSTAssert([[futureClient text] isEqualToString:@"다"],
             @"runtime candidate-range handling depended on a bundle ID");
  DKSTAssert([futureClient markedCallCount] == 0,
             @"future completion client received a marked-text clear");
  [futureClient release];
  [futureController release];

  DKSTDirectControllerProbe *selectionController =
      [[DKSTDirectControllerProbe alloc] init];
  DKSTDirectClient *selectionClient = [[DKSTDirectClient alloc]
      initWithBundleIdentifier:@"com.example.Selection"];
  [selectionClient setText:@"기존 선택"
             selectedRange:NSMakeRange(3, 2)];
  [selectionController processKeyCodeForTest:kDKSTKeyCodeE
                                       client:selectionClient];
  DKSTAssert([[selectionClient text] isEqualToString:@"기존 ㄷ"],
             @"first direct input did not explicitly replace selected text");
  [selectionClient release];
  [selectionController release];

  DKSTDirectControllerProbe *failureController =
      [[DKSTDirectControllerProbe alloc] init];
  DKSTDirectClient *failureClient = [[DKSTDirectClient alloc]
      initWithBundleIdentifier:@"com.example.BrokenDirectInsert"];
  [failureController processKeyCodeForTest:kDKSTKeyCodeE
                                     client:failureClient];
  [failureClient corruptNextInsert];
  DKSTAssert(![failureController tryKeyCodeForTest:kDKSTKeyCodeK
                                            client:failureClient],
             @"delayed document mismatch was accepted as direct input");
  DKSTAssert([failureController usesMarkedFallbackForTest],
             @"verified document mismatch did not request marked fallback");
  [failureClient release];
  [failureController release];

  DKSTDirectControllerProbe *multilineController =
      [[DKSTDirectControllerProbe alloc] init];
  DKSTDirectClient *multilineClient = [[DKSTDirectClient alloc]
      initWithBundleIdentifier:@"com.apple.MobileSMS"];
  for (NSUInteger line = 0; line < 5; line++) {
    [multilineController processKeyCodeForTest:kDKSTKeyCodeA
                                        client:multilineClient];
    [multilineController processKeyCodeForTest:kDKSTKeyCodeK
                                        client:multilineClient];
    [multilineController finishForTest:multilineClient];
    if (line < 4) {
      [multilineClient insertLineBreak];
    }
  }
  DKSTAssert([[multilineClient text]
                 isEqualToString:@"마\n마\n마\n마\n마"],
             @"direct composition split into Jamo after repeated line breaks");
  DKSTAssert([multilineClient markedCallCount] == 0,
             @"multiline direct input unexpectedly used marked text");
  [multilineClient release];
  [multilineController release];

  // Messages can publish an inlineRange one position ahead of the live text
  // after Shift+Return. Rebase from the current caret only when the actual
  // consonant exists in the backtracked range.
  DKSTDirectControllerProbe *laggedSelectionController =
      [[DKSTDirectControllerProbe alloc] init];
  DKSTDirectClient *laggedSelectionClient = [[DKSTDirectClient alloc]
      initWithBundleIdentifier:@"com.apple.MobileSMS"];
  [laggedSelectionClient setText:@"\n" selectedRange:NSMakeRange(1, 0)];
  [laggedSelectionController processKeyCodeForTest:kDKSTKeyCodeA
                                             client:laggedSelectionClient];
  [laggedSelectionController setDirectRangeForTest:NSMakeRange(2, 1)];
  [laggedSelectionController setLastSelectedRangeForTest:NSMakeRange(1, 0)];
  [laggedSelectionController processKeyCodeForTest:kDKSTKeyCodeK
                                             client:laggedSelectionClient];
  DKSTAssert([[laggedSelectionClient text] isEqualToString:@"\n마"],
             @"stale line-start inline range duplicated the first consonant");
  DKSTAssert([laggedSelectionClient markedCallCount] == 0,
             @"line-start range rebasing used marked composition");
  [laggedSelectionClient release];
  [laggedSelectionController release];

  // A genuine move outside inlineRange must still finish the old composition
  // and begin the next one at the user's new caret.
  DKSTDirectControllerProbe *movedCaretController =
      [[DKSTDirectControllerProbe alloc] init];
  DKSTDirectClient *movedCaretClient = [[DKSTDirectClient alloc]
      initWithBundleIdentifier:@"com.example.RealCaretMove"];
  [movedCaretClient setText:@"앞 " selectedRange:NSMakeRange(2, 0)];
  [movedCaretController processKeyCodeForTest:kDKSTKeyCodeA
                                        client:movedCaretClient];
  [movedCaretClient setSelectedRange:NSMakeRange(0, 0)];
  [movedCaretController processKeyCodeForTest:kDKSTKeyCodeK
                                        client:movedCaretClient];
  DKSTAssert([[movedCaretClient text] isEqualToString:@"ㅏ앞 ㅁ"],
             @"a real caret move was mistaken for asynchronous selection lag");
  [movedCaretClient release];
  [movedCaretController release];

  // Selecting direct-input text and pressing Backspace belongs to the client.
  // The buffered final syllable must be discarded rather than decomposed and
  // inserted back into the newly emptied selection.
  DKSTDirectControllerProbe *selectedDeleteController =
      [[DKSTDirectControllerProbe alloc] init];
  DKSTDirectClient *selectedDeleteClient = [[DKSTDirectClient alloc]
      initWithBundleIdentifier:@"com.microsoft.Excel"];
  [selectedDeleteController processKeyCodeForTest:kDKSTKeyCodeA
                                            client:selectedDeleteClient];
  [selectedDeleteController processKeyCodeForTest:kDKSTKeyCodeK
                                            client:selectedDeleteClient];
  [selectedDeleteClient setSelectedRange:NSMakeRange(
                                              0,
                                              [[selectedDeleteClient text]
                                                  length])];
  DKSTAssert(![selectedDeleteController
                 handleBackspaceForTest:selectedDeleteClient],
             @"selected-text Backspace was consumed by the Hangul engine");
  [selectedDeleteClient deleteSelection];
  DKSTAssert([[selectedDeleteClient text] length] == 0,
             @"selected sentence was not deleted cleanly");
  DKSTAssert(![selectedDeleteController
                 handleBackspaceForTest:selectedDeleteClient],
             @"discarded Hangul buffer handled a later Backspace");
  DKSTAssert([[selectedDeleteClient text] length] == 0,
             @"a buffered Jamo reappeared after selected-text deletion");
  [selectedDeleteClient release];
  [selectedDeleteController release];

  [pool drain];
  return 0;
}
