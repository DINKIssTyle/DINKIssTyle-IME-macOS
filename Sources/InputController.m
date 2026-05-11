#import "InputController.h"
#import "DKSTConstants.h"
#import "DKSTHanjaDictionary.h"

@interface InputController ()
- (BOOL)handleCandidateNavigation:(unsigned short)keyCode client:(id)sender;
- (BOOL)handleHanjaConversion:(unsigned short)keyCode
                    modifiers:(NSUInteger)modifiers
                       client:(id)sender;
- (BOOL)handleCustomShift:(unsigned short)keyCode
                modifiers:(NSUInteger)modifiers
                   client:(id)sender;
- (BOOL)processHangulInput:(NSEvent *)event
                   keyCode:(unsigned short)keyCode
                    client:(id)sender
        candidatesVisible:(BOOL)candidatesVisible;
- (BOOL)directInputRangeIsCurrent:(NSRange)range client:(id)sender;
- (BOOL)repairFirstMarkedTextLeakForClient:(id)sender
                                    keyCode:(unsigned short)keyCode
                                  modifiers:(NSUInteger)modifiers
                        selectedRangeBefore:(NSRange)selectedRangeBefore;
@end

static NSInteger DKSTCandidateIndexForNumberKeyCode(unsigned short keyCode) {
  switch (keyCode) {
  case kDKSTKeyCodeNum1: return 0;
  case kDKSTKeyCodeNum2: return 1;
  case kDKSTKeyCodeNum3: return 2;
  case kDKSTKeyCodeNum4: return 3;
  case kDKSTKeyCodeNum5: return 4;
  case kDKSTKeyCodeNum6: return 5;
  case kDKSTKeyCodeNum7: return 6;
  case kDKSTKeyCodeNum8: return 7;
  case kDKSTKeyCodeNum9: return 8;
  default: return -1;
  }
}

// DKSTRomanStringForHangulKeyCode removed — use DKSTRomanStringForKeyCode()
// from DKSTConstants (single source of truth for keyCode mapping)

@implementation InputController

static IMKCandidates *DKSTSharedCandidatesForMacOS26;

- (id)initWithServer:(IMKServer *)server
            delegate:(id)delegate
              client:(id)inputClient {
  self = [super initWithServer:server delegate:delegate client:inputClient];
  if (self) {
    DKSTLog(@"InputController initWithServer: %@ delegate: %@ client: %@",
            server, delegate, inputClient);
    engine = [[DKSTHangul alloc] init];
    currentMode = [kDKSTHangulMode retain]; // Default to Hangul (Retain)

    // Set default preference
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{
      @"EnableMoaJjiki" : @YES,
      @"FullCharacterDelete" : @NO,
      @"EnableCustomShift" : @NO,
      kDKSTUseMarkedTextForAllAppsKey : @NO,
      kDKSTUseAppleHanjaDictionaryKey : @YES,
      kDKSTMarkedTextAppBundleIDsKey : DKSTDefaultMarkedTextAppBundleIDs()
    }];

    // Note: We previously skipped IMKCandidates creation for Preferences app,
    // but this caused crashes because InputMethodKit internally accesses
    // _candidates (e.g., calling isVisible) during deactivation.
    // Always create candidates to satisfy InputMethodKit's expectations.
    NSString *clientBundleID = [inputClient bundleIdentifier];
    BOOL isPreferencesApp = [clientBundleID
        isEqualToString:@"com.dinkisstyle.inputmethod.DKST.preferences"];
    if (isPreferencesApp) {
      DKSTLog(@"Initialized for Preferences App");
    }

    // Always keep IMKCandidates available for all clients. On macOS 26 beta,
    // InputMethodKit may keep using the object after controller dealloc, so
    // reuse one process-wide instance instead of leaking one per controller.
    if (@available(macOS 26, *)) {
      @synchronized([InputController class]) {
        if (!DKSTSharedCandidatesForMacOS26) {
          DKSTSharedCandidatesForMacOS26 =
              [[IMKCandidates alloc]
                  initWithServer:server
                       panelType:kIMKSingleColumnScrollingCandidatePanel];
        }
        _candidates = DKSTSharedCandidatesForMacOS26;
      }
    } else {
      _candidates = [[IMKCandidates alloc]
          initWithServer:server
               panelType:kIMKSingleColumnScrollingCandidatePanel];
    }
    _lastClientSyncTime = 0;
    _directInputComposedLength = 0;
    _directInputComposedText = nil;
    _directInputComposedRange = NSMakeRange(NSNotFound, 0);
    _markedReplacementRange = NSMakeRange(NSNotFound, 0);
    _forcedMarkedTextBundleIDs = [[NSMutableSet alloc] init];
    _lastInputClient = inputClient;
    _lastInputClientBundleID = nil;
    _lastClientSelectedRange = NSMakeRange(NSNotFound, 0);
    _useMarkedTextForClient = NO;
    _hanjaEnabled = YES;
    _markedTextCommittedPrefix = [[NSMutableString alloc] init];
    _hanjaMarkedPrefixLength = 0;
    _hanjaReplacementUsesMarkedPrefix = NO;
    _compositionState = [[DKSTCompositionState alloc] init];
    _chromiumDetectionCache = [[NSMutableDictionary alloc] init];

    [self reloadUserPreferences];
    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(preferencesDidChange:)
               name:NSUserDefaultsDidChangeNotification
             object:nil];

    // Listen for dictionary changes from DKSTDictEditor (distributed
    // notification crosses process boundaries without killing the IME).
    [[NSDistributedNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(dictionaryDidChange:)
               name:@"DKSTDictionaryDidChangeNotification"
             object:nil];

    // Style attributes to match Apple's Korean IME
    NSDictionary *styleAttributes = @{
      IMKCandidatesSendServerKeyEventFirst : @YES,
      IMKCandidatesOpacityAttributeName : @(1.0),
      @"IMKCandidatesFont" : [NSFont systemFontOfSize:15.0
                                               weight:NSFontWeightRegular]
    };
    [_candidates setAttributes:styleAttributes];

    [_candidates
        setSelectionKeys:[NSArray arrayWithObjects:@"1", @"2", @"3", @"4", @"5",
                                                   @"6", @"7", @"8", @"9",
                                                   nil]];
  }
  return self;
}

- (void)dealloc {
  DKSTLog(@"InputController dealloc called");

  // Remove observers FIRST to prevent race conditions where a notification
  // fires during dealloc.
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [[NSDistributedNotificationCenter defaultCenter] removeObserver:self];

  // InputMethodKit on macOS 26 beta internally caches a reference to the
  // IMKCandidates object and may call methods on it after our dealloc is
  // called. The shared instance is intentionally kept alive for the process,
  // which avoids a per-controller leak while preserving the crash workaround.
  if (@available(macOS 26, *)) {
    _candidates = nil;
  } else {
    if (_candidates) {
      [_candidates release];
      _candidates = nil;
    }
  }

  if (_currentHanjaCandidates) {
    [_currentHanjaCandidates release];
    _currentHanjaCandidates = nil;
  }
  if (engine) {
    [engine release];
    engine = nil;
  }
  if (currentMode) {
    [currentMode release];
    currentMode = nil;
  }
  if (_directInputComposedText) {
    [_directInputComposedText release];
    _directInputComposedText = nil;
  }
  if (_forcedMarkedTextBundleIDs) {
    [_forcedMarkedTextBundleIDs release];
    _forcedMarkedTextBundleIDs = nil;
  }
  if (_customShiftMappings) {
    [_customShiftMappings release];
    _customShiftMappings = nil;
  }
  if (_markedTextBundleIDSet) {
    [_markedTextBundleIDSet release];
    _markedTextBundleIDSet = nil;
  }
  if (_markedTextCommittedPrefix) {
    [_markedTextCommittedPrefix release];
    _markedTextCommittedPrefix = nil;
  }
  if (_compositionState) {
    [_compositionState release];
    _compositionState = nil;
  }
  if (_lastInputClientBundleID) {
    [_lastInputClientBundleID release];
    _lastInputClientBundleID = nil;
  }
  if (_chromiumDetectionCache) {
    [_chromiumDetectionCache release];
    _chromiumDetectionCache = nil;
  }
  // (observers already removed at top of dealloc)
  [super dealloc];
}

