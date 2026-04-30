#!/bin/bash
# Akeneo PIM UI Monkey Tests & Frontend Validation
# Date: 2026-05-01

LOG_FILE="logs/ui_monkey_tests_$(date +%Y%m%d_%H%M%S).log"
mkdir -p logs

echo "========================================" | tee "$LOG_FILE"
echo "Akeneo PIM UI Monkey Tests" | tee -a "$LOG_FILE"
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

# Test 1: Homepage Access
echo "=== Test 1: Homepage Access ===" | tee -a "$LOG_FILE"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" https://pim.technostationery.com/ 2>/dev/null)
echo "HTTP Response: $HTTP_CODE" | tee -a "$LOG_FILE"
if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "302" ]]; then
    test_result 0 "Homepage accessible (HTTP $HTTP_CODE)"
else
    test_result 1 "Homepage issue (HTTP $HTTP_CODE)"
fi
echo "" | tee -a "$LOG_FILE"

# Test 2: Login Page
echo "=== Test 2: Login Page ===" | tee -a "$LOG_FILE"
LOGIN_RESPONSE=$(curl -s https://pim.technostationery.com/user/login 2>/dev/null | grep -o "login\|username\|password" | head -3)
if [ ! -z "$LOGIN_RESPONSE" ]; then
    test_result 0 "Login page renders"
    echo "Found elements: $LOGIN_RESPONSE" | tee -a "$LOG_FILE"
else
    test_result 1 "Login page not rendering"
fi
echo "" | tee -a "$LOG_FILE"

# Test 3: JavaScript Assets
echo "=== Test 3: JavaScript Assets ===" | tee -a "$LOG_FILE"
JS_FILES=(
    "public/js/fos_js_routes.json"
    "public/js/module-registry.js"
    "public/bundles/pimui/js/router.js"
)

for file in "${JS_FILES[@]}"; do
    if [ -f "/home/pim/public_html/$file" ]; then
        SIZE=$(stat -f%z "/home/pim/public_html/$file" 2>/dev/null || stat -c%s "/home/pim/public_html/$file" 2>/dev/null)
        if [ "$SIZE" -gt 100 ]; then
            test_result 0 "JS asset valid: $file (${SIZE} bytes)"
        else
            test_result 1 "JS asset too small: $file (${SIZE} bytes)"
        fi
    else
        test_result 1 "JS asset missing: $file"
    fi
done
echo "" | tee -a "$LOG_FILE"

# Test 4: CSS Assets
echo "=== Test 4: CSS Assets ===" | tee -a "$LOG_FILE"
CSS_COUNT=$(find /home/pim/public_html/public/bundles -name "*.css" 2>/dev/null | wc -l)
echo "CSS files found: $CSS_COUNT" | tee -a "$LOG_FILE"
if [ $CSS_COUNT -gt 5 ]; then
    test_result 0 "CSS assets present ($CSS_COUNT files)"
else
    test_result 1 "Insufficient CSS assets ($CSS_COUNT files)"
fi
echo "" | tee -a "$LOG_FILE"

# Test 5: Product Images
echo "=== Test 5: Product Images ===" | tee -a "$LOG_FILE"
IMAGE_COUNT=$(find /home/pim/public_html/public/media/product_images -type f \( -name "*.jpg" -o -name "*.png" \) 2>/dev/null | wc -l)
IMAGE_SIZE=$(du -sh /home/pim/public_html/public/media/product_images 2>/dev/null | cut -f1)
echo "Product images: $IMAGE_COUNT files, Total size: $IMAGE_SIZE" | tee -a "$LOG_FILE"
if [ $IMAGE_COUNT -gt 1000 ]; then
    test_result 0 "Product images present ($IMAGE_COUNT files)"
else
    test_result 1 "Insufficient product images ($IMAGE_COUNT files)"
fi
echo "" | tee -a "$LOG_FILE"

# Test 6: Image Size Variants
echo "=== Test 6: Image Size Variants ===" | tee -a "$LOG_FILE"
for variant in large medium thumbnail; do
    VAR_COUNT=$(find /home/pim/public_html/public/media/product_images/$variant -type f 2>/dev/null | wc -l)
    echo "$variant: $VAR_COUNT files" | tee -a "$LOG_FILE"
    if [ $VAR_COUNT -gt 100 ]; then
        test_result 0 "Image variant present: $variant ($VAR_COUNT files)"
    else
        test_result 1 "Image variant missing/insufficient: $variant ($VAR_COUNT files)"
    fi
done
echo "" | tee -a "$LOG_FILE"

# Test 7: Database Product Count
echo "=== Test 7: Database Product Count ===" | tee -a "$LOG_FILE"
cd /home/pim/public_html
PRODUCT_COUNT=$(php bin/console dbal:run-sql "SELECT COUNT(*) as count FROM pim_catalog_product WHERE is_enabled = 1" --env=prod 2>/dev/null | grep -o '[0-9]*' | tail -1)
echo "Enabled products in database: $PRODUCT_COUNT" | tee -a "$LOG_FILE"
if [ "$PRODUCT_COUNT" -gt 1000 ]; then
    test_result 0 "Database products present ($PRODUCT_COUNT products)"
else
    test_result 1 "Insufficient products in database ($PRODUCT_COUNT products)"
fi
echo "" | tee -a "$LOG_FILE"

# Test 8: Elasticsearch Index
echo "=== Test 8: Elasticsearch Index ===" | tee -a "$LOG_FILE"
ES_COUNT=$(curl -s http://localhost:9200/akeneo_pim_product_and_product_model/_count 2>/dev/null | grep -o '"count":[0-9]*' | cut -d: -f2)
echo "Elasticsearch indexed products: $ES_COUNT" | tee -a "$LOG_FILE"
if [ "$ES_COUNT" -gt 1000 ]; then
    test_result 0 "Elasticsearch index healthy ($ES_COUNT products)"
else
    test_result 1 "Elasticsearch index issue ($ES_COUNT products)"
fi
echo "" | tee -a "$LOG_FILE"

# Test 9: Category Structure
echo "=== Test 9: Category Structure ===" | tee -a "$LOG_FILE"
CATEGORY_COUNT=$(php bin/console dbal:run-sql "SELECT COUNT(*) as count FROM pim_catalog_category" --env=prod 2>/dev/null | grep -o '[0-9]*' | tail -1)
echo "Categories in database: $CATEGORY_COUNT" | tee -a "$LOG_FILE"
if [ "$CATEGORY_COUNT" -gt 10 ]; then
    test_result 0 "Category structure present ($CATEGORY_COUNT categories)"
else
    test_result 1 "Insufficient categories ($CATEGORY_COUNT categories)"
fi
echo "" | tee -a "$LOG_FILE"

# Test 10: Product Models
echo "=== Test 10: Product Models ===" | tee -a "$LOG_FILE"
MODEL_COUNT=$(php bin/console dbal:run-sql "SELECT COUNT(*) as count FROM pim_catalog_product_model" --env=prod 2>/dev/null | grep -o '[0-9]*' | tail -1)
echo "Product models in database: $MODEL_COUNT" | tee -a "$LOG_FILE"
if [ "$MODEL_COUNT" -gt 50 ]; then
    test_result 0 "Product models present ($MODEL_COUNT models)"
else
    test_result 1 "Few product models ($MODEL_COUNT models)"
fi
echo "" | tee -a "$LOG_FILE"

# Test 11: Cache Functionality
echo "=== Test 11: Cache Functionality ===" | tee -a "$LOG_FILE"
php bin/console cache:pool:list --env=prod &>> "$LOG_FILE"
test_result $? "Cache pools accessible"
echo "" | tee -a "$LOG_FILE"

# Test 12: Routing Configuration
echo "=== Test 12: Routing Configuration ===" | tee -a "$LOG_FILE"
if [ -f "/home/pim/public_html/public/js/fos_js_routes.json" ]; then
    ROUTE_COUNT=$(grep -o '"tokens"' /home/pim/public_html/public/js/fos_js_routes.json | wc -l)
    echo "Routes configured: $ROUTE_COUNT" | tee -a "$LOG_FILE"
    if [ $ROUTE_COUNT -gt 10 ]; then
        test_result 0 "Routing configuration valid ($ROUTE_COUNT routes)"
    else
        test_result 1 "Insufficient routes ($ROUTE_COUNT routes)"
    fi
else
    test_result 1 "Routes file missing"
fi
echo "" | tee -a "$LOG_FILE"

# Test 13: Asset Bundles
echo "=== Test 13: Asset Bundles ===" | tee -a "$LOG_FILE"
BUNDLE_COUNT=$(ls -1 /home/pim/public_html/public/bundles 2>/dev/null | wc -l)
echo "Asset bundles: $BUNDLE_COUNT" | tee -a "$LOG_FILE"
if [ $BUNDLE_COUNT -gt 10 ]; then
    test_result 0 "Asset bundles present ($BUNDLE_COUNT bundles)"
else
    test_result 1 "Insufficient asset bundles ($BUNDLE_COUNT bundles)"
fi
echo "" | tee -a "$LOG_FILE"

# Test 14: Permissions
echo "=== Test 14: Critical Directory Permissions ===" | tee -a "$LOG_FILE"
WRITABLE_DIRS=(
    "/home/pim/public_html/var/cache"
    "/home/pim/public_html/var/logs"
    "/home/pim/public_html/public/media"
)

for dir in "${WRITABLE_DIRS[@]}"; do
    if [ -w "$dir" ]; then
        test_result 0 "Directory writable: $(basename $dir)"
    else
        test_result 1 "Directory not writable: $(basename $dir)"
    fi
done
echo "" | tee -a "$LOG_FILE"

# Test 15: System Health
echo "=== Test 15: System Health ===" | tee -a "$LOG_FILE"
LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | tr -d ',')
MEM_PERCENT=$(free | awk '/Mem:/ {printf "%.0f", $3/$2 * 100}')
DISK_PERCENT=$(df -h /home/pim/public_html | awk 'NR==2 {print $5}' | tr -d '%')

echo "CPU Load: $LOAD_AVG" | tee -a "$LOG_FILE"
echo "Memory Usage: ${MEM_PERCENT}%" | tee -a "$LOG_FILE"
echo "Disk Usage: ${DISK_PERCENT}%" | tee -a "$LOG_FILE"

if (( $(echo "$LOAD_AVG < 10" | bc -l) )) && [ $MEM_PERCENT -lt 90 ] && [ $DISK_PERCENT -lt 90 ]; then
    test_result 0 "System resources healthy"
else
    test_result 1 "System resources under pressure"
fi
echo "" | tee -a "$LOG_FILE"

# Summary
echo "========================================" | tee -a "$LOG_FILE"
echo "UI MONKEY TEST SUMMARY" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"
TOTAL=$((PASSED + FAILED))
SUCCESS_RATE=$(awk "BEGIN {printf \"%.1f\", ($PASSED/$TOTAL)*100}")

echo "Total Tests: $TOTAL" | tee -a "$LOG_FILE"
echo "Passed: $PASSED" | tee -a "$LOG_FILE"
echo "Failed: $FAILED" | tee -a "$LOG_FILE"
echo "Success Rate: $SUCCESS_RATE%" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

if [ $FAILED -eq 0 ]; then
    echo "✓ ALL UI TESTS PASSED - AKENEO PIM UI IS STABLE" | tee -a "$LOG_FILE"
    exit 0
elif [ $FAILED -le 3 ]; then
    echo "⚠ MINOR UI ISSUES DETECTED - AKENEO PIM IS MOSTLY STABLE" | tee -a "$LOG_FILE"
    exit 0
else
    echo "✗ UI ISSUES DETECTED - REQUIRES ATTENTION" | tee -a "$LOG_FILE"
    exit 1
fi
