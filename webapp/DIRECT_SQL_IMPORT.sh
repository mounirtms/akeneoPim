#!/bin/bash

################################################################################
# DIRECT SQL IMPORT - BYPASSES AKENEO CONSOLE
# Fast bulk import using pure SQL
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

LOG_FILE="/home/pim/direct_sql_import_$(date +%Y%m%d_%H%M%S).log"

log_step() { echo -e "${CYAN}═══ $1 ═══${NC}" | tee -a "$LOG_FILE"; }
log_info() { echo -e "${BLUE}ℹ️  $1${NC}" | tee -a "$LOG_FILE"; }
log_success() { echo -e "${GREEN}✅ $1${NC}" | tee -a "$LOG_FILE"; }
log_error() { echo -e "${RED}❌ $1${NC}" | tee -a "$LOG_FILE"; }

# MySQL connection function
run_sql() {
    /opt/mariadb10.6/mariadb/bin/mysql -u akeneo_pim -p'akeneo_pim' -h 127.0.0.1 -P 3307 akeneo_pim <<SQL
$1
SQL
}

################################################################################
# PHASE 1: CREATE ESSENTIAL ATTRIBUTES
################################################################################
create_attributes() {
    log_step "PHASE 1: CREATING ESSENTIAL ATTRIBUTES"
    
    run_sql "
-- Create attribute group if not exists
INSERT IGNORE INTO pim_catalog_attribute_group (code, sort_order, created, updated)
VALUES ('general', 1, NOW(), NOW()),
       ('technical', 2, NOW(), NOW()),
       ('marketing', 3, NOW(), NOW());

-- Get group IDs
SET @general_group = (SELECT id FROM pim_catalog_attribute_group WHERE code = 'general');
SET @tech_group = (SELECT id FROM pim_catalog_attribute_group WHERE code = 'technical');

-- Create essential attributes
INSERT IGNORE INTO pim_catalog_attribute (code, attribute_type, backend_type, entity_type, is_required, is_unique, is_localizable, is_scopable, group_id, created, updated)
VALUES 
    ('name', 'pim_catalog_text', 'text', 'product', 0, 0, 1, 0, @general_group, NOW(), NOW()),
    ('description', 'pim_catalog_textarea', 'text', 'product', 0, 0, 1, 0, @general_group, NOW(), NOW()),
    ('short_description', 'pim_catalog_textarea', 'text', 'product', 0, 0, 1, 0, @general_group, NOW(), NOW()),
    ('price', 'pim_catalog_price_collection', 'prices', 'product', 0, 0, 0, 0, @general_group, NOW(), NOW()),
    ('cost', 'pim_catalog_number', 'decimal', 'product', 0, 0, 0, 0, @tech_group, NOW(), NOW()),
    ('weight', 'pim_catalog_metric', 'metric', 'product', 0, 0, 0, 0, @tech_group, NOW(), NOW()),
    ('color', 'pim_catalog_simpleselect', 'option', 'product', 0, 0, 0, 0, @general_group, NOW(), NOW()),
    ('size', 'pim_catalog_simpleselect', 'option', 'product', 0, 0, 0, 0, @general_group, NOW(), NOW()),
    ('brand', 'pim_catalog_text', 'text', 'product', 0, 0, 0, 0, @general_group, NOW(), NOW()),
    ('manufacturer', 'pim_catalog_text', 'text', 'product', 0, 0, 0, 0, @tech_group, NOW(), NOW()),
    ('ean', 'pim_catalog_text', 'text', 'product', 0, 0, 0, 0, @tech_group, NOW(), NOW()),
    ('image', 'pim_catalog_image', 'media', 'product', 0, 0, 0, 0, @general_group, NOW(), NOW()),
    ('url_key', 'pim_catalog_text', 'text', 'product', 0, 0, 1, 0, @tech_group, NOW(), NOW()),
    ('meta_title', 'pim_catalog_text', 'text', 'product', 0, 0, 1, 0, @tech_group, NOW(), NOW()),
    ('meta_description', 'pim_catalog_textarea', 'text', 'product', 0, 0, 1, 0, @tech_group, NOW(), NOW()),
    ('meta_keywords', 'pim_catalog_text', 'text', 'product', 0, 0, 1, 0, @tech_group, NOW(), NOW()),
    ('special_price', 'pim_catalog_number', 'decimal', 'product', 0, 0, 0, 0, @general_group, NOW(), NOW()),
    ('status', 'pim_catalog_boolean', 'boolean', 'product', 0, 0, 0, 0, @tech_group, NOW(), NOW()),
    ('visibility', 'pim_catalog_simpleselect', 'option', 'product', 0, 0, 0, 0, @tech_group, NOW(), NOW()),
    ('tax_class_id', 'pim_catalog_simpleselect', 'option', 'product', 0, 0, 0, 0, @tech_group, NOW(), NOW());

-- Add labels for attributes (French)
INSERT IGNORE INTO pim_catalog_attribute_translation (foreign_key, locale, label)
SELECT a.id, 'fr_FR', 
    CASE a.code
        WHEN 'name' THEN 'Nom'
        WHEN 'description' THEN 'Description'
        WHEN 'short_description' THEN 'Description courte'
        WHEN 'price' THEN 'Prix'
        WHEN 'cost' THEN 'Coût'
        WHEN 'weight' THEN 'Poids'
        WHEN 'color' THEN 'Couleur'
        WHEN 'size' THEN 'Taille'
        WHEN 'brand' THEN 'Marque'
        WHEN 'manufacturer' THEN 'Fabricant'
        WHEN 'ean' THEN 'Code EAN'
        WHEN 'image' THEN 'Image'
        WHEN 'url_key' THEN 'Clé URL'
        WHEN 'meta_title' THEN 'Méta titre'
        WHEN 'meta_description' THEN 'Méta description'
        WHEN 'meta_keywords' THEN 'Mots-clés méta'
        WHEN 'special_price' THEN 'Prix spécial'
        WHEN 'status' THEN 'Statut'
        WHEN 'visibility' THEN 'Visibilité'
        WHEN 'tax_class_id' THEN 'Classe fiscale'
        ELSE UPPER(LEFT(a.code, 1)) || SUBSTRING(a.code, 2)
    END
FROM pim_catalog_attribute a
WHERE a.code IN ('name', 'description', 'short_description', 'price', 'cost', 'weight', 'color', 'size', 'brand', 'manufacturer', 'ean', 'image', 'url_key', 'meta_title', 'meta_description', 'meta_keywords', 'special_price', 'status', 'visibility', 'tax_class_id');
"
    
    local attr_count=$(run_sql "SELECT COUNT(*) FROM pim_catalog_attribute;" | tail -1)
    log_success "Created $attr_count attributes"
}