- (NSString *)bundleIdentifierForClient:(id)sender {
  // IMK clients are XPC proxies, so bundleIdentifier can cross process
  // boundaries. Cache it for this activation and clear it in activateServer:
  // to keep the hot key path from paying that IPC cost repeatedly.
  if ([_lastInputClientBundleID length] > 0) {
    return _lastInputClientBundleID;
  }

  NSString *bundleID = nil;

  @try {
    if (sender && [sender respondsToSelector:@selector(bundleIdentifier)]) {
      bundleID = [sender bundleIdentifier];
    }
    if (!bundleID && [[self client] respondsToSelector:@selector(bundleIdentifier)]) {
      bundleID = [[self client] bundleIdentifier];
    }
  } @catch (NSException *exception) {
    DKSTLog(@"Exception getting client bundle id: %@", exception);
  }

  [_lastInputClientBundleID release];
  _lastInputClientBundleID = [bundleID copy];

  return bundleID;
}

- (void)forceMarkedTextForClient:(id)sender reason:(NSString *)reason {
  NSString *bundleID = [self bundleIdentifierForClient:sender];
  if ([bundleID length] > 0) {
    [_forcedMarkedTextBundleIDs addObject:bundleID];
  }
  _useMarkedTextForClient = YES;
  DKSTLog(@"Forcing marked text for %@: %@", bundleID ?: @"unknown client",
          reason);
}

- (BOOL)bundleIdentifier:(NSString *)bundleID
          matchesPattern:(NSString *)pattern {
  if (![bundleID length] || ![pattern length]) {
    return NO;
  }

  NSRange wildcardRange = [pattern rangeOfString:@"*"];
  if (wildcardRange.location == NSNotFound) {
    return [bundleID isEqualToString:pattern];
  }

  NSString *prefix = [pattern substringToIndex:wildcardRange.location];
  NSString *suffix = [pattern substringFromIndex:NSMaxRange(wildcardRange)];
  return ([prefix length] == 0 || [bundleID hasPrefix:prefix]) &&
         ([suffix length] == 0 || [bundleID hasSuffix:suffix]) &&
         [bundleID length] >= [prefix length] + [suffix length];
}

- (BOOL)bundleIdentifierMatchesMarkedTextConfiguration:(NSString *)bundleID {
  if (![bundleID length]) {
    return NO;
  }

  for (NSString *pattern in _markedTextBundleIDSet) {
    if (![pattern isKindOfClass:[NSString class]]) {
      continue;
    }
    if ([self bundleIdentifier:bundleID matchesPattern:pattern]) {
      return YES;
    }
  }

  return NO;
}

- (BOOL)bundleIdentifierUsesWebKitTextStack:(NSString *)bundleID {
  if (![bundleID length]) {
    return NO;
  }

  NSArray *webkitBundlePrefixes =
      [NSArray arrayWithObjects:@"com.apple.Safari",
                                @"com.apple.WebKit",
                                @"com.apple.mobilesafari", nil];

  for (NSString *prefix in webkitBundlePrefixes) {
    if ([bundleID isEqualToString:prefix] ||
        [bundleID hasPrefix:[prefix stringByAppendingString:@"."]]) {
      return YES;
    }
  }

  return NO;
}

- (BOOL)shouldAvoidEagerSyncForClient:(id)sender {
  return [self clientUsesWebKitTextStack:sender];
}

- (BOOL)shouldTrustDirectCompositionRangeForClient:(id)sender {
  return [self clientUsesWebKitTextStack:sender];
}

- (BOOL)clientUsesWebKitTextStack:(id)sender {
  NSString *bundleID = [self bundleIdentifierForClient:sender];
  return [self bundleIdentifierUsesWebKitTextStack:bundleID];
}

- (BOOL)bundleIdentifierUsesChromiumMarkedTextPolicy:(NSString *)bundleID {
  if (![bundleID length]) {
    return NO;
  }

  NSArray *chromiumBundlePrefixes = [NSArray
      arrayWithObjects:@"org.chromium.Chromium", @"com.google.Chrome",
                       @"com.google.Chrome.canary", @"com.microsoft.edgemac",
                       @"com.brave.Browser", @"com.vivaldi.Vivaldi",
                       @"com.operasoftware.Opera", @"com.naver.Whale",
                       @"company.thebrowser.Browser", @"ai.perplexity.comet",
                       @"com.perplexity.Comet", @"com.perplexity.comet",
                       @"com.openai.atlas", @"com.openai.Atlas",
                       @"com.openai.chatgpt.atlas", nil];

  for (NSString *prefix in chromiumBundlePrefixes) {
    if ([bundleID isEqualToString:prefix] ||
        [bundleID hasPrefix:[prefix stringByAppendingString:@"."]]) {
      return YES;
    }
  }

  return NO;
}

- (BOOL)applicationBundleUsesChromiumTextStack:(NSURL *)bundleURL {
  if (!bundleURL) {
    return NO;
  }

  NSString *bundlePath = [bundleURL path];
  if (![bundlePath length]) {
    return NO;
  }

  NSNumber *cachedResult = [_chromiumDetectionCache objectForKey:bundlePath];
  if (cachedResult) {
    return [cachedResult boolValue];
  }

  NSString *frameworksPath =
      [bundlePath stringByAppendingPathComponent:@"Contents/Frameworks"];
  NSFileManager *fm = [NSFileManager defaultManager];
  BOOL isDirectory = NO;
  if (![fm fileExistsAtPath:frameworksPath isDirectory:&isDirectory] ||
      !isDirectory) {
    [_chromiumDetectionCache setObject:[NSNumber numberWithBool:NO]
                                forKey:bundlePath];
    return NO;
  }

  NSArray *frameworkNames = [fm contentsOfDirectoryAtPath:frameworksPath
                                                    error:nil];
  NSArray *chromiumFrameworkNames =
      [NSArray arrayWithObjects:@"Electron Framework.framework",
                                @"Chromium Embedded Framework.framework",
                                @"Google Chrome Framework.framework",
                                @"Microsoft Edge Framework.framework",
                                @"Brave Browser Framework.framework",
                                @"Vivaldi Framework.framework",
                                @"Opera Framework.framework", nil];

  for (NSString *frameworkName in frameworkNames) {
    if ([chromiumFrameworkNames containsObject:frameworkName]) {
      [_chromiumDetectionCache setObject:[NSNumber numberWithBool:YES]
                                  forKey:bundlePath];
      return YES;
    }
    if ([frameworkName rangeOfString:@"Chromium"
                             options:NSCaseInsensitiveSearch].location !=
            NSNotFound ||
        [frameworkName rangeOfString:@"Electron"
                             options:NSCaseInsensitiveSearch].location !=
            NSNotFound) {
      [_chromiumDetectionCache setObject:[NSNumber numberWithBool:YES]
                                  forKey:bundlePath];
      return YES;
    }
  }

  [_chromiumDetectionCache setObject:[NSNumber numberWithBool:NO]
                              forKey:bundlePath];
  return NO;
}

- (BOOL)runningApplicationUsesChromiumTextStack:(NSString *)bundleID {
  if (![bundleID length]) {
    return NO;
  }

  // The fallback Chromium check can enumerate running apps and inspect bundle
  // frameworks on disk. Cache both YES and NO by bundle ID so first-key policy
  // detection does not repeatedly block the input path.
  NSString *cacheKey = [@"bundle:" stringByAppendingString:bundleID];
  NSNumber *cachedResult = [_chromiumDetectionCache objectForKey:cacheKey];
  if (cachedResult) {
    return [cachedResult boolValue];
  }

  NSArray *runningApps =
      [NSRunningApplication runningApplicationsWithBundleIdentifier:bundleID];
  for (NSRunningApplication *app in runningApps) {
    NSString *appName = [[app localizedName] lowercaseString];
    NSString *bundleName =
        [[[[app bundleURL] lastPathComponent] stringByDeletingPathExtension]
            lowercaseString];
    if ([appName isEqualToString:@"comet"] ||
        [bundleName isEqualToString:@"comet"] ||
        [appName isEqualToString:@"atlas"] ||
        [bundleName isEqualToString:@"atlas"] ||
        [appName isEqualToString:@"chatgpt atlas"] ||
        [bundleName isEqualToString:@"chatgpt atlas"]) {
      [_chromiumDetectionCache setObject:[NSNumber numberWithBool:YES]
                                  forKey:cacheKey];
      return YES;
    }

    if ([self applicationBundleUsesChromiumTextStack:[app bundleURL]]) {
      [_chromiumDetectionCache setObject:[NSNumber numberWithBool:YES]
                                  forKey:cacheKey];
      return YES;
    }
  }

  [_chromiumDetectionCache setObject:[NSNumber numberWithBool:NO]
                              forKey:cacheKey];
  return NO;
}

