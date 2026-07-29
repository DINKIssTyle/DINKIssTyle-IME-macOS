#import "../Sources/InputController+Private.h"

@interface DKSTPolicyClient : NSObject {
  NSString *_bundleID;
  BOOL _showsMarked;
}
- (id)initWithBundleID:(NSString *)bundleID showsMarked:(BOOL)showsMarked;
@end

@implementation DKSTPolicyClient

- (id)initWithBundleID:(NSString *)bundleID showsMarked:(BOOL)showsMarked {
  self = [super init];
  if (self) {
    _bundleID = [bundleID copy];
    _showsMarked = showsMarked;
  }
  return self;
}

- (void)dealloc {
  [_bundleID release];
  [super dealloc];
}

- (NSString *)bundleIdentifier {
  return _bundleID;
}

- (NSRange)selectedRange {
  return NSMakeRange(0, 0);
}

- (BOOL)showsComposingTextAsMarkedText {
  return _showsMarked;
}

@end

@interface DKSTPolicyControllerProbe : InputController
- (BOOL)useMarkedTextForTestClient:(id)client;
- (BOOL)currentMarkedTextPolicyForTest;
- (NSUInteger)stickyFallbackCountForTest;
- (BOOL)transientFallbackForTest;
@end

@implementation DKSTPolicyControllerProbe

- (id)init {
  self = [super init];
  if (self) {
    _forcedMarkedTextBundleIDs = [[NSMutableSet alloc] init];
    _markedTextBundleIDSet = [[NSSet alloc] init];
    _chromiumDetectionCache = [[NSMutableDictionary alloc] init];
    _compositionState = [[DKSTCompositionState alloc] init];
    _directInputComposedRange = NSMakeRange(NSNotFound, 0);
    _markedReplacementRange = NSMakeRange(NSNotFound, 0);
  }
  return self;
}

- (id)textDocument {
  return nil;
}

- (BOOL)useMarkedTextForTestClient:(id)client {
  return [self shouldUseMarkedTextForClient:client];
}

- (BOOL)currentMarkedTextPolicyForTest {
  return _useMarkedTextForClient;
}

- (NSUInteger)stickyFallbackCountForTest {
  return [_forcedMarkedTextBundleIDs count];
}

- (BOOL)transientFallbackForTest {
  return _compositionState.shouldForceMarkedText;
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
  DKSTPolicyControllerProbe *controller =
      [[DKSTPolicyControllerProbe alloc] init];
  DKSTPolicyClient *calendar =
      [[[DKSTPolicyClient alloc] initWithBundleID:@"com.apple.iCal"
                                     showsMarked:NO] autorelease];

  DKSTAssert(![controller useMarkedTextForTestClient:calendar],
             @"Calendar did not begin with direct input");

  [controller forceMarkedTextForClient:calendar
                                reason:@"simulated asynchronous cursor lag"];
  DKSTAssert([controller currentMarkedTextPolicyForTest],
             @"current composition did not enter marked fallback");
  DKSTAssert([controller transientFallbackForTest],
             @"marked fallback was not recorded as transient");
  DKSTAssert([controller stickyFallbackCountForTest] == 0,
             @"transient fallback made Calendar permanently marked");

  [controller refreshMarkedTextPolicyForNewComposition:calendar];
  DKSTAssert(![controller currentMarkedTextPolicyForTest],
             @"new Calendar composition did not return to direct input");
  DKSTAssert(![controller transientFallbackForTest],
             @"transient fallback flag survived into the next composition");

  DKSTPolicyClient *siri =
      [[[DKSTPolicyClient alloc] initWithBundleID:@"com.apple.campo"
                                     showsMarked:NO] autorelease];
  DKSTPolicyClient *word =
      [[[DKSTPolicyClient alloc] initWithBundleID:@"com.microsoft.Word"
                                     showsMarked:NO] autorelease];
  DKSTPolicyClient *futureCompletionClient =
      [[[DKSTPolicyClient alloc] initWithBundleID:@"com.example.FutureCompletion"
                                     showsMarked:NO] autorelease];
  DKSTAssert(![controller useMarkedTextForTestClient:siri],
             @"Siri did not use the runtime direct-input policy");
  DKSTAssert(![controller useMarkedTextForTestClient:word],
             @"Word did not use the runtime direct-input policy");
  DKSTAssert(![controller useMarkedTextForTestClient:futureCompletionClient],
             @"a future completion client required a hard-coded policy");

  [controller release];
  [pool drain];
  return 0;
}
