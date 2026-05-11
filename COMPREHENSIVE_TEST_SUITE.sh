#!/bin/bash
# ========================================
# AKENEO PIM COMPREHENSIVE TEST SUITE
# Date: May 6, 2026
# Branch: recovery-testing-phase3
# ========================================

set -e
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="test_results_${TIMESTAMP}.log"
PASSED=0
FAILED=0
WARNINGS=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "========================================"
echo "AKENEO PIM COMPREHENSIVE TEST SUITE"
echo "Started: $(date)"
echo "Branch: $(git branch --show-current)"
echo "========================================"
echo ""

# Function to log results
log_test() {
    local test_name=$1
    local status=$2
    local message=$3
    
    if [ "$status" == "PASS" ]; then
        echo -e "${GREEN}✓ PASS${NC}: $test_name - $message"
        ((PASSED++))
    elif [ "$status" == "FAIL" ]; then
        echo -e "${RED}✗ FAIL${NC}: $test_name - $message"
        ((FAILED++))
    else
        echo -e "${YELLOW}⚠ WARN${NC}: $test_name - $message"
        ((WARNINGS++))
    fi
    echo "[$status] $test_name: $message" >> "$LOG_FILE"
}

echo "========================================"
echo "TEST CATEGORY 1: INFRASTRUCTURE"
echo "========================================"

# Test 1.1: PHP Version
echo "Test 1.1: PHP CLI Version Check"
PHP_VERSION=$(php --version | head -1 | awk '{print $2}')
if [[ $PHP_VERSION == 8.2.* ]]; then
    log_test "PHP_CLI_VERSION" "PASS" "PHP $PHP_VERSION detected"
else
    log_test "PHP_CLI_VERSION" "WARN" "Unexpected PHP version: $PHP_VERSION"
fi

# Test 1.2: PHP Extensions
echo "Test 1.2: Critical PHP Extensions"
REQUIRED_EXTENSIONS=("pdo" "pdo_mysql" "mysqli" "mbstring" "json" "curl" "xml" "zip" "intl" "bcmath" "gd")
MISSING_EXT=0
for ext in "${REQUIRED_EXTENSIONS[@]}"; do
    if php -m | grep -q "^${ext}$"; then
        log_test "PHP_EXT_${ext}" "PASS" "Extension $ext is loaded"
    else
        log_test "PHP_EXT_${ext}" "FAIL" "Extension $ext is MISSING"
        ((MISSING_EXT++))
    fi
done

# Test 1.3: Symfony Console
echo "Test 1.3: Symfony Console Accessibility"
if php bin/console --version &>/dev/null; then
    SYMFONY_VERSION=$(php bin/console --version | head -1)
    log_test "SYMFONY_CONSOLE" "PASS" "$SYMFONY_VERSION accessible"
else
    log_test "SYMFONY_CONSOLE" "FAIL" "Cannot access Symfony console"
fi

echo ""
echo "========================================"
echo "TEST CATEGORY 2: DATABASE CONNECTIVITY"
echo "========================================"

# Test 2.1: Database Connection
echo "Test 2.1: MariaDB Connection Test"
if mysql -h 127.0.0.1 -P 3307 -u akeneo_pim -pakeneo_pim --skip-ssl -e "SELECT 1;" akeneo_pim &>/dev/null; then
    log_test "DB_CONNECTION" "PASS" "MariaDB connection successful"
else
    log_test "DB_CONNECTION" "FAIL" "Cannot connect to MariaDB"
fi

