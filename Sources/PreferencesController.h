#import "DKSTHangul.h"
#import <Cocoa/Cocoa.h>

@interface PreferencesController : NSWindowController <NSTableViewDataSource, NSTableViewDelegate, NSWindowDelegate> {
    IBOutlet NSButton *capsLockSwitchCheckbox;
    IBOutlet NSButton *moaJjikiCheckbox;
    IBOutlet NSButton *fullDeleteCheckbox;
    IBOutlet NSButton *useMarkedTextForAllAppsCheckbox;
    
    IBOutlet NSButton *hanjaConversionCheckbox;
    
    // New Feature
    IBOutlet NSButton *customShiftCheckbox;
    IBOutlet NSTableView *mappingsTableView;
    IBOutlet NSTableView *markedTextAppsTableView;
    IBOutlet NSButton *addMarkedTextAppButton;
    IBOutlet NSButton *removeMarkedTextAppButton;
    
    NSMutableArray *mappingKeys;
    NSMutableDictionary *mappingDict;
    NSMutableArray *markedTextAppBundleIDs;
    
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
- (IBAction)toggleHanjaConversion:(id)sender;
- (IBAction)toggleFullDelete:(id)sender;
- (IBAction)toggleUseMarkedTextForAllApps:(id)sender;
- (IBAction)addMarkedTextApp:(id)sender;
- (IBAction)removeMarkedTextApp:(id)sender;


@end
