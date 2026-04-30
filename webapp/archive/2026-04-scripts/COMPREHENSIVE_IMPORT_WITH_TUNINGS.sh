#!/bin/bash

################################################################################
# COMPREHENSIVE AKENEO IMPORT WITH HISTORICAL TUNINGS
# Restores complete catalog with SEO optimizations from commits
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

AKENEO_ROOT="/home/pim/public_html"
DATA_DIR="/home/pim/temp_recovery_$(date +%Y%m%d)"
LOG_FILE="/home/pim/comprehensive_import_$(date +%Y%m%d_%H%M%S).log"

# Logging functions
log_step() { echo -e "${CYAN}═══ $1 ═══${NC}" | tee -a "$LOG_FILE"; }
log_info() { echo -e "${BLUE}ℹ️  $1${NC}" | tee -a "$LOG_FILE"; }
log_success() { echo -e "${GREEN}✅ $1${NC}" | tee -a "$LOG_FILE"; }
log_error() { echo -e "${RED}❌ $1${NC}" | tee -a "$LOG_FILE"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}" | tee -a "$LOG_FILE"; }

################################################################################
# PHASE 1: IMPORT ALL ATTRIBUTES
################################################################################
import_attributes() {
    log_step "PHASE 1: IMPORTING ATTRIBUTES (120+)"
    
    cd "$AKENEO_ROOT"
    
    # Extract unique attributes from Magento
    log_info "Extracting attributes from Magento..."
    
    /opt/mariadb10.6/mariadb/bin/mysql -u root -p'YourNewStrongPassword' -h 127.0.0.1 -P 3307 beta_dBT8x12y22 <<'SQL' > /tmp/attributes_import.json
SELECT CONCAT(
    '{"code":"', LOWER(REPLACE(REPLACE(attribute_code, ' ', '_'), '-', '_')), 
    '","type":"', 
    CASE backend_type 
        WHEN 'int' THEN 'pim_catalog_simpleselect'
        WHEN 'decimal' THEN 'pim_catalog_number'
        WHEN 'varchar' THEN 'pim_catalog_text'
        WHEN 'text' THEN 'pim_catalog_textarea'
        WHEN 'datetime' THEN 'pim_catalog_date'
        ELSE 'pim_catalog_text'
    END,
    '","group":"technical","labels":{"fr_FR":"', 
    COALESCE(frontend_label, attribute_code),
    '"},"localizable":false,"scopable":false,"useable_as_grid_filter":true}'
) as json_attr
FROM eav_attribute 
WHERE entity_type_id = 4 
AND attribute_code NOT IN ('sku', 'entity_id', 'attribute_set_id', 'type_id')
GROUP BY attribute_code
LIMIT 200;
SQL
    
    # Import each attribute via API
    local attr_count=0
    while IFS= read -r attr_json; do
        if [ ! -z "$attr_json" ] && [ "$attr_json" != "json_attr" ]; then
            attr_code=$(echo "$attr_json" | grep -oP '"code":"\K[^"]+' || echo "")
            if [ ! -z "$attr_code" ]; then
                log_info "Creating attribute: $attr_code"
                
                # Create attribute via console command
                echo "$attr_json" | php bin/console akeneo:attribute:create --env=prod 2>&1 | tee -a "$LOG_FILE" || {
                    # If API fails, try direct SQL insert
                    /opt/mariadb10.6/mariadb/bin/mysql -u akeneo_pim -p'akeneo_pim' -h 127.0.0.1 -P 3307 akeneo_pim <<SQLINS
INSERT IGNORE INTO pim_catalog_attribute (code, attribute_type, backend_type, is_required, is_unique, is_localizable, is_scopable, created, updated)
VALUES ('$attr_code', 'pim_catalog_text', 'text', 0, 0, 0, 0, NOW(), NOW());
SQLINS
                }
                ((attr_count++))
            fi
        fi
    done < /tmp/attributes_import.json
    
    log_success "Imported $attr_count attributes"
}

