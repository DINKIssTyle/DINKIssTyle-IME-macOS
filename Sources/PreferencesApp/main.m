#import "DKSTSettingsWindowController.h"
#import "DKSTConstants.h"
#import <Cocoa/Cocoa.h>

int main(int argc, const char *argv[]) {
  (void)argc;
  (void)argv;
  @autoreleasepool {
    NSError *dictionaryError = nil;
    if (!DKSTEnsureUserDictionary([NSBundle mainBundle], &dictionaryError)) {
      DKSTLog(@"Failed to prepare user Hanja dictionary: %@", dictionaryError);
    }

    NSApplication *app = [NSApplication sharedApplication];
    [app setActivationPolicy:NSApplicationActivationPolicyRegular];

    // Create standard menu
    NSMenu *menubar = [[[NSMenu alloc] init] autorelease];
    [app setMainMenu:menubar];

    // App Menu
    NSMenuItem *appMenuItem = [[[NSMenuItem alloc] init] autorelease];
    [menubar addItem:appMenuItem];
    NSMenu *appMenu = [[[NSMenu alloc] init] autorelease];
    [appMenuItem setSubmenu:appMenu];
    [appMenu addItemWithTitle:@"Quit DKST macOS용 한글입력기"
                       action:@selector(terminate:)
                keyEquivalent:@"q"];

    // Edit Menu
    NSMenuItem *editMenuItem = [[[NSMenuItem alloc] init] autorelease];
    [menubar addItem:editMenuItem];
    NSMenu *editMenu = [[[NSMenu alloc] initWithTitle:@"Edit"] autorelease];
    [editMenuItem setSubmenu:editMenu];

    [editMenu addItemWithTitle:@"Undo"
                        action:@selector(undo:)
                 keyEquivalent:@"z"];
    [editMenu addItemWithTitle:@"Redo"
                        action:@selector(redo:)
                 keyEquivalent:@"Z"];
    [editMenu addItem:[NSMenuItem separatorItem]];
    [editMenu addItemWithTitle:@"Cut"
                        action:@selector(cut:)
                 keyEquivalent:@"x"];
    [editMenu addItemWithTitle:@"Copy"
                        action:@selector(copy:)
                 keyEquivalent:@"c"];
    [editMenu addItemWithTitle:@"Paste"
                        action:@selector(paste:)
                 keyEquivalent:@"v"];
    [editMenu addItemWithTitle:@"Select All"
                        action:@selector(selectAll:)
                 keyEquivalent:@"a"];

    // Launch Controller
    DKSTSettingsWindowController *controller =
        [DKSTSettingsWindowController sharedController];
    
    // Set delegate to handle app termination
    app.delegate = controller;
    
    [controller showWindow:nil]; // Show the window!

    // Ensure app stays running
    [app run];
  }
  return 0;
}
