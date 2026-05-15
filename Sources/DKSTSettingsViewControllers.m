#import "DKSTSettingsViewControllers.h"
#import "DKSTConstants.h"
#import "DKSTShortcutRecorder.h"

// Helper to get shared defaults
static NSUserDefaults *sharedDefaults() {
  static NSUserDefaults *suiteDefaults = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    suiteDefaults = [[NSUserDefaults alloc]
        initWithSuiteName:@"com.dinkisstyle.inputmethod.DKST"];
  });
  return suiteDefaults;
}

static NSArray *DKSTIMEInfoPlistCandidatePaths() {
  NSMutableArray *paths = [NSMutableArray array];
  NSBundle *mainBundle = [NSBundle mainBundle];
  NSString *settingsBundlePath = [mainBundle bundlePath];

  if ([settingsBundlePath length] > 0) {
    NSString *resourcesPath = [settingsBundlePath stringByDeletingLastPathComponent];
    NSString *contentsPath = [resourcesPath stringByDeletingLastPathComponent];
    NSString *imeBundlePath = [contentsPath stringByDeletingLastPathComponent];

    if ([[settingsBundlePath lastPathComponent] isEqualToString:@"DKSTSettings.app"] &&
        [[resourcesPath lastPathComponent] isEqualToString:@"Resources"] &&
        [[contentsPath lastPathComponent] isEqualToString:@"Contents"] &&
        [[imeBundlePath pathExtension] isEqualToString:@"app"]) {
      [paths addObject:[imeBundlePath
                           stringByAppendingPathComponent:@"Contents/Info.plist"]];
    }

    NSString *siblingIMEPath = [[settingsBundlePath stringByDeletingLastPathComponent]
        stringByAppendingPathComponent:@"DKST.app/Contents/Info.plist"];
    [paths addObject:siblingIMEPath];
  }

  [paths addObject:[@"~/Library/Input Methods/DKST.app/Contents/Info.plist"
                       stringByExpandingTildeInPath]];
  [paths addObject:@"/Library/Input Methods/DKST.app/Contents/Info.plist"];

  return paths;
}

static NSDictionary *DKSTIMEInfoPlist() {
  NSFileManager *fm = [NSFileManager defaultManager];
  for (NSString *path in DKSTIMEInfoPlistCandidatePaths()) {
    if (![path length] || ![fm fileExistsAtPath:path]) {
      continue;
    }

    NSDictionary *plist = [NSDictionary dictionaryWithContentsOfFile:path];
    if ([plist isKindOfClass:[NSDictionary class]]) {
      return plist;
    }
  }

  return [[NSBundle mainBundle] infoDictionary];
}

#pragma mark - Tab 1: General Settings

@implementation DKSTGeneralViewController {
  NSButton *moaJjikiCheckbox;
  NSButton *fullDeleteCheckbox;
  NSButton *hanjaConversionCheckbox;
  NSButton *appleHanjaDictionaryCheckbox;
  NSButton *customShiftCheckbox;
  NSButton *useMarkedTextForAllAppsCheckbox;
  DKSTShortcutRecorder *hanjaShortcutRecorder;
}

