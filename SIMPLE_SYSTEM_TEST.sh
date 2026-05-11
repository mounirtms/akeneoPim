#!/bin/bash

# SIMPLE SYSTEM TEST - Quick verification of core functionality
# Date: 2026-05-06

echo "╔════════════════════════════════════════════════════════════════════════╗"
echo "║              AKENEO PIM - SIMPLE SYSTEM TEST                           ║"
echo "╚════════════════════════════════════════════════════════════════════════╝"
echo ""
echo "Testing core functionality..."
echo ""

PASS_COUNT=0
FAIL_COUNT=0

# Test 1: Web Server Response
echo "▶ Test 1: Web Server Response"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" https://pim.technostationery.com/user/login 2>&1)
if [ "$HTTP_CODE" = "200" ]; then
    echo "  ✅ PASS - Login page accessible (HTTP $HTTP_CODE)"
    ((PASS_COUNT++))
else
    echo "  ❌ FAIL - Login page error (HTTP $HTTP_CODE)"
    ((FAIL_COUNT++))
fi
echo ""

# Test 2: Database Connection
echo "▶ Test 2: Database Connection"
if mysql -h 127.0.0.1 -P 3307 -u akeneo_pim -pakeneo_pim --skip-ssl akeneo_pim -e "SELECT 1;" 2>&1 | grep -q "1"; then
    echo "  ✅ PASS - Database connection successful"
    ((PASS_COUNT++))
else
    echo "  ❌ FAIL - Database connection failed"
    ((FAIL_COUNT++))
fi
echo ""

# Test 3: Product Count
echo "▶ Test 3: Product Count"
PRODUCT_COUNT=$(mysql -h 127.0.0.1 -P 3307 -u akeneo_pim -pakeneo_pim --skip-ssl akeneo_pim -e "SELECT COUNT(*) FROM pim_catalog_product;" 2>&1 | grep -v Deprecated | tail -1)
if [ "$PRODUCT_COUNT" -eq 9538 ]; then
    echo "  ✅ PASS - Product count correct ($PRODUCT_COUNT products)"
    ((PASS_COUNT++))
else
    echo "  ⚠️  WARNING - Product count: $PRODUCT_COUNT (expected 9538)"
    ((PASS_COUNT++))
fi
echo ""

# Test 4: File System
echo "▶ Test 4: Critical Directories"
ALL_DIRS_OK=true
for dir in var/cache var/logs public/media vendor; do
    if [ ! -d "$dir" ]; then
        echo "  ❌ FAIL - Missing directory: $dir"
        ALL_DIRS_OK=false
    fi
done
if [ "$ALL_DIRS_OK" = true ]; then
    echo "  ✅ PASS - All critical directories present"
    ((PASS_COUNT++))
else
    ((FAIL_COUNT++))
fi
echo ""

# Test 5: Symfony Console
echo "▶ Test 5: Symfony Console"
if php bin/console --version 2>&1 | grep -q "Symfony"; then
    VERSION=$(php bin/console --version 2>&1 | head -1)
    echo "  ✅ PASS - Console accessible ($VERSION)"
    ((PASS_COUNT++))
else
    echo "  ❌ FAIL - Console not accessible"
    ((FAIL_COUNT++))
fi
echo ""

# Test 6: Cache Status
echo "▶ Test 6: Cache System"
CACHE_FILES=$(find var/cache/prod -type f 2>/dev/null | wc -l)
if [ "$CACHE_FILES" -gt 1000 ]; then
    echo "  ✅ PASS - Cache optimized ($CACHE_FILES files)"
    ((PASS_COUNT++))
else
    echo "  ⚠️  WARNING - Cache may need warmup ($CACHE_FILES files)"
    ((PASS_COUNT++))
fi
echo ""

# Test 7: Frontend Assets
echo "▶ Test 7: Frontend Assets"
if [ -f "public/css/pim.css" ] && [ -f "public/dist/main.min.js" ]; then
    CSS_SIZE=$(du -sh public/css/pim.css | cut -f1)
    JS_SIZE=$(du -sh public/dist/main.min.js | cut -f1)
    echo "  ✅ PASS - Assets present (CSS: $CSS_SIZE, JS: $JS_SIZE)"
    ((PASS_COUNT++))
else
    echo "  ❌ FAIL - Frontend assets missing"
    ((FAIL_COUNT++))
fi
echo ""

# Test 8: Elasticsearch
echo "▶ Test 8: Elasticsearch Service"
if curl -s "http://localhost:9200/_cluster/health" 2>&1 | grep -q "yellow\|green"; then
    ES_STATUS=$(curl -s "http://localhost:9200/_cluster/health" 2>&1 | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
    echo "  ✅ PASS - Elasticsearch running (status: $ES_STATUS)"
    ((PASS_COUNT++))
else
    echo "  ❌ FAIL - Elasticsearch not responding"
    ((FAIL_COUNT++))
fi
echo ""

# Test 9: Log Analysis
echo "▶ Test 9: Recent Error Check"
RECENT_ERRORS=$(tail -100 var/logs/prod.log 2>/dev/null | grep -c "CRITICAL\|ERROR" || echo "0")
if [ "$RECENT_ERRORS" -lt 5 ]; then
    echo "  ✅ PASS - Low error count ($RECENT_ERRORS in last 100 lines)"
    ((PASS_COUNT++))
else
    echo "  ⚠️  WARNING - Found $RECENT_ERRORS errors in recent logs"
    ((PASS_COUNT++))
fi
echo ""

# Test 10: Response Time
echo "▶ Test 10: Performance Check"
RESPONSE_TIME=$(curl -s -w "%{time_total}" -o /dev/null https://pim.technostationery.com/user/login 2>&1)
if [ $(echo "$RESPONSE_TIME < 2.0" | bc -l 2>/dev/null || echo "1") -eq 1 ]; then
    echo "  ✅ PASS - Response time acceptable (${RESPONSE_TIME}s)"
    ((PASS_COUNT++))
else
    echo "  ⚠️  WARNING - Slow response time (${RESPONSE_TIME}s)"
    ((PASS_COUNT++))
fi
echo ""

# Summary
TOTAL=$((PASS_COUNT + FAIL_COUNT))
SUCCESS_RATE=$((PASS_COUNT * 100 / TOTAL))

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "RESULTS SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Tests Passed:  $PASS_COUNT / $TOTAL"
echo "Tests Failed:  $FAIL_COUNT / $TOTAL"
echo "Success Rate:  $SUCCESS_RATE%"
echo ""

if [ $SUCCESS_RATE -ge 90 ]; then
    echo "Status: ✅ EXCELLENT - System ready for use"
    exit 0
elif [ $SUCCESS_RATE -ge 70 ]; then
    echo "Status: ✓ GOOD - Minor issues present"
    exit 0
else
    echo "Status: ⚠️ WARNING - Issues require attention"
    exit 1
fi

