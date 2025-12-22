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

        
        // 3. Moa-chigi
        moaJjikiCheckbox = [[[NSButton alloc] initWithFrame:NSMakeRect(20, 340, 400, 24)] autorelease];
        [moaJjikiCheckbox setButtonType:NSButtonTypeSwitch];
        [moaJjikiCheckbox setTitle:@"Enable Moa-chigi (Combine Vowel+Consonant)"];
        [moaJjikiCheckbox setTarget:self];
        [moaJjikiCheckbox setAction:@selector(toggleMoaJjiki:)];
        [contentView addSubview:moaJjikiCheckbox];
        
        // 4. Old Hangul
        oldHangulCheckbox = [[[NSButton alloc] initWithFrame:NSMakeRect(20, 310, 400, 24)] autorelease];
        [oldHangulCheckbox setButtonType:NSButtonTypeSwitch];
        [oldHangulCheckbox setTitle:@"Using old Korean script (옛한글 사용)"];
        [oldHangulCheckbox setTarget:self];
        [oldHangulCheckbox setAction:@selector(toggleOldHangul:)];
        [contentView addSubview:oldHangulCheckbox];
        
        // 5. Backspace Behavior
        NSTextField *bsLabel = [[[NSTextField alloc] initWithFrame:NSMakeRect(20, 278, 80, 24)] autorelease];
        [bsLabel setStringValue:@"Delete by:"];
        [bsLabel setBezeled:NO]; [bsLabel setDrawsBackground:NO]; [bsLabel setEditable:NO]; [bsLabel setSelectable:NO];
        [contentView addSubview:bsLabel];
        
        backspaceJasoRadio = [[[NSButton alloc] initWithFrame:NSMakeRect(100, 280, 60, 24)] autorelease];
        [backspaceJasoRadio setButtonType:NSButtonTypeRadio];
        [backspaceJasoRadio setTitle:@"Jaso"];
        [backspaceJasoRadio setTarget:self]; [backspaceJasoRadio setAction:@selector(selectBackspaceJaso:)];
        [contentView addSubview:backspaceJasoRadio];
        
        backspaceGulpjaRadio = [[[NSButton alloc] initWithFrame:NSMakeRect(165, 280, 70, 24)] autorelease];
        [backspaceGulpjaRadio setButtonType:NSButtonTypeRadio];
        [backspaceGulpjaRadio setTitle:@"Gulja"];
        [backspaceGulpjaRadio setTarget:self]; [backspaceGulpjaRadio setAction:@selector(selectBackspaceGulpja:)];
        [contentView addSubview:backspaceGulpjaRadio];

        // 6. Custom Shift Enable
        customShiftCheckbox = [[[NSButton alloc] initWithFrame:NSMakeRect(20, 250, 400, 24)] autorelease];
        [customShiftCheckbox setButtonType:NSButtonTypeSwitch];
        [customShiftCheckbox setTitle:@"Enable Custom Shift Shortcuts (Emoji/Text)"];
        [customShiftCheckbox setTarget:self];
        [customShiftCheckbox setAction:@selector(toggleCustomShift:)];
        [contentView addSubview:customShiftCheckbox];

        // 7. Table Scroll View
        NSScrollView *scrollView = [[[NSScrollView alloc] initWithFrame:NSMakeRect(20, 40, 410, 200)] autorelease];
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
