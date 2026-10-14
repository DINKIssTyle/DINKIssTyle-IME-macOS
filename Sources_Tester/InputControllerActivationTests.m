#import "../Sources/InputController+Private.h"
#import "../Sources/DKSTConstants.h"
#import <objc/runtime.h>

static void Assert(BOOL condition, NSString *message) {
  if (!condition) { NSLog(@"FAIL: %@", message); exit(1); }
}

@interface SyncClient : NSObject
@property(nonatomic, retain) NSMutableArray *calls;
@property(nonatomic, retain) NSMutableString *text;
@property NSRange selection;
@property NSRange mark;
@property BOOL showsMarked;
@property BOOL throwPolicy;
@property BOOL throwTimeout;
@property NSUInteger overrideFailures;
@property NSUInteger overrideCount;
@property NSUInteger policyCount;
@property NSUInteger markedReads;
@property NSUInteger selectionReads;
@property(nonatomic, copy) NSString *bundleID;
@end

@implementation SyncClient
- (id)init {
  if ((self = [super init])) {
    self.calls = [NSMutableArray array];
    self.text = [NSMutableString string];
    self.mark = NSMakeRange(NSNotFound, 0);
    self.showsMarked = YES;
    self.bundleID = @"com.example.Sync";
  }
  return self;
}
- (void)dealloc { [_calls release]; [_text release]; [_bundleID release]; [super dealloc]; }
- (NSString *)bundleIdentifier { [self.calls addObject:@"bundle"]; return self.bundleID; }
- (void)setReplyTimeout:(double)timeout {
  Assert(timeout == 0.1, @"normal clients lost the 100ms reply budget");
  [self.calls addObject:@"timeout"];
  if (self.throwTimeout) [NSException raise:@"UnsupportedTimeout" format:@"injected"];
}
- (void)overrideKeyboardWithKeyboardNamed:(NSString *)name {
  Assert([name isEqualToString:kUSKeylayout], @"unexpected keyboard layout");
  [self.calls addObject:@"override"];
  self.overrideCount++;
  if (self.overrideFailures) {
    self.overrideFailures--;
    [NSException raise:@"UnavailableEndpoint" format:@"injected"];
  }
}
- (BOOL)showsComposingTextAsMarkedText {
  [self.calls addObject:@"policy"];
  self.policyCount++;
  if (self.throwPolicy) [NSException raise:@"PolicyTimeout" format:@"injected"];
  return self.showsMarked;
}
- (NSRange)selectedRange { self.selectionReads++; return self.selection; }
- (NSRange)markedRange { self.markedReads++; return self.mark; }
- (NSAttributedString *)attributedSubstringFromRange:(NSRange)range {
  return [[[NSAttributedString alloc] initWithString:[self.text substringWithRange:range]] autorelease];
}
- (void)insertText:(id)value replacementRange:(NSRange)range {
  NSString *text = [value isKindOfClass:[NSAttributedString class]] ? [value string] : value;
  if (range.location == NSNotFound) range = self.mark.location == NSNotFound ? self.selection : self.mark;
  [self.text replaceCharactersInRange:range withString:text];
  self.selection = NSMakeRange(range.location + text.length, 0);
  self.mark = NSMakeRange(NSNotFound, 0);
}
- (void)setMarkedText:(id)value selectionRange:(NSRange)selection replacementRange:(NSRange)range {
  NSString *text = [value isKindOfClass:[NSAttributedString class]] ? [value string] : value;
  if (range.location == NSNotFound) range = self.mark.location == NSNotFound ? self.selection : self.mark;
  [self.text replaceCharactersInRange:range withString:text];
  self.mark = text.length ? NSMakeRange(range.location, text.length) : NSMakeRange(NSNotFound, 0);
  self.selection = NSMakeRange(range.location + selection.location, selection.length);
}
@end

