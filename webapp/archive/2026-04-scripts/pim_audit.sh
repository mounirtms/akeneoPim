#!/bin/bash
# ============================================================================
# Akeneo PIM Comprehensive Audit & Fix Script
# Date: April 21, 2026
# Purpose: Audit PIM installation, identify issues, and apply fixes
# ============================================================================

set -e

PIM_DIR="/home/pim/public_html"
LOG_DIR="$PIM_DIR/var/logs"
AUDIT_LOG="$PIM_DIR/pim_audit_$(date +%Y%m%d_%H%M%S).log"
BACKUP_DIR="$PIM_DIR/backups/audit_$(date +%Y%m%d_%H%M%S)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$AUDIT_LOG"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$AUDIT_LOG"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$AUDIT_LOG"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$AUDIT_LOG"
}

# ============================================================================
# SECTION 1: ENVIRONMENT AUDIT
# ============================================================================

audit_environment() {
    log "=== SECTION 1: ENVIRONMENT AUDIT ==="
    
    cd "$PIM_DIR" || exit 1
    
    # Check PHP version
    info "PHP Version:"
    php -v | head -1 | tee -a "$AUDIT_LOG"
    
    # Check required PHP extensions
    info "Checking PHP extensions..."
    REQUIRED_EXTENSIONS=("pdo_mysql" "gd" "intl" "opcache" "apcu" "bcmath" "xml" "zip" "curl" "mbstring" "json")
    
    for ext in "${REQUIRED_EXTENSIONS[@]}"; do
        if php -m | grep -q "$ext"; then
            log "  ✓ $ext: INSTALLED"
        else
            error "  ✗ $ext: MISSING"
        fi
    done
    
    # Check Composer
    info "Composer version:"
    if [ -f "composer.phar" ]; then
        php composer.phar --version | tee -a "$AUDIT_LOG"
    else
        warn "Composer not found"
    fi
    
    # Check Node/npm (if needed)
    info "Node.js version:"
    node --version 2>/dev/null | tee -a "$AUDIT_LOG" || warn "Node.js not installed"
    
    # Check disk space
    info "Disk usage:"
    df -h "$PIM_DIR" | tee -a "$AUDIT_LOG"
    
    echo "" >> "$AUDIT_LOG"
}

# ============================================================================
# SECTION 2: DATABASE AUDIT
# ============================================================================

