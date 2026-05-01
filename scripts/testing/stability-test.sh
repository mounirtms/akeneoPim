#!/bin/bash
#
# Akeneo PIM Comprehensive Stability Test
# Consolidated from multiple test scripts
# Version: 2.0 - Optimized & Cleaned
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
BASE_URL="${PIM_URL:-https://pim.technostationery.com}"
PROJECT_ROOT="/home/pim/public_html"
LOG_FILE="$PROJECT_ROOT/var/logs/stability_test_$(date +%Y%m%d_%H%M%S).log"

# Test credentials
TEST_USER="${PIM_USER:-testfix}"
TEST_PASS="${PIM_PASS:-Admin@123}"

# Counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Functions
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}✅ $1${NC}" | tee -a "$LOG_FILE"
    ((PASSED_TESTS++))
}

error() {
    echo -e "${RED}❌ $1${NC}" | tee -a "$LOG_FILE"
    ((FAILED_TESTS++))
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}" | tee -a "$LOG_FILE"
}

test_http_status() {
    local url="$1"
    local expected="${2:-200}"
    local description="$3"
    
    ((TOTAL_TESTS++))
    
    local status=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
    
    if [[ "$status" == "$expected" ]]; then
        success "$description - HTTP $status"
        return 0
    else
        error "$description - Expected $expected, got $status"
        return 1
    fi
}

test_service() {
    local service="$1"
    local description="$2"
    
    ((TOTAL_TESTS++))
    
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        success "$description - Service running"
        return 0
    else
        error "$description - Service not running"
        return 1
    fi
}

test_database() {
    ((TOTAL_TESTS++))
    
    log "Testing database connection..."
    
    if mariadb -h 127.0.0.1 -P 3307 -u akeneo_pim -pakeneo_pim akeneo_pim --ssl=0 -e "SELECT 1" >/dev/null 2>&1; then
        success "Database connection"
        
        # Count products
        local product_count=$(mariadb -h 127.0.0.1 -P 3307 -u akeneo_pim -pakeneo_pim akeneo_pim --ssl=0 -N -e "SELECT COUNT(*) FROM pim_catalog_product" 2>/dev/null || echo "0")
        log "  → Products in database: $product_count"
        
        # Count users
        local user_count=$(mariadb -h 127.0.0.1 -P 3307 -u akeneo_pim -pakeneo_pim akeneo_pim --ssl=0 -N -e "SELECT COUNT(*) FROM oro_user WHERE enabled=1" 2>/dev/null || echo "0")
        log "  → Active users: $user_count"
        
        return 0
    else
        error "Database connection"
        return 1
    fi
}

test_cache() {
    ((TOTAL_TESTS++))
    
    log "Testing cache system..."
    
    if [[ -d "$PROJECT_ROOT/var/cache/prod" ]]; then
        success "Cache directory exists"
        
        local cache_size=$(du -sh "$PROJECT_ROOT/var/cache/prod" 2>/dev/null | cut -f1)
        log "  → Cache size: $cache_size"
        
        return 0
    else
        error "Cache directory missing"
        return 1
    fi
}

test_elasticsearch() {
    ((TOTAL_TESTS++))
    
    log "Testing Elasticsearch..."
    
    if curl -s http://127.0.0.1:9200/_cluster/health >/dev/null 2>&1; then
        success "Elasticsearch responding"
        
        local doc_count=$(curl -s "http://127.0.0.1:9200/_cat/indices?v" 2>/dev/null | grep akeneo | awk '{sum+=$7} END {print sum}' || echo "0")
        log "  → Indexed documents: $doc_count"
        
        return 0
    else
        warning "Elasticsearch not responding (may be disabled)"
        return 0
    fi
}

test_static_assets() {
    log "Testing static assets..."
    
    test_http_status "$BASE_URL/css/pim.css" "200" "PIM CSS"
    test_http_status "$BASE_URL/dist/jquery.min.js" "200" "jQuery"
    test_http_status "$BASE_URL/dist/backbone.min.js" "200" "Backbone"
    test_http_status "$BASE_URL/dist/underscore.min.js" "200" "Underscore"
    test_http_status "$BASE_URL/dist/require.min.js" "200" "RequireJS"
}

test_login() {
    ((TOTAL_TESTS++))
    
    log "Testing login page..."
    
    local response=$(curl -s "$BASE_URL/user/login" 2>/dev/null)
    
    if echo "$response" | grep -q "Connexion\|Login"; then
        success "Login page loads"
        return 0
    else
        error "Login page not loading correctly"
        return 1
    fi
}

test_system_resources() {
    log "Checking system resources..."
    
    # CPU Load
    local load=$(uptime | awk -F'load average:' '{print $2}' | cut -d',' -f1 | xargs)
    log "  → CPU Load: $load"
    
    # Memory
    local mem_used=$(free -h | awk '/^Mem:/ {print $3}')
    local mem_total=$(free -h | awk '/^Mem:/ {print $2}')
    log "  → Memory: $mem_used / $mem_total"
    
    # Disk
    local disk_used=$(df -h "$PROJECT_ROOT" | awk 'NR==2 {print $3}')
    local disk_total=$(df -h "$PROJECT_ROOT" | awk 'NR==2 {print $2}')
    log "  → Disk: $disk_used / $disk_total"
    
    # Check if load is too high
    if (( $(echo "$load > 10" | bc -l) )); then
        warning "High CPU load: $load"
    fi
}

# Main execution
main() {
    clear
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║       AKENEO PIM COMPREHENSIVE STABILITY TEST              ║"
    echo "║                  Version 2.0 - Optimized                   ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    
    log "Starting stability tests..."
    log "Base URL: $BASE_URL"
    log "Log file: $LOG_FILE"
    echo ""
    
    # System Resources
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo " 📊 SYSTEM RESOURCES"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    test_system_resources
    echo ""
    
    # Services
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo " 🔧 SERVICES"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    test_service "mariadb" "MariaDB"
    test_service "redis" "Redis"
    test_service "nginx" "Nginx"
    echo ""
    
    # Database
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo " 💾 DATABASE"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    test_database
    echo ""
    
    # Cache
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo " 🗄️  CACHE"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    test_cache
    echo ""
    
    # Elasticsearch
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo " 🔍 ELASTICSEARCH"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    test_elasticsearch
    echo ""
    
    # Web Interface
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo " 🌐 WEB INTERFACE"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    test_login
    test_http_status "$BASE_URL" "302" "Homepage (redirect)"
    echo ""
    
    # Static Assets
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo " 📦 STATIC ASSETS"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    test_static_assets
    echo ""
    
    # Summary
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo " 📋 TEST SUMMARY"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Total Tests:    $TOTAL_TESTS"
    echo -e "Passed:         ${GREEN}$PASSED_TESTS${NC}"
    echo -e "Failed:         ${RED}$FAILED_TESTS${NC}"
    
    if [[ $FAILED_TESTS -eq 0 ]]; then
        echo ""
        success "ALL TESTS PASSED - SYSTEM STABLE"
        echo ""
        echo "✅ Akeneo PIM is fully operational"
        echo "🔗 Access: $BASE_URL"
        echo "👤 User: $TEST_USER"
        echo ""
    else
        echo ""
        error "SOME TESTS FAILED - REVIEW REQUIRED"
        echo ""
        echo "📝 Check log: $LOG_FILE"
        echo ""
    fi
    
    # Success rate
    local success_rate=$(( PASSED_TESTS * 100 / TOTAL_TESTS ))
    echo "Success Rate: ${success_rate}%"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    return $FAILED_TESTS
}

# Run main
main
exit $?