- (BOOL)directInputRangeIsCurrent:(NSRange)range client:(id)sender {
  if (!sender || range.location == NSNotFound ||
      range.length != _directInputComposedLength ||
      _directInputComposedLength == 0 ||
      [_directInputComposedText length] != _directInputComposedLength) {
    return NO;
  }

  if (NSMaxRange(range) < range.location) {
    return NO;
  }

  @try {
    if ([sender respondsToSelector:@selector(selectedRange)]) {
      NSRange selectedRange = [sender selectedRange];
      if (selectedRange.location != NSNotFound &&
          selectedRange.length == 0 &&
          selectedRange.location < NSMaxRange(range)) {
        return NO;
      }
    }

    if ([sender respondsToSelector:@selector(attributedSubstringFromRange:)]) {
      NSAttributedString *textInRange =
          [sender attributedSubstringFromRange:range];
      if (![[textInRange string] isEqualToString:_directInputComposedText]) {
        DKSTLog(@"Direct input range %@ contains '%@', expected '%@'",
                NSStringFromRange(range), [textInRange string],
                _directInputComposedText);
        return NO;
      }
    }
  } @catch (NSException *exception) {
    DKSTLog(@"Stale direct input range %@: %@",
            NSStringFromRange(range), exception);
    return NO;
  }

  return YES;
}

- (NSRange)directInputReplacementRange:(id)sender {
  if (_directInputComposedLength == 0 || !sender) {
    return _directInputComposedRange;
  }

  if ([self shouldTrustDirectCompositionRangeForClient:sender] &&
      [self directInputRangeIsCurrent:_directInputComposedRange
                               client:sender]) {
    return _directInputComposedRange;
  }

  @try {
    NSRange selectedRange = [sender selectedRange];
    if (selectedRange.location != NSNotFound &&
        selectedRange.length == 0 &&
        selectedRange.location >= _directInputComposedLength) {
      NSRange selectedBacktrackRange =
          NSMakeRange(selectedRange.location - _directInputComposedLength,
                      _directInputComposedLength);
      if ([self directInputRangeIsCurrent:selectedBacktrackRange
                                   client:sender]) {
        return selectedBacktrackRange;
      }
    }
  } @catch (NSException *exception) {
    DKSTLog(@"Exception in directInputReplacementRange: %@", exception);
  }

  if ([self directInputRangeIsCurrent:_directInputComposedRange
                               client:sender]) {
    return _directInputComposedRange;
  }

  DKSTLog(@"Dropping stale direct input range %@",
          NSStringFromRange(_directInputComposedRange));
  [self clearDirectInputState];
  [self clearMarkedReplacementRange];
  [_compositionState resetTransientRanges];
  return NSMakeRange(NSNotFound, 0);
}

- (NSRange)compositionReplacementRange:(id)sender {
  if (_selectedTextRange.location != NSNotFound &&
      _selectedTextRange.length > 0) {
    return _selectedTextRange;
  }
  if (_directInputComposedLength > 0) {
    return [self directInputReplacementRange:sender];
  }
  if (_markedReplacementRange.location != NSNotFound) {
    return _markedReplacementRange;
  }

  NSString *composed = [engine composedString];
  if ([composed length] > 0) {
    return NSMakeRange(0, [composed length]);
  }
  return NSMakeRange(NSNotFound, 0);
}

- (NSString *)textBeforeCursorForClient:(id)sender
                                  limit:(NSUInteger)limit
                                  range:(NSRange *)outRange {
  if (outRange) {
    *outRange = NSMakeRange(NSNotFound, 0);
  }
  if (!sender || ![sender respondsToSelector:@selector(selectedRange)] ||
      ![sender respondsToSelector:@selector(attributedSubstringFromRange:)]) {
    return nil;
  }

  @try {
    NSRange selectedRange = [sender selectedRange];
    if (selectedRange.location == NSNotFound || selectedRange.length > 0) {
      return nil;
    }

    NSUInteger length = MIN(limit, selectedRange.location);
    if (length == 0) {
      return nil;
    }

    NSRange contextRange = NSMakeRange(selectedRange.location - length, length);
    NSAttributedString *contextAttr =
        [sender attributedSubstringFromRange:contextRange];
    NSString *context = [contextAttr string];
    if ([context length] == 0) {
      return nil;
    }

    if (outRange) {
      *outRange = contextRange;
    }
    return context;
  } @catch (NSException *exception) {
    DKSTLog(@"textBeforeCursorForClient failed: %@", exception);
    return nil;
  }
}

- (NSString *)hangulTextForHanjaConversion:(id)sender
                                      range:(NSRange *)outRange {
  _hanjaMarkedPrefixLength = 0;
  _hanjaReplacementUsesMarkedPrefix = NO;

  if (outRange) {
    *outRange = NSMakeRange(NSNotFound, 0);
  }

  @try {
    if ([sender respondsToSelector:@selector(selectedRange)] &&
        [sender respondsToSelector:@selector(attributedSubstringFromRange:)]) {
      NSRange selectedRange = [sender selectedRange];
      if (selectedRange.location != NSNotFound && selectedRange.length > 0) {
        NSAttributedString *selectedAttr =
            [sender attributedSubstringFromRange:selectedRange];
        NSString *selectedText = [selectedAttr string];
        if ([selectedText length] > 0) {
          if (outRange) {
            *outRange = selectedRange;
          }
          return selectedText;
        }
      }
    }
  } @catch (NSException *exception) {
    DKSTLog(@"selected text Hanja target lookup failed: %@", exception);
  }

  NSString *composed = [engine composedString];
  if (_useMarkedTextForClient && [composed length] > 0 &&
      [_markedTextCommittedPrefix length] > 0) {
    NSString *markedText =
        [_markedTextCommittedPrefix stringByAppendingString:composed];
    for (NSUInteger start = 0; start < [markedText length]; start++) {
      NSString *candidateText = [markedText substringFromIndex:start];
      NSArray *matches =
          [[DKSTHanjaDictionary sharedDictionary] hanjaForHangul:candidateText];
      if ([matches count] > 0) {
        if (outRange) {
          NSRange compositionRange = [self compositionReplacementRange:sender];
          *outRange = NSMakeRange(compositionRange.location,
                                  [candidateText length]);
        }
        _hanjaMarkedPrefixLength =
            [candidateText length] > [composed length]
                ? [candidateText length] - [composed length]
                : 0;
        _hanjaReplacementUsesMarkedPrefix = (_hanjaMarkedPrefixLength > 0);
        return candidateText;
      }
    }
  }

  NSRange contextRange = NSMakeRange(NSNotFound, 0);
  NSString *context = [self textBeforeCursorForClient:sender
                                                limit:20
                                                range:&contextRange];
  if ([context length] > 0) {
    NSUInteger suffixStart = [context length];
    while (suffixStart > 0) {
      unichar c = [context characterAtIndex:suffixStart - 1];
      if (c < 0xAC00 || c > 0xD7A3) {
        break;
      }
      suffixStart--;
    }

    NSString *hangulSuffix = [context substringFromIndex:suffixStart];
    for (NSUInteger start = 0; start < [hangulSuffix length]; start++) {
      NSString *candidateText = [hangulSuffix substringFromIndex:start];
      NSArray *matches =
          [[DKSTHanjaDictionary sharedDictionary] hanjaForHangul:candidateText];
      if ([matches count] > 0) {
        NSRange range = NSMakeRange(contextRange.location + suffixStart + start,
                                    [candidateText length]);
        if (outRange) {
          *outRange = range;
        }
        return candidateText;
      }
    }
  }

  if ([composed length] > 0) {
    if (outRange) {
      *outRange = [self compositionReplacementRange:sender];
    }
    return composed;
  }

  return nil;
}

