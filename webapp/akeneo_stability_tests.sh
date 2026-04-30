#!/bin/bash
# Comprehensive Akeneo PIM Stability Testing
# Post-malware cleanup validation
# Date: 2026-04-30

LOG_FILE="logs/stability_tests_$(date +%Y%m%d_%H%M%S).log"
REPORT_FILE="STABILITY_TEST_REPORT_$(date +%Y%m%d).md"

exec > >(tee -a "$LOG_FILE") 2>&1

echo "========================================"
echo "AKENEO PIM STABILITY TESTING"
echo "Date: $(date)"
echo "========================================"
echo ""

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

echo "## Phase 1: System Resources Check"
echo "-----------------------------------"

# Test 1: CPU Load
LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | tr -d ',')
echo "Current load average: $LOAD_AVG"
if (( $(echo "$LOAD_AVG < 10.0" | bc -l) )); then
    test_result 0 "CPU Load Acceptable (<10.0)"
else
    test_result 1 "CPU Load High (>10.0)"
fi

# Test 2: Memory Usage
MEM_USED=$(free -g | awk '/Mem:/ {print $3}')
MEM_TOTAL=$(free -g | awk '/Mem:/ {print $2}')
echo "Memory: ${MEM_USED}GB / ${MEM_TOTAL}GB"
if [ "$MEM_USED" -lt 25 ]; then
    test_result 0 "Memory Usage Acceptable (<25GB)"
else
    test_result 1 "Memory Usage High (>25GB)"
fi

# Test 3: Disk Space
DISK_USAGE=$(df -h /home/pim/public_html | awk 'NR==2 {print $5}' | tr -d '%')
echo "Disk usage: ${DISK_USAGE}%"
if [ "$DISK_USAGE" -lt 80 ]; then
    test_result 0 "Disk Space Sufficient (<80%)"
else
    test_result 1 "Disk Space Critical (>80%)"
fi

echo ""
echo "## Phase 2: Service Health Check"
echo "---------------------------------"

