#!/bin/bash
# PHASE11_VERIFY_FIX.sh - Verify the fix is working
# Date: 2026-05-06

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ PHASE 11: VERIFICATION TESTS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Start time: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo ""

TESTS_PASSED=0
TESTS_FAILED=0

# Test 1: Direct Apache (Port 8080)
echo "1. Test Direct Apache (Port 8080)..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
APACHE_TEST=$(timeout 5 curl -s -H "Host: pim.technostationery.com" http://localhost:8080/ 2>/dev/null)
if echo "$APACHE_TEST" | grep -q "user/login"; then
    echo "✅ PASS: Apache returns redirect to /user/login"
    ((TESTS_PASSED++))
else
    echo "❌ FAIL: Apache still shows directory index"
    echo "Response preview:"
    echo "$APACHE_TEST" | head -5
    ((TESTS_FAILED++))
fi
echo ""

# Test 2: Through Varnish (Port 80)
echo "2. Test Through Varnish (Port 80)..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
VARNISH_TEST=$(timeout 5 curl -s http://localhost/ 2>/dev/null)
if echo "$VARNISH_TEST" | grep -q "user/login"; then
    echo "✅ PASS: Varnish returns redirect to /user/login"
    ((TESTS_PASSED++))
else
    echo "⚠️ WARNING: Varnish may still have cached response"
    echo "Try: sudo varnishadm 'ban req.url ~ /'"
    ((TESTS_FAILED++))
fi
echo ""

# Test 3: Production URL (Through Cloudflare)
echo "3. Test Production URL (Through Cloudflare)..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
PROD_TEST=$(timeout 5 curl -s https://pim.technostationery.com/ 2>/dev/null)
if echo "$PROD_TEST" | grep -q "user/login"; then
    echo "✅ PASS: Production URL returns Akeneo login"
    ((TESTS_PASSED++))
elif echo "$PROD_TEST" | grep -q "Index of"; then
    echo "❌ FAIL: Cloudflare still caching directory index"
    echo "Action required: Clear Cloudflare cache manually"
    ((TESTS_FAILED++))
else
    echo "⚠️ UNKNOWN: Unexpected response"
    echo "$PROD_TEST" | head -5
    ((TESTS_FAILED++))
fi
echo ""

# Test 4: Login Page Accessibility
echo "4. Test /user/login Page..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
LOGIN_TEST=$(timeout 5 curl -s https://pim.technostationery.com/user/login 2>/dev/null)
if echo "$LOGIN_TEST" | grep -q "Akeneo"; then
    echo "✅ PASS: Login page displays Akeneo branding"
    ((TESTS_PASSED++))
else
    echo "❌ FAIL: Login page not displaying correctly"
    ((TESTS_FAILED++))
fi
echo ""

# Test 5: Static Assets
echo "5. Test Static Asset Loading..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
LOGO_TEST=$(timeout 5 curl -s -I https://pim.technostationery.com/bundles/pimui/images/logo.svg 2>/dev/null | head -1)
if echo "$LOGO_TEST" | grep -q "200"; then
    echo "✅ PASS: Static assets (SVG logo) accessible"
    ((TESTS_PASSED++))
else
    echo "❌ FAIL: Static asset not accessible"
    ((TESTS_FAILED++))
fi
echo ""

# Test 6: No Directory Listing
echo "6. Test Directory Listing Disabled..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if echo "$PROD_TEST" | grep -q "Index of"; then
    echo "❌ FAIL: Directory listing still visible"
    ((TESTS_FAILED++))
else
    echo "✅ PASS: No directory listing detected"
    ((TESTS_PASSED++))
fi
echo ""

# Test 7: Response Time
echo "7. Test Response Time..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
RESPONSE_TIME=$(timeout 5 curl -s -o /dev/null -w "%{time_total}" https://pim.technostationery.com/user/login 2>/dev/null)
if (( $(echo "$RESPONSE_TIME < 2.0" | bc -l) )); then
    echo "✅ PASS: Response time ${RESPONSE_TIME}s (< 2s)"
    ((TESTS_PASSED++))
else
    echo "⚠️ WARNING: Response time ${RESPONSE_TIME}s (> 2s)"
    ((TESTS_FAILED++))
fi
echo ""

# Test 8: HTTP Headers
echo "8. Test HTTP Headers..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
HEADERS=$(timeout 5 curl -s -I https://pim.technostationery.com/user/login 2>/dev/null)
if echo "$HEADERS" | grep -q "Content-Security-Policy"; then
    echo "✅ PASS: Security headers present"
    ((TESTS_PASSED++))
else
    echo "⚠️ WARNING: Security headers missing"
    ((TESTS_FAILED++))
fi
echo ""

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 VERIFICATION SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Tests Passed: $TESTS_PASSED / 8"
echo "Tests Failed: $TESTS_FAILED / 8"
SUCCESS_RATE=$(echo "scale=0; $TESTS_PASSED * 100 / 8" | bc)
echo "Success Rate: ${SUCCESS_RATE}%"
echo ""
echo "End time: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo ""

if [ $TESTS_PASSED -ge 6 ]; then
    echo "✅ FIX SUCCESSFUL (${SUCCESS_RATE}% pass rate)"
    echo ""
    echo "🎉 The Akeneo PIM is now accessible at:"
    echo "   https://pim.technostationery.com/user/login"
    echo ""
    if [ $TESTS_FAILED -gt 0 ]; then
        echo "⚠️ Minor issues detected:"
        echo "   - Clear Cloudflare cache if production URL still shows directory index"
        echo "   - Check Varnish cache if localhost test fails"
    fi
    exit 0
else
    echo "❌ FIX INCOMPLETE (${SUCCESS_RATE}% pass rate)"
    echo ""
    echo "🔧 Actions required:"
    echo "1. Clear Cloudflare cache: Dashboard > Caching > Purge Everything"
    echo "2. Clear Varnish cache: sudo varnishadm 'ban req.url ~ /'"
    echo "3. Restart Apache: /scripts/restartsrv_httpd"
    echo "4. Re-run this verification: ./PHASE11_VERIFY_FIX.sh"
    exit 1
fi
