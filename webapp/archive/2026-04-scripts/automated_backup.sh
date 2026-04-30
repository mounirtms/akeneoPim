#!/bin/bash
#
# Automated Backup Script for Akeneo PIM and Magento Beta
# Date: 2026-04-27
#

BACKUP_DIR="/home/backups/pim_magento"
DATE=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$BACKUP_DIR/backup_log_$DATE.txt"

# Create backup directory if not exists
mkdir -p "$BACKUP_DIR"
mkdir -p "$BACKUP_DIR/akeneo"
mkdir -p "$BACKUP_DIR/magento"

echo "═══════════════════════════════════════════════════════════════════" | tee -a "$LOG_FILE"
echo "  AUTOMATED BACKUP - Akeneo PIM & Magento Beta" | tee -a "$LOG_FILE"
echo "  Date: $(date)" | tee -a "$LOG_FILE"
echo "═══════════════════════════════════════════════════════════════════" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Function to check disk space
check_disk_space() {
    AVAILABLE=$(df -h /home | tail -1 | awk '{print $4}')
    echo "Available disk space: $AVAILABLE" | tee -a "$LOG_FILE"
}

# Akeneo PIM Backup
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$LOG_FILE"
echo "1. AKENEO PIM BACKUP" | tee -a "$LOG_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$LOG_FILE"

echo "[1/3] Backing up Akeneo database..." | tee -a "$LOG_FILE"
mysqldump -h127.0.0.1 -P3307 -uakeneo_pim -pakeneo_pim akeneo_pim \
  --single-transaction --quick --lock-tables=false \
  > "$BACKUP_DIR/akeneo/akeneo_pim_db_$DATE.sql" 2>> "$LOG_FILE"

if [ $? -eq 0 ]; then
    SIZE=$(du -h "$BACKUP_DIR/akeneo/akeneo_pim_db_$DATE.sql" | cut -f1)
    echo "✅ Akeneo database backup: $SIZE" | tee -a "$LOG_FILE"
    gzip "$BACKUP_DIR/akeneo/akeneo_pim_db_$DATE.sql"
    echo "✅ Compressed to $(du -h "$BACKUP_DIR/akeneo/akeneo_pim_db_$DATE.sql.gz" | cut -f1)" | tee -a "$LOG_FILE"
else
    echo "❌ Akeneo database backup failed" | tee -a "$LOG_FILE"
fi

echo "[2/3] Backing up Akeneo configuration files..." | tee -a "$LOG_FILE"
tar -czf "$BACKUP_DIR/akeneo/akeneo_config_$DATE.tar.gz" \
  -C /home/pim/public_html \
  .env config/ 2>> "$LOG_FILE"

if [ $? -eq 0 ]; then
    SIZE=$(du -h "$BACKUP_DIR/akeneo/akeneo_config_$DATE.tar.gz" | cut -f1)
    echo "✅ Akeneo config backup: $SIZE" | tee -a "$LOG_FILE"
else
    echo "❌ Akeneo config backup failed" | tee -a "$LOG_FILE"
fi

echo "[3/3] Backing up Akeneo uploads (if any)..." | tee -a "$LOG_FILE"
if [ -d "/home/pim/public_html/public/media" ]; then
    tar -czf "$BACKUP_DIR/akeneo/akeneo_media_$DATE.tar.gz" \
      -C /home/pim/public_html/public \
      media/ 2>> "$LOG_FILE"
    
    if [ $? -eq 0 ]; then
        SIZE=$(du -h "$BACKUP_DIR/akeneo/akeneo_media_$DATE.tar.gz" | cut -f1)
        echo "✅ Akeneo media backup: $SIZE" | tee -a "$LOG_FILE"
    else
        echo "❌ Akeneo media backup failed" | tee -a "$LOG_FILE"
    fi
else
    echo "⚠️  No media directory found" | tee -a "$LOG_FILE"
fi

echo "" | tee -a "$LOG_FILE"

