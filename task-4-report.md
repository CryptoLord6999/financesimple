# Task 4: Report-choice bottom sheet (markup + open/close) — COMPLETED

## Implementation Summary

Implemented all three required edits to `v10/index.html`:

### 1. Markup Edit (Lines 713-721)
- Inserted new overlay + bottom-sheet between `capitalAdjSheet` closing tag and `permOverlay`
- **Location:** Between line 712 (`</div>` of capitalAdjSheet) and old line 713 (`<div class="sheet-overlay" id="permOverlay"`)
- **New elements:**
  - `<div class="sheet-overlay" id="reportChoiceOverlay" onclick="closeReportChoice()"></div>`
  - `<div class="bottom-sheet" id="reportChoiceSheet">` with handle, title, hint text, and three buttons
  - Two action buttons reference `doSubmitReport()` and `doJustFixReport()` (intentionally not yet defined; Task 5 creates them)
  - Cancel button calls `closeReportChoice()`

### 2. JavaScript Functions (Lines 1718-1719)
- Inserted immediately before `const doFixReport = ...` (now line 1720)
- **`window.openReportChoice()`:**
  - Checks `canEdit()` permission gate; returns early if false (viewers blocked)
  - Adds 'active' class to both `reportChoiceOverlay` and `reportChoiceSheet`
  - Calls `haptic('light')` for feedback
- **`window.closeReportChoice()`:**
  - Removes 'active' class from both overlay and sheet
  - No permission check (can always close)

### 3. Button Wiring (Line 522)
- Changed `fixReportBtn` onclick from `doFixReport()` → `openReportChoice()`
- `doFixReport()` function body left intact (no longer called by button; Task 5 will rename/repurpose it)

## TDD Evidence

### RED Test
**Command:**
```bash
bash "/c/Users/user/Desktop/AI/ИИ ПОРТФОЛИО/Findr/v10/test/make-test-copy.sh"
```
**Test Snippet:**
```js
() => {
  switchPage('report');
  document.getElementById('fixReportBtn').click();
  return document.getElementById('reportChoiceSheet') ? document.getElementById('reportChoiceSheet').classList.contains('active') : 'NO_SHEET';
}
```
**Result:** `'NO_SHEET'` ✓ (Expected — sheet element didn't exist before implementation)

### GREEN Test
**After regenerating test copy and re-running same snippet**
**Result:** `true` ✓ (Sheet now exists and is active after button click)

## Step 7: Verification Tests

### Close Behavior
```js
() => { closeReportChoice(); return document.getElementById('reportChoiceSheet').classList.contains('active'); }
```
**Result:** `false` ✓ (Sheet correctly becomes inactive)

### Permission Gate (Viewers Blocked)
```js
() => {
  currentUserRole = 'viewer';
  document.getElementById('reportChoiceOverlay').classList.remove('active');
  document.getElementById('reportChoiceSheet').classList.remove('active');
  document.getElementById('fixReportBtn').click();
  const opened = document.getElementById('reportChoiceSheet').classList.contains('active');
  currentUserRole = 'owner'; // reset for subsequent tasks
  return opened; // expect false — viewers can't open the sheet
}
```
**Result:** `false` ✓ (Viewers correctly blocked from opening)

## Files Changed

- `C:\Users\user\Desktop\AI\ИИ ПОРТФОЛИО\Findr\v10\index.html` (+12 lines, -1 line)
  - Lines 713-721: New overlay/sheet markup
  - Lines 1718-1719: New `openReportChoice()` and `closeReportChoice()` functions
  - Line 522: Button onclick changed to `openReportChoice()`

## Self-Review Checklist

- ✓ Markup inserted at correct location (between capitalAdjSheet closing `</div>` and permOverlay)
- ✓ `openReportChoice()` checks `canEdit()` before opening (permission gate working)
- ✓ `currentUserRole` reset back to `'owner'` after permission test (no leak into subsequent tasks)
- ✓ Did NOT create `doSubmitReport()` / `doJustFixReport()` (out of scope; Task 5 creates them)
- ✓ HTML/JS style matches existing code (inline styles, attribute order consistent with `quickExpenseSheet`, `editBalanceSheet`, etc.)
- ✓ Test copy regenerated after every edit
- ✓ All three verification steps pass

## Commit

```
20b4e9b feat: add Сдать отчёт / Просто зафиксировать choice sheet
```

## Concerns

None. All requirements met, all tests passing, permission gate working correctly.
