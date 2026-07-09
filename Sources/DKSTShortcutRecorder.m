#import "DKSTShortcutRecorder.h"
#import "DKSTKeyMap.h"
#import <Carbon/Carbon.h>

// Context Menu key (PC keyboards) — not defined in Carbon headers
enum { kDKST_VK_ContextMenu = 0x6E };

// Key codes that are allowed to be registered WITHOUT any modifier.
static BOOL DKSTIsStandaloneAllowedKeyCode(unsigned short keyCode) {
    switch (keyCode) {
        // F1–F20
        case kVK_F1:  case kVK_F2:  case kVK_F3:  case kVK_F4:
        case kVK_F5:  case kVK_F6:  case kVK_F7:  case kVK_F8:
        case kVK_F9:  case kVK_F10: case kVK_F11: case kVK_F12:
        case kVK_F13: case kVK_F14: case kVK_F15: case kVK_F16:
        case kVK_F17: case kVK_F18: case kVK_F19: case kVK_F20:
        // Navigation keys
        case kVK_Home:
        case kVK_End:
        case kVK_PageUp:
        case kVK_PageDown:
        case kVK_LeftArrow:
        case kVK_RightArrow:
        case kVK_UpArrow:
        case kVK_DownArrow:
        case kVK_ForwardDelete:
        case kVK_Help:            // Insert key (PC keyboards)
        case kDKST_VK_ContextMenu: // Context Menu key (PC keyboards)
        // JIS Hanja / Kana keys
        case kVK_JIS_Eisu:    // 英数 (102)
        case kVK_JIS_Kana:    // かな (104)
            return YES;
        default:
            return NO;
    }
}

/**
 * Returns a human-readable key name for a given virtual key code using
 * Carbon APIs (UCKeyTranslate) and hardcoded fallbacks for special keys.
 */
static NSString *DKSTKeyNameForKeyCode(unsigned short keyCode) {
    // Hardcoded names for special / non-printable keys
    switch (keyCode) {
        case kVK_Return:        return @"↩";
        case kVK_Tab:           return @"⇥";
        case kVK_Space:         return @"Space";
        case kVK_Delete:        return @"⌫";
        case kVK_ForwardDelete: return @"⌦";
        case kVK_Escape:        return @"⎋";
        case kVK_Home:          return @"↖";
        case kVK_End:           return @"↘";
        case kVK_PageUp:        return @"⇞";
        case kVK_PageDown:      return @"⇟";
        case kVK_LeftArrow:     return @"←";
        case kVK_RightArrow:    return @"→";
        case kVK_UpArrow:       return @"↑";
        case kVK_DownArrow:     return @"↓";
        case kVK_F1:  return @"F1";
        case kVK_F2:  return @"F2";
        case kVK_F3:  return @"F3";
        case kVK_F4:  return @"F4";
        case kVK_F5:  return @"F5";
        case kVK_F6:  return @"F6";
        case kVK_F7:  return @"F7";
        case kVK_F8:  return @"F8";
        case kVK_F9:  return @"F9";
        case kVK_F10: return @"F10";
        case kVK_F11: return @"F11";
        case kVK_F12: return @"F12";
        case kVK_F13: return @"F13";
        case kVK_F14: return @"F14";
        case kVK_F15: return @"F15";
        case kVK_F16: return @"F16";
        case kVK_F17: return @"F17";
        case kVK_F18: return @"F18";
        case kVK_F19: return @"F19";
        case kVK_F20: return @"F20";
        case kVK_JIS_Eisu: return @"英数";
        case kVK_JIS_Kana: return @"かな";
        case kVK_Help:     return @"Insert";
        case kDKST_VK_ContextMenu: return @"Menu";
        // Modifier keys (standalone)
        case kVK_RightControl: return @"Right Control";
        case kVK_Control:      return @"Left Control";
        case kVK_RightShift:   return @"Right Shift";
        case kVK_Shift:        return @"Left Shift";
        case kVK_RightOption:  return @"Right Option";
        case kVK_Option:       return @"Left Option";
        case kVK_RightCommand: return @"Right Command";
        case kVK_Command:      return @"Left Command";
        default:
            break;
    }

    // Use Carbon UCKeyTranslate to resolve printable characters
    TISInputSourceRef currentKeyboard =
        TISCopyCurrentKeyboardLayoutInputSource();
    if (!currentKeyboard) {
        return [NSString stringWithFormat:@"Key(%d)", keyCode];
    }

    CFDataRef layoutData = (CFDataRef)TISGetInputSourceProperty(
        currentKeyboard, kTISPropertyUnicodeKeyLayoutData);
    if (!layoutData) {
        CFRelease(currentKeyboard);
        return [NSString stringWithFormat:@"Key(%d)", keyCode];
    }

    const UCKeyboardLayout *keyboardLayout =
        (const UCKeyboardLayout *)CFDataGetBytePtr(layoutData);

    UInt32 deadKeyState = 0;
    UniChar chars[4] = {0};
    UniCharCount actualLength = 0;

    OSStatus status = UCKeyTranslate(
        keyboardLayout,
        keyCode,
        kUCKeyActionDisplay,
        0, // No modifiers for display name
        LMGetKbdType(),
        kUCKeyTranslateNoDeadKeysBit,
        &deadKeyState,
        sizeof(chars) / sizeof(chars[0]),
        &actualLength,
        chars);

    CFRelease(currentKeyboard);

    if (status == noErr && actualLength > 0) {
        NSString *result =
            [[NSString stringWithCharacters:chars length:actualLength]
                uppercaseString];
        if ([result length] > 0) {
            return result;
        }
    }

    return [NSString stringWithFormat:@"Key(%d)", keyCode];
}

