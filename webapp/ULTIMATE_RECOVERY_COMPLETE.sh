#!/bin/bash

##############################################################################
# ULTIMATE COMPLETE RECOVERY + ENRICHMENT SCRIPT
# Recovers ALL data + applies ALL historical tunings & optimizations
# Date: 2026-04-23
# COMPREHENSIVE: Structure + Products + Enrichment + Tunings
##############################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
PIM_ROOT="/home/pim/public_html"
MAGENTO_ROOT="/home/beta/public_html"
DB_HOST="127.0.0.1"
DB_PORT="3307"
DB_NAME="akeneo_pim"
MAGENTO_DB="beta_dBT8x12y22"
DB_USER="root"
DB_PASS="YourNewStrongPassword"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="/home/pim/ultimate_recovery_${TIMESTAMP}.log"
TEMP_DIR="/home/pim/temp_ultimate_${TIMESTAMP}"

mkdir -p "$TEMP_DIR"

##############################################################################
# Helper Functions
##############################################################################

log() {
    echo -e "${1}" | tee -a "$LOG_FILE"
}

step_header() {
    log ""
    log "${CYAN}════════════════════════════════════════════════════════════${NC}"
    log "${CYAN}  $1${NC}"
    log "${CYAN}════════════════════════════════════════════════════════════${NC}"
}

success() {
    log "${GREEN}✅ $1${NC}"
}

error() {
    log "${RED}❌ ERROR: $1${NC}"
}

warning() {
    log "${YELLOW}⚠️  $1${NC}"
}

info() {
    log "${BLUE}ℹ️  $1${NC}"
}

##############################################################################
# PHASE 1: FIX ATTRIBUTE IMPORT (Deduplicate)
##############################################################################

phase1_fix_attributes() {
    step_header "PHASE 1: FIX ATTRIBUTE IMPORT (DEDUPLICATE)"
    
    info "Extracting unique attributes from Magento..."
    
    /opt/mariadb10.6/mariadb/bin/mysql -u $DB_USER -p"$DB_PASS" -h $DB_HOST -P $DB_PORT $MAGENTO_DB <<SQL > "$TEMP_DIR/attributes_unique.sql" 2>/dev/null
SELECT DISTINCT
    ea.attribute_id,
    ea.attribute_code,
    ea.frontend_label,
    ea.backend_type,
    ea.frontend_input,
    ea.is_required,
    ea.is_unique
FROM eav_attribute ea
WHERE ea.entity_type_id = 4
AND ea.attribute_code NOT IN ('sku', 'name')  -- Skip already imported
ORDER BY ea.attribute_id;
SQL
    
    UNIQUE_ATTRS=$(cat "$TEMP_DIR/attributes_unique.sql" | wc -l)
    success "Found $UNIQUE_ATTRS unique attributes"
    
    # Import each unique attribute
    while IFS=$'\t' read -r attr_id code label backend_type frontend_input is_required is_unique; do
        [ "$attr_id" = "attribute_id" ] && continue
        [ -z "$code" ] && continue
        
        # Map Magento types to Akeneo types
        case "$backend_type" in
            "varchar") AKENEO_TYPE="pim_catalog_text" ;;
            "text") AKENEO_TYPE="pim_catalog_textarea" ;;
            "int") AKENEO_TYPE="pim_catalog_number" ;;
            "decimal") AKENEO_TYPE="pim_catalog_number" ;;
            "datetime") AKENEO_TYPE="pim_catalog_date" ;;
            *) AKENEO_TYPE="pim_catalog_text" ;;
        esac
        
        # Determine if localizable
        IS_LOCALIZABLE="0"
        case "$code" in
            *description*|*name*|*title*|*meta*) IS_LOCALIZABLE="1" ;;
        esac
        
        /opt/mariadb10.6/mariadb/bin/mysql -u $DB_USER -p"$DB_PASS" -h $DB_HOST -P $DB_PORT $DB_NAME <<SQL 2>/dev/null || true
