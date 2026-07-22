#import <Foundation/Foundation.h>
extern NSString *const kDKSTBundleID;
extern NSString *const kDKSTConnection;

// notifications
extern NSString *const kDKSTUserDefaultsDidChangeNotification;
extern NSString *const kDKSTRemapperDidLaunchNotification;
extern NSString *const kDKSTDictionaryAddNewWordNotification;
extern NSString *const kDKSTDictionaryDidChangeNotification;

// modes
extern NSString *const kDKSTEnglishMode;
extern NSString *const kDKSTHangulMode;
extern NSString *const kDKSTHanjaMode;

// layout names
extern NSString *const kUSKeylayout;
extern NSString *const kGermanKeylayout;
extern NSString *const kDvorakKeylayout;
extern NSString *const kDvorakQwertyKeylayout;

// Basic setup
extern NSString *const kDKSTEnglishKeyboardKey;
extern NSString *const kDKSTHangulKeyboardKey;
extern NSString *const kDKSTHangulOrderCorrectionKey;
extern NSString *const kDKSTQwertyEmulationEnableKey;
extern NSString *const kDKSTMarkedTextAppBundleIDsKey;
extern NSString *const kDKSTUseMarkedTextForAllAppsKey;
extern NSString *const kDKSTUseAppleHanjaDictionaryKey;
extern NSString *const kDKSTEnableMoaJjikiKey;
extern NSString *const kDKSTFullCharacterDeleteKey;
extern NSString *const kDKSTEnableHanjaKey;
extern NSString *const kDKSTEnableCustomShiftKey;
extern NSString *const kDKSTCustomShiftMappingsKey;

// Hanja custom shortcut
extern NSString *const kDKSTHanjaShortcutKeyCodeKey;
extern NSString *const kDKSTHanjaShortcutModifiersKey;
extern NSString *const kDKSTHanjaShortcutDidChangeNotification;

NSArray *DKSTDefaultMarkedTextAppBundleIDs(void);
NSString *DKSTUserDictionaryPath(void);

// Shortcuts
extern NSString *const kDKSTShortcutsKey;
extern NSString *const kShortcutUserDefinedKey;
extern NSString *const kShortcutEnableKey;
extern NSString *const kCGEventTypeKey;
extern NSString *const kCGEventKeyCodeKey;
extern NSString *const kCGEventFlagsKey;
extern NSString *const kCGEventFlagsMaskKey;
extern NSString *const kCGEventFlagsOptionKey;
extern NSString *const kShortcutTypeKey;
extern NSString *const kShortcutStringKey;
extern NSString *const kShortcutStringIgnoringModifiersKey;
enum {
  kDKSTSwitchShortcut = 0,
  kDKSTHanjaShortcut,
  kDKSTRomanShortcut,
  kDKSTDictionaryShortcut,
  kDKSTReloadDictionaryShortcut,
  kDKSTRegisterSelectedWordShortcut,
};

enum {
  kCGEventFlagsAny = 0,
  kCGEventFlagsLeft,
  kCGEventFlagsRight,
};

// Key codes (ANSI keyboard)
enum {
  kDKSTKeyCodeA         = 0,
  kDKSTKeyCodeS         = 1,
  kDKSTKeyCodeD         = 2,
  kDKSTKeyCodeF         = 3,
  kDKSTKeyCodeH         = 4,
  kDKSTKeyCodeG         = 5,
  kDKSTKeyCodeZ         = 6,
  kDKSTKeyCodeX         = 7,
  kDKSTKeyCodeC         = 8,
  kDKSTKeyCodeV         = 9,
  kDKSTKeyCodeB         = 11,
  kDKSTKeyCodeQ         = 12,
  kDKSTKeyCodeW         = 13,
  kDKSTKeyCodeE         = 14,
  kDKSTKeyCodeR         = 15,
  kDKSTKeyCodeY         = 16,
  kDKSTKeyCodeT         = 17,
  kDKSTKeyCodeO         = 31,
  kDKSTKeyCodeU         = 32,
  kDKSTKeyCodeI         = 34,
  kDKSTKeyCodeP         = 35,
  kDKSTKeyCodeL         = 37,
  kDKSTKeyCodeJ         = 38,
  kDKSTKeyCodeK         = 40,
  kDKSTKeyCodeN         = 45,
  kDKSTKeyCodeM         = 46,
  kDKSTKeyCodeReturn    = 36,
  kDKSTKeyCodeTab       = 48,
  kDKSTKeyCodeSpace     = 49,
  kDKSTKeyCodeBackspace = 51,
  kDKSTKeyCodeEscape    = 53,
  kDKSTKeyCodePageUp    = 116,
  kDKSTKeyCodePageDown  = 121,
  kDKSTKeyCodeLeft      = 123,
  kDKSTKeyCodeRight     = 124,
  kDKSTKeyCodeDown      = 125,
  kDKSTKeyCodeUp        = 126,
};

