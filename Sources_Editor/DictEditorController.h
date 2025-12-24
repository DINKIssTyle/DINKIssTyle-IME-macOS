/*
 * DictEditorController.h
 * DKSTDictEditor
 *
 * Controller for the Hanja Dictionary Editor.
 * Handles UI, file loading/saving, and searching.
 */

#import <Cocoa/Cocoa.h>

@interface DictEditorController
    : NSObject <NSApplicationDelegate, NSTableViewDataSource,
                NSTableViewDelegate, NSSearchFieldDelegate>

@property(strong) NSWindow *window;
@property(strong) NSTableView *tableView;
@property(strong) NSMutableArray
    *allEntries; // Array of NSMutableDictionary {trigger, values, originalLine}
@property(strong)
    NSMutableArray *filteredEntries; // Array of entries currently shown
@property(strong) NSString *currentFilePath;
@property(strong) NSTextField *statusLabel;
@property(strong) NSSearchField *searchField;

- (void)showAboutWindow:(id)sender;

@end
