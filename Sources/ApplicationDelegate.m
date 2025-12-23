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

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
  // Intentionally empty - Input Method initialization is handled by IMKServer
  // which is set up in main.m, not here.
}

@end
