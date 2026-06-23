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