audit_database() {
    log "=== SECTION 2: DATABASE AUDIT ==="
    
    # Extract DB credentials from .env
    DB_HOST=$(grep "APP_DATABASE_HOST" .env | cut -d'=' -f2)
    DB_PORT=$(grep "APP_DATABASE_PORT" .env | cut -d'=' -f2)
    DB_NAME=$(grep "APP_DATABASE_NAME" .env | cut -d'=' -f2)
    DB_USER=$(grep "APP_DATABASE_USER" .env | cut -d'=' -f2)
    DB_PASS=$(grep "APP_DATABASE_PASSWORD" .env | cut -d'=' -f2)
    
    info "Database: $DB_NAME on $DB_HOST:$DB_PORT"
    
    # Test database connection
    if mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" -e "USE $DB_NAME; SELECT 1;" 2>/dev/null; then
        log "✓ Database connection: SUCCESS"
        
        # Check table count
        TABLE_COUNT=$(mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" -D "$DB_NAME" -sN -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$DB_NAME';")
        info "Total tables: $TABLE_COUNT"
        
        # Check oro_user table issue
        info "Checking oro_user table..."
        mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" -D "$DB_NAME" -e "SHOW TABLE STATUS LIKE 'oro_user'\\G" | tee -a "$AUDIT_LOG"
        
        # Check database size
        DB_SIZE=$(mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" -D "$DB_NAME" -sN -e "SELECT ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size_MB' FROM information_schema.tables WHERE table_schema='$DB_NAME';")
        info "Database size: ${DB_SIZE}MB"
        
    else
        error "✗ Database connection: FAILED"
    fi
    
    echo "" >> "$AUDIT_LOG"
}

# ============================================================================
# SECTION 3: LOG FILES AUDIT
# ============================================================================

audit_logs() {
    log "=== SECTION 3: LOG FILES AUDIT ==="
    
    # Check main error log
    if [ -f "$PIM_DIR/error_log" ]; then
        ERROR_LOG_SIZE=$(du -h "$PIM_DIR/error_log" | cut -f1)
        warn "Main error_log size: $ERROR_LOG_SIZE"
        
        # Count error types
        info "Recent error patterns (last 1000 lines):"
        tail -1000 "$PIM_DIR/error_log" | grep -oP 'PHP \K\w+' | sort | uniq -c | sort -rn | head -10 | tee -a "$AUDIT_LOG"
    fi
    
    # Check Akeneo logs
    if [ -d "$LOG_DIR" ]; then
        info "Akeneo log files:"
        du -sh "$LOG_DIR"/* 2>/dev/null | sort -rh | head -10 | tee -a "$AUDIT_LOG"
        
        # Check for errors in prod.log
        if [ -f "$LOG_DIR/prod.log" ]; then
            info "Recent prod.log errors:"
            tail -100 "$LOG_DIR/prod.log" | grep -i "error\|exception\|critical" | tail -5 | tee -a "$AUDIT_LOG"
        fi
    fi
    
    echo "" >> "$AUDIT_LOG"
}

# ============================================================================
# SECTION 4: CONFIGURATION AUDIT
# ============================================================================

audit_configuration() {
    log "=== SECTION 4: CONFIGURATION AUDIT ==="
    
    # Check .env file
    info ".env configuration:"
    grep -E "^APP_ENV|^APP_DEBUG|^APP_DATABASE|^APP_INDEX|^MAILER_URL|^APP_SECRET" .env | tee -a "$AUDIT_LOG"
    
    # Check if APP_SECRET is default
    if grep -q "ThisTokenIsNotSoSecretChangeIt" .env; then
        error "✗ APP_SECRET is using default value - SECURITY RISK!"
    else
        log "✓ APP_SECRET is customized"
    fi
    
    # Check Elasticsearch configuration
    ES_HOSTS=$(grep "APP_INDEX_HOSTS" .env | cut -d'=' -f2)
    info "Elasticsearch hosts: $ES_HOSTS"
    
    # Test Elasticsearch connection
    if curl -s "http://$ES_HOSTS" > /dev/null; then
        log "✓ Elasticsearch connection: SUCCESS"
    else
        error "✗ Elasticsearch connection: FAILED"
    fi
    
    # Check mailer configuration
    MAILER_URL=$(grep "MAILER_URL" .env | cut -d'=' -f2)
    if [[ "$MAILER_URL" == "null://localhost"* ]]; then
        warn "Mailer is configured as null - emails won't be sent"
    fi
    
    echo "" >> "$AUDIT_LOG"
}

# ============================================================================
# SECTION 5: PERMISSIONS AUDIT
# ============================================================================

audit_permissions() {
    log "=== SECTION 5: PERMISSIONS AUDIT ==="
    
    # Check critical directories
    CRITICAL_DIRS=("var/cache" "var/logs" "var/uploads" "public/media")
    
    for dir in "${CRITICAL_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            PERMS=$(stat -c "%a" "$dir")
            OWNER=$(stat -c "%U:%G" "$dir")
            info "$dir: $PERMS ($OWNER)"
        else
            warn "$dir: NOT FOUND"
        fi
    done
    
    echo "" >> "$AUDIT_LOG"
}

# ============================================================================
# SECTION 6: IDENTIFY SPECIFIC ISSUES
# ============================================================================

identify_issues() {
    log "=== SECTION 6: IDENTIFIED ISSUES ==="
    
    ISSUES_FOUND=0
    
    # Issue 1: Analytics endpoint error
    if grep -q "collect_data.*500" "$LOG_DIR/prod.log" 2>/dev/null; then
        error "Issue #1: Analytics collect_data endpoint returning 500 error"
        ((ISSUES_FOUND++))
    fi
    
    # Issue 2: Function() native code error
    if grep -q "function%20()%20%7B%20%5Bnative%20code%5D%20%7D" "$LOG_DIR/prod.log" 2>/dev/null; then
        error "Issue #2: JavaScript error - invalid URL with 'function() { [native code] }'"
        ((ISSUES_FOUND++))
    fi
    
    # Issue 3: DateTime deprecation
    if grep -q "DateTime::__construct.*deprecated" "$PIM_DIR/error_log" 2>/dev/null; then
        error "Issue #3: Monolog DateTime deprecation warnings (filling error log)"
        ((ISSUES_FOUND++))
    fi
    
    # Issue 4: oro_user CREATE_TIME issue
    if grep -q "UnavailableCreationTimeException.*oro_user" "$LOG_DIR/prod.log" 2>/dev/null; then
        error "Issue #4: CREATE_TIME not available for oro_user table"
        ((ISSUES_FOUND++))
    fi
    
    # Issue 5: Authentication errors
    if grep -q "Full authentication is required" "$LOG_DIR/prod.log" 2>/dev/null; then
        error "Issue #5: Authentication errors detected"
        ((ISSUES_FOUND++))
    fi
    
    # Issue 6: Large error log
    if [ -f "$PIM_DIR/error_log" ]; then
        ERROR_LOG_SIZE_MB=$(du -m "$PIM_DIR/error_log" | cut -f1)
        if [ "$ERROR_LOG_SIZE_MB" -gt 50 ]; then
            error "Issue #6: Error log is very large (${ERROR_LOG_SIZE_MB}MB)"
            ((ISSUES_FOUND++))
        fi
    fi
    
    info "Total issues found: $ISSUES_FOUND"
    echo "" >> "$AUDIT_LOG"
}

# ============================================================================
# SECTION 7: RECOMMENDATIONS
# ============================================================================

generate_recommendations() {
    log "=== SECTION 7: RECOMMENDATIONS ==="
    
    cat << EOF | tee -a "$AUDIT_LOG"

IMMEDIATE FIXES REQUIRED:
1. Clear and rotate error logs (138MB error_log)
2. Fix Monolog DateTime deprecation in vendor/monolog
3. Fix analytics authentication issue
4. Update APP_SECRET in .env
5. Fix forgot password email configuration

CONFIGURATION IMPROVEMENTS:
1. Configure proper SMTP mailer (currently null)
2. Verify Elasticsearch health and optimize
3. Fix oro_user table CREATE_TIME issue
4. Clear Symfony cache
5. Update JavaScript polyfills

OPTIMIZATION RECOMMENDATIONS:
1. Enable OPcache optimization
2. Configure proper log rotation
3. Set up cron job monitoring
4. Implement database query optimization
5. Review and optimize Elasticsearch indices

SECURITY HARDENING:
1. Change APP_SECRET from default value
2. Review user permissions
3. Enable HTTPS for all endpoints
4. Configure proper CORS headers
5. Set up database backup automation

MAGENTO INTEGRATION:
1. Install/Configure Akeneo Connector for Magento 2
2. Set up API credentials
3. Configure product sync schedule
4. Test attribute mapping
5. Verify image sync configuration

EOF

    echo "" >> "$AUDIT_LOG"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    log "Starting Akeneo PIM Comprehensive Audit"
    log "Audit log: $AUDIT_LOG"
    log "=========================================="
    echo ""
    
    audit_environment
    audit_database
    audit_logs
    audit_configuration
    audit_permissions
    identify_issues
    generate_recommendations
    
    log "=========================================="
    log "Audit completed successfully!"
    log "Review the full audit log at: $AUDIT_LOG"
    log ""
    log "Next steps:"
    log "1. Run: ./pim_fix_immediate.sh (for immediate fixes)"
    log "2. Run: ./pim_optimize.sh (for optimizations)"
    log "3. Review: $AUDIT_LOG (for detailed findings)"
}

# Run audit
main
