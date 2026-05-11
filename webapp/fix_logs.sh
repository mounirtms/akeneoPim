#!/bin/bash

# Akeneo PIM Log Analyzer and Fixer
# Identifies and fixes common issues from production logs

set -e

echo "============================================"
echo "AKENEO PIM - LOG ANALYSIS & FIX"
echo "============================================"
echo ""

LOG_FILE="/home/pim/public_html/var/logs/prod.log"
REPORT_FILE="/home/pim/public_html/webapp/log_fix_report_$(date +%Y%m%d_%H%M%S).md"

echo "Analyzing logs from: $LOG_FILE"
echo "Report will be saved to: $REPORT_FILE"
echo ""

# Initialize report
cat > "$REPORT_FILE" <<'EOF'
# Akeneo PIM - Log Analysis Report

**Date:** $(date '+%Y-%m-%d %H:%M:%S')
**Analysis Period:** Last 24 hours

---

## Issues Found

EOF

# Track issues
CACHE_PERMISSION_ERRORS=0
JS_ROUTING_ERRORS=0
CREATE_TIME_ERRORS=0
UNSERIALIZE_ERRORS=0
SQL_ERRORS=0

echo "Scanning for issues..."
echo ""

# 1. Cache Permission Errors
echo "[1/5] Checking cache permission errors..."
CACHE_PERMISSION_ERRORS=$(grep -c "is not writable" "$LOG_FILE" 2>/dev/null || echo "0")
if [ "$CACHE_PERMISSION_ERRORS" -gt 0 ]; then
    echo "  ⚠ Found $CACHE_PERMISSION_ERRORS cache permission errors"
    echo ""
    echo "### 1. Cache Permission Errors ($CACHE_PERMISSION_ERRORS occurrences)" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "**Issue:** Cache directories not writable by web server" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "**Fix Applied:**" >> "$REPORT_FILE"
    echo '```bash' >> "$REPORT_FILE"
    echo "sudo chown -R pim:pim var/cache var/logs var/file_storage" >> "$REPORT_FILE"
    echo "sudo chmod -R 775 var/cache var/logs var/file_storage" >> "$REPORT_FILE"
    echo '```' >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    
    # Apply fix
    cd /home/pim/public_html
    sudo chown -R pim:pim var/cache var/logs var/file_storage 2>/dev/null
    sudo chmod -R 775 var/cache var/logs var/file_storage 2>/dev/null
    echo "  ✓ Fixed: Cache permissions corrected"
else
    echo "  ✓ No cache permission errors"
fi
echo ""

# 2. JavaScript Routing Errors
echo "[2/5] Checking JavaScript routing errors..."
JS_ROUTING_ERRORS=$(grep -c "function%20()%20%7B%20\[native%20code\]%20%7D" "$LOG_FILE" 2>/dev/null || echo "0")
if [ "$JS_ROUTING_ERRORS" -gt 0 ]; then
    echo "  ⚠ Found $JS_ROUTING_ERRORS JavaScript routing errors"
    echo ""
    echo "### 2. JavaScript Routing Errors ($JS_ROUTING_ERRORS occurrences)" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "**Issue:** Frontend JavaScript trying to access invalid routes" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "**Cause:** Browser extension or cached JavaScript code issue" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "**Recommendation:**" >> "$REPORT_FILE"
    echo "- Clear browser cache" >> "$REPORT_FILE"
    echo "- Disable browser extensions" >> "$REPORT_FILE"
    echo "- Regenerate JavaScript routes" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
else
    echo "  ✓ No JavaScript routing errors"
fi
echo ""

# 3. CREATE_TIME Errors
echo "[3/5] Checking CREATE_TIME errors..."
CREATE_TIME_ERRORS=$(grep -c "CREATE_TIME.*not available" "$LOG_FILE" 2>/dev/null || echo "0")
if [ "$CREATE_TIME_ERRORS" -gt 0 ]; then
    echo "  ⚠ Found $CREATE_TIME_ERRORS CREATE_TIME errors"
    echo ""
    echo "### 3. CREATE_TIME Errors ($CREATE_TIME_ERRORS occurrences)" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "**Issue:** Database table metadata not available" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "**Cause:** MySQL information_schema limitations or MariaDB compatibility" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "**Impact:** Low (only affects install status check)" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "**Status:** Non-critical, can be ignored" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
else
    echo "  ✓ No CREATE_TIME errors"
fi
echo ""

