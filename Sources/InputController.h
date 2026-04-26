#import "DKSTHangul.h"
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
  NSRange _directInputComposedRange;
  NSRange _markedReplacementRange;
  NSMutableSet *_forcedMarkedTextBundleIDs;
  id _lastInputClient;
  NSRange _lastClientSelectedRange;
  BOOL _useMarkedTextForClient;
}

- (void)updateComposition:(id)sender;
- (void)updateDirectComposition:(id)sender;
- (void)updateInlineForClient:(id)sender;
- (void)commitComposition:(id)sender;
- (void)applyUserPreferences;
- (void)syncInputClient:(id)sender force:(BOOL)force;
- (void)resetCompositionState;
- (BOOL)hasPendingComposition;
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
- (BOOL)isHangulKeyCode:(unsigned short)keyCode;

@end
