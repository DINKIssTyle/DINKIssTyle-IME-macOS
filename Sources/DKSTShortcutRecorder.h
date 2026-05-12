#import <Cocoa/Cocoa.h>

/**
 * DKSTShortcutRecorder — Native macOS-style shortcut recorder view.
 *
 * Click to start recording, press a key combination to set the shortcut.
 * Displays the shortcut using standard macOS modifier symbols (⌘, ⌥, ⇧, ⌃).
 * Includes a clear (x) button to reset the shortcut to default.
 *
 * Special keys (F1–F12, arrows, Home, End, Page Up/Down, etc.) can be
 * registered without a modifier key.
 */

@class DKSTShortcutRecorder;

@protocol DKSTShortcutRecorderDelegate <NSObject>
@optional
- (void)shortcutRecorder:(DKSTShortcutRecorder *)recorder
       didRecordKeyCode:(unsigned short)keyCode
              modifiers:(NSUInteger)modifiers;
- (void)shortcutRecorderDidClear:(DKSTShortcutRecorder *)recorder;
@end

@interface DKSTShortcutRecorder : NSView {
    unsigned short _keyCode;
    NSUInteger _modifierFlags;
    BOOL _isRecording;
    BOOL _isHovering;
    BOOL _isHoveringClear;
    BOOL _hasShortcut;
    NSTrackingArea *_trackingArea;
    id _localMonitor;
    id<DKSTShortcutRecorderDelegate> _delegate;
}

@property (nonatomic, assign) id<DKSTShortcutRecorderDelegate> delegate;
@property (nonatomic, readonly) unsigned short keyCode;
@property (nonatomic, readonly) NSUInteger modifierFlags;
@property (nonatomic, readonly) BOOL hasShortcut;

- (void)setShortcutWithKeyCode:(unsigned short)keyCode
                     modifiers:(NSUInteger)modifiers;
- (void)clearShortcut;

/** Returns a human-readable display string for the current shortcut. */
- (NSString *)displayString;

/** Returns a display string for any keyCode + modifiers combination. */
+ (NSString *)displayStringForKeyCode:(unsigned short)keyCode
                            modifiers:(NSUInteger)modifiers;

@end
