#import "InputController.h"
#import "DKSTConstants.h"
#import "PreferencesController.h"
#import "DKSTHanjaDictionary.h"

@implementation InputController

- (id)initWithServer:(IMKServer *)server delegate:(id)delegate client:(id)inputClient {
    self = [super initWithServer:server delegate:delegate client:inputClient];
    if (self) {
        engine = [[DKSTHangul alloc] init];
        currentMode = kDKSTHangulMode; // Default to Hangul
        
        // Set default preference
        [[NSUserDefaults standardUserDefaults] registerDefaults:@{ 
            @"EnableCapsLockSwitch": @NO,
            @"EnableMoaJjiki": @YES,
            @"FullCharacterDelete": @NO,
            @"EnableCustomShift": @NO
        }];

        _candidates = [[IMKCandidates alloc] initWithServer:server panelType:kIMKSingleColumnScrollingCandidatePanel];
        [_candidates setAttributes:@{IMKCandidatesSendServerKeyEventFirst: @YES}];
        [_candidates setSelectionKeys:[NSArray arrayWithObjects:@"1", @"2", @"3", @"4", @"5", @"6", @"7", @"8", @"9", nil]];
    }
    return self;
}

- (void)dealloc {
    [_candidates release];
    [engine release];
    [super dealloc];
}

// MARK: - Input Method Kit Methods

- (void)activateServer:(id)sender {
    DKSTLog(@"activateServer called");
    [sender overrideKeyboardWithKeyboardNamed:@"com.apple.keylayout.US"];
    
    // Apply Preferences
    BOOL moaEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"EnableMoaJjiki"];
    [engine setMoaJjikiEnabled:moaEnabled];
    
    BOOL fullDelete = [[NSUserDefaults standardUserDefaults] boolForKey:@"FullCharacterDelete"];
    [engine setFullCharacterDelete:fullDelete];
    
    // Ensure clean state and force Hangul mode on activation
    [engine reset];
    
    // Since we rely on system switching, this Input Method should always be in Hangul mode when active.
    currentMode = kDKSTHangulMode;
    [sender selectInputMode:currentMode];
}

- (void)deactivateServer:(id)sender {
    DKSTLog(@"deactivateServer called");
    [self commitComposition:sender];
}

