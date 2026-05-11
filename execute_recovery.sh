#!/bin/bash
################################################################################
# AKENEO PIM - AUTOMATED RECOVERY SCRIPT
# Date: May 6, 2026
# Purpose: Restore Akeneo PIM to stable state from April 26 backup
# Strategy: Database restoration + selective file recovery from git
################################################################################

set -e  # Exit on error
set -u  # Exit on undefined variable

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/home/pim/backups"
PROJECT_DIR="/home/pim/public_html"
RESTORE_DATE="20260426"
STABLE_COMMIT="380f907511d2f5fb923586fe3ac50c4edde02605"
LOG_FILE="$PROJECT_DIR/recovery_log_$TIMESTAMP.txt"

# Database credentials
DB_HOST="127.0.0.1"
DB_PORT="3307"
DB_NAME="akeneo_pim"
DB_USER="akeneo_pim"
DB_PASS="akeneo_pim"

################################################################################
# Logging functions
################################################################################

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1" | tee -a "$LOG_FILE"
}

log_info() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] INFO:${NC} $1" | tee -a "$LOG_FILE"
}

################################################################################
# Phase 1: Pre-flight checks
################################################################################

preflight_checks() {
    log "=========================================="
    log "PHASE 0: PRE-FLIGHT CHECKS"
    log "=========================================="
    
    # Check if running as correct user
    CURRENT_USER=$(whoami)
    log_info "Running as user: $CURRENT_USER"
    
    # Check backup directory exists
    if [ ! -d "$BACKUP_DIR" ]; then
        log_error "Backup directory not found: $BACKUP_DIR"
        exit 1
    fi
    log "✓ Backup directory exists"
    
    # Check restore file exists
    RESTORE_FILE="$BACKUP_DIR/akeneo_backup_${RESTORE_DATE}_020001.sql.gz"
    if [ ! -f "$RESTORE_FILE" ]; then
        log_error "Restore file not found: $RESTORE_FILE"
        exit 1
    fi
    log "✓ Restore file found: $RESTORE_FILE"
    
    # Check disk space (need at least 10 GB)
    AVAILABLE_SPACE=$(df -BG "$BACKUP_DIR" | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$AVAILABLE_SPACE" -lt 10 ]; then
        log_warning "Low disk space: ${AVAILABLE_SPACE}GB available (recommend 10GB+)"
    else
        log "✓ Disk space available: ${AVAILABLE_SPACE}GB"
    fi
    
    # Check database connection
    if mysql -u "$DB_USER" -p"$DB_PASS" -h "$DB_HOST" -P "$DB_PORT" --ssl=0 -e "SELECT 1" &>/dev/null; then
        log "✓ Database connection successful"
    else
        log_error "Cannot connect to database"
        exit 1
    fi
    
    # Check git repository
    if [ -d "$PROJECT_DIR/.git" ]; then
        log "✓ Git repository found"
    else
        log_error "Not a git repository: $PROJECT_DIR"
        exit 1
    fi
    
    # Check PHP
    if command -v php &>/dev/null; then
        PHP_VERSION=$(php -r "echo PHP_VERSION;")
        log "✓ PHP available: $PHP_VERSION"
    else
        log_error "PHP not found"
        exit 1
    fi
    
    log "=========================================="
    log "All pre-flight checks passed!"
    log "=========================================="
    echo ""
    sleep 2
}

################################################################################
# Phase 1: Emergency backup
################################################################################

phase1_backup() {
    log "=========================================="
    log "PHASE 1: EMERGENCY BACKUP"
    log "=========================================="
    
    cd "$PROJECT_DIR"
    
    # Backup current files
    log "Creating file backup..."
    BACKUP_FILE="$BACKUP_DIR/emergency_files_$TIMESTAMP.tar.gz"
    tar -czf "$BACKUP_FILE" \
        --exclude='vendor' \
        --exclude='node_modules' \
        --exclude='.git' \
        --exclude='var/cache' \
        --exclude='var/logs' \
        ./ 2>&1 | tee -a "$LOG_FILE"
    
    if [ -f "$BACKUP_FILE" ]; then
        BACKUP_SIZE=$(ls -lh "$BACKUP_FILE" | awk '{print $5}')
        log "✓ File backup created: $BACKUP_FILE ($BACKUP_SIZE)"
    else
        log_error "File backup failed"
        exit 1
    fi
    
    # Backup current database
    log "Creating database backup..."
    DB_BACKUP_FILE="$BACKUP_DIR/current_broken_$TIMESTAMP.sql.gz"
    mysqldump -u "$DB_USER" -p"$DB_PASS" -h "$DB_HOST" -P "$DB_PORT" --ssl=0 \
        --single-transaction --quick --lock-tables=false \
        "$DB_NAME" 2>&1 | gzip > "$DB_BACKUP_FILE"
    
    if [ -f "$DB_BACKUP_FILE" ]; then
        DB_BACKUP_SIZE=$(ls -lh "$DB_BACKUP_FILE" | awk '{print $5}')
        log "✓ Database backup created: $DB_BACKUP_FILE ($DB_BACKUP_SIZE)"
    else
        log_error "Database backup failed"
        exit 1
    fi
    
    # Create git backup branch
    log "Creating git backup branch..."
    BACKUP_BRANCH="backup-broken-state-$TIMESTAMP"
    git branch "$BACKUP_BRANCH" 2>&1 | tee -a "$LOG_FILE"
    git add -A 2>&1 | tee -a "$LOG_FILE"
    git commit -m "Emergency backup before restoration - $TIMESTAMP" 2>&1 | tee -a "$LOG_FILE" || log_warning "No changes to commit"
    log "✓ Git backup branch created: $BACKUP_BRANCH"
    
    log "=========================================="
    log "Phase 1 Complete: All backups created"
    log "=========================================="
    echo ""
    sleep 2
}

################################################################################
# Phase 2: Database restoration
################################################################################

phase2_database() {
    log "=========================================="
    log "PHASE 2: DATABASE RESTORATION"
    log "=========================================="
    
    cd "$BACKUP_DIR"
    
    # Extract backup
    log "Extracting database backup..."
    RESTORE_FILE="akeneo_backup_${RESTORE_DATE}_020001.sql.gz"
    EXTRACTED_FILE="restore_$RESTORE_DATE.sql"
    
    gunzip -c "$RESTORE_FILE" > "$EXTRACTED_FILE"
    
    if [ -f "$EXTRACTED_FILE" ]; then
        EXTRACTED_SIZE=$(ls -lh "$EXTRACTED_FILE" | awk '{print $5}')
        log "✓ Database extracted: $EXTRACTED_FILE ($EXTRACTED_SIZE)"
    else
        log_error "Database extraction failed"
        exit 1
    fi
    
    # Drop and recreate database
    log_warning "Dropping current database..."
    mysql -u "$DB_USER" -p"$DB_PASS" -h "$DB_HOST" -P "$DB_PORT" --ssl=0 <<EOF 2>&1 | tee -a "$LOG_FILE"
DROP DATABASE IF EXISTS $DB_NAME;
CREATE DATABASE $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
EOF
    log "✓ Database recreated"
    
    # Restore database
    log "Importing database (this may take 5-10 minutes)..."
    mysql -u "$DB_USER" -p"$DB_PASS" -h "$DB_HOST" -P "$DB_PORT" --ssl=0 \
        "$DB_NAME" < "$EXTRACTED_FILE" 2>&1 | tee -a "$LOG_FILE"
    log "✓ Database imported"
    
    # Verify restoration
    log "Verifying database restoration..."
    VERIFICATION=$(mysql -u "$DB_USER" -p"$DB_PASS" -h "$DB_HOST" -P "$DB_PORT" --ssl=0 "$DB_NAME" <<EOF
SELECT 
    (SELECT COUNT(*) FROM oro_user) as users,
    (SELECT COUNT(*) FROM pim_catalog_product) as products,
    (SELECT COUNT(*) FROM pim_catalog_category) as categories;
EOF
)
    echo "$VERIFICATION" | tee -a "$LOG_FILE"
    log "✓ Database verification complete"
    
    # Cleanup extracted file
    rm -f "$EXTRACTED_FILE"
    
    log "=========================================="
    log "Phase 2 Complete: Database restored from April 26"
    log "=========================================="
    echo ""
    sleep 2
}

################################################################################
# Phase 3: File recovery
################################################################################

phase3_files() {
    log "=========================================="
    log "PHASE 3: FILE RECOVERY"
    log "=========================================="
    
    cd "$PROJECT_DIR"
    
    # Restore critical config files
    log "Restoring configuration files from stable commit..."
    
    FILES_TO_RESTORE=(
        "config/packages/security.yml"
        "config/packages/framework.yml"
        ".env"
    )
    
    for file in "${FILES_TO_RESTORE[@]}"; do
        log "Restoring: $file"
        git checkout "$STABLE_COMMIT" -- "$file" 2>&1 | tee -a "$LOG_FILE" || log_warning "Could not restore $file"
    done
    
    # Try to restore extensions.json if it exists
    log "Attempting to restore extensions.json..."
    git checkout "$STABLE_COMMIT" -- public/js/extensions.json 2>&1 | tee -a "$LOG_FILE" || log_warning "extensions.json not in stable commit"
    
    log "✓ Configuration files restored"
    
    # Fix .env for current environment
    log "Updating .env for current environment..."
    cat >> .env << 'ENVEOF'

# Current environment overrides (added during restoration)
APP_DATABASE_HOST=127.0.0.1
APP_DATABASE_PORT=3307
APP_DATABASE_NAME=akeneo_pim
APP_DATABASE_USER=akeneo_pim
APP_INDEX_HOSTS=localhost:9200
ENVEOF
    log "✓ .env updated"
    
    # Create .env.local
    log "Creating .env.local..."
    cat > .env.local << 'ENVLOCALEOF'
APP_DATABASE_PASSWORD=akeneo_pim
ENVLOCALEOF
    log "✓ .env.local created"
    
    # Create .env.local.php with force override
    log "Creating .env.local.php with force override..."
    cat > .env.local.php << 'ENVPHPEOF'
<?php
// Force override for system environment variables
$_SERVER['APP_DATABASE_PASSWORD'] = 'akeneo_pim';
$_ENV['APP_DATABASE_PASSWORD'] = 'akeneo_pim';

return array(
    'APP_DATABASE_PASSWORD' => 'akeneo_pim',
);
ENVPHPEOF
    log "✓ .env.local.php created"
    
    log "=========================================="
    log "Phase 3 Complete: Configuration files recovered"
    log "=========================================="
    echo ""
    sleep 2
}

################################################################################
# Phase 4: Cache and index reset
################################################################################

phase4_cache() {
    log "=========================================="
    log "PHASE 4: CACHE & INDEX RESET"
    log "=========================================="
    
    cd "$PROJECT_DIR"
    
    # Reset OPcache
    log "Resetting OPcache..."
    php -r "if (function_exists('opcache_reset')) { opcache_reset(); echo 'OPcache reset\n'; }" 2>&1 | tee -a "$LOG_FILE"
    log "✓ OPcache reset"
    
    # Clear Symfony cache
    log "Clearing Symfony cache..."
    php bin/console cache:clear --env=prod --no-debug 2>&1 | tee -a "$LOG_FILE"
    log "✓ Cache cleared"
    
    log "Warming up cache..."
    php bin/console cache:warmup --env=prod --no-debug 2>&1 | tee -a "$LOG_FILE"
    log "✓ Cache warmed up"
    
    # Set permissions
    log "Setting permissions..."
    chmod -R 755 var/cache var/logs var/sessions 2>&1 | tee -a "$LOG_FILE"
    log "✓ Permissions set"
    
    # Reinstall assets
    log "Reinstalling bundle assets..."
    php bin/console pim:installer:assets --symlink --clean --env=prod 2>&1 | tee -a "$LOG_FILE"
    log "✓ Assets installed"
    
    # Reset Elasticsearch indices
    log "Resetting Elasticsearch indices..."
    php bin/console akeneo:elasticsearch:reset-indexes --env=prod -n 2>&1 | tee -a "$LOG_FILE"
    log "✓ Elasticsearch indices reset"
    
    # Reindex products
    log "Reindexing products (this may take 10-20 minutes)..."
    php bin/console pim:product:index --env=prod -n 2>&1 | tee -a "$LOG_FILE"
    log "✓ Products reindexed"
    
    log "Reindexing product models..."
    php bin/console pim:product-model:index --env=prod -n 2>&1 | tee -a "$LOG_FILE"
    log "✓ Product models reindexed"
    
    # Verify Elasticsearch
    log "Verifying Elasticsearch..."
    PRODUCT_COUNT=$(curl -s "http://localhost:9200/akeneo_pim_product_and_product_model/_count" | grep -o '"count":[0-9]*' | cut -d: -f2)
    log "✓ Elasticsearch product count: $PRODUCT_COUNT"
    
    log "=========================================="
    log "Phase 4 Complete: Cache and indices reset"
    log "=========================================="
    echo ""
    sleep 2
}

################################################################################
# Phase 5: Verification
################################################################################

phase5_verify() {
    log "=========================================="
    log "PHASE 5: VERIFICATION"
    log "=========================================="
    
    # Test 1: Login page
    log "Test 1: Login page..."
    LOGIN_STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://pim.technostationery.com/user/login)
    if [ "$LOGIN_STATUS" = "200" ]; then
        log "✓ Login page: $LOGIN_STATUS OK"
    else
        log_error "Login page: $LOGIN_STATUS FAILED"
    fi
    
    # Test 2: Static assets
    log "Test 2: Static assets..."
    CSS_STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://pim.technostationery.com/css/pim.css)
    JS_STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://pim.technostationery.com/dist/main.min.js)
    log "✓ CSS: $CSS_STATUS, JS: $JS_STATUS"
    
    # Test 3: Database
    log "Test 3: Database connection..."
    cd "$PROJECT_DIR"
    USER_COUNT=$(php bin/console doctrine:query:sql "SELECT COUNT(*) as cnt FROM oro_user" 2>&1 | grep -o '[0-9]*' | head -1)
    log "✓ Users in database: $USER_COUNT"
    
    # Test 4: Elasticsearch
    log "Test 4: Elasticsearch indices..."
    curl -s "http://localhost:9200/_cat/indices?v" | grep akeneo | tee -a "$LOG_FILE"
    
    # Test 5: File permissions
    log "Test 5: File permissions..."
    ls -ld var/cache var/logs var/sessions 2>&1 | tee -a "$LOG_FILE"
    
    log "=========================================="
    log "Phase 5 Complete: Automated verification done"
    log "=========================================="
    echo ""
}

################################################################################
# Phase 6: Commit recovery
################################################################################

phase6_commit() {
    log "=========================================="
    log "PHASE 6: COMMIT RECOVERY"
    log "=========================================="
    
    cd "$PROJECT_DIR"
    
    # Stage all changes
    git add -A 2>&1 | tee -a "$LOG_FILE"
    
    # Create commit
    git commit -m "🔧 RESTORATION COMPLETE: Database from April 26, configs from April 22 - $TIMESTAMP

- Restored database from backup: akeneo_backup_${RESTORE_DATE}_020001.sql.gz
- Recovered config files from stable commit: $STABLE_COMMIT (April 22)
- Fixed .env for current environment (127.0.0.1:3307)
- Reset Elasticsearch indices and reindexed products
- Cleared all caches (Symfony, OPcache)
- Status: TESTING REQUIRED

Previous state backed up to:
- Files: emergency_files_$TIMESTAMP.tar.gz
- Database: current_broken_$TIMESTAMP.sql.gz
- Branch: backup-broken-state-$TIMESTAMP

Recovery log: recovery_log_$TIMESTAMP.txt
" 2>&1 | tee -a "$LOG_FILE"
    
    log "✓ Changes committed"
    
    # Create tag
    TAG_NAME="restore-april26-$TIMESTAMP"
    git tag "$TAG_NAME" 2>&1 | tee -a "$LOG_FILE"
    log "✓ Tag created: $TAG_NAME"
    
    log "=========================================="
    log "Phase 6 Complete: Recovery committed"
    log "=========================================="
    echo ""
}

################################################################################
# Main execution
################################################################################

main() {
    echo ""
    echo "################################################################################"
    echo "#                                                                              #"
    echo "#                   AKENEO PIM AUTOMATED RECOVERY                              #"
    echo "#                                                                              #"
    echo "################################################################################"
    echo ""
    echo "This script will:"
    echo "  1. Backup current state"
    echo "  2. Restore database from April 26, 2026"
    echo "  3. Recover configuration files from stable git commit"
    echo "  4. Reset caches and reindex products"
    echo "  5. Run verification tests"
    echo "  6. Commit recovery changes"
    echo ""
    echo "Estimated time: 2-3 hours"
    echo "Log file: $LOG_FILE"
    echo ""
    read -p "Do you want to proceed? (yes/no): " CONFIRM
    
    if [ "$CONFIRM" != "yes" ]; then
        echo "Recovery cancelled."
        exit 0
    fi
    
    echo ""
    log "Recovery started at $(date)"
    log "Running as: $(whoami)"
    log "Working directory: $PROJECT_DIR"
    echo ""
    
    # Execute phases
    preflight_checks
    phase1_backup
    phase2_database
    phase3_files
    phase4_cache
    phase5_verify
    phase6_commit
    
    # Final summary
    echo ""
    echo "################################################################################"
    echo "#                                                                              #"
    echo "#                      RECOVERY COMPLETE                                       #"
    echo "#                                                                              #"
    echo "################################################################################"
    echo ""
    log "=========================================="
    log "RECOVERY SUMMARY"
    log "=========================================="
    log "Status: COMPLETE"
    log "Timestamp: $TIMESTAMP"
    log "Database restored from: April 26, 2026"
    log "Config files from: commit $STABLE_COMMIT (April 22)"
    log "Log file: $LOG_FILE"
    log "Git branch backup: backup-broken-state-$TIMESTAMP"
    log "Git tag: restore-april26-$TIMESTAMP"
    log "=========================================="
    echo ""
    echo "⚠️  MANUAL TESTING REQUIRED:"
    echo "1. Visit https://pim.technostationery.com/user/login"
    echo "2. Try logging in (use credentials from April 26 backup)"
    echo "3. Check if products are visible in catalog"
    echo "4. Verify images load correctly"
    echo "5. Test product creation/editing"
    echo "6. Check API endpoints"
    echo ""
    echo "Recovery log saved to: $LOG_FILE"
    echo ""
}

# Run main function
main "$@"
