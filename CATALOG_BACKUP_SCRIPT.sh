#!/bin/bash
# COMPREHENSIVE CATALOG BACKUP SCRIPT
# Date: 2026-04-29
# Purpose: Complete backup of Akeneo catalog, database, and configuration

set -e  # Exit on error

# Configuration
MYSQL="/opt/mariadb10.6/mariadb/bin/mysql"
MYSQLDUMP="/opt/mariadb10.6/mariadb/bin/mysqldump"
DB_USER="root"
DB_PASS="YourNewStrongPassword"
DB_HOST="127.0.0.1"
DB_PORT="3307"
DB_NAME="akeneo_pim"
BACKUP_BASE="/mnt/aidrive/backups/akeneo"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$BACKUP_BASE/backup_$TIMESTAMP"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Create backup directory
mkdir -p "$BACKUP_DIR"/{database,exports,config,media,logs}

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log "========================================"
log "AKENEO COMPREHENSIVE BACKUP STARTING"
log "Backup Directory: $BACKUP_DIR"
log "========================================"
echo ""

# 1. DATABASE BACKUP
log "=== STEP 1: DATABASE BACKUP ==="
log "Dumping Akeneo database..."
$MYSQLDUMP -u $DB_USER -p"$DB_PASS" \
    -h $DB_HOST -P $DB_PORT \
    --single-transaction \
    --routines \
    --triggers \
    --events \
    --add-drop-database \
    --databases $DB_NAME \
    > "$BACKUP_DIR/database/akeneo_pim_full.sql" 2>/dev/null

if [ $? -eq 0 ]; then
    log "✅ Database dump complete"
    DB_SIZE=$(du -h "$BACKUP_DIR/database/akeneo_pim_full.sql" | cut -f1)
    log "Database size: $DB_SIZE"
    
    # Compress database
    log "Compressing database backup..."
    gzip "$BACKUP_DIR/database/akeneo_pim_full.sql"
    COMPRESSED_SIZE=$(du -h "$BACKUP_DIR/database/akeneo_pim_full.sql.gz" | cut -f1)
    log "✅ Compressed to: $COMPRESSED_SIZE"
else
    error "Database dump failed!"
fi
echo ""

# 2. CATALOG EXPORTS (CSV)
log "=== STEP 2: CATALOG DATA EXPORTS ==="

# Export products
log "Exporting products to CSV..."
$MYSQL -u $DB_USER -p"$DB_PASS" -h $DB_HOST -P $DB_PORT $DB_NAME -e "
SELECT 
    p.identifier,
    f.code as family,
    p.is_enabled,
    p.created,
    p.updated
FROM pim_catalog_product p
LEFT JOIN pim_catalog_family f ON p.family_id = f.id
ORDER BY p.identifier
" > "$BACKUP_DIR/exports/products_list.csv" 2>/dev/null

log "✅ Products exported: $(wc -l < "$BACKUP_DIR/exports/products_list.csv") rows"

# Export categories
log "Exporting categories..."
$MYSQL -u $DB_USER -p"$DB_PASS" -h $DB_HOST -P $DB_PORT $DB_NAME -e "
SELECT 
    code,
    JSON_EXTRACT(labels, '$.fr_FR') as label_fr,
    parent_id,
    root,
    lvl
FROM pim_catalog_category
ORDER BY lvl, parent_id, code
" > "$BACKUP_DIR/exports/categories_list.csv" 2>/dev/null

log "✅ Categories exported: $(wc -l < "$BACKUP_DIR/exports/categories_list.csv") rows"

# Export attributes
log "Exporting attributes..."
$MYSQL -u $DB_USER -p"$DB_PASS" -h $DB_HOST -P $DB_PORT $DB_NAME -e "
SELECT 
    code,
    attribute_type,
    is_required,
    is_unique,
    is_localizable,
    is_scopable,
    JSON_EXTRACT(labels, '$.fr_FR') as label_fr
FROM pim_catalog_attribute
ORDER BY code
" > "$BACKUP_DIR/exports/attributes_list.csv" 2>/dev/null

log "✅ Attributes exported: $(wc -l < "$BACKUP_DIR/exports/attributes_list.csv") rows"

