#!/usr/bin/env bash
###############################################################################
# Akeneo PIM - Health Check & Diagnostics
# Purpose: Comprehensive system health verification
# Usage:   ./health_check.sh [options]
# Options: --quiet (exit code only) | --json (JSON output) | --verbose
###############################################################################

set -euo pipefail

# ── Configuration ────────────────────────────────────────────────────────────
PIM_ROOT="/home/pim/public_html"
PHP_BIN="php"
ENV="prod"
ES_HOST="localhost:9200"
DB_HOST="127.0.0.1"
DB_PORT="3307"
DB_NAME="akeneo_pim"
DB_USER="root"
DB_PASS="YourNewStrongPassword"
PIM_URL="https://pim.technostationery.com"
LOG_DIR="${PIM_ROOT}/var/logs"
LOG_FILE="${LOG_DIR}/health_check.log"

# ── Flags ────────────────────────────────────────────────────────────────────
QUIET=0
JSON_OUTPUT=0
VERBOSE=0

# ── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ── Results ──────────────────────────────────────────────────────────────────
declare -a CHECK_NAMES=()
declare -a CHECK_STATUSES=()
declare -a CHECK_MESSAGES=()
TOTAL_CHECKS=0
PASSED=0
WARNINGS=0
FAILURES=0

# ── Helper functions ─────────────────────────────────────────────────────────
timestamp() { date '+%Y-%m-%d %H:%M:%S'; }

log_result() {
    local name="$1"
    local status="$2"  # ok, warn, fail
    local message="$3"

    CHECK_NAMES+=("$name")
    CHECK_STATUSES+=("$status")
    CHECK_MESSAGES+=("$message")
    ((TOTAL_CHECKS++)) || true

    case "$status" in
        ok)   ((PASSED++)) || true; [[ $QUIET -eq 0 ]] && echo -e "  ${GREEN}[PASS]${NC} ${name}: ${message}" ;;
        warn) ((WARNINGS++)) || true; [[ $QUIET -eq 0 ]] && echo -e "  ${YELLOW}[WARN]${NC} ${name}: ${message}" ;;
        fail) ((FAILURES++)) || true; [[ $QUIET -eq 0 ]] && echo -e "  ${RED}[FAIL]${NC} ${name}: ${message}" ;;
    esac

    echo "[$(timestamp)] [${status^^}] ${name}: ${message}" >> "$LOG_FILE" 2>/dev/null || true
}

separator() { [[ $QUIET -eq 0 ]] && echo -e "${CYAN}────────────────────────────────────────────────────────────${NC}"; }

# ── Parse arguments ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --quiet|-q)   QUIET=1; shift ;;
        --json)       JSON_OUTPUT=1; QUIET=1; shift ;;
        --verbose|-v) VERBOSE=1; shift ;;
        --help|-h)
            echo "Usage: $0 [--quiet|--json|--verbose]"
            exit 0
            ;;
        *) shift ;;
    esac
done

# ═══════════════════════════════════════════════════════════════════════════════
# HEALTH CHECKS
# ═══════════════════════════════════════════════════════════════════════════════

[[ $QUIET -eq 0 ]] && {
    echo ""
    echo -e "${BOLD}${CYAN}Akeneo PIM Health Check${NC}"
    echo -e "${CYAN}Date: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
    separator
    echo ""
}

# ── 1. PHP ───────────────────────────────────────────────────────────────────
[[ $QUIET -eq 0 ]] && echo -e "${BOLD}PHP Environment${NC}"
php_version=$(${PHP_BIN} -v 2>&1 | head -1 | awk '{print $2}')
if [[ -n "$php_version" ]]; then
    log_result "PHP Version" "ok" "$php_version"
else
    log_result "PHP Version" "fail" "PHP not available"
fi

# Check required extensions
for ext in pdo_mysql json curl intl gd bcmath zip; do
    if ${PHP_BIN} -m 2>/dev/null | grep -qi "^${ext}$"; then
        [[ $VERBOSE -eq 1 ]] && log_result "PHP ext: ${ext}" "ok" "loaded"
    else
        log_result "PHP ext: ${ext}" "fail" "not loaded"
    fi
done

# Check PHP memory limit
php_memory=$(${PHP_BIN} -r "echo ini_get('memory_limit');" 2>/dev/null)
log_result "PHP Memory Limit" "ok" "$php_memory"

[[ $QUIET -eq 0 ]] && echo ""

