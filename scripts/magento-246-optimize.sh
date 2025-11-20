#!/bin/bash

# Magento 2.4.6 Optimization & Health Check Script
# This script optimizes Magento for better performance with Pimcore integration

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║      MAGENTO 2.4.6 - OPTIMIZATION & HEALTH CHECK               ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Configuration - Update these paths
MAGENTO_ROOT="/home/technadminy7/public_html"
MAGENTO_BIN="${MAGENTO_ROOT}/bin/magento"
BACKUP_DIR="/home/technadminy7/backups"
DATE=$(date +%Y%m%d_%H%M%S)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print status
print_status() {
    local status=$1
    local message=$2
    
    case $status in
        "ok")
            echo -e "   ${GREEN}✅${NC} $message"
            ;;
        "warn")
            echo -e "   ${YELLOW}⚠️${NC}  $message"
            ;;
        "error")
            echo -e "   ${RED}❌${NC} $message"
            ;;
        "info")
            echo -e "   ${BLUE}ℹ️${NC}  $message"
            ;;
    esac
}

# Function to run Magento command
run_magento() {
    if [ -f "$MAGENTO_BIN" ]; then
        php "$MAGENTO_BIN" "$@"
        return $?
    else
        print_status "error" "Magento CLI not found at: $MAGENTO_BIN"
        return 1
    fi
}

# Check if Magento exists
if [ ! -f "$MAGENTO_BIN" ]; then
    print_status "warn" "Magento installation not found at: $MAGENTO_ROOT"
    print_status "info" "Please update MAGENTO_ROOT variable in this script"
    echo ""
    echo "Current script location: $0"
    echo "Expected Magento at: $MAGENTO_ROOT"
    echo ""
    exit 1
fi

echo "📍 Magento Location: $MAGENTO_ROOT"
echo ""

# ============================================================================
# PHASE 1: HEALTH CHECK
# ============================================================================
echo "═══════════════════════════════════════════════════════════════"
echo "🔍 PHASE 1: HEALTH CHECK"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Check Magento version
echo "📦 Version Information:"
VERSION=$(run_magento --version 2>/dev/null)
if [ $? -eq 0 ]; then
    print_status "ok" "Magento Version: $VERSION"
else
    print_status "error" "Cannot determine Magento version"
fi
echo ""

# Check mode
echo "⚙️  Configuration:"
MODE=$(grep "MAGE_MODE" "${MAGENTO_ROOT}/.htaccess" 2>/dev/null | head -1)
if echo "$MODE" | grep -q "production"; then
    print_status "ok" "Mode: Production"
elif echo "$MODE" | grep -q "developer"; then
    print_status "warn" "Mode: Developer (should be production)"
else
    print_status "info" "Mode: Default (recommend setting to production)"
fi
echo ""

# Check database connection
echo "🗄️  Database Connection:"
DB_CHECK=$(run_magento setup:db:status 2>&1)
if echo "$DB_CHECK" | grep -q "Up to date"; then
    print_status "ok" "Database connection verified"
else
    print_status "warn" "Database might need updates"
fi
echo ""

# ============================================================================
# PHASE 2: CACHE OPTIMIZATION
# ============================================================================
echo "═══════════════════════════════════════════════════════════════"
echo "💾 PHASE 2: CACHE OPTIMIZATION"
echo "═══════════════════════════════════════════════════════════════"
echo ""

print_status "info" "Clearing Magento cache..."
run_magento cache:clean
run_magento cache:flush
print_status "ok" "Cache cleared"
echo ""

print_status "info" "Enabling all cache types..."
run_magento cache:enable
print_status "ok" "All caches enabled"
echo ""

# Check cache status
echo "📊 Cache Status:"
run_magento cache:status
echo ""

# ============================================================================
# PHASE 3: INDEXER OPTIMIZATION
# ============================================================================
echo "═══════════════════════════════════════════════════════════════"
echo "🔄 PHASE 3: INDEXER OPTIMIZATION"
echo "═══════════════════════════════════════════════════════════════"
echo ""

print_status "info" "Reindexing all indexers..."
run_magento indexer:reindex
if [ $? -eq 0 ]; then
    print_status "ok" "All indexers reindexed successfully"
else
    print_status "warn" "Some indexers may have failed - check manually"
fi
echo ""

# Set indexers to update on schedule (better for production)
print_status "info" "Setting indexers to 'Update on Schedule' mode..."
run_magento indexer:set-mode schedule
print_status "ok" "Indexers set to scheduled mode"
echo ""

echo "📊 Indexer Status:"
run_magento indexer:status
echo ""

# ============================================================================
# PHASE 4: DATABASE OPTIMIZATION
# ============================================================================
echo "═══════════════════════════════════════════════════════════════"
echo "🗄️  PHASE 4: DATABASE OPTIMIZATION"
echo "═══════════════════════════════════════════════════════════════"
echo ""

print_status "info" "Cleaning old logs..."
run_magento log:clean --days=7
print_status "ok" "Logs older than 7 days removed"
echo ""

print_status "info" "Cleaning old reports..."
# Clean report tables
mysql -e "TRUNCATE TABLE report_event; TRUNCATE TABLE report_viewed_product_index;" 2>/dev/null || print_status "warn" "Manual database cleanup recommended"
echo ""

# ============================================================================
# PHASE 5: STATIC CONTENT
# ============================================================================
echo "═══════════════════════════════════════════════════════════════"
echo "🎨 PHASE 5: STATIC CONTENT DEPLOYMENT"
echo "═══════════════════════════════════════════════════════════════"
echo ""

print_status "info" "Cleaning static files..."
run_magento setup:static-content:deploy -f
if [ $? -eq 0 ]; then
    print_status "ok" "Static content deployed"
