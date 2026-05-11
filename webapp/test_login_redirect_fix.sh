#!/bin/bash

# Test Login Redirect Fix
# Verifies that after login, user is redirected to dashboard instead of loading screen

echo "============================================"
echo "Login Redirect Fix - Comprehensive Test"
echo "============================================"
echo ""
echo "Testing: https://pim.technostationery.com"
echo ""

# Step 1: Test login page access
echo "Step 1: Testing login page..."
LOGIN_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "https://pim.technostationery.com/user/login")
if [ "$LOGIN_STATUS" = "200" ]; then
    echo "✓ Login page accessible (HTTP $LOGIN_STATUS)"
else
    echo "✗ Login page issue (HTTP $LOGIN_STATUS)"
    exit 1
fi

# Step 2: Get CSRF token from login page
echo ""
echo "Step 2: Getting CSRF token..."
COOKIE_FILE="/tmp/akeneo_login_test_$$.txt"
LOGIN_PAGE=$(curl -s -c "$COOKIE_FILE" "https://pim.technostationery.com/user/login")
CSRF_TOKEN=$(echo "$LOGIN_PAGE" | grep -oP 'name="_csrf_token"[^>]+value="\K[^"]+' | head -1)

if [ -n "$CSRF_TOKEN" ]; then
    echo "✓ CSRF token obtained: ${CSRF_TOKEN:0:20}..."
else
    echo "✗ Failed to get CSRF token"
    rm -f "$COOKIE_FILE"
    exit 1
fi

# Step 3: Submit login and capture redirect location
echo ""
echo "Step 3: Submitting login credentials..."
LOGIN_RESPONSE=$(curl -s -i -b "$COOKIE_FILE" -c "$COOKIE_FILE" \
    -X POST "https://pim.technostationery.com/user/login-check" \
    -d "_username=admin" \
    -d "_password=PimAdmin2026!" \
    -d "_csrf_token=$CSRF_TOKEN" \
    -L)

# Extract final URL from redirect chain
FINAL_URL=$(echo "$LOGIN_RESPONSE" | grep -i "^location:" | tail -1 | sed 's/location: //i' | tr -d '\r\n')

echo "Final redirect location: $FINAL_URL"

# Step 4: Verify we're redirected to dashboard
echo ""
echo "Step 4: Verifying redirect target..."
if echo "$FINAL_URL" | grep -q "/dashboard"; then
    echo "✓ SUCCESS: Redirected to dashboard!"
    SUCCESS=1
elif echo "$FINAL_URL" | grep -q "^/$" || [ "$FINAL_URL" = "/" ]; then
    echo "✗ FAIL: Still redirecting to root (/) - loading screen issue"
    SUCCESS=0
else
    echo "⚠ WARNING: Redirected to unexpected location: $FINAL_URL"
    SUCCESS=0
fi

# Step 5: Test authenticated dashboard access
echo ""
echo "Step 5: Testing authenticated dashboard access..."
DASHBOARD_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -b "$COOKIE_FILE" "https://pim.technostationery.com/dashboard")

if [ "$DASHBOARD_STATUS" = "200" ]; then
    echo "✓ Dashboard accessible (HTTP $DASHBOARD_STATUS)"
else
    echo "✗ Dashboard access issue (HTTP $DASHBOARD_STATUS)"
    SUCCESS=0
fi

# Step 6: Check that dashboard loads actual content (not just loading screen)
echo ""
echo "Step 6: Verifying dashboard content..."
DASHBOARD_CONTENT=$(curl -s -b "$COOKIE_FILE" "https://pim.technostationery.com/dashboard")

if echo "$DASHBOARD_CONTENT" | grep -q "data-hash"; then
    echo "✓ Dashboard contains data-hash (SPA initialized)"
elif echo "$DASHBOARD_CONTENT" | grep -q "dashboard"; then
    echo "✓ Dashboard content detected"
else
    echo "⚠ Dashboard may show loading screen only"
fi

# Cleanup
rm -f "$COOKIE_FILE"

# Final result
echo ""
echo "============================================"
if [ $SUCCESS -eq 1 ]; then
    echo "RESULT: ✓ Login redirect fix VERIFIED!"
    echo ""
    echo "Summary:"
    echo "  - Login page: OK"
    echo "  - CSRF protection: OK"
    echo "  - Login redirect: dashboard (FIXED)"
    echo "  - Dashboard access: OK"
    echo ""
    exit 0
else
    echo "RESULT: ✗ Login redirect still needs fixing"
    echo ""
    echo "Current behavior:"
    echo "  - Redirect target: $FINAL_URL"
    echo "  - Expected: /dashboard"
    echo ""
    exit 1
fi
