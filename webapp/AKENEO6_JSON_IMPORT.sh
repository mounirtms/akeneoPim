#!/bin/bash

################################################################################
# AKENEO 6.0+ JSON-BASED IMPORT
# Uses raw_values JSON column for product data
################################################################################

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

LOG_FILE="/home/pim/json_import_$(date +%Y%m%d_%H%M%S).log"

log_step() { echo -e "${CYAN}═══ $1 ═══${NC}" | tee -a "$LOG_FILE"; }
log_info() { echo -e "${BLUE}ℹ️  $1${NC}" | tee -a "$LOG_FILE"; }
log_success() { echo -e "${GREEN}✅ $1${NC}" | tee -a "$LOG_FILE"; }

run_sql() {
    /opt/mariadb10.6/mariadb/bin/mysql -u akeneo_pim -p'akeneo_pim' -h 127.0.0.1 -P 3307 akeneo_pim -e "$1"
}

################################################################################
# PHASE 1: IMPORT PRODUCTS WITH JSON RAW_VALUES
################################################################################
import_products_json() {
    log_step "PHASE 1: IMPORTING PRODUCTS WITH JSON FORMAT"
    
    log_info "Extracting products from Elasticsearch..."
    
    # Extract and convert to Akeneo JSON format
    python3 << 'PYTHON' > /tmp/products_json_insert.sql
import json, sys

try:
    # Read Elasticsearch data
    with open('/tmp/es_products_batch1.json', 'r') as f:
        es_data = json.load(f)
    
    print("-- Bulk product insert with JSON raw_values")
    print("SET @products_family = (SELECT id FROM pim_catalog_family WHERE code = 'products' LIMIT 1);")
    print("")
    
    count = 0
    for hit in es_data.get('hits', {}).get('hits', []):
        prod = hit.get('_source', {})
        sku = prod.get('sku', '').replace("'", "\\'").replace("\\", "\\\\")
        
        if not sku or count >= 500:
            continue
        
        # Build Akeneo raw_values JSON structure
        raw_values = {}
        
        # Name (localizable)
        name = prod.get('name', '')
        if isinstance(name, dict):
            name = name.get('fr_FR', '')
        if name:
            raw_values['name'] = [{
                'locale': 'fr_FR',
                'scope': None,
                'data': str(name)[:255]
            }]
        
        # Description (localizable)
        desc = prod.get('description', '')
        if isinstance(desc, dict):
            desc = desc.get('fr_FR', '')
        if desc:
            raw_values['description'] = [{
                'locale': 'fr_FR',
                'scope': None,
                'data': str(desc)[:5000]
            }]
        
        # Short description (localizable)
        short_desc = prod.get('short_description', '')
        if isinstance(short_desc, dict):
            short_desc = short_desc.get('fr_FR', '')
        if short_desc:
            raw_values['short_description'] = [{
                'locale': 'fr_FR',
                'scope': None,
                'data': str(short_desc)[:500]
            }]
        
        # Price (non-localizable, non-scopable)
        price = prod.get('price', 0)
        if isinstance(price, dict):
            price = price.get('price_0_1', 0)
        try:
            price_val = float(price)
            if price_val > 0:
                raw_values['price'] = [{
                    'locale': None,
                    'scope': None,
                    'data': [{'amount': str(price_val), 'currency': 'DZD'}]
                }]
        except:
            pass
        
        # Brand (non-localizable)
        brand = prod.get('brand', 'TECHNO')
        if brand:
            raw_values['brand'] = [{
                'locale': None,
                'scope': None,
                'data': str(brand)[:50]
            }]
        
        # Status (enabled/disabled)
        status = 1 if prod.get('status', '') == 'Activé' else 0
        
        # Convert raw_values to JSON and escape for SQL
        raw_values_json = json.dumps(raw_values, ensure_ascii=False)
        raw_values_escaped = raw_values_json.replace("'", "\\'").replace("\\", "\\\\")
        
        # Insert product with JSON raw_values
        print(f"INSERT INTO pim_catalog_product (identifier, family_id, is_enabled, raw_values, created, updated)")
        print(f"VALUES ('{sku}', @products_family, {status}, '{raw_values_escaped}', NOW(), NOW())")
        print(f"ON DUPLICATE KEY UPDATE raw_values = '{raw_values_escaped}', updated = NOW();")
        print("")
        
        count += 1
    
    print(f"-- Total products: {count}")
    
except Exception as e:
    print(f"-- Error: {e}", file=sys.stderr)
    import traceback
    traceback.print_exc(file=sys.stderr)
PYTHON
    
    # Execute
    log_info "Executing bulk insert..."
    /opt/mariadb10.6/mariadb/bin/mysql -u akeneo_pim -p'akeneo_pim' -h 127.0.0.1 -P 3307 akeneo_pim < /tmp/products_json_insert.sql 2>&1 | tee -a "$LOG_FILE"
    
    local count=$(run_sql "SELECT COUNT(*) FROM pim_catalog_product;" | tail -1)
    log_success "Imported $count products"
}

