#!/usr/bin/env bash
###############################################################################
# Akeneo PIM - Cache Management Script
# Purpose: Clear, warm, prune, and manage all cache layers
# Usage:   ./cache_manager.sh [action] [options]
# Actions: clear | warmup | full-reset | pool-clear | pool-prune | fix-perms | status
###############################################################################

set -euo pipefail

# ── Configuration ────────────────────────────────────────────────────────────
PIM_ROOT="/home/pim/public_html"
PHP_BIN="php"
ENV="prod"
LOG_DIR="${PIM_ROOT}/var/logs"
LOG_FILE="${LOG_DIR}/cache_manager.log"
CACHE_DIR="${PIM_ROOT}/var/cache/${ENV}"
WEB_USER="nobody"
WEB_GROUP="nobody"
VERBOSE=0

# ── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ── Helper functions ─────────────────────────────────────────────────────────
timestamp() { date '+%Y-%m-%d %H:%M:%S'; }
log()       { echo -e "[$(timestamp)] $1" | tee -a "$LOG_FILE"; }
info()      { log "${BLUE}[INFO]${NC} $1"; }
success()   { log "${GREEN}[OK]${NC} $1"; }
warn()      { log "${YELLOW}[WARN]${NC} $1"; }
error()     { log "${RED}[ERROR]${NC} $1"; }
separator() { echo -e "${CYAN}────────────────────────────────────────────────────────────${NC}"; }

usage() {
    cat <<EOF
${CYAN}Akeneo PIM Cache Manager${NC}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Usage: $0 <action> [options]

Actions:
  clear          Clear Symfony cache (no warmup)
  warmup         Warm up the cache
  full-reset     Clear + warmup + fix permissions (recommended)
  pool-clear     Clear specific or all cache pools
  pool-prune     Prune expired cache pool entries
  fix-perms      Fix cache/log directory permissions
  status         Show cache status and disk usage
  doctrine       Clear Doctrine metadata/query/result caches
  routing        Dump FOS JS routes
  translations   Dump Oro JS translations

Options:
  -e, --env ENV        Symfony environment (default: prod)
  -p, --pool POOL      Target cache pool name (for pool-clear)
  -v, --verbose        Verbose output
  -h, --help           Show this help

Examples:
  $0 full-reset
  $0 pool-clear --pool cache.app
  $0 clear --env=dev
  $0 status
EOF
    exit 0
}

# ── Parse arguments ──────────────────────────────────────────────────────────
ACTION="${1:-help}"
shift || true

POOL_NAME=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -e|--env)    ENV="$2"; shift 2 ;;
        -p|--pool)   POOL_NAME="$2"; shift 2 ;;
        -v|--verbose) VERBOSE=1; shift ;;
        -h|--help)   usage ;;
        *)           warn "Unknown option: $1"; shift ;;
    esac
done

CACHE_DIR="${PIM_ROOT}/var/cache/${ENV}"

# ── Console helper ───────────────────────────────────────────────────────────
run_console() {
    local cmd="$1"
    shift
    local full_cmd="${PHP_BIN} ${PIM_ROOT}/bin/console ${cmd} --env=${ENV} $*"
    if [[ $VERBOSE -eq 1 ]]; then
        info "Running: ${full_cmd}"
    fi
    cd "$PIM_ROOT" && eval "$full_cmd" 2>&1
}

# ── Action: Clear Cache ──────────────────────────────────────────────────────
do_clear() {
    separator
    info "Clearing Symfony cache (env: ${ENV})..."
    run_console "cache:clear" "--no-warmup"
    success "Cache cleared successfully."
}

# ── Action: Warmup ───────────────────────────────────────────────────────────
do_warmup() {
    separator
    info "Warming up cache (env: ${ENV})..."
    run_console "cache:warmup"
    success "Cache warmed up successfully."
}

# ── Action: Fix Permissions ──────────────────────────────────────────────────
do_fix_perms() {
    separator
    info "Fixing permissions on var/ and public/media..."

    chmod -R 777 "${PIM_ROOT}/var/cache/" 2>/dev/null || true
    chmod -R 777 "${PIM_ROOT}/var/logs/" 2>/dev/null || true
    chmod -R 777 "${PIM_ROOT}/var/log/" 2>/dev/null || true
    chmod -R 777 "${PIM_ROOT}/var/sessions/" 2>/dev/null || true
    chmod -R 777 "${PIM_ROOT}/var/file_storage/" 2>/dev/null || true
    chmod -R 777 "${PIM_ROOT}/public/media/" 2>/dev/null || true

    success "Permissions fixed."
}

# ── Action: Full Reset ───────────────────────────────────────────────────────
do_full_reset() {
    separator
    info "Performing FULL cache reset (clear + warmup + permissions)..."
    echo ""

    # Step 1: Clear
    info "[1/4] Clearing cache..."
    run_console "cache:clear" "--no-warmup"
    success "Cache cleared."

    # Step 2: Warmup
    info "[2/4] Warming up cache..."
    run_console "cache:warmup"
    success "Cache warmed up."

    # Step 3: Fix permissions
    info "[3/4] Fixing permissions..."
    do_fix_perms

    # Step 4: Verify
    info "[4/4] Verifying cache state..."
    if [[ -d "$CACHE_DIR" ]]; then
        local size
        size=$(du -sh "$CACHE_DIR" 2>/dev/null | awk '{print $1}')
        success "Cache directory exists: ${CACHE_DIR} (${size})"
    else
        error "Cache directory missing after warmup!"
        return 1
    fi

    echo ""
    success "Full cache reset completed successfully."
}

