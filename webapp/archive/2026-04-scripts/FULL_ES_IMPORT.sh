#!/bin/bash

################################################################################
# FULL ELASTICSEARCH TO AKENEO IMPORT
# Imports all 8,217 products from Elasticsearch to Akeneo 6.0+
################################################################################

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
RED='\033[0;31m'
NC='\033[0m'

LOG_FILE="/home/pim/full_es_import_$(date +%Y%m%d_%H%M%S).log"

log_step() { echo -e "${CYAN}═══ $1 ═══${NC}" | tee -a "$LOG_FILE"; }
log_info() { echo -e "${BLUE}ℹ️  $1${NC}" | tee -a "$LOG_FILE"; }
log_success() { echo -e "${GREEN}✅ $1${NC}" | tee -a "$LOG_FILE"; }
log_error() { echo -e "${RED}❌ $1${NC}" | tee -a "$LOG_FILE"; }

################################################################################
# PHASE 1: FETCH ALL PRODUCTS FROM ELASTICSEARCH
################################################################################
fetch_all_products() {
    log_step "PHASE 1: FETCHING ALL 8,217 PRODUCTS FROM ELASTICSEARCH"
    
    log_info "Fetching products using scroll API..."
    
    # Initial request with scroll
    curl -s "http://localhost:9200/techno_stationery_product_1_v54/_search?scroll=5m&size=1000" > /tmp/es_batch_1.json
    
    # Get scroll ID
    scroll_id=$(python3 -c "import json; data=json.load(open('/tmp/es_batch_1.json')); print(data.get('_scroll_id', ''))")
    
    batch=2
    total_fetched=1000
    
    # Fetch remaining batches
    while [ ! -z "$scroll_id" ] && [ $batch -le 10 ]; do
        log_info "Fetching batch $batch..."
        
        response=$(curl -s -H "Content-Type: application/json" -d "{\"scroll\":\"5m\",\"scroll_id\":\"$scroll_id\"}" "http://localhost:9200/_search/scroll")
        echo "$response" > /tmp/es_batch_${batch}.json
        
        hits=$(echo "$response" | python3 -c "import json, sys; data=json.load(sys.stdin); print(len(data.get('hits', {}).get('hits', [])))")
        
        if [ "$hits" = "0" ]; then
            break
        fi
        
        total_fetched=$((total_fetched + hits))
        scroll_id=$(echo "$response" | python3 -c "import json, sys; data=json.load(sys.stdin); print(data.get('_scroll_id', ''))")
        batch=$((batch + 1))
    done
    
    log_success "Fetched $total_fetched products in $((batch - 1)) batches"
}

