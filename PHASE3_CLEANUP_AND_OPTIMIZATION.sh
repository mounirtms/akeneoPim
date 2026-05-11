#!/bin/bash
# ========================================
# PHASE 3: CLEANUP & OPTIMIZATION
# Date: May 6, 2026
# ========================================

echo "=========================================="
echo "PHASE 3: CLEANUP & OPTIMIZATION"
echo "Started: $(date)"
echo "=========================================="
echo ""

# Step 1: Clean old audit files
echo "Step 1: Cleaning old audit files..."
echo "------------------------------------"
OLD_AUDITS=$(find . -maxdepth 1 -type f \( -name "*AUDIT*" -o -name "*audit*" -o -name "*CRITICAL*" \) -mtime +1 2>/dev/null | wc -l)
if [ "$OLD_AUDITS" -gt 0 ]; then
    mkdir -p archive/old_audits_$(date +%Y%m%d)
    find . -maxdepth 1 -type f \( -name "*AUDIT*" -o -name "*audit*" -o -name "*CRITICAL*" \) -mtime +1 -exec mv {} archive/old_audits_$(date +%Y%m%d)/ \; 2>/dev/null
    echo "✓ Archived $OLD_AUDITS old audit files"
else
    echo "✓ No old audit files to clean"
fi
echo ""

# Step 2: Clean old log files
echo "Step 2: Cleaning old temporary logs..."
echo "---------------------------------------"
OLD_LOGS=$(find . -maxdepth 1 -type f \( -name "*.log" -o -name "*_log_*" \) -mtime +1 2>/dev/null | wc -l)
if [ "$OLD_LOGS" -gt 0 ]; then
    mkdir -p archive/old_logs_$(date +%Y%m%d)
    find . -maxdepth 1 -type f \( -name "*.log" -o -name "*_log_*" \) -mtime +1 -exec mv {} archive/old_logs_$(date +%Y%m%d)/ \; 2>/dev/null
    echo "✓ Archived $OLD_LOGS old log files"
else
    echo "✓ No old log files to clean"
fi
echo ""

# Step 3: Remove qodercli/qooder-ser tasks
echo "Step 3: Checking for qodercli/qooder tasks..."
echo "----------------------------------------------"
if [ -d ".qoder" ]; then
    echo "⚠ Found .qoder directory (keeping for now - may contain settings)"
fi
QODER_PROCESSES=$(ps aux | grep -E "(qodercli|qooder-ser)" | grep -v grep | wc -l)
if [ "$QODER_PROCESSES" -gt 0 ]; then
    echo "⚠ Found $QODER_PROCESSES qoder processes (will not kill - may be needed)"
else
    echo "✓ No qoder processes running"
fi
echo ""

# Step 4: Check for active SSH sessions
echo "Step 4: Checking active SSH sessions..."
echo "----------------------------------------"
SSH_SESSIONS=$(who | grep -c pts || echo 0)
echo "Active SSH sessions: $SSH_SESSIONS"
echo "Note: Not terminating sessions automatically for safety"
echo ""

# Step 5: Optimize Symfony cache
echo "Step 5: Optimizing Symfony cache..."
echo "------------------------------------"
php bin/console cache:clear --env=prod --no-warmup 2>&1 | tail -3
php bin/console cache:warmup --env=prod 2>&1 | tail -3
echo "✓ Cache optimized"
echo ""

# Step 6: Check disk usage
echo "Step 6: Disk usage check..."
echo "---------------------------"
df -h . | awk 'NR==1 || /\/$/'
echo ""
DU_VAR=$(du -sh var/ 2>/dev/null | awk '{print $1}')
DU_VENDOR=$(du -sh vendor/ 2>/dev/null | awk '{print $1}')
DU_PUBLIC=$(du -sh public/ 2>/dev/null | awk '{print $1}')
echo "Directory sizes:"
echo "  var/: $DU_VAR"
echo "  vendor/: $DU_VENDOR"
echo "  public/: $DU_PUBLIC"
echo ""

# Step 7: Summary of system state
echo "Step 7: System state summary..."
echo "--------------------------------"
echo "Database products: $(mysql -h 127.0.0.1 -P 3307 -u akeneo_pim -pakeneo_pim --skip-ssl akeneo_pim -e 'SELECT COUNT(*) FROM pim_catalog_product;' 2>/dev/null | tail -1)"
echo "Elasticsearch status: $(curl -s http://localhost:9200/_cluster/health 2>/dev/null | grep -o '"status":"[^"]*"' | cut -d'"' -f4)"
echo "Web interface: $(curl -s -o /dev/null -w '%{http_code}' https://pim.technostationery.com/user/login)"
echo "Cache files: $(find var/cache/prod -type f 2>/dev/null | wc -l)"
echo ""

echo "=========================================="
echo "CLEANUP & OPTIMIZATION COMPLETE"
echo "Completed: $(date)"
echo "=========================================="
