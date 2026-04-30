#!/bin/bash
# AUTOMATED OPTIMIZATION SCRIPT FOR AKENEO PIM PLATFORM
# Date: 2026-04-29
# Purpose: Apply critical performance optimizations automatically
# WARNING: Review each section before running in production

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Log file
LOG_FILE="/home/pim/public_html/webapp/logs/optimization_$(date +%Y%m%d_%H%M%S).log"
mkdir -p /home/pim/public_html/webapp/logs

# Functions
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then 
        error "This script requires sudo privileges for system modifications"
        error "Run with: sudo bash $0"
        exit 1
    fi
}

# ============================================================================
# SECTION 1: ELASTICSEARCH OPTIMIZATION
# ============================================================================
optimize_elasticsearch() {
    log "=== ELASTICSEARCH OPTIMIZATION ==="
    
    info "Checking Elasticsearch status..."
    if ! systemctl is-active --quiet elasticsearch; then
        warn "Elasticsearch is not running. Starting..."
        systemctl start elasticsearch
        sleep 10
    fi
    
    # Fix replica issue (main cause of YELLOW status)
    info "Setting replicas to 0 for single-node setup..."
    curl -X PUT "localhost:9200/_settings" -H 'Content-Type: application/json' -d'
    {
      "index": {
        "number_of_replicas": 0
      }
    }' 2>&1 | tee -a "$LOG_FILE"
    
    sleep 2
    
    # Check cluster health
    ES_STATUS=$(curl -s http://localhost:9200/_cluster/health | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
    if [ "$ES_STATUS" = "green" ]; then
        log "✅ Elasticsearch cluster is now GREEN!"
    else
        warn "Elasticsearch status: $ES_STATUS (expected GREEN)"
    fi
    
    info "Elasticsearch optimization complete"
    echo ""
}

# ============================================================================
# SECTION 2: REDIS CONFIGURATION
# ============================================================================
optimize_redis() {
    log "=== REDIS OPTIMIZATION ==="
    
    info "Checking Redis status..."
    if ! systemctl is-active --quiet redis; then
        warn "Redis is not running. Starting..."
        systemctl start redis
        sleep 3
    fi
    
    # Configure Redis memory settings
    info "Configuring Redis memory settings..."
    redis-cli CONFIG SET maxmemory 2gb 2>&1 | tee -a "$LOG_FILE"
    redis-cli CONFIG SET maxmemory-policy allkeys-lru 2>&1 | tee -a "$LOG_FILE"
    
    # Test Redis connectivity
    if redis-cli ping | grep -q "PONG"; then
        log "✅ Redis is responding correctly"
    else
        error "Redis is not responding"
        return 1
    fi
    
    info "Redis optimization complete"
    echo ""
}

# ============================================================================
# SECTION 3: AKENEO REDIS INTEGRATION
# ============================================================================
integrate_redis_akeneo() {
    log "=== AKENEO REDIS INTEGRATION ==="
    
    WEBAPP_DIR="/home/pim/public_html/webapp"
    ENV_FILE="$WEBAPP_DIR/.env.local"
    
    if [ ! -f "$ENV_FILE" ]; then
        error ".env.local not found at $ENV_FILE"
        return 1
    fi
    
    # Backup .env.local
    info "Backing up .env.local..."
    cp "$ENV_FILE" "${ENV_FILE}.backup_$(date +%Y%m%d_%H%M%S)"
    
    # Check if Redis config already exists
    if grep -q "REDIS_HOST" "$ENV_FILE"; then
        warn "Redis configuration already exists in .env.local"
    else
        info "Adding Redis configuration to .env.local..."
        cat >> "$ENV_FILE" << 'REDIS_CONF'

# Redis Configuration (added by optimization script 2026-04-29)
REDIS_HOST=127.0.0.1
REDIS_PORT=6379
REDIS_DB=0
SESSION_HANDLER=redis
SESSION_SAVE_PATH=tcp://127.0.0.1:6379/1
REDIS_CONF
        log "✅ Redis configuration added to .env.local"
    fi
    
    # Clear and warm Akeneo cache
    info "Clearing Akeneo cache..."
    cd "$WEBAPP_DIR"
    rm -rf var/cache/* 2>&1 | tee -a "$LOG_FILE"
    
    info "Warming Akeneo cache..."
    sudo -u pim bin/console cache:clear --env=prod 2>&1 | tee -a "$LOG_FILE"
    sudo -u pim bin/console cache:warmup --env=prod 2>&1 | tee -a "$LOG_FILE"
    
    log "✅ Akeneo Redis integration complete"
    echo ""
}

# ============================================================================
# SECTION 4: SYSTEM STATUS CHECK
# ============================================================================
check_system_status() {
    log "=== SYSTEM STATUS CHECK ==="
    
    # System load
    LOAD=$(uptime | awk -F'load average:' '{print $2}' | awk -F',' '{print $1}' | xargs)
    info "Current system load: $LOAD"
    
    # PHP-FPM workers
    PHP_WORKERS=$(ps aux | grep "php-fpm: pool" | grep -v grep | wc -l)
    info "PHP-FPM workers: $PHP_WORKERS"
    
    # Redis status
    REDIS_OPS=$(redis-cli INFO stats | grep instantaneous_ops_per_sec | cut -d: -f2 | tr -d '\r')
    info "Redis ops/sec: $REDIS_OPS"
    
    # Elasticsearch status
    ES_STATUS=$(curl -s http://localhost:9200/_cluster/health | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
    info "Elasticsearch status: $ES_STATUS"
    
    # MariaDB connections
    DB_CONN=$(/opt/mariadb10.6/mariadb/bin/mysql -u root -p'YourNewStrongPassword' -h 127.0.0.1 -P 3307 -e "SHOW STATUS LIKE 'Threads_connected';" 2>/dev/null | grep Threads | awk '{print $2}')
    info "MariaDB connections: ${DB_CONN:-N/A}/500"
    
    echo ""
}

# ============================================================================
# SECTION 5: PHP-FPM RECOMMENDATIONS
# ============================================================================
phpfpm_recommendations() {
    log "=== PHP-FPM RECOMMENDATIONS ==="
    
    warn "PHP-FPM is managed by cPanel and requires WHM interface changes"
    warn "Current configuration: pm=ondemand, max_children=25"
    echo ""
    info "RECOMMENDED MANUAL CHANGES via WHM:"
    echo "  1. WHM → MultiPHP Manager → FPM Settings"
    echo "  2. Domain: pim.technostationery.com"
    echo "  3. Set: pm=dynamic"
    echo "  4. Set: max_children=60"
    echo "  5. Set: start_servers=15"
    echo "  6. Set: min_spare_servers=10"
    echo "  7. Set: max_spare_servers=25"
    echo "  8. Set: max_requests=1000"
    echo ""
    info "Expected impact: 30-50% load reduction"
    echo ""
}

# ============================================================================
# SECTION 6: CREATE QUICK FIX FOR 404 ERRORS
# ============================================================================
fix_404_errors() {
    log "=== FIXING 404 ERRORS ==="
    
    WEBAPP_DIR="/home/pim/public_html/webapp"
    PUBLIC_DIR="$WEBAPP_DIR/public"
    
    # Create favicon.ico if missing
    if [ ! -f "$PUBLIC_DIR/favicon.ico" ]; then
        info "Creating placeholder favicon.ico..."
        # Create a minimal 1x1 transparent favicon
        echo "AAABAAEAAQEAAAEAIAAwAAAAFgAAACgAAAABAAAAAgAAAAEAIAAAAAAABAAAAAAAAAAAAAAAAAAAAAAAAAAAAP///wAA" | base64 -d > "$PUBLIC_DIR/favicon.ico" 2>/dev/null || touch "$PUBLIC_DIR/favicon.ico"
        chown pim:pim "$PUBLIC_DIR/favicon.ico"
        log "✅ favicon.ico created"
    else
        info "favicon.ico already exists"
    fi
    
    echo ""
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================
main() {
    clear
    echo "=========================================="
    echo "AKENEO PIM AUTOMATED OPTIMIZATION SCRIPT"
    echo "Date: $(date)"
    echo "=========================================="
    echo ""
    
    # Check if running as root
    check_root
    
    log "Starting automated optimization process..."
    log "Log file: $LOG_FILE"
    echo ""
    
    # Run optimizations
    optimize_elasticsearch
    optimize_redis
    integrate_redis_akeneo
    fix_404_errors
    phpfpm_recommendations
    check_system_status
    
    log "=========================================="
    log "OPTIMIZATION COMPLETE!"
    log "=========================================="
    echo ""
    info "Next steps:"
    echo "  1. Apply PHP-FPM changes via WHM (see recommendations above)"
    echo "  2. Monitor system for 30 minutes"
    echo "  3. Run: ./DAILY_MONITORING_SCRIPT.sh"
    echo "  4. Check load average (should decrease to <2.0)"
    echo ""
    log "Full log saved to: $LOG_FILE"
}

# Run main function
main "$@"
