#import "PreferencesController.h"

@implementation PreferencesController

+ (PreferencesController *)sharedController {
    static PreferencesController *sharedController = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedController = [[PreferencesController alloc] init];
    });
    return sharedController;
}

// Helper to get shared defaults
- (NSUserDefaults *)defaults {
    // Access the specific domain of the Input Method
    return [[[NSUserDefaults alloc] initWithSuiteName:@"com.dinkisstyle.inputmethod.DKST"] autorelease];
}

- (id)init {
    NSRect frame = NSMakeRect(0, 0, 450, 400); 
    NSWindow *window = [[[NSWindow alloc] initWithContentRect:frame
                                                    styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable)
                                                      backing:NSBackingStoreBuffered
                                                        defer:NO] autorelease];
    [window setTitle:@"DKST Preferences"];
    [window center];
    [window setDelegate:self]; // Set delegate to handle close
    
    self = [super initWithWindow:window];
    if (self) {
        NSView *contentView = [window contentView];
        
        // Define Keys
        mappingKeys = [[NSMutableArray alloc] initWithObjects:
                       @"y (ㅛ)", @"u (ㅕ)", @"i (ㅑ)", 
                       @"a (ㅁ)", @"s (ㄴ)", @"d (ㅇ)", @"f (ㄹ)", @"g (ㅎ)",
                       @"h (ㅗ)", @"j (ㅓ)", @"k (ㅏ)", @"l (ㅣ)",
                       @"z (ㅋ)", @"x (ㅌ)", @"c (ㅊ)", @"v (ㅍ)", @"b (ㅠ)", @"n (ㅜ)", @"m (ㅡ)", nil];
        
        // Load Dictionary
        NSDictionary *saved = [[self defaults] dictionaryForKey:@"DKSTCustomShiftMappings"];
        if (saved) {
            mappingDict = [saved mutableCopy];
        } else {
            mappingDict = [[NSMutableDictionary alloc] init];
            for (NSString *key in mappingKeys) {
                [mappingDict setObject:@"" forKey:key];
            }
        }
        
        // 1. Caps Lock
        capsLockSwitchCheckbox = [[[NSButton alloc] initWithFrame:NSMakeRect(20, 370, 400, 24)] autorelease];
        [capsLockSwitchCheckbox setButtonType:NSButtonTypeSwitch];
        [capsLockSwitchCheckbox setTitle:@"Use Caps Lock to switch Input Mode"];
        [capsLockSwitchCheckbox setTarget:self];
        [capsLockSwitchCheckbox setAction:@selector(toggleCapsLockSwitch:)];
        [contentView addSubview:capsLockSwitchCheckbox];

        // 2. Menu bar icon
        NSTextField *iconLabel = [[[NSTextField alloc] initWithFrame:NSMakeRect(20, 338, 220, 24)] autorelease];
        [iconLabel setStringValue:@"Menu bar icon (Reboot required):"];
        [iconLabel setBezeled:NO]; [iconLabel setDrawsBackground:NO]; [iconLabel setEditable:NO]; [iconLabel setSelectable:NO];
        [contentView addSubview:iconLabel];
        
        iconPdfRadio = [[[NSButton alloc] initWithFrame:NSMakeRect(245, 340, 80, 24)] autorelease];
        [iconPdfRadio setButtonType:NSButtonTypeRadio];
        [iconPdfRadio setTitle:@"태극문양"];
        [iconPdfRadio setTarget:self]; [iconPdfRadio setAction:@selector(selectIconPdf:)];
        [contentView addSubview:iconPdfRadio];
        
        iconPngRadio = [[[NSButton alloc] initWithFrame:NSMakeRect(330, 340, 50, 24)] autorelease];
        [iconPngRadio setButtonType:NSButtonTypeRadio];
        [iconPngRadio setTitle:@"한글"];
        [iconPngRadio setTarget:self]; [iconPngRadio setAction:@selector(selectIconPng:)];
        [contentView addSubview:iconPngRadio];
        
        // 3. Moa-chigi
        moaJjikiCheckbox = [[[NSButton alloc] initWithFrame:NSMakeRect(20, 310, 400, 24)] autorelease];
        [moaJjikiCheckbox setButtonType:NSButtonTypeSwitch];
        [moaJjikiCheckbox setTitle:@"Enable Moa-chigi (Combine Vowel+Consonant)"];
        [moaJjikiCheckbox setTarget:self];
        [moaJjikiCheckbox setAction:@selector(toggleMoaJjiki:)];
        [contentView addSubview:moaJjikiCheckbox];
        
        // 4. Old Hangul
        oldHangulCheckbox = [[[NSButton alloc] initWithFrame:NSMakeRect(20, 280, 400, 24)] autorelease];
        [oldHangulCheckbox setButtonType:NSButtonTypeSwitch];
        [oldHangulCheckbox setTitle:@"Using old Korean script (실험적인 옛한글 사용)"];
        [oldHangulCheckbox setTarget:self];
        [oldHangulCheckbox setAction:@selector(toggleOldHangul:)];
        [contentView addSubview:oldHangulCheckbox];
        
        // 5. Backspace Behavior
        NSTextField *bsLabel = [[[NSTextField alloc] initWithFrame:NSMakeRect(20, 248, 80, 24)] autorelease];
        [bsLabel setStringValue:@"Delete by:"];
        [bsLabel setBezeled:NO]; [bsLabel setDrawsBackground:NO]; [bsLabel setEditable:NO]; [bsLabel setSelectable:NO];
        [contentView addSubview:bsLabel];
        
        backspaceJasoRadio = [[[NSButton alloc] initWithFrame:NSMakeRect(100, 250, 60, 24)] autorelease];
        [backspaceJasoRadio setButtonType:NSButtonTypeRadio];
        [backspaceJasoRadio setTitle:@"Jaso"];
        [backspaceJasoRadio setTarget:self]; [backspaceJasoRadio setAction:@selector(selectBackspaceJaso:)];
        [contentView addSubview:backspaceJasoRadio];
        
        backspaceGulpjaRadio = [[[NSButton alloc] initWithFrame:NSMakeRect(165, 250, 70, 24)] autorelease];
        [backspaceGulpjaRadio setButtonType:NSButtonTypeRadio];
        [backspaceGulpjaRadio setTitle:@"Gulja"];
        [backspaceGulpjaRadio setTarget:self]; [backspaceGulpjaRadio setAction:@selector(selectBackspaceGulpja:)];
        [contentView addSubview:backspaceGulpjaRadio];

        // 6. Custom Shift Enable
        customShiftCheckbox = [[[NSButton alloc] initWithFrame:NSMakeRect(20, 220, 400, 24)] autorelease];
        [customShiftCheckbox setButtonType:NSButtonTypeSwitch];
        [customShiftCheckbox setTitle:@"Enable Custom Shift Shortcuts (Emoji/Text)"];
        [customShiftCheckbox setTarget:self];
        [customShiftCheckbox setAction:@selector(toggleCustomShift:)];
        [contentView addSubview:customShiftCheckbox];

        // 7. Table Scroll View
        NSScrollView *scrollView = [[[NSScrollView alloc] initWithFrame:NSMakeRect(20, 40, 410, 170)] autorelease];
        [scrollView setBorderType:NSBezelBorder];
        [scrollView setHasVerticalScroller:YES];
        
        // Table View
        mappingsTableView = [[[NSTableView alloc] initWithFrame:NSMakeRect(0, 0, 410, 270)] autorelease];
        
        // Columns
        NSTableColumn *keyCol = [[[NSTableColumn alloc] initWithIdentifier:@"Key"] autorelease];
        [[keyCol headerCell] setStringValue:@"Key"];
        [keyCol setWidth:80];
        [keyCol setEditable:NO];
        [mappingsTableView addTableColumn:keyCol];
        
        NSTableColumn *outCol = [[[NSTableColumn alloc] initWithIdentifier:@"Output"] autorelease];
        [[outCol headerCell] setStringValue:@"Output (Text/Emoji)"];
        [outCol setWidth:300];
        [outCol setEditable:YES];
        [mappingsTableView addTableColumn:outCol];
        
        [mappingsTableView setDataSource:self];
        [mappingsTableView setDelegate:self];
        
        [scrollView setDocumentView:mappingsTableView];
        [contentView addSubview:scrollView];
        
        // 7. Copyright Label
        NSTextField *copyrightLabel = [[[NSTextField alloc] initWithFrame:NSMakeRect(20, 10, 410, 18)] autorelease];
        [copyrightLabel setStringValue:@"(C) 2025 DINKI'ssTyle"];
        [copyrightLabel setBezeled:NO];
        [copyrightLabel setDrawsBackground:NO];
        [copyrightLabel setEditable:NO];
        [copyrightLabel setSelectable:NO];
        [copyrightLabel setAlignment:NSTextAlignmentCenter];
        [copyrightLabel setTextColor:[NSColor secondaryLabelColor]];
        [copyrightLabel setFont:[NSFont systemFontOfSize:11]];
        [contentView addSubview:copyrightLabel];
        
        // Initial State
        [self refreshState];
    }
    return self;
}