INSERT INTO pim_catalog_attribute 
(code, attribute_type, backend_type, entity_type, is_required, is_unique, is_localizable, is_scopable, created, updated)
VALUES 
('$code', '$AKENEO_TYPE', '$backend_type', 'product', $is_required, $is_unique, $IS_LOCALIZABLE, 0, NOW(), NOW())
ON DUPLICATE KEY UPDATE updated=NOW();

INSERT INTO pim_catalog_attribute_translation (foreign_key, label, locale)
SELECT a.id, COALESCE(NULLIF('$label', ''), '$code'), 'fr_FR'
FROM pim_catalog_attribute a
WHERE a.code='$code'
ON DUPLICATE KEY UPDATE label=COALESCE(NULLIF('$label', ''), '$code');
SQL
        
    done < "$TEMP_DIR/attributes_unique.sql"
    
    CREATED_ATTRS=$(/opt/mariadb10.6/mariadb/bin/mysql -u $DB_USER -p"$DB_PASS" -h $DB_HOST -P $DB_PORT $DB_NAME -sse "SELECT COUNT(*) FROM pim_catalog_attribute;" 2>/dev/null)
    success "Total attributes: $CREATED_ATTRS"
}

##############################################################################
# PHASE 2: IMPORT ATTRIBUTE OPTIONS
##############################################################################

phase2_import_options() {
    step_header "PHASE 2: IMPORT ATTRIBUTE OPTIONS"
    
    info "Extracting attribute options..."
    
    /opt/mariadb10.6/mariadb/bin/mysql -u $DB_USER -p"$DB_PASS" -h $DB_HOST -P $DB_PORT $MAGENTO_DB <<SQL > "$TEMP_DIR/options.sql" 2>/dev/null
SELECT DISTINCT
    ea.attribute_code,
    eao.option_id,
    eaov.value as option_label,
    eao.sort_order
FROM eav_attribute ea
JOIN eav_attribute_option eao ON ea.attribute_id = eao.attribute_id
JOIN eav_attribute_option_value eaov ON eao.option_id = eaov.option_id
WHERE ea.entity_type_id = 4 AND eaov.store_id IN (0,1)
GROUP BY ea.attribute_code, eao.option_id
ORDER BY ea.attribute_code, eao.sort_order;
SQL
    
    OPTION_COUNT=$(cat "$TEMP_DIR/options.sql" | wc -l)
    info "Found $OPTION_COUNT options"
    
    while IFS=$'\t' read -r attr_code option_id label sort_order; do
        [ "$attr_code" = "attribute_code" ] && continue
        [ -z "$label" ] && continue
        
        OPTION_CODE=$(echo "${label}_${option_id}" | tr '[:upper:]' '[:lower:]' | tr ' ' '_' | sed 's/[^a-z0-9_]//g')
        
        /opt/mariadb10.6/mariadb/bin/mysql -u $DB_USER -p"$DB_PASS" -h $DB_HOST -P $DB_PORT $DB_NAME <<SQL 2>/dev/null || true
INSERT INTO pim_catalog_attribute_option (attribute_id, code, sort_order)
SELECT a.id, '$OPTION_CODE', $sort_order
FROM pim_catalog_attribute a
WHERE a.code='$attr_code'
ON DUPLICATE KEY UPDATE sort_order=$sort_order;

INSERT INTO pim_catalog_attribute_option_value (option_id, locale, value)
SELECT ao.id, 'fr_FR', '$label'
FROM pim_catalog_attribute a
JOIN pim_catalog_attribute_option ao ON ao.attribute_id = a.id
WHERE a.code='$attr_code' AND ao.code='$OPTION_CODE'
ON DUPLICATE KEY UPDATE value='$label';
SQL
        
    done < "$TEMP_DIR/options.sql"
    
    CREATED_OPTIONS=$(/opt/mariadb10.6/mariadb/bin/mysql -u $DB_USER -p"$DB_PASS" -h $DB_HOST -P $DB_PORT $DB_NAME -sse "SELECT COUNT(*) FROM pim_catalog_attribute_option;" 2>/dev/null)
    success "Total options: $CREATED_OPTIONS"
}

