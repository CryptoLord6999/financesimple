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