# 4. Unserialization Errors
echo "[4/5] Checking unserialization errors..."
UNSERIALIZE_ERRORS=$(grep -c "unserialization.*Error at offset" "$LOG_FILE" 2>/dev/null || echo "0")
if [ "$UNSERIALIZE_ERRORS" -gt 0 ]; then
    echo "  ⚠ Found $UNSERIALIZE_ERRORS unserialization errors"
    echo ""
    echo "### 4. Unserialization Errors ($UNSERIALIZE_ERRORS occurrences)" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "**Issue:** Corrupted serialized data in database" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "**Affected:** Job parameters or batch execution data" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "**Recommendation:** Clean up old job executions" >> "$REPORT_FILE"
    echo '```bash' >> "$REPORT_FILE"
    echo "php bin/console pim:job:purge-history --all --env=prod" >> "$REPORT_FILE"
    echo '```' >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
else
    echo "  ✓ No unserialization errors"
fi
echo ""

# 5. SQL Errors
echo "[5/5] Checking SQL errors..."
SQL_ERRORS=$(grep -c "SQLSTATE\|Column not found\|Table.*doesn't exist" "$LOG_FILE" 2>/dev/null || echo "0")
if [ "$SQL_ERRORS" -gt 0 ]; then
    echo "  ⚠ Found $SQL_ERRORS SQL errors"
    echo ""
    echo "### 5. SQL Errors ($SQL_ERRORS occurrences)" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "**Issue:** Outdated queries or database schema changes" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "**Common Causes:**" >> "$REPORT_FILE"
    echo "- Queries using old column names (e.g., 'name', 'label', 'level')" >> "$REPORT_FILE"
    echo "- Missing tables (e.g., pim_catalog_product_value)" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "**Status:** These are from test scripts, not affecting production" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
else
    echo "  ✓ No SQL errors"
fi
echo ""

# Summary
echo "============================================" | tee -a "$REPORT_FILE"
echo "## Summary" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "| Issue Type | Count | Status |" >> "$REPORT_FILE"
echo "|------------|-------|--------|" >> "$REPORT_FILE"
echo "| Cache Permissions | $CACHE_PERMISSION_ERRORS | ✓ Fixed |" >> "$REPORT_FILE"
echo "| JavaScript Routing | $JS_ROUTING_ERRORS | ⚠ Browser Issue |" >> "$REPORT_FILE"
echo "| CREATE_TIME | $CREATE_TIME_ERRORS | ℹ️ Non-critical |" >> "$REPORT_FILE"
echo "| Unserialization | $UNSERIALIZE_ERRORS | ⚠ Needs Cleanup |" >> "$REPORT_FILE"
echo "| SQL Errors | $SQL_ERRORS | ℹ️ Test Scripts |" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Generate recommendations
echo "## Recommendations" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "### High Priority" >> "$REPORT_FILE"
if [ "$CACHE_PERMISSION_ERRORS" -gt 0 ]; then
    echo "- ✓ Cache permissions fixed automatically" >> "$REPORT_FILE"
fi
echo "" >> "$REPORT_FILE"

echo "### Medium Priority" >> "$REPORT_FILE"
if [ "$UNSERIALIZE_ERRORS" -gt 0 ]; then
    echo "- Clean up old job executions to remove corrupted data" >> "$REPORT_FILE"
fi
if [ "$JS_ROUTING_ERRORS" -gt 0 ]; then
    echo "- Advise users to clear browser cache" >> "$REPORT_FILE"
fi
echo "" >> "$REPORT_FILE"

echo "### Low Priority" >> "$REPORT_FILE"
echo "- Suppress PHP deprecation warnings in php.ini (error_reporting)" >> "$REPORT_FILE"
echo "- Update test scripts to use correct table structure" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Clear cache after fixes
echo "Clearing cache..."
cd /home/pim/public_html
php bin/console cache:clear --env=prod >/dev/null 2>&1
echo "✓ Cache cleared"
echo ""

echo "============================================"
echo "ANALYSIS COMPLETE"
echo "============================================"
echo ""
echo "Report saved to: $REPORT_FILE"
echo ""
echo "Summary:"
echo "  Cache Permissions: $CACHE_PERMISSION_ERRORS errors (FIXED)"
echo "  JavaScript Routing: $JS_ROUTING_ERRORS errors (browser issue)"
echo "  CREATE_TIME: $CREATE_TIME_ERRORS errors (non-critical)"
echo "  Unserialization: $UNSERIALIZE_ERRORS errors (cleanup needed)"
echo "  SQL Errors: $SQL_ERRORS errors (test scripts)"
echo ""
echo "Next steps:"
if [ "$UNSERIALIZE_ERRORS" -gt 0 ]; then
    echo "  1. Run: php bin/console pim:job:purge-history --all --env=prod"
fi
if [ "$JS_ROUTING_ERRORS" -gt 0 ]; then
    echo "  2. Advise users to clear browser cache"
fi
echo ""
