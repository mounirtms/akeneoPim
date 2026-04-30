#!/usr/bin/env bash
###############################################################################
# Akeneo PIM - Elasticsearch Indexing Manager
# Purpose: Manage ES indexes - reindex products, product models, reset, update mappings
# Usage:   ./es_manager.sh [action] [options]
# Actions: index-products | index-models | index-all | reset | update-mapping | status | health
###############################################################################

set -euo pipefail

# ── Configuration ────────────────────────────────────────────────────────────
PIM_ROOT="/home/pim/public_html"
PHP_BIN="php"
ENV="prod"
ES_HOST="${APP_INDEX_HOSTS:-localhost:9200}"
LOG_DIR="${PIM_ROOT}/var/logs"
LOG_FILE="${LOG_DIR}/elasticsearch_manager.log"
VERBOSE=0
BATCH_SIZE=500
IDS=""

# ── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

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
${CYAN}Akeneo PIM Elasticsearch Manager${NC}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Usage: $0 <action> [options]

Actions:
  index-products    Index all products into Elasticsearch
  index-models      Index all product models into Elasticsearch
  index-all         Index both products and product models
  reset             Reset all ES indexes (destructive!)
  update-mapping    Update ES index mappings
  update-limit      Update total fields limit
  status            Show ES index status and document counts
  health            Check Elasticsearch cluster health
  query             Run a test query against product index

Options:
  -e, --env ENV          Symfony environment (default: prod)
  -i, --ids IDS          Comma-separated product IDs to index
  -b, --batch-size N     Batch size for indexing (default: 500)
  -v, --verbose          Verbose output
  --force                Skip confirmation for destructive operations
  -h, --help             Show this help

Examples:
  $0 index-all
  $0 index-products --ids 1,2,3
  $0 reset --force
  $0 status
  $0 health
EOF
    exit 0
}

# ── Parse arguments ──────────────────────────────────────────────────────────
ACTION="${1:-help}"
shift || true

FORCE=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        -e|--env)        ENV="$2"; shift 2 ;;
        -i|--ids)        IDS="$2"; shift 2 ;;
        -b|--batch-size) BATCH_SIZE="$2"; shift 2 ;;
        -v|--verbose)    VERBOSE=1; shift ;;
        --force)         FORCE=1; shift ;;
        -h|--help)       usage ;;
        *)               warn "Unknown option: $1"; shift ;;
    esac
done

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

# ── Confirm destructive actions ──────────────────────────────────────────────
confirm() {
    if [[ $FORCE -eq 1 ]]; then return 0; fi
    local msg="$1"
    echo -en "${YELLOW}${msg} [y/N]: ${NC}"
    read -r answer
    [[ "$answer" =~ ^[Yy]$ ]]
}

# ── Action: Index Products ───────────────────────────────────────────────────
do_index_products() {
    separator
    info "Indexing products into Elasticsearch..."
    local start_time
    start_time=$(date +%s)

    local extra_args=""
    if [[ -n "$IDS" ]]; then
        extra_args="${IDS}"
        info "Indexing specific products: ${IDS}"
    else
        extra_args="--all"
        info "Indexing ALL products (this may take a while)..."
    fi

    run_console "pim:product:index" "$extra_args"

    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    success "Product indexing completed in ${duration}s."
}

# ── Action: Index Product Models ─────────────────────────────────────────────
do_index_models() {
    separator
    info "Indexing product models into Elasticsearch..."
    local start_time
    start_time=$(date +%s)

    local extra_args=""
    if [[ -n "$IDS" ]]; then
        extra_args="${IDS}"
        info "Indexing specific product models: ${IDS}"
    else
        extra_args="--all"
        info "Indexing ALL product models..."
    fi

    run_console "pim:product-model:index" "$extra_args"

    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    success "Product model indexing completed in ${duration}s."
}

# ── Action: Index All ────────────────────────────────────────────────────────
do_index_all() {
    separator
    info "Full reindex: products + product models..."
    local start_time
    start_time=$(date +%s)

    do_index_products
    echo ""
    do_index_models

    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    echo ""
    success "Full reindex completed in ${duration}s."
}

# ── Action: Reset Indexes ────────────────────────────────────────────────────
do_reset() {
    separator
    warn "This will RESET ALL Elasticsearch indexes!"
    warn "All indexed data will be lost and must be re-indexed."

    if ! confirm "Are you sure you want to reset all ES indexes?"; then
        info "Reset cancelled."
        return 0
    fi

    info "Resetting all Elasticsearch indexes..."
    run_console "akeneo:elasticsearch:reset-indexes"
    success "All ES indexes have been reset."
    echo ""
    warn "You must now re-index all data:"
    echo "  $0 index-all"
}