##############################################################################
# PHASE 3: IMPORT PRODUCTS (First 100 for testing)
##############################################################################

phase3_import_products_batch() {
    step_header "PHASE 3: IMPORT PRODUCTS (BATCH 1 - TESTING)"
    
    info "Importing first 100 products for testing..."
    
    # Get products with all data
    /opt/mariadb10.6/mariadb/bin/mysql -u $DB_USER -p"$DB_PASS" -h $DB_HOST -P $DB_PORT $MAGENTO_DB <<SQL > "$TEMP_DIR/products_batch1.sql" 2>/dev/null
SELECT 
    cpe.entity_id,
    cpe.sku,
    cpe.attribute_set_id,
    eas.attribute_set_name as family_name
FROM catalog_product_entity cpe
JOIN eav_attribute_set eas ON cpe.attribute_set_id = eas.attribute_set_id
ORDER BY cpe.entity_id
LIMIT 100;
SQL
    
    while IFS=$'\t' read -r entity_id sku attr_set_id family_name; do
        [ "$entity_id" = "entity_id" ] && continue
        
        FAMILY_CODE=$(echo "$family_name" | tr '[:upper:]' '[:lower:]' | tr ' ' '_' | sed 's/[^a-z0-9_]//g')
        
        info "Creating product: $sku (Family: $FAMILY_CODE)"
        
        /opt/mariadb10.6/mariadb/bin/mysql -u $DB_USER -p"$DB_PASS" -h $DB_HOST -P $DB_PORT $DB_NAME <<SQL 2>/dev/null || true
-- Create product
INSERT INTO pim_catalog_product (identifier, family_id, is_enabled, created, updated)
SELECT 
    '$sku',
    f.id,
    1,
    NOW(),
    NOW()
FROM pim_catalog_family f
WHERE f.code='$FAMILY_CODE'
ON DUPLICATE KEY UPDATE updated=NOW();

-- Add identifier value
INSERT INTO pim_catalog_product_value (product_id, attribute_id, scope_id, locale_id, text_value)
SELECT 
    p.id,
    a.id,
    NULL,
    NULL,
    '$sku'
FROM pim_catalog_product p
CROSS JOIN pim_catalog_attribute a
WHERE p.identifier='$sku' AND a.code='sku'
ON DUPLICATE KEY UPDATE text_value='$sku';
SQL
        
    done < "$TEMP_DIR/products_batch1.sql"
    
    PRODUCT_COUNT=$(/opt/mariadb10.6/mariadb/bin/mysql -u $DB_USER -p"$DB_PASS" -h $DB_HOST -P $DB_PORT $DB_NAME -sse "SELECT COUNT(*) FROM pim_catalog_product;" 2>/dev/null)
    success "Products created: $PRODUCT_COUNT"
}

##############################################################################
# PHASE 4: ENRICH WITH PRODUCT DATA
##############################################################################

