#!/bin/bash
# Setup Automated Database Backups
# Date: 2026-04-23

echo "=========================================="
echo "SETTING UP AUTOMATED BACKUPS"
echo "=========================================="
echo ""

# Create backup directory if it doesn't exist
mkdir -p /home/pim/backups

# Create backup script
cat > /home/pim/backups/daily_backup.sh << 'BACKUP_SCRIPT'
#!/bin/bash
# Daily Automated Backup Script for Akeneo PIM
# Runs daily at 2:00 AM

BACKUP_DIR="/home/pim/backups"
DATE=$(date +%Y%m%d_%H%M%S)
DB_BACKUP="$BACKUP_DIR/akeneo_backup_$DATE.sql.gz"
FILES_BACKUP="$BACKUP_DIR/akeneo_files_$DATE.tar.gz"

# Keep backups for 7 days
RETENTION_DAYS=7

echo "=== Akeneo PIM Backup Started: $(date) ==="

# 1. Backup MariaDB database
echo "Backing up database..."
/opt/mariadb10.6/mariadb/bin/mysqldump \
    -u root \
    -p'YourNewStrongPassword' \
    -h 127.0.0.1 \
    -P 3307 \
    --single-transaction \
    --quick \
    --lock-tables=false \
    akeneo_pim | gzip > "$DB_BACKUP"

if [ $? -eq 0 ]; then
    DB_SIZE=$(ls -lh "$DB_BACKUP" | awk '{print $5}')
    echo "✓ Database backup completed: $DB_BACKUP ($DB_SIZE)"
else
    echo "✗ Database backup failed!"
fi

# 2. Backup file storage (catalog images)
echo "Backing up file storage..."
cd /home/pim/public_html
tar -czf "$FILES_BACKUP" \
    var/file_storage/catalog/ \
    2>/dev/null

if [ $? -eq 0 ]; then
    FILES_SIZE=$(ls -lh "$FILES_BACKUP" | awk '{print $5}')
    echo "✓ Files backup completed: $FILES_BACKUP ($FILES_SIZE)"
else
    echo "✗ Files backup failed!"
fi

# 3. Clean up old backups (keep last 7 days)
echo "Cleaning up old backups (retention: $RETENTION_DAYS days)..."
find "$BACKUP_DIR" -name "akeneo_backup_*.sql.gz" -mtime +$RETENTION_DAYS -delete
find "$BACKUP_DIR" -name "akeneo_files_*.tar.gz" -mtime +$RETENTION_DAYS -delete
echo "✓ Old backups removed"

# 4. Summary
echo ""
echo "=== Backup Summary ==="
echo "Database backup: $DB_BACKUP"
echo "Files backup: $FILES_BACKUP"
echo "Total backups in directory: $(ls -1 $BACKUP_DIR/*.gz 2>/dev/null | wc -l)"
echo "Disk usage: $(du -sh $BACKUP_DIR | awk '{print $1}')"
echo ""
echo "=== Backup Completed: $(date) ==="
BACKUP_SCRIPT

chmod +x /home/pim/backups/daily_backup.sh
echo "✓ Backup script created: /home/pim/backups/daily_backup.sh"
echo ""

# Create cron job
CRON_JOB="0 2 * * * /home/pim/backups/daily_backup.sh >> /home/pim/backups/backup.log 2>&1"

# Check if cron job already exists
if crontab -l 2>/dev/null | grep -q "daily_backup.sh"; then
    echo "✓ Cron job already exists"
else
    echo "Adding cron job..."
    (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
    echo "✓ Cron job added: Daily backup at 2:00 AM"
fi

echo ""
echo "Current cron jobs:"
crontab -l | grep -v "^#"
echo ""

# Test backup script
echo "=== Running Test Backup ==="
bash /home/pim/backups/daily_backup.sh
echo ""

echo "=========================================="
echo "AUTOMATED BACKUPS CONFIGURED"
echo "=========================================="
echo ""
echo "Backup Configuration:"
echo "- Schedule: Daily at 2:00 AM"
echo "- Retention: 7 days"
echo "- Location: /home/pim/backups/"
echo "- Log file: /home/pim/backups/backup.log"
echo ""
echo "Manual backup command:"
echo "  bash /home/pim/backups/daily_backup.sh"
echo ""
echo "View backup log:"
echo "  tail -f /home/pim/backups/backup.log"
echo ""
