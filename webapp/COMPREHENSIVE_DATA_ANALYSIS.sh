#!/bin/bash

################################################################################
# COMPREHENSIVE DATA ANALYSIS & FULL PRODUCT IMPORT
# Find missing products, extract ALL 9,538 from Magento, and import
################################################################################

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
NC='\033[0m'

LOG_FILE="/home/pim/full_data_analysis_$(date +%Y%m%d_%H%M%S).log"

log_step() { echo -e "${CYAN}═══ $1 ═══${NC}" | tee -a "$LOG_FILE"; }
log_info() { echo -e "${BLUE}ℹ️  $1${NC}" | tee -a "$LOG_FILE"; }
log_success() { echo -e "${GREEN}✅ $1${NC}" | tee -a "$LOG_FILE"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}" | tee -a "$LOG_FILE"; }
log_error() { echo -e "${RED}❌ $1${NC}" | tee -a "$LOG_FILE"; }

################################################################################
# PHASE 1: ANALYZE DATA SOURCES
################################################################################
analyze_data_sources() {
    log_step "PHASE 1: ANALYZING ALL DATA SOURCES"
    
    log_info "Checking Elasticsearch..."
    ES_COUNT=$(curl -s "http://localhost:9200/techno_stationery_product_1_v54/_count" | python3 -c "import json,sys; print(json.load(sys.stdin)['count'])")
    log_info "Elasticsearch: $ES_COUNT products"
    
    log_info "Checking Magento database..."
    MAGENTO_COUNT=$(/opt/mariadb10.6/mariadb/bin/mysql -u root -p'YourNewStrongPassword' -h 127.0.0.1 -P 3307 beta_dBT8x12y22 -N -e "SELECT COUNT(*) FROM catalog_product_entity;")
    log_info "Magento: $MAGENTO_COUNT products"
    
    log_info "Checking Akeneo current state..."
    AKENEO_COUNT=$(/opt/mariadb10.6/mariadb/bin/mysql -u akeneo_pim -p'akeneo_pim' -h 127.0.0.1 -P 3307 akeneo_pim -N -e "SELECT COUNT(*) FROM pim_catalog_product;")
    log_info "Akeneo: $AKENEO_COUNT products"
    
    log_info "Calculating discrepancies..."
    MISSING_FROM_AKENEO=$((MAGENTO_COUNT - AKENEO_COUNT))
    
    log_warning "Missing from Akeneo: $MISSING_FROM_AKENEO products"
    
    echo "$ES_COUNT" > /tmp/es_count.txt
    echo "$MAGENTO_COUNT" > /tmp/magento_count.txt
    echo "$AKENEO_COUNT" > /tmp/akeneo_count.txt
}

################################################################################
# PHASE 2: EXTRACT ALL PRODUCTS FROM MAGENTO
################################################################################
extract_all_magento_products() {
    log_step "PHASE 2: EXTRACTING ALL PRODUCTS FROM MAGENTO"
    
    log_info "Extracting ALL product SKUs from Magento..."
    
    /opt/mariadb10.6/mariadb/bin/mysql -u root -p'YourNewStrongPassword' -h 127.0.0.1 -P 3307 beta_dBT8x12y22 -N <<'SQL' > /tmp/all_magento_skus.txt
SELECT DISTINCT sku 
FROM catalog_product_entity 
WHERE sku IS NOT NULL 
AND sku != ''
ORDER BY entity_id;
SQL
    
    local sku_count=$(wc -l < /tmp/all_magento_skus.txt)
    log_success "Extracted $sku_count unique SKUs from Magento"
    
    log_info "Comparing with Akeneo SKUs..."
    /opt/mariadb10.6/mariadb/bin/mysql -u akeneo_pim -p'akeneo_pim' -h 127.0.0.1 -P 3307 akeneo_pim -N -e "SELECT identifier FROM pim_catalog_product ORDER BY identifier;" > /tmp/akeneo_skus.txt
    
    log_info "Finding missing SKUs..."
    comm -23 <(sort /tmp/all_magento_skus.txt) <(sort /tmp/akeneo_skus.txt) > /tmp/missing_skus.txt
    
    local missing_count=$(wc -l < /tmp/missing_skus.txt)
    log_warning "Found $missing_count products missing from Akeneo"
    
    log_info "Sample of missing SKUs:"
    head -10 /tmp/missing_skus.txt | tee -a "$LOG_FILE"
}