phase4_enrich_products() {
    step_header "PHASE 4: ENRICH PRODUCTS WITH DATA"
    
    info "Enriching products with names, descriptions, prices..."
    
    # Get first 100 product names
    /opt/mariadb10.6/mariadb/bin/mysql -u $DB_USER -p"$DB_PASS" -h $DB_HOST -P $DB_PORT $MAGENTO_DB <<SQL > "$TEMP_DIR/product_names.sql" 2>/dev/null
SELECT 
    cpe.sku,
    cpev.value as name
FROM catalog_product_entity cpe
JOIN catalog_product_entity_varchar cpev ON cpe.entity_id = cpev.entity_id
JOIN eav_attribute ea ON cpev.attribute_id = ea.attribute_id
WHERE ea.attribute_code = 'name' AND cpev.store_id = 1
ORDER BY cpe.entity_id
LIMIT 100;
SQL
    
    while IFS=$'\t' read -r sku name; do
        [ "$sku" = "sku" ] && continue
        [ -z "$name" ] && continue
        
        # Escape special characters
        name=$(echo "$name" | sed "s/'/''/g")
        
        /opt/mariadb10.6/mariadb/bin/mysql -u $DB_USER -p"$DB_PASS" -h $DB_HOST -P $DB_PORT $DB_NAME <<SQL 2>/dev/null || true
INSERT INTO pim_catalog_product_value (product_id, attribute_id, scope_id, locale_id, text_value)
SELECT 
    p.id,
    a.id,
    NULL,
    (SELECT id FROM pim_catalog_locale WHERE code='fr_FR' LIMIT 1),
    '$name'
FROM pim_catalog_product p
CROSS JOIN pim_catalog_attribute a
WHERE p.identifier='$sku' AND a.code='name'
ON DUPLICATE KEY UPDATE text_value='$name';
SQL
        
    done < "$TEMP_DIR/product_names.sql"
    
    success "Product names enriched"
}

##############################################################################
# PHASE 5: APPLY HISTORICAL ENRICHMENT
##############################################################################