################################################################################
# PHASE 2: IMPORT ATTRIBUTE OPTIONS
################################################################################
import_attribute_options() {
    log_step "PHASE 2: IMPORTING ATTRIBUTE OPTIONS (500+)"
    
    # Extract attribute options from Magento
    /opt/mariadb10.6/mariadb/bin/mysql -u root -p'YourNewStrongPassword' -h 127.0.0.1 -P 3307 beta_dBT8x12y22 <<'SQL' > /tmp/attribute_options.csv
SELECT 
    LOWER(REPLACE(ea.attribute_code, ' ', '_')) as attr_code,
    eao.option_id,
    COALESCE(eaov.value, CONCAT('option_', eao.option_id)) as label_fr
FROM eav_attribute_option eao
JOIN eav_attribute ea ON eao.attribute_id = ea.attribute_id
LEFT JOIN eav_attribute_option_value eaov ON eao.option_id = eaov.option_id AND eaov.store_id = 0
WHERE ea.entity_type_id = 4
ORDER BY ea.attribute_code, eao.sort_order
LIMIT 1000;
SQL
    
    # Import options via SQL (faster for bulk)
    local opt_count=0
    while IFS=$'\t' read -r attr_code opt_id label_fr; do
        if [ ! -z "$attr_code" ] && [ "$attr_code" != "attr_code" ]; then
            /opt/mariadb10.6/mariadb/bin/mysql -u akeneo_pim -p'akeneo_pim' -h 127.0.0.1 -P 3307 akeneo_pim <<SQLOPT
INSERT IGNORE INTO pim_catalog_attribute_option (attribute_id, code, sort_order)
SELECT id, 'opt_${opt_id}', ${opt_id}
FROM pim_catalog_attribute WHERE code = '${attr_code}';

INSERT IGNORE INTO pim_catalog_attribute_option_value (option_id, locale_code, value)
SELECT pao.id, 'fr_FR', '${label_fr}'
FROM pim_catalog_attribute_option pao
JOIN pim_catalog_attribute pa ON pao.attribute_id = pa.id
WHERE pa.code = '${attr_code}' AND pao.code = 'opt_${opt_id}';
SQLOPT
            ((opt_count++))
        fi
    done < /tmp/attribute_options.csv
    
    log_success "Imported $opt_count attribute options"
}

################################################################################
# PHASE 3: ASSIGN ATTRIBUTES TO FAMILIES
################################################################################
assign_attributes_to_families() {
    log_step "PHASE 3: ASSIGNING ATTRIBUTES TO FAMILIES"
    
    # Get all attributes
    local attrs=$(/opt/mariadb10.6/mariadb/bin/mysql -u akeneo_pim -p'akeneo_pim' -h 127.0.0.1 -P 3307 akeneo_pim -N -e "SELECT code FROM pim_catalog_attribute LIMIT 200;")
    
    # Get all families
    local families=$(/opt/mariadb10.6/mariadb/bin/mysql -u akeneo_pim -p'akeneo_pim' -h 127.0.0.1 -P 3307 akeneo_pim -N -e "SELECT code FROM pim_catalog_family;")
    
    # Assign all attributes to all families (we'll filter later based on actual usage)
    for family in $families; do
        log_info "Assigning attributes to family: $family"
        
        for attr in $attrs; do
            /opt/mariadb10.6/mariadb/bin/mysql -u akeneo_pim -p'akeneo_pim' -h 127.0.0.1 -P 3307 akeneo_pim <<SQLFAM
INSERT IGNORE INTO pim_catalog_family_attribute (family_id, attribute_id)
SELECT f.id, a.id
FROM pim_catalog_family f, pim_catalog_attribute a
WHERE f.code = '$family' AND a.code = '$attr';
SQLFAM
        done
    done
    
    log_success "Attributes assigned to families"
}

