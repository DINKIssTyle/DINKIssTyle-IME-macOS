#import <Cocoa/Cocoa.h>
#import "DKSTShortcutRecorder.h"

// Tab 1: General
@interface DKSTGeneralViewController : NSViewController <DKSTShortcutRecorderDelegate>
@end

// Tab 2: Mappings (Single Consonants)
@interface DKSTMappingViewController : NSViewController <NSTableViewDataSource, NSTableViewDelegate>
@end

// Tab 3: Dictionary Editor
@interface DKSTDictionaryViewController : NSViewController <NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate>
@end

// Tab 4: Compatibility (Bundle IDs)
@interface DKSTCompatibilityViewController : NSViewController <NSTableViewDataSource, NSTableViewDelegate>
@end

// Tab 5: About / Info
@interface DKSTAboutViewController : NSViewController
@end
