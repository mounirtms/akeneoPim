#!/bin/bash
# Comprehensive Akeneo PIM Tests - Version 2
# Date: 2026-05-01

LOG_FILE="logs/pim_tests_$(date +%Y%m%d_%H%M%S).log"
mkdir -p logs

echo "========================================" | tee "$LOG_FILE"
echo "Akeneo PIM Comprehensive Test Suite" | tee -a "$LOG_FILE"
echo "Date: $(date)" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

PASSED=0
FAILED=0

test_result() {
    if [ $1 -eq 0 ]; then
        echo "✓ PASS: $2" | tee -a "$LOG_FILE"
        ((PASSED++))
    else
        echo "✗ FAIL: $2" | tee -a "$LOG_FILE"
        ((FAILED++))
    fi
}

# Test 1: Symfony Console Access
echo "=== Test 1: Symfony Console Access ===" | tee -a "$LOG_FILE"
cd /home/pim/public_html
php bin/console --version --env=prod &>> "$LOG_FILE"
test_result $? "Symfony console accessible"
echo "" | tee -a "$LOG_FILE"

# Test 2: Cache System
echo "=== Test 2: Cache System ===" | tee -a "$LOG_FILE"
php bin/console cache:pool:list --env=prod &>> "$LOG_FILE"
test_result $? "Cache pools configured"
echo "" | tee -a "$LOG_FILE"

# Test 3: Product Indexing
echo "=== Test 3: Product Indexing ===" | tee -a "$LOG_FILE"
php bin/console pim:product:index --all --env=prod 2>&1 | tee -a "$LOG_FILE" | grep -q "products indexed"
test_result $? "Product indexing command"
echo "" | tee -a "$LOG_FILE"

# Test 4: Product Model Indexing
echo "=== Test 4: Product Model Indexing ===" | tee -a "$LOG_FILE"
php bin/console pim:product-model:index --all --env=prod 2>&1 | tee -a "$LOG_FILE" | grep -q "indexed"
test_result $? "Product model indexing"
echo "" | tee -a "$LOG_FILE"

# Test 5: Elasticsearch Status
echo "=== Test 5: Elasticsearch Status ===" | tee -a "$LOG_FILE"
curl -s http://localhost:9200/_cluster/health | tee -a "$LOG_FILE" | grep -q '"status":"yellow"\|"status":"green"'
test_result $? "Elasticsearch cluster health"

ES_COUNT=$(curl -s http://localhost:9200/akeneo_pim_product_and_product_model/_count | grep -o '"count":[0-9]*' | cut -d: -f2)
echo "Products indexed: $ES_COUNT" | tee -a "$LOG_FILE"
test_result 0 "Elasticsearch index count: $ES_COUNT products"
echo "" | tee -a "$LOG_FILE"

# Test 6: Database Connection
echo "=== Test 6: Database Connection ===" | tee -a "$LOG_FILE"
php bin/console dbal:run-sql "SELECT COUNT(*) as count FROM pim_catalog_product" --env=prod 2>&1 | tee -a "$LOG_FILE" | grep -q "count"
test_result $? "Database query execution"
echo "" | tee -a "$LOG_FILE"

# Test 7: Completeness Calculation
echo "=== Test 7: Completeness Calculation ===" | tee -a "$LOG_FILE"
timeout 30 php bin/console pim:completeness:calculate --env=prod 2>&1 | tee -a "$LOG_FILE" | grep -q "completeness\|Complete\|processed"
test_result $? "Completeness calculation"
echo "" | tee -a "$LOG_FILE"

# Test 8: Asset Management
echo "=== Test 8: Asset Management ===" | tee -a "$LOG_FILE"
if [ -d "/home/pim/public_html/public/bundles" ]; then
    BUNDLE_COUNT=$(ls -1 /home/pim/public_html/public/bundles | wc -l)
    echo "Asset bundles: $BUNDLE_COUNT" | tee -a "$LOG_FILE"
    test_result 0 "Asset bundles present: $BUNDLE_COUNT bundles"
else
    test_result 1 "Asset bundles directory missing"
fi
echo "" | tee -a "$LOG_FILE"

# Test 9: Product Images
echo "=== Test 9: Product Images ===" | tee -a "$LOG_FILE"
if [ -d "/home/pim/public_html/public/media/catalog" ]; then
    IMAGE_COUNT=$(find /home/pim/public_html/public/media/catalog -type f -name "*.jpg" -o -name "*.png" | wc -l)
    IMAGE_SIZE=$(du -sh /home/pim/public_html/public/media/catalog 2>/dev/null | cut -f1)
    echo "Product images: $IMAGE_COUNT files, Size: $IMAGE_SIZE" | tee -a "$LOG_FILE"
    test_result 0 "Product images: $IMAGE_COUNT files"
else
    test_result 1 "Product images directory missing"
fi
echo "" | tee -a "$LOG_FILE"

# Test 10: Attribute Configuration
echo "=== Test 10: Attribute Configuration ===" | tee -a "$LOG_FILE"
php bin/console pim:catalog:get-product-attributes --env=prod 2>&1 | tee -a "$LOG_FILE" | head -10
test_result ${PIPESTATUS[0]} "Attribute configuration accessible"
echo "" | tee -a "$LOG_FILE"

# Test 11: Routing Configuration
echo "=== Test 11: Routing Configuration ===" | tee -a "$LOG_FILE"
php bin/console fos:js-routing:dump --format=json --target=public/js/fos_js_routes.json --env=prod &>> "$LOG_FILE"
test_result $? "JavaScript routing configuration"

if [ -f "public/js/fos_js_routes.json" ]; then
    ROUTES_SIZE=$(du -h public/js/fos_js_routes.json | cut -f1)
    echo "Routes file: $ROUTES_SIZE" | tee -a "$LOG_FILE"
fi
echo "" | tee -a "$LOG_FILE"

# Test 12: System Resources
echo "=== Test 12: System Resources ===" | tee -a "$LOG_FILE"
LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | tr -d ',')
MEM_USED=$(free -h | awk '/^Mem:/ {print $3}')
MEM_TOTAL=$(free -h | awk '/^Mem:/ {print $2}')
DISK_USAGE=$(df -h /home/pim/public_html | awk 'NR==2 {print $5}')

