#!/bin/bash
################################################################################
# TEST RECOVERY - COMPREHENSIVE TESTING SUITE
# Date: May 6, 2026
# Purpose: Test Akeneo PIM after recovery to verify all systems working
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_DIR="/home/pim/public_html"
BASE_URL="https://pim.technostationery.com"
TEST_LOG="$PROJECT_DIR/test_recovery_$(date +%Y%m%d_%H%M%S).log"

TESTS_PASSED=0
TESTS_FAILED=0
TESTS_WARNING=0

################################################################################
# Test functions
################################################################################

test_result() {
    local test_name="$1"
    local result="$2"
    local message="$3"
    
    if [ "$result" = "PASS" ]; then
        echo -e "${GREEN}✓${NC} $test_name: ${GREEN}PASS${NC} - $message" | tee -a "$TEST_LOG"
        ((TESTS_PASSED++))
    elif [ "$result" = "FAIL" ]; then
        echo -e "${RED}✗${NC} $test_name: ${RED}FAIL${NC} - $message" | tee -a "$TEST_LOG"
        ((TESTS_FAILED++))
    else
        echo -e "${YELLOW}⚠${NC} $test_name: ${YELLOW}WARN${NC} - $message" | tee -a "$TEST_LOG"
        ((TESTS_WARNING++))
    fi
}

################################################################################
# Test Suite
################################################################################

echo ""
echo "################################################################################"
echo "#                  AKENEO PIM RECOVERY TESTING SUITE                           #"
echo "################################################################################"
echo ""
echo "Test log: $TEST_LOG"
echo ""

# Test 1: HTTP Status Tests
echo -e "${BLUE}━━━ Test Group 1: HTTP Status Tests ━━━${NC}"
echo ""

# Test 1.1: Login page
HTTP_LOGIN=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/user/login" 2>&1)
if [ "$HTTP_LOGIN" = "200" ]; then
    test_result "1.1 Login Page" "PASS" "HTTP $HTTP_LOGIN"
else
    test_result "1.1 Login Page" "FAIL" "HTTP $HTTP_LOGIN (expected 200)"
fi

# Test 1.2: CSS file
HTTP_CSS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/css/pim.css" 2>&1)
if [ "$HTTP_CSS" = "200" ]; then
    test_result "1.2 CSS File" "PASS" "HTTP $HTTP_CSS"
else
    test_result "1.2 CSS File" "FAIL" "HTTP $HTTP_CSS (expected 200)"
fi

# Test 1.3: Main JS bundle
HTTP_JS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/dist/main.min.js" 2>&1)
if [ "$HTTP_JS" = "200" ]; then
    test_result "1.3 Main JS Bundle" "PASS" "HTTP $HTTP_JS"
else
    test_result "1.3 Main JS Bundle" "FAIL" "HTTP $HTTP_JS (expected 200)"
fi

# Test 1.4: Vendor JS bundle
HTTP_VENDOR=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/dist/vendor.min.js" 2>&1)
if [ "$HTTP_VENDOR" = "200" ]; then
    test_result "1.4 Vendor JS Bundle" "PASS" "HTTP $HTTP_VENDOR"
else
    test_result "1.4 Vendor JS Bundle" "WARN" "HTTP $HTTP_VENDOR (may not be critical)"
fi

echo ""

# Test 2: Database Tests
echo -e "${BLUE}━━━ Test Group 2: Database Tests ━━━${NC}"
echo ""

cd "$PROJECT_DIR"

# Test 2.1: Database connection
if mysql -u akeneo_pim -p'akeneo_pim' -h 127.0.0.1 -P 3307 --ssl=0 -e "SELECT 1" akeneo_pim &>/dev/null; then
    test_result "2.1 Database Connection" "PASS" "Connected successfully"
else
    test_result "2.1 Database Connection" "FAIL" "Cannot connect to database"
fi

