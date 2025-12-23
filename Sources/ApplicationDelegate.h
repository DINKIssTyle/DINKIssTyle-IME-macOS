/*
 * ApplicationDelegate.h
 * DKST Input Method
 *
 * Created: 2024-12-24
 *
 * Purpose:
 * This class exists to satisfy the MainMenu.xib's reference to
 * "ApplicationDelegate". The XIB was originally created with an
 * ApplicationDelegate class that had an _menu outlet, but the class was never
 * implemented in the codebase, causing runtime warnings:
 *   - "Unknown class 'ApplicationDelegate', using 'NSObject' instead"
 *   - "Failed to connect (_menu) outlet from (NSObject) to (NSMenu)"
 *
 * This minimal implementation provides the required _menu outlet to silence
 * these warnings. The actual input method functionality is handled by
 * InputController, not this delegate.
 */

#import <Cocoa/Cocoa.h>

@interface ApplicationDelegate : NSObject <NSApplicationDelegate> {
  // Instance variable required by MainMenu.xib outlet connection
  // The XIB connects to "_menu" directly (underscore prefix in XIB)
  IBOutlet NSMenu *_menu;
}

@end