- (void)loadView {
  NSStackView *stackView =
      [[NSStackView alloc] initWithFrame:NSMakeRect(0, 0, 550, 450)];
  stackView.orientation = NSUserInterfaceLayoutOrientationVertical;
  stackView.alignment = NSLayoutAttributeLeading;
  stackView.spacing = 12; // Tighter internal spacing
  stackView.edgeInsets = NSEdgeInsetsMake(30, 30, 30, 30);
  self.view = stackView;

  CGFloat leftColWidth = 240;

  // --- 섹션 1: 일반 ---
  NSTextField *generalHeader = [NSTextField labelWithString:@"일반"];
  generalHeader.font = [NSFont boldSystemFontOfSize:13];
  [stackView addView:generalHeader inGravity:NSStackViewGravityTop];

  moaJjikiCheckbox =
      [NSButton checkboxWithTitle:@"모아치기 (자모 순서 자동 보정)"
                           target:self
                           action:@selector(toggleMoaJjiki:)];
  fullDeleteCheckbox =
      [NSButton checkboxWithTitle:@"글자 단위로 삭제"
                           target:self
                           action:@selector(toggleFullDelete:)];
  NSStackView *genRow1 = [NSStackView
      stackViewWithViews:@[ moaJjikiCheckbox, fullDeleteCheckbox ]];
  genRow1.spacing = 20;
  [moaJjikiCheckbox.widthAnchor constraintEqualToConstant:leftColWidth].active =
      YES;
  [stackView addView:genRow1 inGravity:NSStackViewGravityTop];

  customShiftCheckbox =
      [NSButton checkboxWithTitle:@"Shift + 단자음/단모음 사용"
                           target:self
                           action:@selector(toggleCustomShift:)];
  [stackView addView:customShiftCheckbox inGravity:NSStackViewGravityTop];

  [stackView setCustomSpacing:25 afterView:customShiftCheckbox]; // Section gap

  // --- 섹션 2: 한자 및 사전 기능 ---
  NSTextField *dictHeader = [NSTextField labelWithString:@"한자 및 사전 기능"];
  dictHeader.font = [NSFont boldSystemFontOfSize:13];
  [stackView addView:dictHeader inGravity:NSStackViewGravityTop];

  hanjaConversionCheckbox =
      [NSButton checkboxWithTitle:@"한자(사전) 변환 입력 사용"
                           target:self
                           action:@selector(toggleHanjaConversion:)];
  hanjaShortcutRecorder =
      [[DKSTShortcutRecorder alloc] initWithFrame:NSMakeRect(0, 0, 150, 26)];
  hanjaShortcutRecorder.delegate = self;
  NSStackView *shortcutInputRow = [NSStackView stackViewWithViews:@[
    [NSTextField labelWithString:@"단축키:"], hanjaShortcutRecorder
  ]];
  shortcutInputRow.spacing = 8;

  NSStackView *dictRow1 = [NSStackView
      stackViewWithViews:@[ hanjaConversionCheckbox, shortcutInputRow ]];
  dictRow1.spacing = 20;
  [hanjaConversionCheckbox.widthAnchor constraintEqualToConstant:leftColWidth]
      .active = YES;
  [stackView addView:dictRow1 inGravity:NSStackViewGravityTop];

  appleHanjaDictionaryCheckbox =
      [NSButton checkboxWithTitle:@"Apple 시스템 한자 사전도 후보에 사용"
                           target:self
                           action:@selector(toggleAppleHanjaDictionary:)];
  [stackView addView:appleHanjaDictionaryCheckbox
           inGravity:NSStackViewGravityTop];

  [stackView setCustomSpacing:25
                    afterView:appleHanjaDictionaryCheckbox]; // Section gap

  // --- 섹션 3: 호환성 ---
  NSTextField *compatHeader = [NSTextField labelWithString:@"호환성"];
  compatHeader.font = [NSFont boldSystemFontOfSize:13];
  [stackView addView:compatHeader inGravity:NSStackViewGravityTop];

  useMarkedTextForAllAppsCheckbox = [NSButton
      checkboxWithTitle:@"모든 앱에서 밑줄 조합 방식(Marked Text) 사용"
                 target:self
                 action:@selector(toggleUseMarkedTextForAllApps:)];
  [stackView addView:useMarkedTextForAllAppsCheckbox
           inGravity:NSStackViewGravityTop];

  // Flex spacer
  NSView *spacer = [[NSView alloc] init];
  [stackView addView:spacer inGravity:NSStackViewGravityTop];
  [stackView setCustomSpacing:0 afterView:spacer];

  self.preferredContentSize = NSMakeSize(550, 320);
}

- (void)viewWillAppear {
  [super viewWillAppear];
  [self refreshState];
}

- (void)refreshState {
  NSUserDefaults *defaults = sharedDefaults();

  moaJjikiCheckbox.state = [defaults boolForKey:@"EnableMoaJjiki"]
                               ? NSControlStateValueOn
                               : NSControlStateValueOff;
  fullDeleteCheckbox.state = [defaults boolForKey:@"FullCharacterDelete"]
                                 ? NSControlStateValueOn
                                 : NSControlStateValueOff;
  hanjaConversionCheckbox.state = [defaults boolForKey:@"EnableHanja"]
                                      ? NSControlStateValueOn
                                      : NSControlStateValueOff;
  appleHanjaDictionaryCheckbox.state =
      [defaults boolForKey:kDKSTUseAppleHanjaDictionaryKey]
          ? NSControlStateValueOn
          : NSControlStateValueOff;
  customShiftCheckbox.state = [defaults boolForKey:@"EnableCustomShift"]
                                  ? NSControlStateValueOn
                                  : NSControlStateValueOff;
  useMarkedTextForAllAppsCheckbox.state =
      [defaults boolForKey:kDKSTUseMarkedTextForAllAppsKey]
          ? NSControlStateValueOn
          : NSControlStateValueOff;

  [self loadHanjaShortcut];
}

- (void)loadHanjaShortcut {
  CFStringRef appID = CFSTR("com.dinkisstyle.inputmethod.DKST");
  CFPropertyListRef keyCodeRef = CFPreferencesCopyAppValue(
      (__bridge CFStringRef)kDKSTHanjaShortcutKeyCodeKey, appID);
  CFPropertyListRef modifiersRef = CFPreferencesCopyAppValue(
      (__bridge CFStringRef)kDKSTHanjaShortcutModifiersKey, appID);

  if (keyCodeRef && modifiersRef) {
    unsigned short keyCode =
        (unsigned short)[((__bridge NSNumber *)keyCodeRef) integerValue];
    NSUInteger modifiers =
        (NSUInteger)[((__bridge NSNumber *)modifiersRef)unsignedIntegerValue];
    [hanjaShortcutRecorder setShortcutWithKeyCode:keyCode modifiers:modifiers];
  }
  if (keyCodeRef)
    CFRelease(keyCodeRef);
  if (modifiersRef)
    CFRelease(modifiersRef);
}

