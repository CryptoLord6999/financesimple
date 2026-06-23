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