# Test 4: Elasticsearch Health
ES_STATUS=$(curl -s http://localhost:9200/_cluster/health | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
echo "Elasticsearch status: $ES_STATUS"
if [ "$ES_STATUS" = "yellow" ] || [ "$ES_STATUS" = "green" ]; then
    test_result 0 "Elasticsearch Running"
else
    test_result 1 "Elasticsearch Down"
fi

# Test 5: Elasticsearch Product Count
ES_COUNT=$(curl -s "http://localhost:9200/akeneo_pim_product_and_product_model*/_count" | grep -o '"count":[0-9]*' | cut -d':' -f2)
echo "Products in Elasticsearch: $ES_COUNT"
if [ "$ES_COUNT" -gt 9000 ]; then
    test_result 0 "Elasticsearch Products Indexed ($ES_COUNT)"
else
    test_result 1 "Elasticsearch Index Incomplete ($ES_COUNT)"
fi

# Test 6: MySQL Connection
cd /home/pim/public_html
MYSQL_RESULT=$(php -r '
$dsn = "mysql:host=127.0.0.1;port=3307;dbname=akeneo_pim";
try {
    $pdo = new PDO($dsn, "akeneo_pim", "LZVvxnY9vskG");
    $stmt = $pdo->query("SELECT COUNT(*) FROM pim_catalog_product WHERE is_enabled = 1");
    echo $stmt->fetchColumn();
} catch (Exception $e) {
    echo "0";
}
' 2>/dev/null)
echo "Products in MySQL: $MYSQL_RESULT"
if [ "$MYSQL_RESULT" -gt 9000 ]; then
    test_result 0 "MySQL Database Accessible ($MYSQL_RESULT products)"
else
    test_result 1 "MySQL Database Issue"
fi

# Test 7: Redis Connection
REDIS_PING=$(redis-cli -h 127.0.0.1 -p 6379 ping 2>&1)
echo "Redis response: $REDIS_PING"
if [ "$REDIS_PING" = "PONG" ]; then
    test_result 0 "Redis Cache Running"
else
    test_result 1 "Redis Cache Down"
fi

echo ""
echo "## Phase 3: Akeneo Console Commands"
echo "------------------------------------"

# Test 8: Console Access
cd /home/pim/public_html
CONSOLE_TEST=$(php bin/console list --env=prod 2>&1 | grep -c "Available commands")
if [ "$CONSOLE_TEST" -gt 0 ]; then
    test_result 0 "Akeneo Console Accessible"
else
    test_result 1 "Akeneo Console Error"
fi

# Test 9: Cache Status
CACHE_POOLS=$(php bin/console cache:pool:list --env=prod 2>&1 | grep -c "cache")
if [ "$CACHE_POOLS" -gt 5 ]; then
    test_result 0 "Cache Pools Configured ($CACHE_POOLS pools)"
else
    test_result 1 "Cache Configuration Issue"
fi

echo ""
echo "## Phase 4: Data Integrity Tests"
echo "---------------------------------"

# Test 10: Product Models Count
MODELS_COUNT=$(php -r '
$dsn = "mysql:host=127.0.0.1;port=3307;dbname=akeneo_pim";
try {
    $pdo = new PDO($dsn, "akeneo_pim", "LZVvxnY9vskG");
    $stmt = $pdo->query("SELECT COUNT(*) FROM pim_catalog_product_model");
    echo $stmt->fetchColumn();
} catch (Exception $e) {
    echo "0";
}
' 2>/dev/null)
echo "Product models: $MODELS_COUNT"
if [ "$MODELS_COUNT" -gt 400 ]; then
    test_result 0 "Product Models Present ($MODELS_COUNT)"
else
    test_result 1 "Product Models Missing"
fi

# Test 11: Categories Count
CATEGORIES_COUNT=$(php -r '
$dsn = "mysql:host=127.0.0.1;port=3307;dbname=akeneo_pim";
try {
    $pdo = new PDO($dsn, "akeneo_pim", "LZVvxnY9vskG");
    $stmt = $pdo->query("SELECT COUNT(*) FROM pim_catalog_category");
    echo $stmt->fetchColumn();
} catch (Exception $e) {
    echo "0";
}
' 2>/dev/null)
echo "Categories: $CATEGORIES_COUNT"
if [ "$CATEGORIES_COUNT" -gt 150 ]; then
    test_result 0 "Categories Present ($CATEGORIES_COUNT)"
else
    test_result 1 "Categories Missing"
fi

# Test 12: Images on Disk
IMAGE_COUNT=$(find /home/pim/public_html/public/media/product_images -type f 2>/dev/null | wc -l)
echo "Product images on disk: $IMAGE_COUNT"
if [ "$IMAGE_COUNT" -gt 25000 ]; then
    test_result 0 "Product Images Present ($IMAGE_COUNT files)"
else
    test_result 1 "Product Images Incomplete"
fi

echo ""
echo "## Phase 5: Frontend Asset Tests"
echo "---------------------------------"

# Test 13: CSS Assets
CSS_COUNT=$(find /home/pim/public_html/public/css -name "*.css" 2>/dev/null | wc -l)
echo "CSS files: $CSS_COUNT"
if [ "$CSS_COUNT" -gt 10 ]; then
    test_result 0 "CSS Assets Present ($CSS_COUNT files)"
else
    test_result 1 "CSS Assets Missing"
fi

# Test 14: JavaScript Bundles
JS_COUNT=$(find /home/pim/public_html/public/bundles -name "*.js" 2>/dev/null | wc -l)
echo "JavaScript bundles: $JS_COUNT"
if [ "$JS_COUNT" -gt 50 ]; then
    test_result 0 "JavaScript Bundles Present ($JS_COUNT files)"
else
    test_result 1 "JavaScript Bundles Incomplete"
fi

# Test 15: require.min.js Critical File
if [ -f "/home/pim/public_html/public/bundles/pimui/js/require.min.js" ]; then
    test_result 0 "require.min.js Found"
else
    test_result 1 "require.min.js MISSING (critical)"
fi

echo ""
echo "## Phase 6: Security Validation"
echo "--------------------------------"

# Test 16: No malware processes
NUCLEAR_COUNT=$(ps aux | grep -c "nuclear.x86")
if [ "$NUCLEAR_COUNT" -le 1 ]; then
    test_result 0 "No Malware Processes Detected"
else
    test_result 1 "Malware Processes Still Running ($NUCLEAR_COUNT)"
fi

# Test 17: Mining ports blocked
MINING_CONNECTIONS=$(netstat -tupn 2>/dev/null | grep -cE ":5221|:3333|:4444")
if [ "$MINING_CONNECTIONS" -eq 0 ]; then
    test_result 0 "Mining Ports Blocked"
else
    test_result 1 "Mining Connections Active ($MINING_CONNECTIONS)"
fi

# Test 18: Malicious packages removed
MALICIOUS_NPM=$(npm list -g --depth=0 2>/dev/null | grep -cE "gemini-cli|pi-coding|qwen-code")
if [ "$MALICIOUS_NPM" -eq 0 ]; then
    test_result 0 "Malicious NPM Packages Removed"
else
    test_result 1 "Malicious NPM Packages Still Installed"
fi

echo ""
echo "========================================"
echo "TEST SUMMARY"
echo "========================================"
echo "Total Tests: $TESTS_TOTAL"
echo "Passed: $TESTS_PASSED"
echo "Failed: $TESTS_FAILED"
echo ""

if [ "$TESTS_FAILED" -eq 0 ]; then
    echo "🎉 ALL TESTS PASSED - SYSTEM STABLE"
    EXIT_CODE=0
elif [ "$TESTS_FAILED" -le 2 ]; then
    echo "⚠️  MINOR ISSUES - SYSTEM MOSTLY STABLE"
    EXIT_CODE=1
else
    echo "❌ CRITICAL ISSUES - REQUIRES ATTENTION"
    EXIT_CODE=2
fi

echo ""
echo "Full log: $LOG_FILE"
echo "========================================"

exit $EXIT_CODE
