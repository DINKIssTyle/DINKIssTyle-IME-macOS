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

- (id)init {
    NSRect frame = NSMakeRect(0, 0, 350, 150);
    // Use NSPanel for utility window behavior
    NSPanel *panel = [[[NSPanel alloc] initWithContentRect:frame
                                                 styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskUtilityWindow)
                                                   backing:NSBackingStoreBuffered
                                                     defer:NO] autorelease];
    [panel setTitle:@"DKST Preferences"];
    [panel center];
    [panel setLevel:NSFloatingWindowLevel]; 
    [panel setFloatingPanel:YES];
    [panel setHidesOnDeactivate:NO]; // Keep visible if switching apps
    
    self = [super initWithWindow:panel];
    if (self) {
        NSView *contentView = [panel contentView];
        
        // Checkbox: Caps Lock
        capsLockSwitchCheckbox = [[[NSButton alloc] initWithFrame:NSMakeRect(40, 80, 280, 24)] autorelease];
        [capsLockSwitchCheckbox setButtonType:NSButtonTypeSwitch];
        [capsLockSwitchCheckbox setTitle:@"Use Caps Lock to switch Input Mode"];
        [capsLockSwitchCheckbox setTarget:self];
        [capsLockSwitchCheckbox setAction:@selector(toggleCapsLockSwitch:)];
        
        [contentView addSubview:capsLockSwitchCheckbox];

        // Checkbox: Moa-jjiki
        moaJjikiCheckbox = [[[NSButton alloc] initWithFrame:NSMakeRect(40, 50, 280, 24)] autorelease];
        [moaJjikiCheckbox setButtonType:NSButtonTypeSwitch];
        [moaJjikiCheckbox setTitle:@"Enable Moa-chigi (Combine Vowel+Consonant)"];
        [moaJjikiCheckbox setTarget:self];
        [moaJjikiCheckbox setAction:@selector(toggleMoaJjiki:)];
        
        [contentView addSubview:moaJjikiCheckbox];
        
        // Initial State
        [self refreshState];
    }
    return self;
}

- (void)showPreferences {
    NSLog(@"PreferencesController: showPreferences called");
    NSWindow *window = [self window];
    
    // Ensure visibility
    [window center];
    [window makeKeyAndOrderFront:nil];
    [window setLevel:NSFloatingWindowLevel]; // Re-assert level
    
    [NSApp activateIgnoringOtherApps:YES];
    
    [self refreshState];
}

- (void)refreshState {
    BOOL capsEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"EnableCapsLockSwitch"];
    [capsLockSwitchCheckbox setState:(capsEnabled ? NSControlStateValueOn : NSControlStateValueOff)];
    
    BOOL moaEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"EnableMoaJjiki"];
    [moaJjikiCheckbox setState:(moaEnabled ? NSControlStateValueOn : NSControlStateValueOff)];
    
    NSLog(@"PreferencesController: State refreshed. Caps: %d, Moa: %d", capsEnabled, moaEnabled);
}

- (IBAction)toggleCapsLockSwitch:(id)sender {
    BOOL enabled = ([sender state] == NSControlStateValueOn);
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:@"EnableCapsLockSwitch"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    NSLog(@"PreferencesController: CapsLock Toggle -> %d", enabled);
}

- (IBAction)toggleMoaJjiki:(id)sender {
    BOOL enabled = ([sender state] == NSControlStateValueOn);
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:@"EnableMoaJjiki"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    NSLog(@"PreferencesController: MoaJjiki Toggle -> %d", enabled);
}

@end