# ── 2. Database ──────────────────────────────────────────────────────────────
[[ $QUIET -eq 0 ]] && echo -e "${BOLD}Database${NC}"
db_status=$(${PHP_BIN} -r "
    try {
        \$pdo = new PDO('mysql:host=${DB_HOST};port=${DB_PORT};dbname=${DB_NAME}', '${DB_USER}', '${DB_PASS}');
        \$result = \$pdo->query('SELECT COUNT(*) as c FROM oro_user')->fetch();
        echo 'connected:' . \$result['c'] . ' users';
    } catch (\Exception \$e) {
        echo 'error:' . \$e->getMessage();
    }
" 2>/dev/null)

if [[ "$db_status" == connected:* ]]; then
    log_result "Database Connection" "ok" "$db_status"
else
    log_result "Database Connection" "fail" "$db_status"
fi

# Check table count
table_count=$(${PHP_BIN} -r "
    try {
        \$pdo = new PDO('mysql:host=${DB_HOST};port=${DB_PORT};dbname=${DB_NAME}', '${DB_USER}', '${DB_PASS}');
        \$result = \$pdo->query('SELECT COUNT(*) as c FROM information_schema.tables WHERE table_schema=\"${DB_NAME}\"')->fetch();
        echo \$result['c'];
    } catch (\Exception \$e) { echo '0'; }
" 2>/dev/null)
if [[ "$table_count" -gt 0 ]]; then
    log_result "Database Tables" "ok" "${table_count} tables"
else
    log_result "Database Tables" "fail" "No tables found"
fi

# Check product count
product_count=$(${PHP_BIN} -r "
    try {
        \$pdo = new PDO('mysql:host=${DB_HOST};port=${DB_PORT};dbname=${DB_NAME}', '${DB_USER}', '${DB_PASS}');
        \$result = \$pdo->query('SELECT COUNT(*) as c FROM pim_catalog_product')->fetch();
        echo \$result['c'];
    } catch (\Exception \$e) { echo 'error'; }
" 2>/dev/null)
if [[ "$product_count" != "error" ]]; then
    log_result "Products in DB" "ok" "${product_count} products"
else
    log_result "Products in DB" "warn" "Could not query product table"
fi

[[ $QUIET -eq 0 ]] && echo ""

# ── 3. Elasticsearch ────────────────────────────────────────────────────────
[[ $QUIET -eq 0 ]] && echo -e "${BOLD}Elasticsearch${NC}"
es_response=$(curl -s "http://${ES_HOST}/_cluster/health" 2>/dev/null || echo "")
if [[ -n "$es_response" ]]; then
    es_status=$(echo "$es_response" | grep -oP '"status"\s*:\s*"\K[^"]+' || echo "unknown")
    es_nodes=$(echo "$es_response" | grep -oP '"number_of_nodes"\s*:\s*\K[0-9]+' || echo "0")
    case "$es_status" in
        green)  log_result "ES Cluster" "ok" "green (${es_nodes} nodes)" ;;
        yellow) log_result "ES Cluster" "warn" "yellow (${es_nodes} nodes) - replicas unassigned" ;;
        red)    log_result "ES Cluster" "fail" "red - cluster unhealthy" ;;
        *)      log_result "ES Cluster" "fail" "unknown status: $es_status" ;;
    esac

    # Check PIM index
    pim_index_docs=$(curl -s "http://${ES_HOST}/_cat/indices" 2>/dev/null | grep "akeneo_pim_product" | awk '{print $7}' | head -1)
    if [[ -n "$pim_index_docs" ]]; then
        log_result "ES Product Index" "ok" "${pim_index_docs} documents indexed"
    else
        log_result "ES Product Index" "warn" "No product index found"
    fi
else
    log_result "ES Cluster" "fail" "Cannot connect to ${ES_HOST}"
fi

[[ $QUIET -eq 0 ]] && echo ""

# ── 4. File System ──────────────────────────────────────────────────────────
[[ $QUIET -eq 0 ]] && echo -e "${BOLD}File System${NC}"

# Check writable directories
for dir in "var/cache/${ENV}" "var/logs" "var/sessions" "var/file_storage" "public/media"; do
    full_path="${PIM_ROOT}/${dir}"
    if [[ -d "$full_path" && -w "$full_path" ]]; then
        log_result "Writable: ${dir}" "ok" "writable"
    elif [[ -d "$full_path" ]]; then
        log_result "Writable: ${dir}" "fail" "exists but NOT writable"
    else
        log_result "Writable: ${dir}" "warn" "directory missing"
    fi