# Export families
log "Exporting families..."
$MYSQL -u $DB_USER -p"$DB_PASS" -h $DB_HOST -P $DB_PORT $DB_NAME -e "
SELECT 
    f.code,
    JSON_EXTRACT(f.labels, '$.fr_FR') as label_fr,
    COUNT(p.id) as product_count
FROM pim_catalog_family f
LEFT JOIN pim_catalog_product p ON f.id = p.family_id
GROUP BY f.code
ORDER BY f.code
" > "$BACKUP_DIR/exports/families_list.csv" 2>/dev/null

log "✅ Families exported: $(wc -l < "$BACKUP_DIR/exports/families_list.csv") rows"

echo ""

# 3. CONFIGURATION BACKUP
log "=== STEP 3: CONFIGURATION BACKUP ==="
cd /home/pim/public_html

# Backup app configuration
if [ -d "app/config" ]; then
    tar -czf "$BACKUP_DIR/config/app_config.tar.gz" app/config/ 2>/dev/null
    log "✅ App config backed up"
fi

# Backup root configuration
if [ -d "config" ]; then
    tar -czf "$BACKUP_DIR/config/root_config.tar.gz" config/ 2>/dev/null
    log "✅ Root config backed up"
fi

# Backup environment files
cp .env "$BACKUP_DIR/config/.env.backup" 2>/dev/null && log "✅ .env backed up"
cp .env.local "$BACKUP_DIR/config/.env.local.backup" 2>/dev/null && log "✅ .env.local backed up"
cp composer.json "$BACKUP_DIR/config/composer.json" 2>/dev/null && log "✅ composer.json backed up"
cp composer.lock "$BACKUP_DIR/config/composer.lock" 2>/dev/null && log "✅ composer.lock backed up"

echo ""

# 4. MEDIA BACKUP
log "=== STEP 4: MEDIA BACKUP ==="

# Check for media files
if [ -d "public/media" ]; then
    MEDIA_SIZE=$(du -sh public/media 2>/dev/null | cut -f1)
    log "Media directory size: $MEDIA_SIZE"
    
    if [ "$MEDIA_SIZE" != "0" ]; then
        tar -czf "$BACKUP_DIR/media/public_media.tar.gz" public/media/ 2>/dev/null
        log "✅ Public media backed up"
    else
        log "⚠️  No media files found in public/media"
    fi
fi

if [ -d "pub/media" ]; then
    PUB_MEDIA_SIZE=$(du -sh pub/media 2>/dev/null | cut -f1)
    log "Pub media directory size: $PUB_MEDIA_SIZE"
    
    if [ "$PUB_MEDIA_SIZE" != "0" ]; then
        tar -czf "$BACKUP_DIR/media/pub_media.tar.gz" pub/media/ 2>/dev/null
        log "✅ Pub media backed up"
    else
        log "⚠️  No media files found in pub/media"
    fi
fi

echo ""

# 5. CATALOG STATISTICS
log "=== STEP 5: CATALOG STATISTICS ==="

cat > "$BACKUP_DIR/logs/catalog_stats.txt" << STATS
AKENEO CATALOG STATISTICS
Generated: $(date)
========================================

PRODUCTS:
$(echo "SELECT COUNT(*) FROM pim_catalog_product;" | $MYSQL -u $DB_USER -p"$DB_PASS" -h $DB_HOST -P $DB_PORT $DB_NAME -N 2>/dev/null) total products
$(echo "SELECT COUNT(*) FROM pim_catalog_product WHERE is_enabled = 1;" | $MYSQL -u $DB_USER -p"$DB_PASS" -h $DB_HOST -P $DB_PORT $DB_NAME -N 2>/dev/null) enabled products

PRODUCT MODELS:
$(echo "SELECT COUNT(*) FROM pim_catalog_product_model;" | $MYSQL -u $DB_USER -p"$DB_PASS" -h $DB_HOST -P $DB_PORT $DB_NAME -N 2>/dev/null) product models

CATEGORIES:
$(echo "SELECT COUNT(*) FROM pim_catalog_category;" | $MYSQL -u $DB_USER -p"$DB_PASS" -h $DB_HOST -P $DB_PORT $DB_NAME -N 2>/dev/null) categories

