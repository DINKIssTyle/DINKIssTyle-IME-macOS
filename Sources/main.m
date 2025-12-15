#import <Cocoa/Cocoa.h>
#import <InputMethodKit/InputMethodKit.h>

// connection name
NSString *const kConnectionName = @"DKST_1_Connection"; // Match Info.plist

IMKServer *server;

int main(int argc, char *argv[])
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

  NSString* identifier = [[NSBundle mainBundle] bundleIdentifier];
  
  // Initialize standard IMKServer
  server = [[IMKServer alloc] initWithName:kConnectionName
                          bundleIdentifier:identifier];

  // load nib
  [[NSBundle mainBundle] loadNibNamed:@"MainMenu" owner:[NSApplication sharedApplication] topLevelObjects:nil];

  // run
  [[NSApplication sharedApplication] run];

  [server release];
  [pool release];
  return 0;    
}