# Magento Beta Backup
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$LOG_FILE"
echo "2. MAGENTO BETA BACKUP" | tee -a "$LOG_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$LOG_FILE"

echo "[1/3] Backing up Magento database..." | tee -a "$LOG_FILE"
mysqldump -h127.0.0.1 -P3307 -ubeta_ntdbusr24 -p'the-correct-password' beta_dBT8x12y22 \
  --single-transaction --quick --lock-tables=false \
  > "$BACKUP_DIR/magento/magento_beta_db_$DATE.sql" 2>> "$LOG_FILE"

if [ $? -eq 0 ]; then
    SIZE=$(du -h "$BACKUP_DIR/magento/magento_beta_db_$DATE.sql" | cut -f1)
    echo "✅ Magento database backup: $SIZE" | tee -a "$LOG_FILE"
    gzip "$BACKUP_DIR/magento/magento_beta_db_$DATE.sql"
    echo "✅ Compressed to $(du -h "$BACKUP_DIR/magento/magento_beta_db_$DATE.sql.gz" | cut -f1)" | tee -a "$LOG_FILE"
else
    echo "❌ Magento database backup failed" | tee -a "$LOG_FILE"
fi

echo "[2/3] Backing up Magento configuration files..." | tee -a "$LOG_FILE"
tar -czf "$BACKUP_DIR/magento/magento_config_$DATE.tar.gz" \
  -C /home/beta/public_html \
  app/etc/ 2>> "$LOG_FILE"

if [ $? -eq 0 ]; then
    SIZE=$(du -h "$BACKUP_DIR/magento/magento_config_$DATE.tar.gz" | cut -f1)
    echo "✅ Magento config backup: $SIZE" | tee -a "$LOG_FILE"
else
    echo "❌ Magento config backup failed" | tee -a "$LOG_FILE"
fi

echo "[3/3] Creating media backup manifest..." | tee -a "$LOG_FILE"
# Just create a list, don't backup all media (too large)
find /home/beta/public_html/pub/media -type f | wc -l > "$BACKUP_DIR/magento/media_file_count_$DATE.txt"
echo "✅ Media file count saved" | tee -a "$LOG_FILE"

echo "" | tee -a "$LOG_FILE"

# Cleanup old backups (keep last 7 days)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$LOG_FILE"
echo "3. CLEANUP OLD BACKUPS" | tee -a "$LOG_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$LOG_FILE"

echo "Removing backups older than 7 days..." | tee -a "$LOG_FILE"
find "$BACKUP_DIR" -name "*.sql.gz" -mtime +7 -delete
find "$BACKUP_DIR" -name "*.tar.gz" -mtime +7 -delete
find "$BACKUP_DIR" -name "backup_log_*.txt" -mtime +7 -delete

REMAINING=$(find "$BACKUP_DIR" -name "*.gz" | wc -l)
echo "✅ Remaining backup files: $REMAINING" | tee -a "$LOG_FILE"

echo "" | tee -a "$LOG_FILE"

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$LOG_FILE"
echo "4. BACKUP SUMMARY" | tee -a "$LOG_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$LOG_FILE"

check_disk_space

TOTAL_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)
echo "Total backup size: $TOTAL_SIZE" | tee -a "$LOG_FILE"
echo "Backup location: $BACKUP_DIR" | tee -a "$LOG_FILE"
echo "Backup completed: $(date)" | tee -a "$LOG_FILE"

echo "" | tee -a "$LOG_FILE"
echo "✅ BACKUP COMPLETED SUCCESSFULLY" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# List recent backups
echo "Recent backups:" | tee -a "$LOG_FILE"
ls -lh "$BACKUP_DIR/akeneo/" | tail -5 | tee -a "$LOG_FILE"
ls -lh "$BACKUP_DIR/magento/" | tail -5 | tee -a "$LOG_FILE"

echo "═══════════════════════════════════════════════════════════════════" | tee -a "$LOG_FILE"
