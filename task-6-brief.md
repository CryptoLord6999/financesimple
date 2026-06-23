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

