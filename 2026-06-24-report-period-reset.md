# Сдача отчёта со сбросом периода — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a «Сдать отчёт» / «Просто зафиксировать» choice to Findr's «Зафиксировать» button so the owner can close out a reporting period — visually resetting oborot/income/expense/revenue/spend/margin to 0 — without ever deleting underlying transaction history, which stays fully retrievable through the existing «Детали» date filter.

**Architecture:** All changes live in the single existing file `v10/index.html` (no build step, no module system — follow the existing pattern of one inline `<script>`). A new global `reportPeriodStart` epoch marks where the "current, not-yet-reported" window begins; the existing `filterTx`/`calcAcc`/`calcAll` pipeline is extended (not replaced) so that calls made without an explicit period (today's only use of "lifetime") become "since `reportPeriodStart`" instead, while every explicit period (`today`/`week`/`month`/`custom`/`all`) used by «Детали» keeps filtering by real calendar dates, untouched.

**Tech Stack:** Vanilla JS (no framework, no bundler), inline `<script>` in a static PWA HTML file. Verification uses Playwright (MCP browser tools) driving the file directly in Chromium — no test framework/runner is introduced, matching the project's current zero-tooling setup.

## Global Constraints

- Spec source: `v10/docs/superpowers/specs/2026-06-24-report-period-reset-design.md` — every task below implements one of its numbered sections; re-read it if a task's intent is unclear.
- **Never let any verification step write to the real production Firebase project** (`financesimple-7c73a`, hardcoded at `v10/index.html` line ~932). The app calls `firebase.auth().signInAnonymously()` and `firebase.database().ref(...).update(...)` automatically on load/save — this is real, live, production infrastructure for an actual business, not a sandbox. Task 0 builds a `index.test.html` copy with a deliberately broken Firebase config; **every** browser-driven verification step in this plan runs against that copy, never against `index.html` directly. Regenerate the copy (re-run `test/make-test-copy.sh`) after every edit to `index.html`, before testing.
- Balances (`acc.balance`), `capital`, and `siteBalance` (`capital - totalBalance`) must never be reset or filtered by period anywhere in this feature — they behave like balances, not period metrics (confirmed user decision).
- `transactions[]` arrays are never deleted, truncated, or mutated by this feature — the only new state is the `reportPeriodStart` marker and new fields on `savedReports` entries.
- Permission gate: any action that used to require `canEdit()` (`v10/index.html:1042`, `['owner','admin'].includes(currentUserRole)`) keeps requiring it. `undoLastSubmit` also uses `canEdit()`, not `canDelete()`.
- All new UI follows the existing bottom-sheet visual pattern (`.sheet-overlay` + `.bottom-sheet` + `.sheet-handle` + `.sheet-title`, toggled via `.active` class) — see `editBalanceSheet`/`quickExpenseSheet` at `v10/index.html:671-679` for the exact pattern being mirrored.
- Russian copy is fixed by the spec; use it verbatim where quoted in a task.

---

## File Structure

Only one application file changes:
- **Modify:** `v10/index.html` — data globals/persistence (~line 1157-1191), report HTML markup (~line 504-528, ~692-713), report JS logic (~line 1530-1719).

Two new files support safe testing (not shipped to users, not referenced by `index.html`):
- **Create:** `v10/test/make-test-copy.sh` — regenerates `v10/index.test.html` from `v10/index.html` with a broken Firebase config.
- **Create:** `v10/.gitignore` — excludes `index.test.html` from version control.

---

### Task 0: Git baseline + safe test-copy script

**Files:**
- Create: `v10/.gitignore`
- Create: `v10/test/make-test-copy.sh`
- Initialize git repository at `v10/`

**Interfaces:**
- Produces: `test/make-test-copy.sh` — every later task's verification steps run this first, then navigate Playwright to `v10/index.test.html` (never `index.html`).

- [ ] **Step 1: Initialize git and commit the current baseline**

```bash
cd "/c/Users/user/Desktop/AI/ИИ ПОРТФОЛИО/Findr/v10"
git init
git add -A
git commit -m "chore: baseline commit before report-period-reset feature"
```

Expected: `git log --oneline` shows one commit; `git status` shows clean working tree.

- [ ] **Step 2: Create `.gitignore`**

File: `v10/.gitignore`
```
index.test.html
```

- [ ] **Step 3: Create the test-copy script**

File: `v10/test/make-test-copy.sh`
```bash
#!/usr/bin/env bash
# Regenerates index.test.html from index.html with a deliberately invalid
# Firebase config, so browser-driven verification never reaches the real
# production database (financesimple-7c73a). Re-run after every edit to
# index.html, before any Playwright verification step.
set -e
cd "$(dirname "$0")/.."
cp index.html index.test.html
sed -i 's/apiKey: "AIzaSyAbeGi5WVmiszMO9muzZV4CZQxXe17T7UY"/apiKey: "TEST-INVALID-KEY"/' index.test.html
sed -i 's#databaseURL: "https://financesimple-7c73a-default-rtdb.europe-west1.firebasedatabase.app"#databaseURL: "https://test-invalid.invalid"#' index.test.html
sed -i 's/projectId: "financesimple-7c73a"/projectId: "test-invalid-project"/' index.test.html
grep -q "TEST-INVALID-KEY" index.test.html && echo "OK: test copy uses dummy Firebase config"
```

- [ ] **Step 4: Run it and verify**

```bash
chmod +x "/c/Users/user/Desktop/AI/ИИ ПОРТФОЛИО/Findr/v10/test/make-test-copy.sh"
bash "/c/Users/user/Desktop/AI/ИИ ПОРТФОЛИО/Findr/v10/test/make-test-copy.sh"
```

Expected output: `OK: test copy uses dummy Firebase config`. Confirm `v10/index.test.html` now exists.

- [ ] **Step 5: Commit**

```bash
cd "/c/Users/user/Desktop/AI/ИИ ПОРТФОЛИО/Findr/v10"
git add .gitignore test/make-test-copy.sh
git commit -m "chore: add safe test-copy script for Firebase-free browser verification"
```

---

### Task 1: Persist `reportPeriodStart`

**Files:**
- Modify: `v10/index.html:1173` (globals), `:1177` (`saveLocal`), `:1178` (`loadLocal`), `:1179` (`saveServer`), `:1165` (`subscribeToData`)

**Interfaces:**
- Produces: global `reportPeriodStart` (string ISO date, or `null`) — read by Task 2 (`filterTx`) and written by Task 5 (`doSubmitReport`)/Task 7 (`undoLastSubmit`).

- [ ] **Step 1: Write the failing test**

```bash
bash "/c/Users/user/Desktop/AI/ИИ ПОРТФОЛИО/Findr/v10/test/make-test-copy.sh"
```

Use the Playwright MCP tools: navigate to
`file:///C:/Users/user/Desktop/AI/ИИ%20ПОРТФОЛИО/Findr/v10/index.test.html`, then evaluate:

```js
() => {
  try {
    reportPeriodStart = '2026-01-01T12:00:00.000Z';
    saveLocal();
    return localStorage.getItem('fl_rps');
  } catch (e) { return 'ERROR: ' + e.message; }
}
```

- [ ] **Step 2: Run it, confirm it fails**

Expected: `ERROR: reportPeriodStart is not defined` (the variable does not exist yet).

- [ ] **Step 3: Implement**

In `v10/index.html`, change line 1173 from:
```js
let holders = {}, activeHolderId = null, activeAccountId = null, capital = 0, savedReports = {};
```
to:
```js
let holders = {}, activeHolderId = null, activeAccountId = null, capital = 0, savedReports = {}, reportPeriodStart = null;
```

In `saveLocal` (line 1177), add the new key to the existing chain of `localStorage.setItem(...)` calls — insert right after the `fl_reports` line:
```js
localStorage.setItem('fl_rps', reportPeriodStart || '');
```

In `loadLocal` (line 1178), add right after `savedReports = JSON.parse(localStorage.getItem('fl_reports') || '{}');`:
```js
reportPeriodStart = localStorage.getItem('fl_rps') || null;
```

In `saveServer` (line 1179), inside the `.update({...})` payload object, add a `reportPeriodStart` field next to `savedReports`:
```js
await firebase.database().ref(`users/${viewingOwner}`).update({ holders, activeHolderId, activeAccountId, capital, savedReports, reportPeriodStart, totalIncome: s.totalIncome, totalExpense: s.totalExpense, totalSpend: s.totalSpend, revenue: s.revenue, margin: s.margin, incomePercent, expensePercent, goalTarget, goalHistory, lastUpdated: new Date().toISOString(), lastUpdatedBy: firebaseUid });
```

In `subscribeToData` (line 1165), add right after `capital = d.capital || 0; savedReports = d.savedReports || {};`:
```js
reportPeriodStart = d.reportPeriodStart || null;
```

- [ ] **Step 4: Regenerate test copy, run test again, confirm it passes**

```bash
bash "/c/Users/user/Desktop/AI/ИИ ПОРТФОЛИО/Findr/v10/test/make-test-copy.sh"
```

Navigate Playwright to the test copy again, run the same evaluate snippet from Step 1.
Expected: returns `'2026-01-01T12:00:00.000Z'`.

- [ ] **Step 5: Test `loadLocal` round-trip**

```js
() => {
  localStorage.setItem('fl_rps', '2026-02-02T12:00:00.000Z');
  loadLocal();
  return reportPeriodStart;
}
```
Expected: `'2026-02-02T12:00:00.000Z'`.

Also test the unset case:
```js
() => {
  localStorage.removeItem('fl_rps');
  loadLocal();
  return reportPeriodStart;
}
```
Expected: `null`.

- [ ] **Step 6: Commit**

```bash
cd "/c/Users/user/Desktop/AI/ИИ ПОРТФОЛИО/Findr/v10"
git add index.html
git commit -m "feat: persist reportPeriodStart alongside capital/savedReports"
```

---

### Task 2: `filterTx` "since report" default branch

**Files:**
- Modify: `v10/index.html:1184` (`filterTx`)

**Interfaces:**
- Consumes: global `reportPeriodStart` (Task 1).
- Produces: `filterTx(txs, p)` — when `p === undefined`, now filters to transactions since `reportPeriodStart` (or returns all, if unset) instead of returning everything unconditionally. All explicit `p` values (`'today'|'week'|'month'|'custom'|'all'`) behave exactly as before.

- [ ] **Step 1: Write the failing test**

```bash
bash "/c/Users/user/Desktop/AI/ИИ ПОРТФОЛИО/Findr/v10/test/make-test-copy.sh"
```

Navigate to the test copy, evaluate:

```js
() => {
  reportPeriodStart = '2026-01-15T12:00:00.000Z';
  const txs = [
    { type: 'income', amount: 100, date: '2026-01-01T12:00:00.000Z' },
    { type: 'income', amount: 200, date: '2026-02-01T12:00:00.000Z' }
  ];
  return filterTx(txs, undefined).length;
}
```

- [ ] **Step 2: Run it, confirm it fails**

Expected today: `2` (both transactions returned — the Jan 1 one should have been excluded since it's before the Jan 15 cutoff). We want `1`.

- [ ] **Step 3: Implement**

Change `v10/index.html` line 1184 from:
```js
const filterTx = (txs, p) => { if (!txs || p === 'all') return txs || []; const now = new Date(), today = new Date(now.getFullYear(), now.getMonth(), now.getDate()); if (p === 'custom') { if (!detailCustomRange) return txs; const cs = new Date(detailCustomRange.start + 'T00:00:00'), ce = new Date(detailCustomRange.end + 'T23:59:59.999'); return txs.filter(t => { const d = new Date(t.date); return d >= cs && d <= ce; }); } let s; if (p === 'today') s = today; else if (p === 'week') { s = new Date(today); s.setDate(s.getDate() - 6); } else if (p === 'month') { s = new Date(today); s.setMonth(s.getMonth() - 1); } else return txs; return txs.filter(t => new Date(t.date) >= s); };
```
to:
```js
const filterTx = (txs, p) => { if (!txs) return []; if (p === undefined) { return reportPeriodStart ? txs.filter(t => new Date(t.date) >= new Date(reportPeriodStart)) : txs; } if (p === 'all') return txs; const now = new Date(), today = new Date(now.getFullYear(), now.getMonth(), now.getDate()); if (p === 'custom') { if (!detailCustomRange) return txs; const cs = new Date(detailCustomRange.start + 'T00:00:00'), ce = new Date(detailCustomRange.end + 'T23:59:59.999'); return txs.filter(t => { const d = new Date(t.date); return d >= cs && d <= ce; }); } let s; if (p === 'today') s = today; else if (p === 'week') { s = new Date(today); s.setDate(s.getDate() - 6); } else if (p === 'month') { s = new Date(today); s.setMonth(s.getMonth() - 1); } else return txs; return txs.filter(t => new Date(t.date) >= s); };
```

- [ ] **Step 4: Regenerate test copy, run test again, confirm it passes**

```bash
bash "/c/Users/user/Desktop/AI/ИИ ПОРТФОЛИО/Findr/v10/test/make-test-copy.sh"
```

Re-run the Step 1 evaluate snippet. Expected: `1`.

- [ ] **Step 5: Backward-compatibility and regression checks**

```js
() => {
  reportPeriodStart = null;
  const txs = [
    { type: 'income', amount: 100, date: '2026-01-01T12:00:00.000Z' },
    { type: 'income', amount: 200, date: '2026-02-01T12:00:00.000Z' }
  ];
  return filterTx(txs, undefined).length; // expect 2 — unset reportPeriodStart means "since the beginning"
}
```
```js
() => {
  reportPeriodStart = '2026-01-15T12:00:00.000Z';
  const txs = [
    { type: 'income', amount: 100, date: '2026-01-01T12:00:00.000Z' },
    { type: 'income', amount: 200, date: '2026-02-01T12:00:00.000Z' }
  ];
  return filterTx(txs, 'all').length; // expect 2 — explicit 'all' must ignore reportPeriodStart
}
```

Also re-test `calcAcc` directly, since it's the real call site that matters:
```js
() => {
  reportPeriodStart = '2026-01-15T12:00:00.000Z';
  const acc = { transactions: [
    { type: 'income', amount: 100, date: '2026-01-01T12:00:00.000Z' },
    { type: 'income', amount: 200, date: '2026-02-01T12:00:00.000Z' }
  ]};
  return calcAcc(acc).totalIncome; // expect 200
}
```

- [ ] **Step 6: Commit**

```bash
cd "/c/Users/user/Desktop/AI/ИИ ПОРТФОЛИО/Findr/v10"
git add index.html
git commit -m "feat: filterTx treats no-period calls as since-last-report, not lifetime"
```

---

### Task 3: Period-aware `calcAll` + sync «Детали» top summary to `detailPeriod`

**Files:**
- Modify: `v10/index.html:1191` (`calcAll`), `:1534` (`refreshDetail`)

**Interfaces:**
- Consumes: `calcAcc(acc, period)` (existing), global `detailPeriod` (existing).
- Produces: `calcAll(period)` — optional `period` param forwarded to each `calcAcc(a, period)` call. Called with no args (Главная/Отчёт, Task 2's effect) it's "since report"; called with an explicit period (new: «Детали»), spend/revenue/margin reflect that period while `totalBalance`/`siteBalance`/`capital` stay lifetime (unaffected by `period`, since they're summed from raw `a.balance`, not from `calcAcc`).

- [ ] **Step 1: Write the failing test**

```bash
bash "/c/Users/user/Desktop/AI/ИИ ПОРТФОЛИО/Findr/v10/test/make-test-copy.sh"
```

Navigate to the test copy, seed two accounts with transactions at different ages, then call `calcAll('week')`:

```js
() => {
  const oldDate = new Date(Date.now() - 40*86400000).toISOString();
  const recentDate = new Date(Date.now() - 2*86400000).toISOString();
  holders = { h1: { id: 'h1', name: 'H1', accounts: {
    a1: { id: 'a1', name: 'A1', balance: 500, transactions: [
      { type: 'income', amount: 1000, date: oldDate },
      { type: 'income', amount: 300, date: recentDate }
    ] }
  } } };
  reportPeriodStart = null;
  detailPeriod = 'week';
  const s = calcAll(detailPeriod);
  return { income: s.totalIncome, balance: s.totalBalance };
}
```

- [ ] **Step 2: Run it, confirm it fails**

Expected today: `calcAll` takes no parameters, so `calcAll(detailPeriod)` silently ignores the argument — `income` comes back `1300` (both transactions, lifetime) instead of the wanted `300` (week-only). `balance` already correctly returns `500` (this part doesn't need to change).

- [ ] **Step 3: Implement**

Change `v10/index.html` line 1191 from:
```js
const calcAll = () => { let inc = 0, exp = 0, spend = 0, bal = 0; Object.values(holders).forEach(h => { if (!h?.accounts) return; Object.values(h.accounts).forEach(a => { if (!a) return; const s = calcAcc(a); inc += s.totalIncome; exp += s.totalExpense; spend += s.totalSpend; bal += a.balance || 0; }); }); const rev = inc * (incomePercent / 100) + exp * (expensePercent / 100); return { totalIncome: inc, totalExpense: exp, totalSpend: spend, revenue: rev, margin: rev - spend, turnover: inc + exp, totalBalance: bal, siteBalance: capital - bal }; };
```
to:
```js
const calcAll = (period) => { let inc = 0, exp = 0, spend = 0, bal = 0; Object.values(holders).forEach(h => { if (!h?.accounts) return; Object.values(h.accounts).forEach(a => { if (!a) return; const s = calcAcc(a, period); inc += s.totalIncome; exp += s.totalExpense; spend += s.totalSpend; bal += a.balance || 0; }); }); const rev = inc * (incomePercent / 100) + exp * (expensePercent / 100); return { totalIncome: inc, totalExpense: exp, totalSpend: spend, revenue: rev, margin: rev - spend, turnover: inc + exp, totalBalance: bal, siteBalance: capital - bal }; };
```

Change `refreshDetail` (line 1534) from:
```js
const refreshDetail = () => { const s = calcAll(); ['detBalance', 'detCapital', 'detSite', 'detSpend', 'detRevenue'].forEach((id, i) => animateValue(document.getElementById(id), [s.totalBalance, capital, s.siteBalance, s.totalSpend, s.revenue][i], fmt)); const me = document.getElementById('detMargin'); animateValue(me, s.margin, fmt); s.margin < 0 ? me.classList.add('negative') : me.classList.remove('negative'); renderDetailTree(); renderCompare(); renderLeaderboard(); };
```
to:
```js
const refreshDetail = () => { const s = calcAll(detailPeriod); ['detBalance', 'detCapital', 'detSite', 'detSpend', 'detRevenue'].forEach((id, i) => animateValue(document.getElementById(id), [s.totalBalance, capital, s.siteBalance, s.totalSpend, s.revenue][i], fmt)); const me = document.getElementById('detMargin'); animateValue(me, s.margin, fmt); s.margin < 0 ? me.classList.add('negative') : me.classList.remove('negative'); renderDetailTree(); renderCompare(); renderLeaderboard(); };
```

Do **not** change any other call site of `calcAll()` (`refreshReport`, `doShareCurrentReport`, `shareDetail`, `openSetGoal`, the report-saving functions in Task 5) — they must keep calling it with no arguments, so they keep showing "since report" numbers per Task 2.

- [ ] **Step 4: Regenerate test copy, run test again, confirm it passes**

```bash
bash "/c/Users/user/Desktop/AI/ИИ ПОРТФОЛИО/Findr/v10/test/make-test-copy.sh"
```

Re-run the Step 1 snippet. Expected: `{ income: 300, balance: 500 }`.

- [ ] **Step 5: Confirm «Все» period still shows full lifetime history (the feature's core promise)**

```js
() => {
  const oldDate = new Date(Date.now() - 400*86400000).toISOString();
  holders = { h1: { id: 'h1', name: 'H1', accounts: {
    a1: { id: 'a1', name: 'A1', balance: 0, transactions: [ { type: 'income', amount: 999, date: oldDate } ] }
  } } };
  reportPeriodStart = new Date().toISOString(); // simulate "just submitted a report" — since-report would be 0
  const sinceReport = calcAll().totalIncome;
  const allTime = calcAll('all').totalIncome;
  return { sinceReport, allTime };
}
```
Expected: `{ sinceReport: 0, allTime: 999 }` — proves the live summary resets while «Детали» → «Все» still shows everything.

- [ ] **Step 6: Confirm the real UI wiring (`setPeriod`) updates the DOM**

```js
() => {
  switchPage('detail');
  window.setPeriod('week');
  return document.getElementById('detSpend').textContent;
}
```
Expected: a rendered value (not throwing); spot-check it changes when you call `window.setPeriod('all')` afterward and re-read the same element.

- [ ] **Step 7: Commit**

```bash
cd "/c/Users/user/Desktop/AI/ИИ ПОРТФОЛИО/Findr/v10"
git add index.html
git commit -m "feat: calcAll accepts a period; Детали top summary follows the date filter"
```

---

### Task 4: Report-choice bottom sheet (markup + open/close)

**Files:**
- Modify: `v10/index.html:522` (`fixReportBtn` onclick), `:712-713` (insert new sheet markup), `:1709` area (insert `openReportChoice`/`closeReportChoice`)

**Interfaces:**
- Consumes: `canEdit()` (existing, `v10/index.html:1042`), `haptic()` (existing).
- Produces: `window.openReportChoice()`, `window.closeReportChoice()` — DOM ids `reportChoiceOverlay`, `reportChoiceSheet`. Task 5 wires the two action buttons inside this sheet to real functions; until Task 5 lands, those two buttons reference functions that don't exist yet — acceptable for this task, which only tests open/close.

- [ ] **Step 1: Write the failing test**

```bash
bash "/c/Users/user/Desktop/AI/ИИ ПОРТФОЛИО/Findr/v10/test/make-test-copy.sh"
```

Navigate to the test copy, evaluate:
```js
() => {
  switchPage('report');
  document.getElementById('fixReportBtn').click();
  return document.getElementById('reportChoiceSheet') ? document.getElementById('reportChoiceSheet').classList.contains('active') : 'NO_SHEET';
}
```

- [ ] **Step 2: Run it, confirm it fails**

Expected today: `'NO_SHEET'` (the element doesn't exist; clicking the button currently calls `doFixReport()` directly).

- [ ] **Step 3: Implement — markup**

In `v10/index.html`, insert the new overlay/sheet between the closing `</div>` of `capitalAdjSheet` and the start of `permOverlay` — i.e. change:
```html
<button class="btn btn-secondary" onclick="closeCapitalAdjustment()" style="margin-top:8px;">Отмена</button>
</div>
<div class="sheet-overlay" id="permOverlay" onclick="closePermSheet()"></div>
```
to:
```html
<button class="btn btn-secondary" onclick="closeCapitalAdjustment()" style="margin-top:8px;">Отмена</button>
</div>
<div class="sheet-overlay" id="reportChoiceOverlay" onclick="closeReportChoice()"></div>
<div class="bottom-sheet" id="reportChoiceSheet">
<div class="sheet-handle"></div>
<div class="sheet-title">Зафиксировать показатели</div>
<div class="setting-hint" style="text-align:center;margin-bottom:12px;">«Сдать отчёт» сбросит на экране оборот, доходы, расходы, выручку, траты и маржу до 0 — начнётся новый отчётный период. Балансы счетов и капитал не изменятся. Полная история останется доступна в «Деталях».</div>
<button class="btn btn-primary" onclick="doSubmitReport()" style="margin-top:8px;">Сдать отчёт</button>
<button class="btn btn-secondary" onclick="doJustFixReport()" style="margin-top:8px;">Просто зафиксировать</button>
<button class="btn btn-secondary" onclick="closeReportChoice()" style="margin-top:8px;">Отмена</button>
</div>
<div class="sheet-overlay" id="permOverlay" onclick="closePermSheet()"></div>
```

- [ ] **Step 4: Implement — open/close JS**

In `v10/index.html`, immediately before the `const doFixReport = () => {...}` line (line 1709), insert:
```js
window.openReportChoice = () => { if (!canEdit()) return; document.getElementById('reportChoiceOverlay').classList.add('active'); document.getElementById('reportChoiceSheet').classList.add('active'); haptic('light'); };
window.closeReportChoice = () => { document.getElementById('reportChoiceOverlay').classList.remove('active'); document.getElementById('reportChoiceSheet').classList.remove('active'); };
```

- [ ] **Step 5: Implement — wire the button**

Change line 522 from:
```html
<button class="btn btn-primary" id="fixReportBtn" onclick="doFixReport()"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 2L12 14"/><path d="M9 5L12 2L15 5"/><circle cx="12" cy="18" r="2" fill="currentColor"/></svg>Зафиксировать</button>
```
to:
```html
<button class="btn btn-primary" id="fixReportBtn" onclick="openReportChoice()"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 2L12 14"/><path d="M9 5L12 2L15 5"/><circle cx="12" cy="18" r="2" fill="currentColor"/></svg>Зафиксировать</button>
```

(`doFixReport` itself is renamed/replaced in Task 5 — leave its current body in place for now; it's simply no longer called by the button.)

- [ ] **Step 6: Regenerate test copy, run test again, confirm it passes**

```bash
bash "/c/Users/user/Desktop/AI/ИИ ПОРТФОЛИО/Findr/v10/test/make-test-copy.sh"
```

Re-run the Step 1 snippet. Expected: `true`.

- [ ] **Step 7: Confirm close works and the permission gate holds**

```js
() => { closeReportChoice(); return document.getElementById('reportChoiceSheet').classList.contains('active'); } // expect false
```
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

- [ ] **Step 8: Commit**

```bash
cd "/c/Users/user/Desktop/AI/ИИ ПОРТФОЛИО/Findr/v10"
git add index.html
git commit -m "feat: add Сдать отчёт / Просто зафиксировать choice sheet"
```

---

### Task 5: `doSubmitReport()` and `doJustFixReport()`

**Files:**
- Modify: `v10/index.html:1709` (replace `doFixReport`)

**Interfaces:**
- Consumes: `calcAll()` (Task 3, called with no args → since-report numbers), `reportPeriodStart` (Task 1), `closeReportChoice()` (Task 4), `canEdit()`, `saveLocal()`, `saveServer()`, `renderAll()`, `haptic()`, `showToast()`, `icon()`.
- Produces: `window.doSubmitReport()`, `window.doJustFixReport()`, and the shared helper `saveReportSnapshot(extra)`. `savedReports[key]` entries now always carry a `type: 'submit' | 'fix'` field; `'submit'` entries also carry `periodStart` (the `reportPeriodStart` value in effect *before* this submission — `null` if there wasn't one). Task 6 reads `type`/`periodStart`; Task 7 reads `periodStart` to undo.

- [ ] **Step 1: Write the failing test**

```bash
bash "/c/Users/user/Desktop/AI/ИИ ПОРТФОЛИО/Findr/v10/test/make-test-copy.sh"
```

Navigate to the test copy, seed minimal state, then call the not-yet-existing function:

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

- [ ] **Step 2: Run it, confirm it fails**

Expected today: `{ error: 'doSubmitReport is not defined', count: 0 }`.

- [ ] **Step 3: Implement**

Replace the `const doFixReport = () => {...}` line at `v10/index.html:1709` with:
```js
const saveReportSnapshot = (extra) => { const s = calcAll(), now = new Date(), key = now.toISOString().replace(/[:.]/g, '-').slice(0, 19); savedReports[key] = Object.assign({ date: now.toISOString(), turnover: s.turnover, income: s.totalIncome, expense: s.totalExpense, spend: s.totalSpend, revenue: s.revenue, margin: s.margin, balance: s.totalBalance, capital, siteBalance: s.siteBalance }, extra); return key; };
window.doJustFixReport = () => { if (!canEdit()) return; saveReportSnapshot({ type: 'fix' }); saveLocal(); saveServer(); closeReportChoice(); renderAll(); haptic('success'); showToast(icon('check',20),'Отчёт сохранён'); };
window.doSubmitReport = () => { if (!canEdit()) return; const periodStart = reportPeriodStart; saveReportSnapshot({ type: 'submit', periodStart }); reportPeriodStart = new Date().toISOString(); saveLocal(); saveServer(); closeReportChoice(); renderAll(); haptic('success'); showToast(icon('check',20),'Отчёт сдан, период сброшен'); };
```

This is the one place where ordering matters: `saveReportSnapshot` is called **before** `reportPeriodStart` is advanced, so `calcAll()` inside it still computes the *closing* period's totals (since the old `reportPeriodStart`), not the new, empty one.

- [ ] **Step 4: Regenerate test copy, run test again, confirm it passes**

```bash
bash "/c/Users/user/Desktop/AI/ИИ ПОРТФОЛИО/Findr/v10/test/make-test-copy.sh"
```

Re-run the Step 1 snippet. Expected: `{ error: null, count: 1 }`.

- [ ] **Step 5: Verify full submit behavior**

```js
() => {
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
Expected: `{ type: 'submit', periodStart: null, income: 1000, nowIsRecent: true, liveIncomeAfterSubmit: 0 }` — the snapshot captured the closing period correctly, and the live number is now reset.

- [ ] **Step 6: Verify «Просто зафиксировать» does NOT reset anything**

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
Expected: `{ type: 'fix', periodStartAfter: null, liveIncomeAfter: 777 }`.

- [ ] **Step 7: Commit**

```bash
cd "/c/Users/user/Desktop/AI/ИИ ПОРТФОЛИО/Findr/v10"
git add index.html
git commit -m "feat: doSubmitReport closes the period, doJustFixReport snapshots without resetting"
```

---

### Task 6: History badges + date-range display

**Files:**
- Modify: `v10/index.html:1532` (`renderReportsList`), `:1712` (`shareReport`)

**Interfaces:**
- Consumes: `savedReports[key].type`/`.periodStart` (Task 5), `MONTHS` (existing).
- Produces: `fmtDateShort(iso)` helper, reused by both `renderReportsList` and `shareReport`.

- [ ] **Step 1: Write the failing test**

```bash
bash "/c/Users/user/Desktop/AI/ИИ ПОРТФОЛИО/Findr/v10/test/make-test-copy.sh"
```

Navigate to the test copy, evaluate:
```js
() => {
  savedReports = {
    k1: { date: '2026-06-23T12:00:00.000Z', type: 'submit', periodStart: '2026-06-15T12:00:00.000Z', turnover: 100, income: 60, expense: 40, spend: 10, revenue: 5, margin: -5, balance: 0, capital: 0, siteBalance: 0 },
    k2: { date: '2026-06-10T12:00:00.000Z', type: 'fix', turnover: 50, income: 30, expense: 20, spend: 5, revenue: 2, margin: -3, balance: 0, capital: 0, siteBalance: 0 }
  };
  renderReportsList();
  const cards = document.querySelectorAll('#reportsList .report-card');
  return Array.from(cards).map(c => c.querySelector('.report-date').textContent);
}
```

- [ ] **Step 2: Run it, confirm it fails**

Expected today: `["23 июн 2026", "10 июн 2026"]` (single dates only — no range, no badge text in `.report-date`).

- [ ] **Step 3: Implement**

Insert this helper immediately before `const renderReportsList = ...` (line 1532):
```js
const fmtDateShort = (iso) => { const d = new Date(iso); return `${d.getDate()} ${MONTHS[d.getMonth()]} ${d.getFullYear()}`; };
```

Replace the `const renderReportsList = ...` line with:
```js
const renderReportsList = () => { const list = document.getElementById('reportsList'), keys = Object.keys(savedReports).sort().reverse(); if (!keys.length) { list.innerHTML = '<div class="empty-state"><div class="empty-text">Нет отчётов</div></div>'; return; } list.innerHTML = ''; keys.forEach(key => { const r = savedReports[key]; if (!r) return; const d = new Date(r.date), sp = r.spend || 0, mg = r.margin ?? ((r.revenue || 0) - sp); const isSubmit = r.type === 'submit'; const dateLabel = isSubmit ? `${r.periodStart ? fmtDateShort(r.periodStart) : 'С начала'} – ${fmtDateShort(r.date)}` : fmtDateShort(r.date); const badge = isSubmit ? `<span style="display:inline-flex;font-size:0.65rem;font-weight:600;color:var(--ios-green);background:rgba(52,199,89,0.12);padding:2px 8px;border-radius:100px;margin-top:2px;">Сдан</span>` : `<span style="display:inline-flex;font-size:0.65rem;font-weight:600;color:var(--ios-text-secondary);background:rgba(120,120,128,0.12);padding:2px 8px;border-radius:100px;margin-top:2px;">Фиксация</span>`; const c = document.createElement('div'); c.className = 'report-card'; c.innerHTML = `<div class="report-header"><div><div class="report-date">${dateLabel}</div><div class="report-time">${d.toLocaleTimeString('ru-RU', { hour: '2-digit', minute: '2-digit' })}</div>${badge}</div><div class="report-actions"><button class="report-action share" onclick="shareReport('${key}')"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="18" cy="5" r="3"/><circle cx="6" cy="12" r="3"/><circle cx="18" cy="19" r="3"/><line x1="8.59" y1="13.51" x2="15.42" y2="17.49"/><line x1="15.41" y1="6.51" x2="8.59" y2="10.49"/></svg></button>${canDelete() ? `<button class="report-action delete" onclick="deleteReport('${key}')"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/></svg></button>` : ''}</div></div><div class="report-stats"><div class="report-stat"><span class="report-stat-label">${icon('chartUp',15,'#007AFF')}</span><span class="report-stat-value text-blue">${fmt(r.turnover)}</span></div><div class="report-stat"><span class="report-stat-label">${icon('money',15,'#FF9500')}</span><span class="report-stat-value text-orange">${fmt(r.revenue)}</span></div><div class="report-stat"><span class="report-stat-label">${icon('dot',15,'#34C759')}</span><span class="report-stat-value text-green">${fmt(r.income)}</span></div><div class="report-stat"><span class="report-stat-label">${icon('dot',15,'#FF3B30')}</span><span class="report-stat-value text-red">${fmt(r.expense)}</span></div><div class="report-stat"><span class="report-stat-label">${icon('bag',15,'#AF52DE')}</span><span class="report-stat-value text-purple">${fmt(sp)}</span></div><div class="report-stat"><span class="report-stat-label">${icon('trendUp2',15,'#5AC8FA')}</span><span class="report-stat-value text-teal">${fmt(mg)}</span></div></div>`; list.appendChild(c); }); };
```

Replace `window.shareReport` (line 1712) from:
```js
window.shareReport = (key) => { const r = savedReports[key]; if (!r) return; const d = new Date(r.date); shareText(`📊 Отчёт Findr\n📅 ${d.getDate()} ${MONTHS[d.getMonth()]} ${d.getFullYear()}\n💹 Оборот: ${fmt(r.turnover)}\n💰 Выручка: ${fmt(r.revenue)}\n📈 Маржа: ${fmt(r.margin ?? (r.revenue - (r.spend || 0)))}`, 'Отчёт Findr'); };
```
to:
```js
window.shareReport = (key) => { const r = savedReports[key]; if (!r) return; const dateLine = r.type === 'submit' ? `${r.periodStart ? fmtDateShort(r.periodStart) : 'с начала'} – ${fmtDateShort(r.date)}` : fmtDateShort(r.date); shareText(`📊 Отчёт Findr\n📅 ${dateLine}\n💹 Оборот: ${fmt(r.turnover)}\n💰 Выручка: ${fmt(r.revenue)}\n📈 Маржа: ${fmt(r.margin ?? (r.revenue - (r.spend || 0)))}`, 'Отчёт Findr'); };
```

- [ ] **Step 4: Regenerate test copy, run test again, confirm it passes**

```bash
bash "/c/Users/user/Desktop/AI/ИИ ПОРТФОЛИО/Findr/v10/test/make-test-copy.sh"
```

Re-run the Step 1 snippet. Expected: `["15 июн 2026 – 23 июн 2026", "10 июн 2026"]`.

- [ ] **Step 5: Verify badges and legacy (no-`type`) entries**

```js
() => {
  savedReports.k3 = { date: '2026-06-01T12:00:00.000Z', turnover: 1, income: 1, expense: 0, spend: 0, revenue: 0, margin: 0, balance: 0, capital: 0, siteBalance: 0 }; // legacy entry, no `type`
  renderReportsList();
  const cards = document.querySelectorAll('#reportsList .report-card');
  return Array.from(cards).map(c => c.querySelector('.report-header > div > span')?.textContent);
}
```
Expected: `["Сдан", "Фиксация", "Фиксация"]` (legacy entry without `type` defaults to "Фиксация", not a crash).

- [ ] **Step 6: Commit**

```bash
cd "/c/Users/user/Desktop/AI/ИИ ПОРТФОЛИО/Findr/v10"
git add index.html
git commit -m "feat: badge and date-range display for submitted vs fixed reports"
```

---

### Task 7: Undo last submission

**Files:**
- Modify: `v10/index.html:525` (`lastFixedBadge` markup), `:1533` (`checkLastFixed`), insert `undoLastSubmit` near `doSubmitReport`

**Interfaces:**
- Consumes: `savedReports`/`reportPeriodStart` (Task 1, 5), `safeConfirm()` (existing, `v10/index.html:744`), `canEdit()`.
- Produces: `window.undoLastSubmit()` — only acts when the most recent `savedReports` entry has `type === 'submit'`.

- [ ] **Step 1: Write the failing test**

```bash
bash "/c/Users/user/Desktop/AI/ИИ ПОРТФОЛИО/Findr/v10/test/make-test-copy.sh"
```

Navigate to the test copy, evaluate:
```js
() => {
  savedReports = { k1: { date: new Date().toISOString(), type: 'submit', periodStart: '2026-01-01T12:00:00.000Z', turnover: 0, income: 0, expense: 0, spend: 0, revenue: 0, margin: 0, balance: 0, capital: 0, siteBalance: 0 } };
  reportPeriodStart = new Date().toISOString();
  checkLastFixed();
  return document.getElementById('lastFixedUndo') ? document.getElementById('lastFixedUndo').style.display : 'NO_BUTTON';
}
```

- [ ] **Step 2: Run it, confirm it fails**

Expected today: `'NO_BUTTON'` (the element doesn't exist yet).

- [ ] **Step 3: Implement — markup**

Change `v10/index.html` line 525 from:
```html
<div id="lastFixedBadge" style="display:none;background:rgba(52,199,89,0.12);border-radius:12px;padding:12px;margin-bottom:16px;font-size:0.8rem;color:var(--ios-green);font-weight:500;align-items:center;gap:6px;"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg>Последний: <span id="lastFixedDate"></span></div>
```
to:
```html
<div id="lastFixedBadge" style="display:none;background:rgba(52,199,89,0.12);border-radius:12px;padding:12px;margin-bottom:16px;font-size:0.8rem;color:var(--ios-green);font-weight:500;align-items:center;gap:6px;justify-content:space-between;"><div style="display:flex;align-items:center;gap:6px;"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg>Последний: <span id="lastFixedDate"></span></div><button id="lastFixedUndo" onclick="undoLastSubmit()" style="display:none;background:none;border:none;color:var(--ios-green);font-weight:600;font-size:0.8rem;text-decoration:underline;cursor:pointer;padding:0;">Отменить</button></div>
```

- [ ] **Step 4: Implement — `checkLastFixed` + `undoLastSubmit`**

Change `checkLastFixed` (line 1533) from:
```js
const checkLastFixed = () => { const keys = Object.keys(savedReports).sort().reverse(), b = document.getElementById('lastFixedBadge'); if (keys.length) { const d = new Date(savedReports[keys[0]].date); document.getElementById('lastFixedDate').textContent = `${d.getDate()} ${MONTHS[d.getMonth()]} ${d.getFullYear()}`; b.style.display = 'flex'; } else b.style.display = 'none'; };
```
to:
```js
const checkLastFixed = () => { const keys = Object.keys(savedReports).sort().reverse(), b = document.getElementById('lastFixedBadge'), undoBtn = document.getElementById('lastFixedUndo'); if (keys.length) { const last = savedReports[keys[0]], d = new Date(last.date); document.getElementById('lastFixedDate').textContent = `${d.getDate()} ${MONTHS[d.getMonth()]} ${d.getFullYear()}`; b.style.display = 'flex'; undoBtn.style.display = last.type === 'submit' ? 'inline' : 'none'; } else { b.style.display = 'none'; } };
```

Insert immediately after `window.doSubmitReport = ...` (Task 5's line):
```js
window.undoLastSubmit = () => { if (!canEdit()) return; const keys = Object.keys(savedReports).sort().reverse(); if (!keys.length) return; const key = keys[0], entry = savedReports[key]; if (entry.type !== 'submit') return; const undo = () => { reportPeriodStart = entry.periodStart; delete savedReports[key]; saveLocal(); saveServer(); renderAll(); haptic('success'); showToast(icon('check',20),'Сдача отчёта отменена'); }; safeConfirm('Отменить последнюю сдачу отчёта? Показатели вернутся к состоянию до сдачи.', undo); };
```

(`renderAll()` already calls `renderReport` → `refreshReport`, which already calls `renderReportsList()` and `checkLastFixed()` — no need to call them again here.)

- [ ] **Step 5: Regenerate test copy, run test again, confirm it passes**

```bash
bash "/c/Users/user/Desktop/AI/ИИ ПОРТФОЛИО/Findr/v10/test/make-test-copy.sh"
```

Re-run the Step 1 snippet. Expected: `'inline'`.

- [ ] **Step 6: Verify the undo flow end-to-end**

Use `browser_handle_dialog` to auto-accept the upcoming `confirm()` (the test copy has no Telegram SDK, so `safeConfirm` falls back to native `confirm()`), then evaluate:
```js
() => {
  savedReports = { k1: { date: new Date().toISOString(), type: 'submit', periodStart: '2026-01-01T12:00:00.000Z', turnover: 0, income: 0, expense: 0, spend: 0, revenue: 0, margin: 0, balance: 0, capital: 0, siteBalance: 0 } };
  reportPeriodStart = new Date().toISOString();
  undoLastSubmit();
  return { remaining: Object.keys(savedReports).length, restoredPeriodStart: reportPeriodStart };
}
```
Expected: `{ remaining: 0, restoredPeriodStart: '2026-01-01T12:00:00.000Z' }`.

- [ ] **Step 7: Verify the negative case (most recent entry is a plain "fix")**

```js
() => {
  savedReports = { k1: { date: new Date().toISOString(), type: 'fix', turnover: 0, income: 0, expense: 0, spend: 0, revenue: 0, margin: 0, balance: 0, capital: 0, siteBalance: 0 } };
  checkLastFixed();
  return document.getElementById('lastFixedUndo').style.display;
}
```
Expected: `'none'`.

- [ ] **Step 8: Commit**

```bash
cd "/c/Users/user/Desktop/AI/ИИ ПОРТФОЛИО/Findr/v10"
git add index.html
git commit -m "feat: allow undoing the most recent report submission"
```

---

### Task 8: Visible current period label

**Files:**
- Modify: `v10/index.html:516-517` (insert label markup), `:1530` (`refreshReport`)

**Interfaces:**
- Consumes: `reportPeriodStart` (Task 1), `fmtDateShort` (Task 6).
- Produces: `reportPeriodLabel()` helper + `#currentPeriodLabel` DOM text, refreshed every `refreshReport()` call.

- [ ] **Step 1: Write the failing test**

```bash
bash "/c/Users/user/Desktop/AI/ИИ ПОРТФОЛИО/Findr/v10/test/make-test-copy.sh"
```

Navigate to the test copy, evaluate:
```js
() => {
  reportPeriodStart = null;
  refreshReport();
  return document.getElementById('currentPeriodLabel') ? document.getElementById('currentPeriodLabel').textContent : 'NO_LABEL';
}
```

- [ ] **Step 2: Run it, confirm it fails**

Expected today: `'NO_LABEL'`.

- [ ] **Step 3: Implement — markup**

Change `v10/index.html` lines 516-517 from:
```html
</div></div>
<div class="report-actions-group">
```
to:
```html
</div></div>
<div id="currentPeriodLabel" style="text-align:center;font-size:0.75rem;color:var(--ios-text-secondary);margin:-4px 0 14px;"></div>
<div class="report-actions-group">
```

- [ ] **Step 4: Implement — label logic**

Insert immediately before `const refreshReport = ...` (line 1530):
```js
const ruDays = (n) => { const mod10 = n % 10, mod100 = n % 100; if (mod10 === 1 && mod100 !== 11) return 'день'; if ([2,3,4].includes(mod10) && ![12,13,14].includes(mod100)) return 'дня'; return 'дней'; };
const reportPeriodLabel = () => { if (!reportPeriodStart) return 'Текущий период: за всё время'; const days = Math.max(1, Math.ceil((Date.now() - new Date(reportPeriodStart).getTime()) / 86400000)); return `Текущий период: с ${fmtDateShort(reportPeriodStart)} · ${days} ${ruDays(days)}`; };
```

Change `refreshReport` (line 1530) from:
```js
const refreshReport = () => { const s = calcAll(); ['sumTurnover', 'sumRevenue', 'sumIncome', 'sumExpense', 'sumSpend', 'sumBalance', 'sumCapital', 'sumSite'].forEach((id, i) => animateValue(document.getElementById(id), [s.turnover, s.revenue, s.totalIncome, s.totalExpense, s.totalSpend, s.totalBalance, capital, s.siteBalance][i], fmt)); const me = document.getElementById('sumMargin'); animateValue(me, s.margin, fmt); s.margin < 0 ? me.classList.add('negative') : me.classList.remove('negative'); renderReportsList(); checkLastFixed(); };
```
to:
```js
const refreshReport = () => { const s = calcAll(); ['sumTurnover', 'sumRevenue', 'sumIncome', 'sumExpense', 'sumSpend', 'sumBalance', 'sumCapital', 'sumSite'].forEach((id, i) => animateValue(document.getElementById(id), [s.turnover, s.revenue, s.totalIncome, s.totalExpense, s.totalSpend, s.totalBalance, capital, s.siteBalance][i], fmt)); const me = document.getElementById('sumMargin'); animateValue(me, s.margin, fmt); s.margin < 0 ? me.classList.add('negative') : me.classList.remove('negative'); document.getElementById('currentPeriodLabel').textContent = reportPeriodLabel(); renderReportsList(); checkLastFixed(); };
```

- [ ] **Step 5: Regenerate test copy, run test again, confirm it passes**

```bash
bash "/c/Users/user/Desktop/AI/ИИ ПОРТФОЛИО/Findr/v10/test/make-test-copy.sh"
```

Re-run the Step 1 snippet. Expected: `'Текущий период: за всё время'`.

- [ ] **Step 6: Verify the day-count and pluralization**

```js
() => {
  const results = {};
  [1, 3, 9, 21].forEach(n => {
    reportPeriodStart = new Date(Date.now() - n*86400000 - 3600000).toISOString(); // n days + 1h ago, avoids rounding edge
    refreshReport();
    results[n] = document.getElementById('currentPeriodLabel').textContent;
  });
  return results;
}
```
Expected: keys map to strings ending in `1 день`, `3 дня`, `9 дней`, `21 день` respectively (exact leading date text will vary by run date — only the trailing "N <word>" needs checking).

- [ ] **Step 7: Commit**

```bash
cd "/c/Users/user/Desktop/AI/ИИ ПОРТФОЛИО/Findr/v10"
git add index.html
git commit -m "feat: show current report period and its length on the Отчёт page"
```

---

## Manual smoke test (after all tasks land)

Automated steps above all run against `index.test.html` (dummy Firebase config) to avoid touching production data. Before considering the feature done, do one manual pass in the **real** `index.html`/PWA (as the owner normally uses it — Telegram or browser) to confirm: opening «Отчёт», clicking «Зафиксировать» shows the choice sheet, «Сдать отчёт» zeroes the summary and the period label, the history card shows a green «Сдан» badge with a date range, «Отменить» reverts it, and «Детали» → «Все» still shows full historical numbers. This step is on the human, not automatable safely given the live Firebase backend.