@implementation DKSTShortcutRecorder

@synthesize delegate = _delegate;
@synthesize keyCode = _keyCode;
@synthesize modifierFlags = _modifierFlags;
@synthesize hasShortcut = _hasShortcut;

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        _keyCode = 0;
        _modifierFlags = 0;
        _isRecording = NO;
        _isHovering = NO;
        _isHoveringClear = NO;
        _hasShortcut = NO;
        _localMonitor = nil;
    }
    return self;
}

- (void)dealloc {
    [self stopRecording];
    if (_trackingArea) {
        [self removeTrackingArea:_trackingArea];
        [_trackingArea release];
        _trackingArea = nil;
    }
    [super dealloc];
}

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (BOOL)isFlipped {
    return YES;
}

// MARK: - Public API

- (void)setShortcutWithKeyCode:(unsigned short)keyCode
                     modifiers:(NSUInteger)modifiers {
    _keyCode = keyCode;
    _modifierFlags = modifiers;
    _hasShortcut = YES;
    [self setNeedsDisplay:YES];
}

- (void)clearShortcut {
    _keyCode = 0;
    _modifierFlags = 0;
    _hasShortcut = NO;
    [self setNeedsDisplay:YES];
    if ([_delegate respondsToSelector:@selector(shortcutRecorderDidClear:)]) {
        [_delegate shortcutRecorderDidClear:self];
    }
}

- (NSString *)displayString {
    if (!_hasShortcut) {
        return @"";
    }
    return [DKSTShortcutRecorder displayStringForKeyCode:_keyCode
                                              modifiers:_modifierFlags];
}

+ (NSString *)displayStringForKeyCode:(unsigned short)keyCode
                            modifiers:(NSUInteger)modifiers {
    NSMutableString *display = [NSMutableString string];

    if (modifiers & NSEventModifierFlagControl) {
        [display appendString:@"⌃"];
    }
    if (modifiers & NSEventModifierFlagOption) {
        [display appendString:@"⌥"];
    }
    if (modifiers & NSEventModifierFlagShift) {
        [display appendString:@"⇧"];
    }
    if (modifiers & NSEventModifierFlagCommand) {
        [display appendString:@"⌘"];
    }

    [display appendString:DKSTKeyNameForKeyCode(keyCode)];
    return display;
}

// MARK: - Tracking Area

- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    if (_trackingArea) {
        [self removeTrackingArea:_trackingArea];
        [_trackingArea release];
    }
    _trackingArea = [[NSTrackingArea alloc]
        initWithRect:[self bounds]
             options:(NSTrackingMouseEnteredAndExited |
                      NSTrackingMouseMoved |
                      NSTrackingActiveAlways)
               owner:self
            userInfo:nil];
    [self addTrackingArea:_trackingArea];
}

- (void)mouseEntered:(NSEvent *)event {
    _isHovering = YES;
    [self setNeedsDisplay:YES];
}

