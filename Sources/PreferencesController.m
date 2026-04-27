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
    NSRect frame = NSMakeRect(0, 0, 520, 650);
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

        NSArray *savedMarkedTextApps = [[self defaults] arrayForKey:kDKSTMarkedTextAppBundleIDsKey];
        if ([savedMarkedTextApps count] > 0) {
            markedTextAppBundleIDs = [savedMarkedTextApps mutableCopy];
            for (NSString *bundleID in DKSTDefaultMarkedTextAppBundleIDs()) {
                if (![markedTextAppBundleIDs containsObject:bundleID]) {
                    [markedTextAppBundleIDs addObject:bundleID];
                }
            }
            [[self defaults] setObject:markedTextAppBundleIDs forKey:kDKSTMarkedTextAppBundleIDsKey];
            [[self defaults] synchronize];
        } else {
            markedTextAppBundleIDs = [[NSMutableArray alloc] initWithArray:DKSTDefaultMarkedTextAppBundleIDs()];
            [[self defaults] setObject:markedTextAppBundleIDs forKey:kDKSTMarkedTextAppBundleIDsKey];
            [[self defaults] synchronize];
        }
        
        // 2. Moa-jjiki
        moaJjikiCheckbox = [[[NSButton alloc] initWithFrame:NSMakeRect(20, 610, 460, 24)] autorelease];
        [moaJjikiCheckbox setButtonType:NSButtonTypeSwitch];
        [moaJjikiCheckbox setTitle:@"모아치기 (자모 순서 자동 보정)"];
        [moaJjikiCheckbox setTarget:self];
        [moaJjikiCheckbox setAction:@selector(toggleMoaJjiki:)];
        [contentView addSubview:moaJjikiCheckbox];
        
        // 2.5. Hanja Conversion
        hanjaConversionCheckbox = [[[NSButton alloc] initWithFrame:NSMakeRect(20, 580, 460, 24)] autorelease];
        [hanjaConversionCheckbox setButtonType:NSButtonTypeSwitch];
        [hanjaConversionCheckbox setTitle:@"사전 변환 사용 (Option + Enter)"];
        [hanjaConversionCheckbox setTarget:self];
        [hanjaConversionCheckbox setAction:@selector(toggleHanjaConversion:)];
        [contentView addSubview:hanjaConversionCheckbox];

        appleHanjaDictionaryCheckbox = [[[NSButton alloc] initWithFrame:NSMakeRect(20, 550, 460, 24)] autorelease];
        [appleHanjaDictionaryCheckbox setButtonType:NSButtonTypeSwitch];
        [appleHanjaDictionaryCheckbox setTitle:@"Apple 시스템 한자 사전도 후보에 사용"];
        [appleHanjaDictionaryCheckbox setTarget:self];
        [appleHanjaDictionaryCheckbox setAction:@selector(toggleAppleHanjaDictionary:)];
        [contentView addSubview:appleHanjaDictionaryCheckbox];
        
        useMarkedTextForAllAppsCheckbox = [[[NSButton alloc] initWithFrame:NSMakeRect(20, 490, 460, 24)] autorelease];
        [useMarkedTextForAllAppsCheckbox setButtonType:NSButtonTypeSwitch];
        [useMarkedTextForAllAppsCheckbox setTitle:@"모든 앱에서 밑줄 조합 방식 사용"];
        [useMarkedTextForAllAppsCheckbox setTarget:self];
        [useMarkedTextForAllAppsCheckbox setAction:@selector(toggleUseMarkedTextForAllApps:)];
        [contentView addSubview:useMarkedTextForAllAppsCheckbox];

        // 3. Custom Shift Enable (Moved Down)
        customShiftCheckbox = [[[NSButton alloc] initWithFrame:NSMakeRect(20, 460, 460, 24)] autorelease];
        [customShiftCheckbox setButtonType:NSButtonTypeSwitch];
        [customShiftCheckbox setTitle:@"쉬프트키 + 단자음/단모음 사용자화 사용"];
        [customShiftCheckbox setTarget:self];
        [customShiftCheckbox setAction:@selector(toggleCustomShift:)];
        [contentView addSubview:customShiftCheckbox];
        
        // 5. Full Character Delete
        fullDeleteCheckbox = [[[NSButton alloc] initWithFrame:NSMakeRect(20, 520, 460, 24)] autorelease];
        [fullDeleteCheckbox setButtonType:NSButtonTypeSwitch];
        [fullDeleteCheckbox setTitle:@"글자 단위로 삭제"];
        [fullDeleteCheckbox setTarget:self];
        [fullDeleteCheckbox setAction:@selector(toggleFullDelete:)];
        [contentView addSubview:fullDeleteCheckbox];

        // 4. Table Scroll View
        NSScrollView *scrollView = [[[NSScrollView alloc] initWithFrame:NSMakeRect(20, 260, 480, 190)] autorelease];
        [scrollView setBorderType:NSBezelBorder];
        [scrollView setHasVerticalScroller:YES];
        
        // Table View
        mappingsTableView = [[[NSTableView alloc] initWithFrame:NSMakeRect(0, 0, 480, 270)] autorelease];
        
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

        NSTextField *markedLabel = [[[NSTextField alloc] initWithFrame:NSMakeRect(20, 225, 480, 20)] autorelease];
        [markedLabel setStringValue:@"밑줄 조합 방식으로 사용할 앱 Bundle ID"];
        [markedLabel setBezeled:NO];
        [markedLabel setDrawsBackground:NO];
        [markedLabel setEditable:NO];
        [markedLabel setSelectable:NO];
        [markedLabel setFont:[NSFont boldSystemFontOfSize:12]];
        [contentView addSubview:markedLabel];

        NSScrollView *markedScrollView = [[[NSScrollView alloc] initWithFrame:NSMakeRect(20, 70, 480, 145)] autorelease];
        [markedScrollView setBorderType:NSBezelBorder];
        [markedScrollView setHasVerticalScroller:YES];

        markedTextAppsTableView = [[[NSTableView alloc] initWithFrame:NSMakeRect(0, 0, 480, 145)] autorelease];
        NSTableColumn *bundleCol = [[[NSTableColumn alloc] initWithIdentifier:@"BundleID"] autorelease];
        [[bundleCol headerCell] setStringValue:@"Bundle ID"];
        [bundleCol setWidth:460];
        [bundleCol setEditable:YES];
        [markedTextAppsTableView addTableColumn:bundleCol];
        [markedTextAppsTableView setDataSource:self];
        [markedTextAppsTableView setDelegate:self];

        [markedScrollView setDocumentView:markedTextAppsTableView];
        [contentView addSubview:markedScrollView];

        addMarkedTextAppButton = [[[NSButton alloc] initWithFrame:NSMakeRect(20, 35, 80, 24)] autorelease];
        [addMarkedTextAppButton setTitle:@"추가"];
        [addMarkedTextAppButton setTarget:self];
        [addMarkedTextAppButton setAction:@selector(addMarkedTextApp:)];
        [contentView addSubview:addMarkedTextAppButton];

        removeMarkedTextAppButton = [[[NSButton alloc] initWithFrame:NSMakeRect(108, 35, 80, 24)] autorelease];
        [removeMarkedTextAppButton setTitle:@"삭제"];
        [removeMarkedTextAppButton setTarget:self];
        [removeMarkedTextAppButton setAction:@selector(removeMarkedTextApp:)];
        [contentView addSubview:removeMarkedTextAppButton];
        
        // 6. Copyright Link
        NSTextView *copyrightView = [[[NSTextView alloc] initWithFrame:NSMakeRect(20, 2, 480, 18)] autorelease];
        [copyrightView setEditable:NO];
        [copyrightView setSelectable:YES];
        [copyrightView setDrawsBackground:NO];
        [copyrightView setTextContainerInset:NSMakeSize(0, 0)];
        [[copyrightView textContainer] setLineFragmentPadding:0];

        NSString *copyrightText = @"Copyright © 2026 DINKI'ssTyle. | macOS용 DKST 한글입력기 Github.";
        NSString *linkText = @"macOS용 DKST 한글입력기 Github.";
        NSMutableParagraphStyle *copyrightParagraphStyle = [[[NSMutableParagraphStyle alloc] init] autorelease];
        [copyrightParagraphStyle setAlignment:NSTextAlignmentCenter];

        NSMutableAttributedString *copyrightString =
            [[[NSMutableAttributedString alloc] initWithString:copyrightText
                                                    attributes:@{
                                                        NSFontAttributeName: [NSFont systemFontOfSize:11],
                                                        NSForegroundColorAttributeName: [NSColor secondaryLabelColor],
                                                        NSParagraphStyleAttributeName: copyrightParagraphStyle
                                                    }] autorelease];

        NSRange linkRange = [copyrightText rangeOfString:linkText];
        if (linkRange.location != NSNotFound) {
            [copyrightString addAttributes:@{
                NSLinkAttributeName: [NSURL URLWithString:@"https://github.com/DINKIssTyle/DINKIssTyle-IME-macOS"],
                NSForegroundColorAttributeName: [NSColor linkColor],
                NSUnderlineStyleAttributeName: @(NSUnderlineStyleSingle)
            } range:linkRange];
        }

        [[copyrightView textStorage] setAttributedString:copyrightString];
        [contentView addSubview:copyrightView];
        
        // Initial State
        [self refreshState];
    }
    return self;
}