# Test 2.2: User count
USER_COUNT=$(php bin/console doctrine:query:sql "SELECT COUNT(*) as cnt FROM oro_user" 2>/dev/null | grep -o '[0-9]*' | head -1)
if [ ! -z "$USER_COUNT" ] && [ "$USER_COUNT" -gt 0 ]; then
    test_result "2.2 User Count" "PASS" "$USER_COUNT users found"
else
    test_result "2.2 User Count" "FAIL" "No users found or query failed"
fi

# Test 2.3: Product count
PRODUCT_COUNT=$(php bin/console doctrine:query:sql "SELECT COUNT(*) as cnt FROM pim_catalog_product" 2>/dev/null | grep -o '[0-9]*' | head -1)
if [ ! -z "$PRODUCT_COUNT" ] && [ "$PRODUCT_COUNT" -gt 0 ]; then
    test_result "2.3 Product Count" "PASS" "$PRODUCT_COUNT products in database"
else
    test_result "2.3 Product Count" "WARN" "No products or query failed"
fi

# Test 2.4: Category count
CATEGORY_COUNT=$(php bin/console doctrine:query:sql "SELECT COUNT(*) as cnt FROM pim_catalog_category" 2>/dev/null | grep -o '[0-9]*' | head -1)
if [ ! -z "$CATEGORY_COUNT" ] && [ "$CATEGORY_COUNT" -gt 0 ]; then
    test_result "2.4 Category Count" "PASS" "$CATEGORY_COUNT categories in database"
else
    test_result "2.4 Category Count" "WARN" "No categories or query failed"
fi

echo ""

# Test 3: Elasticsearch Tests
echo -e "${BLUE}━━━ Test Group 3: Elasticsearch Tests ━━━${NC}"
echo ""

# Test 3.1: Elasticsearch connection
if curl -s "http://localhost:9200" &>/dev/null; then
    test_result "3.1 Elasticsearch Connection" "PASS" "Connected to localhost:9200"
else
    test_result "3.1 Elasticsearch Connection" "FAIL" "Cannot connect to Elasticsearch"
fi

# Test 3.2: Product index exists
if curl -s "http://localhost:9200/akeneo_pim_product_and_product_model" | grep -q "akeneo_pim_product"; then
    test_result "3.2 Product Index Exists" "PASS" "Index exists"
else
    test_result "3.2 Product Index Exists" "FAIL" "Index not found"
fi

# Test 3.3: Product count in index
ES_PRODUCT_COUNT=$(curl -s "http://localhost:9200/akeneo_pim_product_and_product_model/_count" 2>/dev/null | grep -o '"count":[0-9]*' | cut -d: -f2)
if [ ! -z "$ES_PRODUCT_COUNT" ] && [ "$ES_PRODUCT_COUNT" -gt 0 ]; then
    test_result "3.3 Indexed Products" "PASS" "$ES_PRODUCT_COUNT products indexed"
else
    test_result "3.3 Indexed Products" "WARN" "No products indexed (reindex may be needed)"
fi

echo ""

# Test 4: File System Tests
echo -e "${BLUE}━━━ Test Group 4: File System Tests ━━━${NC}"
echo ""

# Test 4.1: Critical files exist
CRITICAL_FILES=(
    "public/css/pim.css"
    "public/dist/main.min.js"
    "public/bundles/pimui/manifest.json"
    "config/packages/security.yml"
    ".env"
)

for file in "${CRITICAL_FILES[@]}"; do
    if [ -f "$file" ]; then
        FILE_SIZE=$(ls -lh "$file" | awk '{print $5}')
        test_result "4.x Critical File: $(basename $file)" "PASS" "Exists ($FILE_SIZE)"
    else
        test_result "4.x Critical File: $(basename $file)" "FAIL" "Missing"
    fi
done

echo ""

# Test 5: Permissions Tests
echo -e "${BLUE}━━━ Test Group 5: Permissions Tests ━━━${NC}"
echo ""

# Test 5.1: Cache directory writable
if [ -w "var/cache" ]; then
    test_result "5.1 Cache Directory" "PASS" "Writable"
else
    test_result "5.1 Cache Directory" "FAIL" "Not writable"
fi