- (BOOL)showHanjaCandidatesForText:(NSString *)text
                   replacementRange:(NSRange)replacementRange
                             client:(id)sender {
  if ([text length] == 0 || replacementRange.location == NSNotFound ||
      replacementRange.length == 0) {
    return NO;
  }

  NSArray *candidates =
      [[DKSTHanjaDictionary sharedDictionary] hanjaForHangul:text];

  NSMutableArray *allCandidates = [NSMutableArray array];
  if ([candidates count] > 0) {
    [allCandidates addObjectsFromArray:candidates];
  }

  NSString *originalText = text;
  if ([originalText length] > 10) {
    originalText =
        [[originalText substringToIndex:10] stringByAppendingString:@"..."];
  }
  [allCandidates addObject:originalText];

  if (_currentHanjaCandidates) {
    [_currentHanjaCandidates release];
  }
  _currentHanjaCandidates = [allCandidates retain];
  _selectedTextRange = replacementRange;
  [self setMarkedReplacementRange:replacementRange];

  DKSTLog(@"Candidates for '%@': count=%lu range=(%lu,%lu)", text,
          (unsigned long)[allCandidates count],
          (unsigned long)replacementRange.location,
          (unsigned long)replacementRange.length);

  [_candidates updateCandidates];
  [_candidates show:kIMKLocateCandidatesBelowHint];

  _currentHanjaIndex = 0;
  NSInteger firstId = [_candidates candidateIdentifierAtLineNumber:0];
  if (firstId != NSNotFound) {
    [_candidates selectCandidateWithIdentifier:firstId];
  }
  return YES;
}

- (BOOL)shouldUseMarkedTextForClient:(id)sender {
  if (_useMarkedTextForAllApps) {
    return YES;
  }

  // 1. Apple Native Private API Query (마크드 텍스트 네이티브 지원 여부 확인)
  //    KIM queries textDocument.showsComposingTextAsMarkedText (§4.1, §4.4)
  //    Try textDocument (via self) first, then sender as fallback.
  SEL showsComposingTextSel =
      NSSelectorFromString(@"showsComposingTextAsMarkedText");
  SEL textDocSel = NSSelectorFromString(@"textDocument");

  // textDocument proxy first (matches KIM's IMKActiveCompositionController)
  if ([self respondsToSelector:textDocSel]) {
    id textDocument =
        ((id (*)(id, SEL))[self methodForSelector:textDocSel])(self,
                                                               textDocSel);
    if (textDocument &&
        [textDocument respondsToSelector:showsComposingTextSel]) {
      BOOL showsMarked =
          ((BOOL (*)(id, SEL))[textDocument
              methodForSelector:showsComposingTextSel])(
              textDocument, showsComposingTextSel);
      DKSTLog(@"textDocument.showsComposingTextAsMarkedText = %d",
              showsMarked);
      return showsMarked;
    }
  }

  // Fallback: check sender (client proxy) directly
  if ([sender respondsToSelector:showsComposingTextSel]) {
    BOOL showsMarked =
        ((BOOL (*)(id, SEL))[sender methodForSelector:showsComposingTextSel])(
            sender, showsComposingTextSel);
    return showsMarked;
  }

  // 2. Fallback to Bundle ID heuristics (기존 Bundle ID 기반 예외 처리)
  NSString *bundleID = [self bundleIdentifierForClient:sender];

  if (![bundleID length]) {
    return YES;
  }

  if ([_forcedMarkedTextBundleIDs containsObject:bundleID]) {
    return YES;
  }

  if ([self bundleIdentifierUsesWebKitTextStack:bundleID]) {
    return NO;
  }

  if ([self bundleIdentifierMatchesMarkedTextConfiguration:bundleID]) {
    return YES;
  }

  if ([self bundleIdentifierUsesChromiumMarkedTextPolicy:bundleID] ||
      [self runningApplicationUsesChromiumTextStack:bundleID]) {
    return YES;
  }

  if (![sender respondsToSelector:@selector(selectedRange)]) {
    return YES;
  }

  // Avoid calling selectedRange while deciding direct vs marked policy. That
  // crosses the IMK XPC boundary and can block for seconds during focus/input
  // mode transitions. Direct input is started provisionally; the actual input
  // path still validates ranges and can force marked text if the client cannot
  // keep up.
  return NO;
}

- (void)refreshMarkedTextPolicyForClient:(id)sender {
  _useMarkedTextForClient = [self shouldUseMarkedTextForClient:sender];
}

- (BOOL)isHangulKeyCode:(unsigned short)keyCode {
  return DKSTIsHangulKeyCode(keyCode);
}

- (BOOL)repairFirstMarkedTextLeakForClient:(id)sender
                                    keyCode:(unsigned short)keyCode
                                  modifiers:(NSUInteger)modifiers
                        selectedRangeBefore:(NSRange)selectedRangeBefore {
  if (!_useMarkedTextForClient || !sender ||
      _markedReplacementRange.location != NSNotFound ||
      _directInputComposedLength != 0 ||
      selectedRangeBefore.location == NSNotFound ||
      selectedRangeBefore.length != 0) {
    return NO;
  }

  NSString *bundleID = [self bundleIdentifierForClient:sender];
  BOOL isMarkedPolicyTarget =
      _useMarkedTextForAllApps ||
      ([bundleID length] > 0 &&
       ([_forcedMarkedTextBundleIDs containsObject:bundleID] ||
        [self bundleIdentifierMatchesMarkedTextConfiguration:bundleID] ||
        [self bundleIdentifierUsesChromiumMarkedTextPolicy:bundleID] ||
        [self runningApplicationUsesChromiumTextStack:bundleID]));
  if (!isMarkedPolicyTarget ||
      [self bundleIdentifierUsesWebKitTextStack:bundleID]) {
    return NO;
  }

  NSString *roman = DKSTRomanStringForKeyCode(keyCode, modifiers);
  if ([roman length] == 0 ||
      ![sender respondsToSelector:@selector(selectedRange)] ||
      ![sender respondsToSelector:@selector(attributedSubstringFromRange:)]) {
    return NO;
  }

  @try {
    NSRange selectedRangeAfter = [sender selectedRange];
    if (selectedRangeAfter.location != selectedRangeBefore.location + 1 ||
        selectedRangeAfter.length != 0 || selectedRangeAfter.location == 0) {
      return NO;
    }

    NSRange leakedRange = NSMakeRange(selectedRangeAfter.location - 1, 1);
    NSAttributedString *leakedText =
        [sender attributedSubstringFromRange:leakedRange];
    if (![[leakedText string] isEqualToString:roman]) {
      return NO;
    }

    [self setMarkedReplacementRange:leakedRange];
    DKSTLog(@"Repairing first marked-text roman leak at %@ for %@",
            NSStringFromRange(leakedRange), bundleID ?: @"unknown client");
    return YES;
  } @catch (NSException *exception) {
    DKSTLog(@"Exception repairing first marked-text leak: %@", exception);
    return NO;
  }
}

- (void)syncInputClient:(id)sender force:(BOOL)force {
  if (!sender) {
    return;
  }

  NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
  if (!force && _lastClientSyncTime > 0 && now - _lastClientSyncTime < 0.5) {
    return;
  }

  if ([self shouldAvoidEagerSyncForClient:sender]) {
    _lastClientSyncTime = now;
    return;
  }

  @try {
    [sender overrideKeyboardWithKeyboardNamed:kUSKeylayout];
    if (force) {
      [sender selectInputMode:currentMode];
    }
    _lastClientSyncTime = now;
  } @catch (NSException *exception) {
    DKSTLog(@"Exception in syncInputClient: %@", exception);
  }
}

- (void)clearDirectInputState {
  _directInputComposedLength = 0;
  [_directInputComposedText release];
  _directInputComposedText = nil;
  _directInputComposedRange = NSMakeRange(NSNotFound, 0);
}

- (void)resetCompositionState {
  [engine reset];
  [self clearDirectInputState];
  _markedReplacementRange = NSMakeRange(NSNotFound, 0);
  _selectedTextRange = NSMakeRange(NSNotFound, 0);
  _lastClientSelectedRange = NSMakeRange(NSNotFound, 0);
  _currentHanjaIndex = 0;
  [_markedTextCommittedPrefix setString:@""];
  _hanjaMarkedPrefixLength = 0;
  _hanjaReplacementUsesMarkedPrefix = NO;
  [_compositionState reset];
}

- (BOOL)hasPendingComposition {
  return [[engine composedString] length] > 0 ||
          _directInputComposedLength > 0 ||
          _markedReplacementRange.location != NSNotFound;
}

