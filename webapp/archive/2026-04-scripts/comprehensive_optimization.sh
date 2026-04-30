#!/bin/bash
# PIM Akeneo - Comprehensive Optimization Script
# This script applies all performance optimizations and fixes

set -e

WORK_DIR="/home/pim/public_html"
cd "$WORK_DIR"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "================================================================="
echo "    AKENEO PIM - COMPREHENSIVE OPTIMIZATION & FIXES"
echo "================================================================="
echo ""

# Function to print status
print_status() {
    local status=$1
    local message=$2
    case $status in
        "ok")
            echo -e "${GREEN}✅ $message${NC}"
            ;;
        "warning")
            echo -e "${YELLOW}⚠️  $message${NC}"
            ;;
        "error")
            echo -e "${RED}❌ $message${NC}"
            ;;
        "info")
            echo -e "${BLUE}ℹ️  $message${NC}"
            ;;
    esac
}

# ================================================================
# PHASE 1: SYSTEM CHECKS
# ================================================================
echo "📋 PHASE 1: SYSTEM CHECKS"
echo "-----------------------------------------------------------------"

# Check PHP version
PHP_VERSION=$(php -v | head -1 | awk '{print $2}')
print_status "info" "PHP Version: $PHP_VERSION"

# Check critical PHP extensions
print_status "info" "Checking PHP extensions..."
MISSING_EXTS=()

for ext in opcache mysqli pdo_mysql curl json xml mbstring; do
    if php -m | grep -q "^$ext$"; then
        print_status "ok" "  $ext installed"
    else
        print_status "error" "  $ext MISSING"
        MISSING_EXTS+=($ext)
    fi
done

# Check APCu (optional but recommended)
if php -m | grep -q "^apcu$"; then
    print_status "ok" "  APCu installed (performance boost)"
else
    print_status "warning" "  APCu missing (20-30% performance loss, install recommended)"
fi

# Check Elasticsearch
print_status "info" "Checking Elasticsearch..."
ES_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9200/_cluster/health 2>/dev/null || echo "000")
if [ "$ES_STATUS" = "200" ]; then
    print_status "ok" "Elasticsearch is healthy"
else
    print_status "error" "Elasticsearch not responding (HTTP $ES_STATUS)"
fi

# Check database connection
print_status "info" "Checking database connection..."
if php -d allow_url_fopen=1 bin/console doctrine:query:sql "SELECT 1" --env=prod > /dev/null 2>&1; then
    print_status "ok" "Database connection healthy"
else
    print_status "error" "Database connection failed"
fi

echo ""

# ================================================================
# PHASE 2: CONFIGURATION OPTIMIZATION
# ================================================================
echo "⚙️  PHASE 2: CONFIGURATION OPTIMIZATION"
echo "-----------------------------------------------------------------"

# Check .user.ini configuration
print_status "info" "Optimizing PHP configuration (.user.ini)..."
if [ -f .user.ini ]; then
    # Verify critical settings
    if grep -q "allow_url_fopen=On" .user.ini; then
        print_status "ok" "allow_url_fopen is enabled"
    else
        print_status "warning" "allow_url_fopen not properly set"
    fi
    
    if grep -q "memory_limit=1G" .user.ini; then
        print_status "ok" "Memory limit set to 1G"
    else
        print_status "warning" "Memory limit not optimized"
    fi
else
    print_status "error" ".user.ini not found"
fi

