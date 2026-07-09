#import "InputController+Private.h"
#import "DKSTConstants.h"

@implementation InputController (ClientPolicy)

- (NSString *)bundleIdentifierForClient:(id)sender {
  // IMK clients are XPC proxies, so bundleIdentifier can cross process
  // boundaries. Cache it for the specific client that supplied it; policy
  // decisions must not reuse another app's bundle identifier after focus moves.
  if (sender && _lastBundleIdentifierClient == sender &&
      [_lastInputClientBundleID length] > 0) {
    return _lastInputClientBundleID;
  }

  NSString *bundleID = nil;

  @try {
    if (sender && [sender respondsToSelector:@selector(bundleIdentifier)]) {
      bundleID = [sender bundleIdentifier];
    }
    if (!bundleID &&
        [[self client] respondsToSelector:@selector(bundleIdentifier)]) {
      bundleID = [[self client] bundleIdentifier];
    }
  } @catch (NSException *exception) {
    DKSTLog(@"Exception getting client bundle id: %@", exception);
  }

  [_lastInputClientBundleID release];
  _lastInputClientBundleID = [bundleID copy];
  _lastBundleIdentifierClient = sender;

  return bundleID;
}

- (void)forceMarkedTextForClient:(id)sender reason:(NSString *)reason {
  NSString *bundleID = [self bundleIdentifierForClient:sender];
  if ([bundleID length] > 0) {
    [_forcedMarkedTextBundleIDs addObject:bundleID];
  }
  _useMarkedTextForClient = YES;
  DKSTLog(@"Forcing marked text for %@: %@", bundleID ?: @"unknown client",
          reason);
}

- (BOOL)bundleIdentifier:(NSString *)bundleID
          matchesPattern:(NSString *)pattern {
  if (![bundleID length] || ![pattern length]) {
    return NO;
  }

  NSRange wildcardRange = [pattern rangeOfString:@"*"];
  if (wildcardRange.location == NSNotFound) {
    return [bundleID isEqualToString:pattern];
  }

  NSString *prefix = [pattern substringToIndex:wildcardRange.location];
  NSString *suffix = [pattern substringFromIndex:NSMaxRange(wildcardRange)];
  return ([prefix length] == 0 || [bundleID hasPrefix:prefix]) &&
         ([suffix length] == 0 || [bundleID hasSuffix:suffix]) &&
         [bundleID length] >= [prefix length] + [suffix length];
}

- (BOOL)bundleIdentifierMatchesMarkedTextConfiguration:(NSString *)bundleID {
  if (![bundleID length]) {
    return NO;
  }

  for (NSString *pattern in _markedTextBundleIDSet) {
    if (![pattern isKindOfClass:[NSString class]]) {
      continue;
    }
    if ([self bundleIdentifier:bundleID matchesPattern:pattern]) {
      return YES;
    }
  }

  return NO;
}

- (BOOL)bundleIdentifierUsesWebKitTextStack:(NSString *)bundleID {
  if (![bundleID length]) {
    return NO;
  }

  NSArray *webkitBundlePrefixes =
      [NSArray arrayWithObjects:@"com.apple.Safari", @"com.apple.WebKit",
                                @"com.apple.mobilesafari", nil];

  for (NSString *prefix in webkitBundlePrefixes) {
    if ([bundleID isEqualToString:prefix] ||
        [bundleID hasPrefix:[prefix stringByAppendingString:@"."]]) {
      return YES;
    }
  }

  return NO;
}

- (BOOL)clientUsesWebKitTextStack:(id)sender {
  NSString *bundleID = [self bundleIdentifierForClient:sender];
  return [self bundleIdentifierUsesWebKitTextStack:bundleID];
}

- (BOOL)shouldAvoidEagerSyncForClient:(id)sender {
  return [self clientUsesWebKitTextStack:sender];
}

- (BOOL)shouldTrustDirectCompositionRangeForClient:(id)sender {
  return [self clientUsesWebKitTextStack:sender];
}

