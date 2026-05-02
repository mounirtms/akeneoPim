#!/bin/bash
# PHASE 1: EMERGENCY RECOVERY - AKENEO PIM
# Restore to last known working state (backlastchanges branch)

set -e  # Exit on error

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║         AKENEO PIM - EMERGENCY RECOVERY PHASE 1                ║"
echo "║         Restore to Working State (backlastchanges)             ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Log file
LOG_FILE="/home/pim/public_html/recovery_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG_FILE")
exec 2>&1

echo "Started: $(date)"
echo "Log: $LOG_FILE"
echo ""

cd /home/pim/public_html

# ============================================================================
# STEP 1: BACKUP CURRENT STATE
# ============================================================================
echo "=== STEP 1: BACKING UP CURRENT STATE ==="
echo ""

# Backup .env
if [ -f .env ]; then
    cp .env .env.backup.$(date +%Y%m%d_%H%M%S)
    echo "✓ Backed up .env"
fi

# Backup security.yml
if [ -f config/packages/security.yml ]; then
    cp config/packages/security.yml config/packages/security.yml.backup.$(date +%Y%m%d_%H%M%S)
    echo "✓ Backed up security.yml"
fi

# Stash any uncommitted changes
echo ""
echo "Stashing uncommitted changes..."
git stash save "Pre-recovery backup $(date +%Y%m%d_%H%M%S)" || true

echo ""

# ============================================================================
# STEP 2: SWITCH TO WORKING BRANCH
# ============================================================================
echo "=== STEP 2: SWITCHING TO WORKING BRANCH (backlastchanges) ==="
echo ""

# Check current branch
CURRENT_BRANCH=$(git branch --show-current)
echo "Current branch: $CURRENT_BRANCH"

if [ "$CURRENT_BRANCH" != "backlastchanges" ]; then
    echo "Switching to backlastchanges..."
    git checkout backlastchanges
    echo "✓ Switched to backlastchanges"
else
    echo "Already on backlastchanges"
fi

# Pull latest changes
echo ""
echo "Pulling latest changes..."
git pull origin backlastchanges || echo "⚠ Could not pull (already up to date or no remote)"

echo ""

# ============================================================================
# STEP 3: FIX DATABASE CREDENTIALS
# ============================================================================
echo "=== STEP 3: FIXING DATABASE CREDENTIALS ==="
echo ""

# Update .env with correct database settings
echo "Updating .env with correct database credentials..."

# Backup original
cp .env .env.before_fix

# Fix database settings
sed -i 's/APP_DATABASE_HOST=.*/APP_DATABASE_HOST=127.0.0.1/' .env
sed -i 's/APP_DATABASE_PORT=.*/APP_DATABASE_PORT=3307/' .env
sed -i 's/APP_DATABASE_NAME=.*/APP_DATABASE_NAME=pim_dBT8x12y22/' .env
sed -i 's/APP_DATABASE_USER=.*/APP_DATABASE_USER=pim_ntdbusr24/' .env
sed -i 's/APP_DATABASE_PASSWORD=.*/APP_DATABASE_PASSWORD=PIM2024Secure!/' .env

# Enable debug mode for troubleshooting
sed -i 's/APP_ENV=.*/APP_ENV=dev/' .env
sed -i 's/APP_DEBUG=.*/APP_DEBUG=1/' .env

echo "✓ Updated .env"
echo ""

# Test database connection
echo "Testing database connection..."
mariadb -u pim_ntdbusr24 -p'PIM2024Secure!' -h 127.0.0.1 -P 3307 --ssl=0 pim_dBT8x12y22 \
  -e "SELECT COUNT(*) as user_count FROM oro_user;" 2>&1 | tail -1 && echo "✓ Database connection OK" || echo "⚠ Database connection failed"

echo ""

# ============================================================================
# STEP 4: VERIFY CRITICAL ASSETS
# ============================================================================
echo "=== STEP 4: VERIFYING CRITICAL FRONTEND ASSETS ==="
echo ""

