#import "InputController+Private.h"
#import "DKSTConstants.h"
#import "DKSTHanjaDictionary.h"
#import "DKSTKeyMap.h"
#import <objc/message.h>
#import <os/log.h>

static NSInteger DKSTCandidateIndexForNumberKeyCode(unsigned short keyCode) {
  switch (keyCode) {
  case kDKSTKeyCodeNum1:
    return 0;
  case kDKSTKeyCodeNum2:
    return 1;
  case kDKSTKeyCodeNum3:
    return 2;
  case kDKSTKeyCodeNum4:
    return 3;
  case kDKSTKeyCodeNum5:
    return 4;
  case kDKSTKeyCodeNum6:
    return 5;
  case kDKSTKeyCodeNum7:
    return 6;
  case kDKSTKeyCodeNum8:
    return 7;
  case kDKSTKeyCodeNum9:
    return 8;
  default:
    return -1;
  }
}

static BOOL DKSTRangeIsValid(NSRange range) {
  return range.location != NSNotFound &&
         NSMaxRange(range) >= range.location;
}

static BOOL DKSTRangesOverlapOrTouch(NSRange first, NSRange second) {
  if (!DKSTRangeIsValid(first) || !DKSTRangeIsValid(second)) {
    return NO;
  }
  return first.location <= NSMaxRange(second) &&
         second.location <= NSMaxRange(first);
}

@implementation InputController

