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

