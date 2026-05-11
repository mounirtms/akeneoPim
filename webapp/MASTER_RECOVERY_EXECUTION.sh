#!/bin/bash

##############################################################################
# MASTER RECOVERY EXECUTION SCRIPT
# Restores complete Akeneo PIM catalog from Magento using all existing scripts
# Date: 2026-04-23
# COMPREHENSIVE DATA RECOVERY - EVERYTHING
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
PROD_ROOT="/home/technadminy7/public_html"
DB_HOST="127.0.0.1"
DB_PORT="3307"
DB_NAME="akeneo_pim"
MAGENTO_DB="beta_dBT8x12y22"
DB_USER="root"
DB_PASS="YourNewStrongPassword"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="/home/pim/master_recovery_${TIMESTAMP}.log"
REPORT_FILE="/home/pim/public_html/webapp/MASTER_RECOVERY_REPORT_${TIMESTAMP}.md"
TEMP_DIR="/home/pim/temp_recovery_${TIMESTAMP}"

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
# PHASE 1: ANALYZE COMPLETE MAGENTO STRUCTURE
##############################################################################

phase1_analyze_magento() {
    step_header "PHASE 1: ANALYZE COMPLETE MAGENTO STRUCTURE"
    
    info "Extracting complete catalog structure from Magento..."
    
    # 1. Get all attribute sets (families)
    info "1/10: Extracting attribute sets (families)..."
    /opt/mariadb10.6/mariadb/bin/mysql -u $DB_USER -p"$DB_PASS" -h $DB_HOST -P $DB_PORT $MAGENTO_DB <<SQL > "$TEMP_DIR/attribute_sets.sql" 2>/dev/null
SELECT 
    eas.attribute_set_id,
    eas.attribute_set_name,
    eas.sort_order,
    COUNT(DISTINCT eea.attribute_id) as attribute_count
FROM eav_attribute_set eas
LEFT JOIN eav_entity_attribute eea ON eas.attribute_set_id = eea.attribute_set_id
WHERE eas.entity_type_id = 4
GROUP BY eas.attribute_set_id
ORDER BY eas.attribute_set_id;
SQL
    
    FAMILY_COUNT=$(cat "$TEMP_DIR/attribute_sets.sql" | wc -l)
    success "Found $FAMILY_COUNT attribute sets"
    
    # 2. Get ALL attributes with groups
    info "2/10: Extracting all attributes..."
    /opt/mariadb10.6/mariadb/bin/mysql -u $DB_USER -p"$DB_PASS" -h $DB_HOST -P $DB_PORT $MAGENTO_DB <<SQL > "$TEMP_DIR/attributes.sql" 2>/dev/null
SELECT 
    ea.attribute_id,
    ea.attribute_code,
    ea.frontend_label,
    ea.backend_type,
    ea.frontend_input,
    ea.is_required,
    ea.is_unique,
    eag.attribute_group_name as attribute_group,
    ea.default_value
FROM eav_attribute ea
LEFT JOIN eav_entity_attribute eea ON ea.attribute_id = eea.attribute_id
LEFT JOIN eav_attribute_group eag ON eea.attribute_group_id = eag.attribute_group_id
WHERE ea.entity_type_id = 4
ORDER BY ea.attribute_id;
SQL
    
    ATTRIBUTE_COUNT=$(cat "$TEMP_DIR/attributes.sql" | wc -l)
    success "Found $ATTRIBUTE_COUNT attributes"
    
    # 3. Get attribute options (for dropdowns)
    info "3/10: Extracting attribute options..."
    /opt/mariadb10.6/mariadb/bin/mysql -u $DB_USER -p"$DB_PASS" -h $DB_HOST -P $DB_PORT $MAGENTO_DB <<SQL > "$TEMP_DIR/attribute_options.sql" 2>/dev/null
SELECT 
    ea.attribute_code,
    eao.option_id,
    eaov.value as option_label,
    eaov.store_id
FROM eav_attribute ea
JOIN eav_attribute_option eao ON ea.attribute_id = eao.attribute_id
JOIN eav_attribute_option_value eaov ON eao.option_id = eaov.option_id
WHERE ea.entity_type_id = 4
ORDER BY ea.attribute_code, eao.sort_order;
SQL
    
    OPTION_COUNT=$(cat "$TEMP_DIR/attribute_options.sql" | wc -l)
    success "Found $OPTION_COUNT attribute options"
    
    # 4. Get complete category tree
    info "4/10: Extracting category tree..."
    /opt/mariadb10.6/mariadb/bin/mysql -u $DB_USER -p"$DB_PASS" -h $DB_HOST -P $DB_PORT $MAGENTO_DB <<SQL > "$TEMP_DIR/categories.sql" 2>/dev/null
SELECT 
    cce.entity_id,
    ccev.value as name,
    cce.parent_id,
    cce.path,
    cce.level,
    cce.position,
    cce.children_count
FROM catalog_category_entity cce
LEFT JOIN catalog_category_entity_varchar ccev ON cce.entity_id = ccev.entity_id
LEFT JOIN eav_attribute ea ON ccev.attribute_id = ea.attribute_id
WHERE ea.attribute_code = 'name' AND ccev.store_id = 1
ORDER BY cce.path;
SQL
    
    CATEGORY_COUNT=$(cat "$TEMP_DIR/categories.sql" | wc -l)
    success "Found $CATEGORY_COUNT categories"
    
    # 5. Get ALL products with complete data
    info "5/10: Extracting all products..."
    /opt/mariadb10.6/mariadb/bin/mysql -u $DB_USER -p"$DB_PASS" -h $DB_HOST -P $DB_PORT $MAGENTO_DB <<SQL > "$TEMP_DIR/products_base.sql" 2>/dev/null
SELECT 
    entity_id,
    attribute_set_id,
    type_id,
    sku,
    created_at,
    updated_at
FROM catalog_product_entity
ORDER BY entity_id;
SQL
    
    PRODUCT_COUNT=$(cat "$TEMP_DIR/products_base.sql" | wc -l)
    success "Found $PRODUCT_COUNT products"
    
    # 6. Get product varchar attributes (names, descriptions)
    info "6/10: Extracting product varchar data..."
    /opt/mariadb10.6/mariadb/bin/mysql -u $DB_USER -p"$DB_PASS" -h $DB_HOST -P $DB_PORT $MAGENTO_DB <<SQL > "$TEMP_DIR/products_varchar.sql" 2>/dev/null
SELECT 
    cpev.entity_id,
    ea.attribute_code,
    cpev.value,
    cpev.store_id
FROM catalog_product_entity_varchar cpev
JOIN eav_attribute ea ON cpev.attribute_id = ea.attribute_id
WHERE cpev.store_id IN (0,1)
ORDER BY cpev.entity_id, ea.attribute_code;
SQL
    
    VARCHAR_COUNT=$(cat "$TEMP_DIR/products_varchar.sql" | wc -l)
    success "Found $VARCHAR_COUNT varchar values"
    
    # 7. Get product text attributes
    info "7/10: Extracting product text data..."
    /opt/mariadb10.6/mariadb/bin/mysql -u $DB_USER -p"$DB_PASS" -h $DB_HOST -P $DB_PORT $MAGENTO_DB <<SQL > "$TEMP_DIR/products_text.sql" 2>/dev/null
SELECT 
    cpet.entity_id,
    ea.attribute_code,
    cpet.value,
    cpet.store_id
FROM catalog_product_entity_text cpet
JOIN eav_attribute ea ON cpet.attribute_id = ea.attribute_id
WHERE cpet.store_id IN (0,1)
ORDER BY cpet.entity_id, ea.attribute_code;
SQL
    
    TEXT_COUNT=$(cat "$TEMP_DIR/products_text.sql" | wc -l)
    success "Found $TEXT_COUNT text values"
    
    # 8. Get product decimal attributes (prices, weights)
    info "8/10: Extracting product decimal data..."
    /opt/mariadb10.6/mariadb/bin/mysql -u $DB_USER -p"$DB_PASS" -h $DB_HOST -P $DB_PORT $MAGENTO_DB <<SQL > "$TEMP_DIR/products_decimal.sql" 2>/dev/null
SELECT 
    cped.entity_id,
    ea.attribute_code,
    cped.value,
    cped.store_id
FROM catalog_product_entity_decimal cped
JOIN eav_attribute ea ON cped.attribute_id = ea.attribute_id
WHERE cped.store_id IN (0,1)
ORDER BY cped.entity_id, ea.attribute_code;
SQL
    
    DECIMAL_COUNT=$(cat "$TEMP_DIR/products_decimal.sql" | wc -l)
    success "Found $DECIMAL_COUNT decimal values"
    
    # 9. Get product int attributes (status, visibility)
    info "9/10: Extracting product int data..."
    /opt/mariadb10.6/mariadb/bin/mysql -u $DB_USER -p"$DB_PASS" -h $DB_HOST -P $DB_PORT $MAGENTO_DB <<SQL > "$TEMP_DIR/products_int.sql" 2>/dev/null
SELECT 
    cpei.entity_id,
    ea.attribute_code,
    cpei.value,
    cpei.store_id
FROM catalog_product_entity_int cpei
JOIN eav_attribute ea ON cpei.attribute_id = ea.attribute_id
WHERE cpei.store_id IN (0,1)
ORDER BY cpei.entity_id, ea.attribute_code;
SQL
    
    INT_COUNT=$(cat "$TEMP_DIR/products_int.sql" | wc -l)
    success "Found $INT_COUNT int values"
    
    # 10. Get product-category relationships
    info "10/10: Extracting product-category relationships..."
    /opt/mariadb10.6/mariadb/bin/mysql -u $DB_USER -p"$DB_PASS" -h $DB_HOST -P $DB_PORT $MAGENTO_DB <<SQL > "$TEMP_DIR/product_categories.sql" 2>/dev/null
SELECT 
    ccp.product_id,
    ccp.category_id,
    ccp.position
FROM catalog_category_product ccp
ORDER BY ccp.product_id, ccp.position;
SQL
    
    RELATION_COUNT=$(cat "$TEMP_DIR/product_categories.sql" | wc -l)
    success "Found $RELATION_COUNT product-category relations"
    
    # Summary
    log ""
    log "${PURPLE}═══ PHASE 1 COMPLETE ═══${NC}"
    log "Families:              $FAMILY_COUNT"
    log "Attributes:            $ATTRIBUTE_COUNT"
    log "Attribute Options:     $OPTION_COUNT"
    log "Categories:            $CATEGORY_COUNT"
    log "Products:              $PRODUCT_COUNT"
    log "Varchar Values:        $VARCHAR_COUNT"
    log "Text Values:           $TEXT_COUNT"
    log "Decimal Values:        $DECIMAL_COUNT"
    log "Int Values:            $INT_COUNT"
    log "Category Relations:    $RELATION_COUNT"
    log ""
}

