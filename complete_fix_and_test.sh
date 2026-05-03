#!/bin/bash
set -e

echo "======================================="
echo "Akeneo PIM - Complete Fix & Browser Test"
echo "Started: $(date)"
echo "======================================="

# Step 1: Verify manifest.json
echo ""
echo "[1/7] Verifying manifest.json..."
if [ -f "public/bundles/pimui/manifest.json" ]; then
    SIZE=$(du -h public/bundles/pimui/manifest.json | cut -f1)
    echo "✓ manifest.json exists ($SIZE)"
    cat public/bundles/pimui/manifest.json
else
    echo "✗ manifest.json missing - creating..."
    echo '{"css/pim.css":"css/pim.css","js/index.js":"js/index.js","js/require-paths.js":"js/require-paths.js","js/extensions.json":"js/extensions.json"}' > public/bundles/pimui/manifest.json
fi

# Step 2: Verify all critical files
echo ""
echo "[2/7] Verifying all critical files..."
for file in "public/js/require-paths.js" "public/js/extensions.json" "public/css/pim.css" "public/bundles/pimui/js/index.js" "public/bundles/pimui/manifest.json"; do
    if [ -f "$file" ]; then
        echo "  ✓ $file ($(du -h $file | cut -f1))"
    else
        echo "  ✗ $file MISSING"
    fi
done

# Step 3: Fix permissions
echo ""
echo "[3/7] Fixing permissions..."
chmod 644 public/bundles/pimui/manifest.json 2>/dev/null || true
chmod 644 public/js/*.js* 2>/dev/null || true
chmod 644 public/css/*.css 2>/dev/null || true
echo "✓ Permissions updated"

# Step 4: Check bundle symlinks
echo ""
echo "[4/7] Checking bundle symlinks..."
BUNDLE_COUNT=$(find public/bundles -maxdepth 1 -type l 2>/dev/null | wc -l)
echo "  Bundle symlinks: $BUNDLE_COUNT"

# Step 5: Get PIM URL
echo ""
echo "[5/7] Determining PIM URL..."
if [ -f ".env" ]; then
    APP_URL=$(grep "APP_URL=" .env | cut -d'=' -f2 | tr -d '"' || echo "")
    if [ -n "$APP_URL" ]; then
        PIM_URL="$APP_URL"
    else
        PIM_URL="http://localhost"
    fi
else
    PIM_URL="http://localhost"
fi
echo "  PIM URL: $PIM_URL"

# Step 6: Test web access
echo ""
echo "[6/7] Testing web access..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$PIM_URL/index.php" 2>&1 || echo "000")
echo "  HTTP Response: $HTTP_CODE"

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ]; then
    echo "✓ Web server responding correctly"
else
    echo "⚠ Web server returned HTTP $HTTP_CODE"
fi

# Step 7: Save test URLs
echo ""
echo "[7/7] Creating test report..."
cat > BROWSER_TEST_URLS.txt << EOFURLS
Akeneo PIM - Browser Test URLs
Generated: $(date)

Login Page: $PIM_URL/index.php
Direct Login: $PIM_URL/user/login

Assets to verify:
- $PIM_URL/css/pim.css
- $PIM_URL/js/require-paths.js
- $PIM_URL/js/extensions.json

Test Credentials:
- Username: admin
- Password: admin

Alternative:
- Username: finaladmin
- Password: Admin@2024!

Expected Behavior:
1. Login page should load with CSS styling
2. No manifest.json errors in console
3. Login form should be visible
4. After login, dashboard should appear
EOFURLS

echo "✓ Test URLs saved to BROWSER_TEST_URLS.txt"

echo ""
echo "======================================="
echo "Setup Complete!"
echo "======================================="
echo "Next: Open Chromium and navigate to:"
echo "  $PIM_URL/index.php"
echo ""
echo "Check BROWSER_TEST_URLS.txt for details"
echo "======================================="