- (void)dealloc {
    [mappingKeys release];
    [mappingDict release];
    [markedTextAppBundleIDs release];
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

    // Apple Hanja Dictionary Default: YES
    if ([defaults objectForKey:kDKSTUseAppleHanjaDictionaryKey] == nil) {
        [appleHanjaDictionaryCheckbox setState:NSControlStateValueOn];
    } else {
        BOOL useAppleHanjaDictionary = [defaults boolForKey:kDKSTUseAppleHanjaDictionaryKey];
        [appleHanjaDictionaryCheckbox setState:(useAppleHanjaDictionary ? NSControlStateValueOn : NSControlStateValueOff)];
    }
    
    BOOL fullDelete = [defaults boolForKey:@"FullCharacterDelete"];
    [fullDeleteCheckbox setState:(fullDelete ? NSControlStateValueOn : NSControlStateValueOff)];

    BOOL useMarkedTextForAllApps = [defaults boolForKey:kDKSTUseMarkedTextForAllAppsKey];
    [useMarkedTextForAllAppsCheckbox setState:(useMarkedTextForAllApps ? NSControlStateValueOn : NSControlStateValueOff)];
    
    BOOL shiftEnabled = [defaults boolForKey:@"EnableCustomShift"];
    [customShiftCheckbox setState:(shiftEnabled ? NSControlStateValueOn : NSControlStateValueOff)];
    [mappingsTableView setEnabled:shiftEnabled]; // Disable table if feature off
    
    [mappingsTableView reloadData];
    [markedTextAppsTableView reloadData];
}