@interface SyncController : InputController
@property NSUInteger preferenceLoads;
@property NSUInteger shortcutLoads;
@property BOOL nextMarkedPreference;
- (BOOL)markedPolicy;
@end
@implementation SyncController
- (id)init {
  if ((self = [super init])) {
    engine = [[DKSTHangul alloc] init];
    _compositionState = [[DKSTCompositionState alloc] init];
    _markedTextCommittedPrefix = [[NSMutableString alloc] init];
    _markedTextBundleIDSet = [[NSSet alloc] init];
    _chromiumDetectionCache = [[NSMutableDictionary alloc] init];
    _directInputComposedRange = NSMakeRange(NSNotFound, 0);
    _markedReplacementRange = NSMakeRange(NSNotFound, 0);
    _selectedTextRange = NSMakeRange(NSNotFound, 0);
    _lastClientSelectedRange = NSMakeRange(NSNotFound, 0);
    _hanjaShortcutKeyCode = kDKSTKeyCodeReturn;
    _hanjaShortcutModifiers = NSEventModifierFlagOption;
    [self reloadUserPreferences];
    self.preferenceLoads = self.shortcutLoads = 0;
  }
  return self;
}
- (id)textDocument { return nil; }
- (void)reloadUserPreferences {
  self.preferenceLoads++;
  _useMarkedTextForAllApps = self.nextMarkedPreference;
  [self reloadHanjaShortcut];
}
- (void)reloadHanjaShortcut { self.shortcutLoads++; }
- (BOOL)markedPolicy { return _useMarkedTextForClient; }
@end

static void NoOpLifecycle(id object, SEL selector, id sender) {}

static BOOL Type(SyncController *controller, SyncClient *client, unsigned short key) {
  NSEvent *event = [NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint
      modifierFlags:0 timestamp:0 windowNumber:0 context:nil characters:@"r"
      charactersIgnoringModifiers:@"r" isARepeat:NO keyCode:key];
  return [controller handleEvent:event client:client];
}

static void TestActivationAndFirstKeys(void) {
  SyncClient *client = [[[SyncClient alloc] init] autorelease];
  SyncController *controller = [[[SyncController alloc] init] autorelease];
  [controller activateServer:client];
  Assert([[client.calls firstObject] isEqualToString:@"timeout"], @"client read preceded reply timeout setup");
  Assert(controller.preferenceLoads == 0 && controller.shortcutLoads == 0,
         @"clean activation reloaded unchanged preferences");
  Assert(Type(controller, client, kDKSTKeyCodeR), @"first Hangul key escaped to client");
  Assert(Type(controller, client, kDKSTKeyCodeK), @"second Hangul key escaped to client");
  Assert([client.text isEqualToString:@"가"], @"first keys did not compose Hangul");
  Assert(client.overrideCount == 1, @"successful activation repeated keyboard override while typing");
  Assert(client.policyCount == 1, @"permanent marked client repeated its policy query on first key");
#ifndef DEBUG
  Assert(client.markedReads == 0, @"Release performed diagnostic markedRange reads");
#endif
  [controller commitComposition:client];
  for (NSUInteger i = 0; i < 20; i++) {
    [controller activateServer:client];
    Assert(Type(controller, client, kDKSTKeyCodeS), @"rapid reactivation lost its first consonant");
    Assert(Type(controller, client, kDKSTKeyCodeK), @"rapid reactivation lost its first vowel");
    [controller commitComposition:client];
  }
  NSMutableString *expected = [NSMutableString stringWithString:@"가"];
  for (NSUInteger i = 0; i < 20; i++) [expected appendString:@"나"];
  Assert([client.text isEqualToString:expected], @"rapid reactivation duplicated or dropped text");
  Assert(controller.preferenceLoads == 0 && controller.shortcutLoads == 0,
         @"repeated activation reloaded unchanged settings");
}

