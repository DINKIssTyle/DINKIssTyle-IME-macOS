#import "DKSTSettingsWindowController.h"
#import "DKSTSettingsViewControllers.h"

@implementation DKSTSettingsWindowController

+ (DKSTSettingsWindowController *)sharedController {
  static DKSTSettingsWindowController *shared = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    shared = [[DKSTSettingsWindowController alloc] init];
  });
  return shared;
}

- (instancetype)init {
  NSWindow *window = [[NSWindow alloc]
      initWithContentRect:NSMakeRect(0, 0, 600, 500)
                styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable)
                  backing:NSBackingStoreBuffered
                    defer:NO];
  [window center];
  [window setTitle:@"DKST macOS용 한글입력기"];

  if (@available(macOS 11.0, *)) {
    window.toolbarStyle = NSWindowToolbarStylePreference;
  }

  self = [super initWithWindow:window];
  if (self) {
    _tabViewController = [[NSTabViewController alloc] init];
    _tabViewController.tabStyle = NSTabViewControllerTabStyleToolbar;

    // Tab 1: General
    DKSTGeneralViewController *generalVC =
        [[DKSTGeneralViewController alloc] init];
    NSTabViewItem *generalItem =
        [NSTabViewItem tabViewItemWithViewController:generalVC];
    generalItem.label = @"일반";
    generalItem.image = [NSImage imageNamed:@"General"];
    [generalItem.image setTemplate:YES];
    [_tabViewController addTabViewItem:generalItem];

    // Tab 2: Single Consonants
    DKSTMappingViewController *mappingVC =
        [[DKSTMappingViewController alloc] init];
    NSTabViewItem *mappingItem =
        [NSTabViewItem tabViewItemWithViewController:mappingVC];
    mappingItem.label = @"단자음/단모음";
    mappingItem.image = [NSImage imageNamed:@"Mappings"];
    [mappingItem.image setTemplate:YES];
    [_tabViewController addTabViewItem:mappingItem];

    // Tab 3: Dictionary
    DKSTDictionaryViewController *dictVC =
        [[DKSTDictionaryViewController alloc] init];
    NSTabViewItem *dictItem =
        [NSTabViewItem tabViewItemWithViewController:dictVC];
    dictItem.label = @"사전";
    dictItem.image = [NSImage imageNamed:@"Dictionary"];
    [dictItem.image setTemplate:YES];
    [_tabViewController addTabViewItem:dictItem];

    // Tab 4: Compatibility
    DKSTCompatibilityViewController *compatVC =
        [[DKSTCompatibilityViewController alloc] init];
    NSTabViewItem *compatItem =
        [NSTabViewItem tabViewItemWithViewController:compatVC];
    compatItem.label = @"호환성";
    compatItem.image = [NSImage imageNamed:@"Compatibility"];
    [compatItem.image setTemplate:YES];
    [_tabViewController addTabViewItem:compatItem];

    // Tab 5: Info
    DKSTAboutViewController *aboutVC = [[DKSTAboutViewController alloc] init];
    NSTabViewItem *aboutItem =
        [NSTabViewItem tabViewItemWithViewController:aboutVC];
    aboutItem.label = @"정보";
    aboutItem.image = [NSImage imageNamed:@"About"];
    [aboutItem.image setTemplate:YES];
    [_tabViewController addTabViewItem:aboutItem];

    window.contentViewController = _tabViewController;

    [_tabViewController addObserver:self
                         forKeyPath:@"selectedTabViewItemIndex"
                            options:NSKeyValueObservingOptionNew
                            context:NULL];
  }
  return self;
}

- (void)dealloc {
  [_tabViewController removeObserver:self
                          forKeyPath:@"selectedTabViewItemIndex"];
  [super dealloc];
}

- (void)windowDidLoad {
  [super windowDidLoad];
  // Initial size adjustment
  [self updateWindowSizeAnimated:NO];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey, id> *)change
                       context:(void *)context {
  if ([keyPath isEqualToString:@"selectedTabViewItemIndex"]) {
    [self updateWindowSizeAnimated:YES];
  } else {
    [super observeValueForKeyPath:keyPath
                         ofObject:object
                           change:change
                          context:context];
  }
}

- (void)updateWindowSizeAnimated:(BOOL)animated {
  NSInteger index = _tabViewController.selectedTabViewItemIndex;
  if (index < 0 || index >= _tabViewController.tabViewItems.count)
    return;

  NSTabViewItem *item = _tabViewController.tabViewItems[index];
  NSViewController *selectedVC = item.viewController;
  if (!selectedVC)
    return;

  // Fixed width, dynamic height
  CGFloat fixedWidth = 550;
  CGFloat targetHeight = selectedVC.preferredContentSize.height;

  // Fallback if height is not set
  if (targetHeight == 0)
    targetHeight = selectedVC.view.fittingSize.height;
  if (targetHeight < 300)
    targetHeight = 300;

  NSRect frame = [self.window
      frameRectForContentRect:NSMakeRect(0, 0, fixedWidth, targetHeight)];
  NSRect currentFrame = self.window.frame;

  // Keep top-left corner fixed
  CGFloat deltaY = frame.size.height - currentFrame.size.height;
  frame.origin.x = currentFrame.origin.x;
  frame.origin.y = currentFrame.origin.y - deltaY;
  frame.size.width =
      currentFrame.size.width; // Keep current width to avoid horizontal jumps

  // If the window was initialized with a different width, we should use the
  // target width
  frame.size.width =
      [self.window frameRectForContentRect:NSMakeRect(0, 0, fixedWidth, 0)]
          .size.width;

  [self.window setFrame:frame display:YES animate:animated];
}

- (void)showWindow:(id)sender {
  [self.window makeKeyAndOrderFront:sender];
  [NSApp activateIgnoringOtherApps:YES];
}

#pragma mark - NSApplicationDelegate

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication {
  return YES;
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)application
                    hasVisibleWindows:(BOOL)hasVisibleWindows {
  (void)application;
  (void)hasVisibleWindows;
  [self showWindow:nil];
  return YES;
}

@end