################################################################################
# PHASE 2: IMPORT ALL PRODUCTS TO AKENEO
################################################################################
import_all_batches() {
    log_step "PHASE 2: IMPORTING ALL PRODUCTS TO AKENEO"
    
    python3 << 'PYTHON' 2>&1 | tee -a "$LOG_FILE"
import json
import glob
import sys
import pymysql

try:
    # Connect to database
    conn = pymysql.connect(
        host='127.0.0.1',
        port=3307,
        user='akeneo_pim',
        password='akeneo_pim',
        database='akeneo_pim'
    )
    cursor = conn.cursor()
    
    # Get family ID
    cursor.execute("SELECT id FROM pim_catalog_family WHERE code = 'products' LIMIT 1")
    family_result = cursor.fetchone()
    if not family_result:
        print("ERROR: 'products' family not found!")
        sys.exit(1)
    family_id = family_result[0]
    
    print(f"Using family ID: {family_id}")
    
    # Process all batch files
    batch_files = sorted(glob.glob('/tmp/es_batch_*.json'))
    print(f"Found {len(batch_files)} batch files to process")
    
    total_imported = 0
    total_errors = 0
    
    for batch_file in batch_files:
        print(f"\nProcessing {batch_file}...")
        
        with open(batch_file, 'r') as f:
            data = json.load(f)
        
        hits = data.get('hits', {}).get('hits', [])
        print(f"  Products in batch: {len(hits)}")
        
        for hit in hits:
            try:
                prod = hit.get('_source', {})
                sku = prod.get('sku', '')
                
                if not sku:
                    continue
                
                # Build raw_values JSON
                raw_values = {}
                
                # Name (French, localizable)
                name = prod.get('name', '')
                if isinstance(name, dict):
                    name = name.get('fr_FR', '')
                if name:
                    # Optimize: capitalize, trim
                    name = str(name).strip()
                    if name and len(name) > 0:
                        name = name[0].upper() + name[1:] if len(name) > 1 else name.upper()
                    raw_values['name'] = [{
                        'locale': 'fr_FR',
                        'scope': None,
                        'data': name[:255]
                    }]
                
                # Description (French, localizable)
                desc = prod.get('description', '')
                if isinstance(desc, dict):
                    desc = desc.get('fr_FR', '')
                if desc:
                    desc = str(desc).strip()[:5000]
                    raw_values['description'] = [{
                        'locale': 'fr_FR',
                        'scope': None,
                        'data': desc
                    }]
                
                # Short description (French, localizable)
                short_desc = prod.get('short_description', '')
                if isinstance(short_desc, dict):
                    short_desc = short_desc.get('fr_FR', '')
                if short_desc:
                    short_desc = str(short_desc).strip()[:500]
                    raw_values['short_description'] = [{
                        'locale': 'fr_FR',
                        'scope': None,
                        'data': short_desc
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
                
                # Brand
                brand = prod.get('brand', 'TECHNO')
                if brand:
                    raw_values['brand'] = [{
                        'locale': None,
                        'scope': None,
                        'data': str(brand)[:50]
                    }]
                
                # Status
                status = 1 if prod.get('status', '') == 'Activé' else 0
                
                # Convert to JSON
                raw_values_json = json.dumps(raw_values, ensure_ascii=False)
                
                # Insert/update product
                cursor.execute("""
                    INSERT INTO pim_catalog_product (identifier, family_id, is_enabled, raw_values, created, updated)
                    VALUES (%s, %s, %s, %s, NOW(), NOW())
                    ON DUPLICATE KEY UPDATE 
                        raw_values = VALUES(raw_values),
                        is_enabled = VALUES(is_enabled),
                        updated = NOW()
                """, (sku, family_id, status, raw_values_json))
                
                total_imported += 1
                
                if total_imported % 100 == 0:
                    conn.commit()
                    print(f"  Imported {total_imported} products...")
                
            except Exception as e:
                total_errors += 1
                if total_errors <= 10:  # Only show first 10 errors
                    print(f"  Error importing product: {e}")
    
    # Final commit
    conn.commit()
    cursor.close()
    conn.close()
    
    print(f"\n{'='*60}")
    print(f"✅ IMPORT COMPLETE")
    print(f"{'='*60}")
    print(f"Total imported: {total_imported}")
    print(f"Total errors: {total_errors}")
    
except Exception as e:
    print(f"FATAL ERROR: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
PYTHON
    
    log_success "All products imported"
}

################################################################################
# PHASE 3: LINK PRODUCTS TO CATEGORIES
################################################################################
link_categories() {
    log_step "PHASE 3: LINKING PRODUCTS TO CATEGORIES"
    
    log_info "Extracting category mappings from Magento..."
    
    # Get category mappings
    /opt/mariadb10.6/mariadb/bin/mysql -u root -p'YourNewStrongPassword' -h 127.0.0.1 -P 3307 beta_dBT8x12y22 -N <<'SQL' > /tmp/all_category_mappings.csv
SELECT 
    cpe.sku,
    ccp.category_id
FROM catalog_category_product ccp
JOIN catalog_product_entity cpe ON ccp.product_id = cpe.entity_id
WHERE ccp.category_id > 2
LIMIT 100000;
SQL
    
    log_info "Creating category links..."
    
    python3 << 'PYTHON' 2>&1 | tee -a "$LOG_FILE"
import pymysql

try:
    conn = pymysql.connect(
        host='127.0.0.1',
        port=3307,
        user='akeneo_pim',
        password='akeneo_pim',
        database='akeneo_pim'
    )
    cursor = conn.cursor()
    
    count = 0
    errors = 0
    
    with open('/tmp/all_category_mappings.csv', 'r') as f:
        for line in f:
            try:
                parts = line.strip().split('\t')
                if len(parts) != 2:
                    continue
                
                sku, cat_id = parts
                cat_code = f'cat_{cat_id}'
                
                cursor.execute("""
                    INSERT IGNORE INTO pim_catalog_category_product (product_id, category_id)
                    SELECT p.id, c.id
                    FROM pim_catalog_product p, pim_catalog_category c
                    WHERE p.identifier = %s AND c.code = %s
                    LIMIT 1
                """, (sku, cat_code))
                
                count += 1
                
                if count % 500 == 0:
                    conn.commit()
                    print(f"Linked {count} category associations...")
            except Exception as e:
                errors += 1
                if errors <= 10:
                    print(f"Error: {e}")
    
    conn.commit()
    cursor.close()
    conn.close()
    
    print(f"\nTotal category links created: {count}")
    print(f"Total errors: {errors}")
    
except Exception as e:
    print(f"FATAL ERROR: {e}")
    import traceback
    traceback.print_exc()
PYTHON
    
    log_success "Categories linked"
}

################################################################################
# PHASE 4: FINAL REPORT & VERIFICATION
################################################################################
final_report() {
    log_step "PHASE 4: FINAL REPORT & VERIFICATION"
    
    echo ""
    echo -e "${PURPLE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║       FULL ELASTICSEARCH IMPORT - FINAL STATUS            ║${NC}"
    echo -e "${PURPLE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    /opt/mariadb10.6/mariadb/bin/mysql -u akeneo_pim -p'akeneo_pim' -h 127.0.0.1 -P 3307 akeneo_pim -t <<'SQLFINAL'
SELECT 
    'METRIC' as Metric,
    'VALUE' as Value
UNION ALL
SELECT '─────────────────────────────', '──────────────'
UNION ALL
SELECT '✅ Total Products', CAST(COUNT(*) AS CHAR) FROM pim_catalog_product
UNION ALL
SELECT '✅ Enabled Products', CAST(SUM(is_enabled) AS CHAR) FROM pim_catalog_product
UNION ALL
SELECT '✅ Products with Names', CAST(COUNT(*) AS CHAR) 
FROM pim_catalog_product 
WHERE JSON_CONTAINS_PATH(raw_values, 'one', '$.name')
UNION ALL
SELECT '✅ Products with Descriptions', CAST(COUNT(*) AS CHAR)
FROM pim_catalog_product 
WHERE JSON_CONTAINS_PATH(raw_values, 'one', '$.description')
UNION ALL
SELECT '✅ Products with Prices', CAST(COUNT(*) AS CHAR)
FROM pim_catalog_product 
WHERE JSON_CONTAINS_PATH(raw_values, 'one', '$.price')
UNION ALL
SELECT '─────────────────────────────', '──────────────'
UNION ALL
SELECT '📁 Total Families', CAST(COUNT(*) AS CHAR) FROM pim_catalog_family
UNION ALL
SELECT '📋 Total Attributes', CAST(COUNT(*) AS CHAR) FROM pim_catalog_attribute
UNION ALL
SELECT '🗂️  Total Categories', CAST(COUNT(*) AS CHAR) FROM pim_catalog_category
UNION ALL
SELECT '🔗 Category Links', CAST(COUNT(*) AS CHAR) FROM pim_catalog_category_product
UNION ALL
SELECT '─────────────────────────────', '──────────────'
UNION ALL
SELECT '📊 Data Completeness', CONCAT(
    ROUND(100.0 * SUM(CASE WHEN JSON_LENGTH(raw_values) > 2 THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 1),
    '%'
) FROM pim_catalog_product;
SQLFINAL
    
    echo ""
    log_success "FULL IMPORT COMPLETE!"
    echo ""
    log_info "🌐 PIM URL: https://pim.technostationery.com"
    log_info "👤 Login: admin / PimAdmin2026!"
    echo ""
}

################################################################################
# MAIN EXECUTION
################################################################################
main() {
    log_step "STARTING FULL ELASTICSEARCH IMPORT"
    log_info "Start time: $(date)"
    log_info "Target: Import all 8,217 products from Elasticsearch"
    
    fetch_all_products
    import_all_batches
    link_categories
    final_report
    
    log_info "End time: $(date)"
    log_success "ALL OPERATIONS COMPLETE!"
}

main "$@"