# Test 2.2: Database Tables
echo "Test 2.2: Critical Database Tables"
TABLE_COUNT=$(mysql -h 127.0.0.1 -P 3307 -u akeneo_pim -pakeneo_pim --skip-ssl akeneo_pim -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='akeneo_pim';" 2>/dev/null | tail -1)
if [ "$TABLE_COUNT" -gt 90 ]; then
    log_test "DB_TABLES" "PASS" "$TABLE_COUNT tables found (expected ~98)"
else
    log_test "DB_TABLES" "WARN" "Only $TABLE_COUNT tables found (expected ~98)"
fi

# Test 2.3: Product Count
echo "Test 2.3: Product Data Verification"
PRODUCT_COUNT=$(mysql -h 127.0.0.1 -P 3307 -u akeneo_pim -pakeneo_pim --skip-ssl akeneo_pim -e "SELECT COUNT(*) FROM pim_catalog_product;" 2>/dev/null | tail -1)
if [ "$PRODUCT_COUNT" -gt 9000 ]; then
    log_test "DB_PRODUCTS" "PASS" "$PRODUCT_COUNT products in database"
elif [ "$PRODUCT_COUNT" -gt 0 ]; then
    log_test "DB_PRODUCTS" "WARN" "Only $PRODUCT_COUNT products (expected ~9538)"
else
    log_test "DB_PRODUCTS" "FAIL" "No products found in database"
fi

# Test 2.4: Users
echo "Test 2.4: User Accounts Verification"
USER_COUNT=$(mysql -h 127.0.0.1 -P 3307 -u akeneo_pim -pakeneo_pim --skip-ssl akeneo_pim -e "SELECT COUNT(*) FROM oro_user;" 2>/dev/null | tail -1)
if [ "$USER_COUNT" -gt 0 ]; then
    log_test "DB_USERS" "PASS" "$USER_COUNT user accounts found"
else
    log_test "DB_USERS" "FAIL" "No users found in database"
fi

# Test 2.5: Categories
echo "Test 2.5: Category Structure"
CATEGORY_COUNT=$(mysql -h 127.0.0.1 -P 3307 -u akeneo_pim -pakeneo_pim --skip-ssl akeneo_pim -e "SELECT COUNT(*) FROM pim_catalog_category;" 2>/dev/null | tail -1)
if [ "$CATEGORY_COUNT" -gt 100 ]; then
    log_test "DB_CATEGORIES" "PASS" "$CATEGORY_COUNT categories found"
else
    log_test "DB_CATEGORIES" "WARN" "$CATEGORY_COUNT categories (expected ~166)"
fi

echo ""
echo "========================================"
echo "TEST CATEGORY 3: FILE SYSTEM"
echo "========================================"

# Test 3.1: Critical Directories
echo "Test 3.1: Required Directory Structure"
REQUIRED_DIRS=("var/cache" "var/logs" "var/sessions" "public/media" "public/bundles" "vendor")
for dir in "${REQUIRED_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        log_test "DIR_${dir//\//_}" "PASS" "Directory $dir exists"
    else
        log_test "DIR_${dir//\//_}" "FAIL" "Directory $dir is MISSING"
    fi
done

# Test 3.2: Frontend Assets
echo "Test 3.2: Frontend Assets Verification"
if [ -f "public/css/pim.css" ]; then
    SIZE=$(stat -f%z "public/css/pim.css" 2>/dev/null || stat -c%s "public/css/pim.css" 2>/dev/null)
    if [ "$SIZE" -gt 400000 ]; then
        log_test "ASSET_PIM_CSS" "PASS" "pim.css present (${SIZE} bytes)"
    else
        log_test "ASSET_PIM_CSS" "WARN" "pim.css too small (${SIZE} bytes)"
    fi
else
    log_test "ASSET_PIM_CSS" "FAIL" "pim.css is MISSING"
fi

if [ -f "public/dist/main.min.js" ]; then
    SIZE=$(stat -f%z "public/dist/main.min.js" 2>/dev/null || stat -c%s "public/dist/main.min.js" 2>/dev/null)
    log_test "ASSET_MAIN_JS" "PASS" "main.min.js present (${SIZE} bytes)"
else
    log_test "ASSET_MAIN_JS" "FAIL" "main.min.js is MISSING"
fi

if [ -f "public/bundles/pimui/manifest.json" ]; then
    log_test "ASSET_MANIFEST" "PASS" "manifest.json present"
else
    log_test "ASSET_MANIFEST" "FAIL" "manifest.json is MISSING"
fi

# Test 3.3: Permissions
echo "Test 3.3: Directory Permissions"
for dir in "var/cache" "var/logs" "var/sessions"; do
    if [ -w "$dir" ]; then
        log_test "PERM_${dir//\//_}" "PASS" "$dir is writable"
    else
        log_test "PERM_${dir//\//_}" "FAIL" "$dir is NOT writable"
    fi
done

echo ""
echo "========================================"
echo "TEST CATEGORY 4: ELASTICSEARCH"
echo "========================================"

# Test 4.1: Elasticsearch Service
echo "Test 4.1: Elasticsearch Service Check"
if curl -s http://localhost:9200/_cluster/health &>/dev/null; then
    ES_STATUS=$(curl -s http://localhost:9200/_cluster/health | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
    if [ "$ES_STATUS" == "green" ] || [ "$ES_STATUS" == "yellow" ]; then
        log_test "ES_SERVICE" "PASS" "Elasticsearch is $ES_STATUS"
    else
        log_test "ES_SERVICE" "WARN" "Elasticsearch status: $ES_STATUS"
    fi
else
    log_test "ES_SERVICE" "FAIL" "Cannot connect to Elasticsearch"
fi

# Test 4.2: Elasticsearch Indices
echo "Test 4.2: Akeneo Elasticsearch Indices"
INDEX_COUNT=$(curl -s http://localhost:9200/_cat/indices 2>/dev/null | grep -c akeneo || echo 0)
if [ "$INDEX_COUNT" -ge 3 ]; then
    log_test "ES_INDICES" "PASS" "$INDEX_COUNT Akeneo indices found"
else
    log_test "ES_INDICES" "WARN" "Only $INDEX_COUNT Akeneo indices found"
fi

# Test 4.3: Product Index Count
echo "Test 4.3: Product Index Document Count"
INDEXED_PRODUCTS=$(curl -s "http://localhost:9200/akeneo_pim_product*/_count" 2>/dev/null | grep -o '"count":[0-9]*' | cut -d':' -f2 || echo 0)
if [ "$INDEXED_PRODUCTS" -gt 9000 ]; then
    log_test "ES_PRODUCT_COUNT" "PASS" "$INDEXED_PRODUCTS products indexed"
elif [ "$INDEXED_PRODUCTS" -gt 0 ]; then
    log_test "ES_PRODUCT_COUNT" "WARN" "Only $INDEXED_PRODUCTS products indexed (expected ~9538)"
else
    log_test "ES_PRODUCT_COUNT" "WARN" "No products indexed (indexing may be needed)"
fi

echo ""
echo "========================================"
echo "TEST CATEGORY 5: WEB INTERFACE"
echo "========================================"

# Test 5.1: Login Page
echo "Test 5.1: Login Page Accessibility"
LOGIN_STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://pim.technostationery.com/user/login)
RESPONSE_TIME=$(curl -s -o /dev/null -w "%{time_total}" https://pim.technostationery.com/user/login)
if [ "$LOGIN_STATUS" == "200" ]; then
    log_test "WEB_LOGIN_PAGE" "PASS" "HTTP $LOGIN_STATUS (${RESPONSE_TIME}s)"
else
    log_test "WEB_LOGIN_PAGE" "FAIL" "HTTP $LOGIN_STATUS"
fi

# Test 5.2: Dashboard
echo "Test 5.2: Dashboard Accessibility"
DASHBOARD_STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://pim.technostationery.com/)
if [ "$DASHBOARD_STATUS" == "200" ] || [ "$DASHBOARD_STATUS" == "302" ]; then
    log_test "WEB_DASHBOARD" "PASS" "HTTP $DASHBOARD_STATUS"
else
    log_test "WEB_DASHBOARD" "WARN" "HTTP $DASHBOARD_STATUS (may require authentication)"
fi

# Test 5.3: Static Assets
echo "Test 5.3: Static Asset Delivery"
CSS_STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://pim.technostationery.com/css/pim.css)
if [ "$CSS_STATUS" == "200" ]; then
    log_test "WEB_CSS_ASSET" "PASS" "CSS assets HTTP $CSS_STATUS"
else
    log_test "WEB_CSS_ASSET" "FAIL" "CSS assets HTTP $CSS_STATUS"
fi

echo ""
echo "========================================"
echo "TEST CATEGORY 6: CONFIGURATION FILES"
echo "========================================"

# Test 6.1: Environment Files
echo "Test 6.1: Environment Configuration Files"
for file in ".env" ".env.local" "config/packages/security.yml"; do
    if [ -f "$file" ]; then
        log_test "CONFIG_${file//\//_}" "PASS" "$file exists"
    else
        log_test "CONFIG_${file//\//_}" "WARN" "$file not found"
    fi
done

# Test 6.2: Database Configuration
echo "Test 6.2: Database Configuration Check"
if grep -q "APP_DATABASE_HOST=127.0.0.1" .env 2>/dev/null; then
    log_test "CONFIG_DB_HOST" "PASS" "Database host configured"
else
    log_test "CONFIG_DB_HOST" "WARN" "Database host may need verification"
fi

if grep -q "APP_DATABASE_PORT=3307" .env 2>/dev/null; then
    log_test "CONFIG_DB_PORT" "PASS" "Database port configured (3307)"
else
    log_test "CONFIG_DB_PORT" "WARN" "Database port may need verification"
fi

echo ""
echo "========================================"
echo "TEST CATEGORY 7: CACHE & PERFORMANCE"
echo "========================================"

# Test 7.1: Symfony Cache
echo "Test 7.1: Symfony Cache Status"
if [ -d "var/cache/prod" ] && [ "$(ls -A var/cache/prod)" ]; then
    CACHE_FILES=$(find var/cache/prod -type f | wc -l)
    log_test "CACHE_SYMFONY" "PASS" "$CACHE_FILES cache files present"
else
    log_test "CACHE_SYMFONY" "WARN" "Production cache may need warming"
fi

# Test 7.2: OPcache Status
echo "Test 7.2: OPcache Configuration"
if php -r "echo ini_get('opcache.enable');" | grep -q "1"; then
    log_test "CACHE_OPCACHE" "PASS" "OPcache is enabled"
else
    log_test "CACHE_OPCACHE" "WARN" "OPcache may not be enabled"
fi

echo ""
echo "========================================"
echo "TEST CATEGORY 8: AKENEO SPECIFIC"
echo "========================================"

# Test 8.1: Akeneo Console Commands
echo "Test 8.1: Akeneo Console Commands Availability"
if php bin/console list | grep -q "pim:product"; then
    log_test "AKENEO_COMMANDS" "PASS" "Akeneo commands available"
else
    log_test "AKENEO_COMMANDS" "FAIL" "Akeneo commands not found"
fi

# Test 8.2: Channels Configuration
echo "Test 8.2: Sales Channels Configuration"
CHANNEL_COUNT=$(mysql -h 127.0.0.1 -P 3307 -u akeneo_pim -pakeneo_pim --skip-ssl akeneo_pim -e "SELECT COUNT(*) FROM pim_catalog_channel;" 2>/dev/null | tail -1)
if [ "$CHANNEL_COUNT" -ge 3 ]; then
    log_test "AKENEO_CHANNELS" "PASS" "$CHANNEL_COUNT channels configured"
else
    log_test "AKENEO_CHANNELS" "WARN" "Only $CHANNEL_COUNT channels (expected 3)"
fi

# Test 8.3: Locales Configuration
echo "Test 8.3: Locale Configuration"
LOCALE_COUNT=$(mysql -h 127.0.0.1 -P 3307 -u akeneo_pim -pakeneo_pim --skip-ssl akeneo_pim -e "SELECT COUNT(*) FROM pim_catalog_locale;" 2>/dev/null | tail -1)
if [ "$LOCALE_COUNT" -gt 200 ]; then
    log_test "AKENEO_LOCALES" "PASS" "$LOCALE_COUNT locales configured"
else
    log_test "AKENEO_LOCALES" "WARN" "$LOCALE_COUNT locales configured"
fi

# Test 8.4: Family Configuration
echo "Test 8.4: Product Families"
FAMILY_COUNT=$(mysql -h 127.0.0.1 -P 3307 -u akeneo_pim -pakeneo_pim --skip-ssl akeneo_pim -e "SELECT COUNT(*) FROM pim_catalog_family;" 2>/dev/null | tail -1)
if [ "$FAMILY_COUNT" -gt 10 ]; then
    log_test "AKENEO_FAMILIES" "PASS" "$FAMILY_COUNT families configured"
else
    log_test "AKENEO_FAMILIES" "WARN" "$FAMILY_COUNT families configured"
fi

echo ""
echo "========================================"
echo "FINAL SUMMARY"
echo "========================================"
echo ""
echo -e "${GREEN}PASSED:${NC} $PASSED tests"
echo -e "${YELLOW}WARNINGS:${NC} $WARNINGS tests"
echo -e "${RED}FAILED:${NC} $FAILED tests"
echo ""

TOTAL=$((PASSED + WARNINGS + FAILED))
SUCCESS_RATE=$((PASSED * 100 / TOTAL))

echo "Total Tests: $TOTAL"
echo "Success Rate: ${SUCCESS_RATE}%"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ ALL CRITICAL TESTS PASSED${NC}"
    EXIT_CODE=0
elif [ $FAILED -le 2 ]; then
    echo -e "${YELLOW}⚠ MINOR ISSUES DETECTED (${FAILED} failures)${NC}"
    EXIT_CODE=1
else
    echo -e "${RED}✗ SIGNIFICANT ISSUES DETECTED (${FAILED} failures)${NC}"
    EXIT_CODE=2
fi

echo ""
echo "Detailed log saved to: $LOG_FILE"
echo "Completed: $(date)"
echo "========================================"

exit $EXIT_CODE