done

# Check critical files
for file in "public/dist/main.min.js" "public/dist/vendor.min.js" "public/css/pim.css"; do
    if [[ -f "${PIM_ROOT}/${file}" ]]; then
        local_size=$(ls -lh "${PIM_ROOT}/${file}" | awk '{print $5}')
        log_result "File: ${file}" "ok" "${local_size}"
    else
        log_result "File: ${file}" "fail" "missing"
    fi
done

# Disk space
disk_usage=$(df -h "${PIM_ROOT}" | tail -1 | awk '{print $5}')
disk_avail=$(df -h "${PIM_ROOT}" | tail -1 | awk '{print $4}')
disk_pct=$(echo "$disk_usage" | tr -d '%')
if [[ "$disk_pct" -lt 80 ]]; then
    log_result "Disk Usage" "ok" "${disk_usage} used, ${disk_avail} available"
elif [[ "$disk_pct" -lt 90 ]]; then
    log_result "Disk Usage" "warn" "${disk_usage} used, ${disk_avail} available"
else
    log_result "Disk Usage" "fail" "${disk_usage} used, ${disk_avail} available - CRITICAL"
fi

[[ $QUIET -eq 0 ]] && echo ""

# ── 5. Web Server ───────────────────────────────────────────────────────────
[[ $QUIET -eq 0 ]] && echo -e "${BOLD}Web Server${NC}"

# Login page
login_code=$(curl -s -o /dev/null -w "%{http_code}" "${PIM_URL}/user/login" --max-time 10 2>/dev/null || echo "000")
if [[ "$login_code" == "200" ]]; then
    log_result "Login Page" "ok" "HTTP ${login_code}"
elif [[ "$login_code" == "302" || "$login_code" == "301" ]]; then
    log_result "Login Page" "ok" "HTTP ${login_code} (redirect)"
elif [[ "$login_code" == "403" ]]; then
    log_result "Login Page" "warn" "HTTP 403 (Cloudflare challenge)"
else
    log_result "Login Page" "fail" "HTTP ${login_code}"
fi

# API endpoint
api_code=$(curl -s -o /dev/null -w "%{http_code}" "${PIM_URL}/api/rest/v1/" --max-time 10 2>/dev/null || echo "000")
if [[ "$api_code" == "401" || "$api_code" == "200" ]]; then
    log_result "API Endpoint" "ok" "HTTP ${api_code}"
elif [[ "$api_code" == "403" ]]; then
    log_result "API Endpoint" "warn" "HTTP 403 (Cloudflare)"
else
    log_result "API Endpoint" "fail" "HTTP ${api_code}"
fi

# CSS file
css_code=$(curl -s -o /dev/null -w "%{http_code}" "${PIM_URL}/css/pim.css" --max-time 10 2>/dev/null || echo "000")
if [[ "$css_code" == "200" ]]; then
    log_result "CSS Assets" "ok" "HTTP ${css_code}"
else
    log_result "CSS Assets" "fail" "HTTP ${css_code}"
fi

# JS file
js_code=$(curl -s -o /dev/null -w "%{http_code}" "${PIM_URL}/dist/main.min.js" --max-time 10 2>/dev/null || echo "000")
if [[ "$js_code" == "200" ]]; then
    log_result "JS Bundle" "ok" "HTTP ${js_code}"
else
    log_result "JS Bundle" "fail" "HTTP ${js_code}"
fi

[[ $QUIET -eq 0 ]] && echo ""

# ── 6. Cron Jobs ────────────────────────────────────────────────────────────
[[ $QUIET -eq 0 ]] && echo -e "${BOLD}Cron Jobs${NC}"
cron_count=$(crontab -l 2>/dev/null | grep -c "AKENEO_PIM_CRON" 2>/dev/null || true)
cron_count=${cron_count:-0}
if [[ "$cron_count" -gt 0 ]]; then
    active_jobs=$(crontab -l 2>/dev/null | grep -c "^[^#].*bin/console" 2>/dev/null || true)
    active_jobs=${active_jobs:-0}
    log_result "Cron Jobs" "ok" "${active_jobs} active PIM cron entries"
else
    log_result "Cron Jobs" "warn" "No Akeneo PIM cron jobs installed"
fi

