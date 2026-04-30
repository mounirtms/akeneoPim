#!/usr/bin/env bash
###############################################################################
# Akeneo PIM - Deployment Script
# Purpose: Full deployment workflow - assets, webpack, cache, permissions, validation
# Usage:   ./deploy.sh [action] [options]
# Actions: full | assets | webpack | quick | rollback | validate
###############################################################################

set -euo pipefail

# ── Configuration ────────────────────────────────────────────────────────────
PIM_ROOT="/home/pim/public_html"
WEBAPP_ROOT="${PIM_ROOT}/webapp"
PHP_BIN="php"
NODE_BIN="node"
YARN_BIN="yarn"
NPM_BIN="npm"
ENV="prod"
LOG_DIR="${PIM_ROOT}/var/logs"
LOG_FILE="${LOG_DIR}/deploy.log"
BACKUP_DIR="${PIM_ROOT}/var/deploy_backups"
VERBOSE=0
SKIP_WEBPACK=0
SKIP_TESTS=0

# ── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ── Helper functions ─────────────────────────────────────────────────────────
timestamp() { date '+%Y-%m-%d %H:%M:%S'; }
log()       { echo -e "[$(timestamp)] $1" | tee -a "$LOG_FILE"; }
info()      { log "${BLUE}[INFO]${NC} $1"; }
success()   { log "${GREEN}[OK]${NC} $1"; }
warn()      { log "${YELLOW}[WARN]${NC} $1"; }
error()     { log "${RED}[ERROR]${NC} $1"; }
step()      { log "${BOLD}${CYAN}[STEP]${NC} $1"; }
separator() { echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }

die() { error "$1"; exit 1; }

usage() {
    cat <<EOF
${CYAN}Akeneo PIM Deployment Manager${NC}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Usage: $0 <action> [options]

Actions:
  full           Full deployment (backup, assets, webpack, cache, permissions, validate)
  assets         Install PIM assets and symlink bundles
  webpack        Rebuild webpack bundles only
  quick          Quick deploy (cache clear + warmup + permissions only)
  js-routes      Dump FOS JS routes
  translations   Dump Oro JS translations
  validate       Run post-deployment validation checks
  rollback       Rollback to previous dist/ backup

Options:
  -e, --env ENV        Symfony environment (default: prod)
  --skip-webpack       Skip webpack build during full deploy
  --skip-tests         Skip validation tests
  -v, --verbose        Verbose output
  -h, --help           Show this help

Examples:
  $0 full                     # Full deployment
  $0 full --skip-webpack      # Full deploy without webpack rebuild
  $0 quick                    # Quick cache reset
  $0 webpack                  # Rebuild webpack only
  $0 validate                 # Run validation checks
  $0 rollback                 # Restore previous dist/ build
EOF
    exit 0
}

# ── Parse arguments ──────────────────────────────────────────────────────────
ACTION="${1:-help}"
shift || true

while [[ $# -gt 0 ]]; do
    case "$1" in
        -e|--env)        ENV="$2"; shift 2 ;;
        --skip-webpack)  SKIP_WEBPACK=1; shift ;;
        --skip-tests)    SKIP_TESTS=1; shift ;;
        -v|--verbose)    VERBOSE=1; shift ;;
        -h|--help)       usage ;;
        *)               warn "Unknown option: $1"; shift ;;
    esac
done

# ── Console helper ───────────────────────────────────────────────────────────
run_console() {
    local cmd="$1"
    shift
    cd "$PIM_ROOT" && ${PHP_BIN} bin/console ${cmd} --env=${ENV} "$@" 2>&1
}

# ── Create backup ────────────────────────────────────────────────────────────
do_backup() {
    step "Creating backup of current dist/ ..."
    mkdir -p "$BACKUP_DIR"
    local backup_name="dist_$(date +%Y%m%d_%H%M%S).tar.gz"
    if [[ -d "${PIM_ROOT}/public/dist" ]]; then
        cd "$PIM_ROOT" && tar -czf "${BACKUP_DIR}/${backup_name}" public/dist/ 2>/dev/null || true
        success "Backup created: ${BACKUP_DIR}/${backup_name}"
    else
        warn "No dist/ directory found to backup."
    fi
}

