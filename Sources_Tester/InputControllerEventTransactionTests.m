#import "../Sources/InputController+Private.h"
#import "../Sources/DKSTConstants.h"

@interface DKSTEditDocumentProbe : NSObject {
  BOOL _editing;
  NSUInteger _beginCount;
  NSUInteger _endCount;
  NSUInteger _invalidateCount;
}
- (void)beginEdit;
- (void)endEdit;
- (void)invalidateCache;
- (BOOL)isEditing;
- (NSUInteger)beginCount;
- (NSUInteger)endCount;
- (NSUInteger)invalidateCount;
@end

@implementation DKSTEditDocumentProbe

- (void)beginEdit {
  NSCAssert(!_editing, @"nested beginEdit");
  _editing = YES;
  _beginCount++;
}

- (void)endEdit {
  NSCAssert(_editing, @"endEdit without beginEdit");
  _editing = NO;
  _endCount++;
}

- (void)invalidateCache {
  NSCAssert(!_editing, @"cache invalidated before endEdit");
  _invalidateCount++;
}

- (BOOL)isEditing {
  return _editing;
}

- (NSUInteger)beginCount {
  return _beginCount;
}

- (NSUInteger)endCount {
  return _endCount;
}

- (NSUInteger)invalidateCount {
  return _invalidateCount;
}

@end

@interface DKSTEventTransactionControllerProbe : InputController {
  DKSTEditDocumentProbe *_document;
  BOOL _innerResult;
  BOOL _innerObservedEditing;
  BOOL _commitObservedEditing;
  NSUInteger _commitCount;
}
- (id)initWithDocument:(DKSTEditDocumentProbe *)document;
- (void)setInnerResult:(BOOL)innerResult;
- (BOOL)innerObservedEditing;
- (BOOL)commitObservedEditing;
- (NSUInteger)commitCount;
@end

@implementation DKSTEventTransactionControllerProbe

- (id)initWithDocument:(DKSTEditDocumentProbe *)document {
  self = [super init];
  if (self) {
    _document = [document retain];
  }
  return self;
}

- (void)dealloc {
  [_document release];
  [super dealloc];
}

- (id)textDocument {
  return _document;
}

- (void)setInnerResult:(BOOL)innerResult {
  _innerResult = innerResult;
}

- (BOOL)handleEventInEditTransaction:(NSEvent *)event client:(id)sender {
  (void)event;
  (void)sender;
  _innerObservedEditing = [_document isEditing];
  return _innerResult;
}

- (void)commitComposition:(id)sender {
  (void)sender;
  _commitObservedEditing = [_document isEditing];
  _commitCount++;
}

- (BOOL)innerObservedEditing {
  return _innerObservedEditing;
}

- (BOOL)commitObservedEditing {
  return _commitObservedEditing;
}

- (NSUInteger)commitCount {
  return _commitCount;
}

@end

static NSEvent *DKSTKeyEvent(unsigned short keyCode,
                             NSEventModifierFlags modifiers,
                             NSString *characters) {
  return [NSEvent keyEventWithType:NSEventTypeKeyDown
                          location:NSZeroPoint
                     modifierFlags:modifiers
                         timestamp:0
                      windowNumber:0
                           context:nil
                        characters:characters
       charactersIgnoringModifiers:characters
                         isARepeat:NO
                           keyCode:keyCode];
}

static void DKSTAssert(BOOL condition, NSString *message) {
  if (!condition) {
    NSLog(@"FAIL: %@", message);
    exit(1);
  }
}

int main(void) {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  DKSTEditDocumentProbe *document = [[DKSTEditDocumentProbe alloc] init];
  DKSTEventTransactionControllerProbe *controller =
      [[DKSTEventTransactionControllerProbe alloc]
          initWithDocument:document];

  [controller setInnerResult:NO];
  NSEvent *shiftReturn =
      DKSTKeyEvent(kDKSTKeyCodeReturn, NSEventModifierFlagShift, @"\r");
  DKSTAssert(![controller handleEvent:shiftReturn client:nil],
             @"Shift+Return was not passed through");
  DKSTAssert([controller innerObservedEditing],
             @"event body did not run inside beginEdit/endEdit");
  DKSTAssert([controller commitCount] == 1,
             @"Shift+Return did not finish composition");
  DKSTAssert(![controller commitObservedEditing],
             @"Shift+Return committed before endEdit");
  DKSTAssert([document beginCount] == 1 && [document endCount] == 1,
             @"Shift+Return edit transaction was unbalanced");
  DKSTAssert([document invalidateCount] == 1,
             @"unhandled Shift+Return did not invalidate the cache");

  [controller setInnerResult:YES];
  NSEvent *hangulKey = DKSTKeyEvent(kDKSTKeyCodeA, 0, @"a");
  DKSTAssert([controller handleEvent:hangulKey client:nil],
             @"handled Hangul key was passed through");
  DKSTAssert([document beginCount] == 2 && [document endCount] == 2,
             @"handled Hangul edit transaction was unbalanced");
  DKSTAssert([document invalidateCount] == 1,
             @"handled Hangul key unnecessarily invalidated the cache");
  DKSTAssert([controller commitCount] == 1,
             @"handled Hangul key unexpectedly committed composition");

  [controller release];
  [document release];
  [pool drain];
  return 0;
}
