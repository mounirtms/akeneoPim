#!/bin/bash
# Comprehensive Akeneo PIM UI and Enrich Menu Tests
# Tests login, UI rendering, enrich menu, styles, and logs

LOG_DIR="logs"
mkdir -p "$LOG_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$LOG_DIR/pim_ui_tests_${TIMESTAMP}.log"

echo "========================================" | tee -a "$LOG_FILE"
echo "Akeneo PIM UI & Enrich Menu Tests" | tee -a "$LOG_FILE"
echo "Started: $(date)" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"

PASSED=0
FAILED=0
TOTAL=0

# Helper function
run_test() {
    local test_name="$1"
    local test_command="$2"
    TOTAL=$((TOTAL + 1))
    echo "" | tee -a "$LOG_FILE"
    echo "Test $TOTAL: $test_name" | tee -a "$LOG_FILE"
    if eval "$test_command" >> "$LOG_FILE" 2>&1; then
        echo "✓ PASSED" | tee -a "$LOG_FILE"
        PASSED=$((PASSED + 1))
    else
        echo "✗ FAILED" | tee -a "$LOG_FILE"
        FAILED=$((FAILED + 1))
    fi
}

cd /home/pim/public_html

# Test 1: Homepage Access
run_test "Homepage HTTP Status" \
    "curl -s -o /dev/null -w '%{http_code}' https://pim.technostationery.com/ | grep -E '(200|302)'"

# Test 2: Login Page Access
run_test "Login Page Accessible" \
    "curl -s https://pim.technostationery.com/user/login | grep -q 'login'"

# Test 3: Login Form HTML Present
run_test "Login Form HTML Structure" \
    "curl -s https://pim.technostationery.com/user/login | grep -q '<form'"

# Test 4: CSS Files Exist
run_test "CSS Files in public/css" \
    "ls -1 public/css/*.css 2>/dev/null | wc -l | grep -v '^0$'"

# Test 5: Webpack Dist Assets
run_test "Webpack Dist Directory" \
    "[ -d public/dist ] && [ \$(ls public/dist/*.js 2>/dev/null | wc -l) -gt 0 ]"

# Test 6: Main JavaScript Bundle
run_test "Main JS Bundle (vendor.min.js)" \
    "[ -f public/dist/vendor.min.js ]"

# Test 7: Console Works
run_test "Symfony Console Accessible" \
    "php bin/console --version --env=prod | grep -q 'Symfony'"

# Test 8: Enrich Bundle Commands
run_test "Enrich Commands Available" \
    "php bin/console list pim --env=prod | grep -q 'pim:'"

# Test 9: Product Model Commands
run_test "Product Model Commands" \
    "php bin/console list pim --env=prod | grep -q 'pim:product'"

# Test 10: Cache Directory Writable
run_test "Cache Directory Writable" \
    "[ -w var/cache ]"

# Test 11: Logs Directory Writable
run_test "Logs Directory Writable" \
    "[ -w var/logs ]"

# Test 12: Public Media Directory
run_test "Public Media Directory" \
    "[ -d public/media ] && [ \$(ls public/media 2>/dev/null | wc -l) -gt 0 ]"

# Test 13: Product Images Exist
run_test "Product Images Present" \
    "[ \$(find public/media -name '*.jpg' -o -name '*.png' 2>/dev/null | wc -l) -gt 100 ]"

# Test 14: Elasticsearch Connection
run_test "Elasticsearch Reachable" \
    "curl -s http://localhost:9200/_cluster/health | grep -q 'status'"

# Test 15: Elasticsearch Product Index
run_test "Elasticsearch Product Index" \
    "curl -s http://localhost:9200/_cat/indices | grep -q 'akeneo_pim_product'"

# Test 16: Redis Service
run_test "Redis Service Running" \
    "redis-cli ping 2>/dev/null | grep -q 'PONG'"

# Test 17: Varnish Service
run_test "Varnish Service Running" \
    "varnishstat -1 2>/dev/null | grep -q 'uptime'"

# Test 18: Database Connection
run_test "Database Connection" \
    "php bin/console doctrine:query:sql 'SELECT COUNT(*) FROM pim_catalog_product' --env=prod | grep -qE '[0-9]+'"

# Test 19: Recent Error Logs Check
run_test "No Critical Errors in Last 100 Lines" \
    "! tail -100 var/logs/prod.log | grep -qi 'critical\|fatal'"

# Test 20: Routes Configuration
run_test "Routes Loaded Successfully" \
    "php bin/console debug:router --env=prod | wc -l | awk '{if(\$1>100) exit 0; else exit 1}'"

# Test 21: Asset Installation
run_test "Symfony Assets Installed" \
    "[ -d public/bundles ] && [ \$(ls public/bundles 2>/dev/null | wc -l) -gt 5 ]"

# Test 22: Enrich Bundle Assets
run_test "Enrich Bundle Assets Present" \
    "[ -d public/bundles/pimui ] || [ -d public/bundles/pim ] || [ -d public/bundles/enrich ]"

# Test 23: JavaScript Routes File
run_test "JS Routes Configuration" \
    "[ -f public/js/fos_js_routes.json ] || [ -f public/bundles/pimui/js/router.js ]"

# Test 24: System Resources Check
run_test "Adequate System Resources" \
    "free -g | awk '/^Mem:/ {if(\$2>8) exit 0; else exit 1}'"

# Summary
echo "" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"
echo "TEST SUMMARY" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"
echo "Total Tests: $TOTAL" | tee -a "$LOG_FILE"
echo "Passed: $PASSED ($(awk "BEGIN {printf \"%.1f\", ($PASSED/$TOTAL)*100}")%)" | tee -a "$LOG_FILE"
echo "Failed: $FAILED ($(awk "BEGIN {printf \"%.1f\", ($FAILED/$TOTAL)*100}")%)" | tee -a "$LOG_FILE"
echo "Success Rate: $(awk "BEGIN {printf \"%.1f\", ($PASSED/$TOTAL)*100}")%" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

if [ $FAILED -eq 0 ]; then
    echo "✓ ALL TESTS PASSED - System is STABLE" | tee -a "$LOG_FILE"
    exit 0
elif [ $FAILED -le 3 ]; then
    echo "⚠ MINOR ISSUES DETECTED - $FAILED test(s) failed" | tee -a "$LOG_FILE"
    exit 1
else
    echo "✗ CRITICAL ISSUES - $FAILED test(s) failed" | tee -a "$LOG_FILE"
    exit 2
fi