- (IBAction)toggleMoaJjiki:(id)sender {
  [sharedDefaults() setBool:(moaJjikiCheckbox.state == NSControlStateValueOn)
                     forKey:@"EnableMoaJjiki"];
  [sharedDefaults() synchronize];
}

- (IBAction)toggleFullDelete:(id)sender {
  [sharedDefaults() setBool:(fullDeleteCheckbox.state == NSControlStateValueOn)
                     forKey:@"FullCharacterDelete"];
  [sharedDefaults() synchronize];
}

- (IBAction)toggleHanjaConversion:(id)sender {
  [sharedDefaults()
      setBool:(hanjaConversionCheckbox.state == NSControlStateValueOn)
       forKey:@"EnableHanja"];
  [sharedDefaults() synchronize];
}

- (IBAction)toggleAppleHanjaDictionary:(id)sender {
  [sharedDefaults()
      setBool:(appleHanjaDictionaryCheckbox.state == NSControlStateValueOn)
       forKey:kDKSTUseAppleHanjaDictionaryKey];
  [sharedDefaults() synchronize];
}

- (IBAction)toggleCustomShift:(id)sender {
  [sharedDefaults() setBool:(customShiftCheckbox.state == NSControlStateValueOn)
                     forKey:@"EnableCustomShift"];
  [sharedDefaults() synchronize];
}

- (IBAction)toggleUseMarkedTextForAllApps:(id)sender {
  [sharedDefaults()
      setBool:(useMarkedTextForAllAppsCheckbox.state == NSControlStateValueOn)
       forKey:kDKSTUseMarkedTextForAllAppsKey];
  [sharedDefaults() synchronize];
}

- (void)shortcutRecorder:(DKSTShortcutRecorder *)recorder
        didRecordKeyCode:(unsigned short)keyCode
               modifiers:(NSUInteger)modifiers {
  CFStringRef appID = CFSTR("com.dinkisstyle.inputmethod.DKST");
  CFPreferencesSetAppValue((__bridge CFStringRef)kDKSTHanjaShortcutKeyCodeKey,
                           (__bridge CFPropertyListRef) @(keyCode), appID);
  CFPreferencesSetAppValue((__bridge CFStringRef)kDKSTHanjaShortcutModifiersKey,
                           (__bridge CFPropertyListRef) @(modifiers), appID);
  CFPreferencesAppSynchronize(appID);

  [[NSDistributedNotificationCenter defaultCenter]
      postNotificationName:kDKSTHanjaShortcutDidChangeNotification
                    object:nil
                  userInfo:nil
        deliverImmediately:YES];
}

- (void)shortcutRecorderDidClear:(DKSTShortcutRecorder *)recorder {
  CFStringRef appID = CFSTR("com.dinkisstyle.inputmethod.DKST");
  CFPreferencesSetAppValue((__bridge CFStringRef)kDKSTHanjaShortcutKeyCodeKey,
                           NULL, appID);
  CFPreferencesSetAppValue((__bridge CFStringRef)kDKSTHanjaShortcutModifiersKey,
                           NULL, appID);
  CFPreferencesAppSynchronize(appID);

  [[NSDistributedNotificationCenter defaultCenter]
      postNotificationName:kDKSTHanjaShortcutDidChangeNotification
                    object:nil
                  userInfo:nil
        deliverImmediately:YES];
}

@end

#pragma mark - Tab 2: Mapping Settings

@implementation DKSTMappingViewController {
  NSTableView *tableView;
  NSMutableArray *mappingKeys;
  NSMutableDictionary *mappingDict;
}

- (void)loadView {
  NSStackView *stackView =
      [[NSStackView alloc] initWithFrame:NSMakeRect(0, 0, 500, 400)];
  stackView.orientation = NSUserInterfaceLayoutOrientationVertical;
  stackView.alignment = NSLayoutAttributeLeading;
  stackView.spacing = 15;
  stackView.edgeInsets = NSEdgeInsetsMake(30, 30, 30, 30);
  self.view = stackView;

  NSTextField *descLabel =
      [NSTextField labelWithString:@"Shift + 단자음/ 단모음으로 자주 사용하는 "
                                   @"문구를 빠르게 작성하세요."];
  [stackView addView:descLabel inGravity:NSStackViewGravityTop];

  NSScrollView *scrollView =
      [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, 440, 250)];
  scrollView.hasVerticalScroller = YES;
  scrollView.borderType = NSBezelBorder;

  tableView = [[NSTableView alloc] initWithFrame:scrollView.bounds];
  NSTableColumn *keyCol = [[NSTableColumn alloc] initWithIdentifier:@"Key"];
  keyCol.title = @"키";
  keyCol.width = 100;
  keyCol.editable = NO;
  [tableView addTableColumn:keyCol];

  NSTableColumn *outCol = [[NSTableColumn alloc] initWithIdentifier:@"Output"];
  outCol.title = @"출력내용(Text/Emoji)";
  outCol.width = 300;
  outCol.editable = YES;
  [tableView addTableColumn:outCol];

  tableView.dataSource = self;
  tableView.delegate = self;
  tableView.usesAlternatingRowBackgroundColors = YES;

  scrollView.documentView = tableView;
  [stackView addView:scrollView inGravity:NSStackViewGravityTop];

  mappingKeys = [[NSMutableArray alloc]
      initWithObjects:@"y (ㅛ)", @"u (ㅕ)", @"i (ㅑ)", @"a (ㅁ)", @"s (ㄴ)",
                      @"d (ㅇ)", @"f (ㄹ)", @"g (ㅎ)", @"h (ㅗ)", @"j (ㅓ)",
                      @"k (ㅏ)", @"l (ㅣ)", @"z (ㅋ)", @"x (ㅌ)", @"c (ㅊ)",
                      @"v (ㅍ)", @"b (ㅠ)", @"n (ㅜ)", @"m (ㅡ)", nil];

  self.preferredContentSize = NSMakeSize(550, 480);
}

