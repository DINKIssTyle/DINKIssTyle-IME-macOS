#import "DKSTHangul.h"
#import <Cocoa/Cocoa.h>

@interface PreferencesController : NSWindowController <NSTableViewDataSource, NSTableViewDelegate, NSWindowDelegate> {
    IBOutlet NSButton *capsLockSwitchCheckbox;
    IBOutlet NSButton *moaJjikiCheckbox;
    
    // New Feature
    IBOutlet NSButton *customShiftCheckbox;
    IBOutlet NSTableView *mappingsTableView;
    
    NSMutableArray *mappingKeys;
    NSMutableDictionary *mappingDict;
    
    // Internal Hangul support for Prefs
    DKSTHangul *uiEngine;
    id uiEventMonitor;
    
    // Shortcut Recording (Restored)
    IBOutlet NSButton *shortcutButton;
    BOOL isRecordingShortcut;
    NSInteger savedKeyCode;
    NSUInteger savedModifiers;
    id eventMonitor;
}

+ (PreferencesController *)sharedController;
- (void)showPreferences;
- (IBAction)toggleCapsLockSwitch:(id)sender;
- (IBAction)toggleMoaJjiki:(id)sender;


@end