# Check messenger consumer activity
if [[ -f "${LOG_DIR}/cron_messenger.log" ]]; then
    last_messenger=$(stat -c %Y "${LOG_DIR}/cron_messenger.log" 2>/dev/null || echo "0")
    now=$(date +%s)
    age=$(( (now - last_messenger) / 60 ))
    if [[ $age -lt 5 ]]; then
        log_result "Messenger Worker" "ok" "Last activity ${age} minutes ago"
    elif [[ $age -lt 30 ]]; then
        log_result "Messenger Worker" "warn" "Last activity ${age} minutes ago"
    else
        log_result "Messenger Worker" "fail" "No activity for ${age} minutes"
    fi
else
    log_result "Messenger Worker" "warn" "No messenger log found"
fi

[[ $QUIET -eq 0 ]] && echo ""

# ── 7. Log Analysis ────────────────────────────────────────────────────────
[[ $QUIET -eq 0 ]] && echo -e "${BOLD}Recent Errors${NC}"
if [[ -f "${LOG_DIR}/prod.log" ]]; then
    recent_errors=$(tail -500 "${LOG_DIR}/prod.log" 2>/dev/null | grep -c "CRITICAL\|ERROR" || true)
    recent_errors=$((recent_errors + 0))
    if [[ $recent_errors -eq 0 ]]; then
        log_result "Recent Errors" "ok" "No critical errors in last 500 log entries"
    elif [[ $recent_errors -lt 10 ]]; then
        log_result "Recent Errors" "warn" "${recent_errors} error(s) in last 500 log entries"
    else
        log_result "Recent Errors" "fail" "${recent_errors} errors in last 500 log entries"
    fi

    # Log file size check
    log_size=$(ls -lh "${LOG_DIR}/prod.log" | awk '{print $5}')
    log_size_bytes=$(stat -c %s "${LOG_DIR}/prod.log" 2>/dev/null || echo "0")
    if [[ "$log_size_bytes" -gt 104857600 ]]; then  # >100MB
        log_result "Log File Size" "warn" "prod.log is ${log_size} (consider rotation)"
    else
        log_result "Log File Size" "ok" "prod.log: ${log_size}"
    fi
else
    log_result "Recent Errors" "warn" "No prod.log found"
fi

[[ $QUIET -eq 0 ]] && echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# SUMMARY
# ═══════════════════════════════════════════════════════════════════════════════

if [[ $JSON_OUTPUT -eq 1 ]]; then
    # JSON output
    echo "{"
    echo "  \"timestamp\": \"$(timestamp)\","
    echo "  \"total_checks\": ${TOTAL_CHECKS},"
    echo "  \"passed\": ${PASSED},"
    echo "  \"warnings\": ${WARNINGS},"
    echo "  \"failures\": ${FAILURES},"
    echo "  \"overall_status\": \"$([ $FAILURES -eq 0 ] && echo 'healthy' || echo 'unhealthy')\","
    echo "  \"checks\": ["
    for i in "${!CHECK_NAMES[@]}"; do
        comma=","
        [[ $i -eq $((${#CHECK_NAMES[@]} - 1)) ]] && comma=""
        echo "    {\"name\": \"${CHECK_NAMES[$i]}\", \"status\": \"${CHECK_STATUSES[$i]}\", \"message\": \"${CHECK_MESSAGES[$i]}\"}${comma}"
    done
    echo "  ]"
    echo "}"
elif [[ $QUIET -eq 0 ]]; then
    separator
    echo ""
    echo -e "${BOLD}Health Check Summary${NC}"
    echo -e "  Total checks: ${TOTAL_CHECKS}"
    echo -e "  ${GREEN}Passed:${NC}   ${PASSED}"
    echo -e "  ${YELLOW}Warnings:${NC} ${WARNINGS}"
    echo -e "  ${RED}Failures:${NC} ${FAILURES}"
    echo ""

    if [[ $FAILURES -eq 0 && $WARNINGS -eq 0 ]]; then
        echo -e "  ${GREEN}${BOLD}Overall: HEALTHY${NC}"
    elif [[ $FAILURES -eq 0 ]]; then
        echo -e "  ${YELLOW}${BOLD}Overall: HEALTHY (with warnings)${NC}"
    else
        echo -e "  ${RED}${BOLD}Overall: UNHEALTHY (${FAILURES} failures)${NC}"
    fi
    echo ""
    separator
fi

# Exit code: 0 = healthy, 1 = warnings only, 2 = failures
if [[ $FAILURES -gt 0 ]]; then
    exit 2
elif [[ $WARNINGS -gt 0 ]]; then
    exit 1
else
    exit 0
fi