# ── Action: Update Mapping ───────────────────────────────────────────────────
do_update_mapping() {
    separator
    info "Updating Elasticsearch index mappings..."
    run_console "akeneo:elasticsearch:update-mapping"
    success "ES mappings updated."
}

# ── Action: Update Total Fields Limit ────────────────────────────────────────
do_update_limit() {
    separator
    info "Updating Elasticsearch total fields limit..."
    run_console "akeneo:elasticsearch:update-total-fields-limit"
    success "Total fields limit updated."
}

# ── Action: Status ───────────────────────────────────────────────────────────
do_status() {
    separator
    info "Elasticsearch Index Status"
    echo ""

    echo -e "  ${CYAN}Cluster Health:${NC}"
    local health
    health=$(curl -s "http://${ES_HOST}/_cluster/health" 2>/dev/null || echo '{"status":"unreachable"}')
    local status
    status=$(echo "$health" | grep -oP '"status"\s*:\s*"\K[^"]+' || echo "unknown")
    case "$status" in
        green)  echo -e "    Status: ${GREEN}${status}${NC}" ;;
        yellow) echo -e "    Status: ${YELLOW}${status}${NC}" ;;
        red)    echo -e "    Status: ${RED}${status}${NC}" ;;
        *)      echo -e "    Status: ${RED}${status}${NC}" ;;
    esac
    echo ""

    echo -e "  ${CYAN}Indices:${NC}"
    local indices
    indices=$(curl -s "http://${ES_HOST}/_cat/indices?v&s=index" 2>/dev/null)
    if [[ -n "$indices" ]]; then
        echo "$indices" | while IFS= read -r line; do
            echo "    $line"
        done
    else
        echo -e "    ${RED}Could not retrieve indices.${NC}"
    fi
    echo ""

    # Show Akeneo-specific indices detail
    echo -e "  ${CYAN}Akeneo PIM Indices Detail:${NC}"
    curl -s "http://${ES_HOST}/_cat/indices?v&s=index" 2>/dev/null | grep "akeneo_pim" | while IFS= read -r line; do
        echo "    $line"
    done
    echo ""

    separator
}

# ── Action: Health ───────────────────────────────────────────────────────────
do_health() {
    separator
    info "Elasticsearch Health Check"
    echo ""

    # Cluster health
    echo -e "  ${CYAN}Cluster:${NC}"
    curl -s "http://${ES_HOST}/_cluster/health?pretty" 2>/dev/null || echo -e "  ${RED}Cannot connect to ES at ${ES_HOST}${NC}"
    echo ""

    # Node info
    echo -e "  ${CYAN}Nodes:${NC}"
    curl -s "http://${ES_HOST}/_cat/nodes?v" 2>/dev/null || echo -e "  ${RED}Cannot retrieve node info${NC}"
    echo ""

    # Disk usage
    echo -e "  ${CYAN}Disk Usage:${NC}"
    curl -s "http://${ES_HOST}/_cat/allocation?v" 2>/dev/null || echo -e "  ${RED}Cannot retrieve disk info${NC}"
    echo ""

    separator
}

# ── Action: Query Test ───────────────────────────────────────────────────────
do_query() {
    separator
    info "Running test query against product index..."
    echo ""

    # Get the actual Akeneo product index name
    local index_name
    index_name=$(curl -s "http://${ES_HOST}/_cat/indices" 2>/dev/null | awk '{print $3}' | grep "akeneo_pim_product" | head -1)

    if [[ -z "$index_name" ]]; then
        error "No Akeneo product index found."
        return 1
    fi

    info "Using index: ${index_name}"
    echo ""

    echo -e "  ${CYAN}Document count:${NC}"
    curl -s "http://${ES_HOST}/${index_name}/_count?pretty" 2>/dev/null
    echo ""

    echo -e "  ${CYAN}Sample documents (first 3):${NC}"
    curl -s "http://${ES_HOST}/${index_name}/_search?size=3&pretty" 2>/dev/null | head -50
    echo ""

    separator
}

# ── Dispatch ─────────────────────────────────────────────────────────────────
case "$ACTION" in
    index-products)   do_index_products ;;
    index-models)     do_index_models ;;
    index-all)        do_index_all ;;
    reset)            do_reset ;;
    update-mapping)   do_update_mapping ;;
    update-limit)     do_update_limit ;;
    status)           do_status ;;
    health)           do_health ;;
    query)            do_query ;;
    help|-h|--help)   usage ;;
    *)
        error "Unknown action: ${ACTION}"
        usage
        ;;
esac

exit 0
