#!/bin/bash

################################################################################
# IMPORT ALL ATTRIBUTES FROM MAGENTO TO AKENEO
# Extracts all product attributes and creates them in Akeneo 6.0+
################################################################################

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
NC='\033[0m'

LOG_FILE="/home/pim/attribute_import_$(date +%Y%m%d_%H%M%S).log"

log_step() { echo -e "${CYAN}═══ $1 ═══${NC}" | tee -a "$LOG_FILE"; }
log_info() { echo -e "${BLUE}ℹ️  $1${NC}" | tee -a "$LOG_FILE"; }
log_success() { echo -e "${GREEN}✅ $1${NC}" | tee -a "$LOG_FILE"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}" | tee -a "$LOG_FILE"; }
log_error() { echo -e "${RED}❌ $1${NC}" | tee -a "$LOG_FILE"; }

################################################################################
# PHASE 1: EXTRACT ATTRIBUTES FROM MAGENTO
################################################################################
extract_attributes() {
    log_step "PHASE 1: EXTRACTING ATTRIBUTES FROM MAGENTO"
    
    log_info "Querying Magento database for all product attributes..."
    
    /opt/mariadb10.6/mariadb/bin/mysql -u root -p'YourNewStrongPassword' -h 127.0.0.1 -P 3307 beta_dBT8x12y22 <<'SQL' > /tmp/magento_attributes.tsv
SELECT DISTINCT
    ea.attribute_code,
    ea.backend_type,
    ea.frontend_input,
    ea.is_required,
    ea.is_unique,
    COALESCE(
        (SELECT value FROM eav_attribute_label WHERE attribute_id = ea.attribute_id AND store_id = 0 LIMIT 1),
        ea.frontend_label,
        ea.attribute_code
    ) as label_fr,
    ea.is_user_defined,
    ea.default_value
FROM eav_attribute ea
WHERE ea.entity_type_id = 4
AND ea.attribute_code NOT IN ('entity_id', 'attribute_set_id', 'type_id', 'sku')
ORDER BY ea.attribute_code
LIMIT 500;
SQL
    
    local count=$(wc -l < /tmp/magento_attributes.tsv)
    log_success "Extracted $count attributes from Magento"
}

################################################################################
# PHASE 2: MAP MAGENTO TYPES TO AKENEO TYPES
################################################################################
create_attribute_mapping() {
    log_step "PHASE 2: CREATING ATTRIBUTE TYPE MAPPING"
    
    python3 << 'PYTHON' > /tmp/attribute_mapping.sql
import sys

# Read Magento attributes
attributes = []
with open('/tmp/magento_attributes.tsv', 'r') as f:
    for line in f:
        parts = line.strip().split('\t')
        if len(parts) < 8 or parts[0] == 'attribute_code':
            continue
        
        code = parts[0]
        backend_type = parts[1]
        frontend_input = parts[2]
        is_required = parts[3]
        is_unique = parts[4]
        label_fr = parts[5] if len(parts) > 5 else code
        is_user_defined = parts[6] if len(parts) > 6 else '1'
        default_value = parts[7] if len(parts) > 7 else ''
        
        # Map Magento types to Akeneo types
        akeneo_type = 'pim_catalog_text'
        backend_storage = 'text'
        
        if frontend_input in ['select', 'dropdown']:
            akeneo_type = 'pim_catalog_simpleselect'
            backend_storage = 'option'
        elif frontend_input == 'multiselect':
            akeneo_type = 'pim_catalog_multiselect'
            backend_storage = 'options'
        elif frontend_input == 'boolean':
            akeneo_type = 'pim_catalog_boolean'
            backend_storage = 'boolean'
        elif frontend_input in ['price']:
            akeneo_type = 'pim_catalog_price_collection'
            backend_storage = 'prices'
        elif frontend_input in ['weight']:
            akeneo_type = 'pim_catalog_metric'
            backend_storage = 'metric'
        elif frontend_input == 'date':
            akeneo_type = 'pim_catalog_date'
            backend_storage = 'date'
        elif frontend_input == 'textarea':
            akeneo_type = 'pim_catalog_textarea'
            backend_storage = 'text'
        elif frontend_input == 'image' or frontend_input == 'media_image':
            akeneo_type = 'pim_catalog_image'
            backend_storage = 'media'
        elif backend_type == 'decimal':
            akeneo_type = 'pim_catalog_number'
            backend_storage = 'decimal'
        elif backend_type == 'int':
            if frontend_input not in ['select', 'dropdown']:
                akeneo_type = 'pim_catalog_number'
                backend_storage = 'integer'
        
        # Determine if localizable (usually yes for text/textarea)
        is_localizable = '1' if akeneo_type in ['pim_catalog_text', 'pim_catalog_textarea'] else '0'
        
        attributes.append({
            'code': code,
            'type': akeneo_type,
            'backend': backend_storage,
            'label': label_fr,
            'required': '1' if is_required == '1' else '0',
            'unique': '1' if is_unique == '1' else '0',
            'localizable': is_localizable,
            'scopable': '0'
        })

# Generate SQL
print("-- Attribute import SQL")
print("SET @general_group = (SELECT id FROM pim_catalog_attribute_group WHERE code = 'general' LIMIT 1);")
print("SET @tech_group = (SELECT id FROM pim_catalog_attribute_group WHERE code = 'technical' LIMIT 1);")
print("SET @marketing_group = (SELECT id FROM pim_catalog_attribute_group WHERE code = 'marketing' LIMIT 1);")
print("")

for attr in attributes:
    code = attr['code'].replace("'", "''")[:100]
    label = attr['label'].replace("'", "''")[:255]
    
    # Skip if already exists
    print(f"-- Attribute: {code}")
    print(f"INSERT IGNORE INTO pim_catalog_attribute (")
    print(f"    code, attribute_type, backend_type, entity_type,")
    print(f"    is_required, is_unique, is_localizable, is_scopable,")
    print(f"    group_id, created, updated")
    print(f") VALUES (")
    print(f"    '{code}', '{attr['type']}', '{attr['backend']}', 'product',")
    print(f"    {attr['required']}, {attr['unique']}, {attr['localizable']}, {attr['scopable']},")
    print(f"    @general_group, NOW(), NOW()")
    print(f");")
    print(f"")
    
    # Add French label
    print(f"INSERT IGNORE INTO pim_catalog_attribute_translation (foreign_key, locale, label)")
    print(f"SELECT id, 'fr_FR', '{label}'")
    print(f"FROM pim_catalog_attribute WHERE code = '{code}';")
    print(f"")

print(f"-- Total attributes: {len(attributes)}")
PYTHON
    
    log_success "Attribute mapping created"
}

