#import "DKSTCompositionState.h"

@implementation DKSTCompositionState

@synthesize shouldCheckInsertionError = _shouldCheckInsertionError;
@synthesize shouldForceMarkedText = _shouldForceMarkedText;

- (id)init {
  self = [super init];
  if (self) {
    [self reset];
  }
  return self;
}

- (void)dealloc {
  [_bufferContents release];
  [_previousBufferContents release];
  [super dealloc];
}

- (NSString *)bufferContents {
  return _bufferContents;
}

- (NSString *)previousBufferContents {
  return _previousBufferContents;
}

- (NSRange)inlineRange {
  return _inlineRange;
}

- (NSRange)replacementRange {
  return _replacementRange;
}

- (BOOL)currentlyEditing {
  return _currentlyEditing;
}

- (void)reset {
  [_bufferContents release];
  _bufferContents = nil;
  [_previousBufferContents release];
  _previousBufferContents = nil;
  _inlineRange = NSMakeRange(NSNotFound, 0);
  _replacementRange = NSMakeRange(NSNotFound, 0);
  _currentlyEditing = NO;
  _shouldCheckInsertionError = YES;
  _shouldForceMarkedText = NO;
}

- (void)resetTransientRanges {
  _inlineRange = NSMakeRange(NSNotFound, 0);
  _replacementRange = NSMakeRange(NSNotFound, 0);
  _currentlyEditing = NO;
}

- (void)updateBufferContents:(NSString *)contents {
  NSString *normalized = contents ?: @"";
  if ((_bufferContents == normalized) ||
      [_bufferContents isEqualToString:normalized]) {
    return;
  }

  [_previousBufferContents release];
  _previousBufferContents = [_bufferContents copy];
  [_bufferContents release];
  _bufferContents = [normalized copy];
  _currentlyEditing = ([_bufferContents length] > 0);
}

- (void)noteInsertedTextWithReplacementRange:(NSRange)replacementRange
                           insertionLocation:(NSUInteger)insertionLocation
                             committedLength:(NSUInteger)committedLength
                              composedLength:(NSUInteger)composedLength {
  NSUInteger start = insertionLocation;
  if (replacementRange.location != NSNotFound) {
    start = replacementRange.location;
  }

  if (start != NSNotFound && composedLength > 0) {
    _inlineRange = NSMakeRange(start + committedLength, composedLength);
  } else {
    _inlineRange = NSMakeRange(NSNotFound, 0);
  }

  _replacementRange = NSMakeRange(NSNotFound, 0);
  _currentlyEditing = (composedLength > 0);
}

- (void)markReplacementRange:(NSRange)range {
  _replacementRange = range;
  [_bufferContents release];
  _bufferContents = nil;
  [_previousBufferContents release];
  _previousBufferContents = nil;
}

- (void)clearReplacementRange {
  _replacementRange = NSMakeRange(NSNotFound, 0);
}

@end
