#import "InputController.h"
#import "DKSTConstants.h"
#import "PreferencesController.h"

@implementation InputController

- (id)initWithServer:(IMKServer *)server delegate:(id)delegate client:(id)inputClient {
    self = [super initWithServer:server delegate:delegate client:inputClient];
    if (self) {
        engine = [[DKSTHangul alloc] init];
        currentMode = kDKSTHangulMode; // Default to Hangul
        
        // Set default preference
        [[NSUserDefaults standardUserDefaults] registerDefaults:@{ 
            @"EnableCapsLockSwitch": @YES,
            @"EnableMoaJjiki": @YES
        }];
    }
    return self;
}

- (void)dealloc {
    [engine release];
    [super dealloc];
}

// MARK: - Input Method Kit Methods

- (void)activateServer:(id)sender {
    NSLog(@"DKST: activateServer called");
    [sender overrideKeyboardWithKeyboardNamed:@"com.apple.keylayout.US"];
    
    // Apply Preferences
    BOOL moaEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"EnableMoaJjiki"];
    [engine setMoaJjikiEnabled:moaEnabled];
    
    // Ensure clean state and force Hangul mode on activation
    [engine reset];
    
    // Since we rely on system switching, this Input Method should always be in Hangul mode when active.
    currentMode = kDKSTHangulMode;
    [sender selectInputMode:currentMode];
}

- (void)deactivateServer:(id)sender {
    NSLog(@"DKST: deactivateServer called");
    [self commitComposition:sender];
}

- (BOOL)handleEvent:(NSEvent *)event client:(id)sender {
    // Handle modifier keys, special keys, etc.
    NSUInteger modifiers = [event modifierFlags] & (NSEventModifierFlagCommand | NSEventModifierFlagControl | NSEventModifierFlagOption);
    
    // Allow Pass-through for Command/Ctrl/Option
    if (modifiers != 0 && modifiers != NSEventModifierFlagShift) {
        [self commitComposition:sender];
        return NO;
    }
    
    unsigned short keyCode = [event keyCode];
    // NSLog(@"DKST: handleEvent keyCode: %d, type: %lu", keyCode, (unsigned long)[event type]);

    
    // Check for Caps Lock (keyCode 57) - Removed to follow Mac System Preferences
    // System "Use Caps Lock to switch..." will handle input source switching if enabled.


    if ([event type] != NSEventTypeKeyDown) {
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

    if (keyCode == 36 || keyCode == 49) { // Enter or Space
        [self commitComposition:sender];
        return NO;
    }
    
    // Check mode - Removed to enforce Hangul processing at all times.
    // We treat this Input Method as purely Hangul. English is handled by switching to "ABC" Input Source.
    /*
    if ([currentMode isEqualToString:kDKSTEnglishMode]) {
        return NO; // Let system handle English
    }
    */
    
    // Process Hangul
    BOOL processed = [engine processCode:keyCode modifiers:[event modifierFlags]];
    
    if (processed) {
        // If engine produced a commit string, commit it first
        NSString *commit = [engine commitString];
        if ([commit length] > 0) {
            [sender insertText:commit replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
        }
        
        // Update preedit
        [self updateComposition:sender];
        return YES;
    } else {
        // Not processed (e.g. non-hangul key), commit pending and let system handle
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
    // Check if there is anything to commit
    NSString *commit = [engine commitString]; // This also clears internal buffer
    NSString *composed = [engine composedString]; // Should be empty after reset usually, unless engine splits
    
    // In simple engine, commitString usually consumes all.
    // If engine has composed string, force commit it.
    // Wait, SimpleEngine 'commitString' getter clears 'completed'. 'composedString' comes from _cho/_jung/_jong.
    // We should flush composed to commit.
    
    // Hard reset engine to flush
    if ([composed length] > 0) {
        [sender insertText:composed replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
    }
    if ([commit length] > 0) { // If there was pending commit
         [sender insertText:commit replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
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
    [[PreferencesController sharedController] showPreferences];
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

@end
