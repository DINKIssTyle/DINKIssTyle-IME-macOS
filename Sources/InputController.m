#import "InputController.h"
#import "DKSTConstants.h"
#import "DKSTHanjaDictionary.h"
#import "PreferencesController.h"

@implementation InputController

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
      @"EnableCapsLockSwitch" : @NO,
      @"EnableMoaJjiki" : @YES,
      @"FullCharacterDelete" : @NO,
      @"EnableCustomShift" : @NO,
      kDKSTUseMarkedTextForAllAppsKey : @NO,
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

    // Always create IMKCandidates for all clients
    _candidates = [[IMKCandidates alloc]
        initWithServer:server
             panelType:kIMKSingleColumnScrollingCandidatePanel];
    _lastClientSyncTime = 0;
    _directInputComposedLength = 0;
    _directInputComposedRange = NSMakeRange(NSNotFound, 0);
    _markedReplacementRange = NSMakeRange(NSNotFound, 0);
    _forcedMarkedTextBundleIDs = [[NSMutableSet alloc] init];
    _useMarkedTextForClient = NO;

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

  // WARNING: Do NOT release _candidates here!
  // InputMethodKit internally caches a reference to the IMKCandidates object
  // and may call methods on it (like isVisible) after our dealloc is called.
  // Releasing it here causes a use-after-free crash in
  // -[_IMKServerLegacy deactivateServer_CommonWithClientWrapper:controller:]
  // This is a known issue/workaround for macOS 26 beta InputMethodKit.
  // The memory will be managed by InputMethodKit.

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
  if (_forcedMarkedTextBundleIDs) {
    [_forcedMarkedTextBundleIDs release];
    _forcedMarkedTextBundleIDs = nil;
  }
  [super dealloc];
}

