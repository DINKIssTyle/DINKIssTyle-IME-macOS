#import "InputController+Private.h"
#import "DKSTConstants.h"
#import "DKSTHanjaDictionary.h"

static BOOL DKSTIsHangulSyllable(unichar character) {
  return character >= 0xAC00 && character <= 0xD7A3;
}

@implementation InputController (Hanja)

- (NSString *)textBeforeCursorForClient:(id)sender
                                  limit:(NSUInteger)limit
                                  range:(NSRange *)outRange {
  if (outRange) {
    *outRange = NSMakeRange(NSNotFound, 0);
  }
  if (!sender || ![sender respondsToSelector:@selector(selectedRange)] ||
      ![sender respondsToSelector:@selector(attributedSubstringFromRange:)]) {
    return nil;
  }

  @try {
    NSRange selectedRange = [sender selectedRange];
    if (selectedRange.location == NSNotFound || selectedRange.length > 0) {
      return nil;
    }

    NSUInteger length = MIN(limit, selectedRange.location);
    if (length == 0) {
      return nil;
    }

    NSRange contextRange = NSMakeRange(selectedRange.location - length, length);
    NSAttributedString *contextAttr =
        [sender attributedSubstringFromRange:contextRange];
    NSString *context = [contextAttr string];
    if ([context length] == 0) {
      return nil;
    }

    if (outRange) {
      *outRange = contextRange;
    }
    return context;
  } @catch (NSException *exception) {
    DKSTLog(@"textBeforeCursorForClient failed: %@", exception);
    return nil;
  }
}

- (NSString *)firstHanjaDictionaryMatchInText:(NSString *)text
                                   startIndex:(NSUInteger *)outStartIndex {
  if (outStartIndex) {
    *outStartIndex = NSNotFound;
  }

  for (NSUInteger start = 0; start < [text length]; start++) {
    NSString *candidateText = [text substringFromIndex:start];
    NSArray *matches =
        [[DKSTHanjaDictionary sharedDictionary] hanjaForHangul:candidateText];
    if ([matches count] > 0) {
      if (outStartIndex) {
        *outStartIndex = start;
      }
      return candidateText;
    }
  }

  return nil;
}

- (NSString *)selectedTextForHanjaConversion:(id)sender
                                       range:(NSRange *)outRange {
  @try {
    if ([sender respondsToSelector:@selector(selectedRange)] &&
        [sender respondsToSelector:@selector(attributedSubstringFromRange:)]) {
      NSRange selectedRange = [sender selectedRange];
      if (selectedRange.location != NSNotFound && selectedRange.length > 0) {
        NSAttributedString *selectedAttr =
            [sender attributedSubstringFromRange:selectedRange];
        NSString *selectedText = [selectedAttr string];
        if ([selectedText length] > 0) {
          if (outRange) {
            *outRange = selectedRange;
          }
          return selectedText;
        }
      }
    }
  } @catch (NSException *exception) {
    DKSTLog(@"selected text Hanja target lookup failed: %@", exception);
  }

  return nil;
}

- (NSString *)markedPrefixTextForHanjaConversion:(id)sender
                                        composed:(NSString *)composed
                                           range:(NSRange *)outRange {
  if (!_useMarkedTextForClient || [composed length] == 0 ||
      [_markedTextCommittedPrefix length] == 0) {
    return nil;
  }

  NSString *markedText =
      [_markedTextCommittedPrefix stringByAppendingString:composed];
  NSString *candidateText =
      [self firstHanjaDictionaryMatchInText:markedText startIndex:NULL];
  if (![candidateText length]) {
    return nil;
  }

  if (outRange) {
    NSRange compositionRange = [self compositionReplacementRange:sender];
    *outRange = NSMakeRange(compositionRange.location, [candidateText length]);
  }
  _hanjaMarkedPrefixLength =
      [candidateText length] > [composed length]
          ? [candidateText length] - [composed length]
          : 0;
  _hanjaReplacementUsesMarkedPrefix = (_hanjaMarkedPrefixLength > 0);
  return candidateText;
}

