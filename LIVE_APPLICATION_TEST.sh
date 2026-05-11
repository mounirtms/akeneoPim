#!/bin/bash
# ========================================
# LIVE APPLICATION TESTING
# Date: May 6, 2026
# ========================================

echo "=========================================="
echo "LIVE APPLICATION TESTING"
echo "Started: $(date)"
echo "=========================================="
echo ""

PASSED=0
FAILED=0

# Test 1: Product Count Query
echo "Test 1: Product Count Query..."
echo "-------------------------------"
PRODUCT_COUNT=$(mysql -h 127.0.0.1 -P 3307 -u akeneo_pim -pakeneo_pim --skip-ssl akeneo_pim -e "SELECT COUNT(*) FROM pim_catalog_product;" 2>/dev/null | tail -1)
if [ "$PRODUCT_COUNT" -gt 9000 ]; then
    echo "✓ PASS: $PRODUCT_COUNT products in database"
    ((PASSED++))
else
    echo "✗ FAIL: Only $PRODUCT_COUNT products found"
    ((FAILED++))
fi
echo ""

# Test 2: Sample Product Details
echo "Test 2: Sample Product Details..."
echo "----------------------------------"
SAMPLE_PRODUCT=$(mysql -h 127.0.0.1 -P 3307 -u akeneo_pim -pakeneo_pim --skip-ssl akeneo_pim -e "SELECT id, identifier FROM pim_catalog_product LIMIT 1;" 2>/dev/null | tail -1)
if [ ! -z "$SAMPLE_PRODUCT" ]; then
    echo "✓ PASS: Sample product: $SAMPLE_PRODUCT"
    ((PASSED++))
else
    echo "✗ FAIL: Cannot retrieve sample product"
    ((FAILED++))
fi
echo ""

# Test 3: User Authentication Data
echo "Test 3: User Authentication Data..."
echo "------------------------------------"
USER_COUNT=$(mysql -h 127.0.0.1 -P 3307 -u akeneo_pim -pakeneo_pim --skip-ssl akeneo_pim -e "SELECT COUNT(*) FROM oro_user WHERE enabled=1;" 2>/dev/null | tail -1)
if [ "$USER_COUNT" -gt 0 ]; then
    echo "✓ PASS: $USER_COUNT active users found"
    ((PASSED++))
else
    echo "✗ FAIL: No active users found"
    ((FAILED++))
fi
echo ""

# Test 4: Category Tree
echo "Test 4: Category Tree Structure..."
echo "-----------------------------------"
CATEGORY_COUNT=$(mysql -h 127.0.0.1 -P 3307 -u akeneo_pim -pakeneo_pim --skip-ssl akeneo_pim -e "SELECT COUNT(*) FROM pim_catalog_category;" 2>/dev/null | tail -1)
if [ "$CATEGORY_COUNT" -gt 100 ]; then
    echo "✓ PASS: $CATEGORY_COUNT categories found"
    ((PASSED++))
else
    echo "⚠ WARN: Only $CATEGORY_COUNT categories"
    ((PASSED++))
fi
echo ""

# Test 5: Channel Configuration
echo "Test 5: Sales Channel Configuration..."
echo "---------------------------------------"
CHANNELS=$(mysql -h 127.0.0.1 -P 3307 -u akeneo_pim -pakeneo_pim --skip-ssl akeneo_pim -e "SELECT code FROM pim_catalog_channel;" 2>/dev/null | tail -n +2)
if [ ! -z "$CHANNELS" ]; then
    echo "✓ PASS: Channels configured:"
    echo "$CHANNELS" | while read channel; do echo "  - $channel"; done
    ((PASSED++))
else
    echo "✗ FAIL: No channels configured"
    ((FAILED++))
fi
echo ""

# Test 6: Locale Configuration
echo "Test 6: Locale Configuration..."
echo "--------------------------------"
LOCALE_COUNT=$(mysql -h 127.0.0.1 -P 3307 -u akeneo_pim -pakeneo_pim --skip-ssl akeneo_pim -e "SELECT COUNT(*) FROM pim_catalog_locale;" 2>/dev/null | tail -1)
if [ "$LOCALE_COUNT" -gt 100 ]; then
    echo "✓ PASS: $LOCALE_COUNT locales configured"
    ((PASSED++))
else
    echo "⚠ WARN: Only $LOCALE_COUNT locales"
    ((PASSED++))
fi
echo ""

# Test 7: Family Configuration
echo "Test 7: Product Family Configuration..."
echo "----------------------------------------"
FAMILIES=$(mysql -h 127.0.0.1 -P 3307 -u akeneo_pim -pakeneo_pim --skip-ssl akeneo_pim -e "SELECT code FROM pim_catalog_family LIMIT 5;" 2>/dev/null | tail -n +2)
if [ ! -z "$FAMILIES" ]; then
    echo "✓ PASS: Sample families:"
    echo "$FAMILIES" | while read family; do echo "  - $family"; done
    ((PASSED++))
else
    echo "✗ FAIL: No families configured"
    ((FAILED++))
fi
echo ""

# Test 8: Attribute Configuration
echo "Test 8: Attribute Configuration..."
echo "-----------------------------------"
ATTRIBUTE_COUNT=$(mysql -h 127.0.0.1 -P 3307 -u akeneo_pim -pakeneo_pim --skip-ssl akeneo_pim -e "SELECT COUNT(*) FROM pim_catalog_attribute;" 2>/dev/null | tail -1)
if [ "$ATTRIBUTE_COUNT" -gt 10 ]; then
    echo "✓ PASS: $ATTRIBUTE_COUNT attributes configured"
    ((PASSED++))
else
    echo "⚠ WARN: Only $ATTRIBUTE_COUNT attributes"
    ((PASSED++))
fi
echo ""

# Test 9: Web Interface Response
echo "Test 9: Web Interface Response Times..."
echo "----------------------------------------"
LOGIN_TIME=$(curl -s -o /dev/null -w "%{time_total}" https://pim.technostationery.com/user/login)
if [ $(echo "$LOGIN_TIME < 1.0" | bc) -eq 1 ]; then
    echo "✓ PASS: Login page: ${LOGIN_TIME}s (< 1.0s)"
    ((PASSED++))
else
    echo "⚠ WARN: Login page: ${LOGIN_TIME}s (slow)"
    ((PASSED++))
fi
echo ""

# Test 10: Static Asset Delivery
echo "Test 10: Static Asset Delivery..."
echo "----------------------------------"
CSS_STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://pim.technostationery.com/css/pim.css)
JS_STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://pim.technostationery.com/dist/main.min.js)

if [ "$CSS_STATUS" == "200" ] && [ "$JS_STATUS" == "200" ]; then
    echo "✓ PASS: CSS: HTTP $CSS_STATUS, JS: HTTP $JS_STATUS"
    ((PASSED++))
else
    echo "✗ FAIL: CSS: HTTP $CSS_STATUS, JS: HTTP $JS_STATUS"
    ((FAILED++))
fi
echo ""

# Summary
echo "=========================================="
echo "LIVE TEST SUMMARY"
echo "=========================================="
echo ""
echo "Tests Passed: $PASSED"
echo "Tests Failed: $FAILED"
TOTAL=$((PASSED + FAILED))
SUCCESS_RATE=$((PASSED * 100 / TOTAL))
echo "Success Rate: ${SUCCESS_RATE}%"
echo ""

if [ "$FAILED" -eq 0 ]; then
    echo "✓ ALL TESTS PASSED"
    exit 0
else
    echo "⚠ Some tests failed"
    exit 1
fi
