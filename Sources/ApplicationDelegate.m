/*
 * ApplicationDelegate.m
 * DKST Input Method
 *
 * Created: 2024-12-24
 *
 * Purpose:
 * Minimal implementation of ApplicationDelegate to satisfy MainMenu.xib
 * references. See ApplicationDelegate.h for detailed explanation.
 *
 * Note:
 * This class intentionally does minimal work. The input method's core
 * functionality is handled by InputController (IMKInputController subclass),
 * not by this delegate. This class exists primarily to:
 *   1. Silence XIB loading warnings about missing class
 *   2. Properly connect the _menu outlet defined in the XIB
 */

#import "ApplicationDelegate.h"

@implementation ApplicationDelegate

// _menu instance variable is connected automatically by XIB at runtime

- (void)awakeFromNib {
  if (_menu) {
    // Find "Preferences..." item tag=1 to insert above it
    NSInteger prefsIndex = [_menu indexOfItemWithTag:1];

    NSMenuItem *dictEditorItem =
        [[NSMenuItem alloc] initWithTitle:@"Dictionary Editor..."
                                   action:@selector(launchDictEditor:)
                            keyEquivalent:@""];
    [dictEditorItem setTarget:self];

    if (prefsIndex >= 0) {
      [_menu insertItem:dictEditorItem atIndex:prefsIndex];
    } else {
      // Fallback: append if prefs not found
      [_menu addItem:dictEditorItem];
    }
  }
}

- (void)launchDictEditor:(id)sender {
  NSString *appPath = [[NSBundle mainBundle] pathForResource:@"DKSTDictEditor"
                                                      ofType:@"app"];
  if (appPath) {
    NSURL *appUrl = [NSURL fileURLWithPath:appPath];
    NSWorkspaceOpenConfiguration *config =
        [NSWorkspaceOpenConfiguration configuration];
    [[NSWorkspace sharedWorkspace]
        openApplicationAtURL:appUrl
               configuration:config
           completionHandler:^(NSRunningApplication *_Nullable app,
                               NSError *_Nullable error) {
             if (error) {
               NSLog(@"DKST: Failed to launch DictEditor: %@", error);
             }
           }];
  } else {
    NSLog(@"DKST: DKSTDictEditor.app not found in bundle resources.");
  }
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
  // Intentionally empty - Input Method initialization is handled by IMKServer
  // which is set up in main.m, not here.
}

@end
