#!/bin/bash

echo "=========================================="
echo "LOGIN ISSUE DETAILED ANALYSIS"
echo "=========================================="
echo ""

echo "Step 1: Check what happens during login submission"
echo "---"
echo "Getting login page and extracting form details..."

curl -s -c /tmp/pim_cookies.txt "https://pim.technostationery.com/user/login" > /tmp/login_page.html

echo "Form action:"
grep -o 'action="[^"]*"' /tmp/login_page.html | head -1

echo ""
echo "Form fields:"
grep -o 'name="_[^"]*"' /tmp/login_page.html | sort -u

echo ""
echo "CSRF token:"
CSRF_TOKEN=$(grep -o 'name="_csrf_token"[^>]*value="[^"]*"' /tmp/login_page.html | grep -o 'value="[^"]*"' | cut -d'"' -f2 | head -1)
echo "Token: ${CSRF_TOKEN:0:50}..."

echo ""
echo "Step 2: Attempt login with curl and capture response"
echo "---"
echo "Submitting login form..."

RESPONSE=$(curl -s -b /tmp/pim_cookies.txt -c /tmp/pim_cookies.txt \
    -X POST "https://pim.technostationery.com/user/login" \
    -d "_username=admin" \
    -d "_password=Admin123!" \
    -d "_csrf_token=$CSRF_TOKEN" \
    -L -D /tmp/login_headers.txt)

echo "Response headers:"
cat /tmp/login_headers.txt | grep -E "HTTP|Location|Set-Cookie" | head -10

echo ""
echo "Response body title:"
echo "$RESPONSE" | grep -o '<title>[^<]*</title>'

echo ""
echo "Any error messages:"
echo "$RESPONSE" | grep -o '<div class="alert[^>]*>[^<]*</div>' | head -3

echo ""
echo "Step 3: Check if we're logged in (look for redirect to dashboard)"
echo "---"
if echo "$RESPONSE" | grep -q "dashboard\|Dashboard\|Tableau de bord"; then
    echo "✅ Login appears successful - dashboard content found"
elif echo "$RESPONSE" | grep -q "Invalid credentials\|Identifiants invalides\|Bad credentials"; then
    echo "❌ Login failed - Invalid credentials message"
else
    echo "⚠️ Unclear - checking page content..."
    echo "$RESPONSE" | grep -o '<h[1-3][^>]*>[^<]*</h[1-3]>' | head -5
fi

echo ""
echo "Step 4: Check database password hash validity"
echo "---"
cd /home/pim/public_html

# Get current hash
CURRENT_HASH=$(mysql -u akeneo_pim -p'akeneo_pim' -P 3307 -h 127.0.0.1 --skip-ssl akeneo_pim -sN -e "SELECT password FROM oro_user WHERE username = 'admin';" 2>/dev/null)

echo "Current hash: ${CURRENT_HASH:0:60}..."

# Verify hash
php -r "
\$hash = '$CURRENT_HASH';
\$password = 'Admin123!';
if (password_verify(\$password, \$hash)) {
    echo '✅ Password hash is valid for: Admin123!\n';
} else {
    echo '❌ Password hash does NOT match: Admin123!\n';
    echo 'Trying common alternatives...\n';
    foreach(['admin', 'admin123', 'Admin123', 'password'] as \$p) {
        if (password_verify(\$p, \$hash)) {
            echo \"✅ Hash matches password: \$p\n\";
            break;
        }
    }
}
"

echo ""
echo "Step 5: Check Akeneo security encoder configuration"
echo "---"
if [ -f config/packages/security.yaml ]; then
    echo "Security encoders/hashers:"
    grep -A 20 "encoders:\|password_hasher:" config/packages/security.yaml | grep -v "^#" | head -25
fi

echo ""
echo "Step 6: Check for any security/firewall blocks"
echo "---"
tail -20 var/logs/prod.log 2>/dev/null | grep -i "login\|auth\|security\|denied" || echo "No recent security logs"

echo ""
echo "=========================================="
echo "NEXT STEPS"
echo "=========================================="
echo ""

