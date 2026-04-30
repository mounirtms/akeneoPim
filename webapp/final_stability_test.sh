#!/bin/bash
# Final Comprehensive Stability Test for Akeneo PIM
# Tests: Console, Database, Services, UI, Enrich Menu, Logs

echo "=========================================="
echo "AKENEO PIM COMPREHENSIVE STABILITY TEST"
echo "Started: $(date)"
echo "=========================================="

PASSED=0
FAILED=0
TOTAL=0
ISSUES=()

test_result() {
    local name="$1"
    local result="$2"
    local details="${3:-}"
    TOTAL=$((TOTAL + 1))
    
    if [ "$result" = "PASS" ]; then
        echo "✓ Test $TOTAL: $name - PASSED"
        PASSED=$((PASSED + 1))
    else
        echo "✗ Test $TOTAL: $name - FAILED"
        FAILED=$((FAILED + 1))
        ISSUES+=("$name: $details")
    fi
}

cd /home/pim/public_html

# CORE SYSTEM TESTS
echo -e "\n=== CORE SYSTEM ==="

# Test 1: Console
if php bin/console --version --env=prod 2>&1 | grep -q "Symfony"; then
    test_result "Symfony Console" "PASS"
else
    test_result "Symfony Console" "FAIL" "Console not responding"
fi

# Test 2: Database
if php bin/console doctrine:query:sql "SELECT COUNT(*) FROM pim_catalog_product" --env=prod 2>/dev/null | grep -qE '[0-9]+'; then
    PRODUCT_COUNT=$(php bin/console doctrine:query:sql "SELECT COUNT(*) FROM pim_catalog_product" --env=prod 2>/dev/null | grep -oE '[0-9]{3,}' | head -1)
    test_result "Database Connection ($PRODUCT_COUNT products)" "PASS"
else
    test_result "Database Connection" "FAIL" "Cannot query database"
fi

# Test 3: Cache Directory
if [ -w var/cache ] && [ "$(ls var/cache/prod 2>/dev/null | wc -l)" -gt 5 ]; then
    test_result "Cache System" "PASS"
else
    test_result "Cache System" "FAIL" "Cache directory issues"
fi

# SERVICES TESTS
echo -e "\n=== SERVICES ==="

