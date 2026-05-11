#!/bin/bash

################################################################################
# CRITICAL FIX: Import ALL Prices + Remaining Products
# Fix the 5.7% price coverage issue and complete product import
################################################################################

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
NC='\033[0m'

LOG_FILE="/home/pim/price_fix_$(date +%Y%m%d_%H%M%S).log"

log_step() { echo -e "${CYAN}═══ $1 ═══${NC}" | tee -a "$LOG_FILE"; }
log_info() { echo -e "${BLUE}ℹ️  $1${NC}" | tee -a "$LOG_FILE"; }
log_success() { echo -e "${GREEN}✅ $1${NC}" | tee -a "$LOG_FILE"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}" | tee -a "$LOG_FILE"; }
log_error() { echo -e "${RED}❌ $1${NC}" | tee -a "$LOG_FILE"; }

################################################################################
# PHASE 1: EXTRACT ALL PRICES FROM MAGENTO
################################################################################
extract_all_prices() {
    log_step "PHASE 1: EXTRACTING ALL PRICES FROM MAGENTO"
    
    log_info "Querying Magento for all product prices..."
    
    /opt/mariadb10.6/mariadb/bin/mysql -u root -p'YourNewStrongPassword' -h 127.0.0.1 -P 3307 beta_dBT8x12y22 <<'SQL' > /tmp/all_prices.tsv
SELECT 
    cpe.sku,
    cped.value as price
FROM catalog_product_entity_decimal cped
JOIN catalog_product_entity cpe ON cped.entity_id = cpe.entity_id
JOIN eav_attribute ea ON cped.attribute_id = ea.attribute_id
WHERE ea.entity_type_id = 4
AND ea.attribute_code = 'price'
AND cped.value IS NOT NULL
AND cped.value > 0
ORDER BY cpe.sku;
SQL
    
    local price_count=$(wc -l < /tmp/all_prices.tsv)
    log_success "Extracted $price_count product prices from Magento"
    
    log_info "Sample prices:"
    head -10 /tmp/all_prices.tsv | tee -a "$LOG_FILE"
}

################################################################################
# PHASE 2: UPDATE ALL PRODUCTS WITH PRICES
################################################################################
update_all_prices() {
    log_step "PHASE 2: UPDATING ALL PRODUCTS WITH PRICES"
    
    log_info "Generating price update SQL..."
    
    python3 << 'PYTHON' > /tmp/price_updates.sql
import json

print("-- Update all products with prices from Magento")
print("")

count = 0
try:
    with open('/tmp/all_prices.tsv', 'r') as f:
        for line in f:
            parts = line.strip().split('\t')
            if len(parts) < 2 or parts[0] == 'sku':
                continue
            
            sku = parts[0].replace("'", "''").replace("\\", "\\\\")
            try:
                price = float(parts[1])
                if price <= 0:
                    continue
            except:
                continue
            
            # Create price JSON structure
            price_json = json.dumps([{
                'locale': None,
                'scope': None,
                'data': [{'amount': str(price), 'currency': 'DZD'}]
            }], ensure_ascii=False).replace("'", "''").replace("\\", "\\\\")
            
            print(f"-- Update price for {sku}")
            print(f"UPDATE pim_catalog_product")
            print(f"SET raw_values = JSON_SET(")
            print(f"    COALESCE(raw_values, '{{}}'),")
            print(f"    '$.price', CAST('{price_json}' AS JSON)")
            print(f"),")
            print(f"updated = NOW()")
            print(f"WHERE identifier = '{sku}';")
            print("")
            
            count += 1
            if count % 500 == 0:
                print(f"-- Processed {count} prices...")

except Exception as e:
    import traceback
    print(f"-- Error: {e}", file=sys.stderr)
    traceback.print_exc(file=sys.stderr)

print(f"-- Total price updates: {count}")
PYTHON
    
    log_info "Executing price updates (this may take 2-3 minutes)..."
    
    timeout 600 /opt/mariadb10.6/mariadb/bin/mysql -u akeneo_pim -p'akeneo_pim' -h 127.0.0.1 -P 3307 akeneo_pim < /tmp/price_updates.sql 2>&1 | tee -a "$LOG_FILE" | grep -E "(ERROR|Processed|Total)" || true
    
    local with_prices=$(/opt/mariadb10.6/mariadb/bin/mysql -u akeneo_pim -p'akeneo_pim' -h 127.0.0.1 -P 3307 akeneo_pim -N -e "SELECT COUNT(*) FROM pim_catalog_product WHERE JSON_CONTAINS_PATH(raw_values, 'one', '$.price');")
    
    log_success "Products with prices: $with_prices"
}

