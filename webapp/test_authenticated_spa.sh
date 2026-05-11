#!/bin/bash

echo "Testing Authenticated SPA Access"
echo "================================="
echo ""

COOKIE_FILE="/tmp/auth_spa_test_$$.txt"

# Step 1: Login
echo "Step 1: Logging in..."
curl -s -c "$COOKIE_FILE" "https://pim.technostationery.com/user/login" > /dev/null
LOGIN_PAGE=$(curl -s -b "$COOKIE_FILE" "https://pim.technostationery.com/user/login")
CSRF_TOKEN=$(echo "$LOGIN_PAGE" | grep -oP 'name="_csrf_token"[^>]+value="\K[^"]+' | head -1)

curl -s -i -b "$COOKIE_FILE" -c "$COOKIE_FILE" -L \
    -X POST "https://pim.technostationery.com/user/login-check" \
    -d "_username=admin" \
    -d "_password=PimAdmin2026!" \
    -d "_csrf_token=$CSRF_TOKEN" > /dev/null 2>&1

echo "✓ Logged in"

# Step 2: Test root path with authentication
echo ""
echo "Step 2: Testing root path (/) when authenticated..."
ROOT_CONTENT=$(curl -s -b "$COOKIE_FILE" "https://pim.technostationery.com/")
echo "First 200 chars of root response:"
echo "$ROOT_CONTENT" | head -c 200
echo ""
echo ""

if echo "$ROOT_CONTENT" | grep -q "<!DOCTYPE html>"; then
    echo "✓ Root returns HTML"
    if echo "$ROOT_CONTENT" | grep -q "data-hash\|backbone\|require.js"; then
        echo "✓ SPA application detected in root"
    else
        echo "⚠ Root HTML doesn't contain expected SPA markers"
    fi
else
    echo "✗ Root doesn't return proper HTML"
fi

# Step 3: Test dashboard route
echo ""
echo "Step 3: Testing /dashboard route when authenticated..."
DASHBOARD_CONTENT=$(curl -s -b "$COOKIE_FILE" "https://pim.technostationery.com/dashboard")
echo "First 200 chars of dashboard response:"
echo "$DASHBOARD_CONTENT" | head -c 200
echo ""
echo ""

if echo "$DASHBOARD_CONTENT" | grep -q "<!DOCTYPE html>"; then
    echo "✓ Dashboard returns HTML"
    if echo "$DASHBOARD_CONTENT" | grep -q "data-hash\|backbone\|require.js"; then
        echo "✓ SPA application detected in dashboard"
    else
        echo "⚠ Dashboard HTML doesn't contain expected SPA markers"
    fi
else
    echo "✗ Dashboard doesn't return proper HTML"
fi

# Step 4: Test hash route redirect
echo ""
echo "Step 4: Testing /#/dashboard (SPA hash route)..."
HASH_DASHBOARD=$(curl -s -b "$COOKIE_FILE" "https://pim.technostationery.com/#/dashboard")
if echo "$HASH_DASHBOARD" | grep -q "<!DOCTYPE html>"; then
    echo "✓ Hash route serves HTML"
fi

# Cleanup
rm -f "$COOKIE_FILE"

echo ""
echo "================================="
echo "Test Complete"
