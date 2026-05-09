#import <Cocoa/Cocoa.h>
#import <ApplicationServices/ApplicationServices.h>
#import <WebKit/WebKit.h>
#import "../Sources/DKSTHangul.h"

static NSString *const DKSTIMETesterBundleID =
    @"com.dinkisstyle.inputmethod.DKST.imetester";
static NSString *const DKSTInputMethodBundleID =
    @"com.dinkisstyle.inputmethod.DKST";
static NSTextView *DKSTLogView = nil;

static void DKSTAppendLog(NSString *format, ...) {
  if (!DKSTLogView) return;
  va_list args;
  va_start(args, format);
  NSString *message =
      [[[NSString alloc] initWithFormat:format arguments:args] autorelease];
  va_end(args);
  NSString *line = [message stringByAppendingString:@"\n"];
  [[DKSTLogView textStorage]
      appendAttributedString:[[[NSAttributedString alloc] initWithString:line]
                                 autorelease]];
  [DKSTLogView scrollRangeToVisible:NSMakeRange([[DKSTLogView string] length], 0)];
}

static BOOL DKSTTextContainsRomanOrIsolatedJamo(NSString *text) {
  for (NSUInteger index = 0; index < [text length]; index++) {
    unichar c = [text characterAtIndex:index];
    if ((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') ||
        (c >= 0x3130 && c <= 0x318F)) {
      return YES;
    }
  }
  return NO;
}

@interface DKSTLoggingTextView : NSTextView
@end

@implementation DKSTLoggingTextView

- (void)insertText:(id)string replacementRange:(NSRange)replacementRange {
  DKSTAppendLog(@"insertText: '%@' replacementRange=%@",
                [string description], NSStringFromRange(replacementRange));
  [super insertText:string replacementRange:replacementRange];
}

- (void)setMarkedText:(id)string
        selectedRange:(NSRange)selectedRange
     replacementRange:(NSRange)replacementRange {
  NSString *text = [string isKindOfClass:[NSAttributedString class]]
                       ? [(NSAttributedString *)string string]
                       : [string description];
  DKSTAppendLog(@"setMarkedText: '%@' selectedRange=%@ replacementRange=%@",
                text, NSStringFromRange(selectedRange),
                NSStringFromRange(replacementRange));
  [super setMarkedText:string
         selectedRange:selectedRange
       replacementRange:replacementRange];
}

- (void)unmarkText {
  DKSTAppendLog(@"unmarkText");
  [super unmarkText];
}

@end

@interface DKSTTesterDelegate : NSObject <NSApplicationDelegate,
                                         WKNavigationDelegate> {
  NSWindow *_window;
  NSTextField *_sampleField;
  NSTextField *_cpuField;
  NSTextField *_singleLineField;
  NSSecureTextField *_secureField;
  NSSearchField *_searchField;
  NSComboBox *_comboBox;
  NSTokenField *_tokenField;
  DKSTLoggingTextView *_loggingTextView;
  NSTextView *_plainTextView;
  WKWebView *_webView;
  NSButton *_autoRunButton;
  NSButton *_stopButton;
  NSTextField *_repeatField;
  NSTextField *_autoStatusField;
  NSArray *_autoSamples;
  NSTimer *_cpuTimer;
  NSInteger _autoTargetIndex;
  NSInteger _autoSampleIndex;
  NSInteger _autoCharacterIndex;
  NSInteger _autoRepeatIndex;
  NSInteger _autoRepeatCount;
  BOOL _autoRunning;
}
@end

@implementation DKSTTesterDelegate

static BOOL DKSTKeyCodeForCharacter(unichar character, CGKeyCode *keyCode) {
  switch (character) {
  case 'a': *keyCode = 0; return YES;
  case 's': *keyCode = 1; return YES;
  case 'd': *keyCode = 2; return YES;
  case 'f': *keyCode = 3; return YES;
  case 'h': *keyCode = 4; return YES;
  case 'g': *keyCode = 5; return YES;
  case 'z': *keyCode = 6; return YES;
  case 'x': *keyCode = 7; return YES;
  case 'c': *keyCode = 8; return YES;
  case 'v': *keyCode = 9; return YES;
  case 'b': *keyCode = 11; return YES;
  case 'q': *keyCode = 12; return YES;
  case 'w': *keyCode = 13; return YES;
  case 'e': *keyCode = 14; return YES;
  case 'r': *keyCode = 15; return YES;
  case 'y': *keyCode = 16; return YES;
  case 't': *keyCode = 17; return YES;
  case 'o': *keyCode = 31; return YES;
  case 'u': *keyCode = 32; return YES;
  case 'i': *keyCode = 34; return YES;
  case 'p': *keyCode = 35; return YES;
  case 'l': *keyCode = 37; return YES;
  case 'j': *keyCode = 38; return YES;
  case 'k': *keyCode = 40; return YES;
  case 'n': *keyCode = 45; return YES;
  case 'm': *keyCode = 46; return YES;
  case ' ': *keyCode = 49; return YES;
  case '\n': *keyCode = 36; return YES;
  default: return NO;
  }
}

- (void)addItemWithTitle:(NSString *)title
                  action:(SEL)action
           keyEquivalent:(NSString *)key
                  toMenu:(NSMenu *)menu {
  NSMenuItem *item =
      [[[NSMenuItem alloc] initWithTitle:title
                                  action:action
                           keyEquivalent:key] autorelease];
  [menu addItem:item];
}

- (void)addItemWithTitle:(NSString *)title
                  action:(SEL)action
           keyEquivalent:(NSString *)key
            modifierMask:(NSEventModifierFlags)mask
                  toMenu:(NSMenu *)menu {
  NSMenuItem *item =
      [[[NSMenuItem alloc] initWithTitle:title
                                  action:action
                           keyEquivalent:key] autorelease];
  [item setKeyEquivalentModifierMask:mask];
  [menu addItem:item];
}

- (void)installMainMenu {
  NSMenu *mainMenu = [[[NSMenu alloc] initWithTitle:@"Main Menu"] autorelease];

  NSMenuItem *appItem =
      [[[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""]
          autorelease];
  [mainMenu addItem:appItem];
  NSMenu *appMenu = [[[NSMenu alloc] initWithTitle:@"IMETester"] autorelease];
  [appItem setSubmenu:appMenu];
  [self addItemWithTitle:@"About DKST IME Tester"
                  action:@selector(orderFrontStandardAboutPanel:)
           keyEquivalent:@""
                  toMenu:appMenu];
  [appMenu addItem:[NSMenuItem separatorItem]];
  [self addItemWithTitle:@"Hide DKST IME Tester"
                  action:@selector(hide:)
           keyEquivalent:@"h"
                  toMenu:appMenu];
  [self addItemWithTitle:@"Hide Others"
                  action:@selector(hideOtherApplications:)
           keyEquivalent:@"h"
            modifierMask:NSEventModifierFlagCommand | NSEventModifierFlagOption
                  toMenu:appMenu];
  [self addItemWithTitle:@"Show All"
                  action:@selector(unhideAllApplications:)
           keyEquivalent:@""
                  toMenu:appMenu];
  [appMenu addItem:[NSMenuItem separatorItem]];
  NSMenuItem *servicesItem =
      [[[NSMenuItem alloc] initWithTitle:@"Services"
                                  action:nil
                           keyEquivalent:@""] autorelease];
  NSMenu *servicesMenu =
      [[[NSMenu alloc] initWithTitle:@"Services"] autorelease];
  [servicesItem setSubmenu:servicesMenu];
  [appMenu addItem:servicesItem];
  [NSApp setServicesMenu:servicesMenu];
  [appMenu addItem:[NSMenuItem separatorItem]];
  [self addItemWithTitle:@"Quit DKST IME Tester"
                  action:@selector(terminate:)
           keyEquivalent:@"q"
                  toMenu:appMenu];

  NSMenuItem *fileItem =
      [[[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""]
          autorelease];
  [mainMenu addItem:fileItem];
  NSMenu *fileMenu = [[[NSMenu alloc] initWithTitle:@"File"] autorelease];
  [fileItem setSubmenu:fileMenu];
  [self addItemWithTitle:@"Close Window"
                  action:@selector(performClose:)
           keyEquivalent:@"w"
                  toMenu:fileMenu];
  [fileMenu addItem:[NSMenuItem separatorItem]];
  [self addItemWithTitle:@"Run Auto Typing"
                  action:@selector(runAutoTyping:)
           keyEquivalent:@"r"
                  toMenu:fileMenu];

  NSMenuItem *editItem =
      [[[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""]
          autorelease];
  [mainMenu addItem:editItem];
  NSMenu *editMenu = [[[NSMenu alloc] initWithTitle:@"Edit"] autorelease];
  [editItem setSubmenu:editMenu];
  [self addItemWithTitle:@"Undo"
                  action:@selector(undo:)
           keyEquivalent:@"z"
                  toMenu:editMenu];
  [self addItemWithTitle:@"Redo"
                  action:@selector(redo:)
           keyEquivalent:@"Z"
                  toMenu:editMenu];
  [editMenu addItem:[NSMenuItem separatorItem]];
  [self addItemWithTitle:@"Cut"
                  action:@selector(cut:)
           keyEquivalent:@"x"
                  toMenu:editMenu];
  [self addItemWithTitle:@"Copy"
                  action:@selector(copy:)
           keyEquivalent:@"c"
                  toMenu:editMenu];
  [self addItemWithTitle:@"Paste"
                  action:@selector(paste:)
           keyEquivalent:@"v"
                  toMenu:editMenu];
  [self addItemWithTitle:@"Paste and Match Style"
                  action:@selector(pasteAsPlainText:)
           keyEquivalent:@"v"
            modifierMask:NSEventModifierFlagCommand | NSEventModifierFlagOption |
                         NSEventModifierFlagShift
                  toMenu:editMenu];
  [self addItemWithTitle:@"Delete"
                  action:@selector(delete:)
           keyEquivalent:@""
                  toMenu:editMenu];
  [editMenu addItem:[NSMenuItem separatorItem]];
  [self addItemWithTitle:@"Select All"
                  action:@selector(selectAll:)
           keyEquivalent:@"a"
                  toMenu:editMenu];

  NSMenuItem *windowItem =
      [[[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""]
          autorelease];
  [mainMenu addItem:windowItem];
  NSMenu *windowMenu = [[[NSMenu alloc] initWithTitle:@"Window"] autorelease];
  [windowItem setSubmenu:windowMenu];
  [self addItemWithTitle:@"Minimize"
                  action:@selector(performMiniaturize:)
           keyEquivalent:@"m"
                  toMenu:windowMenu];
  [self addItemWithTitle:@"Zoom"
                  action:@selector(performZoom:)
           keyEquivalent:@""
                  toMenu:windowMenu];
  [NSApp setWindowsMenu:windowMenu];
  [NSApp setMainMenu:mainMenu];
}

- (NSTextField *)labelWithString:(NSString *)string frame:(NSRect)frame {
  NSTextField *label = [[[NSTextField alloc] initWithFrame:frame] autorelease];
  [label setStringValue:string];
  [label setBezeled:NO];
  [label setDrawsBackground:NO];
  [label setEditable:NO];
  [label setSelectable:NO];
  [label setFont:[NSFont systemFontOfSize:12 weight:NSFontWeightSemibold]];
  return label;
}

- (NSScrollView *)scrollViewWithTextView:(NSTextView *)textView
                                   frame:(NSRect)frame {
  NSScrollView *scroll =
      [[[NSScrollView alloc] initWithFrame:frame] autorelease];
  [scroll setBorderType:NSBezelBorder];
  [scroll setHasVerticalScroller:YES];
  [scroll setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
  [textView setMinSize:NSMakeSize(0, frame.size.height)];
  [textView setMaxSize:NSMakeSize(FLT_MAX, FLT_MAX)];
  [textView setVerticallyResizable:YES];
  [textView setHorizontallyResizable:NO];
  [textView setAutoresizingMask:NSViewWidthSizable];
  [[textView textContainer] setContainerSize:NSMakeSize(frame.size.width, FLT_MAX)];
  [[textView textContainer] setWidthTracksTextView:YES];
  [scroll setDocumentView:textView];
  return scroll;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
  [self installMainMenu];

  _window = [[NSWindow alloc]
      initWithContentRect:NSMakeRect(120, 120, 920, 720)
                styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                          NSWindowStyleMaskResizable |
                          NSWindowStyleMaskMiniaturizable
                  backing:NSBackingStoreBuffered
                    defer:NO];
  [_window setTitle:@"DKST IME Tester"];
  NSView *content = [_window contentView];

  NSTextField *title =
      [self labelWithString:@"DKST IME 회귀 테스트 벤치"
                      frame:NSMakeRect(20, 680, 420, 22)];
  [title setFont:[NSFont systemFontOfSize:18 weight:NSFontWeightBold]];
  [content addSubview:title];

  _cpuField = [[NSTextField alloc] initWithFrame:NSMakeRect(460, 680, 170, 22)];
  [_cpuField setStringValue:@"DKST CPU: --"];
  [_cpuField setBezeled:NO];
  [_cpuField setDrawsBackground:NO];
  [_cpuField setEditable:NO];
  [_cpuField setSelectable:YES];
  [_cpuField setAlignment:NSTextAlignmentRight];
  [content addSubview:_cpuField];

  NSButton *copyBundle =
      [[[NSButton alloc] initWithFrame:NSMakeRect(650, 680, 250, 28)] autorelease];
  [copyBundle setTitle:@"Copy tester bundle ID"];
  [copyBundle setButtonType:NSButtonTypeMomentaryPushIn];
  [copyBundle setBezelStyle:NSBezelStyleRounded];
  [copyBundle setTarget:self];
  [copyBundle setAction:@selector(copyBundleID:)];
  [content addSubview:copyBundle];

  [content addSubview:[self labelWithString:@"자동 테스트 문구"
                                      frame:NSMakeRect(20, 642, 140, 18)]];
  _sampleField =
      [[NSTextField alloc] initWithFrame:NSMakeRect(160, 636, 740, 28)];
  [_sampleField setStringValue:
                    @"gksrmfdlqfur, dkssudgktpdy, rkskekfk, dkslqslek"];
  [content addSubview:_sampleField];

  [content addSubview:[self labelWithString:@"NSTextField"
                                      frame:NSMakeRect(20, 602, 120, 18)]];
  _singleLineField =
      [[NSTextField alloc] initWithFrame:NSMakeRect(20, 574, 260, 28)];
  [content addSubview:_singleLineField];

  [content addSubview:[self labelWithString:@"NSSecureTextField"
                                      frame:NSMakeRect(300, 602, 160, 18)]];
  _secureField =
      [[NSSecureTextField alloc] initWithFrame:NSMakeRect(300, 574, 260, 28)];
  [content addSubview:_secureField];

  [content addSubview:[self labelWithString:@"NSSearchField"
                                      frame:NSMakeRect(580, 602, 140, 18)]];
  _searchField =
      [[NSSearchField alloc] initWithFrame:NSMakeRect(580, 574, 320, 28)];
  [content addSubview:_searchField];

  [content addSubview:[self labelWithString:@"NSComboBox"
                                      frame:NSMakeRect(20, 540, 120, 18)]];
  _comboBox = [[NSComboBox alloc] initWithFrame:NSMakeRect(20, 512, 260, 28)];
  [_comboBox addItemsWithObjectValues:
                 [NSArray arrayWithObjects:@"한글입력", @"안녕하세요", nil]];
  [content addSubview:_comboBox];

  [content addSubview:[self labelWithString:@"NSTokenField"
                                      frame:NSMakeRect(300, 540, 120, 18)]];
  _tokenField = [[NSTokenField alloc] initWithFrame:NSMakeRect(300, 512, 260, 28)];
  [content addSubview:_tokenField];

  [content addSubview:[self labelWithString:@"Logging NSTextView"
                                      frame:NSMakeRect(20, 480, 220, 18)]];
  _loggingTextView =
      [[DKSTLoggingTextView alloc] initWithFrame:NSMakeRect(0, 0, 400, 180)];
  [_loggingTextView setFont:[NSFont systemFontOfSize:22]];
  [content addSubview:[self scrollViewWithTextView:_loggingTextView
                                             frame:NSMakeRect(20, 280, 400, 190)]];

  [content addSubview:[self labelWithString:@"Plain NSTextView"
                                      frame:NSMakeRect(460, 480, 180, 18)]];
  _plainTextView = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 400, 180)];
  [_plainTextView setFont:[NSFont systemFontOfSize:22]];
  [content addSubview:[self scrollViewWithTextView:_plainTextView
                                             frame:NSMakeRect(460, 280, 400, 190)]];

  [content addSubview:[self labelWithString:@"WKWebView contenteditable"
                                      frame:NSMakeRect(20, 244, 240, 18)]];
  WKWebViewConfiguration *config =
      [[[WKWebViewConfiguration alloc] init] autorelease];
  _webView = [[WKWebView alloc] initWithFrame:NSMakeRect(20, 100, 400, 136)
                               configuration:config];
  [_webView setNavigationDelegate:self];
  [_webView loadHTMLString:
                @"<!doctype html><meta charset='utf-8'>"
                 "<style>body{font:22px -apple-system;margin:12px}"
                 "#e{border:1px solid #aaa;min-height:90px;padding:8px}</style>"
                 "<div id='e' contenteditable='true'></div>"
                 "<script>setTimeout(()=>document.getElementById('e').focus(),300);</script>"
                   baseURL:nil];
  [content addSubview:_webView];

  [content addSubview:[self labelWithString:@"이벤트 로그"
                                      frame:NSMakeRect(460, 244, 120, 18)]];
  DKSTLogView = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 400, 120)];
  [DKSTLogView setEditable:NO];
  [DKSTLogView setFont:[NSFont monospacedSystemFontOfSize:11
                                                   weight:NSFontWeightRegular]];
  [content addSubview:[self scrollViewWithTextView:DKSTLogView
                                             frame:NSMakeRect(460, 100, 400, 136)]];

  NSButton *clear =
      [[[NSButton alloc] initWithFrame:NSMakeRect(20, 52, 110, 28)] autorelease];
  [clear setTitle:@"Clear All"];
  [clear setButtonType:NSButtonTypeMomentaryPushIn];
  [clear setBezelStyle:NSBezelStyleRounded];
  [clear setTarget:self];
  [clear setAction:@selector(clearAll:)];
  [content addSubview:clear];

  _autoRunButton =
      [[NSButton alloc] initWithFrame:NSMakeRect(145, 52, 145, 28)];
  [_autoRunButton setTitle:@"Run Auto Typing"];
  [_autoRunButton setButtonType:NSButtonTypeMomentaryPushIn];
  [_autoRunButton setBezelStyle:NSBezelStyleRounded];
  [_autoRunButton setTarget:self];
  [_autoRunButton setAction:@selector(runAutoTyping:)];
  [content addSubview:_autoRunButton];

  _stopButton = [[NSButton alloc] initWithFrame:NSMakeRect(305, 52, 90, 28)];
  [_stopButton setTitle:@"Stop"];
  [_stopButton setButtonType:NSButtonTypeMomentaryPushIn];
  [_stopButton setBezelStyle:NSBezelStyleRounded];
  [_stopButton setTarget:self];
  [_stopButton setAction:@selector(stopAutoTyping:)];
  [_stopButton setEnabled:NO];
  [content addSubview:_stopButton];

  [content addSubview:[self labelWithString:@"반복"
                                      frame:NSMakeRect(410, 58, 34, 18)]];
  _repeatField = [[NSTextField alloc] initWithFrame:NSMakeRect(447, 52, 52, 28)];
  [_repeatField setStringValue:@"1"];
  [_repeatField setAlignment:NSTextAlignmentRight];
  [content addSubview:_repeatField];

  _autoStatusField =
      [[NSTextField alloc] initWithFrame:NSMakeRect(515, 52, 345, 28)];
  [_autoStatusField setStringValue:@"자동 타이핑 대기 중"];
  [_autoStatusField setBezeled:NO];
  [_autoStatusField setDrawsBackground:NO];
  [_autoStatusField setEditable:NO];
  [_autoStatusField setSelectable:YES];
  [content addSubview:_autoStatusField];

  [_window makeKeyAndOrderFront:nil];
  [NSApp activateIgnoringOtherApps:YES];
  [self startCPUMonitoring];
}

- (void)dealloc {
  [_cpuTimer invalidate];
  [_sampleField release];
  [_cpuField release];
  [_singleLineField release];
  [_secureField release];
  [_searchField release];
  [_comboBox release];
  [_tokenField release];
  [_loggingTextView release];
  [_plainTextView release];
  [_webView release];
  [_autoRunButton release];
  [_stopButton release];
  [_repeatField release];
  [_autoStatusField release];
  [_autoSamples release];
  [_window release];
  [super dealloc];
}

- (void)copyBundleID:(id)sender {
  [[NSPasteboard generalPasteboard] clearContents];
  [[NSPasteboard generalPasteboard] setString:DKSTIMETesterBundleID
                                      forType:NSPasteboardTypeString];
  DKSTAppendLog(@"Copied bundle ID: %@", DKSTIMETesterBundleID);
}

- (void)startCPUMonitoring {
  [self updateDKSTCPU:nil];
  _cpuTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                              target:self
                                            selector:@selector(updateDKSTCPU:)
                                            userInfo:nil
                                             repeats:YES];
}

- (void)updateDKSTCPU:(NSTimer *)timer {
  NSArray *apps = [NSRunningApplication
      runningApplicationsWithBundleIdentifier:DKSTInputMethodBundleID];
  if ([apps count] == 0) {
    [_cpuField setStringValue:@"DKST CPU: not running"];
    return;
  }

  pid_t pid = [[apps objectAtIndex:0] processIdentifier];
  NSTask *task = [[[NSTask alloc] init] autorelease];
  NSPipe *pipe = [NSPipe pipe];
  [task setLaunchPath:@"/bin/ps"];
  [task setArguments:[NSArray arrayWithObjects:@"-p",
                                               [NSString stringWithFormat:@"%d", pid],
                                               @"-o", @"%cpu=", nil]];
  [task setStandardOutput:pipe];
  @try {
    [task launch];
    [task waitUntilExit];
    NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
    NSString *output =
        [[[NSString alloc] initWithData:data
                               encoding:NSUTF8StringEncoding] autorelease];
    NSString *cpu = [output
        stringByTrimmingCharactersInSet:
            [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    [_cpuField setStringValue:
                   [NSString stringWithFormat:@"DKST CPU: %@%%", cpu ?: @"--"]];
  } @catch (NSException *exception) {
    [_cpuField setStringValue:@"DKST CPU: --"];
  }
}

- (void)clearAll:(id)sender {
  [_singleLineField setStringValue:@""];
  [_secureField setStringValue:@""];
  [_searchField setStringValue:@""];
  [_comboBox setStringValue:@""];
  [_tokenField setStringValue:@""];
  [_loggingTextView setString:@""];
  [_plainTextView setString:@""];
  [DKSTLogView setString:@""];
  [_webView evaluateJavaScript:@"document.getElementById('e').innerText='';"
             completionHandler:nil];
}

- (BOOL)ensureAccessibilityPermission {
  NSDictionary *options =
      [NSDictionary dictionaryWithObject:(id)kCFBooleanTrue
                                  forKey:(id)kAXTrustedCheckOptionPrompt];
  BOOL trusted = AXIsProcessTrustedWithOptions((CFDictionaryRef)options);
  if (!trusted) {
    DKSTAppendLog(@"자동 타이핑에는 Accessibility 권한이 필요합니다.");
    [_autoStatusField setStringValue:
                          @"시스템 설정 > 개인정보 보호 및 보안 > 손쉬운 사용에서 IMETester 허용"];
  }
  return trusted;
}

- (NSArray *)autoSamples {
  if (_autoSamples) return _autoSamples;

  NSArray *parts = [[_sampleField stringValue] componentsSeparatedByString:@","];
  NSMutableArray *samples = [NSMutableArray array];
  NSCharacterSet *trimSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
  for (NSString *part in parts) {
    NSString *sample = [part stringByTrimmingCharactersInSet:trimSet];
    if ([sample length] > 0) [samples addObject:sample];
  }
  if ([samples count] == 0) {
    [samples addObjectsFromArray:
                 [NSArray arrayWithObjects:@"gksrmfdlqfur",
                                           @"dkssudgktpdy",
                                           @"rkskekfk",
                                           @"dkslqslek",
                                           nil]];
  }
  _autoSamples = [samples copy];
  return _autoSamples;
}

- (NSString *)expectedHangulForSample:(NSString *)sample {
  DKSTHangul *engine = [[[DKSTHangul alloc] init] autorelease];
  NSMutableString *result = [NSMutableString string];
  for (NSUInteger index = 0; index < [sample length]; index++) {
    CGKeyCode keyCode = 0;
    if (!DKSTKeyCodeForCharacter([sample characterAtIndex:index], &keyCode)) {
      continue;
    }
    [engine processCode:keyCode modifiers:0];
    NSString *commit = [engine commitString];
    if ([commit length] > 0) [result appendString:commit];
  }
  NSString *commit = [engine commitString];
  NSString *composed = [engine composedString];
  if ([commit length] > 0) [result appendString:commit];
  if ([composed length] > 0) [result appendString:composed];
  return result;
}

- (NSString *)expectedAutoText {
  NSMutableArray *converted = [NSMutableArray array];
  for (NSString *sample in [self autoSamples]) {
    [converted addObject:[self expectedHangulForSample:sample]];
  }
  return [[converted componentsJoinedByString:@" "] stringByAppendingString:@" "];
}

- (NSInteger)requestedRepeatCount {
  NSInteger count = [_repeatField integerValue];
  if (count < 1) count = 1;
  if (count > 999) count = 999;
  [_repeatField setIntegerValue:count];
  return count;
}

- (NSString *)autoTargetName {
  switch (_autoTargetIndex) {
  case 0: return @"NSTextField";
  case 1: return @"NSSecureTextField";
  case 2: return @"NSSearchField";
  case 3: return @"NSComboBox";
  case 4: return @"NSTokenField";
  case 5: return @"Logging NSTextView";
  case 6: return @"Plain NSTextView";
  case 7: return @"WKWebView";
  default: return @"Unknown";
  }
}

- (void)focusAutoTarget {
  [_window makeKeyAndOrderFront:nil];
  [NSApp activateIgnoringOtherApps:YES];

  switch (_autoTargetIndex) {
  case 0: [_window makeFirstResponder:_singleLineField]; break;
  case 1: [_window makeFirstResponder:_secureField]; break;
  case 2: [_window makeFirstResponder:_searchField]; break;
  case 3: [_window makeFirstResponder:_comboBox]; break;
  case 4: [_window makeFirstResponder:_tokenField]; break;
  case 5: [_window makeFirstResponder:_loggingTextView]; break;
  case 6: [_window makeFirstResponder:_plainTextView]; break;
  case 7:
    [_window makeFirstResponder:_webView];
    [_webView evaluateJavaScript:@"document.getElementById('e').focus();"
               completionHandler:nil];
    break;
  default: break;
  }
}

- (void)postKeyCode:(CGKeyCode)keyCode {
  CGEventRef keyDown = CGEventCreateKeyboardEvent(NULL, keyCode, true);
  CGEventRef keyUp = CGEventCreateKeyboardEvent(NULL, keyCode, false);
  CGEventPost(kCGHIDEventTap, keyDown);
  CGEventPost(kCGHIDEventTap, keyUp);
  CFRelease(keyDown);
  CFRelease(keyUp);
}

- (void)typeNextAutoCharacter {
  if (!_autoRunning) return;

  NSArray *samples = [self autoSamples];
  if (_autoTargetIndex >= 8) {
    [self reportAutoTypingResults];
    _autoRepeatIndex++;
    if (_autoRepeatIndex < _autoRepeatCount) {
      [self clearAll:nil];
      _autoTargetIndex = 0;
      _autoSampleIndex = 0;
      _autoCharacterIndex = 0;
      DKSTAppendLog(@"Auto typing pass %ld/%ld started",
                    (long)(_autoRepeatIndex + 1),
                    (long)_autoRepeatCount);
      [self focusAutoTarget];
      [self performSelector:@selector(typeNextAutoCharacter)
                 withObject:nil
                 afterDelay:0.45];
      return;
    }

    _autoRunning = NO;
    [_autoRunButton setEnabled:YES];
    [_stopButton setEnabled:NO];
    [_autoStatusField setStringValue:@"자동 타이핑 완료"];
    DKSTAppendLog(@"Auto typing finished: %ld pass(es)",
                  (long)_autoRepeatCount);
    return;
  }

  if (_autoSampleIndex >= [samples count]) {
    _autoTargetIndex++;
    _autoSampleIndex = 0;
    _autoCharacterIndex = 0;
    if (_autoTargetIndex >= 8) {
      [self typeNextAutoCharacter];
      return;
    }
    [self focusAutoTarget];
    [_autoStatusField
        setStringValue:[NSString stringWithFormat:@"포커스 전환: %@",
                                                   [self autoTargetName]]];
    [self performSelector:@selector(typeNextAutoCharacter)
               withObject:nil
               afterDelay:0.45];
    return;
  }

  NSString *sample = [samples objectAtIndex:_autoSampleIndex];
  if (_autoCharacterIndex == 0) {
    DKSTAppendLog(@"Auto typing pass %ld/%ld %@: %@",
                  (long)(_autoRepeatIndex + 1),
                  (long)_autoRepeatCount, [self autoTargetName], sample);
    [_autoStatusField
        setStringValue:[NSString stringWithFormat:@"%ld/%ld %@ 입력 중: %@",
                                                   (long)(_autoRepeatIndex + 1),
                                                   (long)_autoRepeatCount,
                                                   [self autoTargetName],
                                                   sample]];
  }

  if (_autoCharacterIndex < [sample length]) {
    CGKeyCode keyCode = 0;
    unichar character = [sample characterAtIndex:_autoCharacterIndex];
    if (DKSTKeyCodeForCharacter(character, &keyCode)) [self postKeyCode:keyCode];
    _autoCharacterIndex++;
    [self performSelector:@selector(typeNextAutoCharacter)
               withObject:nil
               afterDelay:0.045];
    return;
  }

  CGKeyCode delimiter = 0;
  if (DKSTKeyCodeForCharacter(' ', &delimiter)) [self postKeyCode:delimiter];
  _autoSampleIndex++;
  _autoCharacterIndex = 0;
  [self performSelector:@selector(typeNextAutoCharacter)
             withObject:nil
             afterDelay:0.18];
}

- (NSString *)normalizedResultText:(NSString *)text {
  NSString *normalized =
      [text stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
  while ([normalized rangeOfString:@"  "].location != NSNotFound) {
    normalized = [normalized stringByReplacingOccurrencesOfString:@"  "
                                                       withString:@" "];
  }
  return [normalized
      stringByTrimmingCharactersInSet:
          [NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (void)logFailureDetailsForText:(NSString *)actual
                         expected:(NSString *)expected
                           target:(NSString *)target {
  NSUInteger sharedLength = MIN([actual length], [expected length]);
  for (NSUInteger index = 0; index < sharedLength; index++) {
    unichar actualChar = [actual characterAtIndex:index];
    unichar expectedChar = [expected characterAtIndex:index];
    if (actualChar != expectedChar) {
      DKSTAppendLog(@"FAIL %@ mismatch at %lu: expected '%C', got '%C'",
                    target, (unsigned long)index, expectedChar, actualChar);
      return;
    }
  }
  if ([actual length] != [expected length]) {
    DKSTAppendLog(@"FAIL %@ length mismatch: expected %lu, got %lu",
                  target, (unsigned long)[expected length],
                  (unsigned long)[actual length]);
  }
}

- (void)logSuspiciousCharactersInText:(NSString *)text target:(NSString *)target {
  for (NSUInteger index = 0; index < [text length]; index++) {
    unichar c = [text characterAtIndex:index];
    if ((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') ||
        (c >= 0x3130 && c <= 0x318F)) {
      DKSTAppendLog(@"FAIL %@ suspicious char at %lu: '%C' U+%04X",
                    target, (unsigned long)index, c, c);
    }
  }
}

- (void)reportText:(NSString *)text
         forTarget:(NSString *)target
          expected:(NSString *)expected {
  NSString *actual = [self normalizedResultText:text ?: @""];
  NSString *normalizedExpected = [self normalizedResultText:expected ?: @""];
  BOOL suspicious = DKSTTextContainsRomanOrIsolatedJamo(actual);
  BOOL mismatch = ![actual isEqualToString:normalizedExpected];
  if (suspicious || mismatch) {
    DKSTAppendLog(@"WARN pass %ld %@ expected='%@' actual='%@'",
                  (long)(_autoRepeatIndex + 1), target,
                  normalizedExpected, actual);
    if (mismatch) {
      [self logFailureDetailsForText:actual
                            expected:normalizedExpected
                              target:target];
    }
    if (suspicious) {
      [self logSuspiciousCharactersInText:actual target:target];
    }
  } else {
    DKSTAppendLog(@"OK pass %ld %@: '%@'",
                  (long)(_autoRepeatIndex + 1), target, actual);
  }
}

- (void)reportAutoTypingResults {
  NSString *expected = [self expectedAutoText];
  [self reportText:[_singleLineField stringValue]
         forTarget:@"NSTextField"
          expected:expected];
  DKSTAppendLog(@"INFO pass %ld NSSecureTextField skipped result comparison",
                (long)(_autoRepeatIndex + 1));
  [self reportText:[_searchField stringValue]
         forTarget:@"NSSearchField"
          expected:expected];
  [self reportText:[_comboBox stringValue]
         forTarget:@"NSComboBox"
          expected:expected];
  [self reportText:[_tokenField stringValue]
         forTarget:@"NSTokenField"
          expected:expected];
  [self reportText:[_loggingTextView string]
         forTarget:@"Logging NSTextView"
          expected:expected];
  [self reportText:[_plainTextView string]
         forTarget:@"Plain NSTextView"
          expected:expected];
  [_webView evaluateJavaScript:@"document.getElementById('e').innerText"
             completionHandler:^(id result, NSError *error) {
               if (error) {
                 DKSTAppendLog(@"WARN WKWebView result read failed: %@", error);
                 return;
               }
               [self reportText:[result description]
                       forTarget:@"WKWebView"
                        expected:expected];
             }];
}

- (void)runAutoTyping:(id)sender {
  if (_autoRunning) return;
  if (![self ensureAccessibilityPermission]) return;

  [_autoSamples release];
  _autoSamples = nil;
  [self clearAll:nil];
  _autoRunning = YES;
  _autoRepeatCount = [self requestedRepeatCount];
  _autoRepeatIndex = 0;
  _autoTargetIndex = 0;
  _autoSampleIndex = 0;
  _autoCharacterIndex = 0;
  [_autoRunButton setEnabled:NO];
  [_stopButton setEnabled:YES];
  DKSTAppendLog(@"Auto typing pass 1/%ld started", (long)_autoRepeatCount);
  [self focusAutoTarget];
  [self performSelector:@selector(typeNextAutoCharacter)
             withObject:nil
             afterDelay:0.45];
}

- (void)stopAutoTyping:(id)sender {
  if (!_autoRunning) return;
  _autoRunning = NO;
  [_autoRunButton setEnabled:YES];
  [_stopButton setEnabled:NO];
  [_autoStatusField setStringValue:@"자동 타이핑 중단"];
  DKSTAppendLog(@"Auto typing stopped at pass %ld/%ld target %@",
                (long)(_autoRepeatIndex + 1),
                (long)_autoRepeatCount,
                [self autoTargetName]);
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
  return YES;
}

@end

int main(int argc, const char *argv[]) {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  [NSApplication sharedApplication];
  DKSTTesterDelegate *delegate = [[[DKSTTesterDelegate alloc] init] autorelease];
  [NSApp setDelegate:delegate];
  [NSApp run];
  [pool drain];
  return 0;
}
