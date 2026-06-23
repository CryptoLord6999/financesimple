# Task 5 Report: `doSubmitReport()` and `doJustFixReport()`

## What I implemented

Replaced the old `const doFixReport = () => {...}` line (was at `index.html:1720`) with three definitions, exactly as specified in the brief:

```js
const saveReportSnapshot = (extra) => { const s = calcAll(), now = new Date(), key = now.toISOString().replace(/[:.]/g, '-').slice(0, 19); savedReports[key] = Object.assign({ date: now.toISOString(), turnover: s.turnover, income: s.totalIncome, expense: s.totalExpense, spend: s.totalSpend, revenue: s.revenue, margin: s.margin, balance: s.totalBalance, capital, siteBalance: s.siteBalance }, extra); return key; };
window.doJustFixReport = () => { if (!canEdit()) return; saveReportSnapshot({ type: 'fix' }); saveLocal(); saveServer(); closeReportChoice(); renderAll(); haptic('success'); showToast(icon('check',20),'Отчёт сохранён'); };
window.doSubmitReport = () => { if (!canEdit()) return; const periodStart = reportPeriodStart; saveReportSnapshot({ type: 'submit', periodStart }); reportPeriodStart = new Date().toISOString(); saveLocal(); saveServer(); closeReportChoice(); renderAll(); haptic('success'); showToast(icon('check',20),'Отчёт сдан, период сброшен'); };
```

Key behavior: `doSubmitReport` captures the OLD `reportPeriodStart` into a local `periodStart` variable, then calls `saveReportSnapshot` (which internally calls `calcAll()` with no args — still using the OLD `reportPeriodStart` at that point), and only afterward advances `reportPeriodStart` to "now". This ordering is what makes the snapshot capture the closing period's true totals instead of a near-zero "since now" result.

`doFixReport` had no other call sites in the file (confirmed via grep — zero matches after removal); the bottom sheet from Task 4 already referenced `doSubmitReport()`/`doJustFixReport()` by name (intentionally undefined until this task). The old `doFixReport` also called `renderReportsList()` and `checkLastFixed()`, neither of which exist anywhere else in the codebase (confirmed via grep — zero matches) — these were already dead/stale calls, correctly dropped in favor of `renderAll()` per the brief's replacement code.

## TDD Evidence

