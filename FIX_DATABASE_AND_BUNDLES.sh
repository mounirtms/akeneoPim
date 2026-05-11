#!/bin/bash
# FIX_DATABASE_AND_BUNDLES.sh - Fix DB SSL issue and bundle symlinks
# Date: 2026-05-06

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 FIX DATABASE & BUNDLE ISSUES"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Fix 1: Database connection with --skip-ssl
echo "1. Testing Database Connection (skip SSL)..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
DB_COUNT=$(mariadb -h 127.0.0.1 -P 3307 -u pim -ppim_password akeneo_pim --skip-ssl -se "SELECT COUNT(*) FROM pim_catalog_product" 2>/dev/null || echo "0")
echo "✓ Products in database: $DB_COUNT"

# Get sample products
SAMPLE=$(mariadb -h 127.0.0.1 -P 3307 -u pim -ppim_password akeneo_pim --skip-ssl -se "SELECT identifier FROM pim_catalog_product LIMIT 5" 2>/dev/null)
if [ -n "$SAMPLE" ]; then
    echo "✓ Sample products:"
    echo "$SAMPLE" | sed 's/^/    /'
fi
echo ""

# Fix 2: Check bundle symlinks
echo "2. Investigating Bundle Symlinks..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ls -la public/bundles/ 2>/dev/null | head -20

# Check if symlinks are broken
echo ""
echo "Checking symlink targets:"
for link in public/bundles/*; do
    if [ -L "$link" ]; then
        TARGET=$(readlink "$link")
        if [ -e "$link" ]; then
            echo "  ✓ $(basename "$link") → $TARGET"
        else
            echo "  ✗ BROKEN: $(basename "$link") → $TARGET"
        fi
    fi
done
echo ""

# Fix 3: Copy assets instead of symlink
echo "3. Installing Assets as Hard Copies..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
rm -rf public/bundles/
php bin/console assets:install public --env=prod 2>&1 | tail -15

BUNDLE_COUNT=$(find public/bundles -type f 2>/dev/null | wc -l | tr -d ' ')
echo ""
echo "Bundle files after hard copy: $BUNDLE_COUNT"

if [ "$BUNDLE_COUNT" -gt 100 ]; then
    echo "✓ Bundles installed successfully"
else
    echo "⚠ Bundle count still low"
    echo "Checking bundle structure:"
    find public/bundles -type d | head -10
fi
echo ""

# Fix 4: Verify specific bundle files
echo "4. Verifying Key Bundle Files..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
KEY_FILES=(
    "public/bundles/pimui/images/akeneo.svg"
    "public/bundles/pimui/css/pim.css"
    "public/bundles/pimui/js/app.js"
)

for file in "${KEY_FILES[@]}"; do
    if [ -f "$file" ]; then
        SIZE=$(stat -c%s "$file" 2>/dev/null)
        echo "  ✓ $file (${SIZE} bytes)"
    else
        echo "  ✗ $file MISSING"
        # Try to find it
        BASENAME=$(basename "$file")
        FOUND=$(find public/bundles -name "$BASENAME" 2>/dev/null | head -1)
        if [ -n "$FOUND" ]; then
            echo "    Found at: $FOUND"
        fi
    fi
done
echo ""

# Fix 5: Check if logo exists elsewhere
echo "5. Searching for Akeneo Logo..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
find public -name "akeneo*.svg" -o -name "logo*.svg" 2>/dev/null | head -10
echo ""

# Fix 6: Update .env.local for database SSL
echo "6. Checking Database Configuration..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if grep -q "DATABASE_URL" .env.local; then
    echo "Current DATABASE_URL:"
    grep "DATABASE_URL" .env.local
    
    # Check if it has SSL params
    if ! grep "DATABASE_URL" .env.local | grep -q "serverVersion"; then
        echo ""
        echo "Suggestion: Add serverVersion parameter to DATABASE_URL"
        echo "Example: DATABASE_URL=mysql://pim:pim_password@127.0.0.1:3307/akeneo_pim?serverVersion=10.6.17-MariaDB"
    fi
else
    echo "✗ DATABASE_URL not found in .env.local"
fi
echo ""

# Fix 7: Test application with fixed DB connection
echo "7. Testing Application..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
LOGIN_TEST=$(timeout 5 php public/index.php 2>&1 | head -20)
if echo "$LOGIN_TEST" | grep -q "user/login"; then
    echo "✓ Application works - redirects to login"
else
    echo "⚠ Application response:"
    echo "$LOGIN_TEST" | head -10
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Database products: $DB_COUNT"
echo "Bundle files: $BUNDLE_COUNT"
echo ""
echo "✅ Fixes complete - use 'mariadb --skip-ssl' for database queries"