check_file() {
    if [ -f "$1" ]; then
        SIZE=$(du -h "$1" | cut -f1)
        echo "  ✓ $1 ($SIZE)"
        return 0
    else
        echo "  ✗ $1 MISSING"
        return 1
    fi
}

# Check critical files
check_file "public/js/extensions.json"
check_file "public/css/pim.css"
check_file "public/bundles/pimui/manifest.json"
check_file "public/bundles/pimui/js/index.js"

MISSING_COUNT=0
test -f public/js/extensions.json || MISSING_COUNT=$((MISSING_COUNT + 1))
test -f public/css/pim.css || MISSING_COUNT=$((MISSING_COUNT + 1))

echo ""
if [ $MISSING_COUNT -eq 0 ]; then
    echo "✓ All critical assets present"
else
    echo "⚠ $MISSING_COUNT critical assets missing - rebuild required"
fi

echo ""

# ============================================================================
# STEP 5: REBUILD ASSETS IF NEEDED
# ============================================================================
if [ $MISSING_COUNT -gt 0 ]; then
    echo "=== STEP 5: REBUILDING MISSING ASSETS ==="
    echo ""
    
    # Clear cache first
    echo "Clearing cache..."
    rm -rf var/cache/*
    
    # Run LESS compilation
    echo ""
    echo "Compiling LESS to CSS..."
    yarn run less || echo "⚠ LESS compilation warning"
    
    # Update extensions
    echo ""
    echo "Updating extensions.json..."
    yarn run update-extensions || echo "⚠ Extensions update warning"
    
    # Install assets
    echo ""
    echo "Installing Akeneo assets..."
    php bin/console pim:installer:assets --symlink --clean --env=dev
    
    # Dump require paths
    echo ""
    echo "Dumping require paths..."
    php bin/console pim:installer:dump-require-paths --env=dev
    
    # Re-check assets
    echo ""
    echo "Re-checking assets..."
    check_file "public/js/extensions.json"
    check_file "public/css/pim.css"
    
    echo ""
fi

# ============================================================================
# STEP 6: CLEAR & WARM CACHE
# ============================================================================
echo "=== STEP 6: CACHE OPERATIONS ==="
echo ""

echo "Clearing Symfony cache..."
php bin/console cache:clear --env=dev

echo ""
echo "Warming up cache..."
php bin/console cache:warmup --env=dev

echo ""

# ============================================================================
# STEP 7: VERIFICATION SUMMARY
# ============================================================================
echo "=== STEP 7: VERIFICATION SUMMARY ==="
echo ""

echo "1. Git Branch:"
git branch --show-current | xargs echo "   Current:"

echo ""
echo "2. Frontend Assets:"
test -f public/js/extensions.json && echo "   ✓ extensions.json" || echo "   ✗ extensions.json MISSING"
test -f public/css/pim.css && echo "   ✓ pim.css" || echo "   ✗ pim.css MISSING"
test -f public/bundles/pimui/manifest.json && echo "   ✓ manifest.json" || echo "   ✗ manifest.json MISSING"

echo ""
echo "3. Configuration:"
grep "APP_DATABASE_HOST" .env | xargs echo "   "
grep "APP_DATABASE_PORT" .env | xargs echo "   "
grep "APP_ENV" .env | xargs echo "   "

echo ""
echo "4. Database:"
mariadb -u pim_ntdbusr24 -p'PIM2024Secure!' -h 127.0.0.1 -P 3307 --ssl=0 pim_dBT8x12y22 \
  -e "SELECT COUNT(*) as users FROM oro_user;" 2>&1 | tail -1 | xargs echo "   User count:"

echo ""

# ============================================================================
# COMPLETION
# ============================================================================
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║              PHASE 1 RECOVERY COMPLETE                         ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "Next Steps:"
echo "1. Test login: node webapp/test_login_properly.js"
echo "2. Check UI: Access https://[your-domain]/user/login"
echo "3. Review log: $LOG_FILE"
echo ""
echo "Completed: $(date)"