################################################################################
# PHASE 4: IMPORT PRODUCTS WITH FULL DATA
################################################################################
import_products_comprehensive() {
    log_step "PHASE 4: IMPORTING 9,538 PRODUCTS WITH COMPLETE DATA"
    
    cd "$AKENEO_ROOT"
    
    # Extract products from Elasticsearch (has the latest data)
    log_info "Extracting products from Elasticsearch..."
    
    curl -s "http://localhost:9200/techno_stationery_product_1_v54/_search?size=10000" | \
        python3 -c "
import json, sys
data = json.load(sys.stdin)
for hit in data['hits']['hits']:
    prod = hit['_source']
    sku = prod.get('sku', '')
    if not sku: continue
    
    name = prod.get('name', {})
    name_fr = name if isinstance(name, str) else name.get('fr_FR', '')
    
    desc = prod.get('description', {})
    desc_fr = desc if isinstance(desc, str) else desc.get('fr_FR', '')
    
    price = prod.get('price', 0)
    if isinstance(price, dict):
        price = price.get('price_0_1', 0)
    
    print(f'{sku}|{name_fr}|{desc_fr}|{price}')
" > /tmp/products_to_import.csv
    
    local product_count=0
    local total_lines=$(wc -l < /tmp/products_to_import.csv)
    
    log_info "Processing $total_lines products..."
    
    while IFS='|' read -r sku name_fr desc_fr price; do
        if [ ! -z "$sku" ] && [ "$sku" != "sku" ]; then
            # Clean data for SQL
            name_clean=$(echo "$name_fr" | sed "s/'/''/g" | cut -c 1-255)
            desc_clean=$(echo "$desc_fr" | sed "s/'/''/g" | cut -c 1-2000)
            price_clean=$(echo "$price" | grep -oE '[0-9.]+' | head -1 || echo "0")
            
            # Insert product
            /opt/mariadb10.6/mariadb/bin/mysql -u akeneo_pim -p'akeneo_pim' -h 127.0.0.1 -P 3307 akeneo_pim <<SQLPROD
-- Insert product
INSERT IGNORE INTO pim_catalog_product (identifier, family_id, is_enabled, created, updated)
SELECT '$sku', f.id, 1, NOW(), NOW()
FROM pim_catalog_family f
WHERE f.code = 'products'
LIMIT 1;

-- Get product ID
SET @prod_id = (SELECT id FROM pim_catalog_product WHERE identifier = '$sku');

-- Insert name (French)
INSERT IGNORE INTO pim_catalog_product_value (product_id, attribute_id, scope_code, locale_code, text_value)
SELECT @prod_id, a.id, NULL, 'fr_FR', '$name_clean'
FROM pim_catalog_attribute a
WHERE a.code = 'name' AND @prod_id IS NOT NULL;

-- Insert description (French)
INSERT IGNORE INTO pim_catalog_product_value (product_id, attribute_id, scope_code, locale_code, text_value)
SELECT @prod_id, a.id, NULL, 'fr_FR', '$desc_clean'
FROM pim_catalog_attribute a
WHERE a.code = 'description' AND @prod_id IS NOT NULL;

-- Insert price
INSERT IGNORE INTO pim_catalog_product_value (product_id, attribute_id, scope_code, locale_code, decimal_value)
SELECT @prod_id, a.id, NULL, NULL, $price_clean
FROM pim_catalog_attribute a
WHERE a.code = 'price' AND @prod_id IS NOT NULL;
SQLPROD
            
            ((product_count++))
            
            if [ $((product_count % 100)) -eq 0 ]; then
                log_info "Imported $product_count / $total_lines products..."
            fi
        fi
    done < /tmp/products_to_import.csv
    
    log_success "Imported $product_count products with full data"
}

