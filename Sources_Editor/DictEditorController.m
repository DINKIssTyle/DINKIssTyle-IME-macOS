/*
 * DictEditorController.m
 * DKSTDictEditor
 */

#import "DictEditorController.h"

@implementation DictEditorController

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
  // 1. Create Window
  NSRect frame = NSMakeRect(0, 0, 600, 500);
  self.window = [[NSWindow alloc]
      initWithContentRect:frame
                styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                           NSWindowStyleMaskResizable |
                           NSWindowStyleMaskMiniaturizable)
                  backing:NSBackingStoreBuffered
                    defer:NO];
  [self.window setTitle:@"DKST Hanja Dictionary Editor"];
  [self.window center];

  // 2. Create UI Elements
  NSView *contentView = [self.window contentView];

  // Top Bar: Search Field and Save Button
  self.searchField =
      [[NSSearchField alloc] initWithFrame:NSMakeRect(20, 460, 460, 22)];
  [self.searchField setDelegate:self];
  [self.searchField setPlaceholderString:@"Search trigger or values..."];
  [self.searchField setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];
  [contentView addSubview:self.searchField];

  NSButton *saveButton =
      [[NSButton alloc] initWithFrame:NSMakeRect(490, 458, 90, 26)];
  [saveButton setTitle:@"Save"];
  [saveButton setBezelStyle:NSBezelStyleRounded];
  [saveButton setTarget:self];
  [saveButton setAction:@selector(saveDictionary:)];
  [saveButton setAutoresizingMask:NSViewMinXMargin | NSViewMinYMargin];
  [contentView addSubview:saveButton];

  // Table View
  NSScrollView *scrollView =
      [[NSScrollView alloc] initWithFrame:NSMakeRect(20, 50, 560, 400)];
  [scrollView setHasVerticalScroller:YES];
  [scrollView setHasHorizontalScroller:YES];
  [scrollView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];

  self.tableView = [[NSTableView alloc] initWithFrame:scrollView.bounds];
  NSTableColumn *triggerCol =
      [[NSTableColumn alloc] initWithIdentifier:@"trigger"];
  [triggerCol setWidth:100];
  [triggerCol setTitle:@"Trigger (Key)"];
  [self.tableView addTableColumn:triggerCol];

  NSTableColumn *valueCol =
      [[NSTableColumn alloc] initWithIdentifier:@"values"];
  [valueCol setWidth:430];
  [valueCol setTitle:@"Values (Comma Separated)"];
  [self.tableView addTableColumn:valueCol];

  [self.tableView setDataSource:self];
  [self.tableView setDelegate:self];
  [self.tableView setUsesAlternatingRowBackgroundColors:YES];

  [scrollView setDocumentView:self.tableView];
  [contentView addSubview:scrollView];

  // Status Label
  self.statusLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(18, 10, 560, 30)];
  [self.statusLabel setEditable:NO];
  [self.statusLabel setBordered:NO];
  [self.statusLabel setBackgroundColor:[NSColor clearColor]];
  [self.statusLabel setStringValue:@"Initializing..."];
  [self.statusLabel setAutoresizingMask:NSViewWidthSizable | NSViewMaxYMargin];
  [self.statusLabel setFont:[NSFont systemFontOfSize:11]];
  [self.statusLabel setTextColor:[NSColor secondaryLabelColor]];
  [contentView addSubview:self.statusLabel];

  [self.window makeKeyAndOrderFront:nil];

  // 3. Load File Logic
  [self performSelector:@selector(detectAndLoadFile)
             withObject:nil
             afterDelay:0.1];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:
    (NSApplication *)sender {
  return YES;
}

#pragma mark - File Logic

