# Task 7 Report: Undo last submission

## What I implemented

Three changes to `v10/index.html`, exactly matching the brief:

1. **`lastFixedBadge` markup** (was line 525): wrapped the existing icon+date content in an inner flex `<div>`, added `justify-content:space-between` to the outer badge, and appended a new `<button id="lastFixedUndo" onclick="undoLastSubmit()">Отменить</button>` (initially `display:none`).

2. **`checkLastFixed`** (was line 1543, in `refreshReport`'s neighborhood): now also grabs `#lastFixedUndo`, and after determining the most recent `savedReports` entry (`last`), sets `undoBtn.style.display = last.type === 'submit' ? 'inline' : 'none'`. No-entries branch still hides the whole badge (undo button is irrelevant in that case since it's already hidden/inside a hidden parent... actually it's a sibling, but it has its own `display:none` default so it doesn't need explicit hiding when there are no reports at all — verified this doesn't regress anything since the button starts hidden and is only ever shown via this function).

3. **`window.undoLastSubmit`**: inserted immediately after `window.doSubmitReport = ...` (line 1723). Gates on `canEdit()` (not `canDelete()`), finds the most recent `savedReports` key, no-ops if there are no entries or the most recent entry's `type !== 'submit'`, otherwise shows a `safeConfirm` dialog; on confirm, restores `reportPeriodStart = entry.periodStart` (including `null`), deletes the snapshot entry, persists (`saveLocal`/`saveServer`), re-renders (`renderAll()`), and shows a success toast/haptic.

No changes to `doSubmitReport`, `doJustFixReport`, or `saveReportSnapshot`. No redundant `renderReportsList()`/`checkLastFixed()` calls added after `renderAll()` — verified `renderAll()` (line 1392) calls `renderReport()`, which is `const renderReport = refreshReport` (line 1540), and `refreshReport`'s body (line 1539) ends with `renderReportsList(); checkLastFixed();`. So `renderAll()` already transitively re-renders both.

## TDD evidence

**RED** — Step 1/2, before any implementation, evaluated in browser against `index.test.html`:
```js
() => {
  savedReports = { k1: { date: new Date().toISOString(), type: 'submit', periodStart: '2026-01-01T12:00:00.000Z', turnover: 0, income: 0, expense: 0, spend: 0, revenue: 0, margin: 0, balance: 0, capital: 0, siteBalance: 0 } };
  reportPeriodStart = new Date().toISOString();
  checkLastFixed();
  return document.getElementById('lastFixedUndo') ? document.getElementById('lastFixedUndo').style.display : 'NO_BUTTON';
}
```
Result: `"NO_BUTTON"` — matches brief's expected RED output exactly.

**GREEN** — Step 5, after implementing markup + `checkLastFixed` + `undoLastSubmit`, regenerated `index.test.html` (`bash test/make-test-copy.sh` → `OK: test copy uses dummy Firebase config`), reloaded, re-ran the identical snippet.
Result: `"inline"` — matches brief's expected GREEN output exactly.

## Step 6: full undo flow (end-to-end)

Used `mcp__playwright__browser_handle_dialog` to accept the native `confirm()` (verified beforehand that `window.Telegram.WebApp.showConfirm` throws `WebAppMethodUnsupported` in this test environment — even though the real `telegram-web-app.js` script is loaded unconditionally by `index.html`, calling `showConfirm` outside the actual Telegram client throws, so `safeConfirm` falls through to native `confirm()` as the brief predicted).

Evaluated:
```js
() => {
  savedReports = { k1: { date: new Date().toISOString(), type: 'submit', periodStart: '2026-01-01T12:00:00.000Z', turnover: 0, income: 0, expense: 0, spend: 0, revenue: 0, margin: 0, balance: 0, capital: 0, siteBalance: 0 } };
  reportPeriodStart = new Date().toISOString();
  undoLastSubmit();
  return 'called';
}
```
This opened a native `confirm()` dialog with message `"Отменить последнюю сдачу отчёта? Показатели вернутся к состоянию до сдачи."` (exact text from the implementation). Accepted via `browser_handle_dialog({accept: true})`.

Then evaluated:
```js
() => ({ remaining: Object.keys(savedReports).length, restoredPeriodStart: reportPeriodStart })
```
**Observed: `{ remaining: 0, restoredPeriodStart: '2026-01-01T12:00:00.000Z' }`** — exact match to brief's expected output.

### Extra check: `null` periodStart case (self-review requirement)
Repeated the same flow with `periodStart: null` instead of a date string. Dialog appeared identically, accepted it, then checked state.
**Observed: `{ remaining: 0, restoredPeriodStart: null }`** — confirms the restore correctly propagates `null`, not just truthy date strings (no coercion to `new Date()` or similar bug).

### Extra check: `canEdit()` gate
Set `currentUserRole = 'viewer'` (so `canEdit()` returns `false` since it checks `['owner','admin'].includes(...)`), then called `undoLastSubmit()` with a valid `'submit'` entry present. No dialog appeared, `savedReports` was untouched (`noopOk: true`, `count: 1`). Restored `currentUserRole = 'owner'` afterward. Confirms the `canEdit()` gate (not `canDelete()`, which is currently identical in implementation but semantically the wrong gate per the plan) is wired in and functioning as an early return.

## Step 7: negative case (most recent entry is a plain "fix")

Evaluated:
```js
() => {
  savedReports = { k1: { date: new Date().toISOString(), type: 'fix', turnover: 0, income: 0, expense: 0, spend: 0, revenue: 0, margin: 0, balance: 0, capital: 0, siteBalance: 0 } };
  checkLastFixed();
  return document.getElementById('lastFixedUndo').style.display;
}
```
**Observed: `'none'`** — exact match to brief's expected output.

### Extra check: `undoLastSubmit()` no-ops on a `'fix'`-type most-recent entry
Called `undoLastSubmit()` directly (not just `checkLastFixed()`) with the most recent entry's `type === 'fix'`. No dialog appeared at all (confirmed no modal state was raised), and `savedReports` was unchanged byte-for-byte (`noopOk: true`, `count: 1`). This confirms the early `if (entry.type !== 'submit') return;` guard inside `undoLastSubmit` fires before `safeConfirm` is ever called — not just that the button is hidden in the UI.

## Files changed

- `C:\Users\user\Desktop\AI\ИИ ПОРТФОЛИО\Findr\v10\index.html` — the three edits described above. Diff: 1 file changed, 3 insertions(+), 2 deletions(-).
- `index.test.html` regenerated twice via `bash test/make-test-copy.sh` (gitignored, not committed) for browser-driven verification — never touched directly.

## Self-review

- **`canEdit()` not `canDelete()`**: confirmed — `window.undoLastSubmit = () => { if (!canEdit()) return; ... }`. Verified behaviorally with `currentUserRole = 'viewer'` (no-op, no dialog).
- **No-ops when most recent entry's `type` is `'fix'` or doesn't exist**: confirmed for `'fix'` (Step 7 + extra check above). For "doesn't exist" (empty `savedReports`): the code does `const keys = Object.keys(savedReports).sort().reverse(); if (!keys.length) return;` before ever touching `entry.type`, so it safely no-ops without throwing on `undefined.type`.
- **`checkLastFixed` show/hide `#lastFixedUndo` correctly**: confirmed both directions — `'submit'` → `'inline'` (Step 5/GREEN), `'fix'` → `'none'` (Step 7).
- **Full undo restores `reportPeriodStart` to exact stored `periodStart`, including `null`**: confirmed both for a real ISO string (`'2026-01-01T12:00:00.000Z'`) and for `null` — see Step 6 and its extra check above.

## Concerns

None. All brief steps (1, 2, 3, 4, 5, 6, 7, 8) executed and passed with exact expected outputs; additional edge cases (canEdit gate, null periodStart, fix-type no-op without dialog) verified beyond the brief's minimum. `renderAll()`'s transitive call to `renderReportsList()`/`checkLastFixed()` was verified by reading `refreshReport`'s actual current source (line 1539) rather than assumed, per the escalation instructions — confirmed true, so no redundant calls were added.

One minor observation (not a defect): `canEdit()` and `canDelete()` currently have identical implementations (`['owner','admin'].includes(currentUserRole)`), so today there's no behavioral difference between gating on one vs. the other. Using `canEdit()` is still correct per the explicit plan requirement and is the semantically right choice (undo is edit-like, not delete-like) — flagging only so a future change to either function's role list doesn't silently break this expectation.
