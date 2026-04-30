#!/bin/bash

echo "=============================================="
echo "Password Reset Flow Test"
echo "=============================================="
echo ""
echo "Date: $(date)"
echo ""

# Test 1: Check reset-request page
echo "Test 1: Accessing /user/reset-request"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" https://pim.technostationery.com/user/reset-request)
if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ PASS - Reset request page accessible (HTTP $HTTP_CODE)"
else
    echo "❌ FAIL - Reset request page returned HTTP $HTTP_CODE"
fi
echo ""

# Test 2: Check send-email endpoint
echo "Test 2: Accessing /user/send-email"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" https://pim.technostationery.com/user/send-email)
if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ] || [ "$HTTP_CODE" = "405" ]; then
    echo "✅ PASS - Send email endpoint accessible (HTTP $HTTP_CODE)"
else
    echo "❌ FAIL - Send email endpoint returned HTTP $HTTP_CODE"
fi
echo ""

# Test 3: Check check-email page
echo "Test 3: Accessing /user/check-email"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" https://pim.technostationery.com/user/check-email)
if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ]; then
    echo "✅ PASS - Check email page accessible (HTTP $HTTP_CODE)"
else
    echo "❌ FAIL - Check email page returned HTTP $HTTP_CODE"
fi
echo ""

# Test 4: Check reset page with test token
echo "Test 4: Accessing /user/reset/test_token"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" https://pim.technostationery.com/user/reset/test_token_12345)
if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ] || [ "$HTTP_CODE" = "404" ]; then
    echo "✅ PASS - Reset page with token accessible (HTTP $HTTP_CODE)"
    echo "   Note: 404 is OK if token doesn't exist, 302 is OK if redirect occurs"
else
    echo "❌ FAIL - Reset page returned HTTP $HTTP_CODE"
fi
echo ""

# Test 5: Check login page
echo "Test 5: Accessing /user/login"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" https://pim.technostationery.com/user/login)
if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ PASS - Login page accessible (HTTP $HTTP_CODE)"
else
    echo "❌ FAIL - Login page returned HTTP $HTTP_CODE"
fi
echo ""

echo "=============================================="
echo "Summary"
echo "=============================================="
echo ""
echo "Security Configuration:"
echo "  - login firewall: pattern ^/user/(login|reset-request|send-email|check-email)\$"
echo "  - reset_password firewall: pattern ^/user/reset/*"
echo "  - Both firewalls: anonymous: ~, stateless: true"
echo ""
echo "Access Control:"
echo "  - ^/user/(login|reset-request|send-email|check-email): IS_AUTHENTICATED_ANONYMOUSLY"
echo "  - ^/user/reset: IS_AUTHENTICATED_ANONYMOUSLY"
echo ""
echo "Next Steps:"
echo "  1. If all tests pass, try the actual forgot password flow in browser"
echo "  2. Go to: https://pim.technostationery.com/user/login"
echo "  3. Click 'Forgot your password?'"
echo "  4. Enter your email address"
echo "  5. Check your email for the reset link"
echo ""
echo "Test completed at: $(date)"
