#import "../Sources/InputController+Private.h"

@interface InputController (DKSTSelectionChangedTesting)
- (void)selectionChanged:(id)sender;
@end

@interface DKSTSelectionClient : NSObject {
  NSRange _selectedRange;
}
- (id)initWithSelectedRange:(NSRange)selectedRange;
- (NSRange)selectedRange;
@end

@implementation DKSTSelectionClient

- (id)initWithSelectedRange:(NSRange)selectedRange {
  self = [super init];
  if (self) {
    _selectedRange = selectedRange;
  }
  return self;
}

- (NSRange)selectedRange {
  return _selectedRange;
}

@end

@interface DKSTSelectionChangedProbe : InputController {
  BOOL _pendingForTest;
  NSUInteger _commitCountForTest;
}
- (void)setPendingForTest:(BOOL)pending;
- (void)setLastSelectedRangeForTest:(NSRange)range;
- (NSRange)lastSelectedRangeForTest;
- (NSUInteger)commitCountForTest;
@end

@implementation DKSTSelectionChangedProbe

- (void)setPendingForTest:(BOOL)pending {
  _pendingForTest = pending;
}

- (BOOL)hasPendingComposition {
  return _pendingForTest;
}

- (void)commitComposition:(id)sender {
  (void)sender;
  _commitCountForTest++;
}

- (void)setLastSelectedRangeForTest:(NSRange)range {
  _lastClientSelectedRange = range;
}

- (NSRange)lastSelectedRangeForTest {
  return _lastClientSelectedRange;
}

- (NSUInteger)commitCountForTest {
  return _commitCountForTest;
}

@end

static void DKSTAssert(BOOL condition, NSString *message) {
  if (!condition) {
    NSLog(@"FAIL: %@", message);
    exit(1);
  }
}

int main(void) {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  DKSTSelectionChangedProbe *controller =
      [[DKSTSelectionChangedProbe alloc] init];

  NSRange originalRange = NSMakeRange(4, 0);
  NSRange asynchronousRange = NSMakeRange(9, 2);
  DKSTSelectionClient *client =
      [[[DKSTSelectionClient alloc]
          initWithSelectedRange:asynchronousRange] autorelease];

  [controller setLastSelectedRangeForTest:originalRange];
  [controller setPendingForTest:YES];
  [controller selectionChanged:client];

  DKSTAssert([controller commitCountForTest] == 0,
             @"an asynchronous selection callback committed composition");
  DKSTAssert(NSEqualRanges([controller lastSelectedRangeForTest], originalRange),
             @"an asynchronous selection callback replaced the tracked range");

  [controller setPendingForTest:NO];
  [controller selectionChanged:client];
  DKSTAssert(NSEqualRanges([controller lastSelectedRangeForTest],
                           asynchronousRange),
             @"an idle selection callback was not cached");

  [controller release];
  [pool drain];
  return 0;
}

