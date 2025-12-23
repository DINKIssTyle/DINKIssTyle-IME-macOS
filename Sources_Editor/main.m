/*
 * main.m
 * DKSTDictEditor
 *
 * Entry point for the Hanja Dictionary Editor application.
 */

#import "DictEditorController.h"
#import <Cocoa/Cocoa.h>

int main(int argc, const char *argv[]) {
  @autoreleasepool {
    // Create the application instance
    NSApplication *app = [NSApplication sharedApplication];

    // Create the delegate (which will create the window)
    DictEditorController *controller = [[DictEditorController alloc] init];
    [app setDelegate:controller];

    // simple main menu
    NSMenu *menubar = [[NSMenu alloc] init];
    NSMenuItem *appMenuItem = [[NSMenuItem alloc] init];
    [menubar addItem:appMenuItem];
    [app setMainMenu:menubar];

    NSMenu *appMenu = [[NSMenu alloc] init];
    NSString *appName = [[NSProcessInfo processInfo] processName];
    NSString *quitTitle = [@"Quit " stringByAppendingString:appName];
    NSMenuItem *quitMenuItem =
        [[NSMenuItem alloc] initWithTitle:quitTitle
                                   action:@selector(terminate:)
                            keyEquivalent:@"q"];
    [appMenu addItem:quitMenuItem];
    [appMenuItem setSubmenu:appMenu];

    /* Edit menu (for copy/paste support) */
    NSMenuItem *editMenuItem = [[NSMenuItem alloc] init];
    [editMenuItem setTitle:@"Edit"];
    [menubar addItem:editMenuItem];

    NSMenu *editMenu = [[NSMenu alloc] initWithTitle:@"Edit"];
    [editMenuItem setSubmenu:editMenu];

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

    // Run the app logic
    [app run];
  }
  return 0;
}