- (void)dealloc {
    [mappingKeys release];
    [mappingDict release];
    [super dealloc];
}

// Window Delegate
- (void)windowWillClose:(NSNotification *)notification {
    // Terminate the app when window closes (since it's a standalone Prefs app now)
    [NSApp terminate:nil];
}

- (void)showPreferences {
    NSLog(@"PreferencesController: showPreferences called");
    NSWindow *window = [self window];
    [window center];
    [window makeKeyAndOrderFront:nil];
    [window setLevel:NSFloatingWindowLevel];
    [NSApp activateIgnoringOtherApps:YES];
    [self refreshState];
}

- (void)refreshState {
    NSUserDefaults *defaults = [self defaults];
    
    BOOL capsEnabled = [defaults boolForKey:@"EnableCapsLockSwitch"];
    [capsLockSwitchCheckbox setState:(capsEnabled ? NSControlStateValueOn : NSControlStateValueOff)];
    
    // Moa-chigi Default: YES
    if ([defaults objectForKey:@"EnableMoaJjiki"] == nil) {
        [moaJjikiCheckbox setState:NSControlStateValueOn];
    } else {
        BOOL moaEnabled = [defaults boolForKey:@"EnableMoaJjiki"];
        [moaJjikiCheckbox setState:(moaEnabled ? NSControlStateValueOn : NSControlStateValueOff)];
    }

    BOOL oldHangulEnabled = [defaults boolForKey:@"EnableOldHangul"];
    [oldHangulCheckbox setState:(oldHangulEnabled ? NSControlStateValueOn : NSControlStateValueOff)];
    
    BOOL shiftEnabled = [defaults boolForKey:@"EnableCustomShift"];
    [customShiftCheckbox setState:(shiftEnabled ? NSControlStateValueOn : NSControlStateValueOff)];
    [mappingsTableView setEnabled:shiftEnabled]; // Disable table if feature off
    
    BOOL useHangul2 = [defaults boolForKey:@"UseHangul2Icon"];
    [iconPdfRadio setState:(useHangul2 ? NSControlStateValueOff : NSControlStateValueOn)];
    [iconPngRadio setState:(useHangul2 ? NSControlStateValueOn : NSControlStateValueOff)];
    
    BOOL fullDelete = [defaults boolForKey:@"FullCharacterDelete"];
    [backspaceJasoRadio setState:(fullDelete ? NSControlStateValueOff : NSControlStateValueOn)];
    [backspaceGulpjaRadio setState:(fullDelete ? NSControlStateValueOn : NSControlStateValueOff)];
    
    [mappingsTableView reloadData];
}