- (BOOL)bundleIdentifierUsesChromiumMarkedTextPolicy:(NSString *)bundleID {
  if (![bundleID length]) {
    return NO;
  }

  NSArray *chromiumBundlePrefixes = [NSArray
      arrayWithObjects:@"org.chromium.Chromium", @"com.google.Chrome",
                       @"com.google.Chrome.canary", @"com.microsoft.edgemac",
                       @"com.brave.Browser", @"com.vivaldi.Vivaldi",
                       @"com.operasoftware.Opera", @"com.naver.Whale",
                       @"company.thebrowser.Browser", @"ai.perplexity.comet",
                       @"com.perplexity.Comet", @"com.perplexity.comet",
                       @"com.openai.atlas", @"com.openai.Atlas",
                       @"com.openai.chatgpt.atlas", nil];

  for (NSString *prefix in chromiumBundlePrefixes) {
    if ([bundleID isEqualToString:prefix] ||
        [bundleID hasPrefix:[prefix stringByAppendingString:@"."]]) {
      return YES;
    }
  }

  return NO;
}

- (BOOL)applicationBundleUsesChromiumTextStack:(NSURL *)bundleURL {
  if (!bundleURL) {
    return NO;
  }

  NSString *bundlePath = [bundleURL path];
  if (![bundlePath length]) {
    return NO;
  }

  NSNumber *cachedResult = [_chromiumDetectionCache objectForKey:bundlePath];
  if (cachedResult) {
    return [cachedResult boolValue];
  }

  NSString *frameworksPath =
      [bundlePath stringByAppendingPathComponent:@"Contents/Frameworks"];
  NSFileManager *fm = [NSFileManager defaultManager];
  BOOL isDirectory = NO;
  if (![fm fileExistsAtPath:frameworksPath isDirectory:&isDirectory] ||
      !isDirectory) {
    [_chromiumDetectionCache setObject:[NSNumber numberWithBool:NO]
                                forKey:bundlePath];
    return NO;
  }

  NSArray *frameworkNames = [fm contentsOfDirectoryAtPath:frameworksPath
                                                    error:nil];
  NSArray *chromiumFrameworkNames =
      [NSArray arrayWithObjects:@"Electron Framework.framework",
                                @"Chromium Embedded Framework.framework",
                                @"Google Chrome Framework.framework",
                                @"Microsoft Edge Framework.framework",
                                @"Brave Browser Framework.framework",
                                @"Vivaldi Framework.framework",
                                @"Opera Framework.framework", nil];

  for (NSString *frameworkName in frameworkNames) {
    if ([chromiumFrameworkNames containsObject:frameworkName]) {
      [_chromiumDetectionCache setObject:[NSNumber numberWithBool:YES]
                                  forKey:bundlePath];
      return YES;
    }
    if ([frameworkName rangeOfString:@"Chromium"
                             options:NSCaseInsensitiveSearch]
                .location != NSNotFound ||
        [frameworkName rangeOfString:@"Electron"
                             options:NSCaseInsensitiveSearch]
                .location != NSNotFound) {
      [_chromiumDetectionCache setObject:[NSNumber numberWithBool:YES]
                                  forKey:bundlePath];
      return YES;
    }
  }

  [_chromiumDetectionCache setObject:[NSNumber numberWithBool:NO]
                              forKey:bundlePath];
  return NO;
}