- (void)detectAndLoadFile {
  NSString *userPath =
      [@"~/Library/Input Methods/DKST.app/Contents/Resources/hanja.txt"
          stringByExpandingTildeInPath];
  NSString *systemPath =
      @"/Library/Input Methods/DKST.app/Contents/Resources/hanja.txt";

  NSFileManager *fm = [NSFileManager defaultManager];
  BOOL userExists = [fm fileExistsAtPath:userPath];
  BOOL systemExists = [fm fileExistsAtPath:systemPath];

  if (userExists && systemExists) {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:@"Duplicate Dictionary Files Found"];
    [alert setInformativeText:@"Found dictionary files in both User and System "
                              @"locations.\nWhich one would you like to edit?"];
    [alert addButtonWithTitle:@"Edit User File (~/...)"];
    [alert addButtonWithTitle:@"Edit System File (/Library/...)"];
    [alert setAlertStyle:NSAlertStyleWarning];

    NSModalResponse response = [alert runModal];
    if (response == NSAlertFirstButtonReturn) {
      [self loadFile:userPath];
    } else {
      [self loadFile:systemPath];
    }
  } else if (userExists) {
    [self loadFile:userPath];
  } else if (systemExists) {
    [self loadFile:systemPath];
  } else {
    // Fallback for development/testing
    NSString *bundlePath = [[NSBundle mainBundle] pathForResource:@"hanja"
                                                           ofType:@"txt"];
    if (bundlePath && [fm fileExistsAtPath:bundlePath]) {
      NSAlert *alert = [[NSAlert alloc] init];
      [alert setMessageText:@"No Standard Dictionary File Found"];
      [alert setInformativeText:
                 [NSString
                     stringWithFormat:@"Editing bundled file for testing:\n%@",
                                      bundlePath]];
      [alert runModal];
      [self loadFile:bundlePath];
    } else {
      NSAlert *alert = [[NSAlert alloc] init];
      [alert setMessageText:@"Error"];
      [alert setInformativeText:
                 @"Could not find 'hanja.txt' in standard locations."];
      [alert runModal];
      [self.statusLabel setStringValue:@"Error: File not found."];
    }
  }
}

- (void)loadFile:(NSString *)path {
  self.currentFilePath = path;
  [self.statusLabel
      setStringValue:[NSString stringWithFormat:@"Editing: %@", path]];

  NSError *error = nil;
  NSString *content = [NSString stringWithContentsOfFile:path
                                                encoding:NSUTF8StringEncoding
                                                   error:&error];
  if (error) {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:@"Read Error"];
    [alert setInformativeText:[error localizedDescription]];
    [alert runModal];
    return;
  }

  self.allEntries = [NSMutableArray array];

  NSArray *lines = [content componentsSeparatedByString:@"\n"];
  for (NSString *line in lines) {
    if (line.length == 0)
      continue;

    // Format: trigger:value1,value2...
    // We only split by the FIRST colon to separate trigger and values
    NSRange colonRange = [line rangeOfString:@":"];
    if (colonRange.location != NSNotFound) {
      NSString *trigger = [line substringToIndex:colonRange.location];
      NSString *values = [line substringFromIndex:colonRange.location + 1];

      NSMutableDictionary *entry = [NSMutableDictionary
          dictionaryWithObjectsAndKeys:trigger, @"trigger", values, @"values",
                                       nil];
      [self.allEntries addObject:entry];
    } else {
      // Keep malformed lines? Or just ignore? Only trigger?
      // Let's assume lines without colon are ignored or handled gracefully
    }
  }

  self.filteredEntries = [NSMutableArray arrayWithArray:self.allEntries];
  [self.tableView reloadData];
}