// MARK: - Actions

- (IBAction)toggleCapsLockSwitch:(id)sender {
    BOOL enabled = ([sender state] == NSControlStateValueOn);
    [[self defaults] setBool:enabled forKey:@"EnableCapsLockSwitch"];
    [[self defaults] synchronize];
}

- (IBAction)toggleMoaJjiki:(id)sender {
    BOOL enabled = ([sender state] == NSControlStateValueOn);
    [[self defaults] setBool:enabled forKey:@"EnableMoaJjiki"];
    [[self defaults] synchronize];
}

- (IBAction)toggleOldHangul:(id)sender {
    BOOL enabled = ([sender state] == NSControlStateValueOn);
    [[self defaults] setBool:enabled forKey:@"EnableOldHangul"];
    [[self defaults] synchronize];
}

- (IBAction)toggleFullDelete:(id)sender {
    // Legacy action, no longer directly used by UI but kept for safety
}

- (IBAction)toggleCustomShift:(id)sender {
    BOOL enabled = ([sender state] == NSControlStateValueOn);
    [[self defaults] setBool:enabled forKey:@"EnableCustomShift"];
    [[self defaults] synchronize];
    [self refreshState];
}

- (void)updateInfoPListIcon:(NSString *)iconName {
    // 1. Locate the Input Method Bundle
    // Since we are likely in a helper app inside Resources or just need to find the main bundle
    NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
    // If we are in .app/Contents/Resources/DKSTPreferences.app, we need to go up
    // But for simplicity, let's try to assume standard structure or search relative
    
    // A robust way for an IME preference pane is finding the bundle by identifier if possible,
    // or traversing up.
    // Let's assume we are resolving to the bundle that contains Info.plist of the Input Method.
    // If this is running INSIDE the Input Method process (which is possible if it's not a separate process),
    // [NSBundle mainBundle] is the Input Method.
    // If it's a separate app, we need to find the Input Method bundle.
    
    // Attempt to find referencing the bundle by ID
    NSString *inputMethodBundleID = @"com.dinkisstyle.inputmethod.DKST";
    NSURL *url = [[NSWorkspace sharedWorkspace] URLForApplicationWithBundleIdentifier:inputMethodBundleID];
    NSString *path = [url path];
    
    if (!path) {
        // Fallback: assume we are inside the bundle (e.g. debugging or monolithic)
        path = [[NSBundle mainBundle] bundlePath];
        // If we are in Preferences.app, go up 3 levels?
        if ([path hasSuffix:@"DKSTPreferences.app"]) {
            path = [[[path stringByDeletingLastPathComponent] // Resources
                     stringByDeletingLastPathComponent] // Contents
                    stringByDeletingLastPathComponent]; // DKST.app
        }
    }
    
    NSString *infoPath = [path stringByAppendingPathComponent:@"Contents/Info.plist"];
    NSLog(@"DKST Preferences: Attempting to update Info.plist at: %@", infoPath);
    
    NSMutableDictionary *infoDict = [NSMutableDictionary dictionaryWithContentsOfFile:infoPath];
    
    if (infoDict) {
        NSMutableDictionary *componentInputModeDict = [infoDict objectForKey:@"ComponentInputModeDict"];
        if (componentInputModeDict) {
            NSMutableDictionary *tsInputModeListKey = [componentInputModeDict objectForKey:@"tsInputModeListKey"];
            if (tsInputModeListKey) {
                NSMutableDictionary *hangulDict = [tsInputModeListKey objectForKey:@"com.dinkisstyle.inputmethod.DKST.hangul"];
                if (hangulDict) {
                    [hangulDict setObject:iconName forKey:@"tsInputModeMenuIconFileKey"];
                    [hangulDict setObject:iconName forKey:@"tsInputModeAlternateMenuIconFileKey"];
                    [hangulDict setObject:iconName forKey:@"tsInputModePaletteIconFileKey"]; // Also update palette if present
                    
                    // Write back
                    BOOL success = [infoDict writeToFile:infoPath atomically:YES];
                    if (success) {
                         NSLog(@"DKST Preferences: Successfully wrote to Info.plist. New Icon: %@", iconName);
                         
                         // Touch the bundle to force cache refresh
                         NSFileManager *fm = [NSFileManager defaultManager];
                         NSDictionary *attrs = @{NSFileModificationDate: [NSDate date]};
                         NSError *error = nil;
                         if (![fm setAttributes:attrs ofItemAtPath:path error:&error]) {
                             NSLog(@"DKST Preferences: Failed to touch bundle at %@: %@", path, error);
                         } else {
                             NSLog(@"DKST Preferences: Touched bundle to refresh cache.");
                         }
                    } else {
                         NSLog(@"DKST Preferences: Failed to write to Info.plist via writeToFile.");
                    }
                    
                    // Since cached by system, suggest reboot (handled by UI label)
                }
            }
        }
    } else {
        NSLog(@"DKST Preferences: Could not find or load Info.plist at %@", infoPath);
    }
}

