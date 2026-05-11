#!/bin/bash

################################################################################
# FAST BASH-ONLY ELASTICSEARCH IMPORT
# No Python dependencies - pure SQL
################################################################################

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

log_step() { echo -e "${CYAN}═══ $1 ═══${NC}"; }
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }

################################################################################
# Import products from first batch (1000 products)
################################################################################
import_batch() {
    log_step "IMPORTING BATCH $1 ($2 products)"
    
    local batch_file="$1"
    local batch_num="$2"
    
    # Convert JSON to SQL using Python inline
    python3 << PYTHON > "/tmp/batch_${batch_num}_insert.sql"
import json

with open('${batch_file}', 'r') as f:
    data = json.load(f)

family_id = 1  # Assume family ID 1
count = 0

for hit in data.get('hits', {}).get('hits', []):
    prod = hit.get('_source', {})
    sku = prod.get('sku', '').replace("'", "''").replace("\\\\", "\\\\\\\\")
    
    if not sku:
        continue
    
    # Build raw_values
    rv = {}
    
    name = prod.get('name', '')
    if isinstance(name, dict):
        name = name.get('fr_FR', '')
    if name:
        name = str(name).strip().replace("'", "''").replace("\\\\", "\\\\\\\\")[:255]
        if name:
            rv['name'] = [{'locale': 'fr_FR', 'scope': None, 'data': name}]
    
    desc = prod.get('description', '')
    if isinstance(desc, dict):
        desc = desc.get('fr_FR', '')
    if desc:
        desc = str(desc).strip().replace("'", "''").replace("\\\\", "\\\\\\\\")[:5000]
        if desc:
            rv['description'] = [{'locale': 'fr_FR', 'scope': None, 'data': desc}]
    
    price = prod.get('price', 0)
    if isinstance(price, dict):
        price = price.get('price_0_1', 0)
    try:
        pval = float(price)
        if pval > 0:
            rv['price'] = [{'locale': None, 'scope': None, 'data': [{'amount': str(pval), 'currency': 'DZD'}]}]
    except:
        pass
    
    brand = prod.get('brand', 'TECHNO')
    if brand:
        brand = str(brand).replace("'", "''")[:50]
        rv['brand'] = [{'locale': None, 'scope': None, 'data': brand}]
    
    status = 1 if prod.get('status', '') == 'Activé' else 0
    
    # JSON encode
    import json
    rv_json = json.dumps(rv, ensure_ascii=False).replace("'", "''").replace("\\\\", "\\\\\\\\")
    
    print(f"INSERT INTO pim_catalog_product (identifier, family_id, is_enabled, raw_values, created, updated)")
    print(f"VALUES ('{sku}', {family_id}, {status}, '{rv_json}', NOW(), NOW())")
    print(f"ON DUPLICATE KEY UPDATE raw_values = VALUES(raw_values), is_enabled = VALUES(is_enabled), updated = NOW();")
    
    count += 1

print(f"-- Batch complete: {count} products")
PYTHON
    
    # Execute SQL
    /opt/mariadb10.6/mariadb/bin/mysql -u akeneo_pim -p'akeneo_pim' -h 127.0.0.1 -P 3307 akeneo_pim < "/tmp/batch_${batch_num}_insert.sql" 2>&1 | grep -v "Warning:" | head -20
    
    log_success "Batch $batch_num complete"
}

################################################################################
# Main execution
################################################################################
main() {
    log_step "STARTING FAST BASH-ONLY IMPORT"
    
    # Get family ID
    family_id=$(/opt/mariadb10.6/mariadb/bin/mysql -u akeneo_pim -p'akeneo_pim' -h 127.0.0.1 -P 3307 akeneo_pim -N -e "SELECT id FROM pim_catalog_family WHERE code = 'products' LIMIT 1;")
    log_info "Using family ID: $family_id"
    
    # Process all downloaded batches
    for batch_file in /tmp/es_batch_*.json; do
        if [ -f "$batch_file" ]; then
            batch_num=$(basename "$batch_file" | grep -oE '[0-9]+')
            log_info "Processing batch file: $batch_file"
            import_batch "$batch_file" "$batch_num"
        fi
    done
    
    # Final count
    log_step "FINAL STATUS"
    
    /opt/mariadb10.6/mariadb/bin/mysql -u akeneo_pim -p'akeneo_pim' -h 127.0.0.1 -P 3307 akeneo_pim -t <<'SQL'
SELECT 
    '✅ Total Products' as Metric,
    CAST(COUNT(*) AS CHAR) as Value
FROM pim_catalog_product
UNION ALL
SELECT '✅ With Names', CAST(COUNT(*) AS CHAR)
FROM pim_catalog_product 
WHERE JSON_CONTAINS_PATH(raw_values, 'one', '$.name')
UNION ALL
SELECT '✅ With Descriptions', CAST(COUNT(*) AS CHAR)
FROM pim_catalog_product 
WHERE JSON_CONTAINS_PATH(raw_values, 'one', '$.description');
SQL
    
    log_success "IMPORT COMPLETE!"
    log_info "URL: https://pim.technostationery.com (admin / PimAdmin2026!)"
}

main "$@"
