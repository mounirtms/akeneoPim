#!/bin/bash
# Pre-Import Backup - Safety measure before image import

echo "=========================================="
echo "PRE-IMPORT BACKUP"
echo "=========================================="
echo "Date: $(date)"
echo ""

BACKUP_DIR="/home/pim/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DB_BACKUP="$BACKUP_DIR/pre_image_import_${TIMESTAMP}.sql.gz"

echo "Creating database backup before image import..."
/opt/mariadb10.6/mariadb/bin/mysqldump \
    -u root \
    -p'YourNewStrongPassword' \
    -h 127.0.0.1 \
    -P 3307 \
    --single-transaction \
    --quick \
    akeneo_pim | gzip > "$DB_BACKUP"

if [ $? -eq 0 ]; then
    SIZE=$(ls -lh "$DB_BACKUP" | awk '{print $5}')
    echo "✓ Backup created: $DB_BACKUP ($SIZE)"
else
    echo "✗ Backup failed!"
    exit 1
fi

echo ""
echo "Current database state:"
/opt/mariadb10.6/mariadb/bin/mysql -u root -p'YourNewStrongPassword' -h 127.0.0.1 -P 3307 akeneo_pim -e "
SELECT 
    'File records before import' as status,
    COUNT(*) as count
FROM akeneo_file_storage_file_info;
"

echo ""
echo "✓ Backup complete. Safe to proceed with import."
echo ""
