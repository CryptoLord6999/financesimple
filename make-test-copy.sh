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
sed -i 's/financesimple-7c73a/test-invalid-project/g' index.test.html
grep -q "TEST-INVALID-KEY" index.test.html && ! grep -q "financesimple-7c73a" index.test.html && echo "OK: test copy uses dummy Firebase config"
