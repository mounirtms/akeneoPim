#!/bin/bash
#
# Akeneo PIM Cache Manager
# Comprehensive cache management utility
# Version: 2.0 - Consolidated
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
PROJECT_ROOT="/home/pim/public_html"
CACHE_DIR="$PROJECT_ROOT/var/cache"
LOG_DIR="$PROJECT_ROOT/var/logs"

log() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

# Cache clear function
clear_cache() {
    local env="${1:-prod}"
    
    log "Clearing $env cache..."
    
    cd "$PROJECT_ROOT"
    
    # Remove cache directory
    if [[ -d "$CACHE_DIR/$env" ]]; then
        rm -rf "$CACHE_DIR/$env"
        success "Cache directory removed"
    fi
    
    # Clear Symfony cache
    php bin/console cache:clear --env=$env --no-debug 2>&1 | grep -v "Deprecated"
    
    success "$env cache cleared"
}

# Cache warmup function
warmup_cache() {
    local env="${1:-prod}"
    
    log "Warming up $env cache..."
    
    cd "$PROJECT_ROOT"
    
    # Warmup Symfony cache
    php bin/console cache:warmup --env=$env --no-debug 2>&1 | grep -v "Deprecated"
    
    # Generate RequireJS paths
    php bin/console pim:installer:dump-require-paths --env=$env 2>&1 | grep -v "Deprecated"
    
    success "$env cache warmed up"
}

# Full cache rebuild
rebuild_cache() {
    local env="${1:-prod}"
    
    log "Rebuilding $env cache..."
    
    clear_cache "$env"
    warmup_cache "$env"
    
    # Set permissions
    bash "$PROJECT_ROOT/scripts/utilities/permissions.sh" 2>/dev/null || true
    
    success "Cache rebuilt successfully"
}

# Redis cache clear
clear_redis() {
    log "Clearing Redis cache..."
    
    if command -v redis-cli &> /dev/null; then
        redis-cli FLUSHDB
        success "Redis cache cleared"
    else
        error "Redis CLI not available"
        return 1
    fi
}

# OPcache reset
reset_opcache() {
    log "Resetting OPcache..."
    
    # Create reset script
    cat > /tmp/opcache_reset.php << 'EOF'
<?php
if (function_exists('opcache_reset')) {
    opcache_reset();
    echo "OPcache reset successful\n";
} else {
    echo "OPcache not available\n";
}
EOF
    
    php /tmp/opcache_reset.php
    rm /tmp/opcache_reset.php
    
    success "OPcache reset"
}

# Show cache statistics
show_stats() {
    echo ""
    echo "═══════════════════════════════════════"
    echo "  CACHE STATISTICS"
    echo "═══════════════════════════════════════"
    echo ""
    
    # Cache directory sizes
    if [[ -d "$CACHE_DIR" ]]; then
        log "Cache directory sizes:"
        du -sh "$CACHE_DIR"/* 2>/dev/null || echo "  No cache directories"
    fi
    
    echo ""
    
    # Redis info
    if command -v redis-cli &> /dev/null; then
        log "Redis statistics:"
        redis-cli INFO stats | grep -E "keyspace_hits|keyspace_misses|used_memory_human" | sed 's/^/  /'
    fi
    
    echo ""
}

# Usage information
usage() {
    cat << EOF
Usage: $0 [command] [environment]

Commands:
    clear [env]     - Clear cache (default: prod)
    warmup [env]    - Warmup cache (default: prod)
    rebuild [env]   - Full cache rebuild (default: prod)
    redis           - Clear Redis cache
    opcache         - Reset OPcache
    stats           - Show cache statistics
    full            - Clear all caches (Symfony, Redis, OPcache)

Environments:
    prod            - Production (default)
    dev             - Development

Examples:
    $0 clear                # Clear production cache
    $0 warmup dev           # Warmup development cache
    $0 rebuild              # Full production cache rebuild
    $0 full                 # Clear all caches

EOF
}

# Main execution
main() {
    local command="${1:-help}"
    local env="${2:-prod}"
    
    case "$command" in
        clear)
            clear_cache "$env"
            ;;
        warmup)
            warmup_cache "$env"
            ;;
        rebuild)
            rebuild_cache "$env"
            ;;
        redis)
            clear_redis
            ;;
        opcache)
            reset_opcache
            ;;
        stats)
            show_stats
            ;;
        full)
            log "Clearing all caches..."
            clear_cache "$env"
            clear_redis || true
            reset_opcache || true
            warmup_cache "$env"
            success "All caches cleared"
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            error "Unknown command: $command"
            usage
            exit 1
            ;;
    esac
}

# Run
main "$@"