################################################################################
# PHASE 3: EXTRACT COMPLETE PRODUCT DATA FROM MAGENTO
################################################################################
extract_complete_product_data() {
    log_step "PHASE 3: EXTRACTING COMPLETE PRODUCT DATA FROM MAGENTO"
    
    log_info "Extracting base product information..."
    /opt/mariadb10.6/mariadb/bin/mysql -u root -p'YourNewStrongPassword' -h 127.0.0.1 -P 3307 beta_dBT8x12y22 <<'SQL' > /tmp/products_complete.tsv
SELECT 
    cpe.sku,
    cpe.type_id,
    cpe.created_at,
    cpe.updated_at
FROM catalog_product_entity cpe
ORDER BY cpe.entity_id
LIMIT 20000;
SQL
    
    log_info "Extracting VARCHAR attributes (text fields)..."
    /opt/mariadb10.6/mariadb/bin/mysql -u root -p'YourNewStrongPassword' -h 127.0.0.1 -P 3307 beta_dBT8x12y22 <<'SQL' > /tmp/products_varchar_all.tsv
SELECT 
    cpe.sku,
    ea.attribute_code,
    cpev.value,
    cpev.store_id
FROM catalog_product_entity_varchar cpev
JOIN catalog_product_entity cpe ON cpev.entity_id = cpe.entity_id
JOIN eav_attribute ea ON cpev.attribute_id = ea.attribute_id
WHERE ea.entity_type_id = 4
AND cpev.value IS NOT NULL
AND cpev.value != ''
ORDER BY cpe.sku, ea.attribute_code
LIMIT 100000;
SQL
    
    log_info "Extracting INT attributes (dropdown values)..."
    /opt/mariadb10.6/mariadb/bin/mysql -u root -p'YourNewStrongPassword' -h 127.0.0.1 -P 3307 beta_dBT8x12y22 <<'SQL' > /tmp/products_int_all.tsv
SELECT 
    cpe.sku,
    ea.attribute_code,
    cpei.value,
    cpei.store_id
FROM catalog_product_entity_int cpei
JOIN catalog_product_entity cpe ON cpei.entity_id = cpe.entity_id
JOIN eav_attribute ea ON cpei.attribute_id = ea.attribute_id
WHERE ea.entity_type_id = 4
AND cpei.value IS NOT NULL
ORDER BY cpe.sku, ea.attribute_code
LIMIT 100000;
SQL
    
    log_info "Extracting DECIMAL attributes (prices, numbers)..."
    /opt/mariadb10.6/mariadb/bin/mysql -u root -p'YourNewStrongPassword' -h 127.0.0.1 -P 3307 beta_dBT8x12y22 <<'SQL' > /tmp/products_decimal_all.tsv
SELECT 
    cpe.sku,
    ea.attribute_code,
    cped.value,
    cped.store_id
FROM catalog_product_entity_decimal cped
JOIN catalog_product_entity cpe ON cped.entity_id = cpe.entity_id
JOIN eav_attribute ea ON cped.attribute_id = ea.attribute_id
WHERE ea.entity_type_id = 4
AND cped.value IS NOT NULL
ORDER BY cpe.sku, ea.attribute_code
LIMIT 100000;
SQL
    
    log_info "Extracting TEXT attributes (long descriptions)..."
    /opt/mariadb10.6/mariadb/bin/mysql -u root -p'YourNewStrongPassword' -h 127.0.0.1 -P 3307 beta_dBT8x12y22 <<'SQL' > /tmp/products_text_all.tsv
SELECT 
    cpe.sku,
    ea.attribute_code,
    LEFT(cpet.value, 5000),
    cpet.store_id
FROM catalog_product_entity_text cpet
JOIN catalog_product_entity cpe ON cpet.entity_id = cpe.entity_id
JOIN eav_attribute ea ON cpet.attribute_id = ea.attribute_id
WHERE ea.entity_type_id = 4
AND cpet.value IS NOT NULL
AND cpet.value != ''
ORDER BY cpe.sku, ea.attribute_code
LIMIT 100000;
SQL
    
    local varchar_count=$(wc -l < /tmp/products_varchar_all.tsv)
    local int_count=$(wc -l < /tmp/products_int_all.tsv)
    local decimal_count=$(wc -l < /tmp/products_decimal_all.tsv)
    local text_count=$(wc -l < /tmp/products_text_all.tsv)
    
    log_success "Extracted attribute values:"
    log_info "  VARCHAR: $varchar_count values"
    log_info "  INT: $int_count values"
    log_info "  DECIMAL: $decimal_count values"
    log_info "  TEXT: $text_count values"
}