- (void)setMarkedReplacementRange:(NSRange)range {
  _markedReplacementRange = range;
  if (range.location == NSNotFound) {
    [_compositionState clearReplacementRange];
  } else {
    [_compositionState markReplacementRange:range];
  }
}

- (void)clearMarkedReplacementRange {
  [self setMarkedReplacementRange:NSMakeRange(NSNotFound, 0)];
}

- (void)rememberSelectedRangeForClient:(id)sender {
  if (!sender || ![sender respondsToSelector:@selector(selectedRange)]) {
    _lastClientSelectedRange = NSMakeRange(NSNotFound, 0);
    return;
  }

  @try {
    _lastClientSelectedRange = [sender selectedRange];
  } @catch (NSException *exception) {
    DKSTLog(@"Exception remembering selected range: %@", exception);
    _lastClientSelectedRange = NSMakeRange(NSNotFound, 0);
  }
}

- (void)prepareForInputClient:(id)sender {
  if (!sender) {
    return;
  }

  BOOL clientChanged = (_lastInputClient && _lastInputClient != sender);
  if (clientChanged) {
    DKSTLog(@"Input client changed; clearing pending composition");

    @try {
      if ([_candidates isVisible]) {
        [_candidates hide];
      }
    } @catch (NSException *exception) {
      DKSTLog(@"Exception hiding candidates on client change: %@", exception);
    }

    if ([self hasPendingComposition]) {
      @try {
        [self commitComposition:_lastInputClient];
      } @catch (NSException *exception) {
        DKSTLog(@"Exception committing previous client composition: %@",
                exception);
        [self resetCompositionState];
      }
    }
  }

  if (clientChanged || _lastInputClient != sender) {
    [self refreshMarkedTextPolicyForClient:sender];
  }

  if (clientChanged && _useMarkedTextForClient) {
    @try {
      [sender setMarkedText:@""
             selectionRange:NSMakeRange(0, 0)
           replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
    } @catch (NSException *exception) {
      DKSTLog(@"Exception clearing new client marked text: %@", exception);
    }
  }

  if (!_useMarkedTextForClient && [self hasPendingComposition] &&
      _lastClientSelectedRange.location != NSNotFound &&
      [sender respondsToSelector:@selector(selectedRange)]) {
    @try {
      NSRange selectedRange = [sender selectedRange];
      if (selectedRange.location != NSNotFound &&
          !NSEqualRanges(selectedRange, _lastClientSelectedRange)) {
        DKSTLog(@"Selection changed during composition; next key starts a new direct composition");
        [self resetCompositionState];
        [sender setMarkedText:@""
               selectionRange:NSMakeRange(0, 0)
             replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
      }
    } @catch (NSException *exception) {
      DKSTLog(@"Exception checking selected range on client prepare: %@",
              exception);
    }
  }

  _lastInputClient = sender;
}

- (void)reloadUserPreferences {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

  _moaJjikiEnabled = [defaults boolForKey:@"EnableMoaJjiki"];
  [engine setMoaJjikiEnabled:_moaJjikiEnabled];

  _fullCharacterDeleteEnabled = [defaults boolForKey:@"FullCharacterDelete"];
  [engine setFullCharacterDelete:_fullCharacterDeleteEnabled];

  _customShiftEnabled = [defaults boolForKey:@"EnableCustomShift"];
  _useMarkedTextForAllApps =
      [defaults boolForKey:kDKSTUseMarkedTextForAllAppsKey];
  if ([defaults objectForKey:@"EnableHanja"] != nil) {
    _hanjaEnabled = [defaults boolForKey:@"EnableHanja"];
  } else {
    _hanjaEnabled = YES;
  }

  NSDictionary *mappings = [defaults dictionaryForKey:@"DKSTCustomShiftMappings"];
  if (_customShiftMappings != mappings) {
    [_customShiftMappings release];
    _customShiftMappings = [mappings copy];
  }

  NSArray *bundleIDs = [defaults arrayForKey:kDKSTMarkedTextAppBundleIDsKey];
  if (![bundleIDs count]) {
    bundleIDs = DKSTDefaultMarkedTextAppBundleIDs();
  }

  NSMutableSet *normalizedBundleIDs = [NSMutableSet set];
  NSCharacterSet *whitespace =
      [NSCharacterSet whitespaceAndNewlineCharacterSet];
  for (NSString *bundleID in bundleIDs) {
    if (![bundleID isKindOfClass:[NSString class]]) {
      continue;
    }
    NSString *trimmed = [bundleID stringByTrimmingCharactersInSet:whitespace];
    if ([trimmed length] > 0) {
      [normalizedBundleIDs addObject:trimmed];
    }
  }

  [_markedTextBundleIDSet release];
  _markedTextBundleIDSet = [normalizedBundleIDs copy];
}

- (void)preferencesDidChange:(NSNotification *)notification {
  [self reloadUserPreferences];
  if (_lastInputClient) {
    [self refreshMarkedTextPolicyForClient:_lastInputClient];
  }
}

// MARK: - Input Method Kit Methods

- (void)dictionaryDidChange:(NSNotification *)notification {
  DKSTLog(@"Received DKSTDictionaryDidChangeNotification — reloading");
  [[DKSTHanjaDictionary sharedDictionary] reloadDictionary];
}

- (void)activateServer:(id)sender {
  DKSTLog(@"activateServer called");

  // Fix: Initialize current mode SAFELY before using it
  // Since we rely on system switching, this Input Method should always be in
  // Hangul mode when active.
  if (currentMode != kDKSTHangulMode) {
    [currentMode release];
    currentMode = [kDKSTHangulMode retain];
  }

  // Always call super first
  [super activateServer:sender];

  _lastInputClient = sender;
  [_lastInputClientBundleID release];
  _lastInputClientBundleID = nil;

  // Force keyboard override and input mode selection.
  // Reset sync time to ensure override is re-applied even if the XPC
  // connection was re-established after an endpoint invalidation.
  _lastClientSyncTime = 0;
  [self syncInputClient:sender force:YES];

  [self reloadUserPreferences];
  [self refreshMarkedTextPolicyForClient:sender];

  // Ensure clean state and force Hangul mode on activation
  [self resetCompositionState];
}

- (void)deactivateServer:(id)sender {
  DKSTLog(@"deactivateServer called");

  // NOTE: Do NOT manipulate _candidates here!
  // InputMethodKit manages candidates internally and accessing it during
  // deactivation can cause crashes if InputMethodKit has already released
  // internal references.

  // Clear our own Hanja candidates data only
  if (_currentHanjaCandidates) {
    [_currentHanjaCandidates release];
    _currentHanjaCandidates = nil;
  }
  _currentHanjaIndex = 0;

  // Commit any pending composition
  @try {
    [self commitComposition:sender];
  } @catch (NSException *exception) {
    DKSTLog(@"Exception in deactivateServer (commit): %@", exception);
  }

  // Call super - this is required for proper cleanup
  [super deactivateServer:sender];
}

// MARK: - Extracted Input Handling Methods

- (BOOL)handleCandidateNavigation:(unsigned short)keyCode client:(id)sender {
  DKSTLog(@"Candidate window is visible, keyCode=%d", keyCode);
  BOOL hasCandidates =
      _currentHanjaCandidates && [_currentHanjaCandidates count] > 0;

  if (keyCode == kDKSTKeyCodeUp) {
    if (hasCandidates) {
      _currentHanjaIndex--;
      if (_currentHanjaIndex < 0) {
        _currentHanjaIndex = [_currentHanjaCandidates count] - 1;
      }
      [_candidates performSelector:@selector(moveUp:) withObject:sender];
      DKSTLog(@"Arrow Up: Index is now %ld", (long)_currentHanjaIndex);
    }
    return YES;
  }

  if (keyCode == kDKSTKeyCodeDown) {
    if (hasCandidates) {
      _currentHanjaIndex++;
      if (_currentHanjaIndex >= [_currentHanjaCandidates count]) {
        _currentHanjaIndex = 0;
      }
      [_candidates performSelector:@selector(moveDown:) withObject:sender];
      DKSTLog(@"Arrow Down: Index is now %ld", (long)_currentHanjaIndex);
    }
    return YES;
  }

  if (keyCode == kDKSTKeyCodeRight) {
    if (hasCandidates) {
      _currentHanjaIndex++;
      if (_currentHanjaIndex >= [_currentHanjaCandidates count]) {
        _currentHanjaIndex = 0;
      }
      [_candidates performSelector:@selector(moveRight:) withObject:sender];
    }
    return YES;
  }

  if (keyCode == kDKSTKeyCodeLeft) {
    if (hasCandidates) {
      _currentHanjaIndex--;
      if (_currentHanjaIndex < 0) {
        _currentHanjaIndex = [_currentHanjaCandidates count] - 1;
      }
      [_candidates performSelector:@selector(moveLeft:) withObject:sender];
    }
    return YES;
  }

  if (keyCode == kDKSTKeyCodePageUp) {
    if (hasCandidates) {
      _currentHanjaIndex -= 9;
      if (_currentHanjaIndex < 0) _currentHanjaIndex = 0;
      [_candidates performSelector:@selector(pageUp:) withObject:sender];
    }
    return YES;
  }

  if (keyCode == kDKSTKeyCodePageDown) {
    if (hasCandidates) {
      _currentHanjaIndex += 9;
      if (_currentHanjaIndex >= [_currentHanjaCandidates count])
        _currentHanjaIndex = [_currentHanjaCandidates count] - 1;
      [_candidates performSelector:@selector(pageDown:) withObject:sender];
    }
    return YES;
  }

  if (keyCode == kDKSTKeyCodeEscape) {
    [_candidates hide];
    return YES;
  }

  if (keyCode == kDKSTKeyCodeReturn || keyCode == kDKSTKeyCodeSpace) {
    DKSTLog(@"Enter/Space pressed. Current Index: %ld",
            (long)_currentHanjaIndex);
    if (hasCandidates && _currentHanjaIndex >= 0 &&
        _currentHanjaIndex < [_currentHanjaCandidates count]) {
      NSString *selected =
          [_currentHanjaCandidates objectAtIndex:_currentHanjaIndex];
      DKSTLog(@"Committing manually tracked candidate: %@", selected);
      [self commitCandidate:selected client:sender];
    } else {
      [_candidates hide];
    }
    return YES;
  }

  // Number keys 1-9 for direct candidate selection
  NSInteger index = DKSTCandidateIndexForNumberKeyCode(keyCode);
  if (index >= 0) {
    if (hasCandidates && index < [_currentHanjaCandidates count]) {
      _currentHanjaIndex = index;
      NSString *selected =
          [_currentHanjaCandidates objectAtIndex:_currentHanjaIndex];
      [self commitCandidate:selected client:sender];
    }
    return YES;
  }

  // Character key while candidates open: hide and fall through
  [_candidates hide];
  return NO;
}

- (BOOL)handleHanjaConversion:(unsigned short)keyCode
                    modifiers:(NSUInteger)modifiers
                       client:(id)sender {
  if (!_hanjaEnabled || keyCode != kDKSTKeyCodeReturn ||
      modifiers != NSEventModifierFlagOption) {
    return NO;
  }

  NSRange conversionRange = NSMakeRange(NSNotFound, 0);
  NSString *conversionText =
      [self hangulTextForHanjaConversion:sender range:&conversionRange];
  return [self showHanjaCandidatesForText:conversionText
                        replacementRange:conversionRange
                                  client:sender];
}

- (BOOL)handleCustomShift:(unsigned short)keyCode
                modifiers:(NSUInteger)modifiers
                   client:(id)sender {
  if (!_customShiftEnabled || modifiers != NSEventModifierFlagShift) {
    return NO;
  }

  NSString *lookupKey = nil;
  switch (keyCode) {
  case 16:  lookupKey = @"y (ㅛ)"; break;
  case 32:  lookupKey = @"u (ㅕ)"; break;
  case 34:  lookupKey = @"i (ㅑ)"; break;
  case 0:   lookupKey = @"a (ㅁ)"; break;
  case 1:   lookupKey = @"s (ㄴ)"; break;
  case 2:   lookupKey = @"d (ㅇ)"; break;
  case 3:   lookupKey = @"f (ㄹ)"; break;
  case 5:   lookupKey = @"g (ㅎ)"; break;
  case 4:   lookupKey = @"h (ㅗ)"; break;
  case 38:  lookupKey = @"j (ㅓ)"; break;
  case 40:  lookupKey = @"k (ㅏ)"; break;
  case 37:  lookupKey = @"l (ㅣ)"; break;
  case 6:   lookupKey = @"z (ㅋ)"; break;
  case 7:   lookupKey = @"x (ㅌ)"; break;
  case 8:   lookupKey = @"c (ㅊ)"; break;
  case 9:   lookupKey = @"v (ㅍ)"; break;
  case 11:  lookupKey = @"b (ㅠ)"; break;
  case 45:  lookupKey = @"n (ㅜ)"; break;
  case 46:  lookupKey = @"m (ㅡ)"; break;
  default:  break;
  }

  if (!lookupKey) {
    return NO;
  }

  NSString *output = [_customShiftMappings objectForKey:lookupKey];
  if (!output || [output length] == 0) {
    return NO;
  }

  [self commitComposition:sender];
  [sender insertText:output
      replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
  return YES;
}

- (BOOL)processHangulInput:(NSEvent *)event
                   keyCode:(unsigned short)keyCode
                    client:(id)sender
        candidatesVisible:(BOOL)candidatesVisible {
  NSUInteger previousComposedLength = 0;
  NSRange selectedRangeBefore = NSMakeRange(NSNotFound, 0);
  if (_useMarkedTextForClient) {
    previousComposedLength = [[engine composedString] length];
    // The roman-leak repair only runs when a new marked composition starts.
    // selectedRange is another IPC call, so skip it while a composition is
    // already active and the captured range would be ignored anyway.
    if (previousComposedLength == 0) {
      @try {
        if ([sender respondsToSelector:@selector(selectedRange)]) {
          selectedRangeBefore = [sender selectedRange];
        }
      } @catch (NSException *exception) {
        DKSTLog(@"Exception checking selected range before input: %@",
                exception);
      }
    }
  }

  BOOL processed = [engine processCode:keyCode modifiers:[event modifierFlags]];

  if (processed) {
    if (candidatesVisible) {
      [_candidates hide];
    }

    if (_useMarkedTextForClient) {
      NSString *commit = [engine commitString];
      if ([commit length] > 0) {
        [self commitMarkedText:commit
        previousComposedLength:previousComposedLength
                        client:sender];
      }
      if (previousComposedLength == 0 &&
          [[engine composedString] length] > 0) {
        [self repairFirstMarkedTextLeakForClient:sender
                                         keyCode:keyCode
                                       modifiers:[event modifierFlags]
                             selectedRangeBefore:selectedRangeBefore];
      }
    }
    [self updateInlineForClient:sender];
    return YES;
  }

  // Not processed (e.g. non-hangul key)
  if ([self isHangulKeyCode:keyCode]) {
    DKSTLog(@"Blocked unprocessed Hangul keyCode=%d", keyCode);
    [self updateInlineForClient:sender];
    return YES;
  }

  [self commitComposition:sender];
  return NO;
}

// MARK: - Input Method Kit Methods (handleEvent)

- (BOOL)handleEvent:(NSEvent *)event client:(id)sender {
  unsigned short keyCode = [event keyCode];

  // §6: KIM pattern — keyDown only; other event types trigger buffer reset
  //     (§3 _handleEvent: step 2: keyDown/keyUp 이외 → resetBufferAndEngine:)
  if ([event type] != NSEventTypeKeyDown) {
    if ([event type] != NSEventTypeFlagsChanged &&
        [self hasPendingComposition]) {
      DKSTLog(@"Non-key event type %lu; resetting composition",
              (unsigned long)[event type]);
      [self commitComposition:sender];
    }
    return NO;
  }

  [self prepareForInputClient:sender];

  // 1. Candidate window navigation
  BOOL candidatesVisible = [_candidates isVisible];
  if (candidatesVisible) {
    if ([self handleCandidateNavigation:keyCode client:sender]) {
      return YES;
    }
    // handleCandidateNavigation hides candidates if key wasn't navigation
    candidatesVisible = NO;
  }

  NSUInteger modifiers =
      [event modifierFlags] &
      (NSEventModifierFlagCommand | NSEventModifierFlagControl |
       NSEventModifierFlagOption | NSEventModifierFlagShift);

  // 2. Hanja conversion (Option + Return)
  if ([self handleHanjaConversion:keyCode modifiers:modifiers client:sender]) {
    return YES;
  }

  // 3. Pass through Command/Ctrl/Option modified keys
  if ((modifiers & (NSEventModifierFlagCommand | NSEventModifierFlagControl |
                    NSEventModifierFlagOption)) != 0) {
    [self commitComposition:sender];
    return NO;
  }

  // §7: Control character safety net (KIM: u_iscntrl → commit + pass through)
  //     Catches C0 control codes not handled by individual key checks below.
  @try {
    NSString *chars = [event characters];
    if ([chars length] > 0) {
      unichar ch = [chars characterAtIndex:0];
      if ((ch < 0x20 || ch == 0x7F) &&
          keyCode != kDKSTKeyCodeTab && keyCode != kDKSTKeyCodeBackspace &&
          keyCode != kDKSTKeyCodeReturn && keyCode != kDKSTKeyCodeSpace &&
          keyCode != kDKSTKeyCodeEscape) {
        if ([self hasPendingComposition]) {
          [self commitComposition:sender];
        }
        return NO;
      }
    }
  } @catch (NSException *exception) {
    DKSTLog(@"Exception checking control characters: %@", exception);
  }

  // 4. Tab — commit and pass through
  if (keyCode == kDKSTKeyCodeTab) {
    [self commitComposition:sender];
    return NO;
  }

  // 5. Backspace
  if (keyCode == kDKSTKeyCodeBackspace) {
    if ([engine backspace]) {
      if (!_useMarkedTextForClient) {
        NSString *composedAfterBackspace = [engine composedString];
        if ([composedAfterBackspace length] == 0 &&
            _directInputComposedLength > 0) {
          [self clearDirectInputState];
          [self clearMarkedReplacementRange];
          return NO;
        }
      }
      [self updateInlineForClient:sender];
      return YES;
    }
    return NO;
  }

  // 6. Enter/Space without candidates — commit and pass through
  if ((keyCode == kDKSTKeyCodeReturn || keyCode == kDKSTKeyCodeSpace) &&
      !candidatesVisible) {
    [self commitComposition:sender];
    return NO;
  }

  // 7. Custom shift mappings
  if ([self handleCustomShift:keyCode modifiers:modifiers client:sender]) {
    return YES;
  }

  // 8. Hangul processing
  return [self processHangulInput:event
                          keyCode:keyCode
                           client:sender
                candidatesVisible:candidatesVisible];
}

- (void)commitMarkedText:(NSString *)commit
    previousComposedLength:(NSUInteger)previousComposedLength
                    client:(id)sender {
  if ([commit length] == 0) {
    return;
  }

  if (_useMarkedTextForClient) {
    [_markedTextCommittedPrefix appendString:commit];
    if ([_markedTextCommittedPrefix length] > 20) {
      [_markedTextCommittedPrefix
          deleteCharactersInRange:NSMakeRange(
                                      0, [_markedTextCommittedPrefix length] - 20)];
    }
  }

  // §4 Fix: Use _markedReplacementRange when available; otherwise let IMK
  // resolve the marked text range automatically via NSNotFound.
  // The previous NSMakeRange(0, previousComposedLength) was interpreted by
  // some clients as an absolute document range, causing text corruption.
  NSRange replacementRange = NSMakeRange(NSNotFound, NSNotFound);
  if (_markedReplacementRange.location != NSNotFound) {
    replacementRange = _markedReplacementRange;
  }

  @try {
    [sender insertText:commit replacementRange:replacementRange];
  } @catch (NSException *exception) {
    DKSTLog(@"Exception committing marked text: %@", exception);
    [sender insertText:commit
        replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
  }

  [self clearMarkedReplacementRange];
  [self rememberSelectedRangeForClient:sender];
}

- (void)updateComposition:(id)sender {
  NSString *composed = [engine composedString];
  if ([composed length] > 0) {
    NSMutableAttributedString *attrString = [[[NSMutableAttributedString alloc]
        initWithString:composed] autorelease];

    // Add underline style
    [attrString addAttribute:NSUnderlineStyleAttributeName
                       value:[NSNumber numberWithInt:NSUnderlineStyleSingle]
                       range:NSMakeRange(0, [composed length])];

    [sender setMarkedText:attrString
           selectionRange:NSMakeRange([composed length], 0)
         replacementRange:_markedReplacementRange];

    // §3: Inline inconsistency check (KIM: inlineInconsistent pattern)
    // Verify the client actually accepted the marked text. Some custom text
    // fields and Electron apps silently ignore setMarkedText, causing the
    // next keystroke to lose the previous jamo (받침 누락).
    @try {
      if ([sender respondsToSelector:@selector(markedRange)]) {
        NSRange markedRange = [sender markedRange];
        if (markedRange.location == NSNotFound ||
            markedRange.length == 0) {
          DKSTLog(@"Inline inconsistent: markedRange empty after "
                  @"setMarkedText (expected length %lu)",
                  (unsigned long)[composed length]);
          // Retry with NSNotFound in case _markedReplacementRange was stale
          if (_markedReplacementRange.location != NSNotFound) {
            [self clearMarkedReplacementRange];
            [sender setMarkedText:attrString
                   selectionRange:NSMakeRange([composed length], 0)
                 replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
          }
        }
      }
    } @catch (NSException *exception) {
      DKSTLog(@"Exception checking inline consistency: %@", exception);
    }

    [self rememberSelectedRangeForClient:sender];
  } else {
    [sender setMarkedText:@""
           selectionRange:NSMakeRange(0, 0)
         replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
    [self clearMarkedReplacementRange];
    [self rememberSelectedRangeForClient:sender];
  }
}

- (BOOL)updateDirectComposition:(id)sender {
  NSString *commit = [engine commitString];
  NSString *composed = [engine composedString];
  NSUInteger commitLength = [commit length];
  NSUInteger composedLength = [composed length];
  NSMutableString *replacement = [NSMutableString string];
  BOOL success = YES;

  if (commitLength > 0) {
    [replacement appendString:commit];
  }
  if (composedLength > 0) {
    [replacement appendString:composed];
  }

  NSRange replacementRange = [self directInputReplacementRange:sender];
  NSUInteger replacementStart = replacementRange.location;
  if (replacementStart == NSNotFound) {
    @try {
      NSRange selectedRange = [sender selectedRange];
      if (selectedRange.location != NSNotFound && selectedRange.length == 0) {
        replacementStart = selectedRange.location;
      }
    } @catch (NSException *exception) {
      DKSTLog(@"Exception getting insertion location: %@", exception);
    }
  }

  if ([replacement length] > 0 || replacementRange.location != NSNotFound) {
    [sender insertText:replacement replacementRange:replacementRange];
  }

  NSUInteger expectedLocation = NSNotFound;
  if (replacementStart != NSNotFound) {
    expectedLocation = replacementStart + commitLength + composedLength;
  }

  // §2: Detect cursor mismatch and signal failure so updateInlineForClient
  // can clean up stale direct-input state immediately.
  if (expectedLocation != NSNotFound && composedLength > 0 &&
      ![self shouldTrustDirectCompositionRangeForClient:sender]) {
    @try {
      NSRange selectedRange = [sender selectedRange];
      if (selectedRange.location == NSNotFound ||
          selectedRange.location != expectedLocation) {
        [self forceMarkedTextForClient:sender
                                reason:@"direct insert cursor mismatch"];
        DKSTLog(@"Direct composition cursor mismatch; will use marked "
                @"text from next update");
        success = NO;
      }
    } @catch (NSException *exception) {
      DKSTLog(@"Exception checking direct insert result: %@", exception);
      [self forceMarkedTextForClient:sender
                              reason:@"direct insert selectedRange exception"];
      success = NO;
    }
  }

  [_compositionState updateBufferContents:replacement];
  [_compositionState noteInsertedTextWithReplacementRange:replacementRange
                                        insertionLocation:replacementStart
                                          committedLength:commitLength
                                           composedLength:composedLength];
  _directInputComposedLength = composedLength;
  [_directInputComposedText release];
  _directInputComposedText = [composed copy];
  _directInputComposedRange = [_compositionState inlineRange];
  [self clearMarkedReplacementRange];
  [self rememberSelectedRangeForClient:sender];
  return success;
}

- (void)updateInlineForClient:(id)sender {
  if (_useMarkedTextForClient) {
    if (_markedReplacementRange.location == NSNotFound &&
        _directInputComposedRange.location != NSNotFound) {
      [self setMarkedReplacementRange:_directInputComposedRange];
    }
    [self clearDirectInputState];
    [self updateComposition:sender];
  } else {
    // §2: If direct composition fails (cursor mismatch), clean up stale
    // direct-input tracking so the next keystroke starts fresh with the
    // marked text path (forceMarkedTextForClient already set the flag).
    if (![self updateDirectComposition:sender]) {
      DKSTLog(@"Direct composition failed; cleaning up for marked text");
      [self clearDirectInputState];
      [_compositionState resetTransientRanges];
    }
  }
}

- (void)commitComposition:(id)sender {
  // If Candidate window is visible, we are likely in the middle of choosing a
  // Hanja. Committing now would flush the Hangul and result in double insertion
  // when Hanja is picked.
  if ([_candidates isVisible]) {
    return;
  }

  if (_directInputComposedLength > 0) {
    [engine reset];
    [self clearDirectInputState];
    [self clearMarkedReplacementRange];
    [_markedTextCommittedPrefix setString:@""];
    [sender setMarkedText:@""
           selectionRange:NSMakeRange(0, 0)
         replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
    [self rememberSelectedRangeForClient:sender];
    return;
  }

  // Check if there is anything to commit
  NSString *commit = [engine commitString]; // This also clears internal buffer
  NSString *composed = [engine composedString]; // Should be empty after reset
                                                // usually, unless engine splits

  // Insert text in correct order: Completed first, then Composed
  NSString *finalText = @"";
  if ([commit length] > 0 && [composed length] > 0) {
    finalText = [commit stringByAppendingString:composed];
  } else if ([commit length] > 0) {
    finalText = commit;
  } else if ([composed length] > 0) {
    finalText = composed;
  }

  // §5 Fix: insertText:replacementRange: with NSNotFound automatically
  // replaces the current marked text per IMK protocol. Only call
  // setMarkedText:@"" when there's nothing to insert (to clear stale
  // marked text without double-processing).
  if ([finalText length] > 0) {
    [sender insertText:finalText
        replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
  } else {
    [sender setMarkedText:@""
           selectionRange:NSMakeRange(0, 0)
         replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
  }

  [engine reset];
  [self clearDirectInputState];
  [self clearMarkedReplacementRange];
  [_markedTextCommittedPrefix setString:@""];
  [self rememberSelectedRangeForClient:sender];
}

- (void)setValue:(id)value forTag:(long)tag client:(id)sender {
  if (tag == kTextServiceInputModePropertyTag) {
    NSString *newMode = (NSString *)value;
    if (newMode) {
      // Proper MRC retain/release
      if (![currentMode isEqualToString:newMode]) {
        [currentMode release];
        currentMode = [newMode retain];
        [self commitComposition:sender];
      }
    }
  }
}

// Menu handling (Modes)
- (void)launchBundledApp:(NSString *)appName {
  NSString *path = [[NSBundle mainBundle] pathForResource:appName ofType:@"app"];
  if (!path) {
    DKSTLog(@"%@.app not found in bundle resources", appName);
    return;
  }
  [[NSWorkspace sharedWorkspace]
      openApplicationAtURL:[NSURL fileURLWithPath:path]
             configuration:[NSWorkspaceOpenConfiguration configuration]
         completionHandler:^(NSRunningApplication *app, NSError *error) {
           if (error) {
             DKSTLog(@"Failed to launch %@: %@", appName, error);
           }
         }];
}

- (void)showPreferences:(id)sender {
  [self launchBundledApp:@"DKSTPreferences"];
}

- (void)launchDictEditor:(id)sender {
  [self launchBundledApp:@"DKSTDictEditor"];
}

- (NSMenu *)menu {
  NSMenu *menu = [[[NSMenu alloc] initWithTitle:@"DKST"] autorelease];

  NSMenuItem *prefsItem =
      [[[NSMenuItem alloc] initWithTitle:@"Preferences..."
                                  action:@selector(showPreferences:)
                           keyEquivalent:@""] autorelease];
  [prefsItem setTarget:self];
  [menu addItem:prefsItem];

  NSMenuItem *dictEditorItem =
      [[[NSMenuItem alloc] initWithTitle:@"Dictionary Editor..."
                                  action:@selector(launchDictEditor:)
                           keyEquivalent:@""] autorelease];
  [dictEditorItem setTarget:self];
  [menu addItem:dictEditorItem];

  return menu;
}

// Required methods?
// recognizedEvents:
- (NSUInteger)recognizedEvents:(id)sender {
  return NSEventMaskKeyDown | NSEventMaskFlagsChanged;
}

// IMKCandidates Data Source
- (NSArray *)candidates:(id)sender {
  // Return the cached candidates array
  if (_currentHanjaCandidates && [_currentHanjaCandidates count] > 0) {
    DKSTLog(@"candidates: returning %lu items",
            (unsigned long)[_currentHanjaCandidates count]);
    return _currentHanjaCandidates;
  }
  return nil;
}

- (void)commitCandidate:(id)candidate client:(id)sender {
  NSString *selected = nil;
  if (candidate && [candidate isKindOfClass:[NSAttributedString class]]) {
    selected = [candidate string];
  } else if (candidate && [candidate isKindOfClass:[NSString class]]) {
    selected = candidate;
  }

  // Fallback: If no candidate provided or nil, use the first available
  // candidate
  if (!selected && _currentHanjaCandidates &&
      [_currentHanjaCandidates count] > 0) {
    selected = [_currentHanjaCandidates objectAtIndex:0];
  }

  // Debug log
  DKSTLog(@"commitCandidate selected='%@'", selected);

  if (selected) {
    NSString *hanja = [[selected componentsSeparatedByString:@" "] firstObject];
    if (hanja && [hanja length] > 0) {
      NSRange replacementRange;

      // Check if we're replacing selected text or composed text
      if (_selectedTextRange.location != NSNotFound &&
          _selectedTextRange.length > 0) {
        // Replacing selected text
        replacementRange = _selectedTextRange;
        DKSTLog(@"Replacing selected text at range: location=%lu, length=%lu",
                (unsigned long)replacementRange.location,
                (unsigned long)replacementRange.length);
      } else {
        replacementRange = [self compositionReplacementRange:sender];
        DKSTLog(@"Replacing composition text: location=%lu, length=%lu",
                (unsigned long)replacementRange.location,
                (unsigned long)replacementRange.length);
      }

      // Insert Hanja, replacing the text
      if (_hanjaReplacementUsesMarkedPrefix && _hanjaMarkedPrefixLength > 0) {
        @try {
          [sender setMarkedText:@""
                 selectionRange:NSMakeRange(0, 0)
               replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
          NSRange selectedRange = [sender selectedRange];
          if (selectedRange.location != NSNotFound &&
              selectedRange.location >= _hanjaMarkedPrefixLength) {
            replacementRange =
                NSMakeRange(selectedRange.location - _hanjaMarkedPrefixLength,
                            _hanjaMarkedPrefixLength);
          }
        } @catch (NSException *exception) {
          DKSTLog(@"Exception preparing marked-prefix Hanja replacement: %@",
                  exception);
        }
      }
      [sender insertText:hanja replacementRange:replacementRange];
      [engine reset];
      [self clearDirectInputState];
      [self clearMarkedReplacementRange];
    } else {
      DKSTLog(@"Failed to extract hanja from '%@'", selected);
    }
  } else {
    DKSTLog(@"No candidate selected to commit");
  }

  // Reset selected range
  _selectedTextRange = NSMakeRange(NSNotFound, 0);
  [self clearMarkedReplacementRange];
  [_markedTextCommittedPrefix setString:@""];
  _hanjaMarkedPrefixLength = 0;
  _hanjaReplacementUsesMarkedPrefix = NO;
  _currentHanjaIndex = 0; // Reset index

  [_candidates hide];
  if (_currentHanjaCandidates) {
    [_currentHanjaCandidates release];
    _currentHanjaCandidates = nil;
  }
}

// Candidate Selection Handler
- (void)candidateSelected:(NSAttributedString *)candidateString {
  [self commitCandidate:candidateString client:[self client]];
}

@end
