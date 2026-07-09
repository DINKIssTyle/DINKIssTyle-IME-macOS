#import <Cocoa/Cocoa.h>

BOOL DKSTIsModifierKeyCode(unsigned short keyCode);
BOOL DKSTModifierKeyIsPress(unsigned short keyCode, NSUInteger flags);
NSUInteger DKSTModifierMaskForKeyCode(unsigned short keyCode);

BOOL DKSTIsHangulANSIKeyCode(unsigned short keyCode);
BOOL DKSTRomanCharacterForANSIKeyCode(unsigned short keyCode,
                                      NSUInteger flags,
                                      unichar *character);
NSString *DKSTRomanStringForANSIKeyCode(unsigned short keyCode,
                                        NSUInteger flags);
BOOL DKSTKeyCodeForTypingCharacter(unichar character,
                                   unsigned short *keyCode);