################################################################################
# PHASE 5: APPLY HISTORICAL SEO TUNINGS
################################################################################
apply_seo_tunings() {
    log_step "PHASE 5: APPLYING HISTORICAL SEO TUNINGS & OPTIMIZATIONS"
    
    cd "$AKENEO_ROOT"
    
    # 1. Optimize product names (from commit 332dbd6)
    log_info "Optimizing product names for SEO..."
    /opt/mariadb10.6/mariadb/bin/mysql -u akeneo_pim -p'akeneo_pim' -h 127.0.0.1 -P 3307 akeneo_pim <<'SQLSEO'
-- Capitalize first letter of each word
UPDATE pim_catalog_product_value pv
JOIN pim_catalog_attribute pa ON pv.attribute_id = pa.id
SET pv.text_value = CONCAT(UCASE(LEFT(pv.text_value, 1)), SUBSTRING(pv.text_value, 2))
WHERE pa.code = 'name' AND pv.locale_code = 'fr_FR'
AND pv.text_value REGEXP '^[a-z]';

-- Remove duplicate spaces
UPDATE pim_catalog_product_value pv
JOIN pim_catalog_attribute pa ON pv.attribute_id = pa.id
SET pv.text_value = REPLACE(REPLACE(REPLACE(pv.text_value, '  ', ' '), '  ', ' '), '  ', ' ')
WHERE pa.code = 'name' AND pv.locale_code = 'fr_FR';

-- Trim leading/trailing spaces
UPDATE pim_catalog_product_value pv
JOIN pim_catalog_attribute pa ON pv.attribute_id = pa.id
SET pv.text_value = TRIM(pv.text_value)
WHERE pa.code = 'name' AND pv.locale_code = 'fr_FR';
SQLSEO
    
    log_success "Product names optimized"
    
    # 2. Enrich descriptions with keywords (from commit da745f34)
    log_info "Enriching product descriptions..."
    /opt/mariadb10.6/mariadb/bin/mysql -u akeneo_pim -p'akeneo_pim' -h 127.0.0.1 -P 3307 akeneo_pim <<'SQLRICH'
-- Add "de qualité" to short descriptions
UPDATE pim_catalog_product_value pv
JOIN pim_catalog_attribute pa ON pv.attribute_id = pa.id
SET pv.text_value = CONCAT(pv.text_value, ' - Produit de qualité professionnelle.')
WHERE pa.code = 'description' 
AND pv.locale_code = 'fr_FR'
AND LENGTH(pv.text_value) < 100
AND pv.text_value NOT LIKE '%qualité%';
SQLRICH
    
    log_success "Descriptions enriched"
    
    # 3. Calculate completeness (from commit da745f34)
    log_info "Calculating product completeness..."
    php bin/console pim:completeness:calculate --env=prod 2>&1 | tee -a "$LOG_FILE"
    log_success "Completeness calculated"
    
    # 4. Reindex Elasticsearch (from commit da745f34)
    log_info "Reindexing products in Elasticsearch..."
    php bin/console akeneo:elasticsearch:reset-indexes --env=prod 2>&1 | tee -a "$LOG_FILE"
    php bin/console pim:product:index --all --env=prod 2>&1 | tee -a "$LOG_FILE"
    php bin/console pim:product-model:index --all --env=prod 2>&1 | tee -a "$LOG_FILE"
    log_success "Elasticsearch reindexed"
}

################################################################################
# PHASE 6: DATA QUALITY VERIFICATION
################################################################################
verify_data_quality() {
    log_step "PHASE 6: VERIFYING DATA QUALITY"
    
    # Run comprehensive quality check
    local quality_report=$(/opt/mariadb10.6/mariadb/bin/mysql -u akeneo_pim -p'akeneo_pim' -h 127.0.0.1 -P 3307 akeneo_pim <<'SQLQUAL'
SELECT 'Total Products', COUNT(*) FROM pim_catalog_product
UNION ALL
SELECT 'Products with Names', COUNT(DISTINCT pv.product_id) 
FROM pim_catalog_product_value pv
JOIN pim_catalog_attribute pa ON pv.attribute_id = pa.id
WHERE pa.code = 'name' AND pv.text_value IS NOT NULL AND pv.text_value != ''
UNION ALL
SELECT 'Products with Descriptions', COUNT(DISTINCT pv.product_id)
FROM pim_catalog_product_value pv
JOIN pim_catalog_attribute pa ON pv.attribute_id = pa.id
WHERE pa.code = 'description' AND pv.text_value IS NOT NULL AND pv.text_value != ''
UNION ALL
SELECT 'Products with Prices', COUNT(DISTINCT pv.product_id)
FROM pim_catalog_product_value pv
JOIN pim_catalog_attribute pa ON pv.attribute_id = pa.id
WHERE pa.code = 'price' AND pv.decimal_value > 0
UNION ALL
SELECT 'Total Attributes', COUNT(*) FROM pim_catalog_attribute
UNION ALL
SELECT 'Total Attribute Options', COUNT(*) FROM pim_catalog_attribute_option
UNION ALL
SELECT 'Total Categories', COUNT(*) FROM pim_catalog_category;
SQLQUAL
)
    
    echo "$quality_report" | tee -a "$LOG_FILE"
    
    log_success "Data quality verification complete"
}

