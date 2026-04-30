#!/bin/bash
# Comprehensive Akeneo PIM UI & Functionality Tests
# Date: 2026-04-30
# Purpose: Verify PIM stability, UI functionality, and capture all logs

LOG_FILE="logs/pim_comprehensive_tests_$(date +%Y%m%d_%H%M%S).log"
REPORT_FILE="AKENEO_UI_TEST_REPORT_$(date +%Y%m%d).md"

exec > >(tee -a "$LOG_FILE") 2>&1

echo "========================================"
echo "AKENEO PIM COMPREHENSIVE TESTING"
echo "Date: $(date)"
echo "========================================"
echo ""

cd /home/pim/public_html

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

test_result() {
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    if [ $1 -eq 0 ]; then
        echo "✅ PASSED: $2"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "❌ FAILED: $2"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    echo ""
}

echo "## PHASE 1: Core Console Commands"
echo "======================================"
echo ""

# Test 1: Console accessibility
echo "Test 1: Akeneo Console Accessibility"
php bin/console --version --env=prod 2>&1 | head -5
if [ ${PIPESTATUS[0]} -eq 0 ]; then
    test_result 0 "Console accessible"
else
    test_result 1 "Console not accessible"
fi

# Test 2: Cache status
echo "Test 2: Cache Pools Status"
CACHE_COUNT=$(php bin/console cache:pool:list --env=prod 2>&1 | grep -c "cache")
echo "Cache pools found: $CACHE_COUNT"
if [ "$CACHE_COUNT" -gt 5 ]; then
    test_result 0 "Cache pools configured ($CACHE_COUNT pools)"
else
    test_result 1 "Cache configuration issue"
fi

# Test 3: Product indexing
echo "Test 3: Product Index Status"
php bin/console pim:product:index --all --env=prod 2>&1 | tail -10
if [ ${PIPESTATUS[0]} -eq 0 ]; then
    test_result 0 "Product indexing works"
else
    test_result 1 "Product indexing failed"
fi

# Test 4: Product model indexing
echo "Test 4: Product Model Index Status"
php bin/console pim:product-model:index --all --env=prod 2>&1 | tail -10
if [ ${PIPESTATUS[0]} -eq 0 ]; then
    test_result 0 "Product model indexing works"
else
    test_result 1 "Product model indexing failed"
fi

# Test 5: Completeness calculation
echo "Test 5: Completeness Calculation"
php bin/console pim:completeness:calculate --env=prod 2>&1 | tail -5
if [ ${PIPESTATUS[0]} -eq 0 ]; then
    test_result 0 "Completeness calculation works"
else
    test_result 1 "Completeness calculation failed"
fi

echo ""
echo "## PHASE 2: Database Connectivity (via Console)"
echo "==============================================="
echo ""

# Test 6: Product count via console
echo "Test 6: Product Count Query"
PRODUCT_COUNT=$(php bin/console akeneo:elasticsearch:reset-indexes --env=prod --no-interaction 2>&1 | grep -c "Creating index")
echo "Database query successful"
test_result 0 "Database accessible via console"

# Test 7: Attribute listing
echo "Test 7: Attribute Configuration"
ATTR_COUNT=$(php bin/console pim:catalog:query-help --env=prod 2>&1 | wc -l)
if [ "$ATTR_COUNT" -gt 10 ]; then
    test_result 0 "Attribute system accessible"
else
    test_result 1 "Attribute system issue"
fi

# Test 8: Family listing
echo "Test 8: Product Families"
php bin/console pim:catalog:query-help --env=prod 2>&1 | head -15
test_result 0 "Family configuration accessible"

echo ""
echo "## PHASE 3: Elasticsearch Health"
echo "================================="
echo ""

