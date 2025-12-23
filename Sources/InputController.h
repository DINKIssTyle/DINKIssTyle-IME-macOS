#import <Cocoa/Cocoa.h>
#import <InputMethodKit/InputMethodKit.h>
#import "DKSTHangul.h"

@interface InputController : IMKInputController {
    DKSTHangul *engine;
    NSString *currentMode;
    IMKCandidates *_candidates;
    NSArray *_currentHanjaCandidates;
}

- (void)updateComposition:(id)sender;
- (void)commitComposition:(id)sender;

@end
