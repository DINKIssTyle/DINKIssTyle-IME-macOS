#import "../Sources/InputController+Private.h"
#import "../Sources/DKSTConstants.h"

@interface InputController (DKSTCandidateTestCallbacks)
- (void)candidateSelected:(NSAttributedString *)candidateString;
@end

@interface DKSTCandidatePanelProbe : NSObject {
  BOOL _visible;
  NSUInteger _hideCount;
}
- (BOOL)isVisible;
- (void)hide;
- (NSUInteger)hideCount;
@end

@implementation DKSTCandidatePanelProbe

- (id)init {
  self = [super init];
  if (self) {
    _visible = YES;
  }
  return self;
}

- (BOOL)isVisible {
  return _visible;
}

- (void)hide {
  _visible = NO;
  _hideCount++;
}

- (NSUInteger)hideCount {
  return _hideCount;
}

@end

@interface DKSTHanjaClientProbe : NSObject {
  NSMutableString *_text;
  NSRange _selectedRange;
  DKSTCandidatePanelProbe *_panel;
  NSUInteger _insertCount;
  BOOL _markedClearObservedHiddenPanel;
  BOOL _insertObservedHiddenPanel;
}
- (id)initWithPanel:(DKSTCandidatePanelProbe *)panel;
- (NSString *)text;
- (NSUInteger)insertCount;
- (BOOL)markedClearObservedHiddenPanel;
- (BOOL)insertObservedHiddenPanel;
@end

@implementation DKSTHanjaClientProbe

- (id)initWithPanel:(DKSTCandidatePanelProbe *)panel {
  self = [super init];
  if (self) {
    _text = [@"대한민국" mutableCopy];
    _selectedRange = NSMakeRange(4, 0);
    _panel = [panel retain];
  }
  return self;
}

- (void)dealloc {
  [_panel release];
  [_text release];
  [super dealloc];
}

- (NSString *)bundleIdentifier {
  return @"com.google.Chrome";
}

- (NSRange)selectedRange {
  return _selectedRange;
}

- (void)setMarkedText:(id)value
       selectionRange:(NSRange)selectionRange
      replacementRange:(NSRange)replacementRange {
  (void)selectionRange;
  (void)replacementRange;
  NSString *string = [value isKindOfClass:[NSAttributedString class]]
                         ? [(NSAttributedString *)value string]
                         : value;
  if ([string length] == 0) {
    _markedClearObservedHiddenPanel = ![_panel isVisible];
    // Model a Chromium field with the final syllable still marked. Clearing the
    // mark removes that syllable and leaves the committed three-syllable prefix.
    [_text setString:@"대한민"];
    _selectedRange = NSMakeRange(3, 0);
  }
}

- (void)insertText:(id)value replacementRange:(NSRange)replacementRange {
  NSString *string = [value isKindOfClass:[NSAttributedString class]]
                         ? [(NSAttributedString *)value string]
                         : value;
  _insertObservedHiddenPanel = ![_panel isVisible];
  [_text replaceCharactersInRange:replacementRange withString:string];
  _selectedRange =
      NSMakeRange(replacementRange.location + [string length], 0);
  _insertCount++;
}

- (NSString *)text {
  return _text;
}

- (NSUInteger)insertCount {
  return _insertCount;
}

- (BOOL)markedClearObservedHiddenPanel {
  return _markedClearObservedHiddenPanel;
}

- (BOOL)insertObservedHiddenPanel {
  return _insertObservedHiddenPanel;
}

@end

@interface DKSTHanjaControllerProbe : InputController {
  id _testClient;
}
- (id)initWithPanel:(DKSTCandidatePanelProbe *)panel client:(id)client;
- (BOOL)selectWithKeyCode:(unsigned short)keyCode;
@end

@implementation DKSTHanjaControllerProbe

- (id)initWithPanel:(DKSTCandidatePanelProbe *)panel client:(id)client {
  self = [super init];
  if (self) {
    engine = [[DKSTHangul alloc] init];
    _compositionState = [[DKSTCompositionState alloc] init];
    _markedTextCommittedPrefix = [[NSMutableString alloc] initWithString:@"대한민"];
    _markedReplacementRange = NSMakeRange(0, 4);
    _selectedTextRange = NSMakeRange(0, 4);
    _hanjaMarkedPrefixLength = 3;
    _hanjaReplacementUsesMarkedPrefix = YES;
    _currentHanjaCandidates =
        [[NSArray alloc] initWithObjects:@"大韓民國 대한민국", @"대한민국", nil];
    _currentHanjaIndex = 0;
    _candidates = (IMKCandidates *)panel;
    _testClient = [client retain];
  }
  return self;
}

