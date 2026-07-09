#import "DKSTKeyMap.h"
#import "DKSTConstants.h"

enum {
  kDKSTKeyCodeRightControl = 0x3E,
  kDKSTKeyCodeControl = 0x3B,
  kDKSTKeyCodeRightShift = 0x3C,
  kDKSTKeyCodeShift = 0x38,
  kDKSTKeyCodeRightOption = 0x3D,
  kDKSTKeyCodeOption = 0x3A,
  kDKSTKeyCodeRightCommand = 0x36,
  kDKSTKeyCodeCommand = 0x37,
};

typedef struct {
  unsigned short keyCode;
  unichar lowerCharacter;
} DKSTRomanKeyMapping;

static const DKSTRomanKeyMapping kDKSTRomanKeyMappings[] = {
    {kDKSTKeyCodeA, 'a'}, {kDKSTKeyCodeS, 's'}, {kDKSTKeyCodeD, 'd'},
    {kDKSTKeyCodeF, 'f'}, {kDKSTKeyCodeH, 'h'}, {kDKSTKeyCodeG, 'g'},
    {kDKSTKeyCodeZ, 'z'}, {kDKSTKeyCodeX, 'x'}, {kDKSTKeyCodeC, 'c'},
    {kDKSTKeyCodeV, 'v'}, {kDKSTKeyCodeB, 'b'}, {kDKSTKeyCodeQ, 'q'},
    {kDKSTKeyCodeW, 'w'}, {kDKSTKeyCodeE, 'e'}, {kDKSTKeyCodeR, 'r'},
    {kDKSTKeyCodeY, 'y'}, {kDKSTKeyCodeT, 't'}, {kDKSTKeyCodeO, 'o'},
    {kDKSTKeyCodeU, 'u'}, {kDKSTKeyCodeI, 'i'}, {kDKSTKeyCodeP, 'p'},
    {kDKSTKeyCodeL, 'l'}, {kDKSTKeyCodeJ, 'j'}, {kDKSTKeyCodeK, 'k'},
    {kDKSTKeyCodeN, 'n'}, {kDKSTKeyCodeM, 'm'},
};

static NSUInteger DKSTRomanKeyMappingCount(void) {
  return sizeof(kDKSTRomanKeyMappings) / sizeof(kDKSTRomanKeyMappings[0]);
}

BOOL DKSTIsModifierKeyCode(unsigned short keyCode) {
  switch (keyCode) {
  case kDKSTKeyCodeRightControl:
  case kDKSTKeyCodeControl:
  case kDKSTKeyCodeRightShift:
  case kDKSTKeyCodeShift:
  case kDKSTKeyCodeRightOption:
  case kDKSTKeyCodeOption:
  case kDKSTKeyCodeRightCommand:
  case kDKSTKeyCodeCommand:
    return YES;
  default:
    return NO;
  }
}

BOOL DKSTModifierKeyIsPress(unsigned short keyCode, NSUInteger flags) {
  switch (keyCode) {
  case kDKSTKeyCodeRightControl:
  case kDKSTKeyCodeControl:
    return (flags & NSEventModifierFlagControl) != 0;
  case kDKSTKeyCodeRightShift:
  case kDKSTKeyCodeShift:
    return (flags & NSEventModifierFlagShift) != 0;
  case kDKSTKeyCodeRightOption:
  case kDKSTKeyCodeOption:
    return (flags & NSEventModifierFlagOption) != 0;
  case kDKSTKeyCodeRightCommand:
  case kDKSTKeyCodeCommand:
    return (flags & NSEventModifierFlagCommand) != 0;
  default:
    return NO;
  }
}

NSUInteger DKSTModifierMaskForKeyCode(unsigned short keyCode) {
  switch (keyCode) {
  case kDKSTKeyCodeRightControl:
  case kDKSTKeyCodeControl:
    return NSEventModifierFlagControl;
  case kDKSTKeyCodeRightShift:
  case kDKSTKeyCodeShift:
    return NSEventModifierFlagShift;
  case kDKSTKeyCodeRightOption:
  case kDKSTKeyCodeOption:
    return NSEventModifierFlagOption;
  case kDKSTKeyCodeRightCommand:
  case kDKSTKeyCodeCommand:
    return NSEventModifierFlagCommand;
  default:
    return 0;
  }
}

BOOL DKSTIsHangulANSIKeyCode(unsigned short keyCode) {
  for (NSUInteger i = 0; i < DKSTRomanKeyMappingCount(); i++) {
    if (kDKSTRomanKeyMappings[i].keyCode == keyCode) {
      return YES;
    }
  }
  return NO;
}

BOOL DKSTRomanCharacterForANSIKeyCode(unsigned short keyCode,
                                      NSUInteger flags,
                                      unichar *character) {
  for (NSUInteger i = 0; i < DKSTRomanKeyMappingCount(); i++) {
    DKSTRomanKeyMapping mapping = kDKSTRomanKeyMappings[i];
    if (mapping.keyCode == keyCode) {
      unichar result = mapping.lowerCharacter;
      if ((flags & NSEventModifierFlagShift) != 0) {
        result = result - 'a' + 'A';
      }
      if (character) {
        *character = result;
      }
      return YES;
    }
  }
  return NO;
}

NSString *DKSTRomanStringForANSIKeyCode(unsigned short keyCode,
                                        NSUInteger flags) {
  unichar character = 0;
  if (!DKSTRomanCharacterForANSIKeyCode(keyCode, flags, &character)) {
    return nil;
  }
  return [NSString stringWithFormat:@"%C", character];
}

BOOL DKSTKeyCodeForTypingCharacter(unichar character,
                                   unsigned short *keyCode) {
  if (character == ' ') {
    if (keyCode) {
      *keyCode = kDKSTKeyCodeSpace;
    }
    return YES;
  }
  if (character == '\n') {
    if (keyCode) {
      *keyCode = kDKSTKeyCodeReturn;
    }
    return YES;
  }

  unichar lower = character;
  if (character >= 'A' && character <= 'Z') {
    lower = character - 'A' + 'a';
  }
  for (NSUInteger i = 0; i < DKSTRomanKeyMappingCount(); i++) {
    DKSTRomanKeyMapping mapping = kDKSTRomanKeyMappings[i];
    if (mapping.lowerCharacter == lower) {
      if (keyCode) {
        *keyCode = mapping.keyCode;
      }
      return YES;
    }
  }
  return NO;
}