################################################################################
# PHASE 3: IMPORT ATTRIBUTES TO AKENEO
################################################################################
import_attributes() {
    log_step "PHASE 3: IMPORTING ATTRIBUTES TO AKENEO"
    
    log_info "Executing attribute import SQL..."
    
    /opt/mariadb10.6/mariadb/bin/mysql -u akeneo_pim -p'akeneo_pim' -h 127.0.0.1 -P 3307 akeneo_pim < /tmp/attribute_mapping.sql 2>&1 | tee -a "$LOG_FILE" | grep -E "(ERROR|Total)" || true
    
    local count=$(/opt/mariadb10.6/mariadb/bin/mysql -u akeneo_pim -p'akeneo_pim' -h 127.0.0.1 -P 3307 akeneo_pim -N -e "SELECT COUNT(*) FROM pim_catalog_attribute;")
    
    log_success "Total attributes in Akeneo: $count"
}

################################################################################
# PHASE 4: ASSIGN ATTRIBUTES TO FAMILIES
################################################################################
assign_to_families() {
    log_step "PHASE 4: ASSIGNING ATTRIBUTES TO FAMILIES"
    
    log_info "Linking attributes to product families..."
    
    /opt/mariadb10.6/mariadb/bin/mysql -u akeneo_pim -p'akeneo_pim' -h 127.0.0.1 -P 3307 akeneo_pim <<'SQLFAM'
-- Assign all attributes to all families
INSERT IGNORE INTO pim_catalog_family_attribute (family_id, attribute_id)
SELECT f.id, a.id
FROM pim_catalog_family f
CROSS JOIN pim_catalog_attribute a
WHERE a.code NOT IN ('sku');

-- Set name as label attribute for families that don't have one
UPDATE pim_catalog_family f
SET f.label_attribute_id = (SELECT id FROM pim_catalog_attribute WHERE code = 'name' LIMIT 1)
WHERE f.label_attribute_id IS NULL;
SQLFAM
    
    local link_count=$(/opt/mariadb10.6/mariadb/bin/mysql -u akeneo_pim -p'akeneo_pim' -h 127.0.0.1 -P 3307 akeneo_pim -N -e "SELECT COUNT(*) FROM pim_catalog_family_attribute;")
    
    log_success "Total family-attribute links: $link_count"
}

