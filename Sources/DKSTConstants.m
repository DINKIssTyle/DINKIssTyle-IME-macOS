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
NSString *const kDKSTEnableMoaJjikiKey = @"EnableMoaJjiki";
NSString *const kDKSTFullCharacterDeleteKey = @"FullCharacterDelete";
NSString *const kDKSTEnableHanjaKey = @"EnableHanja";
NSString *const kDKSTEnableCustomShiftKey = @"EnableCustomShift";
NSString *const kDKSTCustomShiftMappingsKey = @"DKSTCustomShiftMappings";

// Hanja custom shortcut
NSString *const kDKSTHanjaShortcutKeyCodeKey = @"DKSTHanjaShortcutKeyCode";
NSString *const kDKSTHanjaShortcutModifiersKey = @"DKSTHanjaShortcutModifiers";
NSString *const kDKSTHanjaShortcutDidChangeNotification =
    @"DKSTHanjaShortcutDidChangeNotification";

NSArray *DKSTDefaultMarkedTextAppBundleIDs(void) {
  return [NSArray
      arrayWithObjects:@"com.apple.Terminal", @"com.googlecode.iterm2",
                       @"com.microsoft.VSCode", @"com.microsoft.VSCodeInsiders",
                       @"dev.zed.Zed", @"dev.zed.Zed-Dev",
                       @"com.todesktop.230313mzl4w4u92", @"com.google.Chrome",
                       @"com.google.Chrome.canary", @"com.microsoft.edgemac",
                       @"com.openai.chat", @"com.openai.codex",
                       @"com.google.android.studio", @"com.google.antigravity",
                       @"com.dinkisstyle.translatorai",
                       @"com.dinkisstyle.terminalai",
                       @"com.dinkisstyle.nametagmaker",
                       @"com.dinkisstyle.llmchat", @"com.dinkisstyle.mdbrowser",
                       @"com.dinkisstyle.phototaggerai",
                       @"com.dinkisstyle.readerserver", nil];
}

NSString *DKSTUserDictionaryPath(void) {
  NSArray *applicationSupportPaths = NSSearchPathForDirectoriesInDomains(
      NSApplicationSupportDirectory, NSUserDomainMask, YES);
  NSString *applicationSupportPath = [applicationSupportPaths firstObject];
  if (![applicationSupportPath length]) {
    applicationSupportPath = [NSHomeDirectory()
        stringByAppendingPathComponent:@"Library/Application Support"];
  }
  return [[applicationSupportPath
      stringByAppendingPathComponent:@"DKST Korean IME"]
      stringByAppendingPathComponent:@"hanja.txt"];
}

BOOL DKSTEnsureUserDictionary(NSBundle *resourceBundle, NSError **error) {
  NSFileManager *fileManager = [NSFileManager defaultManager];
  NSString *destinationPath = DKSTUserDictionaryPath();
  BOOL isDirectory = NO;

  if ([fileManager fileExistsAtPath:destinationPath
                        isDirectory:&isDirectory]) {
    if (!isDirectory) {
      return YES;
    }

    if (error) {
      *error = [NSError
          errorWithDomain:NSCocoaErrorDomain
                     code:NSFileWriteFileExistsError
                 userInfo:@{
                   NSFilePathErrorKey : destinationPath,
                   NSLocalizedDescriptionKey :
                       @"한자 사전 파일 경로에 폴더가 존재합니다."
                 }];
    }
    return NO;
  }

  NSBundle *bundle = resourceBundle ?: [NSBundle mainBundle];
  NSString *sourcePath = [bundle pathForResource:@"hanja" ofType:@"txt"];
  if (![sourcePath length]) {
    if (error) {
      *error = [NSError
          errorWithDomain:NSCocoaErrorDomain
                     code:NSFileNoSuchFileError
                 userInfo:@{
                   NSLocalizedDescriptionKey :
                       @"앱 번들에서 기본 한자 사전을 찾지 못했습니다."
                 }];
    }
    return NO;
  }

  NSString *destinationDirectory =
      [destinationPath stringByDeletingLastPathComponent];
  if (![fileManager createDirectoryAtPath:destinationDirectory
              withIntermediateDirectories:YES
                               attributes:nil
                                    error:error]) {
    return NO;
  }

  NSData *dictionaryData =
      [NSData dataWithContentsOfFile:sourcePath options:0 error:error];
  if (!dictionaryData) {
    return NO;
  }

  return [dictionaryData writeToFile:destinationPath
                             options:NSDataWritingAtomic
                               error:error];
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
