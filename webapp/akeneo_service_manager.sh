#!/bin/bash
#
# Akeneo PIM Service Management Script
# Manages all Akeneo PIM related services and monitoring
#
# Date: 2026-04-30
# Repository: https://github.com/mounirtms/akeneoPim.git
# Branch: oldbranch

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIM_DIR="/home/pim/public_html"
LOG_DIR="$PIM_DIR/var/logs"
BACKUP_DIR="$PIM_DIR/backups"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check Redis service
check_redis() {
    log_info "Checking Redis service..."
    if redis-cli ping &>/dev/null; then
        log_success "Redis is running"
        redis-cli INFO server | grep redis_version
        return 0
    else
        log_error "Redis is not running"
        return 1
    fi
}

# Check MariaDB service
check_mariadb() {
    log_info "Checking MariaDB service..."
    if mysqladmin -h 127.0.0.1 -P 3307 -u root -p"YourNewStrongPassword" ping &>/dev/null; then
        log_success "MariaDB is running"
        mysql -h 127.0.0.1 -P 3307 -u root -p"YourNewStrongPassword" -e "SELECT VERSION();" 2>/dev/null
        return 0
    else
        log_error "MariaDB is not running"
        return 1
    fi
}

# Check Elasticsearch service
check_elasticsearch() {
    log_info "Checking Elasticsearch service..."
    if curl -s http://localhost:9200/_cluster/health &>/dev/null; then
        log_success "Elasticsearch is running"
        curl -s http://localhost:9200/_cluster/health?pretty | grep -E "(status|cluster_name)"
        return 0
    else
        log_error "Elasticsearch is not running"
        return 1
    fi
}

# Check cache status
check_cache() {
    log_info "Checking cache status..."
    
    # File cache
    if [ -d "$PIM_DIR/var/cache/prod" ]; then
        CACHE_SIZE=$(du -sh "$PIM_DIR/var/cache/prod" 2>/dev/null | cut -f1)
        CACHE_FILES=$(find "$PIM_DIR/var/cache/prod" -type f 2>/dev/null | wc -l)
        log_info "File cache: $CACHE_SIZE ($CACHE_FILES files)"
    fi
    
    # Redis cache
    if redis-cli ping &>/dev/null; then
        for db in {1..5}; do
            KEYS=$(redis-cli -n $db DBSIZE 2>/dev/null)
            if [ "$KEYS" != "0" ]; then
                log_info "Redis DB$db: $KEYS keys"
            fi
        done
    fi
}

# Clear cache
clear_cache() {
    log_info "Clearing Akeneo cache..."
    cd "$PIM_DIR"
    
    # Backup current cache
    if [ -d "var/cache/prod" ]; then
        BACKUP_NAME="cache_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
        tar -czf "$BACKUP_DIR/$BACKUP_NAME" var/cache/prod 2>/dev/null || true
        log_info "Cache backed up to $BACKUP_NAME"
    fi
    
    # Clear Symfony cache
    php bin/console cache:clear --env=prod --no-warmup
    
    # Clear Redis cache if available
    if redis-cli ping &>/dev/null; then
        for db in {1..5}; do
            redis-cli -n $db FLUSHDB &>/dev/null || true
        done
        log_success "Redis cache cleared"
    fi
    
    # Warmup cache
    php bin/console cache:warmup --env=prod
    
    log_success "Cache cleared and warmed up"
}

# Check system health
check_health() {
    log_info "=== Akeneo PIM Health Check ==="
    echo ""
    
    # Services
    log_info "Services Status:"
    check_redis || true
    check_mariadb || true
    check_elasticsearch || true
    echo ""
    
    # Cache
    check_cache
    echo ""
    
    # Disk space
    log_info "Disk Usage:"
    df -h "$PIM_DIR" | tail -1
    echo ""
    
    # Memory
    log_info "Memory Usage:"
    free -h | grep -E "^Mem:"
    echo ""
    
    # Load average
    log_info "System Load:"
    uptime
    echo ""
    
    # Recent errors
    log_info "Recent Errors (last 10):"
    if [ -f "$LOG_DIR/prod.log" ]; then
        grep -i error "$LOG_DIR/prod.log" 2>/dev/null | tail -10 || echo "No errors found"
    else
        echo "Log file not found"
    fi
}