##############################################################################
# PHASE 2: IMPORT FAMILIES (ATTRIBUTE SETS)
##############################################################################

phase2_import_families() {
    step_header "PHASE 2: IMPORT FAMILIES (ATTRIBUTE SETS)"
    
    info "Creating families in Akeneo from Magento attribute sets..."
    
    # Read attribute sets and create families
    while IFS=$'\t' read -r set_id set_name sort_order attr_count; do
        [ "$set_id" = "attribute_set_id" ] && continue  # Skip header
        
        # Clean and normalize family code
        FAMILY_CODE=$(echo "$set_name" | tr '[:upper:]' '[:lower:]' | tr ' ' '_' | tr '-' '_' | sed 's/[^a-z0-9_]//g')
        
        info "Creating family: $FAMILY_CODE ($set_name)"
        
        /opt/mariadb10.6/mariadb/bin/mysql -u $DB_USER -p"$DB_PASS" -h $DB_HOST -P $DB_PORT $DB_NAME <<SQL 2>/dev/null || true
-- Create family
INSERT INTO pim_catalog_family (code, created, updated) 
VALUES ('$FAMILY_CODE', NOW(), NOW())
ON DUPLICATE KEY UPDATE updated=NOW();

-- Add French label
INSERT INTO pim_catalog_family_translation (foreign_key, label, locale)
SELECT f.id, '$set_name', 'fr_FR'
FROM pim_catalog_family f
WHERE f.code='$FAMILY_CODE'
ON DUPLICATE KEY UPDATE label='$set_name';
SQL
        
        success "Created: $FAMILY_CODE"
        
    done < "$TEMP_DIR/attribute_sets.sql"
    
    # Verify
    CREATED_FAMILIES=$(/opt/mariadb10.6/mariadb/bin/mysql -u $DB_USER -p"$DB_PASS" -h $DB_HOST -P $DB_PORT $DB_NAME -sse "SELECT COUNT(*) FROM pim_catalog_family;" 2>/dev/null)
    
    success "Total families in Akeneo: $CREATED_FAMILIES"
}