# Test 5.2: Logs directory writable
if [ -w "var/logs" ]; then
    test_result "5.2 Logs Directory" "PASS" "Writable"
else
    test_result "5.2 Logs Directory" "FAIL" "Not writable"
fi

# Test 5.3: Sessions directory writable
if [ -w "var/sessions" ]; then
    test_result "5.3 Sessions Directory" "PASS" "Writable"
else
    test_result "5.3 Sessions Directory" "FAIL" "Not writable"
fi

echo ""

# Test 6: Configuration Tests
echo -e "${BLUE}━━━ Test Group 6: Configuration Tests ━━━${NC}"
echo ""

# Test 6.1: .env database config
if grep -q "APP_DATABASE_HOST=127.0.0.1" .env && grep -q "APP_DATABASE_PORT=3307" .env; then
    test_result "6.1 Database Config" "PASS" "Correct host and port"
else
    test_result "6.1 Database Config" "FAIL" "Incorrect configuration"
fi

# Test 6.2: .env Elasticsearch config
if grep -q "APP_INDEX_HOSTS=localhost:9200" .env; then
    test_result "6.2 Elasticsearch Config" "PASS" "Correct host"
else
    test_result "6.2 Elasticsearch Config" "FAIL" "Incorrect configuration"
fi

# Test 6.3: .env.local.php exists
if [ -f ".env.local.php" ]; then
    test_result "6.3 .env.local.php" "PASS" "Override file exists"
else
    test_result "6.3 .env.local.php" "WARN" "Override file missing"
fi

echo ""

# Test 7: Symfony Console Tests
echo -e "${BLUE}━━━ Test Group 7: Symfony Console Tests ━━━${NC}"
echo ""

# Test 7.1: Console works
if php bin/console --version &>/dev/null; then
    SYMFONY_VERSION=$(php bin/console --version | head -1)
    test_result "7.1 Symfony Console" "PASS" "$SYMFONY_VERSION"
else
    test_result "7.1 Symfony Console" "FAIL" "Console not working"
fi

# Test 7.2: Cache is warm
if [ -d "var/cache/prod" ] && [ "$(ls -A var/cache/prod)" ]; then
    test_result "7.2 Cache Status" "PASS" "Cache directory populated"
else
    test_result "7.2 Cache Status" "WARN" "Cache may need warming"
fi

echo ""

################################################################################
# Summary
################################################################################

echo ""
echo "################################################################################"
echo "#                            TEST RESULTS SUMMARY                              #"
echo "################################################################################"
echo ""
echo -e "${GREEN}✓ Passed:${NC}  $TESTS_PASSED"
echo -e "${YELLOW}⚠ Warnings:${NC} $TESTS_WARNING"
echo -e "${RED}✗ Failed:${NC}  $TESTS_FAILED"
echo ""

TOTAL_TESTS=$((TESTS_PASSED + TESTS_FAILED + TESTS_WARNING))
SUCCESS_RATE=$((TESTS_PASSED * 100 / TOTAL_TESTS))

echo "Total tests: $TOTAL_TESTS"
echo "Success rate: ${SUCCESS_RATE}%"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}🎉 All critical tests passed!${NC}"
    echo ""
    echo "✅ Next steps:"
    echo "   1. Test login manually: $BASE_URL/user/login"
    echo "   2. Verify you can see products in catalog"
    echo "   3. Check images are loading"
    echo "   4. Try creating/editing a product"
    echo "   5. Test API endpoints if needed"
    EXIT_CODE=0
elif [ $TESTS_FAILED -le 2 ]; then
    echo -e "${YELLOW}⚠️  Minor issues detected${NC}"
    echo ""
    echo "Review failed tests above and fix before production use."
    EXIT_CODE=1
else
    echo -e "${RED}❌ Critical issues detected${NC}"
    echo ""
    echo "Multiple tests failed. System may not be functional."
    echo "Review test log: $TEST_LOG"
    EXIT_CODE=2
fi

echo ""
echo "Full test log: $TEST_LOG"
echo ""

exit $EXIT_CODE
