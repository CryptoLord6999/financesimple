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