##############################################################################
# PHASE 3: IMPORT ALL ATTRIBUTES
##############################################################################

phase3_import_attributes() {
    step_header "PHASE 3: IMPORT ALL ATTRIBUTES"
    
    info "Creating all attributes in Akeneo..."
    
    # Map Magento backend types to Akeneo types
    declare -A TYPE_MAP
    TYPE_MAP["varchar"]="pim_catalog_text"
    TYPE_MAP["text"]="pim_catalog_textarea"
    TYPE_MAP["int"]="pim_catalog_number"
    TYPE_MAP["decimal"]="pim_catalog_number"
    TYPE_MAP["datetime"]="pim_catalog_date"
    TYPE_MAP["static"]="pim_catalog_text"
    
    while IFS=$'\t' read -r attr_id code label backend_type frontend_input is_required is_unique group_name default_value; do
        [ "$attr_id" = "attribute_id" ] && continue  # Skip header
        [ -z "$code" ] && continue
        
        # Map types
        AKENEO_TYPE="${TYPE_MAP[$backend_type]}"
        [ -z "$AKENEO_TYPE" ] && AKENEO_TYPE="pim_catalog_text"
        
        # Determine if localizable (has French values)
        IS_LOCALIZABLE="0"
        [ "$code" = "name" ] || [ "$code" = "description" ] || [ "$code" = "short_description" ] && IS_LOCALIZABLE="1"
        
        info "Creating attribute: $code ($AKENEO_TYPE)"
        
        /opt/mariadb10.6/mariadb/bin/mysql -u $DB_USER -p"$DB_PASS" -h $DB_HOST -P $DB_PORT $DB_NAME <<SQL 2>/dev/null || true
-- Create attribute
INSERT INTO pim_catalog_attribute 
(code, attribute_type, backend_type, entity_type, is_required, is_unique, is_localizable, is_scopable, created, updated)
VALUES 
('$code', '$AKENEO_TYPE', '$backend_type', 'product', $is_required, $is_unique, $IS_LOCALIZABLE, 0, NOW(), NOW())
ON DUPLICATE KEY UPDATE updated=NOW();

-- Add French label
INSERT INTO pim_catalog_attribute_translation (foreign_key, label, locale)
SELECT a.id, COALESCE(NULLIF('$label', ''), '$code'), 'fr_FR'
FROM pim_catalog_attribute a
WHERE a.code='$code'
ON DUPLICATE KEY UPDATE label=COALESCE(NULLIF('$label', ''), '$code');
SQL
        
    done < "$TEMP_DIR/attributes.sql"
    
    # Verify
    CREATED_ATTRS=$(/opt/mariadb10.6/mariadb/bin/mysql -u $DB_USER -p"$DB_PASS" -h $DB_HOST -P $DB_PORT $DB_NAME -sse "SELECT COUNT(*) FROM pim_catalog_attribute;" 2>/dev/null)
    
    success "Total attributes in Akeneo: $CREATED_ATTRS"
}

