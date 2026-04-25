#!/bin/bash
# Final Session & Authentication Verification
# This script simulates a real browser flow and tests the complete authentication

echo "============================================="
echo "Final Session & Authentication Test"
echo "Started: $(date '+%Y-%m-%d %H:%M:%S')"
echo "============================================="
echo ""

BASE_URL="https://pim.technostationery.com"
COOKIE_FILE="/tmp/akeneo_session_test_$$"

# Step 1: Test login page
echo "[1/5] Testing login page access..."
LOGIN_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/user/login")
if [ "$LOGIN_STATUS" = "200" ]; then
    echo "  ✓ Login page accessible (HTTP $LOGIN_STATUS)"
else
    echo "  ✗ Login page error (HTTP $LOGIN_STATUS)"
fi

# Step 2: Perform authenticated test with cookie persistence
echo ""
echo "[2/5] Testing authentication flow..."
# Get CSRF token
CSRF_TOKEN=$(curl -s -c "$COOKIE_FILE" "$BASE_URL/user/login" | grep -oP 'name="_csrf_token".*?value="\K[^"]+')
echo "  CSRF Token: ${CSRF_TOKEN:0:20}..."

# Submit login
LOGIN_RESPONSE=$(curl -s -i -b "$COOKIE_FILE" -c "$COOKIE_FILE" \
    -d "_username=admin" \
    -d "_password=PimAdmin2026!" \
    -d "_csrf_token=$CSRF_TOKEN" \
    -d "_target_path=/dashboard" \
    -d "_remember_me=on" \
    "$BASE_URL/user/login-check")

LOGIN_CODE=$(echo "$LOGIN_RESPONSE" | grep "HTTP/" | head -1 | awk '{print $2}')
echo "  Login response: HTTP $LOGIN_CODE"

# Check for session cookies
if [ -f "$COOKIE_FILE" ]; then
    COOKIE_COUNT=$(grep -c "BAPID\|BAPRM\|PHPSESSID" "$COOKIE_FILE" 2>/dev/null || echo "0")
    echo "  Session cookies set: $COOKIE_COUNT"
fi

# Step 3: Test dashboard access with cookies
echo ""
echo "[3/5] Testing authenticated dashboard access..."
DASHBOARD_RESPONSE=$(curl -s -i -b "$COOKIE_FILE" -L "$BASE_URL/")
DASHBOARD_CODE=$(echo "$DASHBOARD_RESPONSE" | grep "HTTP/" | tail -1 | awk '{print $2}')
echo "  Dashboard response: HTTP $DASHBOARD_CODE"

# Check if we're redirected to login
if echo "$DASHBOARD_RESPONSE" | grep -q "name=\"_password\""; then
    echo "  ✗ FAILED: Redirected to login page (session not persisting)"
    echo ""
    echo "  Session Debug Info:"
    [ -f "$COOKIE_FILE" ] && cat "$COOKIE_FILE" | grep -E "BAPID|BAPRM|PHPSESSID" || echo "  No session cookies found"
else
    echo "  ✓ SUCCESS: Dashboard accessible (no login form)"
fi

# Check for SPA elements
if echo "$DASHBOARD_RESPONSE" | grep -q "main.min.js"; then
    echo "  ✓ SPA assets present"
else
    echo "  ! SPA assets missing (check webpack build)"
fi

# Step 4: Test API endpoint
echo ""
echo "[4/5] Testing API with session authentication..."
API_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -b "$COOKIE_FILE" "$BASE_URL/rest/user/current")
echo "  API endpoint response: HTTP $API_RESPONSE"
if [ "$API_RESPONSE" = "200" ]; then
    echo "  ✓ API authentication working"
elif [ "$API_RESPONSE" = "401" ] || [ "$API_RESPONSE" = "403" ]; then
    echo "  ✗ API authentication failed"
else
    echo "  ! API endpoint returned HTTP $API_RESPONSE"
fi

# Step 5: Summary
echo ""
echo "[5/5] Test Summary"
echo "============================================="

# Final verdict
BODY_SIZE=$(echo "$DASHBOARD_RESPONSE" | wc -c)
HAS_LOGIN=$(echo "$DASHBOARD_RESPONSE" | grep -c "name=\"_password\"" || echo "0")

if [ "$DASHBOARD_CODE" = "200" ] && [ "$HAS_LOGIN" = "0" ] && [ "$BODY_SIZE" -gt 5000 ]; then
    echo "✓✓✓ AUTHENTICATION WORKING ✓✓✓"
    echo ""
    echo "Status: Session persistence is functional"
    echo "Dashboard: Accessible without login form"
    echo "Response size: ${BODY_SIZE} bytes (SPA loaded)"
    echo ""
    echo "The application is ready for use!"
    echo "Access: $BASE_URL"
    echo "Credentials: admin / PimAdmin2026!"
elif [ "$DASHBOARD_CODE" = "200" ] && [ "$HAS_LOGIN" = "0" ]; then
    echo "⚠ PARTIAL SUCCESS ⚠"
    echo ""
    echo "Status: Authentication works but SPA may not be fully loaded"
    echo "Response size: ${BODY_SIZE} bytes"
    echo ""
    echo "Possible issues:"
    echo "  - Frontend assets not built"
    echo "  - JavaScript not loading"
    echo "  - Check browser console for errors"
else
    echo "✗✗✗ AUTHENTICATION FAILED ✗✗✗"
    echo ""
    echo "Status: Session not persisting after login"
    echo "Dashboard code: HTTP $DASHBOARD_CODE"
    echo "Has login form: $HAS_LOGIN"
    echo ""
    echo "Next steps:"
    echo "  1. Check var/logs/prod.log for errors"
    echo "  2. Verify session directory permissions"
    echo "  3. Check APP_SECRET in .env"
    echo "  4. Review config/packages/prod/session.yaml"
fi

echo "============================================="
echo "Finished: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Cleanup
rm -f "$COOKIE_FILE"