- (NSString *)contextTextForHanjaConversion:(id)sender
                                      range:(NSRange *)outRange {
  NSRange contextRange = NSMakeRange(NSNotFound, 0);
  NSString *context = [self textBeforeCursorForClient:sender
                                                limit:20
                                                range:&contextRange];
  if ([context length] == 0) {
    return nil;
  }

  NSUInteger suffixStart = [context length];
  while (suffixStart > 0) {
    unichar c = [context characterAtIndex:suffixStart - 1];
    if (!DKSTIsHangulSyllable(c)) {
      break;
    }
    suffixStart--;
  }

  NSString *hangulSuffix = [context substringFromIndex:suffixStart];
  NSUInteger candidateStart = NSNotFound;
  NSString *candidateText =
      [self firstHanjaDictionaryMatchInText:hangulSuffix
                                 startIndex:&candidateStart];
  if (![candidateText length]) {
    return nil;
  }

  if (outRange) {
    NSRange range =
        NSMakeRange(contextRange.location + suffixStart + candidateStart,
                    [candidateText length]);
    *outRange = range;
  }
  return candidateText;
}

- (NSString *)composedTextForHanjaConversion:(NSString *)composed
                                      client:(id)sender
                                       range:(NSRange *)outRange {
  if ([composed length] == 0) {
    return nil;
  }

  if (outRange) {
    *outRange = [self compositionReplacementRange:sender];
  }
  return composed;
}

- (NSString *)hangulTextForHanjaConversion:(id)sender
                                     range:(NSRange *)outRange {
  _hanjaMarkedPrefixLength = 0;
  _hanjaReplacementUsesMarkedPrefix = NO;

  if (outRange) {
    *outRange = NSMakeRange(NSNotFound, 0);
  }

  NSString *selectedText =
      [self selectedTextForHanjaConversion:sender range:outRange];
  if ([selectedText length] > 0) {
    return selectedText;
  }

  NSString *composed = [engine composedString];
  NSString *markedPrefixText =
      [self markedPrefixTextForHanjaConversion:sender
                                      composed:composed
                                         range:outRange];
  if ([markedPrefixText length] > 0) {
    return markedPrefixText;
  }

  NSString *contextText =
      [self contextTextForHanjaConversion:sender range:outRange];
  if ([contextText length] > 0) {
    return contextText;
  }

  return [self composedTextForHanjaConversion:composed
                                       client:sender
                                        range:outRange];
}

- (BOOL)showHanjaCandidatesForText:(NSString *)text
                  replacementRange:(NSRange)replacementRange
                            client:(id)sender {
  if ([text length] == 0 || replacementRange.location == NSNotFound ||
      replacementRange.length == 0) {
    return NO;
  }

  NSArray *candidates =
      [[DKSTHanjaDictionary sharedDictionary] hanjaForHangul:text];

  NSMutableArray *allCandidates = [NSMutableArray array];
  if ([candidates count] > 0) {
    [allCandidates addObjectsFromArray:candidates];
  }

  // Keep the original text as the replacement value. Truncating here corrupts
  // the committed text when the user chooses the "leave unchanged" candidate.
  [allCandidates addObject:text];

  if (_currentHanjaCandidates) {
    [_currentHanjaCandidates release];
  }
  _currentHanjaCandidates = [allCandidates retain];
  _selectedTextRange = replacementRange;
  [self setMarkedReplacementRange:replacementRange];

  DKSTLog(@"Candidates for '%@': count=%lu range=(%lu,%lu)", text,
          (unsigned long)[allCandidates count],
          (unsigned long)replacementRange.location,
          (unsigned long)replacementRange.length);

  [_candidates updateCandidates];
  [_candidates show:kIMKLocateCandidatesBelowHint];

  _currentHanjaIndex = 0;
  NSInteger firstId = [_candidates candidateIdentifierAtLineNumber:0];
  if (firstId != NSNotFound) {
    [_candidates selectCandidateWithIdentifier:firstId];
  }
  return YES;
}

- (BOOL)handleHanjaConversion:(unsigned short)keyCode
                    modifiers:(NSUInteger)modifiers
                       client:(id)sender {
  if (!_hanjaEnabled || keyCode != _hanjaShortcutKeyCode ||
      modifiers != _hanjaShortcutModifiers) {
    return NO;
  }

  NSRange conversionRange = NSMakeRange(NSNotFound, 0);
  NSString *conversionText =
      [self hangulTextForHanjaConversion:sender range:&conversionRange];
  return [self showHanjaCandidatesForText:conversionText
                         replacementRange:conversionRange
                                   client:sender];
}

