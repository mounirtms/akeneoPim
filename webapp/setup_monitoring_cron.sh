#!/bin/bash
# Automated Monitoring Cron Setup Script
# Date: 2026-04-30
# Purpose: Install automated monitoring and maintenance cron jobs

SCRIPT_DIR="/home/pim/public_html/webapp"
LOG_DIR="$SCRIPT_DIR/logs"

echo "=========================================="
echo "Akeneo PIM Automated Monitoring Setup"
echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=========================================="
echo ""

# Create log directory
mkdir -p "$LOG_DIR"

# Backup existing crontab
echo "Backing up existing crontab..."
crontab -l > "$SCRIPT_DIR/crontab_backup_$(date +%Y%m%d_%H%M%S).txt" 2>/dev/null || echo "No existing crontab"

# Create new crontab entries
cat > "$SCRIPT_DIR/akeneo_monitoring_crontab.txt" << 'EOF'
# Akeneo PIM Automated Monitoring & Maintenance
# Installed: 2026-04-30

# Daily health check - runs at 2:00 AM
0 2 * * * /home/pim/public_html/webapp/quick_health_check.sh >> /home/pim/public_html/webapp/logs/daily_health_$(date +\%Y\%m\%d).log 2>&1

# Weekly Elasticsearch optimization - runs Sunday at 3:00 AM
0 3 * * 0 /home/pim/public_html/webapp/optimize_elasticsearch.sh >> /home/pim/public_html/webapp/logs/weekly_optimization_$(date +\%Y\%m\%d).log 2>&1

# Weekly quality tests - runs Sunday at 4:00 AM
0 4 * * 0 /home/pim/public_html/webapp/quality_performance_tests.sh >> /home/pim/public_html/webapp/logs/weekly_quality_$(date +\%Y\%m\%d).log 2>&1

# Monthly Magento export - runs 1st of month at 1:00 AM
0 1 1 * * /home/pim/public_html/webapp/magento_export_sync.sh >> /home/pim/public_html/webapp/logs/monthly_export_$(date +\%Y\%m\%d).log 2>&1

# Bi-weekly completeness calculation - runs every other Sunday at 5:00 AM
0 5 */14 * * cd /home/pim/public_html && php bin/console pim:completeness:calculate --env=prod >> /home/pim/public_html/webapp/logs/completeness_$(date +\%Y\%m\%d).log 2>&1

# Weekly product reindex - runs Saturday at 2:00 AM
0 2 * * 6 cd /home/pim/public_html && php bin/console pim:product:index --all --env=prod >> /home/pim/public_html/webapp/logs/reindex_$(date +\%Y\%m\%d).log 2>&1

# Daily log cleanup (remove logs older than 30 days) - runs at 1:00 AM
0 1 * * * find /home/pim/public_html/webapp/logs -name "*.log" -mtime +30 -delete

# Weekly disk space check - runs Monday at 6:00 AM
0 6 * * 1 df -h /home/pim/public_html > /home/pim/public_html/webapp/logs/disk_space_$(date +\%Y\%m\%d).log 2>&1
EOF

echo "Cron jobs configured:"
echo ""
cat "$SCRIPT_DIR/akeneo_monitoring_crontab.txt"
echo ""

# Installation instructions
cat > "$SCRIPT_DIR/CRON_INSTALLATION_GUIDE.md" << 'EOF'
# Akeneo PIM Cron Jobs Installation Guide

## Overview
This guide explains how to install automated monitoring and maintenance cron jobs for Akeneo PIM.

## Cron Jobs Schedule

### Daily Tasks
- **02:00 AM** - Health check (system status monitoring)
- **01:00 AM** - Log cleanup (removes logs older than 30 days)

### Weekly Tasks
- **Sunday 03:00 AM** - Elasticsearch optimization
- **Sunday 04:00 AM** - Quality & performance tests
- **Saturday 02:00 AM** - Product reindex
- **Monday 06:00 AM** - Disk space check

### Bi-Weekly Tasks
- **Every other Sunday 05:00 AM** - Completeness calculation

### Monthly Tasks
- **1st day 01:00 AM** - Magento export generation

## Installation Methods

### Method 1: Automatic Installation (Recommended)
```bash
cd /home/pim/public_html/webapp
cat akeneo_monitoring_crontab.txt | crontab -
```