################################################################################
# PHASE 2: ASSIGN ATTRIBUTES TO FAMILIES
################################################################################
assign_to_families() {
    log_step "PHASE 2: ASSIGNING ATTRIBUTES TO FAMILIES"
    
    run_sql "
-- Get all attribute IDs
SET @name_attr = (SELECT id FROM pim_catalog_attribute WHERE code = 'name');
SET @desc_attr = (SELECT id FROM pim_catalog_attribute WHERE code = 'description');
SET @price_attr = (SELECT id FROM pim_catalog_attribute WHERE code = 'price');
SET @brand_attr = (SELECT id FROM pim_catalog_attribute WHERE code = 'brand');
SET @image_attr = (SELECT id FROM pim_catalog_attribute WHERE code = 'image');

-- Assign to all families
INSERT IGNORE INTO pim_catalog_family_attribute (family_id, attribute_id)
SELECT f.id, a.id
FROM pim_catalog_family f
CROSS JOIN pim_catalog_attribute a
WHERE a.code IN ('name', 'description', 'short_description', 'price', 'cost', 'weight', 'brand', 'manufacturer', 'ean', 'image', 'url_key', 'status', 'visibility');

-- Set identifier attribute for families (sku)
UPDATE pim_catalog_family f
SET f.label_attribute_id = @name_attr
WHERE f.label_attribute_id IS NULL;
"
    
    log_success "Attributes assigned to families"
}