# ── Action: Pool Clear ───────────────────────────────────────────────────────
do_pool_clear() {
    separator
    if [[ -n "$POOL_NAME" ]]; then
        info "Clearing cache pool: ${POOL_NAME}..."
        run_console "cache:pool:clear" "$POOL_NAME"
        success "Pool '${POOL_NAME}' cleared."
    else
        info "Clearing ALL cache pools..."
        local pools
        pools=$(run_console "cache:pool:list" 2>/dev/null | grep -v "Pool name" | grep -v "^-" | grep -v "^$" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
        while IFS= read -r pool; do
            [[ -z "$pool" ]] && continue
            info "  Clearing pool: ${pool}"
            run_console "cache:pool:clear" "$pool" 2>/dev/null || warn "  Failed to clear: ${pool}"
        done <<< "$pools"
        success "All cache pools cleared."
    fi
}

# ── Action: Pool Prune ───────────────────────────────────────────────────────
do_pool_prune() {
    separator
    info "Pruning expired cache entries..."
    run_console "cache:pool:prune"
    success "Cache pools pruned."
}

# ── Action: Doctrine Cache ───────────────────────────────────────────────────
do_doctrine() {
    separator
    info "Clearing all Doctrine caches..."

    info "  Clearing metadata cache..."
    run_console "doctrine:cache:clear-metadata" 2>/dev/null || warn "  Metadata cache clear failed (may not be configured)."

    info "  Clearing query cache..."
    run_console "doctrine:cache:clear-query" 2>/dev/null || warn "  Query cache clear failed (may not be configured)."

    info "  Clearing result cache..."
    run_console "doctrine:cache:clear-result" 2>/dev/null || warn "  Result cache clear failed (may not be configured)."

    success "Doctrine caches cleared."
}

# ── Action: Dump Routing ─────────────────────────────────────────────────────
do_routing() {
    separator
    info "Dumping FOS JS routes..."
    run_console "fos:js-routing:dump" "--format=json"
    success "JS routes dumped."
}

# ── Action: Dump Translations ────────────────────────────────────────────────
do_translations() {
    separator
    info "Dumping Oro JS translations..."
    run_console "oro:translation:dump"
    success "Translations dumped."
}

# ── Action: Status ───────────────────────────────────────────────────────────
do_status() {
    separator
    info "Cache Status Report"
    echo ""

    # Cache directory size
    if [[ -d "$CACHE_DIR" ]]; then
        local size
        size=$(du -sh "$CACHE_DIR" 2>/dev/null | awk '{print $1}')
        echo -e "  ${GREEN}Cache directory:${NC} ${CACHE_DIR}"
        echo -e "  ${GREEN}Size:${NC}            ${size}"
        echo -e "  ${GREEN}Files:${NC}           $(find "$CACHE_DIR" -type f 2>/dev/null | wc -l)"
    else
        echo -e "  ${RED}Cache directory does not exist!${NC}"
    fi
    echo ""

    # Log directory
    if [[ -d "${PIM_ROOT}/var/logs" ]]; then
        local logsize
        logsize=$(du -sh "${PIM_ROOT}/var/logs" 2>/dev/null | awk '{print $1}')
        echo -e "  ${GREEN}Logs directory:${NC}  ${PIM_ROOT}/var/logs"
        echo -e "  ${GREEN}Size:${NC}            ${logsize}"
    fi
    echo ""

    # Sessions
    if [[ -d "${PIM_ROOT}/var/sessions" ]]; then
        local sess_count
        sess_count=$(find "${PIM_ROOT}/var/sessions" -type f 2>/dev/null | wc -l)
        echo -e "  ${GREEN}Sessions:${NC}        ${sess_count} files"
    fi
    echo ""

    # Cache pools
    echo -e "  ${CYAN}Registered Cache Pools:${NC}"
    run_console "cache:pool:list" 2>/dev/null | grep -v "Pool name" | grep -v "^-" | grep -v "^$" | while read -r pool; do
        echo -e "    - ${pool}"
    done
    echo ""

    # Permissions check
    echo -e "  ${CYAN}Permissions Check:${NC}"
    for dir in "${PIM_ROOT}/var/cache" "${PIM_ROOT}/var/logs" "${PIM_ROOT}/var/sessions"; do
        if [[ -w "$dir" ]]; then
            echo -e "    ${GREEN}[OK]${NC}  ${dir} (writable)"
        else
            echo -e "    ${RED}[FAIL]${NC} ${dir} (NOT writable)"
        fi
    done

    separator
}

# ── Dispatch ─────────────────────────────────────────────────────────────────
case "$ACTION" in
    clear)          do_clear ;;
    warmup)         do_warmup ;;
    full-reset)     do_full_reset ;;
    pool-clear)     do_pool_clear ;;
    pool-prune)     do_pool_prune ;;
    fix-perms)      do_fix_perms ;;
    status)         do_status ;;
    doctrine)       do_doctrine ;;
    routing)        do_routing ;;
    translations)   do_translations ;;
    help|-h|--help) usage ;;
    *)
        error "Unknown action: ${ACTION}"
        usage
        ;;
esac

exit 0