################################################################################
# PHASE 4: EXTRACT ALL BRANDS
################################################################################
extract_brands() {
    log_step "PHASE 4: EXTRACTING ALL BRANDS"
    
    log_info "Querying brand/manufacturer data..."
    
    /opt/mariadb10.6/mariadb/bin/mysql -u root -p'YourNewStrongPassword' -h 127.0.0.1 -P 3307 beta_dBT8x12y22 <<'SQL' > /tmp/all_brands.tsv
SELECT DISTINCT
    COALESCE(
        (SELECT cpev.value 
         FROM catalog_product_entity_varchar cpev 
         JOIN eav_attribute ea ON cpev.attribute_id = ea.attribute_id 
         WHERE ea.attribute_code IN ('brand', 'manufacturer') 
         AND cpev.entity_id = cpe.entity_id 
         AND ea.entity_type_id = 4 
         LIMIT 1),
        'TECHNO'
    ) as brand,
    COUNT(*) as product_count
FROM catalog_product_entity cpe
GROUP BY brand
ORDER BY product_count DESC;
SQL
    
    local brand_count=$(wc -l < /tmp/all_brands.tsv)
    log_success "Found $brand_count unique brands"
    
    log_info "Top brands:"
    head -20 /tmp/all_brands.tsv | tee -a "$LOG_FILE"
}

################################################################################
# PHASE 5: EXTRACT COMPLETE CATEGORY MAPPINGS
################################################################################
extract_category_mappings() {
    log_step "PHASE 5: EXTRACTING COMPLETE CATEGORY MAPPINGS"
    
    log_info "Extracting all product-category relationships..."
    
    /opt/mariadb10.6/mariadb/bin/mysql -u root -p'YourNewStrongPassword' -h 127.0.0.1 -P 3307 beta_dBT8x12y22 <<'SQL' > /tmp/all_category_mappings.tsv
SELECT 
    cpe.sku,
    ccp.category_id,
    cc.level,
    ccv.value as category_name
FROM catalog_category_product ccp
JOIN catalog_product_entity cpe ON ccp.product_id = cpe.entity_id
JOIN catalog_category_entity cc ON ccp.category_id = cc.entity_id
LEFT JOIN catalog_category_entity_varchar ccv 
    ON cc.entity_id = ccv.entity_id 
    AND ccv.attribute_id = (SELECT attribute_id FROM eav_attribute WHERE attribute_code = 'name' AND entity_type_id = 3 LIMIT 1)
    AND ccv.store_id = 0
WHERE ccp.category_id > 2
ORDER BY cpe.sku, cc.level;
SQL
    
    local mapping_count=$(wc -l < /tmp/all_category_mappings.tsv)
    log_success "Extracted $mapping_count category mappings"
}

################################################################################
# PHASE 6: GENERATE COMPREHENSIVE IMPORT PLAN
################################################################################
generate_import_plan() {
    log_step "PHASE 6: GENERATING COMPREHENSIVE IMPORT PLAN"
    
    cat > /tmp/import_plan.txt <<'PLAN'
═══════════════════════════════════════════════════════════════
                    COMPREHENSIVE IMPORT PLAN
═══════════════════════════════════════════════════════════════

PHASE 1: DATA PREPARATION (1-2 hours)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ Extract all products from Magento (DONE)
✓ Extract all attribute values (DONE)
✓ Extract all brands (DONE)
✓ Extract all category mappings (DONE)
○ Identify missing products
○ Build comprehensive product JSON structures

PHASE 2: MISSING PRODUCTS IMPORT (2-3 hours)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
○ Import ~1,324 missing products
○ Include all fields and attributes
○ Link to categories
○ Assign to families
Estimated time: 2-3 hours

PHASE 3: COMPLETE ATTRIBUTE ENRICHMENT (3-4 hours)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
○ Update ALL 8,217 existing products
○ Add missing attribute values from Magento
○ Include varchar, int, decimal, text attributes
○ Total attribute values: ~100,000+
Estimated time: 3-4 hours

PHASE 4: DATA QUALITY & CLEANING (2-3 hours)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
○ Identify and remove duplicate products
○ Fix malformed product names
○ Clean descriptions (remove HTML, fix encoding)
○ Validate prices (ensure all > 0)
○ Fix special characters and encoding issues
Estimated time: 2-3 hours

PHASE 5: IMAGE LINKING (1-2 hours)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
○ Map product SKUs to image files
○ Update raw_values with image paths
○ Verify image accessibility
○ Remove broken image links
Estimated time: 1-2 hours

PHASE 6: PRODUCT MODELS & VARIANTS (4-6 hours)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
○ Extract configurable products from Magento
○ Create family variants in Akeneo
○ Link simple products to parent models
○ Configure variant axes (color, size, etc.)
Estimated time: 4-6 hours

PHASE 7: FINAL OPTIMIZATION (2-3 hours)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
○ Calculate product completeness
○ Reindex Elasticsearch
○ Optimize database queries
○ Generate quality reports
○ Final verification
Estimated time: 2-3 hours

═══════════════════════════════════════════════════════════════
TOTAL ESTIMATED TIME: 15-23 hours
RECOMMENDED APPROACH: Execute phases sequentially over 2-3 days
═══════════════════════════════════════════════════════════════
PLAN
    
    cat /tmp/import_plan.txt | tee -a "$LOG_FILE"
}