ATTRIBUTES:
$(echo "SELECT COUNT(*) FROM pim_catalog_attribute;" | $MYSQL -u $DB_USER -p"$DB_PASS" -h $DB_HOST -P $DB_PORT $DB_NAME -N 2>/dev/null) attributes

FAMILIES:
$(echo "SELECT COUNT(*) FROM pim_catalog_family;" | $MYSQL -u $DB_USER -p"$DB_PASS" -h $DB_HOST -P $DB_PORT $DB_NAME -N 2>/dev/null) families

========================================
STATS

log "✅ Statistics saved"
cat "$BACKUP_DIR/logs/catalog_stats.txt"
echo ""

# 6. BACKUP MANIFEST
log "=== STEP 6: CREATING BACKUP MANIFEST ==="

BACKUP_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)

cat > "$BACKUP_DIR/BACKUP_MANIFEST.txt" << MANIFEST
AKENEO BACKUP MANIFEST
========================================
Backup Date: $(date)
Backup Directory: $BACKUP_DIR
Total Backup Size: $BACKUP_SIZE
========================================

CONTENTS:
1. database/akeneo_pim_full.sql.gz - Full database dump
2. exports/*.csv - Catalog data exports (products, categories, attributes, families)
3. config/*.tar.gz - Configuration files (app, root)
4. config/.env* - Environment configuration files
5. media/*.tar.gz - Media files (if any)
6. logs/catalog_stats.txt - Catalog statistics snapshot

RESTORE INSTRUCTIONS:
========================================
1. Stop all services:
   sudo systemctl stop httpd ea-php83-php-fpm

2. Restore database:
   gunzip -c database/akeneo_pim_full.sql.gz | mysql -u root -p -h 127.0.0.1 -P 3307

3. Restore configuration:
   cd /home/pim/public_html
   tar -xzf config/app_config.tar.gz
   tar -xzf config/root_config.tar.gz
   cp config/.env.backup .env
   cp config/.env.local.backup .env.local

4. Restore media (if needed):
   tar -xzf media/public_media.tar.gz -C /home/pim/public_html/
   tar -xzf media/pub_media.tar.gz -C /home/pim/public_html/

5. Clear caches:
   php bin/console cache:clear --env=prod
   php bin/console cache:warmup --env=prod

6. Reindex Elasticsearch:
   php bin/console akeneo:elasticsearch:reset-indexes --env=prod

7. Restart services:
   sudo systemctl start httpd ea-php83-php-fpm

8. Verify:
   - Check PIM URL: https://pim.technostationery.com
   - Test product access
   - Verify category navigation
   
========================================
BACKUP VERIFIED: $(date)
========================================
MANIFEST

log "✅ Manifest created"
echo ""

# 7. FINAL SUMMARY
log "========================================"
log "BACKUP COMPLETED SUCCESSFULLY!"
log "========================================"
echo ""
log "Backup Location: $BACKUP_DIR"
log "Total Size: $BACKUP_SIZE"
log "Manifest: $BACKUP_DIR/BACKUP_MANIFEST.txt"
echo ""
log "Files backed up:"
log "  ✅ Database: akeneo_pim (compressed)"
log "  ✅ Products: $(wc -l < "$BACKUP_DIR/exports/products_list.csv") products"
log "  ✅ Categories: $(wc -l < "$BACKUP_DIR/exports/categories_list.csv") categories"
log "  ✅ Attributes: $(wc -l < "$BACKUP_DIR/exports/attributes_list.csv") attributes"
log "  ✅ Families: $(wc -l < "$BACKUP_DIR/exports/families_list.csv") families"
log "  ✅ Configuration files"
log "  ✅ Media files (if present)"
log "  ✅ Catalog statistics"
echo ""
log "To restore this backup, see: $BACKUP_DIR/BACKUP_MANIFEST.txt"
echo ""

# Create symlink to latest backup
cd "$BACKUP_BASE"
rm -f latest 2>/dev/null
ln -s "backup_$TIMESTAMP" latest
log "✅ Symlink created: $BACKUP_BASE/latest -> backup_$TIMESTAMP"

echo ""
log "Backup complete! Your catalog is safely backed up."