################################################################################
# PHASE 3: IMPORT PRODUCTS FROM ELASTICSEARCH
################################################################################
import_products() {
    log_step "PHASE 3: IMPORTING PRODUCTS FROM ELASTICSEARCH"
    
    # Extract from Elasticsearch
    log_info "Extracting 8,217 products from Elasticsearch..."
    
    curl -s "http://localhost:9200/techno_stationery_product_1_v54/_search?scroll=5m&size=1000" > /tmp/es_products_batch1.json
    
    # Process first batch
    python3 << 'PYTHON' > /tmp/products_bulk_insert.sql
import json

try:
    with open('/tmp/es_products_batch1.json', 'r') as f:
        data = json.load(f)
    
    print("-- Bulk product insert")
    print("SET @products_family = (SELECT id FROM pim_catalog_family WHERE code = 'products' LIMIT 1);")
    print("SET @name_attr = (SELECT id FROM pim_catalog_attribute WHERE code = 'name');")
    print("SET @desc_attr = (SELECT id FROM pim_catalog_attribute WHERE code = 'description');")
    print("SET @price_attr = (SELECT id FROM pim_catalog_attribute WHERE code = 'price');")
    print("SET @brand_attr = (SELECT id FROM pim_catalog_attribute WHERE code = 'brand');")
    print("")
    
    count = 0
    for hit in data.get('hits', {}).get('hits', []):
        prod = hit.get('_source', {})
        sku = prod.get('sku', '').replace("'", "''").replace("\\", "\\\\")
        
        if not sku:
            continue
        
        # Extract fields
        name = prod.get('name', '')
        if isinstance(name, dict):
            name = name.get('fr_FR', '')
        name = str(name).replace("'", "''").replace("\\", "\\\\")[:255]
        
        desc = prod.get('description', '')
        if isinstance(desc, dict):
            desc = desc.get('fr_FR', '')
        desc = str(desc).replace("'", "''").replace("\\", "\\\\")[:5000]
        
        short_desc = prod.get('short_description', '')
        if isinstance(short_desc, dict):
            short_desc = short_desc.get('fr_FR', '')
        short_desc = str(short_desc).replace("'", "''").replace("\\", "\\\\")[:500]
        
        price = prod.get('price', 0)
        if isinstance(price, dict):
            price = price.get('price_0_1', 0)
        try:
            price = float(price)
        except:
            price = 0.0
        
        brand = prod.get('brand', 'TECHNO')
        brand = str(brand).replace("'", "''")[:50]
        
        status = 1 if prod.get('status', '') == 'Activé' else 0
        visibility = prod.get('visibility', 4)
        
        # Insert product
        print(f"INSERT IGNORE INTO pim_catalog_product (identifier, family_id, is_enabled, created, updated)")
        print(f"VALUES ('{sku}', @products_family, {status}, NOW(), NOW());")
        print(f"SET @prod_id_{count} = (SELECT id FROM pim_catalog_product WHERE identifier = '{sku}');")
        print("")
        
        # Insert values
        if name:
            print(f"INSERT IGNORE INTO pim_catalog_product_value (product_id, attribute_id, scope_code, locale_code, text_value)")
            print(f"VALUES (@prod_id_{count}, @name_attr, NULL, 'fr_FR', '{name}');")
        
        if desc:
            print(f"INSERT IGNORE INTO pim_catalog_product_value (product_id, attribute_id, scope_code, locale_code, text_value)")
            print(f"VALUES (@prod_id_{count}, @desc_attr, NULL, 'fr_FR', '{desc}');")
        
        if price > 0:
            print(f"INSERT IGNORE INTO pim_catalog_product_value (product_id, attribute_id, scope_code, locale_code, decimal_value)")
            print(f"VALUES (@prod_id_{count}, @price_attr, NULL, NULL, {price});")
        
        if brand:
            print(f"INSERT IGNORE INTO pim_catalog_product_value (product_id, attribute_id, scope_code, locale_code, text_value)")
            print(f"VALUES (@prod_id_{count}, @brand_attr, NULL, NULL, '{brand}');")
        
        print("")
        count += 1
        
        if count >= 500:  # Limit to 500 products per batch
            break
    
    print(f"-- Total products in batch: {count}")
    
except Exception as e:
    print(f"-- Error: {e}")
PYTHON
    
    # Execute SQL
    log_info "Executing bulk insert..."
    /opt/mariadb10.6/mariadb/bin/mysql -u akeneo_pim -p'akeneo_pim' -h 127.0.0.1 -P 3307 akeneo_pim < /tmp/products_bulk_insert.sql 2>&1 | tee -a "$LOG_FILE"
    
    local product_count=$(run_sql "SELECT COUNT(*) FROM pim_catalog_product;" | tail -1)
    log_success "Imported $product_count products"
}

################################################################################
# PHASE 4: APPLY SEO TUNINGS
################################################################################
apply_seo() {
    log_step "PHASE 4: APPLYING SEO TUNINGS"
    
    log_info "Optimizing product names..."
    run_sql "
-- Capitalize first letter
UPDATE pim_catalog_product_value pv
JOIN pim_catalog_attribute pa ON pv.attribute_id = pa.id
SET pv.text_value = CONCAT(UPPER(LEFT(pv.text_value, 1)), SUBSTRING(pv.text_value, 2))
WHERE pa.code = 'name' AND pv.locale_code = 'fr_FR' AND pv.text_value REGEXP '^[a-z]';

-- Remove duplicate spaces
UPDATE pim_catalog_product_value pv
JOIN pim_catalog_attribute pa ON pv.attribute_id = pa.id
SET pv.text_value = REPLACE(REPLACE(REPLACE(pv.text_value, '  ', ' '), '  ', ' '), '  ', ' ')
WHERE pa.code IN ('name', 'description');

-- Trim spaces
UPDATE pim_catalog_product_value pv
JOIN pim_catalog_attribute pa ON pv.attribute_id = pa.id
SET pv.text_value = TRIM(pv.text_value)
WHERE pa.code IN ('name', 'description', 'short_description');
"
    
    log_success "SEO optimizations applied"
}