static IMKCandidates *DKSTSharedCandidates;

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
      kDKSTEnableMoaJjikiKey : @YES,
      kDKSTFullCharacterDeleteKey : @NO,
      kDKSTEnableCustomShiftKey : @NO,
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

    // Always keep IMKCandidates available for all clients.
    // Reuse one process-wide instance instead of allocating and releasing
    // one per controller, which causes heavy XPC connection churn with
    // CursorUIViewService and dangling pointer crashes in InputMethodKit.
    @synchronized([InputController class]) {
      if (!DKSTSharedCandidates) {
        DKSTSharedCandidates = [[IMKCandidates alloc]
            initWithServer:server
                 panelType:kIMKSingleColumnScrollingCandidatePanel];
      }
      _candidates = DKSTSharedCandidates;
    }
    _lastClientSyncTime = 0;
    _directInputComposedLength = 0;
    _directInputComposedText = nil;
    _directInputComposedRange = NSMakeRange(NSNotFound, 0);
    _markedReplacementRange = NSMakeRange(NSNotFound, 0);
    _forcedMarkedTextBundleIDs = [[NSMutableSet alloc] init];
    _lastInputClient = inputClient;
    _lastBundleIdentifierClient = nil;
    _lastInputClientBundleID = nil;
    _lastClientSelectedRange = NSMakeRange(NSNotFound, 0);
    _useMarkedTextForClient = NO;
    _hanjaEnabled = YES;
    _markedTextCommittedPrefix = [[NSMutableString alloc] init];
    _hanjaMarkedPrefixLength = 0;
    _hanjaReplacementUsesMarkedPrefix = NO;
    _compositionState = [[DKSTCompositionState alloc] init];
    _chromiumDetectionCache = [[NSMutableDictionary alloc] init];

    // Default Hanja shortcut: Option + Return
    _hanjaShortcutKeyCode = kDKSTKeyCodeReturn;
    _hanjaShortcutModifiers = NSEventModifierFlagOption;
    _hanjaModifierPending = NO;

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
               name:kDKSTDictionaryDidChangeNotification
             object:nil];

    // Listen for Hanja shortcut changes from Preferences app
    [[NSDistributedNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(hanjaShortcutDidChange:)
               name:kDKSTHanjaShortcutDidChangeNotification
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

  // The shared candidates instance is intentionally kept alive for the process,
  // which avoids per-controller connection churn and use-after-free crashes.
  _candidates = nil;

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

- (BOOL)directInputRangeIsCurrent:(NSRange)range client:(id)sender {
  return [self directInputRangeIsCurrent:range client:sender allowSelection:NO];
}

- (BOOL)directInputRangeIsCurrent:(NSRange)range
                           client:(id)sender
                   allowSelection:(BOOL)allowSelection {
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
    if (!allowSelection &&
        [sender respondsToSelector:@selector(selectedRange)]) {
      NSRange selectedRange = [sender selectedRange];
      if (selectedRange.location != NSNotFound && selectedRange.length > 0) {
        return NO;
      }
    }

    BOOL didRead = NO;
    if (![self directInputRange:range
                  containsText:_directInputComposedText
                        client:sender
                       didRead:&didRead]) {
      return NO;
    }
  } @catch (NSException *exception) {
    DKSTLog(@"Stale direct input range %@: %@", NSStringFromRange(range),
            exception);
    return NO;
  }

  return YES;
}

- (BOOL)directInputRange:(NSRange)range
            containsText:(NSString *)expectedText
                  client:(id)sender
                 didRead:(BOOL *)didRead {
  if (didRead) {
    *didRead = NO;
  }
  if (!sender || !expectedText || !DKSTRangeIsValid(range) ||
      range.length != [expectedText length]) {
    return NO;
  }

  @try {
    if ([sender respondsToSelector:@selector(attributedSubstringFromRange:)]) {
      NSAttributedString *textInRange =
          [sender attributedSubstringFromRange:range];
      if (textInRange) {
        if (didRead) {
          *didRead = YES;
        }
        BOOL matches = [[textInRange string] isEqualToString:expectedText];
        if (!matches) {
          DKSTLog(@"Direct input range %@ contains '%@', expected '%@'",
                  NSStringFromRange(range), [textInRange string], expectedText);
        }
        return matches;
      }
    }

    // IMKTextDocumentTextInputAdaptor exposes a plain-string fallback used by
    // the native Korean input method when attributedSubstringFromRange: cannot
    // provide a value.
    id textSource = sender;
    SEL stringFromRangeSelector =
        NSSelectorFromString(@"stringFromRange:actualRange:");
    if (![textSource respondsToSelector:stringFromRangeSelector]) {
      SEL textDocumentSelector = NSSelectorFromString(@"textDocument");
      if ([self respondsToSelector:textDocumentSelector]) {
        textSource =
            ((id (*)(id, SEL))objc_msgSend)(self, textDocumentSelector);
      }
    }
    if ([textSource respondsToSelector:stringFromRangeSelector]) {
      NSRange actualRange = range;
      NSString *textInRange =
          ((id (*)(id, SEL, NSRange, NSRange *))objc_msgSend)(
              textSource, stringFromRangeSelector, range, &actualRange);
      if (textInRange) {
        if (didRead) {
          *didRead = YES;
        }
        BOOL matches = NSEqualRanges(actualRange, range) &&
                       [textInRange isEqualToString:expectedText];
        if (!matches) {
          DKSTLog(@"Direct input range %@ returned %@ and '%@', expected '%@'",
                  NSStringFromRange(range), NSStringFromRange(actualRange),
                  textInRange, expectedText);
        }
        return matches;
      }
    }
  } @catch (NSException *exception) {
    DKSTLog(@"Exception reading direct input range %@: %@",
            NSStringFromRange(range), exception);
  }

  // A client without a readable document range cannot prove that insertion
  // failed. Keep direct input and use subsequent range observations instead.
  return YES;
}

- (NSRange)directInputReplacementRange:(id)sender {
  if (!sender) {
    return _directInputComposedRange;
  }

  NSRange selectedRange = NSMakeRange(NSNotFound, 0);
  @try {
    if ([sender respondsToSelector:@selector(selectedRange)]) {
      selectedRange = [sender selectedRange];
    }
  } @catch (NSException *exception) {
    DKSTLog(@"Exception reading direct input selection: %@", exception);
  }

  // The first character replaces a live selection explicitly. Relying on
  // NSNotFound here loses the insertion location needed to track inlineRange.
  if (_directInputComposedLength == 0) {
    if (selectedRange.location != NSNotFound && selectedRange.length > 0) {
      return selectedRange;
    }
    return NSMakeRange(NSNotFound, 0);
  }

  BOOL trackedRangeIsUsable =
      DKSTRangeIsValid(_directInputComposedRange) &&
      _directInputComposedRange.length == _directInputComposedLength;

  // Completion UIs may select a suffix immediately after inlineRange or a
  // candidate that includes inlineRange itself. Use the union before checking
  // the old text: the completion is allowed to have rewritten that text.
  if (trackedRangeIsUsable && selectedRange.length > 0 &&
      DKSTRangesOverlapOrTouch(_directInputComposedRange, selectedRange)) {
    return NSUnionRange(_directInputComposedRange, selectedRange);
  }

  if (trackedRangeIsUsable &&
      [self directInputRangeIsCurrent:_directInputComposedRange
                               client:sender
                       allowSelection:YES]) {
    return _directInputComposedRange;
  }

  // Recover only when inlineRange was lost. This is secondary to the tracked
  // range so a completion selected from the composition start is not missed.
  if (!trackedRangeIsUsable && selectedRange.location != NSNotFound &&
      selectedRange.location >= _directInputComposedLength) {
    NSRange backtrackRange =
        NSMakeRange(selectedRange.location - _directInputComposedLength,
                    _directInputComposedLength);
    if ([self directInputRangeIsCurrent:backtrackRange
                                 client:sender
                         allowSelection:selectedRange.length > 0]) {
      if (selectedRange.length > 0 &&
          DKSTRangesOverlapOrTouch(backtrackRange, selectedRange)) {
        return NSUnionRange(backtrackRange, selectedRange);
      }
      return backtrackRange;
    }
  }

  DKSTLog(@"Dropping stale direct input range %@",
          NSStringFromRange(_directInputComposedRange));
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
  NSRange markedReplacementRange = [_compositionState replacementRange];
  if (markedReplacementRange.location != NSNotFound) {
    return markedReplacementRange;
  }

  NSString *composed = [engine composedString];
  if ([composed length] > 0) {
    return NSMakeRange(0, [composed length]);
  }
  return NSMakeRange(NSNotFound, 0);
}

- (BOOL)isHangulKeyCode:(unsigned short)keyCode {
  return DKSTIsHangulANSIKeyCode(keyCode);
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
    _lastClientSyncTime = now;
  } @catch (NSException *exception) {
    DKSTLog(@"Exception in syncInputClient: %@", exception);
  }
}