- (IBAction)selectIconPdf:(id)sender {
    [[self defaults] setBool:NO forKey:@"UseHangul2Icon"];
    [[self defaults] synchronize];
    [self updateInfoPListIcon:@"Hangul.pdf"];
    [self refreshState];
}

- (IBAction)selectIconPng:(id)sender {
    [[self defaults] setBool:YES forKey:@"UseHangul2Icon"];
    [[self defaults] synchronize];
    [self updateInfoPListIcon:@"Hangul_2.pdf"];
    [self refreshState];
}

- (IBAction)selectBackspaceJaso:(id)sender {
    [[self defaults] setBool:NO forKey:@"FullCharacterDelete"];
    [[self defaults] synchronize];
    [self refreshState];
}

- (IBAction)selectBackspaceGulpja:(id)sender {
    [[self defaults] setBool:YES forKey:@"FullCharacterDelete"];
    [[self defaults] synchronize];
    [self refreshState];
}

// MARK: - TableView DataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return [mappingKeys count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    NSString *key = [mappingKeys objectAtIndex:row];
    if ([[tableColumn identifier] isEqualToString:@"Key"]) {
        return key;
    } else {
        return [mappingDict objectForKey:key];
    }
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if ([[tableColumn identifier] isEqualToString:@"Output"]) {
        NSString *key = [mappingKeys objectAtIndex:row];
        NSString *newValue = (NSString *)object;
        [mappingDict setObject:newValue forKey:key];
        
        // Save
        [[self defaults] setObject:mappingDict forKey:@"DKSTCustomShiftMappings"];
        [[self defaults] synchronize];
    }
}

@end