- (void)saveDictionary:(id)sender {
  if (!self.currentFilePath)
    return;

  NSMutableString *output = [NSMutableString string];

  for (NSDictionary *entry in self.allEntries) {
    NSString *trigger = entry[@"trigger"];
    NSString *values = entry[@"values"];
    // Ensure values are clean before saving (double check)
    NSString *cleanValues = [values stringByReplacingOccurrencesOfString:@", "
                                                              withString:@","];
    [output appendFormat:@"%@:%@\n", trigger, cleanValues];
  }

  // 1. Try writing directly first (Works for User path ~/Library/...)
  NSError *error = nil;
  BOOL success = [output writeToFile:self.currentFilePath
                          atomically:YES
                            encoding:NSUTF8StringEncoding
                               error:&error];

  if (success) {
    [self showSaveSuccess];
    return;
  }

  // 2. If failed (likely Permission Denied for /Library/...), try with Sudo via
  // AppleScript Write to temp file first
  NSString *tempPath =
      [NSTemporaryDirectory() stringByAppendingPathComponent:@"hanja_temp.txt"];
  [output writeToFile:tempPath
           atomically:YES
             encoding:NSUTF8StringEncoding
                error:nil];

  // Construct AppleScript execution of shell command
  NSString *scriptSource = [NSString
      stringWithFormat:@"do shell script \"cp -f '%@' '%@' && chmod 644 '%@'\" "
                       @"with administrator privileges",
                       tempPath, self.currentFilePath, self.currentFilePath];

  NSAppleScript *appleScript =
      [[NSAppleScript alloc] initWithSource:scriptSource];
  NSDictionary *errorInfo = nil;
  NSAppleEventDescriptor *eventResult =
      [appleScript executeAndReturnError:&errorInfo];

  if (!eventResult) {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:@"Save Failed"];
    NSString *errMsg =
        errorInfo[NSAppleScriptErrorMessage] ?: @"Unknown AppleScript error";
    [alert setInformativeText:errMsg];
    [alert runModal];
  } else {
    [self showSaveSuccess];
    // Reload to reflect changes
    [self loadFile:self.currentFilePath];
  }

  // Cleanup temp
  [[NSFileManager defaultManager] removeItemAtPath:tempPath error:nil];
}

- (void)showSaveSuccess {
  NSString *oldStatus = [self.statusLabel stringValue];
  [self.statusLabel setStringValue:@"Saved successfully!"];
  [self performSelector:@selector(restoreStatus:)
             withObject:oldStatus
             afterDelay:2.0];
}

- (void)restoreStatus:(NSString *)msg {
  [self.statusLabel setStringValue:msg];
}

#pragma mark - Search Logic

// Real-time filtering is handled here by observing text changes
- (void)controlTextDidChange:(NSNotification *)obj {
  if ([obj object] == self.searchField) {
    NSString *filter = [self.searchField stringValue];
    [self filterEntries:filter];
  }
}

- (void)filterEntries:(NSString *)filter {
  // Basic performance optimization: suspend updates for large data sets if
  // needed, but for simple text dictionary, direct reloadData is responsive
  // enough.
  if (filter.length == 0) {
    self.filteredEntries = [NSMutableArray arrayWithArray:self.allEntries];
  } else {
    self.filteredEntries = [NSMutableArray array];
    for (NSDictionary *entry in self.allEntries) {
      NSString *trigger = entry[@"trigger"];
      NSString *values = entry[@"values"];

      // Case insensitive search
      if ([trigger localizedCaseInsensitiveContainsString:filter] ||
          [values localizedCaseInsensitiveContainsString:filter]) {
        [self.filteredEntries addObject:entry];
      }
    }
  }
  [self.tableView reloadData];
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
  return self.filteredEntries.count;
}

- (id)tableView:(NSTableView *)tableView
    objectValueForTableColumn:(NSTableColumn *)tableColumn
                          row:(NSInteger)row {
  if (row >= self.filteredEntries.count)
    return nil;

  NSDictionary *entry = self.filteredEntries[row];
  return entry[tableColumn.identifier]; // "trigger" or "values"
}

#pragma mark - NSTableViewDelegate

- (void)tableView:(NSTableView *)tableView
    setObjectValue:(id)object
    forTableColumn:(NSTableColumn *)tableColumn
               row:(NSInteger)row {
  if (row >= self.filteredEntries.count)
    return;

  NSMutableDictionary *entry = self.filteredEntries[row];
  NSString *newValue = (NSString *)object;

  // Real-time Correction: Remove spaces after commas immediately
  if ([tableColumn.identifier isEqualToString:@"values"]) {
    newValue = [newValue stringByReplacingOccurrencesOfString:@", "
                                                   withString:@","];
    // Also handle Space+Comma just in case
    newValue = [newValue stringByReplacingOccurrencesOfString:@" ,"
                                                   withString:@","];
  }

  [entry setObject:newValue forKey:tableColumn.identifier];

  // Refilter if currently searching?
  // If we edit a cell and it no longer matches the filter, should it vanish?
  // Usually it's better to keep it until the next search change, or reload.
  // We will keep it simple for now (no auto-refilter on edit).
}

@end
