#import <Foundation/Foundation.h>

@interface DKSTCompositionState : NSObject {
  NSString *_bufferContents;
  NSString *_previousBufferContents;
  NSRange _inlineRange;
  NSRange _replacementRange;
  BOOL _currentlyEditing;
  BOOL _shouldCheckInsertionError;
  BOOL _shouldForceMarkedText;
}

@property(nonatomic, readonly) NSString *bufferContents;
@property(nonatomic, readonly) NSString *previousBufferContents;
@property(nonatomic, readonly) NSRange inlineRange;
@property(nonatomic, readonly) NSRange replacementRange;
@property(nonatomic, readonly) BOOL currentlyEditing;
@property(nonatomic, assign) BOOL shouldCheckInsertionError;
@property(nonatomic, assign) BOOL shouldForceMarkedText;

- (void)reset;
- (void)resetTransientRanges;
- (void)updateBufferContents:(NSString *)contents;
- (NSRange)directReplacementRangeForSelectedRange:(NSRange)selectedRange
                                   composedLength:(NSUInteger)composedLength;
- (void)noteInsertedTextWithReplacementRange:(NSRange)replacementRange
                           insertionLocation:(NSUInteger)insertionLocation
                             committedLength:(NSUInteger)committedLength
                              composedLength:(NSUInteger)composedLength;
- (NSUInteger)expectedSelectedLocationForInsertionLocation:(NSUInteger)location
                                           committedLength:(NSUInteger)committedLength
                                            composedLength:(NSUInteger)composedLength;
- (BOOL)selectedRange:(NSRange)selectedRange
    matchesExpectedLocation:(NSUInteger)expectedLocation;
- (BOOL)shouldFallbackForSelectedRange:(NSRange)selectedRange
                      expectedLocation:(NSUInteger)expectedLocation;
- (void)markReplacementRange:(NSRange)range;
- (void)clearReplacementRange;

@end