- (void)viewWillAppear {
  [super viewWillAppear];
  [self loadData];
}

- (void)loadData {
  NSUserDefaults *defaults = sharedDefaults();

  NSDictionary *saved = [defaults dictionaryForKey:@"DKSTCustomShiftMappings"];
  if (mappingDict) {
    [mappingDict release];
    mappingDict = nil;
  }
  
  if (saved) {
    mappingDict = [saved mutableCopy]; // Retain count 1
  } else {
    mappingDict = [[NSMutableDictionary alloc] init]; // Retain count 1
    for (NSString *key in mappingKeys)
      [mappingDict setObject:@"" forKey:key];
  }
  [tableView reloadData];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
  return mappingKeys.count;
}

- (id)tableView:(NSTableView *)tableView
    objectValueForTableColumn:(NSTableColumn *)tableColumn
                          row:(NSInteger)row {
  NSString *key = mappingKeys[row];
  if ([tableColumn.identifier isEqualToString:@"Key"])
    return key;
  return mappingDict[key];
}

- (void)tableView:(NSTableView *)tableView
    setObjectValue:(id)object
    forTableColumn:(NSTableColumn *)tableColumn
               row:(NSInteger)row {
  if ([tableColumn.identifier isEqualToString:@"Output"]) {
    NSString *key = mappingKeys[row];
    [mappingDict setObject:(NSString *)object forKey:key];
    [sharedDefaults() setObject:mappingDict forKey:@"DKSTCustomShiftMappings"];
    [sharedDefaults() synchronize];
  }
}

@end

#pragma mark - Tab 3: Dictionary Settings

@implementation DKSTDictionaryViewController {
  NSTableView *tableView;
  NSMutableArray *allEntries;
  NSMutableArray *filteredEntries;
  NSSearchField *searchField;
  NSString *currentFilePath;
}

- (void)loadView {
  NSStackView *stackView =
      [[NSStackView alloc] initWithFrame:NSMakeRect(0, 0, 500, 400)];
  stackView.orientation = NSUserInterfaceLayoutOrientationVertical;
  stackView.alignment = NSLayoutAttributeLeading;
  stackView.spacing = 10;
  stackView.edgeInsets = NSEdgeInsetsMake(30, 30, 30, 30);
  self.view = stackView;

  NSStackView *topRow = [NSStackView stackViewWithViews:@[
    searchField =
        [[NSSearchField alloc] initWithFrame:NSMakeRect(0, 0, 240, 22)],
    ({
      NSButton *btn = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 100, 26)];
      btn.title = @"온라인 업데이트";
      btn.bezelStyle = NSBezelStyleRounded;
      btn.target = self;
      btn.action = @selector(updateDictionary:);
      btn;
    }),
    ({
      NSButton *btn = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 80, 26)];
      btn.title = @"저장";
      btn.bezelStyle = NSBezelStyleRounded;
      btn.target = self;
      btn.action = @selector(saveDictionary:);
      btn;
    })
  ]];
  searchField.delegate = self;
  searchField.placeholderString = @"문자, 또는 후보창 문자를 검색하세요.";
  [stackView addView:topRow inGravity:NSStackViewGravityTop];

  NSScrollView *scrollView =
      [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, 440, 250)];
  scrollView.hasVerticalScroller = YES;
  scrollView.borderType = NSBezelBorder;

  tableView = [[NSTableView alloc] initWithFrame:scrollView.bounds];
  NSTableColumn *trigCol =
      [[NSTableColumn alloc] initWithIdentifier:@"trigger"];
  trigCol.title = @"문자";
  trigCol.width = 80;
  [tableView addTableColumn:trigCol];

  NSTableColumn *valCol = [[NSTableColumn alloc] initWithIdentifier:@"values"];
  valCol.title = @"한자 후보창에 보여줄 문자";
  valCol.width = 330;
  [tableView addTableColumn:valCol];

  tableView.dataSource = self;
  tableView.delegate = self;
  tableView.usesAlternatingRowBackgroundColors = YES;
  scrollView.documentView = tableView;
  [stackView addView:scrollView inGravity:NSStackViewGravityTop];

  NSStackView *bottomRow = [NSStackView stackViewWithViews:@[
    ({
      NSButton *btn = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 70, 26)];
      btn.title = @"+ 추가";
      btn.bezelStyle = NSBezelStyleRounded;
      btn.target = self;
      btn.action = @selector(addEntry:);
      btn;
    }),
    ({
      NSButton *btn = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 70, 26)];
      btn.title = @"- 제거";
      btn.bezelStyle = NSBezelStyleRounded;
      btn.target = self;
      btn.action = @selector(deleteEntry:);
      btn;
    }),
    [NSView new], // Spacer
    ({
      NSButton *btn =
          [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 100, 26)];
      btn.title = @"파일 열기";
      btn.bezelStyle = NSBezelStyleRounded;
      btn.target = self;
      btn.action = @selector(openDictionaryFile:);
      btn;
    })
  ]];
  bottomRow.distribution = NSStackViewDistributionFill;
  [stackView addView:bottomRow inGravity:NSStackViewGravityTop];
  [bottomRow.widthAnchor constraintEqualToAnchor:stackView.widthAnchor
                                        constant:-60]
      .active = YES;

  self.preferredContentSize = NSMakeSize(550, 480);
  [self detectAndLoadFile];
}

