#import <Cocoa/Cocoa.h>
#import "PreferencesController.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];
        
        // Launch Controller
        PreferencesController *controller = [PreferencesController sharedController];
        [controller showPreferences]; // Show the window!
        
        // Ensure app stays running
        [app run];
    }
    return 0;
}