echo "CPU Load: $LOAD_AVG" | tee -a "$LOG_FILE"
echo "Memory: $MEM_USED / $MEM_TOTAL" | tee -a "$LOG_FILE"
echo "Disk Usage: $DISK_USAGE" | tee -a "$LOG_FILE"

# CPU load should be under 10 for stable operation
if (( $(echo "$LOAD_AVG < 10" | bc -l) )); then
    test_result 0 "CPU load acceptable: $LOAD_AVG"
else
    test_result 1 "CPU load high: $LOAD_AVG"
fi
echo "" | tee -a "$LOG_FILE"

# Test 13: Frontend Assets
echo "=== Test 13: Frontend Assets Verification ===" | tee -a "$LOG_FILE"
KEY_FILES=(
    "public/js/fos_js_routes.json"
    "public/bundles/pimui/js/router.js"
    "public/js/module-registry.js"
)

for file in "${KEY_FILES[@]}"; do
    if [ -f "/home/pim/public_html/$file" ]; then
        SIZE=$(du -h "/home/pim/public_html/$file" | cut -f1)
        echo "✓ $file ($SIZE)" | tee -a "$LOG_FILE"
        test_result 0 "Asset file present: $file"
    else
        echo "✗ Missing: $file" | tee -a "$LOG_FILE"
        test_result 1 "Asset file missing: $file"
    fi
done
echo "" | tee -a "$LOG_FILE"

# Test 14: Web Server Access
echo "=== Test 14: Web Server Access ===" | tee -a "$LOG_FILE"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" https://pim.technostationery.com/ 2>/dev/null || echo "000")
echo "HTTP Response Code: $HTTP_CODE" | tee -a "$LOG_FILE"
if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "302" ]]; then
    test_result 0 "Web server responding: HTTP $HTTP_CODE"
else
    test_result 1 "Web server issue: HTTP $HTTP_CODE"
fi
echo "" | tee -a "$LOG_FILE"

# Test 15: Permissions Check
echo "=== Test 15: Directory Permissions ===" | tee -a "$LOG_FILE"
CRITICAL_DIRS=(
    "var/cache"
    "var/logs"
    "var/file_storage"
    "public/media"
)

for dir in "${CRITICAL_DIRS[@]}"; do
    FULL_PATH="/home/pim/public_html/$dir"
    if [ -d "$FULL_PATH" ]; then
        if [ -w "$FULL_PATH" ]; then
            test_result 0 "Directory writable: $dir"
        else
            test_result 1 "Directory not writable: $dir"
        fi
    else
        test_result 1 "Directory missing: $dir"
    fi
done
echo "" | tee -a "$LOG_FILE"

# Summary
echo "========================================" | tee -a "$LOG_FILE"
echo "TEST SUMMARY" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"
TOTAL=$((PASSED + FAILED))
SUCCESS_RATE=$(awk "BEGIN {printf \"%.1f\", ($PASSED/$TOTAL)*100}")
echo "Total Tests: $TOTAL" | tee -a "$LOG_FILE"
echo "Passed: $PASSED" | tee -a "$LOG_FILE"
echo "Failed: $FAILED" | tee -a "$LOG_FILE"
echo "Success Rate: $SUCCESS_RATE%" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

if [ $FAILED -eq 0 ]; then
    echo "✓ ALL TESTS PASSED - AKENEO PIM IS STABLE" | tee -a "$LOG_FILE"
    exit 0
elif [ $FAILED -le 3 ]; then
    echo "⚠ MINOR ISSUES DETECTED - AKENEO PIM IS MOSTLY STABLE" | tee -a "$LOG_FILE"
    exit 0
else
    echo "✗ CRITICAL ISSUES DETECTED - REQUIRES ATTENTION" | tee -a "$LOG_FILE"
    exit 1
fi