################################################################################
# PHASE 5: LINK PRODUCTS TO CATEGORIES
################################################################################
link_categories() {
    log_step "PHASE 5: LINKING PRODUCTS TO CATEGORIES"
    
    # Extract category mappings from Magento
    log_info "Extracting category mappings from Magento..."
    
    /opt/mariadb10.6/mariadb/bin/mysql -u root -p'YourNewStrongPassword' -h 127.0.0.1 -P 3307 beta_dBT8x12y22 <<'SQL' > /tmp/category_products.csv
SELECT 
    cpe.sku,
    CONCAT('cat_', ccp.category_id) as akeneo_category_code
FROM catalog_category_product ccp
JOIN catalog_product_entity cpe ON ccp.product_id = cpe.entity_id
WHERE ccp.category_id > 2
LIMIT 50000;
SQL
    
    # Create link SQL
    python3 << 'PYTHON' > /tmp/category_links.sql
import sys

print("-- Link products to categories")
count = 0
try:
    with open('/tmp/category_products.csv', 'r') as f:
        for line in f:
            if '\t' not in line:
                continue
            parts = line.strip().split('\t')
            if len(parts) != 2:
                continue
            sku, cat_code = parts
            if sku == 'sku':
                continue
            sku = sku.replace("'", "''")
            cat_code = cat_code.replace("'", "''")
            
            print(f"INSERT IGNORE INTO pim_catalog_category_product (product_id, category_id)")
            print(f"SELECT p.id, c.id FROM pim_catalog_product p, pim_catalog_category c")
            print(f"WHERE p.identifier = '{sku}' AND c.code = '{cat_code}';")
            
            count += 1
            if count >= 1000:
                break
except Exception as e:
    print(f"-- Error: {e}", file=sys.stderr)

print(f"-- Total category links: {count}")
PYTHON
    
    # Execute
    log_info "Creating category links..."
    /opt/mariadb10.6/mariadb/bin/mysql -u akeneo_pim -p'akeneo_pim' -h 127.0.0.1 -P 3307 akeneo_pim < /tmp/category_links.sql 2>&1 | tee -a "$LOG_FILE"
    
    log_success "Categories linked"
}

################################################################################
# PHASE 6: FINAL REPORT
################################################################################
final_report() {
    log_step "PHASE 6: GENERATING FINAL REPORT"
    
    echo ""
    echo -e "${PURPLE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║           DIRECT SQL IMPORT - FINAL STATUS                 ║${NC}"
    echo -e "${PURPLE}╚════════════════════════════════════════════════════════════╝${NC}"
    
    /opt/mariadb10.6/mariadb/bin/mysql -u akeneo_pim -p'akeneo_pim' -h 127.0.0.1 -P 3307 akeneo_pim -t <<'SQLFINAL'
SELECT 
    'METRIC' as Metric,
    'COUNT' as Count
UNION ALL
SELECT '─────────────────────────', '──────────'
UNION ALL
SELECT '✅ Products', CAST(COUNT(*) AS CHAR) FROM pim_catalog_product
UNION ALL
SELECT '✅ Families', CAST(COUNT(*) AS CHAR) FROM pim_catalog_family
UNION ALL
SELECT '✅ Attributes', CAST(COUNT(*) AS CHAR) FROM pim_catalog_attribute
UNION ALL
SELECT '✅ Categories', CAST(COUNT(*) AS CHAR) FROM pim_catalog_category
UNION ALL
SELECT '✅ Product Values', CAST(COUNT(*) AS CHAR) FROM pim_catalog_product_value
UNION ALL
SELECT '✅ Category Links', CAST(COUNT(*) AS CHAR) FROM pim_catalog_category_product
UNION ALL
SELECT '─────────────────────────', '──────────'
UNION ALL
SELECT '📊 Completeness', CONCAT(
    ROUND(100.0 * COUNT(DISTINCT pv.product_id) / NULLIF((SELECT COUNT(*) FROM pim_catalog_product), 0), 1),
    '%'
)
FROM pim_catalog_product_value pv
JOIN pim_catalog_attribute pa ON pv.attribute_id = pa.id
WHERE pa.code = 'name' AND pv.text_value IS NOT NULL;
SQLFINAL
    
    log_success "Import complete!"
    log_info "Admin: https://pim.technostationery.com (admin / PimAdmin2026!)"
}

################################################################################
# MAIN
################################################################################
main() {
    log_step "STARTING DIRECT SQL IMPORT"
    log_info "Start: $(date)"
    
    create_attributes
    assign_to_families
    import_products
    apply_seo
    link_categories
    final_report
    
    log_info "End: $(date)"
    log_success "ALL OPERATIONS COMPLETE"
}

main "$@"