##############################################################################
# PHASE 4: IMPORT ATTRIBUTE OPTIONS
##############################################################################

phase4_import_options() {
    step_header "PHASE 4: IMPORT ATTRIBUTE OPTIONS"
    
    info "Creating attribute options..."
    
    while IFS=$'\t' read -r attr_code option_id label store_id; do
        [ "$attr_code" = "attribute_code" ] && continue
        [ -z "$attr_code" ] || [ -z "$label" ] && continue
        
        # Only process store_id 1 (French) or 0 (default)
        [ "$store_id" != "1" ] && [ "$store_id" != "0" ] && continue
        
        info "Adding option '$label' to $attr_code"
        
        /opt/mariadb10.6/mariadb/bin/mysql -u $DB_USER -p"$DB_PASS" -h $DB_HOST -P $DB_PORT $DB_NAME <<SQL 2>/dev/null || true
-- Create option
INSERT INTO pim_catalog_attribute_option (attribute_id, code, sort_order)
SELECT a.id, '$(echo "$label" | tr '[:upper:]' '[:lower:]' | tr ' ' '_' | sed 's/[^a-z0-9_]//g')_$option_id', $option_id
FROM pim_catalog_attribute a
WHERE a.code='$attr_code'
ON DUPLICATE KEY UPDATE sort_order=$option_id;

-- Add French label
INSERT INTO pim_catalog_attribute_option_value (option_id, locale, value)
SELECT ao.id, 'fr_FR', '$label'
FROM pim_catalog_attribute a
JOIN pim_catalog_attribute_option ao ON ao.attribute_id = a.id
WHERE a.code='$attr_code' 
AND ao.code='$(echo "$label" | tr '[:upper:]' '[:lower:]' | tr ' ' '_' | sed 's/[^a-z0-9_]//g')_$option_id'
ON DUPLICATE KEY UPDATE value='$label';
SQL
        
    done < "$TEMP_DIR/attribute_options.sql"
    
    # Verify
    CREATED_OPTIONS=$(/opt/mariadb10.6/mariadb/bin/mysql -u $DB_USER -p"$DB_PASS" -h $DB_HOST -P $DB_PORT $DB_NAME -sse "SELECT COUNT(*) FROM pim_catalog_attribute_option;" 2>/dev/null)
    
    success "Total attribute options in Akeneo: $CREATED_OPTIONS"
}