- (void)mouseExited:(NSEvent *)event {
    _isHovering = NO;
    _isHoveringClear = NO;
    [self setNeedsDisplay:YES];
}

- (void)mouseMoved:(NSEvent *)event {
    NSPoint local = [self convertPoint:[event locationInWindow] fromView:nil];
    NSRect clearRect = [self clearButtonRect];
    BOOL inClear = NSPointInRect(local, clearRect);
    if (inClear != _isHoveringClear) {
        _isHoveringClear = inClear;
        [self setNeedsDisplay:YES];
    }
}

// MARK: - Mouse Events

- (void)mouseDown:(NSEvent *)event {
    NSPoint local = [self convertPoint:[event locationInWindow] fromView:nil];
    NSRect clearRect = [self clearButtonRect];

    // Click on the 'x' clear button
    if (_hasShortcut && !_isRecording && NSPointInRect(local, clearRect)) {
        [self clearShortcut];
        return;
    }

    // Toggle recording
    if (_isRecording) {
        [self stopRecording];
    } else {
        [self startRecording];
    }
}

// MARK: - Recording

- (void)startRecording {
    _isRecording = YES;
    [self setNeedsDisplay:YES];

    // Use a local event monitor to capture key events
    __block DKSTShortcutRecorder *weakSelf = self;
    _localMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:
        (NSEventMaskKeyDown | NSEventMaskFlagsChanged)
        handler:^NSEvent *(NSEvent *event) {
            DKSTShortcutRecorder *strongSelf = weakSelf;
            if (!strongSelf || !strongSelf->_isRecording) {
                return event;
            }

            // Handle modifier-only keys via FlagsChanged
            if ([event type] == NSEventTypeFlagsChanged) {
                unsigned short keyCode = [event keyCode];
                if (DKSTIsModifierKeyCode(keyCode)) {
                    NSUInteger flags = [event modifierFlags] &
                        (NSEventModifierFlagCommand | NSEventModifierFlagControl |
                         NSEventModifierFlagOption | NSEventModifierFlagShift);
                    
                    if (DKSTModifierKeyIsPress(keyCode, flags)) {
                        // Modifier pressed: Update current shortcut state but don't stop yet
                        strongSelf->_keyCode = keyCode;
                        strongSelf->_modifierFlags = flags & ~DKSTModifierMaskForKeyCode(keyCode);
                        strongSelf->_hasShortcut = YES;
                        [strongSelf setNeedsDisplay:YES];
                    } else {
                        // Modifier released: If all modifiers are released, commit the last one
                        if (flags == 0 && strongSelf->_hasShortcut) {
                            [strongSelf stopRecording];
                            if ([strongSelf->_delegate respondsToSelector:
                                    @selector(shortcutRecorder:didRecordKeyCode:modifiers:)]) {
                                [strongSelf->_delegate
                                    shortcutRecorder:strongSelf
                                    didRecordKeyCode:strongSelf->_keyCode
                                           modifiers:strongSelf->_modifierFlags];
                            }
                        }
                    }
                    return nil; // Consume modifier changes during recording
                }
                return event;
            }

            if ([event type] == NSEventTypeKeyDown) {
                unsigned short keyCode = [event keyCode];
                NSUInteger modifiers =
                    [event modifierFlags] &
                    (NSEventModifierFlagCommand | NSEventModifierFlagControl |
                     NSEventModifierFlagOption | NSEventModifierFlagShift);

                // Escape cancels recording
                if (keyCode == kVK_Escape && modifiers == 0) {
                    [strongSelf stopRecording];
                    return nil;
                }

                // Validate: modifiers required for regular keys,
                // special keys can be standalone
                BOOL hasModifiers = (modifiers != 0);
                BOOL isStandaloneAllowed =
                    DKSTIsStandaloneAllowedKeyCode(keyCode);

                if (!hasModifiers && !isStandaloneAllowed) {
                    // Ignore: normal key without modifiers
                    return nil;
                }

                // Accept this shortcut
                strongSelf->_keyCode = keyCode;
                strongSelf->_modifierFlags = modifiers;
                strongSelf->_hasShortcut = YES;
                [strongSelf stopRecording];

                if ([strongSelf->_delegate respondsToSelector:
                        @selector(shortcutRecorder:didRecordKeyCode:modifiers:)]) {
                    [strongSelf->_delegate
                        shortcutRecorder:strongSelf
                        didRecordKeyCode:keyCode
                               modifiers:modifiers];
                }
                return nil; // Swallow the event
            }

            return event;
        }];
}