- (void)resetCompositionState {
  [engine reset];
  [self clearDirectCompositionStatePreservingMarkedRange:NO];
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

- (void)clearDirectCompositionStatePreservingMarkedRange:
    (BOOL)preserveMarkedRange {
  _directInputComposedLength = 0;
  [_directInputComposedText release];
  _directInputComposedText = nil;
  _directInputComposedRange = NSMakeRange(NSNotFound, 0);
  if (!preserveMarkedRange) {
    [self clearMarkedReplacementRange];
  }
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
    [_lastInputClientBundleID release];
    _lastInputClientBundleID = nil;
    _lastBundleIdentifierClient = nil;

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

  // REMOVED: Forced setMarkedText:@"" on client change (Phase 1 Method 3)
  // This was found to cause input issues in some applications.
  // commitComposition: already handles state cleanup.

  if (!_useMarkedTextForClient && [self hasPendingComposition] &&
      _lastClientSelectedRange.location != NSNotFound &&
      [sender respondsToSelector:@selector(selectedRange)]) {
    @try {
      NSRange selectedRange = [sender selectedRange];
      if (selectedRange.location != NSNotFound &&
          !NSEqualRanges(selectedRange, _lastClientSelectedRange)) {
        BOOL selectionContinuesInlineCompletion =
            _directInputComposedLength > 0 &&
            selectedRange.length > 0 &&
            DKSTRangeIsValid(_directInputComposedRange) &&
            DKSTRangesOverlapOrTouch(_directInputComposedRange, selectedRange);
        if (selectionContinuesInlineCompletion) {
          _lastClientSelectedRange = selectedRange;
          DKSTLog(@"Keeping direct composition for inline selection %@",
                  NSStringFromRange(selectedRange));
          return;
        }

        BOOL caretFollowsInlineRange =
            _directInputComposedLength > 0 &&
            selectedRange.length == 0 &&
            DKSTRangeIsValid(_directInputComposedRange) &&
            selectedRange.location == NSMaxRange(_directInputComposedRange);
        if (caretFollowsInlineRange) {
          _lastClientSelectedRange = selectedRange;
          return;
        }

        // If an asynchronous client reports a caret that no longer matches the
        // tracked inlineRange, derive the live range from that caret before
        // treating it as a user move. Messages can shift its text-document
        // coordinates after Shift+Return. Trust the rebased range only when
        // the document actually contains the active composition there.
        if (_directInputComposedLength > 0 &&
            selectedRange.length == 0 &&
            selectedRange.location >= _directInputComposedLength) {
          NSRange backtrackRange =
              NSMakeRange(selectedRange.location - _directInputComposedLength,
                          _directInputComposedLength);
          BOOL canRebaseDirectRange =
              !NSEqualRanges(backtrackRange, _directInputComposedRange) &&
              [self directInputRangeIsCurrent:backtrackRange
                                       client:sender
                               allowSelection:YES];
          if (canRebaseDirectRange) {
            NSRange previousInlineRange = _directInputComposedRange;
            _directInputComposedRange = backtrackRange;
            _lastClientSelectedRange = selectedRange;
#ifdef DEBUG
            os_log(
                OS_LOG_DEFAULT,
                "DKST: rebased direct-input range "
                "selected={%{public}lu,%{public}lu} "
                "old={%{public}lu,%{public}lu} "
                "new={%{public}lu,%{public}lu}",
                (unsigned long)selectedRange.location,
                (unsigned long)selectedRange.length,
                (unsigned long)previousInlineRange.location,
                (unsigned long)previousInlineRange.length,
                (unsigned long)backtrackRange.location,
                (unsigned long)backtrackRange.length);
#endif
            return;
          }
        }

        if (_directInputComposedLength > 0 &&
            [self directInputRangeIsCurrent:_directInputComposedRange
                                     client:sender
                             allowSelection:YES]) {
#ifdef DEBUG
          os_log(
              OS_LOG_DEFAULT,
              "DKST: direct-input selection moved "
              "selected={%{public}lu,%{public}lu} "
              "last={%{public}lu,%{public}lu} "
              "inline={%{public}lu,%{public}lu}",
              (unsigned long)selectedRange.location,
              (unsigned long)selectedRange.length,
              (unsigned long)_lastClientSelectedRange.location,
              (unsigned long)_lastClientSelectedRange.length,
              (unsigned long)_directInputComposedRange.location,
              (unsigned long)_directInputComposedRange.length);
#endif
          DKSTLog(@"Selection moved away from direct composition %@; "
                  @"finishing it before the next key",
                  NSStringFromRange(_directInputComposedRange));
          [self commitComposition:sender];
          return;
        }

        DKSTLog(@"Direct composition contents changed outside inline range; "
                @"resetting without clearing marked text");
        [self resetCompositionState];
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

  BOOL moaJjikiEnabled = [defaults boolForKey:kDKSTEnableMoaJjikiKey];
  [engine setMoaJjikiEnabled:moaJjikiEnabled];

  BOOL fullCharacterDeleteEnabled =
      [defaults boolForKey:kDKSTFullCharacterDeleteKey];
  [engine setFullCharacterDelete:fullCharacterDeleteEnabled];

  _customShiftEnabled = [defaults boolForKey:kDKSTEnableCustomShiftKey];
  _useMarkedTextForAllApps =
      [defaults boolForKey:kDKSTUseMarkedTextForAllAppsKey];
  if ([defaults objectForKey:kDKSTEnableHanjaKey] != nil) {
    _hanjaEnabled = [defaults boolForKey:kDKSTEnableHanjaKey];
  } else {
    _hanjaEnabled = YES;
  }

  NSDictionary *mappings =
      [defaults dictionaryForKey:kDKSTCustomShiftMappingsKey];
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

  // Load custom Hanja shortcut from CFPreferences (cross-process safe)
  [self reloadHanjaShortcut];
}

- (void)reloadHanjaShortcut {
  CFStringRef appID = (__bridge CFStringRef)kDKSTBundleID;

  // Force re-read from disk (bypass in-memory cache)
  CFPreferencesAppSynchronize(appID);

  CFPropertyListRef keyCodeRef = CFPreferencesCopyAppValue(
      (__bridge CFStringRef)kDKSTHanjaShortcutKeyCodeKey, appID);
  CFPropertyListRef modifiersRef = CFPreferencesCopyAppValue(
      (__bridge CFStringRef)kDKSTHanjaShortcutModifiersKey, appID);

  if (keyCodeRef && modifiersRef) {
    _hanjaShortcutKeyCode =
        (unsigned short)[((__bridge NSNumber *)keyCodeRef) integerValue];
    _hanjaShortcutModifiers =
        (NSUInteger)[((__bridge NSNumber *)modifiersRef) unsignedIntegerValue];
    DKSTLog(@"Loaded custom Hanja shortcut: keyCode=%d modifiers=0x%lx",
            _hanjaShortcutKeyCode, (unsigned long)_hanjaShortcutModifiers);
  } else {
    // Fallback to default: Option + Return
    _hanjaShortcutKeyCode = kDKSTKeyCodeReturn;
    _hanjaShortcutModifiers = NSEventModifierFlagOption;
    DKSTLog(@"Using default Hanja shortcut: Option + Return");
  }

  if (keyCodeRef) CFRelease(keyCodeRef);
  if (modifiersRef) CFRelease(modifiersRef);
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

- (void)hanjaShortcutDidChange:(NSNotification *)notification {
  DKSTLog(@"Received DKSTHanjaShortcutDidChangeNotification — reloading shortcut");
  [self reloadHanjaShortcut];
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

  // InputMethodKit's client proxy performs synchronous XPC round trips for
  // operations such as selectedRange and insertText:. Limit those waits so an
  // unresponsive client cannot stall the input method indefinitely. This is an
  // internal IMK proxy API, so keep the call capability-checked.
  SEL timeoutSel = NSSelectorFromString(@"setReplyTimeout:");
  if ([sender respondsToSelector:timeoutSel]) {
    // 100 ms still bounds a hung client while leaving more headroom than the
    // previous 30 ms for temporarily busy applications.
    ((void (*)(id, SEL, double))objc_msgSend)(sender, timeoutSel, 0.1);
    DKSTLog(@"Set client XPC replyTimeout to 0.1s for %@",
            [self bundleIdentifierForClient:sender]);
  }

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

- (void)selectionChanged:(id)sender {
  DKSTLog(@"selectionChanged called");
  if (!sender) {
    return;
  }

  @try {
    if ([sender respondsToSelector:@selector(selectedRange)]) {
      NSRange selectedRange = [sender selectedRange];
      if (selectedRange.location != NSNotFound) {
        // insertText: and setMarkedText: can deliver this private callback
        // asynchronously. Calendar's autofill popup makes that particularly
        // visible: the notification for the previous syllable can arrive after
        // the next syllable's first consonant has already been inserted. Never
        // mutate composition state from this ambiguous callback. The next real
        // key event validates the live selection in prepareForInputClient:; a
        // genuine caret move is handled there without dropping a newer engine
        // buffer because of a stale notification.
        if (![self hasPendingComposition]) {
          _lastClientSelectedRange = selectedRange;
        } else {
          DKSTLog(@"Deferring selection change %@ while composition is pending",
                  NSStringFromRange(selectedRange));
        }
      }
    }
  } @catch (NSException *exception) {
    DKSTLog(@"Exception in selectionChanged: %@", exception);
  }
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
      if (_currentHanjaIndex < 0)
        _currentHanjaIndex = 0;
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
    [self cancelHanjaCandidates];
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
      [self cancelHanjaCandidates];
    }
    return YES;
  }

  // Number keys 1-9 for direct candidate selection
  NSInteger index = DKSTCandidateIndexForNumberKeyCode(keyCode);
  if (index >= 0) {
    if (hasCandidates) {
      NSInteger pageStartIndex = (_currentHanjaIndex / 9) * 9;
      NSInteger targetIndex = pageStartIndex + index;
      if (targetIndex < [_currentHanjaCandidates count]) {
        _currentHanjaIndex = targetIndex;
        NSString *selected =
            [_currentHanjaCandidates objectAtIndex:_currentHanjaIndex];
        [self commitCandidate:selected client:sender];
      }
    }
    return YES;
  }

  // Character key while candidates open: hide and fall through
  [self cancelHanjaCandidates];
  return NO;
}

- (BOOL)handleCustomShift:(unsigned short)keyCode
                modifiers:(NSUInteger)modifiers
                   client:(id)sender {
  if (!_customShiftEnabled || modifiers != NSEventModifierFlagShift) {
    return NO;
  }

  NSString *lookupKey = nil;
  switch (keyCode) {
  case kDKSTKeyCodeY:
    lookupKey = @"y (ㅛ)";
    break;
  case kDKSTKeyCodeU:
    lookupKey = @"u (ㅕ)";
    break;
  case kDKSTKeyCodeI:
    lookupKey = @"i (ㅑ)";
    break;
  case kDKSTKeyCodeA:
    lookupKey = @"a (ㅁ)";
    break;
  case kDKSTKeyCodeS:
    lookupKey = @"s (ㄴ)";
    break;
  case kDKSTKeyCodeD:
    lookupKey = @"d (ㅇ)";
    break;
  case kDKSTKeyCodeF:
    lookupKey = @"f (ㄹ)";
    break;
  case kDKSTKeyCodeG:
    lookupKey = @"g (ㅎ)";
    break;
  case kDKSTKeyCodeH:
    lookupKey = @"h (ㅗ)";
    break;
  case kDKSTKeyCodeJ:
    lookupKey = @"j (ㅓ)";
    break;
  case kDKSTKeyCodeK:
    lookupKey = @"k (ㅏ)";
    break;
  case kDKSTKeyCodeL:
    lookupKey = @"l (ㅣ)";
    break;
  case kDKSTKeyCodeZ:
    lookupKey = @"z (ㅋ)";
    break;
  case kDKSTKeyCodeX:
    lookupKey = @"x (ㅌ)";
    break;
  case kDKSTKeyCodeC:
    lookupKey = @"c (ㅊ)";
    break;
  case kDKSTKeyCodeV:
    lookupKey = @"v (ㅍ)";
    break;
  case kDKSTKeyCodeB:
    lookupKey = @"b (ㅠ)";
    break;
  case kDKSTKeyCodeN:
    lookupKey = @"n (ㅜ)";
    break;
  case kDKSTKeyCodeM:
    lookupKey = @"m (ㅡ)";
    break;
  default:
    break;
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
  BOOL processed = [engine processCode:keyCode modifiers:[event modifierFlags]];

  if (processed) {
    if (candidatesVisible) {
      [_candidates hide];
    }

    if (_useMarkedTextForClient) {
      NSString *commit = [engine commitString];
      if ([commit length] > 0) {
        [self commitMarkedText:commit client:sender];
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

  if (candidatesVisible) {
    if (keyCode == kDKSTKeyCodeLeft || keyCode == kDKSTKeyCodeRight ||
        keyCode == kDKSTKeyCodeDown || keyCode == kDKSTKeyCodeUp ||
        keyCode == kDKSTKeyCodeReturn || keyCode == kDKSTKeyCodeSpace ||
        keyCode == kDKSTKeyCodeEscape ||
        (keyCode >= kDKSTKeyCodeNum1 && keyCode <= kDKSTKeyCodeNum0)) {
      return NO;
    }
    [_candidates hide];
  }

  [self commitComposition:sender];
  return NO;
}

// MARK: - Input Method Kit Methods (handleEvent)

- (BOOL)handleEvent:(NSEvent *)event client:(id)sender {
  id textDocument = nil;
  BOOL beganEdit = NO;
  SEL textDocumentSelector = NSSelectorFromString(@"textDocument");
  SEL beginEditSelector = NSSelectorFromString(@"beginEdit");
  SEL endEditSelector = NSSelectorFromString(@"endEdit");
  SEL invalidateCacheSelector = NSSelectorFromString(@"invalidateCache");

  @try {
    if ([self respondsToSelector:textDocumentSelector]) {
      textDocument =
          ((id (*)(id, SEL))objc_msgSend)(self, textDocumentSelector);
    }
    if (textDocument && [textDocument respondsToSelector:beginEditSelector] &&
        [textDocument respondsToSelector:endEditSelector]) {
      ((void (*)(id, SEL))objc_msgSend)(textDocument, beginEditSelector);
      beganEdit = YES;
    }
  } @catch (NSException *exception) {
    DKSTLog(@"Exception beginning text document edit: %@", exception);
    textDocument = nil;
    beganEdit = NO;
  }

  BOOL handled = NO;
  @try {
    handled = [self handleEventInEditTransaction:event client:sender];
  } @finally {
    @try {
      if (beganEdit) {
        ((void (*)(id, SEL))objc_msgSend)(textDocument, endEditSelector);
      }
    } @catch (NSException *exception) {
      DKSTLog(@"Exception ending text document edit: %@", exception);
    }
  }

  // Match KIM's ordering for pass-through Return: finish the edit transaction
  // before reading the final selection and clearing composition state. The
  // client applies the line break after this method returns, so remembering a
  // selection from inside the cached edit can leave the next inlineRange on
  // the preceding line.
  if (!handled && [event type] == NSEventTypeKeyDown &&
      [event keyCode] == kDKSTKeyCodeReturn) {
    [self commitComposition:sender];
  }

  // The native controller invalidates its text-document cache only for an
  // event it passes back to the client. Handled Hangul updates stay inside one
  // coherent edit snapshot.
  if (!handled && textDocument &&
      [textDocument respondsToSelector:invalidateCacheSelector]) {
    @try {
      ((void (*)(id, SEL))objc_msgSend)(textDocument,
                                       invalidateCacheSelector);
    } @catch (NSException *exception) {
      DKSTLog(@"Exception invalidating text document cache: %@", exception);
    }
  }

  return handled;
}

- (BOOL)handleEventInEditTransaction:(NSEvent *)event client:(id)sender {
  unsigned short keyCode = [event keyCode];

  // Handle modifier-only Hanja shortcut (e.g., Option + Control)
  if ([event type] == NSEventTypeFlagsChanged && _hanjaEnabled &&
      DKSTIsModifierKeyCode(_hanjaShortcutKeyCode)) {
    if (keyCode == _hanjaShortcutKeyCode) {
      NSUInteger flags = [event modifierFlags] &
                         (NSEventModifierFlagCommand | NSEventModifierFlagControl |
                          NSEventModifierFlagOption | NSEventModifierFlagShift);

      NSUInteger requiredFlags =
          _hanjaShortcutModifiers |
          DKSTModifierMaskForKeyCode(_hanjaShortcutKeyCode);

      if (DKSTModifierKeyIsPress(keyCode, flags)) {
        if (flags == requiredFlags) {
          _hanjaModifierPending = YES;
        } else {
          _hanjaModifierPending = NO;
        }
      } else if (_hanjaModifierPending) {
        // Modifier released without intervening keyDown → trigger
        _hanjaModifierPending = NO;
        NSRange conversionRange = NSMakeRange(NSNotFound, 0);
        NSString *conversionText =
            [self hangulTextForHanjaConversion:sender range:&conversionRange];
        if ([self showHanjaCandidatesForText:conversionText
                            replacementRange:conversionRange
                                      client:sender]) {
          return YES;
        }
      }
    }
    return NO;
  }

  // Item 6: KIM pattern - Reset buffer for events other than
  // KeyDown/FlagsChanged
  if ([event type] != NSEventTypeKeyDown) {
    if ([event type] != NSEventTypeFlagsChanged) {
      [self resetCompositionState];
    }
    return NO;
  }

  // Any keyDown clears modifier-only pending state
  _hanjaModifierPending = NO;

  [self prepareForInputClient:sender];
  [self refreshMarkedTextPolicyForNewComposition:sender];

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

  // 2. Hanja conversion (custom shortcut, default: Option + Return)
  if ([self handleHanjaConversion:keyCode modifiers:modifiers client:sender]) {
    return YES;
  }

  // 3. Pass through Command/Ctrl/Option modified keys
  if ((modifiers & (NSEventModifierFlagCommand | NSEventModifierFlagControl |
                    NSEventModifierFlagOption)) != 0) {
    [self commitComposition:sender];
    return NO;
  }

  // 4. Tab — commit and pass through
  if (keyCode == kDKSTKeyCodeTab) {
    [self commitComposition:sender];
    return NO;
  }

  // 5. Backspace
  if (keyCode == kDKSTKeyCodeBackspace) {
    // Direct composition has already written its visible text into the
    // document. If the client now exposes a real selection, Backspace belongs
    // to the client and must delete that selection atomically. Editing the
    // Hangul engine first would resurrect the last buffered Jamo after the
    // selected sentence disappears (notably in Excel and Messages).
    if (!_useMarkedTextForClient && _directInputComposedLength > 0 &&
        [sender respondsToSelector:@selector(selectedRange)]) {
      @try {
        NSRange selectedRange = [sender selectedRange];
        if (selectedRange.location != NSNotFound &&
            selectedRange.length > 0) {
#ifdef DEBUG
          os_log(
              OS_LOG_DEFAULT,
              "DKST: passing selected-text Backspace to client "
              "selected={%{public}lu,%{public}lu} "
              "inline={%{public}lu,%{public}lu}",
              (unsigned long)selectedRange.location,
              (unsigned long)selectedRange.length,
              (unsigned long)_directInputComposedRange.location,
              (unsigned long)_directInputComposedRange.length);
#endif
          [self resetCompositionState];
          return NO;
        }
      } @catch (NSException *exception) {
        DKSTLog(@"Exception checking selection before Backspace: %@",
                exception);
      }
    }

    if ([engine backspace]) {
      if (!_useMarkedTextForClient) {
        NSString *composedAfterBackspace = [engine composedString];
        if ([composedAfterBackspace length] == 0 &&
            _directInputComposedLength > 0) {
          [self clearDirectCompositionStatePreservingMarkedRange:NO];
          return NO;
        }
      }
      [self updateInlineForClient:sender];
      return YES;
    }
    return NO;
  }

  // 6. Enter — pass through. handleEvent: commits after endEdit so the
  // selection snapshot cannot remain anchored to the preceding line.
  if (keyCode == kDKSTKeyCodeReturn && !candidatesVisible) {
    return NO;
  }

  // 6b. Space — KIM pattern: commit composed text + Space atomically
  if (keyCode == kDKSTKeyCodeSpace && !candidatesVisible) {
    if ([self hasPendingComposition]) {
      NSString *commit = [engine commitString];
      NSString *composed = [engine composedString];
      NSMutableString *finalText = [NSMutableString string];

      if ([commit length] > 0) {
        [finalText appendString:commit];
      }
      if ([composed length] > 0) {
        [finalText appendString:composed];
      }
      [finalText appendString:@" "];

      NSRange replacementRange = NSMakeRange(NSNotFound, NSNotFound);
      if (!_useMarkedTextForClient &&
          _directInputComposedRange.location != NSNotFound) {
        replacementRange = [self directInputReplacementRange:sender];
      }

      @try {
        [sender insertText:finalText replacementRange:replacementRange];
      } @catch (NSException *exception) {
        DKSTLog(@"Exception inserting Space commit: %@", exception);
        [sender insertText:finalText
            replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
      }

      [engine reset];
      [self clearDirectCompositionStatePreservingMarkedRange:NO];
      [_markedTextCommittedPrefix setString:@""];
      [self rememberSelectedRangeForClient:sender];

      return YES;
    }

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

- (void)commitMarkedText:(NSString *)commit client:(id)sender {
  if ([commit length] == 0) {
    return;
  }

  if (_useMarkedTextForClient) {
    [_markedTextCommittedPrefix appendString:commit];
    if ([_markedTextCommittedPrefix length] > 20) {
      [_markedTextCommittedPrefix
          deleteCharactersInRange:NSMakeRange(
                                      0, [_markedTextCommittedPrefix length] -
                                             20)];
    }
  }

  // Item 4: Always use NSNotFound for replacementRange to let IMK handle it
  // unless a specific replacement range is already set.
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

    // Item 3: Check for inline consistency (KIM's inlineInconsistent pattern)
    @try {
      if ([sender respondsToSelector:@selector(markedRange)]) {
        NSRange markedRange = [sender markedRange];
        if (markedRange.location == NSNotFound || markedRange.length == 0) {
          DKSTLog(
              @"Inline inconsistent: markedRange not set after setMarkedText "
              @"for %@",
              [self bundleIdentifierForClient:sender]);
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
  BOOL hadDirectComposition = _directInputComposedLength > 0;
  NSMutableString *replacement = [NSMutableString string];

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
      if (selectedRange.location != NSNotFound) {
        replacementStart = selectedRange.location;
      }
    } @catch (NSException *exception) {
      DKSTLog(@"Exception getting insertion location: %@", exception);
    }
  }

  if (hadDirectComposition && replacementRange.location == NSNotFound) {
    [self forceMarkedTextForClient:sender
                            reason:@"tracked direct composition disappeared"];
    return NO;
  }

  if ([replacement length] > 0 || replacementRange.location != NSNotFound) {
    @try {
      [sender insertText:replacement replacementRange:replacementRange];
    } @catch (NSException *exception) {
      DKSTLog(@"Direct insert failed: %@", exception);
      if (replacementRange.location != NSNotFound) {
        [self setMarkedReplacementRange:replacementRange];
      }
      [self forceMarkedTextForClient:sender reason:@"direct insert exception"];
      return NO;
    }
  }

  NSUInteger expectedLocation = NSNotFound;
  if (replacementStart != NSNotFound) {
    expectedLocation = replacementStart + commitLength + composedLength;
  }

  // KIM's insertNewText: does not read the document back on the first direct
  // insertion. Some clients, including Messages after Shift+Return, expose the
  // new selection immediately but publish attributed document contents one
  // event later. Treating that first snapshot as authoritative switches the
  // composition to marked text and splits the following Hangul syllables.
  //
  // Validate once on the next update, using the complete buffer exactly as
  // updateContentsWithoutInline does, then stop checking while the buffer keeps
  // changing successfully.
  if (hadDirectComposition &&
      _compositionState.shouldCheckInsertionError &&
      replacementStart != NSNotFound && [replacement length] > 0) {
    NSRange insertedBufferRange =
        NSMakeRange(replacementStart, [replacement length]);
    BOOL didReadInsertedText = NO;
    BOOL insertedTextMatches =
        [self directInputRange:insertedBufferRange
                 containsText:replacement
                       client:sender
                      didRead:&didReadInsertedText];
    if (didReadInsertedText && !insertedTextMatches) {
      [self setMarkedReplacementRange:
                (replacementRange.location != NSNotFound
                     ? replacementRange
                     : insertedBufferRange)];
      [self forceMarkedTextForClient:sender
                              reason:@"direct insert text mismatch"];
      return NO;
    }
  }

  if (expectedLocation != NSNotFound && composedLength > 0 && _directInputComposedLength > 0 &&
      ![self shouldTrustDirectCompositionRangeForClient:sender]) {
    @try {
      NSRange selectedRange = [sender selectedRange];

      // Allow self-healing or asynchronous lag:
      // If the cursor is still at the insertion start (expectedLocation - composedLength)
      // or at the previous selected location, it's just lag!
      BOOL isLag = (selectedRange.location != NSNotFound &&
                    (selectedRange.location == expectedLocation - composedLength ||
                     selectedRange.location == _lastClientSelectedRange.location));

      if (selectedRange.location == NSNotFound ||
          (selectedRange.location != expectedLocation && !isLag)) {
        // Autofill clients can still report the selection from before
        // insertText: here. Do not turn that asynchronous observation into a
        // marked-text policy change. The next key validates both the live
        // selection and the actual text in directInputReplacementRange:.
        DKSTLog(@"Deferred direct insert validation: expected %lu, got %lu "
                @"(lag allowed: %d)",
                (unsigned long)expectedLocation,
                (unsigned long)selectedRange.location,
                isLag);
      }
    } @catch (NSException *exception) {
      // A failed observation does not mean the insert itself failed. Keep the
      // direct state and validate it from the next real key event.
      DKSTLog(@"Deferred direct insert validation after exception: %@",
              exception);
    }
  }

  [_compositionState updateBufferContents:replacement];
  NSString *previousBuffer = [_compositionState previousBufferContents];
  if (previousBuffer &&
      ![replacement isEqualToString:previousBuffer]) {
    _compositionState.shouldCheckInsertionError = NO;
  }
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

  return YES;
}

- (void)updateInlineForClient:(id)sender {
  if (!_useMarkedTextForClient) {
    BOOL directOK = [self updateDirectComposition:sender];
    if (!directOK) {
      DKSTLog(@"Direct composition failed; switching to marked text for "
              @"current composition");
      _useMarkedTextForClient = YES;

      // Migrate direct composition state to marked text
      if (_markedReplacementRange.location == NSNotFound &&
          _directInputComposedRange.location != NSNotFound) {
        [self setMarkedReplacementRange:_directInputComposedRange];
      }
      [self clearDirectCompositionStatePreservingMarkedRange:YES];

      // Re-update using marked text mode immediately
      [self updateComposition:sender];
    }
    return;
  }

  // Marked text path
  if (_markedReplacementRange.location == NSNotFound &&
      _directInputComposedRange.location != NSNotFound) {
    [self setMarkedReplacementRange:_directInputComposedRange];
  }
  [self clearDirectCompositionStatePreservingMarkedRange:YES];
  [self updateComposition:sender];
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
    [self clearDirectCompositionStatePreservingMarkedRange:NO];
    [_markedTextCommittedPrefix setString:@""];
    [self rememberSelectedRangeForClient:sender];
    return;
  }

  // Check if there is anything to commit
  NSString *commit = [engine commitString]; // This also clears internal buffer
  NSString *composed = [engine composedString]; // Should be empty after reset
                                                // usually, unless engine splits

  // In simple engine, commitString usually consumes all.
  // If engine has composed string, force commit it.
  // Wait, SimpleEngine 'commitString' getter clears 'completed'.
  // 'composedString' comes from _cho/_jung/_jong. We should flush composed to
  // commit.

  // Hard reset engine to flush
  // Insert text in correct order: Completed first, then Composed
  NSString *finalText = @"";
  if ([commit length] > 0 && [composed length] > 0) {
    finalText = [commit stringByAppendingString:composed];
  } else if ([commit length] > 0) {
    finalText = commit;
  } else if ([composed length] > 0) {
    finalText = composed;
  }

  if ([finalText length] > 0) {
    [sender insertText:finalText
        replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
  } else {
    // Only if nothing was inserted, clear marked text explicitly
    [sender setMarkedText:@""
           selectionRange:NSMakeRange(0, 0)
         replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
  }

  [engine reset];
  [self clearDirectCompositionStatePreservingMarkedRange:NO];
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
- (void)openSettingsApplication {
  NSBundle *inputMethodBundle = [NSBundle bundleForClass:[self class]];
  NSString *path =
      [inputMethodBundle pathForResource:@"DKSTSettings" ofType:@"app"];

  // bundleForClass:가 예기치 않게 다른 번들을 반환하는 환경에서도 설치된
  // 입력기 번들의 Resources 디렉터리를 직접 확인합니다.
  if (!path) {
    NSString *fallbackPath =
        [[[NSBundle mainBundle] resourcePath]
            stringByAppendingPathComponent:@"DKSTSettings.app"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:fallbackPath]) {
      path = fallbackPath;
    }
  }

  if (path) {
    NSURL *url = [NSURL fileURLWithPath:path];
    NSWorkspaceOpenConfiguration *configuration =
        [NSWorkspaceOpenConfiguration configuration];
    configuration.activates = YES;
    configuration.addsToRecentItems = NO;

    [[NSWorkspace sharedWorkspace]
        openApplicationAtURL:url
               configuration:configuration
           completionHandler:^(NSRunningApplication *runningApp,
                               NSError *error) {
             if (error) {
               DKSTLog(@"Failed to launch Settings app: %@", error);
               return;
             }

             // 이미 실행 중이거나 뒤에 가려진 경우에도 설정 창을 앞으로
             // 가져옵니다. applicationShouldHandleReopen:도 창을 다시 엽니다.
             if (runningApp) {
               BOOL activated = [runningApp
                   activateWithOptions:NSApplicationActivateAllWindows];
               if (!activated) {
                 DKSTLog(@"Settings app launched but could not be activated");
               }
             }
           }];
  } else {
    DKSTLog(@"Could not find Settings app at %@", path);
  }
}

- (void)showPreferences:(id)sender {
  (void)sender;
  [self openSettingsApplication];
}

- (void)showSettings:(id)sender {
  (void)sender;
  [self openSettingsApplication];
}

- (NSMenu *)menu {
  NSMenu *menu = [[[NSMenu alloc] initWithTitle:@"DKST"] autorelease];

  NSMenuItem *settingsItem =
      [[[NSMenuItem alloc] initWithTitle:@"Settings..."
                                  action:@selector(showSettings:)
                           keyEquivalent:@""] autorelease];
  [settingsItem setTarget:self];
  [menu addItem:settingsItem];

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

@end
