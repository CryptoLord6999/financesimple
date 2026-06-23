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