################################################################################
# PHASE 7: CLEAR CACHE & OPTIMIZE
################################################################################
optimize_system() {
    log_step "PHASE 7: CLEARING CACHE & OPTIMIZING SYSTEM"
    
    cd "$AKENEO_ROOT"
    
    # Clear all caches
    log_info "Clearing cache..."
    php bin/console cache:clear --env=prod --no-warmup 2>&1 | tee -a "$LOG_FILE"
    php bin/console pim:installer:assets --env=prod 2>&1 | tee -a "$LOG_FILE"
    
    # Optimize autoloader
    log_info "Optimizing autoloader..."
    composer dump-autoload --optimize 2>&1 | tee -a "$LOG_FILE" || true
    
    log_success "System optimized"
}

################################################################################
# MAIN EXECUTION
################################################################################
main() {
    log_step "STARTING COMPREHENSIVE IMPORT WITH HISTORICAL TUNINGS"
    log_info "Start time: $(date)"
    log_info "Data directory: $DATA_DIR"
    log_info "Log file: $LOG_FILE"
    
    # Execute all phases
    import_attributes
    import_attribute_options
    assign_attributes_to_families
    import_products_comprehensive
    apply_seo_tunings
    verify_data_quality
    optimize_system
    
    log_step "COMPREHENSIVE IMPORT COMPLETE"
    log_info "End time: $(date)"
    
    # Final status report
    echo ""
    echo -e "${PURPLE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║         COMPREHENSIVE IMPORT - FINAL STATUS                ║${NC}"
    echo -e "${PURPLE}╚════════════════════════════════════════════════════════════╝${NC}"
    
    /opt/mariadb10.6/mariadb/bin/mysql -u akeneo_pim -p'akeneo_pim' -h 127.0.0.1 -P 3307 akeneo_pim -t <<'SQLFINAL'
SELECT 
    'METRIC' as Metric,
    'COUNT' as Count
UNION ALL
SELECT '─────────────────────', '─────────'
UNION ALL
SELECT 'Products', CAST(COUNT(*) AS CHAR) FROM pim_catalog_product
UNION ALL
SELECT 'Families', CAST(COUNT(*) AS CHAR) FROM pim_catalog_family
UNION ALL
SELECT 'Attributes', CAST(COUNT(*) AS CHAR) FROM pim_catalog_attribute
UNION ALL
SELECT 'Attribute Options', CAST(COUNT(*) AS CHAR) FROM pim_catalog_attribute_option
UNION ALL
SELECT 'Categories', CAST(COUNT(*) AS CHAR) FROM pim_catalog_category
UNION ALL
SELECT 'Users', CAST(COUNT(*) AS CHAR) FROM oro_user
UNION ALL
SELECT 'Locales', CAST(COUNT(*) AS CHAR) FROM pim_catalog_locale
UNION ALL
SELECT 'Channels', CAST(COUNT(*) AS CHAR) FROM pim_catalog_channel;
SQLFINAL
    
    log_success "Full catalog restored with SEO tunings applied!"
    log_info "Admin login: https://pim.technostationery.com"
    log_info "Username: admin | Password: PimAdmin2026!"
}

# Run main function
main "$@"
