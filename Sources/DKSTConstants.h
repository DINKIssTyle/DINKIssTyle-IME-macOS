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