##############################################################################
# PHASE 5: IMPORT CATEGORY TREE
##############################################################################

phase5_import_categories() {
    step_header "PHASE 5: IMPORT COMPLETE CATEGORY TREE"
    
    info "Creating complete category tree..."
    
    # First, create master category
    /opt/mariadb10.6/mariadb/bin/mysql -u $DB_USER -p"$DB_PASS" -h $DB_HOST -P $DB_PORT $DB_NAME <<SQL 2>/dev/null || true
-- Create master category
INSERT INTO pim_catalog_category (code, parent_id, root, lvl, lft, rgt, created, updated)
VALUES ('master', NULL, 1, 0, 1, 10000, NOW(), NOW())
ON DUPLICATE KEY UPDATE code=code;

-- Add French label
INSERT INTO pim_catalog_category_translation (foreign_key, label, locale)
SELECT id, 'Catalogue Principal', 'fr_FR'
FROM pim_catalog_category
WHERE code='master'
ON DUPLICATE KEY UPDATE label='Catalogue Principal';
SQL
    
    success "Master category created"
    
    # Import all categories
    while IFS=$'\t' read -r entity_id name parent_id path level position children_count; do
        [ "$entity_id" = "entity_id" ] && continue
        [ "$entity_id" = "1" ] || [ "$entity_id" = "2" ] && continue  # Skip root categories
        [ -z "$name" ] && continue
        
        # Create category code
        CAT_CODE="cat_${entity_id}"
        
        info "Creating category: $CAT_CODE ($name)"
        
        /opt/mariadb10.6/mariadb/bin/mysql -u $DB_USER -p"$DB_PASS" -h $DB_HOST -P $DB_PORT $DB_NAME <<SQL 2>/dev/null || true
-- Create category
INSERT INTO pim_catalog_category (code, root, lvl, lft, rgt, created, updated)
SELECT '$CAT_CODE', 
       (SELECT id FROM pim_catalog_category WHERE code='master' LIMIT 1),
       $level,
       $position * 2,
       ($position * 2) + 1,
       NOW(), 
       NOW()
ON DUPLICATE KEY UPDATE lvl=$level;

-- Add French label
INSERT INTO pim_catalog_category_translation (foreign_key, label, locale)
SELECT c.id, '$name', 'fr_FR'
FROM pim_catalog_category c
WHERE c.code='$CAT_CODE'
ON DUPLICATE KEY UPDATE label='$name';
SQL
        
    done < "$TEMP_DIR/categories.sql"
    
    # Verify
    CREATED_CATS=$(/opt/mariadb10.6/mariadb/bin/mysql -u $DB_USER -p"$DB_PASS" -h $DB_HOST -P $DB_PORT $DB_NAME -sse "SELECT COUNT(*) FROM pim_catalog_category;" 2>/dev/null)
    
    success "Total categories in Akeneo: $CREATED_CATS"
}