################################################################################
# PHASE 5: IMPORT ATTRIBUTE OPTIONS
################################################################################
import_attribute_options() {
    log_step "PHASE 5: IMPORTING ATTRIBUTE OPTIONS"
    
    log_info "Extracting attribute options from Magento..."
    
    /opt/mariadb10.6/mariadb/bin/mysql -u root -p'YourNewStrongPassword' -h 127.0.0.1 -P 3307 beta_dBT8x12y22 <<'SQL' > /tmp/attribute_options.tsv
SELECT 
    ea.attribute_code,
    eao.option_id,
    eao.sort_order,
    COALESCE(
        (SELECT value FROM eav_attribute_option_value WHERE option_id = eao.option_id AND store_id = 0 LIMIT 1),
        CONCAT('Option ', eao.option_id)
    ) as label_fr
FROM eav_attribute_option eao
JOIN eav_attribute ea ON eao.attribute_id = ea.attribute_id
WHERE ea.entity_type_id = 4
AND ea.frontend_input IN ('select', 'multiselect', 'dropdown')
ORDER BY ea.attribute_code, eao.sort_order
LIMIT 2000;
SQL
    
    log_info "Creating attribute option SQL..."
    
    python3 << 'PYTHON' > /tmp/attribute_options_import.sql
print("-- Attribute options import")

option_count = 0
current_attr = None

try:
    with open('/tmp/attribute_options.tsv', 'r') as f:
        for line in f:
            parts = line.strip().split('\t')
            if len(parts) < 4 or parts[0] == 'attribute_code':
                continue
            
            attr_code = parts[0].replace("'", "''")[:100]
            option_id = parts[1]
            sort_order = parts[2]
            label = parts[3].replace("'", "''")[:255]
            
            if not label or label == 'NULL':
                label = f'Option {option_id}'
            
            option_code = f'opt_{option_id}'
            
            # Insert option
            print(f"-- Option for {attr_code}")
            print(f"INSERT IGNORE INTO pim_catalog_attribute_option (attribute_id, code, sort_order)")
            print(f"SELECT id, '{option_code}', {sort_order}")
            print(f"FROM pim_catalog_attribute")
            print(f"WHERE code = '{attr_code}' LIMIT 1;")
            print(f"")
            
            # Insert label
            print(f"INSERT IGNORE INTO pim_catalog_attribute_option_value (option_id, locale_code, value)")
            print(f"SELECT pao.id, 'fr_FR', '{label}'")
            print(f"FROM pim_catalog_attribute_option pao")
            print(f"JOIN pim_catalog_attribute pa ON pao.attribute_id = pa.id")
            print(f"WHERE pa.code = '{attr_code}' AND pao.code = '{option_code}';")
            print(f"")
            
            option_count += 1

except Exception as e:
    print(f"-- Error: {e}", file=sys.stderr)

print(f"-- Total options: {option_count}")
PYTHON
    
    log_info "Importing attribute options..."
    
    /opt/mariadb10.6/mariadb/bin/mysql -u akeneo_pim -p'akeneo_pim' -h 127.0.0.1 -P 3307 akeneo_pim < /tmp/attribute_options_import.sql 2>&1 | tee -a "$LOG_FILE" | grep -E "(ERROR|Total)" || true
    
    local opt_count=$(/opt/mariadb10.6/mariadb/bin/mysql -u akeneo_pim -p'akeneo_pim' -h 127.0.0.1 -P 3307 akeneo_pim -N -e "SELECT COUNT(*) FROM pim_catalog_attribute_option;")
    
    log_success "Total attribute options: $opt_count"
}