static void TestBoundedRecoveryAndClientChange(void) {
  SyncClient *client = [[[SyncClient alloc] init] autorelease];
  client.overrideFailures = 1;
  SyncController *controller = [[[SyncController alloc] init] autorelease];
  [controller activateServer:client];
  Assert(Type(controller, client, kDKSTKeyCodeR), @"failed override lost first key");
  Assert(Type(controller, client, kDKSTKeyCodeK), @"recovered override lost second key");
  Assert(client.overrideCount == 2 && [client.text isEqualToString:@"가"], @"known sync failure did not recover once");
  SyncClient *other = [[[SyncClient alloc] init] autorelease];
  Assert(Type(controller, other, kDKSTKeyCodeS), @"new client without activation lost first key");
  Assert([[other.calls firstObject] isEqualToString:@"timeout"] && other.overrideCount == 1,
         @"client change did not configure and sync its own proxy");
  Assert([other.text isEqualToString:@"ㄴ"], @"old composition leaked into new client");

  SyncClient *hung = [[[SyncClient alloc] init] autorelease];
  hung.overrideFailures = 100;
  SyncController *limited = [[[SyncController alloc] init] autorelease];
  [limited activateServer:hung];
  Type(limited, hung, kDKSTKeyCodeR);
  Type(limited, hung, kDKSTKeyCodeK);
  Type(limited, hung, kDKSTKeyCodeS);
  Assert(hung.overrideCount == 2, @"unresponsive endpoint was retried on every key");

  SyncClient *webkit = [[[SyncClient alloc] init] autorelease];
  webkit.bundleID = @"com.apple.Safari";
  [limited activateServer:webkit];
  Type(limited, webkit, kDKSTKeyCodeR);
  Assert(webkit.overrideCount == 0, @"WebKit eager-sync exception was lost");
}

static void TestDeferredPreferencesAndProxyErrors(void) {
  SyncClient *client = [[[SyncClient alloc] init] autorelease];
  client.showsMarked = NO;
  SyncController *controller = [[[SyncController alloc] init] autorelease];
  [controller activateServer:client];
  Type(controller, client, kDKSTKeyCodeR);
  controller.nextMarkedPreference = YES;
  NSNotification *change = [NSNotification notificationWithName:NSUserDefaultsDidChangeNotification object:nil];
  [controller preferencesDidChange:change];
  [controller preferencesDidChange:change];
  [controller hanjaShortcutDidChange:change];
  Type(controller, client, kDKSTKeyCodeK);
  Assert(![controller markedPolicy] && controller.preferenceLoads == 0,
         @"notification changed in-flight composition policy");
  Assert([client.text isEqualToString:@"가"], @"settings change broke the active syllable");
  [controller commitComposition:client];
  Type(controller, client, kDKSTKeyCodeS);
  Assert([controller markedPolicy] && controller.preferenceLoads == 1 && controller.shortcutLoads == 1,
         @"pending changes were not coalesced at the next composition");
  Type(controller, client, kDKSTKeyCodeK);
  Assert([client.text isEqualToString:@"가나"], @"policy boundary dropped or duplicated a syllable");

  SyncClient *faulty = [[[SyncClient alloc] init] autorelease];
  faulty.throwTimeout = faulty.throwPolicy = YES;
  [controller activateServer:faulty];
  // Use a fresh controller so its forced-marked setting cannot mask the fault.
  SyncController *fallback = [[[SyncController alloc] init] autorelease];
  [fallback activateServer:faulty];
  Assert(Type(fallback, faulty, kDKSTKeyCodeR), @"private API exception aborted first key processing");

  SyncController *modifier = [[[SyncController alloc] init] autorelease];
  [modifier activateServer:client];
  [modifier hanjaShortcutDidChange:change];
  NSEvent *flags = [NSEvent keyEventWithType:NSEventTypeFlagsChanged location:NSZeroPoint
      modifierFlags:NSEventModifierFlagShift timestamp:0 windowNumber:0 context:nil
      characters:@"" charactersIgnoringModifiers:@"" isARepeat:NO keyCode:56];
  [modifier handleEvent:flags client:client];
  Assert(modifier.shortcutLoads == 1, @"modifier-only shortcut update waited for an ordinary key");
}

int main(void) {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  // The tests execute DKST's real lifecycle body without a live system IMK
  // server. Only framework setup/teardown is stubbed, not DKST behavior.
  Method activate = class_getInstanceMethod([IMKInputController class], @selector(activateServer:));
  IMP original = method_setImplementation(activate, (IMP)NoOpLifecycle);
  TestActivationAndFirstKeys();
  TestBoundedRecoveryAndClientChange();
  TestDeferredPreferencesAndProxyErrors();
  method_setImplementation(activate, original);
  [pool drain];
  return 0;
}