- (NSString *)bundleIdentifierForClient:(id)sender {
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

- (NSRange)directInputReplacementRange:(id)sender {
  if (_directInputComposedLength == 0 || !sender) {
    return _directInputComposedRange;
  }

  @try {
    NSRange selectedRange = [sender selectedRange];
    if (selectedRange.location != NSNotFound &&
        selectedRange.length == 0 &&
        selectedRange.location >= _directInputComposedLength) {
      return NSMakeRange(selectedRange.location - _directInputComposedLength,
                         _directInputComposedLength);
    }
  } @catch (NSException *exception) {
    DKSTLog(@"Exception in directInputReplacementRange: %@", exception);
  }

  return _directInputComposedRange;
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

- (BOOL)shouldUseMarkedTextForClient:(id)sender {
  if ([[NSUserDefaults standardUserDefaults]
          boolForKey:kDKSTUseMarkedTextForAllAppsKey]) {
    return YES;
  }

  NSString *bundleID = [self bundleIdentifierForClient:sender];

  if (![bundleID length]) {
    return YES;
  }

  if ([_forcedMarkedTextBundleIDs containsObject:bundleID]) {
    return YES;
  }

  NSArray *bundleIDs =
      [[NSUserDefaults standardUserDefaults] arrayForKey:kDKSTMarkedTextAppBundleIDsKey];
  if (![bundleIDs count]) {
    bundleIDs = DKSTDefaultMarkedTextAppBundleIDs();
  }

  for (NSString *markedBundleID in bundleIDs) {
    NSString *trimmed = [markedBundleID
        stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([trimmed length] > 0 && [bundleID isEqualToString:trimmed]) {
      return YES;
    }
  }

  @try {
    if (![sender respondsToSelector:@selector(selectedRange)]) {
      return YES;
    }
    NSRange selectedRange = [sender selectedRange];
    if (selectedRange.location == NSNotFound) {
      return YES;
    }
  } @catch (NSException *exception) {
    DKSTLog(@"Exception checking selected range for direct input: %@",
            exception);
    return YES;
  }

  return NO;
}

- (BOOL)isHangulKeyCode:(unsigned short)keyCode {
  switch (keyCode) {
  case 0:  // a
  case 1:  // s
  case 2:  // d
  case 3:  // f
  case 4:  // h
  case 5:  // g
  case 6:  // z
  case 7:  // x
  case 8:  // c
  case 9:  // v
  case 11: // b
  case 12: // q
  case 13: // w
  case 14: // e
  case 15: // r
  case 16: // y
  case 17: // t
  case 31: // o
  case 32: // u
  case 34: // i
  case 35: // p
  case 37: // l
  case 38: // j
  case 40: // k
  case 45: // n
  case 46: // m
    return YES;
  default:
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

- (void)applyUserPreferences {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

  BOOL moaEnabled = [defaults boolForKey:@"EnableMoaJjiki"];
  [engine setMoaJjikiEnabled:moaEnabled];

  BOOL fullDelete = [defaults boolForKey:@"FullCharacterDelete"];
  [engine setFullCharacterDelete:fullDelete];
}

// MARK: - Input Method Kit Methods

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

  [self syncInputClient:sender force:YES];

  [self applyUserPreferences];
  _useMarkedTextForClient = [self shouldUseMarkedTextForClient:sender];

  // Ensure clean state and force Hangul mode on activation
  [engine reset];
  _directInputComposedLength = 0;
  _directInputComposedRange = NSMakeRange(NSNotFound, 0);
  _markedReplacementRange = NSMakeRange(NSNotFound, 0);
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

- (BOOL)handleEvent:(NSEvent *)event client:(id)sender {
  // 1. Check if Preferences Window is Key (Active)
  NSWindow *prefWindow = [[PreferencesController sharedController] window];
  if (prefWindow && [prefWindow isKeyWindow]) {
    [NSApp sendEvent:event];
    return YES; // Stop IMK from processing it for the client (TextEdit)
  }

  unsigned short keyCode = [event keyCode];

  // Filter out everything but KeyDown (fixes Option release bug closing
  // candidates)
  if ([event type] != NSEventTypeKeyDown) {
    return NO;
  }

  // Do not reselect/override the input client while handling a text key. Doing
  // so can race the current event and let the first Roman character leak.
  [self applyUserPreferences];
  _useMarkedTextForClient = [self shouldUseMarkedTextForClient:sender];

  // Process Candidate Navigation (Arrow keys, Enter, Space, numbers)
  if ([_candidates isVisible]) {
    DKSTLog(@"Candidate window is visible, keyCode=%d", keyCode);
    BOOL handled = NO;
    if (keyCode == 126) { // Up
      if (_currentHanjaCandidates && [_currentHanjaCandidates count] > 0) {
        _currentHanjaIndex--;
        if (_currentHanjaIndex < 0) {
          _currentHanjaIndex =
              [_currentHanjaCandidates count] - 1; // Wrap to bottom
        }

        // Restore Visuals: Let IMKCandidates handle the UI
        [_candidates performSelector:@selector(moveUp:) withObject:sender];

        DKSTLog(@"Arrow Up: Index is now %ld", (long)_currentHanjaIndex);
      }
      handled = YES;
    } else if (keyCode == 125) { // Down
      if (_currentHanjaCandidates && [_currentHanjaCandidates count] > 0) {
        _currentHanjaIndex++;
        if (_currentHanjaIndex >= [_currentHanjaCandidates count]) {
          _currentHanjaIndex = 0; // Wrap to top
        }

        // Restore Visuals
        [_candidates performSelector:@selector(moveDown:) withObject:sender];

        DKSTLog(@"Arrow Down: Index is now %ld", (long)_currentHanjaIndex);
      }
      handled = YES;
    } else if (keyCode == 124) { // Right (Treat as Down for single column)
      if (_currentHanjaCandidates && [_currentHanjaCandidates count] > 0) {
        _currentHanjaIndex++;
        if (_currentHanjaIndex >= [_currentHanjaCandidates count]) {
          _currentHanjaIndex = 0;
        }
        // Restore Visuals
        [_candidates performSelector:@selector(moveRight:) withObject:sender];
      }
      handled = YES;
    } else if (keyCode == 123) { // Left (Treat as Up for single column)
      if (_currentHanjaCandidates && [_currentHanjaCandidates count] > 0) {
        _currentHanjaIndex--;
        if (_currentHanjaIndex < 0) {
          _currentHanjaIndex = [_currentHanjaCandidates count] - 1;
        }
        // Restore Visuals
        [_candidates performSelector:@selector(moveLeft:) withObject:sender];
      }
      handled = YES;
    } else if (keyCode == 116) { // Page Up
      if (_currentHanjaCandidates && [_currentHanjaCandidates count] > 0) {
        _currentHanjaIndex -= 9; // Jump 9
        if (_currentHanjaIndex < 0)
          _currentHanjaIndex = 0;

        // Restore Visuals
        [_candidates performSelector:@selector(pageUp:) withObject:sender];
      }
      handled = YES;
    } else if (keyCode == 121) { // Page Down
      if (_currentHanjaCandidates && [_currentHanjaCandidates count] > 0) {
        _currentHanjaIndex += 9;
        if (_currentHanjaIndex >= [_currentHanjaCandidates count])
          _currentHanjaIndex = [_currentHanjaCandidates count] - 1;

        // Restore Visuals
        [_candidates performSelector:@selector(pageDown:) withObject:sender];
      }
      handled = YES;
    } else if (keyCode == 53) { // ESC
      [_candidates hide];
      handled = YES;
    } else if (keyCode == 36 || keyCode == 49) { // Enter or Space
      DKSTLog(@"Enter/Space pressed. Current Index: %ld",
              (long)_currentHanjaIndex);

      if (_currentHanjaCandidates && _currentHanjaIndex >= 0 &&
          _currentHanjaIndex < [_currentHanjaCandidates count]) {

        NSString *selected =
            [_currentHanjaCandidates objectAtIndex:_currentHanjaIndex];
        DKSTLog(@"Committing manually tracked candidate: %@", selected);
        [self commitCandidate:selected client:sender];
        handled = YES;
      } else {
        // Fallback (shouldn't happen if candidates exist)
        [_candidates hide];
        handled = YES;
      }
    } else if (keyCode >= 18 && keyCode <= 29) { // Numbers
      // Simple map: 18=1, 19=2, 20=3, 21=4, 23=5, 22=6, 26=7, 28=8, 25=9, 29=0
      NSInteger index = -1;
      if (keyCode == 18)
        index = 0;
      else if (keyCode == 19)
        index = 1;
      else if (keyCode == 20)
        index = 2;
      else if (keyCode == 21)
        index = 3;
      else if (keyCode == 23)
        index = 4;
      else if (keyCode == 22)
        index = 5;
      else if (keyCode == 26)
        index = 6;
      else if (keyCode == 28)
        index = 7;
      else if (keyCode == 25)
        index = 8;

      if (index >= 0) {
        // Use offset logic if we had pagination, but here we just map 1-9 to
        // first 9 items
        if (_currentHanjaCandidates &&
            index < [_currentHanjaCandidates count]) {
          _currentHanjaIndex = index; // Update index

          NSString *selected =
              [_currentHanjaCandidates objectAtIndex:_currentHanjaIndex];
          [self commitCandidate:selected client:sender];
        }
      }
      handled = YES;
    }

    if (handled) {
      return YES;
    }

    // Character key while candidates open: hide and proceed (typing will commit
    // naturally)
    [_candidates hide];
  }

  // Handle modifier keys
  // NOTE: validation of Shift for shortcuts requires it to be preserved in the
  // mask
  NSUInteger modifiers =
      [event modifierFlags] &
      (NSEventModifierFlagCommand | NSEventModifierFlagControl |
       NSEventModifierFlagOption | NSEventModifierFlagShift);

  // NSLog(@"DKST: handleEvent keyCode: %d, type: %lu", keyCode, (unsigned
  // long)[event type]);

  // Check for Caps Lock (keyCode 57) - Removed to follow Mac System Preferences
  // System "Use Caps Lock to switch..." will handle input source switching if
  // enabled.

  // Hanja Conversion: Option + Return (keyCode 36)
  BOOL hanjaEnabled = YES;
  if ([[NSUserDefaults standardUserDefaults] objectForKey:@"EnableHanja"] !=
      nil) {
    hanjaEnabled =
        [[NSUserDefaults standardUserDefaults] boolForKey:@"EnableHanja"];
  }

  if (hanjaEnabled && (keyCode == 36) &&
      (modifiers == NSEventModifierFlagOption)) {
    NSString *composed = [engine composedString];
    if ([composed length] > 0) {
      // Existing behavior: Convert composed text
      NSArray *candidates =
          [[DKSTHanjaDictionary sharedDictionary] hanjaForHangul:composed];

      // Always include the original text as a candidate (like Apple's default
      // IME)
      NSMutableArray *allCandidates = [NSMutableArray array];
      if (candidates && [candidates count] > 0) {
        [allCandidates addObjectsFromArray:candidates];
      }
      // Add original text (truncate if too long)
      NSString *originalText = composed;
      if ([originalText length] > 10) {
        originalText =
            [[originalText substringToIndex:10] stringByAppendingString:@"..."];
      }
      [allCandidates addObject:originalText];

      if ([allCandidates count] > 0) {
        if (_currentHanjaCandidates) {
          [_currentHanjaCandidates release];
        }
        _currentHanjaCandidates = [allCandidates retain];

        _selectedTextRange = [self compositionReplacementRange:sender];
        if (_useMarkedTextForClient) {
          _markedReplacementRange = _selectedTextRange;
        }

        DKSTLog(@"Candidates count: %lu", (unsigned long)[allCandidates count]);
        for (NSUInteger i = 0; i < [allCandidates count]; i++) {
          DKSTLog(@"  Candidate[%lu]: '%@' (class: %@)", i,
                  [allCandidates objectAtIndex:i],
                  [[allCandidates objectAtIndex:i] class]);
        }

        // Use updateCandidates to trigger data source method candidates:
        [_candidates updateCandidates];
        [_candidates show:kIMKLocateCandidatesBelowHint];

        // Force select the first candidate (index 0)
        _currentHanjaIndex = 0; // Initialize index
        NSInteger firstId = [_candidates candidateIdentifierAtLineNumber:0];
        if (firstId != NSNotFound) {
          [_candidates selectCandidateWithIdentifier:firstId];
        }
        return YES;
      }
    } else {
      // New behavior: Try to convert selected text
      NSRange selectedRange = [sender selectedRange];
      DKSTLog(@"Selected range: location=%lu, length=%lu",
              (unsigned long)selectedRange.location,
              (unsigned long)selectedRange.length);

      if (selectedRange.length > 0 && selectedRange.location != NSNotFound) {
        NSAttributedString *selectedAttrString =
            [sender attributedSubstringFromRange:selectedRange];
        NSString *selectedText = [selectedAttrString string];
        DKSTLog(@"Selected text: %@", selectedText);

        if (selectedText && [selectedText length] > 0) {
          NSArray *candidates = [[DKSTHanjaDictionary sharedDictionary]
              hanjaForHangul:selectedText];

          // Always include the original text as a candidate
          NSMutableArray *allCandidates = [NSMutableArray array];
          if (candidates && [candidates count] > 0) {
            [allCandidates addObjectsFromArray:candidates];
          }
          // Add original text (truncate if too long)
          NSString *originalText = selectedText;
          if ([originalText length] > 10) {
            originalText = [[originalText substringToIndex:10]
                stringByAppendingString:@"..."];
          }
          [allCandidates addObject:originalText];

          if ([allCandidates count] > 0) {
            if (_currentHanjaCandidates) {
              [_currentHanjaCandidates release];
            }
            _currentHanjaCandidates = [allCandidates retain];

            // Store the selected range for later replacement
            _selectedTextRange = selectedRange;
            _markedReplacementRange = selectedRange;

            DKSTLog(@"Candidates for '%@': count=%lu", selectedText,
                    (unsigned long)[allCandidates count]);
            for (NSUInteger i = 0; i < [allCandidates count]; i++) {
              DKSTLog(@"  Candidate[%lu]: '%@' (class: %@)", i,
                      [allCandidates objectAtIndex:i],
                      [[allCandidates objectAtIndex:i] class]);
            }

            // Use updateCandidates to trigger data source method candidates:
            [_candidates updateCandidates];
            [_candidates show:kIMKLocateCandidatesBelowHint];

            // Force select the first candidate
            _currentHanjaIndex = 0; // Initialize index
            NSInteger firstId = [_candidates candidateIdentifierAtLineNumber:0];
            if (firstId != NSNotFound) {
              [_candidates selectCandidateWithIdentifier:firstId];
            }
            return YES;
          }
        }
      }
    }
  } // Allow Pass-through for Command/Ctrl/Option
  // If modifiers have Cmd/Ctrl/Option, pass through. Shift is allowed for
  // processing.
  if ((modifiers & (NSEventModifierFlagCommand | NSEventModifierFlagControl |
                    NSEventModifierFlagOption)) != 0) {
    [self commitComposition:sender];
    return NO;
  }

  // Tab Handling (keyCode 48) - removed as requested, just pass through or
  // commit
  if (keyCode == 48) {
    [self commitComposition:sender];
    return NO;
  }

  // Backspace Handling (keyCode 51)
  if (keyCode == 51) {
    if ([engine backspace]) {
      if (_useMarkedTextForClient) {
        [self updateInlineForClient:sender];
      } else {
        NSString *composedAfterBackspace = [engine composedString];
        if ([composedAfterBackspace length] == 0 &&
            _directInputComposedLength > 0) {
          _directInputComposedLength = 0;
          _directInputComposedRange = NSMakeRange(NSNotFound, 0);
          _markedReplacementRange = NSMakeRange(NSNotFound, 0);
          return NO;
        }
        [self updateInlineForClient:sender];
      }
      return YES;
    } else {
      return NO;
    }
  }

  if ((keyCode == 36 || keyCode == 49) &&
      ![_candidates isVisible]) { // Enter or Space
    [self commitComposition:sender];
    return NO;
  }

  // Check mode - Removed to enforce Hangul processing at all times.
  // We treat this Input Method as purely Hangul. English is handled by
  // switching to "ABC" Input Source.

  // CUSTOM SHIFT SHORTCUT CHECK
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  BOOL shiftEnabled = [defaults boolForKey:@"EnableCustomShift"];

  if (shiftEnabled && (modifiers == NSEventModifierFlagShift)) {
    // Map keyCode to key string used in dictionary
    NSString *lookupKey = nil;
    switch (keyCode) {
    case 16:
      lookupKey = @"y (ㅛ)";
      break;
    case 32:
      lookupKey = @"u (ㅕ)";
      break;
    case 34:
      lookupKey = @"i (ㅑ)";
      break;
    case 0:
      lookupKey = @"a (ㅁ)";
      break;
    case 1:
      lookupKey = @"s (ㄴ)";
      break;
    case 2:
      lookupKey = @"d (ㅇ)";
      break;
    case 3:
      lookupKey = @"f (ㄹ)";
      break;
    case 5:
      lookupKey = @"g (ㅎ)";
      break;
    case 4:
      lookupKey = @"h (ㅗ)";
      break;
    case 38:
      lookupKey = @"j (ㅓ)";
      break;
    case 40:
      lookupKey = @"k (ㅏ)";
      break;
    case 37:
      lookupKey = @"l (ㅣ)";
      break;
    case 6:
      lookupKey = @"z (ㅋ)";
      break;
    case 7:
      lookupKey = @"x (ㅌ)";
      break;
    case 8:
      lookupKey = @"c (ㅊ)";
      break;
    case 9:
      lookupKey = @"v (ㅍ)";
      break;
    case 11:
      lookupKey = @"b (ㅠ)";
      break;
    case 45:
      lookupKey = @"n (ㅜ)";
      break;
    case 46:
      lookupKey = @"m (ㅡ)";
      break;
    default:
      break;
    }

    if (lookupKey) {
      NSDictionary *mappings =
          [defaults dictionaryForKey:@"DKSTCustomShiftMappings"];
      NSString *output = [mappings objectForKey:lookupKey];
      if (output && [output length] > 0) {
        // If we have mapped content, commit it directly
        // First commit any pending composition
        [self commitComposition:sender];

        [sender insertText:output
            replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
        return YES; // Consumed
      }
    }
  }

  // Process Candidate Navigation (Arrow keys, Enter, Space, numbers)
  // Process Candidate Navigation (Arrow keys, Enter, Space, numbers)

  // Process Hangul
  BOOL processed = [engine processCode:keyCode modifiers:[event modifierFlags]];

  if (processed) {
    // If Candidate window is visible and we start typing something else, hide
    // it.
    if ([_candidates isVisible]) {
      [_candidates hide];
    }

    if (_useMarkedTextForClient) {
      NSString *commit = [engine commitString];
      if ([commit length] > 0) {
        [sender insertText:commit
            replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
      }
      [self updateInlineForClient:sender];
    } else {
      [self updateInlineForClient:sender];
    }
    return YES;
  } else {
    // Not processed (e.g. non-hangul key)

    if ([self isHangulKeyCode:keyCode]) {
      DKSTLog(@"Blocked unprocessed Hangul keyCode=%d", keyCode);
      [self updateInlineForClient:sender];
      return YES;
    }

    // If Candidate window is visible, we might be navigating.
    // With SendServerKeyEventFirst = NO, we should only hit this if candidates
    // didn't handle it.
    if ([_candidates isVisible]) {
      // Check if it's a navigation/selection key. If so, return NO to let
      // client handle it BUT do NOT commit, so the candidate window keeps its
      // context.
      if (keyCode == 123 || keyCode == 124 || keyCode == 125 ||
          keyCode == 126 || keyCode == 36 || keyCode == 49 || keyCode == 53 ||
          (keyCode >= 18 && keyCode <= 29)) {
        return NO;
      }

      // For other keys while visible, hide candidates and then commit.
      [_candidates hide];
    }

    // Otherwise, commit pending and let system handle
    [self commitComposition:sender];
    return NO;
  }
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
  } else {
    [sender setMarkedText:@""
           selectionRange:NSMakeRange(0, 0)
         replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
    _markedReplacementRange = NSMakeRange(NSNotFound, 0);
  }
}

- (void)updateDirectComposition:(id)sender {
  NSString *commit = [engine commitString];
  NSString *composed = [engine composedString];
  NSUInteger commitLength = [commit length];
  NSUInteger composedLength = [composed length];
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

  if (expectedLocation != NSNotFound && composedLength > 0) {
    @try {
      NSRange selectedRange = [sender selectedRange];
      if (selectedRange.location == NSNotFound ||
          selectedRange.location != expectedLocation) {
        [self forceMarkedTextForClient:sender
                                reason:@"direct insert cursor mismatch"];
        DKSTLog(@"Keeping current direct composition; marked text starts on next composition update");
      }
    } @catch (NSException *exception) {
      DKSTLog(@"Exception checking direct insert result: %@", exception);
      [self forceMarkedTextForClient:sender
                              reason:@"direct insert selectedRange exception"];
    }
  }

  _directInputComposedLength = composedLength;
  if (composedLength > 0 && replacementStart != NSNotFound) {
    _directInputComposedRange =
        NSMakeRange(replacementStart + commitLength, composedLength);
  } else {
    _directInputComposedRange = NSMakeRange(NSNotFound, 0);
  }
  _markedReplacementRange = NSMakeRange(NSNotFound, 0);
}

- (void)updateInlineForClient:(id)sender {
  _useMarkedTextForClient = [self shouldUseMarkedTextForClient:sender];
  if (_useMarkedTextForClient) {
    if (_markedReplacementRange.location == NSNotFound &&
        _directInputComposedRange.location != NSNotFound) {
      _markedReplacementRange = _directInputComposedRange;
    }
    _directInputComposedLength = 0;
    _directInputComposedRange = NSMakeRange(NSNotFound, 0);
    [self updateComposition:sender];
  } else {
    [self updateDirectComposition:sender];
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
    _directInputComposedLength = 0;
    _directInputComposedRange = NSMakeRange(NSNotFound, 0);
    _markedReplacementRange = NSMakeRange(NSNotFound, 0);
    [sender setMarkedText:@""
           selectionRange:NSMakeRange(0, 0)
         replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
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
  if ([commit length] > 0) {
    [sender insertText:commit
        replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
  }
  if ([composed length] > 0) {
    [sender insertText:composed
        replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
  }

  [engine reset];
  _directInputComposedLength = 0;
  _directInputComposedRange = NSMakeRange(NSNotFound, 0);
  _markedReplacementRange = NSMakeRange(NSNotFound, 0);
  [sender setMarkedText:@""
         selectionRange:NSMakeRange(0, 0)
       replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
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
- (void)showPreferences:(id)sender {
  NSString *path = [[NSBundle mainBundle] pathForResource:@"DKSTPreferences"
                                                   ofType:@"app"];
  if (path) {
    NSURL *url = [NSURL fileURLWithPath:path];
    [[NSWorkspace sharedWorkspace]
        openApplicationAtURL:url
               configuration:[NSWorkspaceOpenConfiguration configuration]
           completionHandler:^(NSRunningApplication *app, NSError *error) {
             if (error) {
               DKSTLog(@"Failed to launch Preferences app: %@", error);
             }
           }];
  } else {
    DKSTLog(@"Could not find Preferences app at %@", path);
  }
}

- (void)launchDictEditor:(id)sender {
  NSString *appPath = [[NSBundle mainBundle] pathForResource:@"DKSTDictEditor"
                                                      ofType:@"app"];
  if (appPath) {
    NSURL *appUrl = [NSURL fileURLWithPath:appPath];
    NSWorkspaceOpenConfiguration *config =
        [NSWorkspaceOpenConfiguration configuration];
    [[NSWorkspace sharedWorkspace]
        openApplicationAtURL:appUrl
               configuration:config
           completionHandler:^(NSRunningApplication *_Nullable app,
                               NSError *_Nullable error) {
             if (error) {
               DKSTLog(@"DKST: Failed to launch DictEditor: %@", error);
             }
           }];
  } else {
    DKSTLog(@"DKST: DKSTDictEditor.app not found in bundle resources.");
  }
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

  /* functionality not yet implemented
  NSMenuItem *englishItem = [[[NSMenuItem alloc] initWithTitle:@"English"
  action:@selector(selectInputMode:) keyEquivalent:@""] autorelease];
  [englishItem setTag:0];
  if ([currentMode isEqualToString:kDKSTEnglishMode]) {
      [englishItem setState:NSControlStateValueOn];
  } else {
      [englishItem setState:NSControlStateValueOff];
  }
  [menu addItem:englishItem];

  NSMenuItem *hangulItem = [[[NSMenuItem alloc] initWithTitle:@"Hangul"
  action:@selector(selectInputMode:) keyEquivalent:@""] autorelease];
  [hangulItem setTag:1];
  if ([currentMode isEqualToString:kDKSTHangulMode]) {
      [hangulItem setState:NSControlStateValueOn];
  } else {
      [hangulItem setState:NSControlStateValueOff];
  }
  [menu addItem:hangulItem];
  */

  return menu;
}

- (void)selectInputMode:(id)sender {
  NSInteger tag = [sender tag];
  NSString *newMode = (tag == 0) ? kDKSTEnglishMode : kDKSTHangulMode;

  if (currentMode != newMode) {
    [currentMode release];
    currentMode = [newMode retain];
  }

  [[self client] selectInputMode:newMode];
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
      [sender insertText:hanja replacementRange:replacementRange];
      [engine reset];
      _directInputComposedLength = 0;
      _directInputComposedRange = NSMakeRange(NSNotFound, 0);
      _markedReplacementRange = NSMakeRange(NSNotFound, 0);
    } else {
      DKSTLog(@"Failed to extract hanja from '%@'", selected);
    }
  } else {
    DKSTLog(@"No candidate selected to commit");
  }

  // Reset selected range
  _selectedTextRange = NSMakeRange(NSNotFound, 0);
  _markedReplacementRange = NSMakeRange(NSNotFound, 0);
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
