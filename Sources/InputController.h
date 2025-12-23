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
}

- (void)updateComposition:(id)sender;
- (void)commitComposition:(id)sender;

@end
