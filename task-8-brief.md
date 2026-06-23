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
