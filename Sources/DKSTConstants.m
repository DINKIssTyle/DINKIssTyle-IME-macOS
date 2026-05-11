#import "DKSTConstants.h"
#import <Cocoa/Cocoa.h>

NSString *const kDKSTBundleID = @"com.dinkisstyle.inputmethod.DKST";
NSString *const kDKSTConnection = @"DKST_1_Connection";

NSString *const kDKSTUserDefaultsDidChangeNotification =
    @"DKSTUserDefaultsDidChangeNotification";
NSString *const kDKSTRemapperDidLaunchNotification =
    @"DKSTRemapperDidLaunchNotification";
NSString *const kDKSTDictionaryAddNewWordNotification =
    @"DKSTDictionaryAddNewWordNotification";
NSString *const kDKSTDictionaryDidChangeNotification =
    @"DKSTDictionaryDidChangeNotification";

NSString *const kDKSTEnglishMode = @"com.dinkisstyle.inputmethod.DKST.english";
NSString *const kDKSTHangulMode = @"com.dinkisstyle.inputmethod.DKST.hangul";
NSString *const kDKSTHanjaMode = @"com.dinkisstyle.inputmethod.DKST.hanja";

// layout names
NSString *const kUSKeylayout = @"com.apple.keylayout.US";
NSString *const kGermanKeylayout = @"com.apple.keylayout.German";
NSString *const kDvorakKeylayout = @"com.apple.keylayout.Dvorak";
NSString *const kDvorakQwertyKeylayout =
    @"com.apple.keylayout.Dvorak-QWERTYCMD";

// Basic setup
NSString *const kDKSTEnglishKeyboardKey = @"DKSTEnglishKeyboard";
NSString *const kDKSTHangulKeyboardKey = @"DKSTHangulKeyboard";
NSString *const kDKSTHangulOrderCorrectionKey = @"DKSTHangulOrderCorrection";
NSString *const kDKSTQwertyEmulationEnableKey = @"DKSTQwertyEmulationEnable";
NSString *const kDKSTMarkedTextAppBundleIDsKey = @"DKSTMarkedTextAppBundleIDs";
NSString *const kDKSTUseMarkedTextForAllAppsKey =
    @"DKSTUseMarkedTextForAllApps";
NSString *const kDKSTUseAppleHanjaDictionaryKey =
    @"DKSTUseAppleHanjaDictionary";

NSArray *DKSTDefaultMarkedTextAppBundleIDs(void) {
  return [NSArray
      arrayWithObjects:@"com.apple.Terminal", @"com.googlecode.iterm2",
                       @"com.microsoft.VSCode", @"com.microsoft.VSCodeInsiders",
                       @"dev.zed.Zed", @"dev.zed.Zed-Dev",
                       @"com.todesktop.230313mzl4w4u92", @"com.google.Chrome",
                       @"com.google.Chrome.canary", @"com.microsoft.edgemac",
                       @"com.openai.chat", @"com.openai.codex",
                       @"com.google.android.studio", @"com.google.antigravity",
                       //    @"com.adobe.*", @"com.hancom.office.*",
                       @"com.dinkisstyle.translatorai",
                       @"com.dinkisstyle.terminalai",
                       @"com.dinkisstyle.nametagmaker",
                       @"com.dinkisstyle.llmchat", @"com.dinkisstyle.mdbrowser",
                       @"com.dinkisstyle.phototaggerai",
                       @"com.dinkisstyle.readerserver", nil];
}

// Shortcuts
NSString *const kDKSTShortcutsKey = @"DKSTShortcuts";
NSString *const kShortcutUserDefinedKey = @"ShortcutUserDefined";
NSString *const kShortcutEnableKey = @"ShortcutEnable";
NSString *const kCGEventTypeKey = @"CGEventType";
NSString *const kCGEventKeyCodeKey = @"CGEventKeyCode";
NSString *const kCGEventFlagsKey = @"CGEventFlags";
NSString *const kCGEventFlagsMaskKey = @"CGEventFlagsMask";
NSString *const kCGEventFlagsOptionKey = @"CGEventFlagsOption";
NSString *const kShortcutTypeKey = @"ShortcutType";
NSString *const kShortcutStringKey = @"ShortcutString";
NSString *const kShortcutStringIgnoringModifiersKey =
    @"ShortcutStringIgnoringModifiers";

