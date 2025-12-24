# Work In Progress: Hanja Candidate Window Fix

**Date**: 2025-12-23
**Objective**: Fix the issue where selecting a Hanja candidate does not replace the composed Hangul text.

## Current Status
- **Navigation**: ✅ Fixed. Arrow keys, Page Up/Down move the selection in the candidate window.
- **Trigger**: ✅ Fixed. `Option + Return` reliably opens the candidate window.
- **Dismissal**: ✅ Fixed. `ESC` closes the window. `Option` key release no longer closes it.
- **Selection**: ⚠️ **Partially functioning**. Keys (Enter, Space, Numbers) are recognized and trigger the commit logic, but the actual text replacement in the client application (e.g., TextEdit) is reported as failing ("Input not changing").

## Attempts & Logic Implemented

1.  **Event Forwarding (Failed)**:
    - Attempted to just forward `keyDown:` events to `_candidates`.
    - Result: Candidate window didn't respond reliably to navigation.

2.  **Selector-Based Navigation (Success)**:
    - Implemented manual handling in `handleEvent:` that calls `moveUp:`, `moveDown:`, etc., directly on the `_candidates` object.
    - Result: Navigation works perfectly.

3.  **Explicit Commit Logic (Current Strategy)**:
    - **Issue**: `[_candidates selectedCandidateString]` was suspected to be `nil` when Enter was pressed, or the `client` reference was lost.
    - **Fix**: Created `commitCandidate:client:` helper method.
    - **Persistence**: Added `_currentHanjaCandidates` to `InputController` to store the candidate array. If `IMKCandidates` returns no selection, we fallback to `_currentHanjaCandidates[0]` (the first item).
    - **Client**: We now pass the `sender` (IMKClient) from `handleEvent:` directly to the commit method to ensure we are talking to the active application.
    - **Debugging**: Added `NSLog` output prefixed with `DKST:` to trace execution.

## Next Steps (If "Text Not Changing" Persists)

When you return, check the **Console.app** for `DKST` logs.

### Scenario A: Logs show `DKST: commitCandidate selected='...'`
If the log shows the correct Hanja string was selected but text didn't change:
- **Cause**: `insertText:` is being rejected or `setMarkedText:@""` is interfering.
- **Action**:
    - Try removing `[sender setMarkedText:@"" ...]` before insertion.
    - Try `[sender insertText:hanja replacementRange:NSMakeRange(0, [composed length])]` instead of `NSNotFound`.

### Scenario B: Logs show `DKST: No candidate selected to commit`
- **Cause**: Both `selectedCandidateString` and the fallback `_currentHanjaCandidates` array failed.
- **Action**: Verify `setCandidateData:` is actually populating the internal array. Ensure `_currentHanjaCandidates` is retained properly.

### Scenario C: No Logs at all
- **Cause**: The `handleEvent:` block for Enter/Space is not being hit.
- **Action**: Re-verify the `priority` of the `if ([_candidates isVisible])` block in [InputController.m](file:///Users/dinki/Documents/GitHub/DINKIssTyle-IME-macOS/Sources/InputController.m). (It should be at the very top).

## Reference Code (InputController.m)
```objectivec
- (void)commitCandidate:(id)candidate client:(id)sender {
    // ... string extraction ...
    
    // Fallback using persisted array
    if (!selected && _currentHanjaCandidates && [_currentHanjaCandidates count] > 0) {
        selected = [_currentHanjaCandidates objectAtIndex:0];
    }
    
    if (selected) {
         // Force clear mark
         [sender setMarkedText:@"" selectionRange:NSMakeRange(0,0) replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
         // Insert
         [sender insertText:hanja replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
         [engine reset];
    }
    // ...
}
```