- (BOOL)handleEvent:(NSEvent *)event client:(id)sender {
    // 1. Check if Preferences Window is Key (Active)
    NSWindow *prefWindow = [[PreferencesController sharedController] window];
    if (prefWindow && [prefWindow isKeyWindow]) {
        [NSApp sendEvent:event];
        return YES; // Stop IMK from processing it for the client (TextEdit)
    }

    unsigned short keyCode = [event keyCode];

    // Filter out everything but KeyDown (fixes Option release bug closing candidates)
    if ([event type] != NSEventTypeKeyDown) {
        return NO;
    }

    // Process Candidate Navigation (Arrow keys, Enter, Space, numbers)
    if ([_candidates isVisible]) {
        DKSTLog(@"Candidate window is visible, keyCode=%d", keyCode);
        BOOL handled = NO;
        if (keyCode == 126) { // Up
            [_candidates performSelector:@selector(moveUp:) withObject:sender];
            handled = YES;
        } else if (keyCode == 125) { // Down
            [_candidates performSelector:@selector(moveDown:) withObject:sender];
            handled = YES;
        } else if (keyCode == 124) { // Right
            [_candidates performSelector:@selector(moveRight:) withObject:sender];
            handled = YES;
        } else if (keyCode == 123) { // Left
            [_candidates performSelector:@selector(moveLeft:) withObject:sender];
            handled = YES;
        } else if (keyCode == 116) { // Page Up
            [_candidates performSelector:@selector(pageUp:) withObject:sender];
            handled = YES;
        } else if (keyCode == 121) { // Page Down
            [_candidates performSelector:@selector(pageDown:) withObject:sender];
            handled = YES;
        } else if (keyCode == 53) { // ESC
            [_candidates hide];
            handled = YES;
        } else if (keyCode == 36 || keyCode == 49) { // Enter or Space
            DKSTLog(@"Enter/Space pressed in candidate window");
            // Select current
            NSAttributedString *current = [_candidates selectedCandidateString];
            DKSTLog(@"selectedCandidateString=%@", current);
            
            // If no candidate is selected, try to use the first one from our persisted array
            if (!current && _currentHanjaCandidates && [_currentHanjaCandidates count] > 0) {
                DKSTLog(@"Using first candidate from _currentHanjaCandidates");
                NSString *firstCandidate = [_currentHanjaCandidates objectAtIndex:0];
                [self commitCandidate:firstCandidate client:sender];
                handled = YES;
            } else if (current) {
                DKSTLog(@"About to call commitCandidate");
                [self commitCandidate:current client:sender];
                handled = YES;
            } else {
                DKSTLog(@"No candidate available, hiding window");
                [_candidates hide];
                handled = YES;
            }
        } else if (keyCode >= 18 && keyCode <= 29) { // Numbers
            // Simple map: 18=1, 19=2, 20=3, 21=4, 23=5, 22=6, 26=7, 28=8, 25=9, 29=0
            NSInteger index = -1;
            if (keyCode == 18) index = 0;
            else if (keyCode == 19) index = 1;
            else if (keyCode == 20) index = 2;
            else if (keyCode == 21) index = 3;
            else if (keyCode == 23) index = 4;
            else if (keyCode == 22) index = 5;
            else if (keyCode == 26) index = 6;
            else if (keyCode == 28) index = 7;
            else if (keyCode == 25) index = 8;
            
            if (index >= 0) {
                 // Map line number to identifier
                 // Since we use single column, index 0 is first line.
                 NSInteger identifier = [_candidates candidateIdentifierAtLineNumber:index];
                 if (identifier != NSNotFound) {
                     [_candidates selectCandidateWithIdentifier:identifier];
                     NSAttributedString *current = [_candidates selectedCandidateString];
                     if (current) {
                         [self commitCandidate:current client:sender];
                     }
                 }
            }
            handled = YES;
        }
        
        if (handled) {
            return YES;
        }
        
        // Character key while candidates open: hide and proceed (typing will commit naturally)
        [_candidates hide];
    }



    // Handle modifier keys
    // NOTE: validation of Shift for shortcuts requires it to be preserved in the mask
    NSUInteger modifiers = [event modifierFlags] & (NSEventModifierFlagCommand | NSEventModifierFlagControl | NSEventModifierFlagOption | NSEventModifierFlagShift);
    

    // NSLog(@"DKST: handleEvent keyCode: %d, type: %lu", keyCode, (unsigned long)[event type]);

    
    // Check for Caps Lock (keyCode 57) - Removed to follow Mac System Preferences
    // System "Use Caps Lock to switch..." will handle input source switching if enabled.




    // Hanja Conversion: Option + Return (keyCode 36)
    BOOL hanjaEnabled = YES;
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"EnableHanja"] != nil) {
        hanjaEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"EnableHanja"];
    }
    
    if (hanjaEnabled && (keyCode == 36) && (modifiers == NSEventModifierFlagOption)) {
         NSString *composed = [engine composedString];
         if ([composed length] > 0) {
             NSArray *candidates = [[DKSTHanjaDictionary sharedDictionary] hanjaForHangul:composed];
             if (candidates && [candidates count] > 0) {
                 if (_currentHanjaCandidates) {
                     [_currentHanjaCandidates release];
                 }
                 _currentHanjaCandidates = [candidates retain];
                 
                 [_candidates setCandidateData:candidates];
                 [_candidates updateCandidates];
                 [_candidates show:kIMKLocateCandidatesBelowHint]; 
                 
                 // Force select the first candidate (index 0)
                 NSInteger firstId = [_candidates candidateIdentifierAtLineNumber:0];
                 if (firstId != NSNotFound) {
                     [_candidates selectCandidateWithIdentifier:firstId];
                 }
                 return YES;
             }
         }
    }

    // Allow Pass-through for Command/Ctrl/Option
    // If modifiers have Cmd/Ctrl/Option, pass through. Shift is allowed for processing.
    if ((modifiers & (NSEventModifierFlagCommand | NSEventModifierFlagControl | NSEventModifierFlagOption)) != 0) {
        [self commitComposition:sender];
        return NO;
    }
    
    // Tab Handling (keyCode 48) - removed as requested, just pass through or commit
    if (keyCode == 48) {
        [self commitComposition:sender];
        return NO;
    }

    // Backspace Handling (keyCode 51)
    if (keyCode == 51) {
        if ([engine backspace]) {
            [self updateComposition:sender];
            return YES;
        } else {
            return NO;
        }
    }

    if ((keyCode == 36 || keyCode == 49) && ![_candidates isVisible]) { // Enter or Space
        [self commitComposition:sender];
        return NO;
    }
    
    // Check mode - Removed to enforce Hangul processing at all times.
    // We treat this Input Method as purely Hangul. English is handled by switching to "ABC" Input Source.
    
    // CUSTOM SHIFT SHORTCUT CHECK
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL shiftEnabled = [defaults boolForKey:@"EnableCustomShift"];
    
    if (shiftEnabled && (modifiers == NSEventModifierFlagShift)) {
        // Map keyCode to key string used in dictionary
        NSString *lookupKey = nil;
        switch (keyCode) {
            case 16: lookupKey = @"y (ㅛ)"; break;
            case 32: lookupKey = @"u (ㅕ)"; break;
            case 34: lookupKey = @"i (ㅑ)"; break;
            case 0:  lookupKey = @"a (ㅁ)"; break;
            case 1:  lookupKey = @"s (ㄴ)"; break;
            case 2:  lookupKey = @"d (ㅇ)"; break;
            case 3:  lookupKey = @"f (ㄹ)"; break;
            case 5:  lookupKey = @"g (ㅎ)"; break;
            case 4:  lookupKey = @"h (ㅗ)"; break;
            case 38: lookupKey = @"j (ㅓ)"; break;
            case 40: lookupKey = @"k (ㅏ)"; break;
            case 37: lookupKey = @"l (ㅣ)"; break;
            case 6:  lookupKey = @"z (ㅋ)"; break;
            case 7:  lookupKey = @"x (ㅌ)"; break;
            case 8:  lookupKey = @"c (ㅊ)"; break;
            case 9:  lookupKey = @"v (ㅍ)"; break;
            case 11: lookupKey = @"b (ㅠ)"; break;
            case 45: lookupKey = @"n (ㅜ)"; break;
            case 46: lookupKey = @"m (ㅡ)"; break;
            default: break;
        }
        
        if (lookupKey) {
            NSDictionary *mappings = [defaults dictionaryForKey:@"DKSTCustomShiftMappings"];
            NSString *output = [mappings objectForKey:lookupKey];
            if (output && [output length] > 0) {
                // If we have mapped content, commit it directly
                // First commit any pending composition
                [self commitComposition:sender];
                
                [sender insertText:output replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
                return YES; // Consumed
            }
        }
    }
    
    // Process Candidate Navigation (Arrow keys, Enter, Space, numbers)
    // Process Candidate Navigation (Arrow keys, Enter, Space, numbers)


    // Process Hangul
    BOOL processed = [engine processCode:keyCode modifiers:[event modifierFlags]];
    
    if (processed) {
        // If Candidate window is visible and we start typing something else, hide it.
        if ([_candidates isVisible]) {
            [_candidates hide];
        }

        // If engine produced a commit string, commit it first
        NSString *commit = [engine commitString];
        if ([commit length] > 0) {
            [sender insertText:commit replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
        }
        
        // Update preedit
        [self updateComposition:sender];
        return YES;
    } else {
        // Not processed (e.g. non-hangul key)
        
        // If Candidate window is visible, we might be navigating.
        // With SendServerKeyEventFirst = NO, we should only hit this if candidates didn't handle it.
        if ([_candidates isVisible]) {
            // Check if it's a navigation/selection key. If so, return NO to let client handle it
            // BUT do NOT commit, so the candidate window keeps its context.
            if (keyCode == 123 || keyCode == 124 || keyCode == 125 || keyCode == 126 || 
                keyCode == 36 || keyCode == 49 || keyCode == 53 ||
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
        NSMutableAttributedString *attrString = [[[NSMutableAttributedString alloc] initWithString:composed] autorelease];
        
        // Add underline style
        [attrString addAttribute:NSUnderlineStyleAttributeName
                           value:[NSNumber numberWithInt:NSUnderlineStyleSingle]
                           range:NSMakeRange(0, [composed length])];
        
        [sender setMarkedText:attrString
               selectionRange:NSMakeRange([composed length], 0)
             replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
    } else {
        [sender setMarkedText:@"" selectionRange:NSMakeRange(0,0) replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
    }
}

- (void)commitComposition:(id)sender {
    // If Candidate window is visible, we are likely in the middle of choosing a Hanja.
    // Committing now would flush the Hangul and result in double insertion when Hanja is picked.
    if ([_candidates isVisible]) {
        return;
    }
    
    // Check if there is anything to commit
    NSString *commit = [engine commitString]; // This also clears internal buffer
    NSString *composed = [engine composedString]; // Should be empty after reset usually, unless engine splits
    
    // In simple engine, commitString usually consumes all.
    // If engine has composed string, force commit it.
    // Wait, SimpleEngine 'commitString' getter clears 'completed'. 'composedString' comes from _cho/_jung/_jong.
    // We should flush composed to commit.
    
    // Hard reset engine to flush
    // Insert text in correct order: Completed first, then Composed
    if ([commit length] > 0) {
         [sender insertText:commit replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
    }
    if ([composed length] > 0) {
        [sender insertText:composed replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
    }
    
    [engine reset];
    [sender setMarkedText:@"" selectionRange:NSMakeRange(0,0) replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
}

- (void)setValue:(id)value forTag:(long)tag client:(id)sender {
    if (tag == kTextServiceInputModePropertyTag) {
        NSString *newMode = (NSString *)value;
        if (newMode) {
            currentMode = newMode;
            [self commitComposition:sender];
        }
    }
}

// Menu handling (Modes)
- (void)showPreferences:(id)sender {
    NSString *path = [[NSBundle mainBundle] pathForResource:@"DKSTPreferences" ofType:@"app"];
    if (path) {
        NSURL *url = [NSURL fileURLWithPath:path];
        [[NSWorkspace sharedWorkspace] openApplicationAtURL:url
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

- (NSMenu *)menu {
    NSMenu *menu = [[[NSMenu alloc] initWithTitle:@"DKST"] autorelease];
    
    NSMenuItem *prefsItem = [[[NSMenuItem alloc] initWithTitle:@"Preferences..." action:@selector(showPreferences:) keyEquivalent:@""] autorelease];
    [prefsItem setTarget:self];
    [menu addItem:prefsItem];
    
    /* functionality not yet implemented
    NSMenuItem *englishItem = [[[NSMenuItem alloc] initWithTitle:@"English" action:@selector(selectInputMode:) keyEquivalent:@""] autorelease];
    [englishItem setTag:0];
    if ([currentMode isEqualToString:kDKSTEnglishMode]) {
        [englishItem setState:NSControlStateValueOn];
    } else {
        [englishItem setState:NSControlStateValueOff];
    }
    [menu addItem:englishItem];
    
    NSMenuItem *hangulItem = [[[NSMenuItem alloc] initWithTitle:@"Hangul" action:@selector(selectInputMode:) keyEquivalent:@""] autorelease];
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
    currentMode = newMode;
    
    [[self client] selectInputMode:newMode];
}


// Required methods?
// recognizedEvents:
- (NSUInteger)recognizedEvents:(id)sender {
    return NSEventMaskKeyDown | NSEventMaskFlagsChanged;
}

// IMKCandidates Data Source
// IMKCandidates Data Source
- (NSArray *)candidates:(id)sender {
    NSString *composed = [engine composedString];
    if ([composed length] > 0) {
        return [[DKSTHanjaDictionary sharedDictionary] hanjaForHangul:composed];
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
    
    // Fallback: If no candidate provided or nil, use the first available candidate
    if (!selected && _currentHanjaCandidates && [_currentHanjaCandidates count] > 0) {
        selected = [_currentHanjaCandidates objectAtIndex:0];
    }
    
    // Debug log
    DKSTLog(@"commitCandidate selected='%@'", selected);
    
    if (selected) {
        NSString *hanja = [[selected componentsSeparatedByString:@" "] firstObject];
        if (hanja && [hanja length] > 0) {
             // Get the length of the composed Hangul to replace
             NSString *composed = [engine composedString];
             NSUInteger length = [composed length];
             
             // Insert Hanja, replacing the composed Hangul
             // replacementRange with location=0 and length=composedLength will replace the marked text
             [sender insertText:hanja replacementRange:NSMakeRange(0, length)];
             [engine reset];
        } else {
             DKSTLog(@"Failed to extract hanja from '%@'", selected);
        }
    } else {
        DKSTLog(@"No candidate selected to commit");
    }
    
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