- (BOOL)runningApplicationUsesChromiumTextStack:(NSString *)bundleID {
  if (![bundleID length]) {
    return NO;
  }

  // The fallback Chromium check can enumerate running apps and inspect bundle
  // frameworks on disk. Cache both YES and NO by bundle ID so first-key policy
  // detection does not repeatedly block the input path.
  NSString *cacheKey = [@"bundle:" stringByAppendingString:bundleID];
  NSNumber *cachedResult = [_chromiumDetectionCache objectForKey:cacheKey];
  if (cachedResult) {
    return [cachedResult boolValue];
  }

  NSArray *runningApps =
      [NSRunningApplication runningApplicationsWithBundleIdentifier:bundleID];
  for (NSRunningApplication *app in runningApps) {
    NSString *appName = [[app localizedName] lowercaseString];
    NSString *bundleName = [[[[app bundleURL] lastPathComponent]
        stringByDeletingPathExtension] lowercaseString];
    if ([appName isEqualToString:@"comet"] ||
        [bundleName isEqualToString:@"comet"] ||
        [appName isEqualToString:@"atlas"] ||
        [bundleName isEqualToString:@"atlas"] ||
        [appName isEqualToString:@"chatgpt atlas"] ||
        [bundleName isEqualToString:@"chatgpt atlas"]) {
      [_chromiumDetectionCache setObject:[NSNumber numberWithBool:YES]
                                  forKey:cacheKey];
      return YES;
    }

    if ([self applicationBundleUsesChromiumTextStack:[app bundleURL]]) {
      [_chromiumDetectionCache setObject:[NSNumber numberWithBool:YES]
                                  forKey:cacheKey];
      return YES;
    }
  }

  [_chromiumDetectionCache setObject:[NSNumber numberWithBool:NO]
                              forKey:cacheKey];
  return NO;
}

- (BOOL)shouldUseMarkedTextForClient:(id)sender {
  if (_useMarkedTextForAllApps) {
    return YES;
  }

  // 1. Apple Private API: Query showsComposingTextAsMarkedText
  // This is the most reliable way to detect if a client needs marked text.
  // KIM_Extension uses textDocument proxy for this query.
  SEL textDocSel = NSSelectorFromString(@"textDocument");
  id textDocument = nil;
  if ([self respondsToSelector:textDocSel]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    textDocument = [self performSelector:textDocSel];
#pragma clang diagnostic pop
  }

  SEL showsComposingTextSel =
      NSSelectorFromString(@"showsComposingTextAsMarkedText");

  // Check textDocument proxy first (standard IMK behavior)
  if (textDocument && [textDocument respondsToSelector:showsComposingTextSel]) {
    BOOL showsMarked = ((BOOL (*)(
        id, SEL))[textDocument methodForSelector:showsComposingTextSel])(
        textDocument, showsComposingTextSel);
    return showsMarked;
  }

  // Fallback: Check sender directly (some apps might implement it)
  if ([sender respondsToSelector:showsComposingTextSel]) {
    BOOL showsMarked =
        ((BOOL (*)(id, SEL))[sender methodForSelector:showsComposingTextSel])(
            sender, showsComposingTextSel);
    return showsMarked;
  }

  NSString *bundleID = [self bundleIdentifierForClient:sender];

  if (![bundleID length]) {
    return YES;
  }

  if ([_forcedMarkedTextBundleIDs containsObject:bundleID]) {
    return YES;
  }

  if ([self bundleIdentifierUsesWebKitTextStack:bundleID]) {
    return NO;
  }

  if ([self bundleIdentifierMatchesMarkedTextConfiguration:bundleID]) {
    return YES;
  }

  if ([self bundleIdentifierUsesChromiumMarkedTextPolicy:bundleID] ||
      [self runningApplicationUsesChromiumTextStack:bundleID]) {
    return YES;
  }

  @try {
    if (![sender respondsToSelector:@selector(selectedRange)]) {
      return YES;
    }
    NSRange selectedRange = [sender selectedRange];
    if (selectedRange.location == NSNotFound) {
      return YES;
    }
  } @catch (NSException *exception) {
    DKSTLog(@"Exception checking selected range for direct input: %@",
            exception);
    return YES;
  }

  return NO;
}

- (void)refreshMarkedTextPolicyForClient:(id)sender {
  _useMarkedTextForClient = [self shouldUseMarkedTextForClient:sender];
}

@end
