#import <Cocoa/Cocoa.h>

@interface PreferencesController : NSWindowController {
    IBOutlet NSButton *capsLockSwitchCheckbox;
    IBOutlet NSButton *moaJjikiCheckbox;
}

+ (PreferencesController *)sharedController;
- (void)showPreferences;
- (IBAction)toggleCapsLockSwitch:(id)sender;
- (IBAction)toggleMoaJjiki:(id)sender;


@end
