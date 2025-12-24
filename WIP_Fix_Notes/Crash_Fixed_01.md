# Crash Fix Report - EXC_BAD_ACCESS during deactivateServer

**Date:** 2024-12-24  
**macOS Version:** 26.3 (25D5087f) Beta  
**Issue:** IME crash on client switch or deactivation

---

## Problem

The DKST Input Method was crashing with `EXC_BAD_ACCESS (SIGSEGV)` during:
- Switching between applications
- Closing the Preferences app
- General input source switching

### Crash Stack Trace
```
Thread 0 Crashed:
0  libobjc.A.dylib   objc_msgSend + 32
1  InputMethodKit    -[_IMKServerLegacy deactivateServer_CommonWithClientWrapper:controller:] + 368
```

### Exception Details
- **Type:** `EXC_BAD_ACCESS (SIGSEGV)`
- **Subtype:** `KERN_INVALID_ADDRESS (possible pointer authentication failure)`
- **Selector:** `isVisible` (called on `IMKCandidates`)

---

## Root Cause

InputMethodKit internally caches a reference to the `IMKCandidates` object created in `InputController`. When our `dealloc` released `_candidates`, InputMethodKit's cached reference became a dangling pointer. Subsequent calls to `isVisible` on this invalid pointer caused the crash.

---

## Solution

### 1. Always Create IMKCandidates for All Clients

Previously, we skipped creating `IMKCandidates` for the Preferences app client. This caused InputMethodKit to crash when trying to access a nil candidates object.

**File:** `InputController.m` - `initWithServer:delegate:client:`

```objc
// Always create IMKCandidates for all clients
_candidates = [[IMKCandidates alloc]
    initWithServer:server
         panelType:kIMKSingleColumnScrollingCandidatePanel];
```

### 2. Do NOT Release _candidates in dealloc

InputMethodKit manages the `IMKCandidates` lifecycle internally. Releasing it ourselves causes use-after-free.

**File:** `InputController.m` - `dealloc`

```objc
- (void)dealloc {
  // WARNING: Do NOT release _candidates here!
  // InputMethodKit internally caches a reference to the IMKCandidates object
  // and may call methods on it (like isVisible) after our dealloc is called.
  
  // Release other resources normally
  if (_currentHanjaCandidates) {
    [_currentHanjaCandidates release];
    _currentHanjaCandidates = nil;
  }
  // ... other releases
  [super dealloc];
}
```

---

## Files Modified

| File | Changes |
|------|---------|
| `Sources/InputController.m` | Always create IMKCandidates; Don't release in dealloc |
| `Sources/ApplicationDelegate.m` | Cleaned up unused menu code |

---

## Notes

- This appears to be related to macOS 26 beta InputMethodKit behavior
- Minor memory leak may occur (IMKCandidates not explicitly released), but InputMethodKit manages this
- Should monitor for any regressions in stable macOS releases