################################################################################
# PHASE 7: GENERATE DATA QUALITY REPORT
################################################################################
generate_quality_report() {
    log_step "PHASE 7: GENERATING DATA QUALITY REPORT"
    
    /opt/mariadb10.6/mariadb/bin/mysql -u akeneo_pim -p'akeneo_pim' -h 127.0.0.1 -P 3307 akeneo_pim -t <<'SQLREPORT' > /tmp/data_quality_report.txt
SELECT '═══════════════════════════════════════════════' as '';
SELECT '      CURRENT DATA QUALITY REPORT             ' as '';
SELECT '═══════════════════════════════════════════════' as '';

SELECT '' as '';
SELECT 'METRIC' as Metric, 'CURRENT' as Current, 'TARGET' as Target, 'STATUS' as Status
UNION ALL SELECT '─────────────────────', '─────────', '─────────', '──────────'
UNION ALL
SELECT 'Total Products', 
    CAST(COUNT(*) AS CHAR),
    '9538',
    CONCAT(ROUND(100.0 * COUNT(*) / 9538, 1), '%')
FROM pim_catalog_product
UNION ALL
SELECT 'Products with Names',
    CAST(COUNT(*) AS CHAR),
    CAST((SELECT COUNT(*) FROM pim_catalog_product) AS CHAR),
    CONCAT(ROUND(100.0 * COUNT(*) / NULLIF((SELECT COUNT(*) FROM pim_catalog_product), 0), 1), '%')
FROM pim_catalog_product WHERE JSON_CONTAINS_PATH(raw_values, 'one', '$.name')
UNION ALL
SELECT 'Products with Descriptions',
    CAST(COUNT(*) AS CHAR),
    CAST((SELECT COUNT(*) FROM pim_catalog_product) AS CHAR),
    CONCAT(ROUND(100.0 * COUNT(*) / NULLIF((SELECT COUNT(*) FROM pim_catalog_product), 0), 1), '%')
FROM pim_catalog_product WHERE JSON_CONTAINS_PATH(raw_values, 'one', '$.description')
UNION ALL
SELECT 'Products with Prices',
    CAST(COUNT(*) AS CHAR),
    CAST((SELECT COUNT(*) FROM pim_catalog_product) AS CHAR),
    CONCAT(ROUND(100.0 * COUNT(*) / NULLIF((SELECT COUNT(*) FROM pim_catalog_product), 0), 1), '%')
FROM pim_catalog_product WHERE JSON_CONTAINS_PATH(raw_values, 'one', '$.price')
UNION ALL
SELECT 'Products in Categories',
    CAST(COUNT(DISTINCT product_id) AS CHAR),
    CAST((SELECT COUNT(*) FROM pim_catalog_product) AS CHAR),
    CONCAT(ROUND(100.0 * COUNT(DISTINCT product_id) / NULLIF((SELECT COUNT(*) FROM pim_catalog_product), 0), 1), '%')
FROM pim_catalog_category_product;
SQLREPORT
    
    cat /tmp/data_quality_report.txt | tee -a "$LOG_FILE"
}

################################################################################
# MAIN EXECUTION
################################################################################
main() {
    log_step "STARTING COMPREHENSIVE DATA ANALYSIS"
    log_info "Start time: $(date)"
    log_info "Log file: $LOG_FILE"
    
    analyze_data_sources
    extract_all_magento_products
    extract_complete_product_data
    extract_brands
    extract_category_mappings
    generate_import_plan
    generate_quality_report
    
    log_step "ANALYSIS COMPLETE"
    log_info "End time: $(date)"
    
    echo ""
    echo -e "${PURPLE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║           COMPREHENSIVE ANALYSIS COMPLETE                  ║${NC}"
    echo -e "${PURPLE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    log_success "All data extracted and analyzed"
    log_info "Next: Review import plan and execute phases sequentially"
    log_info "Extracted files available in /tmp/"
    log_info "Full log: $LOG_FILE"
}

main "$@"