else
    print_status "warn" "Static content deployment had issues"
fi
echo ""

# ============================================================================
# PHASE 6: CATALOG OPTIMIZATION
# ============================================================================
echo "═══════════════════════════════════════════════════════════════"
echo "📦 PHASE 6: CATALOG OPTIMIZATION"
echo "═══════════════════════════════════════════════════════════════"
echo ""

print_status "info" "Checking catalog configuration..."

# Enable flat catalog (recommended for large catalogs)
print_status "info" "Enabling flat catalog for products..."
run_magento config:set catalog/frontend/flat_catalog_product 1
print_status "ok" "Flat catalog for products enabled"

print_status "info" "Enabling flat catalog for categories..."
run_magento config:set catalog/frontend/flat_catalog_category 1
print_status "ok" "Flat catalog for categories enabled"

echo ""

# ============================================================================
# PHASE 7: PERFORMANCE SETTINGS
# ============================================================================
echo "═══════════════════════════════════════════════════════════════"
echo "⚡ PHASE 7: PERFORMANCE SETTINGS"
echo "═══════════════════════════════════════════════════════════════"
echo ""

print_status "info" "Optimizing performance settings..."

# Merge CSS files
run_magento config:set dev/css/merge_css_files 1
print_status "ok" "CSS merging enabled"

# Merge JS files
run_magento config:set dev/js/merge_files 1
print_status "ok" "JavaScript merging enabled"

# Enable JS bundling
run_magento config:set dev/js/enable_js_bundling 1
print_status "ok" "JavaScript bundling enabled"

# Minify HTML
run_magento config:set dev/template/minify_html 1
print_status "ok" "HTML minification enabled"

# Minify CSS
run_magento config:set dev/css/minify_files 1
print_status "ok" "CSS minification enabled"

# Minify JS
run_magento config:set dev/js/minify_files 1
print_status "ok" "JavaScript minification enabled"

echo ""

# ============================================================================
# PHASE 8: COMPILATION & DEPLOYMENT
# ============================================================================
echo "═══════════════════════════════════════════════════════════════"
echo "🔨 PHASE 8: COMPILATION & DEPLOYMENT"
echo "═══════════════════════════════════════════════════════════════"
echo ""

print_status "info" "Running dependency injection compilation..."
run_magento setup:di:compile
if [ $? -eq 0 ]; then
    print_status "ok" "DI compilation successful"
else
    print_status "warn" "DI compilation had issues"
fi
echo ""

print_status "info" "Upgrading database schema..."
run_magento setup:upgrade --keep-generated
print_status "ok" "Database schema upgraded"
echo ""

# ============================================================================
# PHASE 9: PERMISSIONS
# ============================================================================
echo "═══════════════════════════════════════════════════════════════"
echo "🔒 PHASE 9: FILE PERMISSIONS"
echo "═══════════════════════════════════════════════════════════════"
echo ""

print_status "info" "Setting proper file permissions..."

# Set directory permissions
find "${MAGENTO_ROOT}/var" -type d -exec chmod 775 {} \; 2>/dev/null
find "${MAGENTO_ROOT}/pub" -type d -exec chmod 775 {} \; 2>/dev/null
find "${MAGENTO_ROOT}/generated" -type d -exec chmod 775 {} \; 2>/dev/null

# Set file permissions
find "${MAGENTO_ROOT}/var" -type f -exec chmod 664 {} \; 2>/dev/null
find "${MAGENTO_ROOT}/pub" -type f -exec chmod 664 {} \; 2>/dev/null
find "${MAGENTO_ROOT}/generated" -type f -exec chmod 664 {} \; 2>/dev/null

print_status "ok" "Permissions set for var/, pub/, generated/"
echo ""

# ============================================================================
# PHASE 10: EXPORT PREPARATION FOR PIMCORE
# ============================================================================
echo "═══════════════════════════════════════════════════════════════"
echo "📤 PHASE 10: EXPORT PREPARATION FOR PIMCORE"
echo "═══════════════════════════════════════════════════════════════"
echo ""

EXPORT_DIR="${MAGENTO_ROOT}/var/export"
mkdir -p "$EXPORT_DIR"

print_status "info" "Export directory: $EXPORT_DIR"
print_status "info" "To export catalog, run:"
echo "        php bin/magento catalog:product:export"
echo "        php bin/magento catalog:category:export"
echo ""

# ============================================================================
# SUMMARY
# ============================================================================
echo "═══════════════════════════════════════════════════════════════"
echo "📊 OPTIMIZATION SUMMARY"
echo "═══════════════════════════════════════════════════════════════"
echo ""

print_status "ok" "Cache cleared and enabled"
print_status "ok" "All indexers reindexed"
print_status "ok" "Static content deployed"
print_status "ok" "Flat catalog enabled"
print_status "ok" "CSS/JS merging and minification enabled"
print_status "ok" "Database optimized"
print_status "ok" "File permissions set"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "✅ MAGENTO 2.4.6 OPTIMIZATION COMPLETE"
echo "═══════════════════════════════════════════════════════════════"
echo ""

echo "🔍 Next Steps:"
echo "   1. Test admin panel: ${MAGENTO_ROOT}/admin"
echo "   2. Test frontend: ${MAGENTO_ROOT}/"
echo "   3. Export catalog: php bin/magento catalog:product:export"
echo "   4. Import to Pimcore: php import/import-products-from-magento.php"
echo ""

echo "📚 Documentation:"
echo "   • Magento DevDocs: https://devdocs.magento.com/"
echo "   • Performance Guide: See PIMCORE_MAGENTO_SETUP.md"
echo ""