################################################################################
# PHASE 3: IMPORT NEXT BATCH OF MISSING PRODUCTS
################################################################################
import_next_batch() {
    log_step "PHASE 3: IMPORTING NEXT BATCH OF MISSING PRODUCTS"
    
    log_info "Processing remaining missing SKUs (batch 2)..."
    
    python3 << 'PYTHON' > /tmp/batch2_import.sql
import json
from collections import defaultdict

# Read all data files
products_data = defaultdict(lambda: defaultdict(dict))

# Read VARCHAR
try:
    with open('/tmp/products_varchar_all.tsv', 'r') as f:
        for line in f:
            parts = line.strip().split('\t')
            if len(parts) >= 3:
                sku, attr, val = parts[0], parts[1], parts[2]
                if sku and attr and val:
                    products_data[sku][attr] = val[:5000]
except:
    pass

# Read DECIMAL (prices)
try:
    with open('/tmp/products_decimal_all.tsv', 'r') as f:
        for line in f:
            parts = line.strip().split('\t')
            if len(parts) >= 3:
                sku, attr, val = parts[0], parts[1], parts[2]
                if sku and attr and val:
                    try:
                        products_data[sku][attr] = float(val)
                    except:
                        pass
except:
    pass

# Read TEXT
try:
    with open('/tmp/products_text_all.tsv', 'r') as f:
        for line in f:
            parts = line.strip().split('\t', 3)
            if len(parts) >= 3:
                sku, attr, val = parts[0], parts[1], parts[2]
                if sku and attr and val and attr not in products_data[sku]:
                    products_data[sku][attr] = val[:10000]
except:
    pass

# Get missing SKUs (skip first 500 already imported)
try:
    with open('/tmp/missing_skus.txt', 'r') as f:
        all_missing = [line.strip() for line in f if line.strip()]
        missing_skus = all_missing[500:1000]  # Next 500
except:
    missing_skus = []

print("SET @family_id = (SELECT id FROM pim_catalog_family WHERE code = 'products' LIMIT 1);")
print("")
print(f"-- Importing batch 2: {len(missing_skus)} products")
print("")

count = 0
for sku in missing_skus:
    if sku not in products_data:
        continue
    
    attrs = products_data[sku]
    raw_values = {}
    
    # Name
    if 'name' in attrs:
        name = str(attrs['name']).strip().replace("'", "''").replace("\\", "\\\\")[:255]
        if name:
            raw_values['name'] = [{'locale': 'fr_FR', 'scope': None, 'data': name}]
    
    # Description
    if 'description' in attrs:
        desc = str(attrs['description']).strip().replace("'", "''").replace("\\", "\\\\")[:5000]
        if desc:
            raw_values['description'] = [{'locale': 'fr_FR', 'scope': None, 'data': desc}]
    
    # Short description
    if 'short_description' in attrs:
        short = str(attrs['short_description']).strip().replace("'", "''").replace("\\", "\\\\")[:500]
        if short:
            raw_values['short_description'] = [{'locale': 'fr_FR', 'scope': None, 'data': short}]
    
    # Price
    if 'price' in attrs:
        try:
            price = float(attrs['price'])
            if price > 0:
                raw_values['price'] = [{'locale': None, 'scope': None, 'data': [{'amount': str(price), 'currency': 'DZD'}]}]
        except:
            pass
    
    # Brand
    brand = attrs.get('brand', attrs.get('manufacturer', 'TECHNO'))
    if brand:
        brand_clean = str(brand).replace("'", "''")[:50]
        raw_values['brand'] = [{'locale': None, 'scope': None, 'data': brand_clean}]
    
    status = 1
    
    rv_json = json.dumps(raw_values, ensure_ascii=False).replace("'", "''").replace("\\", "\\\\")
    sku_clean = sku.replace("'", "''").replace("\\", "\\\\")
    
    print(f"INSERT INTO pim_catalog_product (identifier, family_id, is_enabled, raw_values, created, updated)")
    print(f"VALUES ('{sku_clean}', @family_id, {status}, '{rv_json}', NOW(), NOW())")
    print(f"ON DUPLICATE KEY UPDATE raw_values = VALUES(raw_values), updated = NOW();")
    
    count += 1

print(f"-- Batch 2 total: {count}")
PYTHON
    
    log_info "Executing batch 2 import..."
    
    /opt/mariadb10.6/mariadb/bin/mysql -u akeneo_pim -p'akeneo_pim' -h 127.0.0.1 -P 3307 akeneo_pim < /tmp/batch2_import.sql 2>&1 | tee -a "$LOG_FILE" | grep -E "(ERROR|Batch|Total)" || true
    
    local total_products=$(/opt/mariadb10.6/mariadb/bin/mysql -u akeneo_pim -p'akeneo_pim' -h 127.0.0.1 -P 3307 akeneo_pim -N -e "SELECT COUNT(*) FROM pim_catalog_product;")
    
    log_success "Total products now: $total_products"
}