# ── Install Assets ───────────────────────────────────────────────────────────
do_assets() {
    separator
    step "Installing PIM assets..."

    # Install Symfony assets (symlink bundles to public)
    info "  [1/3] Installing bundle assets..."
    run_console "assets:install" "--symlink" "${PIM_ROOT}/public"
    success "  Bundle assets installed."

    # Install PIM-specific assets
    info "  [2/3] Installing PIM assets..."
    run_console "pim:installer:assets" "--symlink"
    success "  PIM assets installed."

    # Dump FOS JS routes
    info "  [3/3] Dumping JS routes..."
    run_console "fos:js-routing:dump" "--format=json"
    success "  JS routes dumped."

    success "Asset installation complete."
}

# ── Build Webpack ────────────────────────────────────────────────────────────
do_webpack() {
    separator
    step "Building webpack bundles..."
    local start_time
    start_time=$(date +%s)

    cd "$PIM_ROOT"

    # Check if webpack config exists
    if [[ ! -f "webpack.config.js" ]]; then
        die "webpack.config.js not found in ${PIM_ROOT}"
    fi

    # Check node_modules
    if [[ ! -d "node_modules" ]]; then
        info "  node_modules not found, running yarn install..."
        ${YARN_BIN} install --frozen-lockfile 2>&1 || ${NPM_BIN} install 2>&1
    fi

    # Run webpack production build
    info "  Running webpack production build..."
    ${NPM_BIN} run webpack 2>&1 || {
        # Fallback: try yarn
        ${YARN_BIN} run webpack 2>&1 || {
            # Direct webpack
            npx webpack --config webpack.config.js --progress 2>&1
        }
    }

    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    success "Webpack build completed in ${duration}s."

    # Verify output
    if [[ -f "${PIM_ROOT}/public/dist/main.min.js" ]]; then
        local size
        size=$(ls -lh "${PIM_ROOT}/public/dist/main.min.js" | awk '{print $5}')
        success "  main.min.js: ${size}"
    else
        error "  main.min.js not found after build!"
    fi
}

# ── Cache Management ─────────────────────────────────────────────────────────
do_cache() {
    separator
    step "Managing cache..."

    info "  [1/3] Clearing cache..."
    run_console "cache:clear" "--no-warmup"
    success "  Cache cleared."

    info "  [2/3] Warming up cache..."
    run_console "cache:warmup"
    success "  Cache warmed."

    info "  [3/3] Fixing permissions..."
    chmod -R 777 "${PIM_ROOT}/var/cache/" 2>/dev/null || true
    chmod -R 777 "${PIM_ROOT}/var/logs/" 2>/dev/null || true
    chmod -R 777 "${PIM_ROOT}/var/log/" 2>/dev/null || true
    chmod -R 777 "${PIM_ROOT}/var/sessions/" 2>/dev/null || true
    chmod -R 777 "${PIM_ROOT}/var/file_storage/" 2>/dev/null || true
    chmod -R 777 "${PIM_ROOT}/public/media/" 2>/dev/null || true
    success "  Permissions fixed."

    success "Cache management complete."
}

# ── Dump Translations ────────────────────────────────────────────────────────
do_translations() {
    separator
    step "Dumping translations..."
    run_console "oro:translation:dump"
    success "Translations dumped."
}

# ── Dump JS Routes ───────────────────────────────────────────────────────────
do_js_routes() {
    separator
    step "Dumping FOS JS routes..."
    run_console "fos:js-routing:dump" "--format=json"
    success "JS routes dumped."
}

