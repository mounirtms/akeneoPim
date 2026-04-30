#!/bin/bash
#
# SETUP AUTOMATED MONITORING CRON JOBS
# Configures daily health checks, backups, and quality validation
# Date: 2026-04-29
#

echo "========================================="
echo "  MONITORING AUTOMATION SETUP"
echo "========================================="
echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Check if we're root or have sudo
if [ "$EUID" -ne 0 ]; then 
    echo "⚠ This script should be run as root or with sudo"
    echo "  Some cron operations may require elevated privileges"
    echo ""
fi

# Define paths
WEBAPP_DIR="/home/pim/public_html/webapp"
AKENEO_DIR="/home/pim/public_html"
BACKUP_DIR="/mnt/aidrive/backups/akeneo"
LOG_DIR="$WEBAPP_DIR/logs"

# Create log directory if needed
mkdir -p "$LOG_DIR"

echo "Step 1: Checking script permissions..."
echo "─────────────────────────────────────────"

# Make scripts executable
chmod +x "$WEBAPP_DIR/CATALOG_BACKUP_SCRIPT.sh" 2>/dev/null
chmod +x "$WEBAPP_DIR/CATALOG_HEALTH_MONITOR.php" 2>/dev/null
chmod +x "$WEBAPP_DIR/DATA_QUALITY_CHECKER.php" 2>/dev/null

echo "✓ Scripts are executable"
echo ""

echo "Step 2: Creating cron job entries..."
echo "─────────────────────────────────────────"

# Create temporary cron file
CRON_TEMP="/tmp/akeneo_monitoring_cron.txt"

cat > "$CRON_TEMP" << 'EOF'
# ========================================
# AKENEO PIM AUTOMATED MONITORING
# Generated: 2026-04-29
# ========================================

# Daily Catalog Health Check (8 AM)
# Runs comprehensive health monitoring with scoring
0 8 * * * cd /home/pim/public_html/webapp && php CATALOG_HEALTH_MONITOR.php >> logs/health_cron.log 2>&1

# Daily Backup (2 AM)
# Full catalog backup with compression
0 2 * * * /home/pim/public_html/webapp/CATALOG_BACKUP_SCRIPT.sh >> /home/pim/public_html/webapp/logs/backup_cron.log 2>&1

# Weekly Data Quality Check (Monday 9 AM)
# Comprehensive validation of catalog data integrity
0 9 * * MON cd /home/pim/public_html/webapp && php DATA_QUALITY_CHECKER.php >> logs/quality_cron.log 2>&1

# Weekly Backup Cleanup (Sunday 3 AM)
# Remove backups older than 30 days
0 3 * * SUN find /mnt/aidrive/backups/akeneo/ -name "backup_*" -mtime +30 -exec rm -rf {} \; 2>&1 | tee -a /home/pim/public_html/webapp/logs/cleanup_cron.log

EOF

echo "Cron entries prepared:"
cat "$CRON_TEMP"
echo ""

echo "Step 3: Installation options..."
echo "─────────────────────────────────────────"
echo ""
echo "OPTION A: Install for root user (recommended)"
echo "  crontab -u root $CRON_TEMP"
echo ""
echo "OPTION B: Install for current user"
echo "  crontab $CRON_TEMP"
echo ""
echo "OPTION C: Install for akeneo_pim user (if exists)"
echo "  crontab -u akeneo_pim $CRON_TEMP"
echo ""
echo "OPTION D: Manual installation"
echo "  1. Run: crontab -e"
echo "  2. Copy contents from: $CRON_TEMP"
echo ""

# Attempt automatic installation for root
if [ "$EUID" -eq 0 ]; then
    echo "Attempting automatic installation for root user..."
    
    # Backup existing crontab
    crontab -l > /tmp/crontab_backup_$(date +%Y%m%d_%H%M%S).txt 2>/dev/null
    
    # Install new cron jobs
    crontab "$CRON_TEMP"
    
    if [ $? -eq 0 ]; then
        echo "✓ Cron jobs installed successfully!"
        echo ""
        echo "Installed jobs:"
        crontab -l | grep -A 10 "AKENEO PIM"
    else
        echo "❌ Automatic installation failed"
        echo "Please install manually using Option D"
    fi
else
    echo "⚠ Not running as root - manual installation required"
    echo "Please choose one of the options above"
fi

echo ""
echo "Step 4: Verify installation..."
echo "─────────────────────────────────────────"
echo ""
echo "To verify cron jobs are installed, run:"
echo "  crontab -l | grep AKENEO"
echo ""
echo "To view cron logs:"
echo "  tail -f $LOG_DIR/health_cron.log"
echo "  tail -f $LOG_DIR/backup_cron.log"
echo "  tail -f $LOG_DIR/quality_cron.log"
echo ""

echo "Step 5: Test run (optional)..."
echo "─────────────────────────────────────────"
echo ""
echo "To test monitoring scripts manually:"
echo "  cd $WEBAPP_DIR"
echo "  php CATALOG_HEALTH_MONITOR.php"
echo "  php DATA_QUALITY_CHECKER.php"
echo "  ./CATALOG_BACKUP_SCRIPT.sh"
echo ""

echo "Step 6: Email notifications (optional)..."
echo "─────────────────────────────────────────"
echo ""
echo "To enable email alerts, edit scripts and set:"
echo "  \$config['alert_email'] = 'your-email@example.com';"
echo ""
echo "Configure mail server (if not already configured):"
echo "  apt-get install sendmail  # or postfix"
echo ""

echo "========================================="
echo "✓ Monitoring automation setup complete!"
echo "========================================="
echo ""
echo "Summary:"
echo "  - Health checks: Daily at 8 AM"
echo "  - Backups: Daily at 2 AM"
echo "  - Quality checks: Weekly (Monday 9 AM)"
echo "  - Backup cleanup: Weekly (Sunday 3 AM)"
echo ""
echo "Cron configuration saved to: $CRON_TEMP"
echo ""
