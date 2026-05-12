#import <Cocoa/Cocoa.h>

@interface DKSTSettingsWindowController : NSWindowController <NSToolbarDelegate, NSApplicationDelegate>

@property (strong) NSTabViewController *tabViewController;

+ (DKSTSettingsWindowController *)sharedController;
- (void)showWindow:(id)sender;

@end
