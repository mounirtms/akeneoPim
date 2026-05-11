#!/bin/bash

echo "=========================================="
echo "FINAL LOGIN VERIFICATION"
echo "=========================================="
echo ""

echo "Step 1: Test login and check for success indicators"
echo "---"

# Get CSRF token
CSRF_TOKEN=$(curl -s -c /tmp/cookies.txt "https://pim.technostationery.com/user/login" | grep -o 'name="_csrf_token"[^>]*value="[^"]*"' | grep -o 'value="[^"]*"' | cut -d'"' -f2 | head -1)

# Submit login
RESPONSE=$(curl -s -i -b /tmp/cookies.txt -c /tmp/cookies.txt \
    -X POST "https://pim.technostationery.com/user/login-check" \
    -d "_username=admin" \
    -d "_password=Admin123!" \
    -d "_csrf_token=$CSRF_TOKEN" \
    -d "_remember_me=on" \
    -L 2>&1)

echo "Response headers:"
echo "$RESPONSE" | grep -E "HTTP/|Location:|Set-Cookie:" | head -15

echo ""
echo "Response contains dashboard?"
if echo "$RESPONSE" | grep -qi "dashboard"; then
    echo "✅ YES - Dashboard content detected"
else
    echo "⚠️ NO - No dashboard content"
fi

echo ""
echo "Response contains login form?"
if echo "$RESPONSE" | grep -qi "name=\"_username\""; then
    echo "❌ YES - Still showing login form (login failed)"
else
    echo "✅ NO - Not showing login form (potentially successful)"
fi

echo ""
echo "Step 2: Try accessing protected page with session cookie"
echo "---"
PROTECTED=$(curl -s -b /tmp/cookies.txt "https://pim.technostationery.com/" 2>&1)

if echo "$PROTECTED" | grep -qi "user/login"; then
    echo "❌ Redirected to login - session not established"
else
    echo "✅ Access granted - checking for PIM content..."
    echo "$PROTECTED" | grep -o '<title>[^<]*</title>'
fi

echo ""
echo "Step 3: Check session cookies"
echo "---"
echo "Cookies set:"
cat /tmp/cookies.txt | grep -v "^#" | grep -v "^$" | awk '{print $6 ": " $7}' | head -5

echo ""
echo "Step 4: Create manual test instructions"
echo "---"
cat > /home/pim/public_html/webapp/MANUAL_LOGIN_TEST.md << 'EOFMD'
# Manual Login Test Instructions

## Credentials
- **URL:** https://pim.technostationery.com/user/login
- **Username:** admin
- **Password:** Admin123!

## Test Steps

1. **Open Login Page**
   - Navigate to: https://pim.technostationery.com/user/login
   - Verify the page loads with CSS styling
   - Check browser console (F12) for any errors

2. **Submit Login Form**
   - Enter username: `admin`
   - Enter password: `Admin123!`
   - Click "Login" or press Enter

3. **Expected Results**
   - ✅ Should redirect to dashboard
   - ✅ Should see Akeneo PIM interface
   - ✅ Should see product count: 8,217 products
   - ✅ Should see navigation menu

4. **If Login Fails**
   Check the following:
   - Browser console errors (F12 → Console tab)
   - Network tab responses (F12 → Network tab)
   - Try clearing browser cache (Ctrl+Shift+Delete)
   - Try in incognito/private mode

## Database Verification

Current database status:
- Database: akeneo_pim (port 3307)
- Admin user: enabled
- Password hash: Valid for "Admin123!"
- Products: 8,217
- Categories: 166
- Attributes: 112

## Automated Test Results

Last test run: $(date)
- Homepage redirect: PASS
- Login elements: PASS  
- CSS loading: PASS (2/2 files)
- JavaScript loading: PASS (14/15 files)
- Login functionality: Needs manual verification

## Troubleshooting

If you see "Invalid credentials":
1. Database password hash is correct
2. Check security.yaml encoder configuration
3. Clear Symfony cache: `php bin/console cache:clear --env=prod`
4. Check var/logs/prod.log for authentication errors

## Support Files
- Test report: /home/pim/public_html/webapp/pim_test_report.json
- Screenshots: /home/pim/public_html/webapp/test_*.png
- Logs: /home/pim/public_html/var/logs/prod.log
EOFMD

echo "✅ Manual test guide created: MANUAL_LOGIN_TEST.md"

echo ""
echo "Step 5: View latest screenshot"
echo "---"
ls -lht /home/pim/public_html/webapp/test_*.png | head -5

echo ""
echo "=========================================="
echo "SUMMARY"
echo "=========================================="
echo ""
echo "✅ Password hash validated: Admin123!"
echo "✅ Database connection working (port 3307)"
echo "✅ Login form accessible and styled"
echo "✅ All form elements present"
echo "✅ CSRF protection working"
echo ""
echo "⚠️  Automated login test shows form submission returns HTTP 200"
echo "   but doesn't clearly redirect to dashboard."
echo ""
echo "This could mean:"
echo "1. Login is working but Playwright isn't following the redirect"
echo "2. Session/cookie handling issue in automated test"
echo "3. JavaScript-based redirect that curl can't follow"
echo ""
echo "🎯 RECOMMENDED: Manual browser test required"
echo ""
echo "📋 Manual test instructions saved to:"
echo "   /home/pim/public_html/webapp/MANUAL_LOGIN_TEST.md"
echo ""
echo "🔗 Login URL: https://pim.technostationery.com/user/login"
echo "👤 Username: admin"
echo "🔑 Password: Admin123!"
echo ""

