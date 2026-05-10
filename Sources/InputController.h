#import "DKSTHangul.h"
#import "DKSTCompositionState.h"
#import <Cocoa/Cocoa.h>
#import <InputMethodKit/InputMethodKit.h>

@interface InputController : IMKInputController {
  DKSTHangul *engine;
  NSString *currentMode;
  IMKCandidates *_candidates;
  NSArray *_currentHanjaCandidates;
  NSInteger _currentHanjaIndex; // Track selection index manually
  NSRange _selectedTextRange;   // For selected text Hanja conversion
  NSTimeInterval _lastClientSyncTime;
  NSUInteger _directInputComposedLength;
  NSString *_directInputComposedText;
  NSRange _directInputComposedRange;
  NSRange _markedReplacementRange;
  NSMutableSet *_forcedMarkedTextBundleIDs;
  id _lastInputClient;
  id _lastBundleIdentifierClient;
  NSString *_lastInputClientBundleID;
  NSRange _lastClientSelectedRange;
  BOOL _useMarkedTextForClient;
  BOOL _moaJjikiEnabled;
  BOOL _fullCharacterDeleteEnabled;
  BOOL _customShiftEnabled;
  BOOL _hanjaEnabled;
  BOOL _useMarkedTextForAllApps;
  BOOL _unicodeInjectionEnabled;
  BOOL _unicodeInjectionAccessLogged;
  NSUInteger _unicodeInjectedComposedLength;
  NSDictionary *_customShiftMappings;
  NSSet *_markedTextBundleIDSet;
  NSSet *_unicodeInjectionBundleIDSet;
  NSMutableString *_markedTextCommittedPrefix;
  NSUInteger _hanjaMarkedPrefixLength;
  BOOL _hanjaReplacementUsesMarkedPrefix;
  DKSTCompositionState *_compositionState;
  NSMutableDictionary *_chromiumDetectionCache;
}

- (void)updateComposition:(id)sender;
- (void)updateDirectComposition:(id)sender;
- (void)updateInlineForClient:(id)sender;
- (void)commitMarkedText:(NSString *)commit
    previousComposedLength:(NSUInteger)previousComposedLength
                    client:(id)sender;
- (void)commitComposition:(id)sender;
- (void)reloadUserPreferences;
- (void)preferencesDidChange:(NSNotification *)notification;
- (void)refreshMarkedTextPolicyForClient:(id)sender;
- (void)syncInputClient:(id)sender force:(BOOL)force;
- (void)resetCompositionState;
- (BOOL)hasPendingComposition;
- (void)setMarkedReplacementRange:(NSRange)range;
- (void)clearMarkedReplacementRange;
- (void)rememberSelectedRangeForClient:(id)sender;
- (void)prepareForInputClient:(id)sender;
- (NSRange)directInputReplacementRange:(id)sender;
- (NSRange)compositionReplacementRange:(id)sender;
- (NSString *)textBeforeCursorForClient:(id)sender
                                  limit:(NSUInteger)limit
                                  range:(NSRange *)outRange;
- (NSString *)hangulTextForHanjaConversion:(id)sender
                                      range:(NSRange *)outRange;
- (BOOL)showHanjaCandidatesForText:(NSString *)text
                   replacementRange:(NSRange)replacementRange
                             client:(id)sender;
- (NSString *)bundleIdentifierForClient:(id)sender;
- (void)forceMarkedTextForClient:(id)sender reason:(NSString *)reason;
- (BOOL)shouldUseMarkedTextForClient:(id)sender;
- (BOOL)bundleIdentifierMatchesMarkedTextConfiguration:(NSString *)bundleID;
- (BOOL)shouldUseUnicodeInjectionForClient:(id)sender;
- (void)updateUnicodeInjectionComposition:(id)sender;
- (void)postUnicodeString:(NSString *)string;
- (void)postSyntheticBackspaceCount:(NSUInteger)count;
- (void)postSyntheticKeyboardEvent:(CGEventRef)event;
- (BOOL)eventContainsInjectedUnicodeText:(NSEvent *)event;
- (BOOL)bundleIdentifierUsesWebKitTextStack:(NSString *)bundleID;
- (BOOL)shouldAvoidEagerSyncForClient:(id)sender;
- (BOOL)shouldTrustDirectCompositionRangeForClient:(id)sender;
- (BOOL)bundleIdentifierUsesChromiumMarkedTextPolicy:(NSString *)bundleID;
- (BOOL)runningApplicationUsesChromiumTextStack:(NSString *)bundleID;
- (BOOL)applicationBundleUsesChromiumTextStack:(NSURL *)bundleURL;
- (BOOL)isHangulKeyCode:(unsigned short)keyCode;

@end