// MARK: - Actions

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

- (IBAction)toggleAppleHanjaDictionary:(id)sender {
    BOOL enabled = ([sender state] == NSControlStateValueOn);
    [[self defaults] setBool:enabled forKey:kDKSTUseAppleHanjaDictionaryKey];
    [[self defaults] synchronize];
}

- (IBAction)toggleFullDelete:(id)sender {
    BOOL enabled = ([sender state] == NSControlStateValueOn);
    [[self defaults] setBool:enabled forKey:@"FullCharacterDelete"];
    [[self defaults] synchronize];
}

- (IBAction)toggleUseMarkedTextForAllApps:(id)sender {
    BOOL enabled = ([sender state] == NSControlStateValueOn);
    [[self defaults] setBool:enabled forKey:kDKSTUseMarkedTextForAllAppsKey];
    [[self defaults] synchronize];
}

- (IBAction)toggleCustomShift:(id)sender {
    BOOL enabled = ([sender state] == NSControlStateValueOn);
    [[self defaults] setBool:enabled forKey:@"EnableCustomShift"];
    [[self defaults] synchronize];
    [self refreshState];
}

- (void)saveMarkedTextAppBundleIDs {
    NSMutableArray *cleaned = [NSMutableArray array];
    for (NSString *bundleID in markedTextAppBundleIDs) {
        NSString *trimmed = [bundleID stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([trimmed length] > 0 && ![cleaned containsObject:trimmed]) {
            [cleaned addObject:trimmed];
        }
    }

    [markedTextAppBundleIDs setArray:cleaned];
    [[self defaults] setObject:markedTextAppBundleIDs forKey:kDKSTMarkedTextAppBundleIDsKey];
    [[self defaults] synchronize];
    [markedTextAppsTableView reloadData];
}

- (IBAction)addMarkedTextApp:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    [panel setCanChooseFiles:YES];
    [panel setCanChooseDirectories:NO];
    [panel setAllowsMultipleSelection:YES];
    [panel setAllowedFileTypes:[NSArray arrayWithObject:@"app"]];
    [panel setPrompt:@"선택"];
    [panel setMessage:@".app 번들을 선택하세요."];

    NSInteger result = [panel runModal];
    if (result != NSModalResponseOK) {
        return;
    }

    BOOL added = NO;
    for (NSURL *url in [panel URLs]) {
        NSBundle *bundle = [NSBundle bundleWithURL:url];
        NSString *bundleID = [bundle bundleIdentifier];
        if ([bundleID length] > 0 && ![markedTextAppBundleIDs containsObject:bundleID]) {
            [markedTextAppBundleIDs addObject:bundleID];
            added = YES;
        }
    }

    if (added) {
        [self saveMarkedTextAppBundleIDs];
        NSInteger row = [markedTextAppBundleIDs count] - 1;
        [markedTextAppsTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
    }
}

- (IBAction)removeMarkedTextApp:(id)sender {
    NSInteger row = [markedTextAppsTableView selectedRow];
    if (row >= 0 && row < [markedTextAppBundleIDs count]) {
        [markedTextAppBundleIDs removeObjectAtIndex:row];
        [self saveMarkedTextAppBundleIDs];
    }
}

// MARK: - TableView DataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    if (tableView == markedTextAppsTableView) {
        return [markedTextAppBundleIDs count];
    }
    return [mappingKeys count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (tableView == markedTextAppsTableView) {
        return [markedTextAppBundleIDs objectAtIndex:row];
    }

    NSString *key = [mappingKeys objectAtIndex:row];
    if ([[tableColumn identifier] isEqualToString:@"Key"]) {
        return key;
    } else {
        return [mappingDict objectForKey:key];
    }
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (tableView == markedTextAppsTableView) {
        NSString *newValue = [(NSString *)object stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([newValue length] > 0 && row >= 0 && row < [markedTextAppBundleIDs count]) {
            [markedTextAppBundleIDs replaceObjectAtIndex:row withObject:newValue];
            [self saveMarkedTextAppBundleIDs];
        }
        return;
    }

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