# Test 4: Elasticsearch
ES_STATUS=$(curl -s http://localhost:9200/_cluster/health 2>/dev/null | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
if [ "$ES_STATUS" = "yellow" ] || [ "$ES_STATUS" = "green" ]; then
    ES_DOCS=$(curl -s "http://localhost:9200/_cat/indices" 2>/dev/null | grep akeneo | awk '{print $7}' | head -1)
    test_result "Elasticsearch ($ES_STATUS, $ES_DOCS docs)" "PASS"
else
    test_result "Elasticsearch" "FAIL" "Status: $ES_STATUS"
fi

# Test 5: Redis
if redis-cli ping 2>/dev/null | grep -q "PONG"; then
    test_result "Redis Service" "PASS"
else
    test_result "Redis Service" "FAIL" "Redis not responding"
fi

# Test 6: Varnish
if varnishstat -1 2>/dev/null | grep -q "uptime"; then
    test_result "Varnish Cache" "PASS"
else
    test_result "Varnish Cache" "FAIL" "Varnish not responding"
fi

# WEB & UI TESTS
echo -e "\n=== WEB & UI ==="

# Test 7: Homepage
HTTP_CODE=$(curl -s -o /dev/null -w '%{http_code}' https://pim.technostationery.com/)
if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ]; then
    test_result "Homepage Access (HTTP $HTTP_CODE)" "PASS"
else
    test_result "Homepage Access" "FAIL" "HTTP $HTTP_CODE"
fi

# Test 8: Login Page
if curl -s https://pim.technostationery.com/user/login 2>/dev/null | grep -q "login"; then
    test_result "Login Page" "PASS"
else
    test_result "Login Page" "FAIL" "Login page not rendering"
fi

# Test 9: CSS Files
if [ -f public/css/pim.css ]; then
    CSS_SIZE=$(ls -lh public/css/pim.css | awk '{print $5}')
    test_result "CSS Files ($CSS_SIZE)" "PASS"
else
    test_result "CSS Files" "FAIL" "No CSS files found"
fi

# Test 10: JavaScript Bundles
if [ -f public/dist/vendor.min.js ] && [ -f public/dist/main.min.js ]; then
    VENDOR_SIZE=$(ls -lh public/dist/vendor.min.js | awk '{print $5}')
    test_result "JS Bundles ($VENDOR_SIZE vendor.min.js)" "PASS"
else
    test_result "JS Bundles" "FAIL" "Missing JavaScript files"
fi

# Test 11: Symfony Assets
BUNDLE_COUNT=$(ls public/bundles/ 2>/dev/null | wc -l)
if [ "$BUNDLE_COUNT" -gt 10 ]; then
    test_result "Symfony Assets ($BUNDLE_COUNT bundles)" "PASS"
else
    test_result "Symfony Assets" "FAIL" "Only $BUNDLE_COUNT bundles found"
fi

# ENRICH & FEATURES
echo -e "\n=== ENRICH & FEATURES ==="

# Test 12: Enrich Routes
ENRICH_ROUTES=$(php bin/console debug:router --env=prod 2>/dev/null | grep -c "pim_enrich")
if [ "$ENRICH_ROUTES" -gt 50 ]; then
    test_result "Enrich Routes ($ENRICH_ROUTES available)" "PASS"
else
    test_result "Enrich Routes" "FAIL" "Only $ENRICH_ROUTES routes found"
fi

# Test 13: PIM Commands
PIM_COMMANDS=$(php bin/console list pim --env=prod 2>/dev/null | grep -c "pim:")
if [ "$PIM_COMMANDS" -gt 20 ]; then
    test_result "PIM Commands ($PIM_COMMANDS available)" "PASS"
else
    test_result "PIM Commands" "FAIL" "Only $PIM_COMMANDS commands"
fi

# Test 14: Product Images
IMAGE_COUNT=$(find public/media -name "*.jpg" -o -name "*.png" 2>/dev/null | wc -l)
if [ "$IMAGE_COUNT" -gt 1000 ]; then
    test_result "Product Images ($IMAGE_COUNT files)" "PASS"
else
    test_result "Product Images" "FAIL" "Only $IMAGE_COUNT images"
fi

# Test 15: JS Routes
if [ -f public/js/fos_js_routes.json ]; then
    ROUTE_SIZE=$(ls -lh public/js/fos_js_routes.json | awk '{print $5}')
    test_result "JavaScript Routing ($ROUTE_SIZE)" "PASS"
else
    test_result "JavaScript Routing" "FAIL" "Routes file missing"
fi

# LOGS & ERRORS
echo -e "\n=== LOGS & ERRORS ==="

# Test 16: No Critical Errors
CRITICAL_COUNT=$(tail -100 var/logs/prod.log 2>/dev/null | grep -ic "critical\|fatal")
if [ "$CRITICAL_COUNT" -eq 0 ]; then
    test_result "Recent Critical Errors (0 found)" "PASS"
else
    test_result "Recent Critical Errors" "FAIL" "$CRITICAL_COUNT critical errors"
fi

# Test 17: Log Files Writable
if [ -w var/logs ]; then
    test_result "Log Directory Writable" "PASS"
else
    test_result "Log Directory" "FAIL" "Cannot write logs"
fi

# SYSTEM RESOURCES
echo -e "\n=== SYSTEM RESOURCES ==="

# Test 18: Memory
TOTAL_MEM=$(free -g | awk '/^Mem:/ {print $2}')
USED_MEM=$(free -g | awk '/^Mem:/ {print $3}')
if [ "$TOTAL_MEM" -gt 8 ]; then
    test_result "Memory ($USED_MEM GB / $TOTAL_MEM GB used)" "PASS"
else
    test_result "Memory" "FAIL" "Insufficient memory"
fi

# Test 19: Disk Space
DISK_USAGE=$(df -h /home/pim | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -lt 80 ]; then
    test_result "Disk Space (${DISK_USAGE}% used)" "PASS"
else
    test_result "Disk Space" "FAIL" "${DISK_USAGE}% disk usage"
fi

# Test 20: CPU Load
LOAD=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
LOAD_INT=$(echo "$LOAD" | cut -d'.' -f1)
if [ "$LOAD_INT" -lt 10 ]; then
    test_result "CPU Load ($LOAD)" "PASS"
else
    test_result "CPU Load" "FAIL" "High load: $LOAD"
fi

# SUMMARY
echo -e "\n=========================================="
echo "TEST SUMMARY"
echo "=========================================="
echo "Total Tests: $TOTAL"
echo "Passed: $PASSED"
echo "Failed: $FAILED"
SUCCESS_RATE=$(awk "BEGIN {printf \"%.1f\", ($PASSED/$TOTAL)*100}")
echo "Success Rate: ${SUCCESS_RATE}%"
echo ""

if [ $FAILED -eq 0 ]; then
    echo "✓✓✓ ALL TESTS PASSED - SYSTEM FULLY STABLE ✓✓✓"
    STATUS="STABLE"
    EXIT_CODE=0
elif [ $FAILED -le 2 ]; then
    echo "⚠ MINOR ISSUES - System mostly stable"
    STATUS="MOSTLY_STABLE"
    EXIT_CODE=1
elif [ $FAILED -le 5 ]; then
    echo "⚠ MODERATE ISSUES - Requires attention"
    STATUS="NEEDS_ATTENTION"
    EXIT_CODE=2
else
    echo "✗ CRITICAL ISSUES - Immediate action required"
    STATUS="UNSTABLE"
    EXIT_CODE=3
fi

if [ ${#ISSUES[@]} -gt 0 ]; then
    echo -e "\nISSUES DETECTED:"
    for issue in "${ISSUES[@]}"; do
        echo "  - $issue"
    done
fi

echo -e "\nOverall Status: $STATUS"
echo "Completed: $(date)"
echo "=========================================="

exit $EXIT_CODE