- (void)dealloc {
  [_testClient release];
  [super dealloc];
}

- (id)client {
  return _testClient;
}

- (BOOL)selectWithKeyCode:(unsigned short)keyCode {
  return [self handleCandidateNavigation:keyCode client:_testClient];
}

@end

static void DKSTAssert(BOOL condition, NSString *message) {
  if (!condition) {
    NSLog(@"FAIL: %@", message);
    exit(1);
  }
}

static void DKSTDrainDeferredCommit(void) {
  [[NSRunLoop currentRunLoop]
      runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
}

static void DKSTTestKeyboardSelection(unsigned short keyCode,
                                      NSString *label) {
  DKSTCandidatePanelProbe *panel = [[DKSTCandidatePanelProbe alloc] init];
  DKSTHanjaClientProbe *client =
      [[DKSTHanjaClientProbe alloc] initWithPanel:panel];
  DKSTHanjaControllerProbe *controller =
      [[DKSTHanjaControllerProbe alloc] initWithPanel:panel client:client];

  DKSTAssert([controller selectWithKeyCode:keyCode],
             [NSString stringWithFormat:@"%@ was not handled", label]);
  DKSTAssert([panel hideCount] == 1,
             [NSString stringWithFormat:@"%@ did not close the panel first",
                                        label]);
  DKSTAssert([client insertCount] == 0,
             [NSString stringWithFormat:@"%@ committed inside the key event",
                                        label]);

  DKSTDrainDeferredCommit();
  DKSTAssert([client insertCount] == 1,
             [NSString stringWithFormat:@"%@ did not commit once", label]);
  DKSTAssert([[client text] isEqualToString:@"大韓民國"],
             [NSString stringWithFormat:@"%@ committed the wrong text", label]);
  DKSTAssert([client markedClearObservedHiddenPanel],
             [NSString stringWithFormat:
                           @"%@ cleared marked text before closing the panel",
                           label]);
  DKSTAssert([client insertObservedHiddenPanel],
             [NSString stringWithFormat:@"%@ inserted before closing the panel",
                                        label]);

  [controller release];
  [client release];
  [panel release];
}

int main(void) {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

  DKSTTestKeyboardSelection(kDKSTKeyCodeReturn, @"Return");
  DKSTTestKeyboardSelection(kDKSTKeyCodeNum1, @"number selection");

  DKSTCandidatePanelProbe *panel = [[DKSTCandidatePanelProbe alloc] init];
  DKSTHanjaClientProbe *client =
      [[DKSTHanjaClientProbe alloc] initWithPanel:panel];
  DKSTHanjaControllerProbe *controller =
      [[DKSTHanjaControllerProbe alloc] initWithPanel:panel client:client];
  DKSTAssert([controller selectWithKeyCode:kDKSTKeyCodeReturn],
             @"Return was not handled for duplicate-callback test");
  NSAttributedString *candidate = [[[NSAttributedString alloc]
      initWithString:@"大韓民國 대한민국"] autorelease];
  [controller candidateSelected:candidate];
  DKSTDrainDeferredCommit();
  DKSTAssert([client insertCount] == 1,
             @"native candidate callback caused a duplicate commit");
  DKSTAssert([[client text] isEqualToString:@"大韓民國"],
             @"native candidate callback committed the wrong text");

  [controller release];
  [client release];
  [panel release];

  panel = [[DKSTCandidatePanelProbe alloc] init];
  client = [[DKSTHanjaClientProbe alloc] initWithPanel:panel];
  controller =
      [[DKSTHanjaControllerProbe alloc] initWithPanel:panel client:client];
  DKSTAssert([controller selectWithKeyCode:kDKSTKeyCodeReturn],
             @"Return was not handled for late-callback test");
  DKSTDrainDeferredCommit();
  [controller candidateSelected:candidate];
  DKSTAssert([client insertCount] == 1,
             @"late native candidate callback caused a duplicate commit");

  [controller release];
  [client release];
  [panel release];
  [pool drain];
  return 0;
}