// Number key codes (for candidate selection)
enum {
  kDKSTKeyCodeNum1 = 18,
  kDKSTKeyCodeNum2 = 19,
  kDKSTKeyCodeNum3 = 20,
  kDKSTKeyCodeNum4 = 21,
  kDKSTKeyCodeNum6 = 22,
  kDKSTKeyCodeNum5 = 23,
  kDKSTKeyCodeNum9 = 25,
  kDKSTKeyCodeNum7 = 26,
  kDKSTKeyCodeNum8 = 28,
  kDKSTKeyCodeNum0 = 29,
};

// Advanced setup
extern NSString *const kDKSTHangulCommitByWordKey;
extern NSString *const kDKSTEnglishBypassWithOptionKey;
extern NSString *const kDKSTHanjaCommitByWordKey;
extern NSString *const kDKSTHanjaParenStyleKey;
extern NSString *const kDKSTVIModeKey;

extern NSString *const kDKSTCandidatesPanelPropertiesKey;
extern NSString *const kDKSTCandidatesPanelTypeKey;
extern NSString *const kDKSTCandidatesFontSizeKey;

extern NSString *const kDKSTIndicatorPropertiesKey;
extern NSString *const kDKSTIndicatorEnableKey;

// Dictionary setup
extern NSString *const kDKSTDisabledDictionariesKey;
extern NSString *const kDKSTDictionaryEnabledKey;
extern NSString *const kDKSTDictionaryFilenameKey;

extern NSString *const kDKSTAttributedStringEnabledKey;
extern NSString *const kDKSTFontsAttributesKey;

enum {
  kDKSTDictionaryForNilMode = -1,
  kDKSTDictionaryForAllMode = 0,
  kDKSTDictionaryForHangulMode,
  kDKSTDictionaryForRomanMode,
};

// Trigger setup
extern NSString *const kDKSTTriggerPropertiesKey;
extern NSString *const kDKSTTriggerEnableKey;
extern NSString *const kDKSTTriggerAlertKey;
extern NSString *const kDKSTTriggerChangeInputModeKey;
extern NSString *const kDKSTTriggerArrayKey;

// Remapper setup
extern NSString *const kDKSTAppSpecificSetupKey;

// Updater setup
extern NSString *const kDKSTUpdateCheckPeriodKey;
extern NSString *const kDKSTUpdateLastCheckKey;

// For developer
extern NSString *const kDKSTVerboseModeKey;

#define ANYMODMASK 0xffff0000
#define LEFTMODMASK                                                            \
  (ANYMODMASK | NX_DEVICELCTLKEYMASK | NX_DEVICELSHIFTKEYMASK |                \
   NX_DEVICELCMDKEYMASK | NX_DEVICELALTKEYMASK)
#define RIGHTMODMASK                                                           \
  (ANYMODMASK | NX_DEVICERCTLKEYMASK | NX_DEVICERSHIFTKEYMASK |                \
   NX_DEVICERCMDKEYMASK | NX_DEVICERALTKEYMASK)

#ifdef DEBUG
#define DLOG(fmt, ...)                                                         \
  NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);
#else
#define DLOG(...)
#endif

#ifdef DEBUG
#define NSLog_VM(fmt, ...)                                                     \
  NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);
#else
#define NSLog_VM(...)
#endif

// Debug logging - automatically enabled in DEBUG builds, disabled in RELEASE
#ifdef DEBUG
#define DKSTLog(fmt, ...) NSLog((@"DKST: " fmt), ##__VA_ARGS__)
#else
#define DKSTLog(...)
#endif