### Method 2: Manual Installation
```bash
# Open crontab editor
crontab -e

# Copy and paste the contents from akeneo_monitoring_crontab.txt
# Save and exit
```

### Method 3: Append to Existing Crontab
```bash
cd /home/pim/public_html/webapp
crontab -l > current_crontab.txt
cat akeneo_monitoring_crontab.txt >> current_crontab.txt
crontab current_crontab.txt
```

## Verification

### Check Installed Cron Jobs
```bash
crontab -l
```

### View Cron Logs
```bash
# System cron log
tail -f /var/log/cron

# Application logs
tail -f /home/pim/public_html/webapp/logs/daily_health_*.log
```

### Test Cron Job Execution
```bash
# Run a script manually to test
/home/pim/public_html/webapp/quick_health_check.sh
```

## Log Files Location

All automated task logs are stored in:
```
/home/pim/public_html/webapp/logs/
```

### Log File Naming Convention
- Daily health: `daily_health_YYYYMMDD.log`
- Weekly optimization: `weekly_optimization_YYYYMMDD.log`
- Weekly quality: `weekly_quality_YYYYMMDD.log`
- Monthly export: `monthly_export_YYYYMMDD.log`
- Completeness: `completeness_YYYYMMDD.log`
- Reindex: `reindex_YYYYMMDD.log`
- Disk space: `disk_space_YYYYMMDD.log`

## Customization

### Change Execution Time
Edit `akeneo_monitoring_crontab.txt` and modify the time fields:
```
Minute Hour Day Month DayOfWeek Command
  |     |    |    |       |
  0     2    *    *       *  (02:00 AM every day)
```

### Disable Specific Tasks
Comment out the line with `#`:
```bash
# 0 2 * * * /home/pim/public_html/webapp/quick_health_check.sh
```

### Add Custom Tasks
Add new lines following the same format:
```bash
0 12 * * * /path/to/custom/script.sh >> /path/to/log.log 2>&1
```

## Troubleshooting

### Cron Jobs Not Running
1. Check if cron service is running:
   ```bash
   systemctl status cron
   # or
   service cron status
   ```

2. Check cron logs:
   ```bash
   tail -f /var/log/cron
   ```

3. Verify script permissions:
   ```bash
   chmod +x /home/pim/public_html/webapp/*.sh
   ```

### Script Execution Errors
1. Run script manually to see errors:
   ```bash
   /home/pim/public_html/webapp/quick_health_check.sh
   ```

2. Check log file for errors:
   ```bash
   tail -100 /home/pim/public_html/webapp/logs/daily_health_*.log
   ```

### Email Notifications (Optional)
To receive email notifications, add `MAILTO` at the top:
```bash
MAILTO=admin@technostationery.com
```

## Best Practices

1. **Monitor Logs Regularly** - Review logs weekly
2. **Adjust Timing** - Schedule during low-traffic hours
3. **Backup Before Changes** - Always backup crontab before editing
4. **Test First** - Run scripts manually before scheduling
5. **Keep Scripts Updated** - Update paths if moving installation

## Removal

To remove all monitoring cron jobs:
```bash
# Backup current crontab
crontab -l > crontab_backup.txt

# Edit and remove Akeneo monitoring lines
crontab -e
```

Or restore from backup:
```bash
crontab crontab_backup_YYYYMMDD_HHMMSS.txt
```

## Support

For issues or questions:
- Check logs in `/home/pim/public_html/webapp/logs/`
- Review script execution manually
- Verify file permissions and paths
- Consult system administrator

---

**Installation Date:** 2026-04-30  
**Version:** 1.0  
**Status:** Ready for installation
EOF

echo "✅ Installation guide created: CRON_INSTALLATION_GUIDE.md"
echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "Next Steps:"
echo "1. Review the cron jobs in: akeneo_monitoring_crontab.txt"
echo "2. Install using: cat akeneo_monitoring_crontab.txt | crontab -"
echo "3. Verify installation: crontab -l"
echo "4. Read full guide: CRON_INSTALLATION_GUIDE.md"
echo ""
echo "Scripts ready for automation:"
echo "  - quick_health_check.sh"
echo "  - optimize_elasticsearch.sh"
echo "  - quality_performance_tests.sh"
echo "  - magento_export_sync.sh"
echo ""
echo "All scripts are executable and tested."
echo "=========================================="