################################################################################
# PHASE 2: LINK PRODUCTS TO CATEGORIES
################################################################################
link_categories() {
    log_step "PHASE 2: LINKING PRODUCTS TO CATEGORIES"
    
    log_info "Extracting category mappings..."
    
    /opt/mariadb10.6/mariadb/bin/mysql -u root -p'YourNewStrongPassword' -h 127.0.0.1 -P 3307 beta_dBT8x12y22 <<'SQL' > /tmp/category_map.csv
SELECT 
    cpe.sku,
    GROUP_CONCAT(CONCAT('cat_', ccp.category_id) SEPARATOR ',') as categories
FROM catalog_category_product ccp
JOIN catalog_product_entity cpe ON ccp.product_id = cpe.entity_id
WHERE ccp.category_id > 2
GROUP BY cpe.sku
LIMIT 10000;
SQL
    
    # Create SQL for category links
    python3 << 'PYTHON' > /tmp/category_links.sql
count = 0
try:
    with open('/tmp/category_map.csv', 'r') as f:
        for line in f:
            if '\t' not in line:
                continue
            parts = line.strip().split('\t')
            if len(parts) != 2 or parts[0] == 'sku':
                continue
            
            sku = parts[0].replace("'", "''")
            cat_codes = parts[1].split(',')
            
            for cat_code in cat_codes[:5]:  # Max 5 categories per product
                cat_code = cat_code.strip().replace("'", "''")
                print(f"INSERT IGNORE INTO pim_catalog_category_product (product_id, category_id)")
                print(f"SELECT p.id, c.id FROM pim_catalog_product p, pim_catalog_category c")
                print(f"WHERE p.identifier = '{sku}' AND c.code = '{cat_code}';")
                count += 1
except Exception as e:
    print(f"-- Error: {e}")

print(f"-- Total links: {count}")
PYTHON
    
    /opt/mariadb10.6/mariadb/bin/mysql -u akeneo_pim -p'akeneo_pim' -h 127.0.0.1 -P 3307 akeneo_pim < /tmp/category_links.sql 2>&1 | tee -a "$LOG_FILE"
    
    log_success "Categories linked"
}