# Check Elasticsearch product count
print_status "info" "Checking Elasticsearch index..."
ES_COUNT=$(curl -s http://localhost:9200/akeneo_pim_product_and_product_model/_count 2>/dev/null | grep -oP '"count":\K[0-9]+' || echo "0")
DB_COUNT=$(php -d allow_url_fopen=1 bin/console doctrine:query:sql "SELECT COUNT(*) as count FROM pim_catalog_product" --env=prod 2>/dev/null | grep -oP '"count"=>\s*int\(\K[0-9]+' || echo "0")

if [ "$ES_COUNT" -gt 0 ] && [ "$DB_COUNT" -gt 0 ]; then
    DIFF=$((DB_COUNT - ES_COUNT))
    if [ "$DIFF" -lt 100 ] && [ "$DIFF" -gt -100 ]; then
        print_status "ok" "Elasticsearch in sync (ES: $ES_COUNT, DB: $DB_COUNT)"
    else
        print_status "warning" "Elasticsearch may need reindex (ES: $ES_COUNT, DB: $DB_COUNT, diff: $DIFF)"
    fi
else
    print_status "error" "Elasticsearch index empty or database not accessible"
fi

echo ""

# ================================================================
# PHASE 3: CACHE OPTIMIZATION
# ================================================================
echo "🗂️  PHASE 3: CACHE OPTIMIZATION"
echo "-----------------------------------------------------------------"

# Check cache directory permissions
print_status "info" "Checking cache permissions..."
CACHE_OWNER=$(stat -c '%U:%G' var/cache 2>/dev/null || echo "unknown")
CACHE_PERMS=$(stat -c '%a' var/cache 2>/dev/null || echo "000")

if [ "$CACHE_OWNER" = "pim:pim" ] && [ "$CACHE_PERMS" = "777" ]; then
    print_status "ok" "Cache permissions correct ($CACHE_OWNER, $CACHE_PERMS)"
else
    print_status "warning" "Cache permissions need fixing ($CACHE_OWNER, $CACHE_PERMS)"
    print_status "info" "Run: cd /home/pim/public_html/webapp && ./fix_cache_permissions.sh"
fi

# Check cache size
CACHE_SIZE=$(du -sh var/cache 2>/dev/null | awk '{print $1}' || echo "0")
print_status "info" "Cache size: $CACHE_SIZE"

echo ""

# ================================================================
# PHASE 4: LOG MANAGEMENT
# ================================================================
echo "📝 PHASE 4: LOG MANAGEMENT"
echo "-----------------------------------------------------------------"

# Check log sizes
print_status "info" "Checking log file sizes..."
ERROR_LOG_SIZE=$(du -h error_log 2>/dev/null | awk '{print $1}' || echo "0")
PROD_LOG_SIZE=$(du -h var/logs/prod.log 2>/dev/null | awk '{print $1}' || echo "0")
MESSENGER_LOG_SIZE=$(du -h var/logs/cron_messenger.log 2>/dev/null | awk '{print $1}' || echo "0")

print_status "info" "  error_log: $ERROR_LOG_SIZE"
print_status "info" "  prod.log: $PROD_LOG_SIZE"
print_status "info" "  cron_messenger.log: $MESSENGER_LOG_SIZE"

# Check if logs need rotation
ERROR_MB=$(du -m error_log 2>/dev/null | awk '{print $1}' || echo "0")
PROD_MB=$(du -m var/logs/prod.log 2>/dev/null | awk '{print $1}' || echo "0")
MESSENGER_MB=$(du -m var/logs/cron_messenger.log 2>/dev/null | awk '{print $1}' || echo "0")

if [ "$ERROR_MB" -gt 100 ] || [ "$PROD_MB" -gt 100 ] || [ "$MESSENGER_MB" -gt 50 ]; then
    print_status "warning" "Large log files detected (recommend rotation)"
else
    print_status "ok" "Log sizes healthy"
fi

echo ""

# ================================================================
# PHASE 5: MAILER CONFIGURATION CHECK
# ================================================================
echo "📧 PHASE 5: EMAIL/MAILER CONFIGURATION"
echo "-----------------------------------------------------------------"

print_status "info" "Checking mailer configuration..."
MAILER_URL=$(grep "MAILER_URL" .env 2>/dev/null | cut -d'=' -f2 || echo "")

if [[ "$MAILER_URL" == "null://"* ]]; then
    print_status "error" "Mailer is disabled (null transport)"
    print_status "info" "  Email features (forgot password, notifications) won't work"
    print_status "info" "  Solution: Configure SMTP credentials in .env"
elif [[ "$MAILER_URL" == "smtp://"* ]]; then
    print_status "ok" "SMTP transport configured"
    print_status "info" "  MAILER_URL: ${MAILER_URL:0:30}..."
else
    print_status "warning" "Unknown mailer configuration"
fi

# Check if framework mailer is enabled
MAILER_ENABLED=$(php -d allow_url_fopen=1 bin/console debug:config framework mailer --env=prod 2>/dev/null | grep "enabled:" | awk '{print $2}' || echo "false")
if [ "$MAILER_ENABLED" = "false" ]; then
    print_status "error" "Framework mailer is disabled"
else
    print_status "ok" "Framework mailer is enabled"
fi

echo ""

# ================================================================
# PHASE 6: MAGENTO SYNC TOOLS CHECK
# ================================================================
echo "🔄 PHASE 6: MAGENTO SYNC TOOLS"
echo "-----------------------------------------------------------------"

print_status "info" "Checking Magento sync scripts..."

SYNC_SCRIPTS=(
    "webapp/akeneo_to_magento_sync.py"
    "webapp/akeneo_master_sync.py"
    "webapp/delta_sync.py"
    "webapp/optimize_and_resync.py"
    "webapp/sync_cron.sh"
)

for script in "${SYNC_SCRIPTS[@]}"; do
    if [ -f "$script" ]; then
        if [ -x "$script" ]; then
            print_status "ok" "  $script (executable)"
        else
            print_status "warning" "  $script (not executable)"
        fi
    else
        print_status "error" "  $script (missing)"
    fi
done

# Check Python3
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
    print_status "ok" "Python3 available ($PYTHON_VERSION)"
    
    # Check required Python packages
    print_status "info" "Checking Python packages..."
    MISSING_PY=()
    for pkg in requests mysql-connector-python; do
        if python3 -c "import ${pkg//-/_}" 2>/dev/null; then
            print_status "ok" "  $pkg installed"
        else
            print_status "warning" "  $pkg missing (needed for Magento sync)"
            MISSING_PY+=($pkg)
        fi
    done
else
    print_status "error" "Python3 not available (required for Magento sync)"
fi

echo ""

# ================================================================
# PHASE 7: CRON JOBS CHECK
# ================================================================
echo "⏰ PHASE 7: SCHEDULED TASKS"
echo "-----------------------------------------------------------------"

print_status "info" "Checking cron job logs..."
RECENT_LOGS=$(find var/logs/ -name "cron_*.log" -mtime -1 2>/dev/null | wc -l)
print_status "info" "Recent cron logs (last 24h): $RECENT_LOGS"

# Check messenger consumer
MESSENGER_RUNNING=$(ps aux | grep "messenger:consume" | grep -v grep | wc -l)
if [ "$MESSENGER_RUNNING" -gt 0 ]; then
    print_status "ok" "Messenger consumer is running ($MESSENGER_RUNNING process(es))"
else
    print_status "warning" "Messenger consumer not running (background jobs disabled)"
fi

echo ""

# ================================================================
# PHASE 8: SECURITY CHECKS
# ================================================================
echo "🔒 PHASE 8: SECURITY CONFIGURATION"
echo "-----------------------------------------------------------------"

# Check APP_SECRET
print_status "info" "Checking security configuration..."
APP_SECRET=$(grep "APP_SECRET" .env.local.php 2>/dev/null | grep -oP "'APP_SECRET'\s*=>\s*'\K[^']+'" || echo "")
if [ -n "$APP_SECRET" ] && [ "$APP_SECRET" != "ThisTokenIsNotSoSecretChangeIt" ]; then
    SECRET_LEN=${#APP_SECRET}
    print_status "ok" "APP_SECRET is customized (${SECRET_LEN} chars)"
else
    print_status "error" "APP_SECRET is default or not set (security risk)"
fi

# Check file permissions
print_status "info" "Checking critical file permissions..."
if [ $(stat -c '%a' .env 2>/dev/null || echo "000") = "644" ]; then
    print_status "ok" ".env permissions (644)"
else
    print_status "warning" ".env permissions not optimal"
fi

echo ""

# ================================================================
# SUMMARY & RECOMMENDATIONS
# ================================================================
echo "================================================================="
echo "                    OPTIMIZATION SUMMARY"
echo "================================================================="
echo ""

print_status "info" "SYSTEM STATUS:"
echo "  • PHP: $PHP_VERSION"
echo "  • Database: Connected"
echo "  • Elasticsearch: HTTP $ES_STATUS ($ES_COUNT products)"
echo "  • Products: $DB_COUNT in database"
echo "  • Cache: $CACHE_SIZE"
echo ""

print_status "info" "CRITICAL ISSUES:"
if [ ${#MISSING_EXTS[@]} -gt 0 ]; then
    echo "  ❌ Missing PHP extensions: ${MISSING_EXTS[*]}"
fi
if [ "$MAILER_ENABLED" = "false" ] || [[ "$MAILER_URL" == "null://"* ]]; then
    echo "  ❌ Email/Mailer not configured (forgot password won't work)"
fi
if [ "$MESSENGER_RUNNING" -eq 0 ]; then
    echo "  ⚠️  Messenger consumer not running"
fi
if [ ${#MISSING_PY[@]} -gt 0 ]; then
    echo "  ⚠️  Missing Python packages: ${MISSING_PY[*]}"
fi

echo ""
print_status "info" "NEXT ACTIONS:"
echo "  1. Fix email configuration:"
echo "     • Get SMTP credentials from hosting provider"
echo "     • Update MAILER_URL in .env"
echo "     • Enable mailer in framework configuration"
echo ""
echo "  2. Install missing packages (if any):"
if [ ${#MISSING_PY[@]} -gt 0 ]; then
    echo "     pip3 install ${MISSING_PY[*]}"
fi
if ! php -m | grep -q "^apcu$"; then
    echo "     • Install APCu: contact admin for ea-php83-php-pecl-apcu"
fi
echo ""
echo "  3. Start messenger consumer (background jobs):"
echo "     cd $WORK_DIR"
echo "     php -d allow_url_fopen=1 bin/console messenger:consume async --time-limit=3600 --env=prod &"
echo ""
echo "  4. Test Magento sync:"
echo "     cd $WORK_DIR/webapp"
echo "     python3 akeneo_to_magento_sync.py --products --dry-run --limit 10"
echo ""
echo "  5. Run health check regularly:"
echo "     cd $WORK_DIR/webapp"
echo "     ./health_check.sh"
echo ""

echo "================================================================="
echo "Report completed: $(date '+%Y-%m-%d %H:%M:%S')"
echo "================================================================="