Setup: `bash test/make-test-copy.sh` regenerates `index.test.html` with a dummy/invalid Firebase config. Served via `python -m http.server 8791` (file:// blocked by Playwright tool), navigated via `mcp__playwright__browser_navigate` to `http://localhost:8791/index.test.html`.

### RED

Command: ran the Step 1 snippet from the brief against the pre-edit `index.test.html`:
```js
() => {
  const now = new Date().toISOString();
  holders = { h1: { id: 'h1', name: 'H1', accounts: {
    a1: { id: 'a1', name: 'A1', balance: 1000, transactions: [ { type: 'income', amount: 1000, date: now } ] }
  } } };
  activeHolderId = 'h1'; activeAccountId = 'a1'; capital = 500; savedReports = {}; reportPeriodStart = null;
  renderAll();
  try {
    doSubmitReport();
    return { error: null, count: Object.keys(savedReports).length };
  } catch (e) { return { error: e.message, count: Object.keys(savedReports).length }; }
}
```
**Output:** `{ "error": "doSubmitReport is not defined", "count": 0 }` — matches brief's expected RED exactly.

### GREEN

After implementing Step 3, re-ran `bash test/make-test-copy.sh`, did a fresh page navigation (file changed on disk), re-ran the identical Step 1 snippet.

**Output:** `{ "error": null, "count": 1 }` — matches brief's expected GREEN exactly.

## Step 5 check: full submit behavior

First attempt (issuing the Step-5-only snippet as a separate tool call, reusing state from the GREEN run) returned `nowIsRecent: false`. Investigated: this was a test-harness timing artifact, not a code bug — roughly 30 seconds of agent/tool round-trip latency had elapsed between the `doSubmitReport()` call and the later `Date.now()` check inside the *next* tool invocation, pushing the delta past the brief's `< 5000`ms sanity-check window. Confirmed by inspecting raw values:
```js
{ reportPeriodStart: "2026-06-23T18:19:33.461Z", now: "2026-06-23T18:20:03.633Z", deltaMs: 30172 }
```
`reportPeriodStart` had in fact been set to "now" at the moment `doSubmitReport()` ran — just not "now" relative to a later, separate tool call.

To eliminate that artifact, re-ran the full sequence (seed state + `doSubmitReport()` + the Step 5 assertions) inside a single `browser_evaluate` call, so the elapsed time between setting `reportPeriodStart` and checking it is sub-millisecond:

```js
() => {
  const now = new Date().toISOString();
  holders = { h1: { id: 'h1', name: 'H1', accounts: {
    a1: { id: 'a1', name: 'A1', balance: 1000, transactions: [ { type: 'income', amount: 1000, date: now } ] }
  } } };
  activeHolderId = 'h1'; activeAccountId = 'a1'; capital = 500; savedReports = {}; reportPeriodStart = null;
  renderAll();
  doSubmitReport();
  const key = Object.keys(savedReports)[0];
  const entry = savedReports[key];
  return {
    type: entry.type,
    periodStart: entry.periodStart,
    income: entry.income,
    nowIsRecent: (Date.now() - new Date(reportPeriodStart).getTime()) < 5000,
    liveIncomeAfterSubmit: calcAll().totalIncome
  };
}
```

**Output:** `{ "type": "submit", "periodStart": null, "income": 1000, "nowIsRecent": true, "liveIncomeAfterSubmit": 0 }`

Matches the brief's expected `{ type: 'submit', periodStart: null, income: 1000, nowIsRecent: true, liveIncomeAfterSubmit: 0 }` exactly.

## Step 6 check: «Просто зафиксировать» does NOT reset anything

```js
() => {
  const now = new Date().toISOString();
  holders = { h1: { id: 'h1', name: 'H1', accounts: {
    a1: { id: 'a1', name: 'A1', balance: 1000, transactions: [ { type: 'income', amount: 777, date: now } ] }
  } } };
  activeHolderId = 'h1'; activeAccountId = 'a1'; savedReports = {}; reportPeriodStart = null;
  doJustFixReport();
  const key = Object.keys(savedReports)[0];
  return { type: savedReports[key].type, periodStartAfter: reportPeriodStart, liveIncomeAfter: calcAll().totalIncome };
}
```

**Output:** `{ "type": "fix", "periodStartAfter": null, "liveIncomeAfter": 777 }`

Matches the brief's expected `{ type: 'fix', periodStartAfter: null, liveIncomeAfter: 777 }` exactly.

## Console check

Confirmed the only console errors/warnings during testing were the expected, deliberate ones from `make-test-copy.sh`'s dummy Firebase config (`TEST-INVALID-KEY`, unparseable database URL, triggered each time `saveServer()` runs inside the new functions) plus a benign Telegram WebApp haptics-not-supported warning. No errors related to the new code logic itself.

## Files changed

- `C:\Users\user\Desktop\AI\ИИ ПОРТФОЛИО\Findr\v10\index.html` — 1 line removed (`doFixReport`), 3 lines added (`saveReportSnapshot`, `window.doJustFixReport`, `window.doSubmitReport`). Net +3/-1.

## Self-review findings

- **Ordering trace**: `doSubmitReport` reads `const periodStart = reportPeriodStart` (captures old value) → calls `saveReportSnapshot(...)` which calls `calcAll()` while `reportPeriodStart` is still the old value → only after that line returns does `reportPeriodStart = new Date().toISOString()` run. Confirmed correct both by static reading and by the Step 5 empirical result (`income: 1000` captured, `liveIncomeAfterSubmit: 0` after).
- **`doJustFixReport` never assigns to `reportPeriodStart`** — confirmed by reading the function body (no such statement exists) and empirically via Step 6 (`periodStartAfter: null`, unchanged).
- **Snapshot field parity**: `saveReportSnapshot` produces the exact same 10 base fields the old `doFixReport` had (`date, turnover, income, expense, spend, revenue, margin, balance, capital, siteBalance`), plus whatever `extra` is merged in (`type`, and `periodStart` for submits).
- **`closeReportChoice()` called in both**: confirmed present in both function bodies, called before `renderAll()`/toast, consistent with Task 4's sheet-close pattern.
- No other call sites of `doFixReport` existed anywhere in `index.html` (verified via grep before and after the edit), so removal was safe. `calcAll`, `filterTx`, `calcAcc`, and the Task 4 sheet markup were not touched.

## Concerns

None blocking. One non-issue worth flagging for future task authors: the brief's Step 5 `nowIsRecent` check (`< 5000`ms) is sensitive to agent/tool round-trip latency if the seed-and-call step and the assertion step are split across two separate `browser_evaluate` invocations — in this run that gap was ~30s, large enough to fail the threshold despite the underlying code being correct. Running setup+action+assertion in one evaluate call avoids the artifact. No code change needed; this is purely about how the check is invoked during manual/agent-driven verification, not a defect in `doSubmitReport`.
