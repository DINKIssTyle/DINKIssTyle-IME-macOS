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
  BOOL _customShiftEnabled;
  BOOL _hanjaEnabled;
  BOOL _useMarkedTextForAllApps;
  NSDictionary *_customShiftMappings;
  NSSet *_markedTextBundleIDSet;
  NSMutableString *_markedTextCommittedPrefix;
  NSUInteger _hanjaMarkedPrefixLength;
  BOOL _hanjaReplacementUsesMarkedPrefix;
  DKSTCompositionState *_compositionState;
  NSMutableDictionary *_chromiumDetectionCache;
  // Custom Hanja shortcut — MUST remain at the end of the ivar list
  // to avoid InputMethodKit memory layout conflicts.
  unsigned short _hanjaShortcutKeyCode;
  NSUInteger _hanjaShortcutModifiers;
  BOOL _hanjaModifierPending;
}

@end