- (void)detectAndLoadFile {
  NSString *userPath =
      [@"~/Library/Input Methods/DKST.app/Contents/Resources/hanja.txt"
          stringByExpandingTildeInPath];
  NSString *systemPath =
      @"/Library/Input Methods/DKST.app/Contents/Resources/hanja.txt";
  NSFileManager *fm = [NSFileManager defaultManager];

  if ([fm fileExistsAtPath:userPath])
    [self loadFile:userPath];
  else if ([fm fileExistsAtPath:systemPath])
    [self loadFile:systemPath];
}

- (void)loadFile:(NSString *)path {
  if (allEntries) {
    [allEntries release];
    allEntries = nil;
  }
  if (filteredEntries) {
    [filteredEntries release];
    filteredEntries = nil;
  }
  
  currentFilePath = [path retain]; // Ensure path is kept
  allEntries = [[NSMutableArray alloc] init];
  NSString *content = [NSString stringWithContentsOfFile:path
                                                encoding:NSUTF8StringEncoding
                                                   error:nil];
  if (!content)
    return;

  NSArray *lines = [content componentsSeparatedByString:@"\n"];
  for (NSString *line in lines) {
    if (line.length == 0)
      continue;
    NSRange colon = [line rangeOfString:@":"];
    if (colon.location != NSNotFound) {
      NSString *trigger = [line substringToIndex:colon.location];
      NSString *values = [line substringFromIndex:colon.location + 1];
      [allEntries
          addObject:[NSMutableDictionary
                        dictionaryWithObjectsAndKeys:trigger, @"trigger",
                                                     values, @"values", nil]];
    } else if ([line containsString:@"###DKST"]) {
      [allEntries
          addObject:[NSMutableDictionary
                        dictionaryWithObjectsAndKeys:@"###DKST", @"trigger",
                                                     @"--- 사용자 데이터 구분선 ---", @"values", nil]];
    }
  }
  filteredEntries = [allEntries mutableCopy];
  [tableView reloadData];
}

- (void)controlTextDidChange:(NSNotification *)obj {
  if (obj.object == searchField) {
    NSString *filter = searchField.stringValue;
    
    if (filteredEntries) {
      [filteredEntries release];
      filteredEntries = nil;
    }
    
    if (filter.length == 0) {
      filteredEntries = [allEntries mutableCopy];
    } else {
      filteredEntries = [[NSMutableArray alloc] init];
      for (NSDictionary *e in allEntries) {
        NSString *trigger = e[@"trigger"];
        NSString *values = e[@"values"];
        BOOL match = NO;
        if (trigger && [trigger localizedCaseInsensitiveContainsString:filter]) {
          match = YES;
        } else if (values && [values localizedCaseInsensitiveContainsString:filter]) {
          match = YES;
        }
        if (match) [filteredEntries addObject:e];
      }
    }
    [tableView reloadData];
  }
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
  return filteredEntries.count;
}
- (id)tableView:(NSTableView *)tableView
    objectValueForTableColumn:(NSTableColumn *)tableColumn
                          row:(NSInteger)row {
  return filteredEntries[row][tableColumn.identifier];
}
- (void)tableView:(NSTableView *)tableView
    setObjectValue:(id)object
    forTableColumn:(NSTableColumn *)tableColumn
               row:(NSInteger)row {
  NSMutableDictionary *entry = filteredEntries[row];
  NSString *newValue = (NSString *)object;

  // Real-time Correction for "values" column
  if ([tableColumn.identifier isEqualToString:@"values"]) {
    // 1. Normalize comma spacing
    newValue = [newValue stringByReplacingOccurrencesOfString:@", "
                                                   withString:@","];
    newValue = [newValue stringByReplacingOccurrencesOfString:@" ,"
                                                   withString:@","];
    // 3. Remove exact duplicate values
    NSArray *parts = [newValue componentsSeparatedByString:@","];
    NSMutableArray *unique = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];
    for (NSString *part in parts) {
      NSString *trimmed =
          [part stringByTrimmingCharactersInSet:
              [NSCharacterSet whitespaceCharacterSet]];
      if ([trimmed length] > 0 && ![seen containsObject:trimmed]) {
        [seen addObject:trimmed];
        [unique addObject:trimmed];
      }
    }
    newValue = [unique componentsJoinedByString:@","];
  }

  // Also strip colons from the trigger column
  if ([tableColumn.identifier isEqualToString:@"trigger"]) {
    newValue = [newValue stringByReplacingOccurrencesOfString:@":"
                                                   withString:@""];
  }

  [entry setObject:newValue forKey:tableColumn.identifier];
}

