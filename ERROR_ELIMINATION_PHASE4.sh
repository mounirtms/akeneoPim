#!/bin/bash
# ========================================
# PHASE 4: ERROR ELIMINATION & LOG ANALYSIS
# Date: May 6, 2026
# ========================================

echo "=========================================="
echo "PHASE 4: ERROR ELIMINATION"
echo "Started: $(date)"
echo "=========================================="
echo ""

# Step 1: Analyze Production Logs
echo "Step 1: Analyzing Production Logs..."
echo "--------------------------------------"
if [ -f "var/logs/prod.log" ]; then
    echo "Production log size: $(du -h var/logs/prod.log | awk '{print $1}')"
    
    # Count error levels
    CRITICAL_COUNT=$(grep -c "CRITICAL" var/logs/prod.log 2>/dev/null || echo 0)
    ERROR_COUNT=$(grep -c "\.ERROR" var/logs/prod.log 2>/dev/null || echo 0)
    WARNING_COUNT=$(grep -c "WARNING" var/logs/prod.log 2>/dev/null || echo 0)
    
    echo "Log Analysis:"
    echo "  CRITICAL: $CRITICAL_COUNT"
    echo "  ERROR: $ERROR_COUNT"
    echo "  WARNING: $WARNING_COUNT"
    
    echo ""
    echo "Recent CRITICAL errors (last 10):"
    grep "CRITICAL" var/logs/prod.log 2>/dev/null | tail -10 | cut -c1-150 || echo "  None found"
    
    echo ""
    echo "Recent ERROR entries (last 10):"
    grep "\.ERROR" var/logs/prod.log 2>/dev/null | tail -10 | cut -c1-150 || echo "  None found"
else
    echo "⚠ Production log not found"
fi
echo ""

# Step 2: Check PHP Error Logs
echo "Step 2: Checking PHP Error Logs..."
echo "-----------------------------------"
if [ -f "error_log" ]; then
    echo "PHP error log size: $(du -h error_log | awk '{print $1}')"
    echo "Recent PHP errors (last 10):"
    tail -10 error_log | cut -c1-150
else
    echo "✓ No PHP error_log file (good sign)"
fi
echo ""

# Step 3: Check Apache/Web Server Logs
echo "Step 3: Checking Web Server Logs..."
echo "------------------------------------"
echo "Recent access attempts:"
tail -5 /var/log/httpd/access_log 2>/dev/null | grep pim.technostationery.com | cut -c1-150 || echo "  Log not accessible"
echo ""

# Step 4: Check Symfony Deprecations
echo "Step 4: Analyzing Symfony Deprecations..."
echo "------------------------------------------"
DEPRECATION_COUNT=$(grep -c "DEPRECATED" var/logs/prod.log 2>/dev/null || echo 0)
echo "Deprecation warnings: $DEPRECATION_COUNT"
if [ "$DEPRECATION_COUNT" -gt 0 ]; then
    echo "Sample deprecations (first 5):"
    grep "DEPRECATED" var/logs/prod.log 2>/dev/null | head -5 | cut -c1-150
fi
echo ""

# Step 5: Check Database Connection Errors
echo "Step 5: Database Connection Status..."
echo "--------------------------------------"
DB_ERRORS=$(grep -c "database\|DB\|mysql\|connection" var/logs/prod.log 2>/dev/null | grep -i error || echo 0)
echo "Database-related errors: $DB_ERRORS"

# Test current connection
if mysql -h 127.0.0.1 -P 3307 -u akeneo_pim -pakeneo_pim --skip-ssl akeneo_pim -e "SELECT 1;" &>/dev/null; then
    echo "✓ Database connection: WORKING"
else
    echo "✗ Database connection: FAILED"
fi
echo ""

# Step 6: Check Elasticsearch Errors
echo "Step 6: Elasticsearch Error Check..."
echo "-------------------------------------"
ES_ERRORS=$(grep -c "elasticsearch\|ES" var/logs/prod.log 2>/dev/null | grep -i error || echo 0)
echo "Elasticsearch-related errors: $ES_ERRORS"

# Test current connection
if curl -s http://localhost:9200/_cluster/health &>/dev/null; then
    ES_STATUS=$(curl -s http://localhost:9200/_cluster/health | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
    echo "✓ Elasticsearch status: $ES_STATUS"
else
    echo "✗ Elasticsearch: NOT ACCESSIBLE"
fi
echo ""

# Step 7: Check File Permission Issues
echo "Step 7: File Permission Check..."
echo "---------------------------------"
PERM_ERRORS=$(grep -c "permission\|forbidden\|access denied" var/logs/prod.log 2>/dev/null || echo 0)
echo "Permission-related errors: $PERM_ERRORS"

# Check critical directories
for dir in var/cache var/logs var/sessions public/media; do
    if [ -w "$dir" ]; then
        echo "✓ $dir: writable"
    else
        echo "✗ $dir: NOT writable"
    fi
done
echo ""

# Step 8: Generate Error Summary
echo "Step 8: Error Summary..."
echo "------------------------"
TOTAL_ERRORS=$((CRITICAL_COUNT + ERROR_COUNT))
echo "Total errors found: $TOTAL_ERRORS"

if [ "$TOTAL_ERRORS" -eq 0 ]; then
    echo "✓ No errors found in logs"
    EXIT_CODE=0
elif [ "$TOTAL_ERRORS" -lt 10 ]; then
    echo "⚠ Minor errors present (< 10)"
    EXIT_CODE=1
else
    echo "✗ Significant errors present (>= 10)"
    EXIT_CODE=2
fi

echo ""
echo "=========================================="
echo "LOG ANALYSIS COMPLETE"
echo "Completed: $(date)"
echo "=========================================="

exit $EXIT_CODE