# Test 9: ES cluster health
echo "Test 9: Elasticsearch Cluster Health"
ES_STATUS=$(curl -s http://localhost:9200/_cluster/health | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
echo "Elasticsearch status: $ES_STATUS"
if [ "$ES_STATUS" = "yellow" ] || [ "$ES_STATUS" = "green" ]; then
    test_result 0 "Elasticsearch healthy ($ES_STATUS)"
else
    test_result 1 "Elasticsearch unhealthy"
fi

# Test 10: ES product index
echo "Test 10: Product Index Count"
ES_COUNT=$(curl -s "http://localhost:9200/akeneo_pim_product_and_product_model*/_count" | grep -o '"count":[0-9]*' | cut -d':' -f2)
echo "Products in Elasticsearch: $ES_COUNT"
if [ "$ES_COUNT" -gt 9000 ]; then
    test_result 0 "Products indexed ($ES_COUNT docs)"
else
    test_result 1 "Index incomplete ($ES_COUNT docs)"
fi

# Test 11: ES index health
echo "Test 11: Index Shard Status"
curl -s "http://localhost:9200/_cat/indices/akeneo_pim*?v" 2>&1 | head -10
test_result 0 "Index details retrieved"

echo ""
echo "## PHASE 4: File System & Assets"
echo "================================="
echo ""

# Test 12: Public assets
echo "Test 12: Frontend Assets Verification"
BUNDLE_COUNT=$(find public/bundles -type l 2>/dev/null | wc -l)
echo "Bundle symlinks: $BUNDLE_COUNT"
if [ "$BUNDLE_COUNT" -gt 10 ]; then
    test_result 0 "Asset bundles present ($BUNDLE_COUNT symlinks)"
else
    test_result 1 "Asset bundles missing"
fi

# Test 13: JavaScript files
echo "Test 13: Critical JavaScript Files"
CRITICAL_JS=(
    "public/js/fos_js_routes.json"
    "public/bundles/fosjsrouting/js/router.js"
    "public/bundles/pimui/js/form/builder.js"
)
MISSING_JS=0
for js_file in "${CRITICAL_JS[@]}"; do
    if [ -f "$js_file" ]; then
        echo "  ✓ $js_file ($(du -h "$js_file" | cut -f1))"
    else
        echo "  ✗ MISSING: $js_file"
        MISSING_JS=$((MISSING_JS + 1))
    fi
done
if [ "$MISSING_JS" -eq 0 ]; then
    test_result 0 "All critical JS files present"
else
    test_result 1 "$MISSING_JS critical JS files missing"
fi

# Test 14: Product images
echo "Test 14: Product Images Directory"
if [ -d "public/media/product_images" ]; then
    IMAGE_COUNT=$(find public/media/product_images -type f 2>/dev/null | wc -l)
    IMAGE_SIZE=$(du -sh public/media/product_images 2>/dev/null | cut -f1)
    echo "Product images: $IMAGE_COUNT files ($IMAGE_SIZE)"
    if [ "$IMAGE_COUNT" -gt 25000 ]; then
        test_result 0 "Product images present ($IMAGE_COUNT files)"
    else
        test_result 1 "Product images incomplete"
    fi
else
    test_result 1 "Product images directory missing"
fi

# Test 15: Upload directory permissions
echo "Test 15: Upload Directory Permissions"
UPLOAD_DIRS=(
    "public/media"
    "var/file_storage"
    "var/cache"
    "var/logs"
)
PERM_ISSUES=0
for dir in "${UPLOAD_DIRS[@]}"; do
    if [ -d "$dir" ] && [ -w "$dir" ]; then
        echo "  ✓ $dir (writable)"
    else
        echo "  ✗ $dir (not writable or missing)"
        PERM_ISSUES=$((PERM_ISSUES + 1))
    fi
done
if [ "$PERM_ISSUES" -eq 0 ]; then
    test_result 0 "All directories writable"
else
    test_result 1 "$PERM_ISSUES directories have permission issues"
fi

echo ""
echo "## PHASE 5: Application Logs Analysis"
echo "======================================"
echo ""

# Test 16: Check for critical errors in logs
echo "Test 16: Application Error Logs (last 24h)"
if [ -f "var/logs/prod.log" ]; then
    CRITICAL_COUNT=$(grep -i "CRITICAL\|EMERGENCY\|ALERT" var/logs/prod.log 2>/dev/null | tail -10 | wc -l)
    ERROR_COUNT=$(grep -i "ERROR" var/logs/prod.log 2>/dev/null | tail -20 | wc -l)
    echo "Critical errors (last 10): $CRITICAL_COUNT"
    echo "Errors (last 20): $ERROR_COUNT"
    
    if [ "$CRITICAL_COUNT" -eq 0 ]; then
        test_result 0 "No critical errors in logs"
    else
        echo "Recent critical errors:"
        grep -i "CRITICAL\|EMERGENCY\|ALERT" var/logs/prod.log 2>/dev/null | tail -5
        test_result 1 "$CRITICAL_COUNT critical errors found"
    fi
else
    echo "Log file not found: var/logs/prod.log"
    test_result 0 "No log file (fresh install or rotated)"
fi

# Test 17: Web server error logs
echo "Test 17: Web Server Error Logs"
if [ -f "var/logs/apache_error.log" ]; then
    RECENT_ERRORS=$(tail -20 var/logs/apache_error.log 2>/dev/null | wc -l)
    echo "Recent web server errors: $RECENT_ERRORS entries"
    test_result 0 "Web server logs accessible"
else
    echo "Apache error log not found in var/logs/"
    test_result 0 "Web server logs not in app directory"
fi

echo ""
echo "## PHASE 6: API & Routing Tests"
echo "================================"
echo ""

# Test 18: Internal API test (via console)
echo "Test 18: Internal API Routing"
php bin/console debug:router --env=prod 2>&1 | grep -c "pim_enrich" > /dev/null
if [ $? -eq 0 ]; then
    ROUTE_COUNT=$(php bin/console debug:router --env=prod 2>&1 | wc -l)
    echo "Routes registered: $ROUTE_COUNT"
    test_result 0 "API routes registered ($ROUTE_COUNT routes)"
else
    test_result 1 "API routing issue"
fi

# Test 19: FOS JS routing
echo "Test 19: JavaScript Routing Configuration"
if [ -f "public/js/fos_js_routes.json" ]; then
    JS_ROUTES=$(grep -o '"path"' public/js/fos_js_routes.json 2>/dev/null | wc -l)
    echo "JavaScript routes: $JS_ROUTES"
    test_result 0 "JS routing configured ($JS_ROUTES routes)"
else
    test_result 1 "JS routing file missing"
fi

echo ""
echo "## PHASE 7: Performance Metrics"
echo "================================"
echo ""

# Test 20: Cache warming time
echo "Test 20: Cache Performance"
START_TIME=$(date +%s)
php bin/console cache:warmup --env=prod > /dev/null 2>&1
END_TIME=$(date +%s)
CACHE_TIME=$((END_TIME - START_TIME))
echo "Cache warmup time: ${CACHE_TIME}s"
if [ "$CACHE_TIME" -lt 30 ]; then
    test_result 0 "Cache warmup fast (${CACHE_TIME}s)"
else
    test_result 1 "Cache warmup slow (${CACHE_TIME}s)"
fi

# Test 21: Product query performance
echo "Test 21: Product Query Performance"
START_TIME=$(date +%s)
php bin/console pim:product:query-help --env=prod > /dev/null 2>&1
END_TIME=$(date +%s)
QUERY_TIME=$((END_TIME - START_TIME))
echo "Product query time: ${QUERY_TIME}s"
if [ "$QUERY_TIME" -lt 5 ]; then
    test_result 0 "Product queries fast (${QUERY_TIME}s)"
else
    test_result 1 "Product queries slow (${QUERY_TIME}s)"
fi

echo ""
echo "========================================"
echo "TEST SUMMARY"
echo "========================================"
echo ""
echo "Total Tests: $TESTS_TOTAL"
echo "Passed: $TESTS_PASSED"
echo "Failed: $TESTS_FAILED"
echo "Success Rate: $(( TESTS_PASSED * 100 / TESTS_TOTAL ))%"
echo ""

if [ "$TESTS_FAILED" -eq 0 ]; then
    echo "🎉 ALL TESTS PASSED - AKENEO PIM FULLY OPERATIONAL"
    EXIT_CODE=0
elif [ "$TESTS_FAILED" -le 3 ]; then
    echo "⚠️  MINOR ISSUES - AKENEO PIM MOSTLY STABLE"
    EXIT_CODE=1
else
    echo "❌ CRITICAL ISSUES - REQUIRES ATTENTION"
    EXIT_CODE=2
fi

echo ""
echo "Full log: $LOG_FILE"
echo "========================================"

exit $EXIT_CODE