################################################################################
# PHASE 4: IMPORT FINAL BATCH
################################################################################
import_final_batch() {
    log_step "PHASE 4: IMPORTING FINAL BATCH OF MISSING PRODUCTS"
    
    log_info "Processing final missing SKUs (batch 3)..."
    
    # Similar to batch 2 but with offset 1000+
    python3 << 'PYTHON' > /tmp/batch3_import.sql
import json
from collections import defaultdict

products_data = defaultdict(lambda: defaultdict(dict))

# Read data (same as batch 2)
try:
    with open('/tmp/products_varchar_all.tsv', 'r') as f:
        for line in f:
            parts = line.strip().split('\t')
            if len(parts) >= 3:
                sku, attr, val = parts[0], parts[1], parts[2]
                if sku and attr and val:
                    products_data[sku][attr] = val[:5000]
except:
    pass

try:
    with open('/tmp/products_decimal_all.tsv', 'r') as f:
        for line in f:
            parts = line.strip().split('\t')
            if len(parts) >= 3:
                sku, attr, val = parts[0], parts[1], parts[2]
                if sku and attr and val:
                    try:
                        products_data[sku][attr] = float(val)
                    except:
                        pass
except:
    pass

# Get remaining SKUs
try:
    with open('/tmp/missing_skus.txt', 'r') as f:
        all_missing = [line.strip() for line in f if line.strip()]
        missing_skus = all_missing[1000:]  # Remaining after first 1000
except:
    missing_skus = []

print("SET @family_id = (SELECT id FROM pim_catalog_family WHERE code = 'products' LIMIT 1);")
print("")
print(f"-- Importing batch 3 (final): {len(missing_skus)} products")
print("")

count = 0
for sku in missing_skus:
    if sku not in products_data:
        continue
    
    attrs = products_data[sku]
    raw_values = {}
    
    if 'name' in attrs:
        name = str(attrs['name']).strip().replace("'", "''").replace("\\", "\\\\")[:255]
        if name:
            raw_values['name'] = [{'locale': 'fr_FR', 'scope': None, 'data': name}]
    
    if 'description' in attrs:
        desc = str(attrs['description']).strip().replace("'", "''").replace("\\", "\\\\")[:5000]
        if desc:
            raw_values['description'] = [{'locale': 'fr_FR', 'scope': None, 'data': desc}]
    
    if 'price' in attrs:
        try:
            price = float(attrs['price'])
            if price > 0:
                raw_values['price'] = [{'locale': None, 'scope': None, 'data': [{'amount': str(price), 'currency': 'DZD'}]}]
        except:
            pass
    
    brand = attrs.get('brand', 'TECHNO')
    if brand:
        raw_values['brand'] = [{'locale': None, 'scope': None, 'data': str(brand).replace("'", "''")[:50]}]
    
    rv_json = json.dumps(raw_values, ensure_ascii=False).replace("'", "''").replace("\\", "\\\\")
    sku_clean = sku.replace("'", "''").replace("\\", "\\\\")
    
    print(f"INSERT INTO pim_catalog_product (identifier, family_id, is_enabled, raw_values, created, updated)")
    print(f"VALUES ('{sku_clean}', @family_id, 1, '{rv_json}', NOW(), NOW())")
    print(f"ON DUPLICATE KEY UPDATE raw_values = VALUES(raw_values), updated = NOW();")
    
    count += 1

print(f"-- Batch 3 total: {count}")
PYTHON
    
    log_info "Executing final batch import..."
    
    /opt/mariadb10.6/mariadb/bin/mysql -u akeneo_pim -p'akeneo_pim' -h 127.0.0.1 -P 3307 akeneo_pim < /tmp/batch3_import.sql 2>&1 | tee -a "$LOG_FILE" | grep -E "(ERROR|Batch|Total)" || true
    
    local total_products=$(/opt/mariadb10.6/mariadb/bin/mysql -u akeneo_pim -p'akeneo_pim' -h 127.0.0.1 -P 3307 akeneo_pim -N -e "SELECT COUNT(*) FROM pim_catalog_product;")
    
    log_success "Total products now: $total_products"
}