# Database backup
backup_database() {
    log_info "Creating database backup..."
    
    mkdir -p "$BACKUP_DIR"
    BACKUP_FILE="$BACKUP_DIR/akeneo_db_$(date +%Y%m%d_%H%M%S).sql.gz"
    
    if mysqldump -h 127.0.0.1 -P 3307 -u root -p"YourNewStrongPassword" \
        akeneo_pim \
        --single-transaction \
        --quick \
        --lock-tables=false \
        2>/dev/null | gzip > "$BACKUP_FILE"; then
        
        BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
        log_success "Database backup created: $(basename $BACKUP_FILE) ($BACKUP_SIZE)"
        
        # Keep only last 7 backups
        ls -t "$BACKUP_DIR"/akeneo_db_*.sql.gz 2>/dev/null | tail -n +8 | xargs -r rm
        log_info "Old backups cleaned (keeping last 7)"
    else
        log_error "Database backup failed"
        return 1
    fi
}

# Full system backup
backup_full() {
    log_info "Creating full system backup..."
    
    mkdir -p "$BACKUP_DIR"
    BACKUP_FILE="$BACKUP_DIR/akeneo_full_$(date +%Y%m%d_%H%M%S).tar.gz"
    
    cd "$PIM_DIR"
    tar -czf "$BACKUP_FILE" \
        --exclude='var/cache/*' \
        --exclude='var/logs/*' \
        --exclude='vendor/*' \
        --exclude='node_modules/*' \
        --exclude='backups/*' \
        config/ \
        public/ \
        src/ \
        templates/ \
        .env \
        composer.json \
        composer.lock \
        2>/dev/null || true
    
    BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    log_success "Full backup created: $(basename $BACKUP_FILE) ($BACKUP_SIZE)"
}

# Elasticsearch reindex
reindex_elasticsearch() {
    log_info "Reindexing Elasticsearch..."
    cd "$PIM_DIR"
    
    php bin/console akeneo:elasticsearch:reset-indexes --env=prod
    php bin/console pim:product-model:index --all --env=prod
    php bin/console pim:product:index --all --env=prod
    
    log_success "Elasticsearch reindexing completed"
}

# Show usage
show_usage() {
    cat << EOF
Akeneo PIM Service Management Script

Usage: $0 [command]

Commands:
    health              Check system health
    redis              Check Redis status
    mariadb            Check MariaDB status
    elasticsearch      Check Elasticsearch status
    cache              Show cache status
    clear-cache        Clear all caches
    backup-db          Backup database
    backup-full        Full system backup
    reindex            Reindex Elasticsearch
    monitor            Run continuous monitoring
    help               Show this help

Examples:
    $0 health          # Run health check
    $0 clear-cache     # Clear all caches
    $0 backup-db       # Backup database

EOF
}

# Monitor mode
monitor_mode() {
    log_info "Starting monitoring mode (Ctrl+C to stop)..."
    
    while true; do
        clear
        echo "=== Akeneo PIM Monitor - $(date) ==="
        echo ""
        check_health
        echo ""
        log_info "Refreshing in 30 seconds..."
        sleep 30
    done
}

# Main
case "${1:-help}" in
    health)
        check_health
        ;;
    redis)
        check_redis
        ;;
    mariadb)
        check_mariadb
        ;;
    elasticsearch)
        check_elasticsearch
        ;;
    cache)
        check_cache
        ;;
    clear-cache)
        clear_cache
        ;;
    backup-db)
        backup_database
        ;;
    backup-full)
        backup_full
        ;;
    reindex)
        reindex_elasticsearch
        ;;
    monitor)
        monitor_mode
        ;;
    help|--help|-h)
        show_usage
        ;;
    *)
        log_error "Unknown command: $1"
        show_usage
        exit 1
        ;;
esac

exit 0