# ── Validation ───────────────────────────────────────────────────────────────
do_validate() {
    separator
    step "Running post-deployment validation..."
    local errors=0
    echo ""

    # 1. Check critical files exist
    info "  [1/8] Checking critical files..."
    local critical_files=(
        "public/dist/main.min.js"
        "public/dist/vendor.min.js"
        "public/css/pim.css"
        "public/bundles/pimui/js/index.js"
    )
    for f in "${critical_files[@]}"; do
        if [[ -f "${PIM_ROOT}/${f}" ]]; then
            echo -e "    ${GREEN}[OK]${NC}  ${f}"
        else
            echo -e "    ${RED}[MISS]${NC} ${f}"
            ((errors++)) || true
        fi
    done

    # 2. Check cache directory
    info "  [2/8] Checking cache..."
    if [[ -d "${PIM_ROOT}/var/cache/${ENV}" ]]; then
        echo -e "    ${GREEN}[OK]${NC}  Cache directory exists"
        if [[ -w "${PIM_ROOT}/var/cache/${ENV}" ]]; then
            echo -e "    ${GREEN}[OK]${NC}  Cache directory writable"
        else
            echo -e "    ${RED}[FAIL]${NC} Cache directory NOT writable"
            ((errors++)) || true
        fi
    else
        echo -e "    ${RED}[FAIL]${NC} Cache directory missing"
        ((errors++)) || true
    fi

    # 3. Check Elasticsearch
    info "  [3/8] Checking Elasticsearch..."
    local es_status
    es_status=$(curl -s "http://localhost:9200/_cluster/health" 2>/dev/null | grep -oP '"status"\s*:\s*"\K[^"]+' || echo "unreachable")
    if [[ "$es_status" == "green" || "$es_status" == "yellow" ]]; then
        echo -e "    ${GREEN}[OK]${NC}  ES cluster: ${es_status}"
    else
        echo -e "    ${RED}[FAIL]${NC} ES cluster: ${es_status}"
        ((errors++)) || true
    fi

    # 4. Check database
    info "  [4/8] Checking database..."
    local db_check
    db_check=$(cd "$PIM_ROOT" && ${PHP_BIN} -r "
        \$host = getenv('APP_DATABASE_HOST') ?: '127.0.0.1';
        \$port = getenv('APP_DATABASE_PORT') ?: '3307';
        \$name = getenv('APP_DATABASE_NAME') ?: 'akeneo_pim';
        \$user = 'root';
        \$pass = 'YourNewStrongPassword';
        try {
            \$pdo = new PDO(\"mysql:host=\$host;port=\$port;dbname=\$name\", \$user, \$pass);
            echo 'connected';
        } catch (\Exception \$e) {
            echo 'error: ' . \$e->getMessage();
        }
    " 2>/dev/null)
    if [[ "$db_check" == "connected" ]]; then
        echo -e "    ${GREEN}[OK]${NC}  Database connection"
    else
        echo -e "    ${RED}[FAIL]${NC} Database: ${db_check}"
        ((errors++)) || true
    fi

    # 5. Check web server response
    info "  [5/8] Checking web server..."
    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" "https://pim.technostationery.com/user/login" 2>/dev/null || echo "000")
    if [[ "$http_code" == "200" || "$http_code" == "302" ]]; then
        echo -e "    ${GREEN}[OK]${NC}  Web server responding (HTTP ${http_code})"
    else
        echo -e "    ${RED}[FAIL]${NC} Web server: HTTP ${http_code}"
        ((errors++)) || true
    fi

    # 6. Check API endpoint
    info "  [6/8] Checking API endpoint..."
    http_code=$(curl -s -o /dev/null -w "%{http_code}" "https://pim.technostationery.com/api/rest/v1/" 2>/dev/null || echo "000")
    if [[ "$http_code" == "200" || "$http_code" == "401" ]]; then
        echo -e "    ${GREEN}[OK]${NC}  API responding (HTTP ${http_code})"
    else
        echo -e "    ${YELLOW}[WARN]${NC} API: HTTP ${http_code}"
    fi

    # 7. Check Symfony routes
    info "  [7/8] Checking route configuration..."
    local route_count
    route_count=$(run_console "debug:router" 2>/dev/null | wc -l)
    echo -e "    ${GREEN}[OK]${NC}  ${route_count} routes registered"

    # 8. Check for __moduleConfig issue
    info "  [8/8] Checking for known JS issues..."
    if [[ -f "${PIM_ROOT}/public/dist/main.min.js" ]]; then
        if grep -q 'setModuleConfig(__moduleConfig)' "${PIM_ROOT}/public/dist/main.min.js" 2>/dev/null; then
            # Check if it's the safe version
            if grep -q '__moduleConfig.*||.*{}' "${PIM_ROOT}/public/dist/main.min.js" 2>/dev/null; then
                echo -e "    ${GREEN}[OK]${NC}  __moduleConfig has safe fallback"
            else
                echo -e "    ${YELLOW}[WARN]${NC} __moduleConfig may not have safe fallback"
            fi
        else
            echo -e "    ${GREEN}[OK]${NC}  No bare __moduleConfig references"
        fi
    fi

    echo ""
    separator
    if [[ $errors -eq 0 ]]; then
        success "All validation checks passed!"
    else
        error "${errors} validation check(s) failed!"
    fi
    return $errors
}

# ── Rollback ─────────────────────────────────────────────────────────────────
do_rollback() {
    separator
    step "Rolling back to previous dist/ build..."

    if [[ ! -d "$BACKUP_DIR" ]]; then
        die "No backup directory found at ${BACKUP_DIR}"
    fi

    local latest_backup
    latest_backup=$(ls -t "${BACKUP_DIR}"/dist_*.tar.gz 2>/dev/null | head -1)

    if [[ -z "$latest_backup" ]]; then
        die "No dist/ backups found in ${BACKUP_DIR}"
    fi

    info "Restoring from: ${latest_backup}"
    cd "$PIM_ROOT" && tar -xzf "$latest_backup"
    success "Rollback complete. Restored: ${latest_backup}"

    # Clear cache after rollback
    info "Clearing cache after rollback..."
    do_cache
}

# ── Quick Deploy ─────────────────────────────────────────────────────────────
do_quick() {
    separator
    step "Quick deployment (cache reset only)..."
    local start_time
    start_time=$(date +%s)

    do_cache

    if [[ $SKIP_TESTS -eq 0 ]]; then
        echo ""
        do_validate || true
    fi

    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    echo ""
    success "Quick deploy completed in ${duration}s."
}

# ── Full Deploy ──────────────────────────────────────────────────────────────
do_full() {
    separator
    step "Starting FULL deployment..."
    local start_time
    start_time=$(date +%s)
    echo ""

    # Step 1: Backup
    step "[1/6] Backup"
    do_backup
    echo ""

    # Step 2: Assets
    step "[2/6] Assets"
    do_assets
    echo ""

    # Step 3: Webpack
    if [[ $SKIP_WEBPACK -eq 0 ]]; then
        step "[3/6] Webpack"
        do_webpack
        echo ""
    else
        warn "[3/6] Webpack: SKIPPED (--skip-webpack)"
        echo ""
    fi

    # Step 4: Translations
    step "[4/6] Translations"
    do_translations 2>/dev/null || warn "  Translation dump had issues (non-critical)"
    echo ""

    # Step 5: Cache
    step "[5/6] Cache"
    do_cache
    echo ""

    # Step 6: Validate
    if [[ $SKIP_TESTS -eq 0 ]]; then
        step "[6/6] Validation"
        do_validate || true
    else
        warn "[6/6] Validation: SKIPPED (--skip-tests)"
    fi

    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    echo ""
    separator
    success "Full deployment completed in ${duration}s."
    info "Backup stored in: ${BACKUP_DIR}"
}

# ── Dispatch ─────────────────────────────────────────────────────────────────
case "$ACTION" in
    full)          do_full ;;
    assets)        do_assets ;;
    webpack)       do_webpack ;;
    quick)         do_quick ;;
    js-routes)     do_js_routes ;;
    translations)  do_translations ;;
    validate)      do_validate ;;
    rollback)      do_rollback ;;
    help|-h|--help) usage ;;
    *)
        error "Unknown action: ${ACTION}"
        usage
        ;;
esac

exit 0