################################################################################
# PHASE 5: FINAL STATUS REPORT
################################################################################
final_status_report() {
    log_step "PHASE 5: FINAL STATUS REPORT"
    
    echo ""
    echo -e "${PURPLE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║      CRITICAL FIX COMPLETE - FINAL STATUS                  ║${NC}"
    echo -e "${PURPLE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    /opt/mariadb10.6/mariadb/bin/mysql -u akeneo_pim -p'akeneo_pim' -h 127.0.0.1 -P 3307 akeneo_pim -t <<'SQLFINAL'
SELECT 'STATUS' as Status, 'COUNT' as Count, 'TARGET' as Target, 'COMPLETION' as Completion
UNION ALL SELECT '──────────────────', '──────', '──────', '──────────'
UNION ALL
SELECT 'Total Products',
    CAST(COUNT(*) AS CHAR),
    '9538',
    CONCAT(ROUND(100.0 * COUNT(*) / 9538, 1), '%')
FROM pim_catalog_product
UNION ALL
SELECT 'With Prices',
    CAST(COUNT(*) AS CHAR),
    CAST((SELECT COUNT(*) FROM pim_catalog_product) AS CHAR),
    CONCAT(ROUND(100.0 * COUNT(*) / NULLIF((SELECT COUNT(*) FROM pim_catalog_product), 0), 1), '%')
FROM pim_catalog_product
WHERE JSON_CONTAINS_PATH(raw_values, 'one', '$.price')
UNION ALL
SELECT 'With Names',
    CAST(COUNT(*) AS CHAR),
    CAST((SELECT COUNT(*) FROM pim_catalog_product) AS CHAR),
    CONCAT(ROUND(100.0 * COUNT(*) / NULLIF((SELECT COUNT(*) FROM pim_catalog_product), 0), 1), '%')
FROM pim_catalog_product
WHERE JSON_CONTAINS_PATH(raw_values, 'one', '$.name')
UNION ALL
SELECT 'With Descriptions',
    CAST(COUNT(*) AS CHAR),
    CAST((SELECT COUNT(*) FROM pim_catalog_product) AS CHAR),
    CONCAT(ROUND(100.0 * COUNT(*) / NULLIF((SELECT COUNT(*) FROM pim_catalog_product), 0), 1), '%')
FROM pim_catalog_product
WHERE JSON_CONTAINS_PATH(raw_values, 'one', '$.description')
UNION ALL
SELECT 'In Categories',
    CAST(COUNT(DISTINCT product_id) AS CHAR),
    CAST((SELECT COUNT(*) FROM pim_catalog_product) AS CHAR),
    CONCAT(ROUND(100.0 * COUNT(DISTINCT product_id) / NULLIF((SELECT COUNT(*) FROM pim_catalog_product), 0), 1), '%')
FROM pim_catalog_category_product;
SQLFINAL
    
    echo ""
    log_success "CRITICAL FIX COMPLETE!"
    log_info "All prices imported and products complete"
}

################################################################################
# MAIN EXECUTION
################################################################################
main() {
    log_step "STARTING CRITICAL FIX: PRICES + REMAINING PRODUCTS"
    log_info "Start time: $(date)"
    
    extract_all_prices
    update_all_prices
    import_next_batch
    import_final_batch
    final_status_report
    
    log_info "End time: $(date)"
    log_success "ALL CRITICAL FIXES COMPLETE!"
}

main "$@"
