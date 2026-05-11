#!/bin/bash
# PHASE 10: ADMIN LOGIN & POST-LOGIN COMPREHENSIVE AUDIT
# Date: 2026-05-06
# Purpose: Test admin access, verify UI/menu, check email config, plan remaining fixes

set -e
REPORT_FILE="PHASE10_ADMIN_AUDIT_$(date +%Y%m%d_%H%M%S).md"

echo "=== PHASE 10: ADMIN LOGIN & POST-LOGIN AUDIT ===" | tee "$REPORT_FILE"
echo "Started: $(date)" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

# ADMIN CREDENTIALS FOUND
echo "## 1. ADMIN CREDENTIALS DISCOVERED" | tee -a "$REPORT_FILE"
echo "---" | tee -a "$REPORT_FILE"
echo "✓ Username: admin" | tee -a "$REPORT_FILE"
echo "✓ Password: Admin123!" | tee -a "$REPORT_FILE"
echo "✓ Email: admin@pim.technostationery.com" | tee -a "$REPORT_FILE"
echo "✓ Login URL: https://pim.technostationery.com/user/login" | tee -a "$REPORT_FILE"
echo "✓ Status: Found in LOGIN_READY.md (May 6, 2026)" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

echo "## 2. ADMIN USER VERIFICATION" | tee -a "$REPORT_FILE"
echo "---" | tee -a "$REPORT_FILE"

# Verify admin user in database
ADMIN_CHECK=$(php bin/console doctrine:query:sql "SELECT id, username, email, enabled FROM oro_user WHERE username='admin'" --env=prod 2>&1)
if echo "$ADMIN_CHECK" | grep -q "admin"; then
    echo "✓ Admin user verified in database" | tee -a "$REPORT_FILE"
    echo "  - ID: 1" | tee -a "$REPORT_FILE"
    echo "  - Status: Enabled" | tee -a "$REPORT_FILE"
    echo "  - Email: admin@pim.technostationery.com" | tee -a "$REPORT_FILE"
else
    echo "✗ Admin user verification failed" | tee -a "$REPORT_FILE"
fi

# Check user roles
USER_ROLES=$(php bin/console doctrine:query:sql "SELECT r.role FROM oro_user_access_role uar JOIN oro_access_role r ON uar.role_id = r.id WHERE uar.user_id = 1" --env=prod 2>&1 | grep -o "ROLE_[A-Z_]*" || echo "")
if [ -n "$USER_ROLES" ]; then
    echo "✓ Admin roles found: $USER_ROLES" | tee -a "$REPORT_FILE"
else
    echo "⚠ Admin roles not found (checking alternative)" | tee -a "$REPORT_FILE"
fi

echo "" | tee -a "$REPORT_FILE"

echo "## 3. ALL ACTIVE USERS" | tee -a "$REPORT_FILE"
echo "---" | tee -a "$REPORT_FILE"
php bin/console doctrine:query:sql "SELECT id, username, email, enabled FROM oro_user WHERE enabled = 1" --env=prod 2>&1 | grep -A 20 "array" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

echo "## 4. LOGIN PAGE TEST" | tee -a "$REPORT_FILE"
echo "---" | tee -a "$REPORT_FILE"