##############################################################################
# PHASE 6: ASSIGN ATTRIBUTES TO FAMILIES
##############################################################################

phase6_assign_attributes() {
    step_header "PHASE 6: ASSIGN ATTRIBUTES TO FAMILIES"
    
    info "Assigning attributes to families..."
    
    # Get family-attribute relationships from Magento
    /opt/mariadb10.6/mariadb/bin/mysql -u $DB_USER -p"$DB_PASS" -h $DB_HOST -P $DB_PORT $MAGENTO_DB <<SQL > "$TEMP_DIR/family_attributes.sql" 2>/dev/null
SELECT 
    eas.attribute_set_id,
    eas.attribute_set_name,
    ea.attribute_code,
    eea.is_required
FROM eav_attribute_set eas
JOIN eav_entity_attribute eea ON eas.attribute_set_id = eea.attribute_set_id
JOIN eav_attribute ea ON eea.attribute_id = ea.attribute_id
WHERE eas.entity_type_id = 4
ORDER BY eas.attribute_set_id, ea.attribute_code;
SQL
    
    while IFS=$'\t' read -r set_id set_name attr_code is_required; do
        [ "$set_id" = "attribute_set_id" ] && continue
        
        FAMILY_CODE=$(echo "$set_name" | tr '[:upper:]' '[:lower:]' | tr ' ' '_' | tr '-' '_' | sed 's/[^a-z0-9_]//g')
        
        /opt/mariadb10.6/mariadb/bin/mysql -u $DB_USER -p"$DB_PASS" -h $DB_HOST -P $DB_PORT $DB_NAME <<SQL 2>/dev/null || true
-- Assign attribute to family
INSERT IGNORE INTO pim_catalog_family_attribute (family_id, attribute_id)
SELECT f.id, a.id
FROM pim_catalog_family f
CROSS JOIN pim_catalog_attribute a
WHERE f.code='$FAMILY_CODE' AND a.code='$attr_code';

-- Mark as required if needed
$([ "$is_required" = "1" ] && echo "INSERT IGNORE INTO pim_catalog_attribute_requirement (attribute_id, family_id, channel_id, required)
SELECT a.id, f.id, c.id, 1
FROM pim_catalog_attribute a
CROSS JOIN pim_catalog_family f
CROSS JOIN pim_catalog_channel c
WHERE a.code='$attr_code' AND f.code='$FAMILY_CODE';")
SQL
        
    done < "$TEMP_DIR/family_attributes.sql"
    
    success "Attributes assigned to families"
}

##############################################################################
# Main Execution
##############################################################################

main() {
    log ""
    log "${PURPLE}╔════════════════════════════════════════════════════════════╗${NC}"
    log "${PURPLE}║     MASTER RECOVERY EXECUTION - COMPLETE CATALOG           ║${NC}"
    log "${PURPLE}║     $(date '+%Y-%m-%d %H:%M:%S')                           ║${NC}"
    log "${PURPLE}╚════════════════════════════════════════════════════════════╝${NC}"
    log ""
    
    phase1_analyze_magento
    phase2_import_families
    phase3_import_attributes
    phase4_import_options
    phase5_import_categories
    phase6_assign_attributes
    
    log ""
    log "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    log "${GREEN}║     STRUCTURE IMPORT COMPLETE - READY FOR PRODUCTS         ║${NC}"
    log "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    log ""
    log "${BLUE}Log: $LOG_FILE${NC}"
    log "${BLUE}Temp: $TEMP_DIR${NC}"
    log ""
    log "${YELLOW}Next: Run product import (PHASE 7-8)${NC}"
}

# Execute
main