- (void)commitCandidate:(id)candidate client:(id)sender {
  NSString *selected = nil;
  if (candidate && [candidate isKindOfClass:[NSAttributedString class]]) {
    selected = [candidate string];
  } else if (candidate && [candidate isKindOfClass:[NSString class]]) {
    selected = candidate;
  }

  // Fallback: If no candidate provided or nil, use the first available
  // candidate
  if (!selected && _currentHanjaCandidates &&
      [_currentHanjaCandidates count] > 0) {
    selected = [_currentHanjaCandidates objectAtIndex:0];
  }

  // Debug log
  DKSTLog(@"commitCandidate selected='%@'", selected);

  if (selected) {
    // The last candidate is always the original source text. Candidate display
    // strings may contain an annotation after a space, but the original text
    // itself can also contain spaces and must be committed without truncation.
    NSString *sourceText = [_currentHanjaCandidates lastObject];
    NSString *hanja = [selected isEqualToString:sourceText]
                          ? selected
                          : [[selected componentsSeparatedByString:@" "] firstObject];
    if (hanja && [hanja length] > 0) {
      NSRange replacementRange;

      // Check if we're replacing selected text or composed text
      if (_selectedTextRange.location != NSNotFound &&
          _selectedTextRange.length > 0) {
        // Replacing selected text
        replacementRange = _selectedTextRange;
        DKSTLog(@"Replacing selected text at range: location=%lu, length=%lu",
                (unsigned long)replacementRange.location,
                (unsigned long)replacementRange.length);
      } else {
        replacementRange = [self compositionReplacementRange:sender];
        DKSTLog(@"Replacing composition text: location=%lu, length=%lu",
                (unsigned long)replacementRange.location,
                (unsigned long)replacementRange.length);
      }

      // Insert Hanja, replacing the text
      if (_hanjaReplacementUsesMarkedPrefix && _hanjaMarkedPrefixLength > 0) {
        @try {
          [sender setMarkedText:@""
                 selectionRange:NSMakeRange(0, 0)
               replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
          NSRange selectedRange = [sender selectedRange];
          if (selectedRange.location != NSNotFound &&
              selectedRange.location >= _hanjaMarkedPrefixLength) {
            replacementRange =
                NSMakeRange(selectedRange.location - _hanjaMarkedPrefixLength,
                            _hanjaMarkedPrefixLength);
          }
        } @catch (NSException *exception) {
          DKSTLog(@"Exception preparing marked-prefix Hanja replacement: %@",
                  exception);
        }
      }
      [sender insertText:hanja replacementRange:replacementRange];
      [engine reset];
      [self clearDirectCompositionStatePreservingMarkedRange:NO];
    } else {
      DKSTLog(@"Failed to extract hanja from '%@'", selected);
    }
  } else {
    DKSTLog(@"No candidate selected to commit");
  }

  [_markedTextCommittedPrefix setString:@""];
  [self cancelHanjaCandidates];
}

- (void)cancelHanjaCandidates {
  _selectedTextRange = NSMakeRange(NSNotFound, 0);
  [self clearMarkedReplacementRange];
  _hanjaMarkedPrefixLength = 0;
  _hanjaReplacementUsesMarkedPrefix = NO;
  _currentHanjaIndex = 0;

  [_candidates hide];
  if (_currentHanjaCandidates) {
    [_currentHanjaCandidates release];
    _currentHanjaCandidates = nil;
  }
}

// Candidate Selection Handler
- (void)candidateSelected:(NSAttributedString *)candidateString {
  [self commitCandidate:candidateString client:[self client]];
}

- (void)candidateSelectionChanged:(NSAttributedString *)candidateString {
  if (candidateString && _currentHanjaCandidates) {
    NSString *selectedStr = [candidateString string];
    NSUInteger idx = [_currentHanjaCandidates indexOfObject:selectedStr];
    if (idx != NSNotFound) {
      _currentHanjaIndex = idx;
      DKSTLog(@"candidateSelectionChanged: updated _currentHanjaIndex to %lu for '%@'",
              (unsigned long)_currentHanjaIndex, selectedStr);
    }
  }
}

@end