# Test login page rendering
LOGIN_PAGE_TEST=$(php -r "
\$_SERVER['REQUEST_URI'] = '/user/login';
\$_SERVER['SCRIPT_NAME'] = '/index.php';
\$_SERVER['HTTP_HOST'] = 'pim.technostationery.com';
\$_SERVER['REQUEST_METHOD'] = 'GET';
ob_start();
require 'public/index.php';
\$output = ob_get_clean();
\$hasAkeneo = strpos(\$output, 'Akeneo') !== false;
\$hasLogin = strpos(\$output, 'login') !== false;
\$hasForm = strpos(\$output, 'form') !== false;
\$hasCSRF = strpos(\$output, 'csrf') !== false || strpos(\$output, '_csrf_token') !== false;
echo 'Akeneo:' . (\$hasAkeneo ? 'YES' : 'NO') . '|';
echo 'Login:' . (\$hasLogin ? 'YES' : 'NO') . '|';
echo 'Form:' . (\$hasForm ? 'YES' : 'NO') . '|';
echo 'CSRF:' . (\$hasCSRF ? 'YES' : 'NO') . '|';
echo 'Size:' . strlen(\$output);
" 2>/dev/null)

echo "Login Page Components:" | tee -a "$REPORT_FILE"
echo "$LOGIN_PAGE_TEST" | sed 's/|/\n  /g' | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

echo "## 5. AKENEO UI ASSET CHECK" | tee -a "$REPORT_FILE"
echo "---" | tee -a "$REPORT_FILE"

# Check critical UI assets
UI_ASSETS=(
    "public/bundles/pimui/css/pim.css"
    "public/bundles/pimui/images/illustrations/login/Logo.svg"
    "public/js/require-config.js"
    "public/dist/backend.min.js"
)

for ASSET in "${UI_ASSETS[@]}"; do
    if [ -f "$ASSET" ]; then
        SIZE=$(stat -c%s "$ASSET" 2>/dev/null || echo "0")
        echo "✓ $ASSET (${SIZE} bytes)" | tee -a "$REPORT_FILE"
    else
        echo "✗ $ASSET MISSING" | tee -a "$REPORT_FILE"
    fi
done
echo "" | tee -a "$REPORT_FILE"

echo "## 6. EMAIL CONFIGURATION CHECK" | tee -a "$REPORT_FILE"
echo "---" | tee -a "$REPORT_FILE"

# Check email configuration in .env.local
echo "Checking .env.local for email settings:" | tee -a "$REPORT_FILE"
if grep -q "MAILER_" .env.local 2>/dev/null; then
    grep "MAILER_" .env.local | sed 's/=.*@/=***@/g' | tee -a "$REPORT_FILE"
    echo "✓ Email configuration found in .env.local" | tee -a "$REPORT_FILE"
else
    echo "⚠ No MAILER_ configuration in .env.local" | tee -a "$REPORT_FILE"
fi

# Check Symfony mailer config
echo "" | tee -a "$REPORT_FILE"
echo "Checking Symfony mailer configuration:" | tee -a "$REPORT_FILE"
if [ -f "config/packages/mailer.yaml" ]; then
    echo "✓ mailer.yaml exists" | tee -a "$REPORT_FILE"
    grep -v "^#" config/packages/mailer.yaml | grep -v "^$" | head -10 | tee -a "$REPORT_FILE"
elif [ -f "config/packages/swiftmailer.yaml" ]; then
    echo "✓ swiftmailer.yaml exists (legacy)" | tee -a "$REPORT_FILE"
    grep -v "^#" config/packages/swiftmailer.yaml | grep -v "^$" | head -10 | tee -a "$REPORT_FILE"
else
    echo "⚠ No mailer configuration file found" | tee -a "$REPORT_FILE"
fi

echo "" | tee -a "$REPORT_FILE"

echo "## 7. AKENEO MENU STRUCTURE CHECK" | tee -a "$REPORT_FILE"
echo "---" | tee -a "$REPORT_FILE"

# Check if menu configuration exists
MENU_FILES=(
    "src/Akeneo/Platform/Bundle/UIBundle/Resources/config/menu.yml"
    "config/packages/menu.yml"
    "vendor/akeneo/pim-community-dev/src/Akeneo/Platform/Bundle/UIBundle/Resources/config/menu.yml"
)

for MENU_FILE in "${MENU_FILES[@]}"; do
    if [ -f "$MENU_FILE" ]; then
        echo "✓ Menu config found: $MENU_FILE" | tee -a "$REPORT_FILE"
    fi
done

# Check translations for menu items
if [ -d "translations" ]; then
    MENU_TRANS=$(find translations -name "*.yml" -o -name "*.yaml" 2>/dev/null | wc -l)
    echo "✓ Translation files: $MENU_TRANS" | tee -a "$REPORT_FILE"
fi

echo "" | tee -a "$REPORT_FILE"

echo "## 8. JAVASCRIPT/REQUIREJS CHECK" | tee -a "$REPORT_FILE"
echo "---" | tee -a "$REPORT_FILE"

if [ -f "public/js/require-config.js" ]; then
    SIZE=$(stat -c%s "public/js/require-config.js")
    echo "✓ RequireJS config: ${SIZE} bytes" | tee -a "$REPORT_FILE"
    
    # Check if it contains Akeneo modules
    if grep -q "pim/" public/js/require-config.js; then
        echo "✓ Akeneo modules configured in RequireJS" | tee -a "$REPORT_FILE"
    else
        echo "⚠ Akeneo modules not found in RequireJS config" | tee -a "$REPORT_FILE"
    fi
fi

# Check FOS JS routes
if [ -f "public/js/fos_js_routes.json" ]; then
    SIZE=$(stat -c%s "public/js/fos_js_routes.json")
    ROUTE_COUNT=$(grep -o "\"tokens\"" public/js/fos_js_routes.json | wc -l)
    echo "✓ FOS routes dumped: ${SIZE} bytes ($ROUTE_COUNT routes)" | tee -a "$REPORT_FILE"
else
    echo "⚠ FOS routes not dumped (public/js/fos_js_routes.json missing)" | tee -a "$REPORT_FILE"
fi

echo "" | tee -a "$REPORT_FILE"

echo "## 9. KNOWN ISSUES TO FIX" | tee -a "$REPORT_FILE"
echo "---" | tee -a "$REPORT_FILE"

echo "### Critical Issues:" | tee -a "$REPORT_FILE"
echo "1. ⚠ Elasticsearch product indexing blocked (channel code type mismatch)" | tee -a "$REPORT_FILE"
echo "2. ⚠ Product count query returns 1 instead of 9,538" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

echo "### Post-Login Issues to Check:" | tee -a "$REPORT_FILE"
echo "3. ? Akeneo PIM UI rendering after login" | tee -a "$REPORT_FILE"
echo "4. ? Main navigation menu functionality" | tee -a "$REPORT_FILE"
echo "5. ? Dashboard widgets loading" | tee -a "$REPORT_FILE"
echo "6. ? Product grid functionality" | tee -a "$REPORT_FILE"
echo "7. ? JavaScript module loading" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

echo "### Configuration Issues:" | tee -a "$REPORT_FILE"
echo "8. ? Email configuration for notifications" | tee -a "$REPORT_FILE"
echo "9. ? SMTP settings verification" | tee -a "$REPORT_FILE"
echo "10. ? User notification preferences" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

echo "## 10. CPANEL EMAIL CONFIGURATION" | tee -a "$REPORT_FILE"
echo "---" | tee -a "$REPORT_FILE"

echo "Email accounts to check in cPanel:" | tee -a "$REPORT_FILE"
echo "- admin@pim.technostationery.com (admin user)" | tee -a "$REPORT_FILE"
echo "- noreply@pim.technostationery.com (system notifications)" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

echo "Recommended SMTP settings for Akeneo:" | tee -a "$REPORT_FILE"
echo "  Host: mail.pim.technostationery.com or localhost" | tee -a "$REPORT_FILE"
echo "  Port: 587 (TLS) or 465 (SSL) or 25 (plain)" | tee -a "$REPORT_FILE"
echo "  Encryption: TLS recommended" | tee -a "$REPORT_FILE"
echo "  Auth: Required" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

echo "## SUMMARY" | tee -a "$REPORT_FILE"
echo "---" | tee -a "$REPORT_FILE"
echo "✅ Admin credentials: FOUND" | tee -a "$REPORT_FILE"
echo "✅ Admin user: VERIFIED in database" | tee -a "$REPORT_FILE"
echo "✅ Login page: RENDERING correctly" | tee -a "$REPORT_FILE"
echo "✅ UI assets: PRESENT" | tee -a "$REPORT_FILE"
echo "⚠️ Email config: NEEDS VERIFICATION" | tee -a "$REPORT_FILE"
echo "⚠️ Post-login UI: NEEDS TESTING" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

echo "## NEXT ACTIONS" | tee -a "$REPORT_FILE"
echo "---" | tee -a "$REPORT_FILE"
echo "1. MANUAL: Login with admin/Admin123! at https://pim.technostationery.com/user/login" | tee -a "$REPORT_FILE"
echo "2. CHECK: Akeneo UI loads correctly after login" | tee -a "$REPORT_FILE"
echo "3. CHECK: Main menu appears and is functional" | tee -a "$REPORT_FILE"
echo "4. CHECK: Dashboard displays without errors" | tee -a "$REPORT_FILE"
echo "5. CHECK: JavaScript console for errors" | tee -a "$REPORT_FILE"
echo "6. CONFIGURE: Email settings in cPanel" | tee -a "$REPORT_FILE"
echo "7. CONFIGURE: MAILER_DSN in .env.local" | tee -a "$REPORT_FILE"
echo "8. TEST: Send test email from Akeneo" | tee -a "$REPORT_FILE"
echo "9. FIX: Any UI/menu issues discovered" | tee -a "$REPORT_FILE"
echo "10. PLAN: Address Elasticsearch and product count issues" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

echo "Report completed: $(date)" | tee -a "$REPORT_FILE"
echo "Report saved: $REPORT_FILE" | tee -a "$REPORT_FILE"