- (void)addEntry:(id)sender {
  NSMutableDictionary *newE = [NSMutableDictionary
      dictionaryWithObjectsAndKeys:@"", @"trigger", @"", @"values", nil];
  [allEntries addObject:newE];
  
  if (filteredEntries) [filteredEntries release];
  filteredEntries = [allEntries mutableCopy];
  
  [tableView reloadData];
  [tableView selectRowIndexes:[NSIndexSet
                                  indexSetWithIndex:filteredEntries.count - 1]
         byExtendingSelection:NO];
  [tableView scrollRowToVisible:filteredEntries.count - 1];
}

- (void)deleteEntry:(id)sender {
  NSInteger row = tableView.selectedRow;
  if (row >= 0) {
    [allEntries removeObject:filteredEntries[row]];
    [filteredEntries removeObjectAtIndex:row];
    [tableView reloadData];
  }
}

- (void)updateDictionary:(id)sender {
  // Use the script to update
  NSString *scriptPath = [[NSBundle mainBundle] pathForResource:@"dictup" ofType:@"sh"];
  // If not in bundle, try the one in the project root for dev
  if (!scriptPath) {
    scriptPath = @"/Users/dinki/Documents/GitHub/DINKIssTyle-IME-macOS/dictup.sh";
  }

  NSTask *task = [[NSTask alloc] init];
  [task setLaunchPath:@"/bin/bash"];
  [task setArguments:@[ scriptPath ]];
  
  NSError *error = nil;
  if ([task launchAndReturnError:&error]) {
    [task waitUntilExit];
    if ([task terminationStatus] == 0) {
      [self loadFile:currentFilePath];
      NSAlert *a = [[NSAlert alloc] init];
      a.messageText = @"온라인 업데이트가 완료되었습니다.";
      [a runModal];
    } else {
      NSAlert *a = [[NSAlert alloc] init];
      a.messageText = @"업데이트 중 오류가 발생했습니다.";
      [a runModal];
    }
  } else {
    NSAlert *a = [[NSAlert alloc] init];
    a.messageText = [NSString stringWithFormat:@"업데이트 스크립트를 실행할 수 없습니다: %@", error.localizedDescription];
    [a runModal];
  }
}

- (void)saveDictionary:(id)sender {
  NSMutableString *outS = [NSMutableString string];
  for (NSDictionary *e in allEntries) {
    NSString *trigger = e[@"trigger"];
    NSString *values = e[@"values"];

    // Normalize spacing before saving
    NSString *cleanValues = values;
    cleanValues = [cleanValues stringByReplacingOccurrencesOfString:@", "
                                                         withString:@","];
    cleanValues = [cleanValues stringByReplacingOccurrencesOfString:@" ,"
                                                         withString:@","];

    // Remove exact duplicates
    NSArray *parts = [cleanValues componentsSeparatedByString:@","];
    NSMutableArray *unique = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];
    for (NSString *part in parts) {
      NSString *trimmed = [part
          stringByTrimmingCharactersInSet:[NSCharacterSet
                                              whitespaceCharacterSet]];
      if ([trimmed length] > 0 && ![seen containsObject:trimmed]) {
        [seen addObject:trimmed];
        [unique addObject:trimmed];
      }
    }
    cleanValues = [unique componentsJoinedByString:@","];

    // Also clean trigger
    NSString *cleanTrigger =
        [trigger stringByReplacingOccurrencesOfString:@":" withString:@""];

    if ([cleanTrigger isEqualToString:@"###DKST"]) {
      [outS appendFormat:@"\n###DKST\n"];
    } else {
      [outS appendFormat:@"%@:%@\n", cleanTrigger, cleanValues];
    }
  }

  NSError *error = nil;
  if ([outS writeToFile:currentFilePath
             atomically:YES
               encoding:NSUTF8StringEncoding
                  error:&error]) {
    [[NSDistributedNotificationCenter defaultCenter]
        postNotificationName:@"DKSTDictionaryDidChangeNotification"
                      object:nil
                    userInfo:nil
          deliverImmediately:YES];
    NSAlert *a = [[NSAlert alloc] init];
    a.messageText = @"저장되었습니다.";
    [a runModal];
  } else {
    // Fallback to admin permission if needed (AppleScript logic)
    NSString *temp = [NSTemporaryDirectory()
        stringByAppendingPathComponent:@"hanja_temp.txt"];
    [outS writeToFile:temp
           atomically:YES
             encoding:NSUTF8StringEncoding
                error:nil];
    NSString *script =
        [NSString stringWithFormat:@"do shell script \"cp -f '%@' '%@'\" with "
                                   @"administrator privileges",
                                   temp, currentFilePath];
    NSAppleScript *as = [[NSAppleScript alloc] initWithSource:script];
    if ([as executeAndReturnError:nil]) {
      [[NSDistributedNotificationCenter defaultCenter]
          postNotificationName:@"DKSTDictionaryDidChangeNotification"
                        object:nil
                      userInfo:nil
            deliverImmediately:YES];
      NSAlert *a = [[NSAlert alloc] init];
      a.messageText = @"저장되었습니다.";
      [a runModal];
    }
  }
}