################################################################################
# PHASE 3: APPLY SEO OPTIMIZATIONS
################################################################################
apply_seo() {
    log_step "PHASE 3: APPLYING SEO OPTIMIZATIONS"
    
    log_info "Updating product JSON for SEO..."
    
    # We'll use Python to update JSON fields
    python3 << 'PYTHON'
import pymysql
import json
import re

try:
    conn = pymysql.connect(
        host='127.0.0.1',
        port=3307,
        user='akeneo_pim',
        password='akeneo_pim',
        database='akeneo_pim'
    )
    cursor = conn.cursor()
    
    # Get all products
    cursor.execute("SELECT id, identifier, raw_values FROM pim_catalog_product WHERE raw_values IS NOT NULL")
    products = cursor.fetchall()
    
    updated = 0
    for prod_id, sku, raw_values_str in products:
        try:
            raw_values = json.loads(raw_values_str)
            modified = False
            
            # Optimize name: capitalize first letter, remove extra spaces
            if 'name' in raw_values:
                for val in raw_values['name']:
                    if val.get('data'):
                        original = val['data']
                        # Remove extra spaces
                        optimized = re.sub(r'\s+', ' ', original).strip()
                        # Capitalize first letter
                        if optimized and optimized[0].islower():
                            optimized = optimized[0].upper() + optimized[1:]
                        if optimized != original:
                            val['data'] = optimized
                            modified = True
            
            # Optimize description: remove extra spaces
            if 'description' in raw_values:
                for val in raw_values['description']:
                    if val.get('data'):
                        original = val['data']
                        optimized = re.sub(r'\s+', ' ', original).strip()
                        if optimized != original:
                            val['data'] = optimized
                            modified = True
            
            # Update if modified
            if modified:
                new_json = json.dumps(raw_values, ensure_ascii=False)
                cursor.execute(
                    "UPDATE pim_catalog_product SET raw_values = %s, updated = NOW() WHERE id = %s",
                    (new_json, prod_id)
                )
                updated += 1
        except:
            pass
    
    conn.commit()
    cursor.close()
    conn.close()
    
    print(f"Updated {updated} products with SEO optimizations")
    
except Exception as e:
    print(f"Error: {e}")
    import traceback
    traceback.print_exc()
PYTHON
    
    log_success "SEO optimizations applied"
}

################################################################################
# PHASE 4: FINAL REPORT
################################################################################
final_report() {
    log_step "PHASE 4: GENERATING FINAL REPORT"
    
    echo ""
    echo -e "${PURPLE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║          AKENEO 6.0+ JSON IMPORT - FINAL STATUS            ║${NC}"
    echo -e "${PURPLE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    /opt/mariadb10.6/mariadb/bin/mysql -u akeneo_pim -p'akeneo_pim' -h 127.0.0.1 -P 3307 akeneo_pim -t <<'SQLFINAL'
SELECT 
    'METRIC' as Metric,
    'COUNT' as Count
UNION ALL
SELECT '─────────────────────────', '──────────'
UNION ALL
SELECT '✅ Products', CAST(COUNT(*) AS CHAR) FROM pim_catalog_product
UNION ALL
SELECT '✅ Enabled Products', CAST(SUM(is_enabled) AS CHAR) FROM pim_catalog_product
UNION ALL
SELECT '✅ Families', CAST(COUNT(*) AS CHAR) FROM pim_catalog_family
UNION ALL
SELECT '✅ Attributes', CAST(COUNT(*) AS CHAR) FROM pim_catalog_attribute
UNION ALL
SELECT '✅ Categories', CAST(COUNT(*) AS CHAR) FROM pim_catalog_category
UNION ALL
SELECT '✅ Category Links', CAST(COUNT(*) AS CHAR) FROM pim_catalog_category_product
UNION ALL
SELECT '─────────────────────────', '──────────'
UNION ALL
SELECT '📊 Products with Data', CAST(COUNT(*) AS CHAR) 
FROM pim_catalog_product 
WHERE JSON_LENGTH(raw_values) > 0;
SQLFINAL
    
    echo ""
    log_success "Import complete!"
    log_info "PIM URL: https://pim.technostationery.com"
    log_info "Login: admin / PimAdmin2026!"
    echo ""
}

################################################################################
# MAIN
################################################################################
main() {
    log_step "AKENEO 6.0+ JSON-BASED IMPORT STARTING"
    log_info "Start: $(date)"
    
    # Check if Python MySQL library is available
    python3 -c "import pymysql" 2>/dev/null || {
        log_info "Installing PyMySQL..."
        pip3 install pymysql --quiet 2>&1 | tee -a "$LOG_FILE"
    }
    
    import_products_json
    link_categories
    apply_seo
    final_report
    
    log_info "End: $(date)"
    log_success "ALL OPERATIONS COMPLETE"
}

main "$@"