// Advanced
NSString *const kDKSTHangulCommitByWordKey = @"DKSTHangulCommitByWord";
NSString *const kDKSTEnglishBypassWithOptionKey =
    @"DKSTEnglishBypassWithOption";
NSString *const kDKSTHanjaCommitByWordKey = @"DKSTHanjaCommitByWord";
NSString *const kDKSTHanjaParenStyleKey = @"DKSTHanjaParenStyle";
NSString *const kDKSTVIModeKey = @"DKSTVIMode";

NSString *const kDKSTCandidatesPanelPropertiesKey =
    @"DKSTCandidatesPanelProperties";
NSString *const kDKSTCandidatesPanelTypeKey = @"DKSTCandidatesPanelType";
NSString *const kDKSTCandidatesFontSizeKey = @"DKSTCandidatesFontSize";

NSString *const kDKSTIndicatorPropertiesKey = @"DKSTIndicatorProperties";
NSString *const kDKSTIndicatorEnableKey = @"DKSTIndicatorEnable";

// Dictionary
NSString *const kDKSTDisabledDictionariesKey = @"DKSTDisabledDictionaries";
NSString *const kDKSTDictionaryEnabledKey = @"DKSTDictionaryEnabled";
NSString *const kDKSTDictionaryFilenameKey = @"DKSTDictionaryFilename";

NSString *const kDKSTAttributedStringEnabledKey =
    @"DKSTAttributedStringEnabled";
NSString *const kDKSTFontsAttributesKey = @"DKSTFontsAttributes";

// Trigger
NSString *const kDKSTTriggerPropertiesKey = @"DKSTTriggerProperties";
NSString *const kDKSTTriggerEnableKey = @"DKSTTriggerEnable";
NSString *const kDKSTTriggerAlertKey = @"DKSTTriggerAlert";
NSString *const kDKSTTriggerChangeInputModeKey = @"DKSTTriggerChangeInputMode";
NSString *const kDKSTTriggerArrayKey = @"DKSTTriggerArray";

// Remapper
NSString *const kDKSTAppSpecificSetupKey = @"DKSTAppSpecificSetup";

// Updater
NSString *const kDKSTUpdateCheckPeriodKey = @"DKSTUpdateCheckPeriod";
NSString *const kDKSTUpdateLastCheckKey = @"DKSTUpdateLastCheck";

// Dev
NSString *const kDKSTVerboseModeKey = @"DKSTVerboseMode";

// Shared keyCode → ASCII mapping (single source of truth)
unichar DKSTASCIIForKeyCode(unsigned short keyCode, BOOL shift) {
  switch (keyCode) {
  case 0:  return shift ? 'A' : 'a';
  case 1:  return shift ? 'S' : 's';
  case 2:  return shift ? 'D' : 'd';
  case 3:  return shift ? 'F' : 'f';
  case 4:  return shift ? 'H' : 'h';
  case 5:  return shift ? 'G' : 'g';
  case 6:  return shift ? 'Z' : 'z';
  case 7:  return shift ? 'X' : 'x';
  case 8:  return shift ? 'C' : 'c';
  case 9:  return shift ? 'V' : 'v';
  case 11: return shift ? 'B' : 'b';
  case 12: return shift ? 'Q' : 'q';
  case 13: return shift ? 'W' : 'w';
  case 14: return shift ? 'E' : 'e';
  case 15: return shift ? 'R' : 'r';
  case 16: return shift ? 'Y' : 'y';
  case 17: return shift ? 'T' : 't';
  case 31: return shift ? 'O' : 'o';
  case 32: return shift ? 'U' : 'u';
  case 34: return shift ? 'I' : 'i';
  case 35: return shift ? 'P' : 'p';
  case 37: return shift ? 'L' : 'l';
  case 38: return shift ? 'J' : 'j';
  case 40: return shift ? 'K' : 'k';
  case 45: return shift ? 'N' : 'n';
  case 46: return shift ? 'M' : 'm';
  default: return 0;
  }
}

BOOL DKSTIsHangulKeyCode(unsigned short keyCode) {
  return DKSTASCIIForKeyCode(keyCode, NO) != 0;
}

NSString *DKSTRomanStringForKeyCode(unsigned short keyCode,
                                    NSUInteger modifiers) {
  BOOL shift = (modifiers & NSEventModifierFlagShift) != 0;
  unichar ch = DKSTASCIIForKeyCode(keyCode, shift);
  if (ch == 0) return nil;
  return [NSString stringWithCharacters:&ch length:1];
}
