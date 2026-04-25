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
  BOOL _useMarkedTextForClient;
}

- (void)updateComposition:(id)sender;
- (void)updateDirectComposition:(id)sender;
- (void)commitComposition:(id)sender;
- (void)applyUserPreferences;
- (void)syncInputClient:(id)sender force:(BOOL)force;
- (NSRange)directInputReplacementRange:(id)sender;
- (BOOL)shouldUseMarkedTextForClient:(id)sender;

@end