- (void)openDictionaryFile:(id)sender {
  [[NSWorkspace sharedWorkspace] openFile:currentFilePath];
}

@end

#pragma mark - Tab 4: Compatibility Settings

@implementation DKSTCompatibilityViewController {
  NSTableView *tableView;
  NSMutableArray *bundleIDs;
}

- (void)loadView {
  NSStackView *stackView =
      [[NSStackView alloc] initWithFrame:NSMakeRect(0, 0, 500, 400)];
  stackView.orientation = NSUserInterfaceLayoutOrientationVertical;
  stackView.alignment = NSLayoutAttributeLeading;
  stackView.spacing = 15;
  stackView.edgeInsets = NSEdgeInsetsMake(30, 30, 30, 30);
  self.view = stackView;

  NSTextField *desc =
      [NSTextField labelWithString:@"이 곳에 등록한 앱은 밑줄 조합 방식을 "
                                   @"강제하여 한글 입력 호환성을 개선합니다."];
  [stackView addView:desc inGravity:NSStackViewGravityTop];

  NSScrollView *scrollView =
      [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, 440, 250)];
  scrollView.hasVerticalScroller = YES;
  scrollView.borderType = NSBezelBorder;

  tableView = [[NSTableView alloc] initWithFrame:scrollView.bounds];
  NSTableColumn *col = [[NSTableColumn alloc] initWithIdentifier:@"BundleID"];
  col.title = @"Bundle ID";
  col.width = 420;
  [tableView addTableColumn:col];

  tableView.dataSource = self;
  tableView.delegate = self;
  tableView.usesAlternatingRowBackgroundColors = YES;
  scrollView.documentView = tableView;
  [stackView addView:scrollView inGravity:NSStackViewGravityTop];

  NSStackView *btnRow = [NSStackView stackViewWithViews:@[
    ({
      NSButton *btn = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 70, 26)];
      btn.title = @"+ 추가";
      btn.bezelStyle = NSBezelStyleRounded;
      btn.target = self;
      btn.action = @selector(addApp:);
      btn;
    }),
    ({
      NSButton *btn = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 70, 26)];
      btn.title = @"- 제거";
      btn.bezelStyle = NSBezelStyleRounded;
      btn.target = self;
      btn.action = @selector(removeApp:);
      btn;
    })
  ]];
  btnRow.spacing = 10;
  [stackView addView:btnRow inGravity:NSStackViewGravityTop];

  self.preferredContentSize = NSMakeSize(550, 480);
}

- (void)viewWillAppear {
  [super viewWillAppear];
  NSArray *saved =
      [sharedDefaults() arrayForKey:kDKSTMarkedTextAppBundleIDsKey];
  bundleIDs = saved ? [saved mutableCopy] : [NSMutableArray array];
  [tableView reloadData];
}

- (void)saveData {
  [sharedDefaults() setObject:bundleIDs forKey:kDKSTMarkedTextAppBundleIDsKey];
  [sharedDefaults() synchronize];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
  return bundleIDs.count;
}
- (id)tableView:(NSTableView *)tableView
    objectValueForTableColumn:(NSTableColumn *)tableColumn
                          row:(NSInteger)row {
  return bundleIDs[row];
}
- (void)tableView:(NSTableView *)tableView
    setObjectValue:(id)object
    forTableColumn:(NSTableColumn *)tableColumn
               row:(NSInteger)row {
  bundleIDs[row] = (NSString *)object;
  [self saveData];
}

- (void)addApp:(id)sender {
  NSOpenPanel *p = [NSOpenPanel openPanel];
  p.allowedFileTypes = @[ @"app" ];
  if ([p runModal] == NSModalResponseOK) {
    NSString *bid = [[NSBundle bundleWithURL:p.URL] bundleIdentifier];
    if (bid && ![bundleIDs containsObject:bid]) {
      [bundleIDs addObject:bid];
      [tableView reloadData];
      [self saveData];
    }
  }
}

- (void)removeApp:(id)sender {
  NSInteger row = tableView.selectedRow;
  if (row >= 0) {
    [bundleIDs removeObjectAtIndex:row];
    [tableView reloadData];
    [self saveData];
  }
}