- (void)stopRecording {
    _isRecording = NO;
    if (_localMonitor) {
        [NSEvent removeMonitor:_localMonitor];
        _localMonitor = nil;
    }
    [self setNeedsDisplay:YES];
}

// MARK: - Layout

- (NSRect)clearButtonRect {
    CGFloat buttonSize = 16.0;
    CGFloat margin = 8.0;
    NSRect bounds = [self bounds];
    return NSMakeRect(
        NSMaxX(bounds) - buttonSize - margin,
        (NSHeight(bounds) - buttonSize) / 2.0,
        buttonSize,
        buttonSize);
}

// MARK: - Drawing

- (void)drawRect:(NSRect)dirtyRect {
    NSRect bounds = [self bounds];

    // Background
    NSColor *bgColor;
    if (_isRecording) {
        bgColor = [NSColor colorWithCalibratedWhite:0.95 alpha:1.0];
    } else if (_isHovering) {
        bgColor = [NSColor colorWithCalibratedWhite:0.97 alpha:1.0];
    } else {
        bgColor = [NSColor controlBackgroundColor];
    }

    NSBezierPath *bgPath =
        [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(bounds, 0.5, 0.5)
                                        xRadius:6.0
                                        yRadius:6.0];
    [bgColor setFill];
    [bgPath fill];

    // Border
    NSColor *borderColor;
    if (_isRecording) {
        borderColor = [NSColor controlAccentColor];
    } else {
        borderColor = [NSColor separatorColor];
    }
    [borderColor setStroke];
    [bgPath setLineWidth:(_isRecording ? 2.0 : 1.0)];
    [bgPath stroke];

    // Text
    NSString *displayText;
    NSColor *textColor;
    NSFont *textFont;

    if (_isRecording) {
        displayText = @"키 입력 대기중...";
        textColor = [NSColor placeholderTextColor];
        textFont = [NSFont systemFontOfSize:12 weight:NSFontWeightRegular];
    } else if (_hasShortcut) {
        displayText = [self displayString];
        textColor = [NSColor labelColor];
        textFont = [NSFont monospacedSystemFontOfSize:13
                                               weight:NSFontWeightMedium];
    } else {
        displayText = @"단축키 없음 (기본: ⌥↩)";
        textColor = [NSColor placeholderTextColor];
        textFont = [NSFont systemFontOfSize:12 weight:NSFontWeightRegular];
    }

    NSDictionary *attrs = @{
        NSFontAttributeName : textFont,
        NSForegroundColorAttributeName : textColor,
    };

    NSSize textSize = [displayText sizeWithAttributes:attrs];
    CGFloat textX = 12.0;
    CGFloat textY = (NSHeight(bounds) - textSize.height) / 2.0;
    [displayText drawAtPoint:NSMakePoint(textX, textY) withAttributes:attrs];

    // Clear button (x)
    if (_hasShortcut && !_isRecording) {
        NSRect clearRect = [self clearButtonRect];
        NSColor *clearColor =
            _isHoveringClear
                ? [NSColor secondaryLabelColor]
                : [NSColor tertiaryLabelColor];

        NSBezierPath *xPath = [NSBezierPath bezierPath];
        CGFloat inset = 4.0;
        [xPath moveToPoint:NSMakePoint(NSMinX(clearRect) + inset,
                                       NSMinY(clearRect) + inset)];
        [xPath lineToPoint:NSMakePoint(NSMaxX(clearRect) - inset,
                                       NSMaxY(clearRect) - inset)];
        [xPath moveToPoint:NSMakePoint(NSMaxX(clearRect) - inset,
                                       NSMinY(clearRect) + inset)];
        [xPath lineToPoint:NSMakePoint(NSMinX(clearRect) + inset,
                                       NSMaxY(clearRect) - inset)];
        [clearColor setStroke];
        [xPath setLineWidth:1.5];
        [xPath setLineCapStyle:NSLineCapStyleRound];
        [xPath stroke];
    }
}

@end