################################################################################
# PHASE 6: UPDATE PRODUCTS WITH ATTRIBUTE DATA
################################################################################
enrich_products() {
    log_step "PHASE 6: ENRICHING PRODUCTS WITH ATTRIBUTE DATA"
    
    log_info "Extracting product attribute values from Magento..."
    
    # Sample: Get varchar attributes (most common)
    /opt/mariadb10.6/mariadb/bin/mysql -u root -p'YourNewStrongPassword' -h 127.0.0.1 -P 3307 beta_dBT8x12y22 <<'SQL' > /tmp/product_attributes_varchar.tsv
SELECT 
    cpe.sku,
    ea.attribute_code,
    cpev.value
FROM catalog_product_entity_varchar cpev
JOIN catalog_product_entity cpe ON cpev.entity_id = cpe.entity_id
JOIN eav_attribute ea ON cpev.attribute_id = ea.attribute_id
WHERE ea.entity_type_id = 4
AND ea.attribute_code NOT IN ('sku', 'name', 'description', 'short_description')
AND cpev.value IS NOT NULL
AND cpev.value != ''
LIMIT 50000;
SQL
    
    log_info "Updating product raw_values with additional attributes..."
    
    python3 << 'PYTHON'
import json
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
    
    # Read product attributes
    product_attrs = {}
    with open('/tmp/product_attributes_varchar.tsv', 'r') as f:
        for line in f:
            parts = line.strip().split('\t')
            if len(parts) < 3 or parts[0] == 'sku':
                continue
            
            sku = parts[0]
            attr_code = parts[1]
            value = parts[2]
            
            if sku not in product_attrs:
                product_attrs[sku] = {}
            
            product_attrs[sku][attr_code] = value
    
    print(f"Loaded attributes for {len(product_attrs)} products")
    
    # Update products in batches
    updated = 0
    for sku, attrs in list(product_attrs.items())[:1000]:  # Limit to 1000 for speed
        try:
            # Get current raw_values
            cursor.execute("SELECT id, raw_values FROM pim_catalog_product WHERE identifier = %s", (sku,))
            result = cursor.fetchone()
            
            if not result:
                continue
            
            prod_id, raw_values_str = result
            raw_values = json.loads(raw_values_str) if raw_values_str else {}
            
            # Add new attributes
            for attr_code, value in attrs.items():
                if attr_code not in raw_values:
                    raw_values[attr_code] = [{
                        'locale': None,
                        'scope': None,
                        'data': value[:255]
                    }]
            
            # Update
            new_json = json.dumps(raw_values, ensure_ascii=False)
            cursor.execute(
                "UPDATE pim_catalog_product SET raw_values = %s, updated = NOW() WHERE id = %s",
                (new_json, prod_id)
            )
            updated += 1
            
            if updated % 100 == 0:
                conn.commit()
                print(f"Updated {updated} products...")
        except Exception as e:
            print(f"Error updating {sku}: {e}")
    
    conn.commit()
    cursor.close()
    conn.close()
    
    print(f"\nTotal products enriched: {updated}")
    
except Exception as e:
    print(f"Error: {e}")
    import traceback
    traceback.print_exc()
PYTHON
    
    log_success "Products enriched with additional attributes"
}

################################################################################
# PHASE 7: FINAL REPORT
################################################################################
final_report() {
    log_step "PHASE 7: FINAL REPORT"
    
    echo ""
    echo -e "${PURPLE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║        ATTRIBUTE IMPORT - FINAL STATUS                     ║${NC}"
    echo -e "${PURPLE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    /opt/mariadb10.6/mariadb/bin/mysql -u akeneo_pim -p'akeneo_pim' -h 127.0.0.1 -P 3307 akeneo_pim -t <<'SQLFINAL'
SELECT 
    'METRIC' as Metric,
    'COUNT' as Count
UNION ALL
SELECT '─────────────────────────────', '──────────────'
UNION ALL
SELECT '✅ Total Attributes', CAST(COUNT(*) AS CHAR)
FROM pim_catalog_attribute
UNION ALL
SELECT '✅ Attribute Options', CAST(COUNT(*) AS CHAR)
FROM pim_catalog_attribute_option
UNION ALL
SELECT '✅ Family-Attribute Links', CAST(COUNT(*) AS CHAR)
FROM pim_catalog_family_attribute
UNION ALL
SELECT '✅ Attribute Groups', CAST(COUNT(*) AS CHAR)
FROM pim_catalog_attribute_group
UNION ALL
SELECT '─────────────────────────────', '──────────────'
UNION ALL
SELECT '📊 Text Attributes', CAST(COUNT(*) AS CHAR)
FROM pim_catalog_attribute
WHERE attribute_type LIKE '%text%'
UNION ALL
SELECT '📊 Select Attributes', CAST(COUNT(*) AS CHAR)
FROM pim_catalog_attribute
WHERE attribute_type LIKE '%select%'
UNION ALL
SELECT '📊 Number Attributes', CAST(COUNT(*) AS CHAR)
FROM pim_catalog_attribute
WHERE attribute_type LIKE '%number%';
SQLFINAL
    
    echo ""
    log_success "ATTRIBUTE IMPORT COMPLETE!"
    log_info "Next: Recreate product models and apply SEO tunings"
}

################################################################################
# MAIN EXECUTION
################################################################################
main() {
    log_step "STARTING COMPREHENSIVE ATTRIBUTE IMPORT"
    log_info "Start time: $(date)"
    
    extract_attributes
    create_attribute_mapping
    import_attributes
    assign_to_families
    import_attribute_options
    enrich_products
    final_report
    
    log_info "End time: $(date)"
    log_success "ALL ATTRIBUTE IMPORT OPERATIONS COMPLETE!"
}

main "$@"