@end

#pragma mark - Tab 5: About Settings

@implementation DKSTAboutViewController

- (void)loadView {
  NSStackView *stackView =
      [[NSStackView alloc] initWithFrame:NSMakeRect(0, 0, 500, 400)];
  stackView.orientation = NSUserInterfaceLayoutOrientationVertical;
  stackView.alignment = NSLayoutAttributeCenterX;
  stackView.spacing = 20;
  stackView.edgeInsets = NSEdgeInsetsMake(30, 30, 30, 30);
  self.view = stackView;

  // App Icon (128x128)
  NSImageView *iconView =
      [[NSImageView alloc] initWithFrame:NSMakeRect(0, 0, 128, 128)];
  iconView.image = [NSImage imageNamed:@"icon"];
  [iconView.widthAnchor constraintEqualToConstant:128].active = YES;
  [iconView.heightAnchor constraintEqualToConstant:128].active = YES;
  [stackView addView:iconView inGravity:NSStackViewGravityTop];

  [stackView setCustomSpacing:20 afterView:iconView];

  NSTextField *titleLabel =
      [NSTextField labelWithString:@"DKST macOS용 한글입력기"];
  titleLabel.font = [NSFont boldSystemFontOfSize:24];
  titleLabel.alignment = NSTextAlignmentCenter;
  [stackView addView:titleLabel inGravity:NSStackViewGravityTop];

  // Read IME Version from the bundled or installed input method Info.plist.
  NSDictionary *imePlist = DKSTIMEInfoPlist();
  NSString *imeVersion = imePlist[@"DKSTVersionDisplay"] ?: imePlist[@"CFBundleShortVersionString"] ?: @"Unknown";

  NSTextField *imeVerLabel = [NSTextField
      labelWithString:[NSString
                          stringWithFormat:@"입력기 버전: %@", imeVersion]];
  imeVerLabel.alignment = NSTextAlignmentCenter;
  [stackView addView:imeVerLabel inGravity:NSStackViewGravityTop];

  // Preferences Version from macro
#ifndef DKST_PREFS_VERSION
#define DKST_PREFS_VERSION "2.0.0"
#endif
  NSString *prefsVersion = @DKST_PREFS_VERSION;
  NSTextField *prefsVerLabel = [NSTextField
      labelWithString:[NSString
                          stringWithFormat:@"환경설정 버전: %@", prefsVersion]];
  prefsVerLabel.alignment = NSTextAlignmentCenter;
  [stackView addView:prefsVerLabel inGravity:NSStackViewGravityTop];

  // Links
  NSStackView *linkRow = [NSStackView stackViewWithViews:@[
    ({
      NSButton *btn = [NSButton buttonWithTitle:@"GitHub 페이지"
                                         target:self
                                         action:@selector(openGitHub:)];
      [btn setBordered:NO];
      NSMutableAttributedString *t =
          [[NSMutableAttributedString alloc] initWithString:btn.title];
      [t addAttribute:NSForegroundColorAttributeName
                value:[NSColor linkColor]
                range:NSMakeRange(0, t.length)];
      [t addAttribute:NSUnderlineStyleAttributeName
                value:@(NSUnderlineStyleSingle)
                range:NSMakeRange(0, t.length)];
      btn.attributedTitle = t;
      btn;
    }),
    ({
      NSButton *btn = [NSButton buttonWithTitle:@"후원"
                                         target:self
                                         action:@selector(openSupport:)];
      [btn setBordered:NO];
      NSMutableAttributedString *t =
          [[NSMutableAttributedString alloc] initWithString:btn.title];
      [t addAttribute:NSForegroundColorAttributeName
                value:[NSColor linkColor]
                range:NSMakeRange(0, t.length)];
      [t addAttribute:NSUnderlineStyleAttributeName
                value:@(NSUnderlineStyleSingle)
                range:NSMakeRange(0, t.length)];
      btn.attributedTitle = t;
      btn;
    })
  ]];
  linkRow.spacing = 20;
  [stackView addView:linkRow inGravity:NSStackViewGravityTop];

  NSTextField *copyLabel =
      [NSTextField labelWithString:@"(C) 2026 DINKI'ssTyle"];
  copyLabel.alignment = NSTextAlignmentCenter;
  copyLabel.textColor = [NSColor secondaryLabelColor];
  copyLabel.font = [NSFont systemFontOfSize:11];
  [stackView addView:copyLabel inGravity:NSStackViewGravityTop];

  self.preferredContentSize = NSMakeSize(550, 420);
}

- (void)openGitHub:(id)sender {
  [[NSWorkspace sharedWorkspace]
      openURL:[NSURL
                  URLWithString:
                      @"https://github.com/DINKIssTyle/DINKIssTyle-IME-macOS"]];
}

- (void)openSupport:(id)sender {
  [[NSWorkspace sharedWorkspace]
      openURL:[NSURL
                  URLWithString:
                      @"https://github.com/sponsors/DINKIssTyle"]];
}

@end