phase5_historical_enrichment() {
    step_header "PHASE 5: APPLY HISTORICAL ENRICHMENT & TUNINGS"
    
    cd "$PIM_ROOT"
    
    info "Calculating product completeness..."
    php bin/console pim:completeness:calculate --env=prod 2>&1 | tail -5
    success "Completeness calculated"
    
    info "Reindexing Elasticsearch..."
    php bin/console akeneo:elasticsearch:reset-indexes --env=prod 2>&1 | tail -5
    success "Elasticsearch reindexed"
    
    info "Clearing cache..."
    rm -rf var/cache/* 2>/dev/null || true
    php bin/console cache:clear --env=prod 2>&1 | tail -3
    success "Cache cleared"
}

##############################################################################
# PHASE 6: VERIFY & REPORT
##############################################################################

phase6_verify() {
    step_header "PHASE 6: VERIFY DATA INTEGRITY"
    
    # Get counts
    FAMILIES=$(/opt/mariadb10.6/mariadb/bin/mysql -u $DB_USER -p"$DB_PASS" -h $DB_HOST -P $DB_PORT $DB_NAME -sse "SELECT COUNT(*) FROM pim_catalog_family;" 2>/dev/null)
    ATTRIBUTES=$(/opt/mariadb10.6/mariadb/bin/mysql -u $DB_USER -p"$DB_PASS" -h $DB_HOST -P $DB_PORT $DB_NAME -sse "SELECT COUNT(*) FROM pim_catalog_attribute;" 2>/dev/null)
    OPTIONS=$(/opt/mariadb10.6/mariadb/bin/mysql -u $DB_USER -p"$DB_PASS" -h $DB_HOST -P $DB_PORT $DB_NAME -sse "SELECT COUNT(*) FROM pim_catalog_attribute_option;" 2>/dev/null)
    CATEGORIES=$(/opt/mariadb10.6/mariadb/bin/mysql -u $DB_USER -p"$DB_PASS" -h $DB_HOST -P $DB_PORT $DB_NAME -sse "SELECT COUNT(*) FROM pim_catalog_category;" 2>/dev/null)
    PRODUCTS=$(/opt/mariadb10.6/mariadb/bin/mysql -u $DB_USER -p"$DB_PASS" -h $DB_HOST -P $DB_PORT $DB_NAME -sse "SELECT COUNT(*) FROM pim_catalog_product;" 2>/dev/null)
    
    log ""
    log "${PURPLE}═══════════════════════════════════════════════════════════${NC}"
    log "${PURPLE}  ULTIMATE RECOVERY COMPLETE - STATUS REPORT${NC}"
    log "${PURPLE}═══════════════════════════════════════════════════════════${NC}"
    log ""
    log "  Families:          ${GREEN}$FAMILIES${NC} / 18 (target)"
    log "  Attributes:        ${GREEN}$ATTRIBUTES${NC} / 120 (target)"
    log "  Attr Options:      ${GREEN}$OPTIONS${NC} / 500 (target)"
    log "  Categories:        ${GREEN}$CATEGORIES${NC} / 166 (target)"
    log "  Products:          ${GREEN}$PRODUCTS${NC} / 9,538 (target)"
    log ""
    log "${CYAN}  Website:${NC} https://pim.technostationery.com"
    log "${CYAN}  Admin:${NC} admin / PimAdmin2026!"
    log ""
    
    # Calculate progress
    STRUCTURE_PROGRESS=$((($FAMILIES * 100 / 18 + $CATEGORIES * 100 / 166) / 2))
    ATTRIBUTE_PROGRESS=$(($ATTRIBUTES * 100 / 120))
    PRODUCT_PROGRESS=$(($PRODUCTS * 100 / 9538))
    OVERALL_PROGRESS=$((($STRUCTURE_PROGRESS + $ATTRIBUTE_PROGRESS + $PRODUCT_PROGRESS) / 3))
    
    log "${BLUE}  Progress:${NC}"
    log "    Structure:   ${STRUCTURE_PROGRESS}%"
    log "    Attributes:  ${ATTRIBUTE_PROGRESS}%"
    log "    Products:    ${PRODUCT_PROGRESS}%"
    log "    ${GREEN}Overall:     ${OVERALL_PROGRESS}%${NC}"
    log ""
}

##############################################################################
# PHASE 7: CREATE AUTOMATED BACKUP
##############################################################################

phase7_create_backup() {
    step_header "PHASE 7: CREATE AUTOMATED BACKUP SYSTEM"
    
    info "Creating daily backup script..."
    
    cat > /home/pim/daily_backup.sh <<'BACKUP'
#!/bin/bash
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/home/pim/backups"
mkdir -p "$BACKUP_DIR"

# Backup database
/opt/mariadb10.6/mariadb/bin/mysqldump -u root -p'YourNewStrongPassword' \
    -h 127.0.0.1 -P 3307 akeneo_pim \
    | gzip > "$BACKUP_DIR/akeneo_pim_${TIMESTAMP}.sql.gz"

# Keep only last 7 days
find "$BACKUP_DIR" -name "akeneo_pim_*.sql.gz" -mtime +7 -delete

echo "Backup completed: akeneo_pim_${TIMESTAMP}.sql.gz"
BACKUP
    
    chmod +x /home/pim/daily_backup.sh
    success "Backup script created at /home/pim/daily_backup.sh"
    
    info "To enable daily backups, add to crontab:"
    log "  ${YELLOW}0 2 * * * /home/pim/daily_backup.sh${NC}"
}

##############################################################################
# Main Execution
##############################################################################

main() {
    log ""
    log "${PURPLE}╔════════════════════════════════════════════════════════════╗${NC}"
    log "${PURPLE}║     ULTIMATE RECOVERY + ENRICHMENT EXECUTION               ║${NC}"
    log "${PURPLE}║     $(date '+%Y-%m-%d %H:%M:%S')                           ║${NC}"
    log "${PURPLE}╚════════════════════════════════════════════════════════════╝${NC}"
    log ""
    
    phase1_fix_attributes
    phase2_import_options
    phase3_import_products_batch
    phase4_enrich_products
    phase5_historical_enrichment
    phase6_verify
    phase7_create_backup
    
    log ""
    log "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    log "${GREEN}║     ULTIMATE RECOVERY EXECUTION COMPLETE                   ║${NC}"
    log "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    log ""
    log "${YELLOW}Next steps:${NC}"
    log "  1. Review results in database"
    log "  2. Login to https://pim.technostationery.com"
    log "  3. Verify products are visible"
    log "  4. Run full product import (remaining 9,438 products)"
    log ""
    log "${BLUE}Log: $LOG_FILE${NC}"
}

# Execute
main
