#import <Cocoa/Cocoa.h>

@interface PreferencesController : NSWindowController {
    IBOutlet NSButton *capsLockSwitchCheckbox;
}

+ (PreferencesController *)sharedController;
- (void)showPreferences;
- (IBAction)toggleCapsLockSwitch:(id)sender;

@end
