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

