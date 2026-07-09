#import "InputController.h"

@interface InputController (Private)

- (NSString *)bundleIdentifierForClient:(id)sender;
- (void)forceMarkedTextForClient:(id)sender reason:(NSString *)reason;
- (BOOL)bundleIdentifier:(NSString *)bundleID
          matchesPattern:(NSString *)pattern;
- (BOOL)bundleIdentifierMatchesMarkedTextConfiguration:(NSString *)bundleID;
- (BOOL)bundleIdentifierUsesWebKitTextStack:(NSString *)bundleID;
- (BOOL)clientUsesWebKitTextStack:(id)sender;
- (BOOL)shouldAvoidEagerSyncForClient:(id)sender;
- (BOOL)shouldTrustDirectCompositionRangeForClient:(id)sender;
- (BOOL)bundleIdentifierUsesChromiumMarkedTextPolicy:(NSString *)bundleID;
- (BOOL)applicationBundleUsesChromiumTextStack:(NSURL *)bundleURL;
- (BOOL)runningApplicationUsesChromiumTextStack:(NSString *)bundleID;
- (BOOL)shouldUseMarkedTextForClient:(id)sender;
- (void)refreshMarkedTextPolicyForClient:(id)sender;

- (BOOL)directInputRangeIsCurrent:(NSRange)range client:(id)sender;
- (NSRange)directInputReplacementRange:(id)sender;
- (NSRange)compositionReplacementRange:(id)sender;
- (void)setMarkedReplacementRange:(NSRange)range;
- (void)clearMarkedReplacementRange;
- (void)clearDirectCompositionStatePreservingMarkedRange:(BOOL)preserveMarkedRange;
- (void)rememberSelectedRangeForClient:(id)sender;
- (void)resetCompositionState;
- (BOOL)hasPendingComposition;

- (NSString *)textBeforeCursorForClient:(id)sender
                                  limit:(NSUInteger)limit
                                  range:(NSRange *)outRange;
- (NSString *)firstHanjaDictionaryMatchInText:(NSString *)text
                                   startIndex:(NSUInteger *)outStartIndex;
- (NSString *)selectedTextForHanjaConversion:(id)sender
                                       range:(NSRange *)outRange;
- (NSString *)markedPrefixTextForHanjaConversion:(id)sender
                                        composed:(NSString *)composed
                                           range:(NSRange *)outRange;
- (NSString *)contextTextForHanjaConversion:(id)sender
                                      range:(NSRange *)outRange;
- (NSString *)composedTextForHanjaConversion:(NSString *)composed
                                      client:(id)sender
                                       range:(NSRange *)outRange;
- (NSString *)hangulTextForHanjaConversion:(id)sender
                                     range:(NSRange *)outRange;
- (BOOL)showHanjaCandidatesForText:(NSString *)text
                  replacementRange:(NSRange)replacementRange
                            client:(id)sender;
- (BOOL)handleHanjaConversion:(unsigned short)keyCode
                    modifiers:(NSUInteger)modifiers
                       client:(id)sender;
- (void)commitCandidate:(id)candidate client:(id)sender;

- (BOOL)isHangulKeyCode:(unsigned short)keyCode;
- (void)syncInputClient:(id)sender force:(BOOL)force;
- (void)prepareForInputClient:(id)sender;
- (void)reloadUserPreferences;
- (void)reloadHanjaShortcut;
- (void)preferencesDidChange:(NSNotification *)notification;
- (void)dictionaryDidChange:(NSNotification *)notification;
- (void)hanjaShortcutDidChange:(NSNotification *)notification;
- (BOOL)handleCandidateNavigation:(unsigned short)keyCode client:(id)sender;
- (BOOL)handleCustomShift:(unsigned short)keyCode
                modifiers:(NSUInteger)modifiers
                   client:(id)sender;
- (BOOL)processHangulInput:(NSEvent *)event
                   keyCode:(unsigned short)keyCode
                    client:(id)sender
         candidatesVisible:(BOOL)candidatesVisible;
- (void)commitMarkedText:(NSString *)commit client:(id)sender;
- (void)updateComposition:(id)sender;
- (BOOL)updateDirectComposition:(id)sender;
- (void)updateInlineForClient:(id)sender;
- (void)commitComposition:(id)sender;
- (void)openSettingsApplication;

@end
