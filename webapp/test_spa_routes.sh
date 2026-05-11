#!/bin/bash

echo "Testing SPA Routes"
echo "=================="
echo ""

# Test 1: Root path should serve the SPA shell
echo "Test 1: Root path (/) should serve SPA shell..."
ROOT_RESPONSE=$(curl -s "https://pim.technostationery.com/")
if echo "$ROOT_RESPONSE" | grep -q "data-hash\|index.html.twig\|Loading"; then
    echo "✓ Root serves SPA shell"
else
    echo "✗ Root doesn't serve SPA shell properly"
fi

# Test 2: Dashboard route should serve the SPA shell
echo ""
echo "Test 2: Dashboard route (/dashboard) should serve SPA shell..."
DASHBOARD_RESPONSE=$(curl -s "https://pim.technostationery.com/dashboard")
if echo "$DASHBOARD_RESPONSE" | grep -q "data-hash\|index.html.twig"; then
    echo "✓ Dashboard serves SPA shell"
else
    echo "✗ Dashboard doesn't serve SPA shell properly"
fi

# Test 3: Check if JavaScript routing file exists
echo ""
echo "Test 3: JavaScript routing configuration..."
JS_ROUTING_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "https://pim.technostationery.com/js/routing")
if [ "$JS_ROUTING_STATUS" = "200" ]; then
    echo "✓ JavaScript routing accessible (HTTP $JS_ROUTING_STATUS)"
else
    echo "✗ JavaScript routing issue (HTTP $JS_ROUTING_STATUS)"
fi

# Test 4: Login flow test
echo ""
echo "Test 4: Complete login flow..."
COOKIE_FILE="/tmp/spa_test_$$.txt"

# Get login page
curl -s -c "$COOKIE_FILE" "https://pim.technostationery.com/user/login" > /dev/null

# Get CSRF token
LOGIN_PAGE=$(curl -s -b "$COOKIE_FILE" "https://pim.technostationery.com/user/login")
CSRF_TOKEN=$(echo "$LOGIN_PAGE" | grep -oP 'name="_csrf_token"[^>]+value="\K[^"]+' | head -1)

if [ -n "$CSRF_TOKEN" ]; then
    # Submit login
    REDIRECT_URL=$(curl -s -i -b "$COOKIE_FILE" -c "$COOKIE_FILE" -L \
        -X POST "https://pim.technostationery.com/user/login-check" \
        -d "_username=admin" \
        -d "_password=PimAdmin2026!" \
        -d "_csrf_token=$CSRF_TOKEN" 2>&1 | grep -i "^location:" | tail -1 | sed 's/location: //i' | tr -d '\r\n')
    
    echo "Login redirects to: $REDIRECT_URL"
    
    if echo "$REDIRECT_URL" | grep -q "dashboard"; then
        echo "✓ Login redirects to dashboard (CORRECT)"
    else
        echo "✗ Login redirect issue: $REDIRECT_URL"
    fi
    
    # Test if we can access dashboard after login
    AUTHED_DASHBOARD=$(curl -s -b "$COOKIE_FILE" "https://pim.technostationery.com/dashboard")
    if echo "$AUTHED_DASHBOARD" | grep -q "data-hash\|dashboard"; then
        echo "✓ Can access dashboard when authenticated"
    else
        echo "✗ Cannot access dashboard properly"
    fi
fi

rm -f "$COOKIE_FILE"

echo ""
echo "================"
echo "SPA Test Complete"
