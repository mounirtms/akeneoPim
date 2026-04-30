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
