#import "PreferencesController.h"
#import "DKSTConstants.h"

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
    NSRect frame = NSMakeRect(0, 0, 450, 430); 
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
        capsLockSwitchCheckbox = [[[NSButton alloc] initWithFrame:NSMakeRect(20, 390, 400, 24)] autorelease];
        [capsLockSwitchCheckbox setButtonType:NSButtonTypeSwitch];
        [capsLockSwitchCheckbox setTitle:@"Caps Lock을 눌러 입력 언어 전환"];
        [capsLockSwitchCheckbox setTarget:self];
        [capsLockSwitchCheckbox setAction:@selector(toggleCapsLockSwitch:)];
        [contentView addSubview:capsLockSwitchCheckbox];

        // 2. Moa-jjiki
        moaJjikiCheckbox = [[[NSButton alloc] initWithFrame:NSMakeRect(20, 360, 400, 24)] autorelease];
        [moaJjikiCheckbox setButtonType:NSButtonTypeSwitch];
        [moaJjikiCheckbox setTitle:@"모아치기 (자모 순서 자동 보정)"];
        [moaJjikiCheckbox setTarget:self];
        [moaJjikiCheckbox setAction:@selector(toggleMoaJjiki:)];
        [contentView addSubview:moaJjikiCheckbox];
        
        // 2.5. Hanja Conversion
        hanjaConversionCheckbox = [[[NSButton alloc] initWithFrame:NSMakeRect(20, 330, 400, 24)] autorelease];
        [hanjaConversionCheckbox setButtonType:NSButtonTypeSwitch];
        [hanjaConversionCheckbox setTitle:@"사전 변환 사용 (Option + Enter)"];
        [hanjaConversionCheckbox setTarget:self];
        [hanjaConversionCheckbox setAction:@selector(toggleHanjaConversion:)];
        [contentView addSubview:hanjaConversionCheckbox];
        
        // 3. Custom Shift Enable (Moved Down)
        customShiftCheckbox = [[[NSButton alloc] initWithFrame:NSMakeRect(20, 270, 400, 24)] autorelease];
        [customShiftCheckbox setButtonType:NSButtonTypeSwitch];
        [customShiftCheckbox setTitle:@"쉬프트키 + 단자음/단모음 사용자화 사용"];
        [customShiftCheckbox setTarget:self];
        [customShiftCheckbox setAction:@selector(toggleCustomShift:)];
        [contentView addSubview:customShiftCheckbox];
        
        // 5. Full Character Delete (Moved Up)
        fullDeleteCheckbox = [[[NSButton alloc] initWithFrame:NSMakeRect(20, 300, 400, 24)] autorelease];
        [fullDeleteCheckbox setButtonType:NSButtonTypeSwitch];
        [fullDeleteCheckbox setTitle:@"글자 단위로 삭제"];
        [fullDeleteCheckbox setTarget:self];
        [fullDeleteCheckbox setAction:@selector(toggleFullDelete:)];
        [contentView addSubview:fullDeleteCheckbox];

        // 4. Table Scroll View
        NSScrollView *scrollView = [[[NSScrollView alloc] initWithFrame:NSMakeRect(20, 40, 410, 220)] autorelease];
        [scrollView setBorderType:NSBezelBorder];
        [scrollView setHasVerticalScroller:YES];
        
        // Table View
        mappingsTableView = [[[NSTableView alloc] initWithFrame:NSMakeRect(0, 0, 410, 270)] autorelease];
        
        // Columns
        NSTableColumn *keyCol = [[[NSTableColumn alloc] initWithIdentifier:@"Key"] autorelease];
        [[keyCol headerCell] setStringValue:@"키"];
        [keyCol setWidth:80];
        [keyCol setEditable:NO];
        [mappingsTableView addTableColumn:keyCol];
        
        NSTableColumn *outCol = [[[NSTableColumn alloc] initWithIdentifier:@"Output"] autorelease];
        [[outCol headerCell] setStringValue:@"출력 내용 (Text/Emoji)"];
        [outCol setWidth:300];
        [outCol setEditable:YES];
        [mappingsTableView addTableColumn:outCol];
        
        [mappingsTableView setDataSource:self];
        [mappingsTableView setDelegate:self];
        
        [scrollView setDocumentView:mappingsTableView];
        [contentView addSubview:scrollView];
        
        // 6. Copyright Label
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
    DKSTLog(@"PreferencesController: showPreferences called");
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
        [moaJjikiCheckbox setState:(moaEnabled ? NSControlStateValueOn : NSControlStateValueOff)];
    }
    
    // Hanja Conversion Default: YES
    if ([defaults objectForKey:@"EnableHanja"] == nil) {
        [hanjaConversionCheckbox setState:NSControlStateValueOn];
    } else {
        BOOL hanjaEnabled = [defaults boolForKey:@"EnableHanja"];
        [hanjaConversionCheckbox setState:(hanjaEnabled ? NSControlStateValueOn : NSControlStateValueOff)];
    }
    
    BOOL fullDelete = [defaults boolForKey:@"FullCharacterDelete"];
    [fullDeleteCheckbox setState:(fullDelete ? NSControlStateValueOn : NSControlStateValueOff)];
    
    BOOL shiftEnabled = [defaults boolForKey:@"EnableCustomShift"];
    [customShiftCheckbox setState:(shiftEnabled ? NSControlStateValueOn : NSControlStateValueOff)];
    [mappingsTableView setEnabled:shiftEnabled]; // Disable table if feature off
    
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

- (IBAction)toggleHanjaConversion:(id)sender {
    BOOL enabled = ([sender state] == NSControlStateValueOn);
    [[self defaults] setBool:enabled forKey:@"EnableHanja"];
    [[self defaults] synchronize];
}

- (IBAction)toggleFullDelete:(id)sender {
    BOOL enabled = ([sender state] == NSControlStateValueOn);
    [[self defaults] setBool:enabled forKey:@"FullCharacterDelete"];
    [[self defaults] synchronize];
}

- (IBAction)toggleCustomShift:(id)sender {
    BOOL enabled = ([sender state] == NSControlStateValueOn);
    [[self defaults] setBool:enabled forKey:@"EnableCustomShift"];
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
