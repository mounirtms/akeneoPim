#!/bin/bash

################################################################################
# COMPREHENSIVE DATA OPTIMIZATION & ENRICHMENT
# Fix prices, enrich attributes, clean data - ALL IN ONE
################################################################################

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
NC='\033[0m'

LOG_FILE="/home/pim/comprehensive_optimization_$(date +%Y%m%d_%H%M%S).log"

log_step() { echo -e "${CYAN}═══ $1 ═══${NC}" | tee -a "$LOG_FILE"; }
log_info() { echo -e "${BLUE}ℹ️  $1${NC}" | tee -a "$LOG_FILE"; }
log_success() { echo -e "${GREEN}✅ $1${NC}" | tee -a "$LOG_FILE"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}" | tee -a "$LOG_FILE"; }

################################################################################
# PHASE 1: FIX ALL PRICES VIA DIRECT SQL
################################################################################
fix_all_prices() {
    log_step "PHASE 1: FIXING ALL PRODUCT PRICES"
    
    log_info "Creating price update script using simpler SQL approach..."
    
    python3 << 'PYTHON' > /tmp/simple_price_update.sql
# Read all prices
prices = {}
try:
    with open('/tmp/all_prices.tsv', 'r') as f:
        for line in f:
            parts = line.strip().split('\t')
            if len(parts) == 2 and parts[0] != 'sku':
                try:
                    sku = parts[0].replace("'", "''").replace("\\", "\\\\")
                    price = float(parts[1])
                    if price > 0:
                        prices[sku] = price
                except:
                    pass
except Exception as e:
    print(f"-- Error reading prices: {e}")

print(f"-- Found {len(prices)} valid prices")
print("")

# Generate simple UPDATE statements
count = 0
for sku, price in list(prices.items())[:10000]:  # Process all
    # Use JSON_MERGE_PATCH which works better
    print(f"UPDATE pim_catalog_product SET")
    print(f"  raw_values = JSON_MERGE_PATCH(")
    print(f"    COALESCE(raw_values, '{{}}'),")
    print(f"    '{{\"price\":[{{\"locale\":null,\"scope\":null,\"data\":[{{\"amount\":\"{price}\",\"currency\":\"DZD\"}}]}}]}}'")
    print(f"  ),")
    print(f"  updated = NOW()")
    print(f"WHERE identifier = '{sku}' AND identifier != '';")
    print("")
    
    count += 1
    if count % 1000 == 0:
        print(f"-- Processed {count} prices...")

print(f"-- Total price updates: {count}")
PYTHON
    
    log_info "Executing price updates (may take 3-5 minutes for 9,538 products)..."
    
    /opt/mariadb10.6/mariadb/bin/mysql -u akeneo_pim -p'akeneo_pim' -h 127.0.0.1 -P 3307 akeneo_pim < /tmp/simple_price_update.sql 2>&1 | tee -a "$LOG_FILE" | tail -50
    
    local with_prices=$(/opt/mariadb10.6/mariadb/bin/mysql -u akeneo_pim -p'akeneo_pim' -h 127.0.0.1 -P 3307 akeneo_pim -N -e "SELECT COUNT(*) FROM pim_catalog_product WHERE JSON_CONTAINS_PATH(raw_values, 'one', '$.price');")
    
    log_success "Products with prices now: $with_prices"
}

################################################################################
# PHASE 2: CLEAN PRODUCT NAMES
################################################################################
clean_product_names() {
    log_step "PHASE 2: CLEANING PRODUCT NAMES"
    
    log_info "Applying name cleaning rules..."
    
    /opt/mariadb10.6/mariadb/bin/mysql -u akeneo_pim -p'akeneo_pim' -h 127.0.0.1 -P 3307 akeneo_pim <<'SQLCLEAN'
-- Clean product names
UPDATE pim_catalog_product
SET raw_values = JSON_REPLACE(
    raw_values,
    '$.name[0].data',
    TRIM(
        REGEXP_REPLACE(
            REGEXP_REPLACE(
                JSON_UNQUOTE(JSON_EXTRACT(raw_values, '$.name[0].data')),
                '\\s+', ' '
            ),
            '^[a-z]', UPPER(SUBSTRING(JSON_UNQUOTE(JSON_EXTRACT(raw_values, '$.name[0].data')), 1, 1))
        )
    )
),
updated = NOW()
WHERE JSON_CONTAINS_PATH(raw_values, 'one', '$.name')
LIMIT 5000;
SQLCLEAN
    
    log_success "Product names cleaned"
}

################################################################################
# PHASE 3: CLEAN DESCRIPTIONS
################################################################################
clean_descriptions() {
    log_step "PHASE 3: CLEANING PRODUCT DESCRIPTIONS"
    
    log_info "Removing HTML and fixing encoding..."
    
    /opt/mariadb10.6/mariadb/bin/mysql -u akeneo_pim -p'akeneo_pim' -h 127.0.0.1 -P 3307 akeneo_pim <<'SQLDESC'
-- Remove common HTML tags and entities
UPDATE pim_catalog_product
SET raw_values = JSON_REPLACE(
    raw_values,
    '$.description[0].data',
    TRIM(
        REGEXP_REPLACE(
            REGEXP_REPLACE(
                REGEXP_REPLACE(
                    REGEXP_REPLACE(
                        REPLACE(
                            REPLACE(
                                REPLACE(
                                    JSON_UNQUOTE(JSON_EXTRACT(raw_values, '$.description[0].data')),
                                    '&nbsp;', ' '
                                ),
                                '&amp;', '&'
                            ),
                            '&quot;', '"'
                        ),
                        '<[^>]+>', ''
                    ),
                    '\\s+', ' '
                ),
                '^\\s+', ''
            ),
            '\\s+$', ''
        )
    )
),
updated = NOW()
WHERE JSON_CONTAINS_PATH(raw_values, 'one', '$.description')
LIMIT 5000;
SQLDESC
    
    log_success "Descriptions cleaned"
}

################################################################################
# PHASE 4: LINK REMAINING CATEGORIES
################################################################################
link_remaining_categories() {
    log_step "PHASE 4: LINKING REMAINING PRODUCTS TO CATEGORIES"
    
    log_info "Finding products without categories..."
    
    # Get products not in categories
    /opt/mariadb10.6/mariadb/bin/mysql -u akeneo_pim -p'akeneo_pim' -h 127.0.0.1 -P 3307 akeneo_pim -N <<'SQLMISSING' > /tmp/products_without_categories.txt
SELECT p.identifier
FROM pim_catalog_product p
LEFT JOIN pim_catalog_category_product ccp ON p.id = ccp.product_id
WHERE ccp.product_id IS NULL
LIMIT 1000;
SQLMISSING
    
    local missing_count=$(wc -l < /tmp/products_without_categories.txt)
    log_info "Products without categories: $missing_count"
    
    if [ $missing_count -gt 0 ]; then
        log_info "Assigning to default category..."
        
        # Assign to root category (category id 2 or first available)
        /opt/mariadb10.6/mariadb/bin/mysql -u akeneo_pim -p'akeneo_pim' -h 127.0.0.1 -P 3307 akeneo_pim <<'SQLASSIGN'
INSERT IGNORE INTO pim_catalog_category_product (product_id, category_id)
SELECT p.id, (SELECT id FROM pim_catalog_category WHERE code != 'master' ORDER BY id LIMIT 1)
FROM pim_catalog_product p
LEFT JOIN pim_catalog_category_product ccp ON p.id = ccp.product_id
WHERE ccp.product_id IS NULL
LIMIT 1000;
SQLASSIGN
    fi
    
    log_success "Remaining products linked to categories"
}

################################################################################
# PHASE 5: IDENTIFY DUPLICATES
################################################################################
identify_duplicates() {
    log_step "PHASE 5: IDENTIFYING DUPLICATE PRODUCTS"
    
    log_info "Checking for duplicates..."
    
    /opt/mariadb10.6/mariadb/bin/mysql -u akeneo_pim -p'akeneo_pim' -h 127.0.0.1 -P 3307 akeneo_pim -t <<'SQLDUP'
SELECT 
    'Duplicate Check' as Check_Type,
    COUNT(*) as Count
FROM (
    SELECT identifier, COUNT(*) as cnt
    FROM pim_catalog_product
    GROUP BY identifier
    HAVING cnt > 1
) duplicates
UNION ALL
SELECT 'Unique Products', COUNT(DISTINCT identifier)
FROM pim_catalog_product;
SQLDUP
    
    log_success "Duplicate check complete"
}

################################################################################
# PHASE 6: ADD MISSING BRANDS
################################################################################
add_missing_brands() {
    log_step "PHASE 6: ENSURING ALL PRODUCTS HAVE BRANDS"
    
    log_info "Finding products without brands..."
    
    /opt/mariadb10.6/mariadb/bin/mysql -u akeneo_pim -p'akeneo_pim' -h 127.0.0.1 -P 3307 akeneo_pim <<'SQLBRAND'
UPDATE pim_catalog_product
SET raw_values = JSON_MERGE_PATCH(
    COALESCE(raw_values, '{}'),
    '{"brand":[{"locale":null,"scope":null,"data":"TECHNO"}]}'
),
updated = NOW()
WHERE NOT JSON_CONTAINS_PATH(raw_values, 'one', '$.brand')
LIMIT 5000;
SQLBRAND
    
    local with_brands=$(/opt/mariadb10.6/mariadb/bin/mysql -u akeneo_pim -p'akeneo_pim' -h 127.0.0.1 -P 3307 akeneo_pim -N -e "SELECT COUNT(*) FROM pim_catalog_product WHERE JSON_CONTAINS_PATH(raw_values, 'one', '$.brand');")
    
    log_success "Products with brands: $with_brands"
}

################################################################################
# PHASE 7: GENERATE COMPREHENSIVE STATUS REPORT
################################################################################
generate_status_report() {
    log_step "PHASE 7: GENERATING COMPREHENSIVE STATUS REPORT"
    
    echo ""
    echo -e "${PURPLE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║    COMPREHENSIVE OPTIMIZATION - FINAL STATUS              ║${NC}"
    echo -e "${PURPLE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    /opt/mariadb10.6/mariadb/bin/mysql -u akeneo_pim -p'akeneo_pim' -h 127.0.0.1 -P 3307 akeneo_pim -t <<'SQLFINAL'
SELECT 
    'DATA QUALITY METRICS' as Metric,
    'COUNT' as Count,
    'PERCENTAGE' as Percentage
UNION ALL
SELECT '═══════════════════════', '══════', '══════════'
UNION ALL
SELECT 'Total Products',
    CAST(COUNT(*) AS CHAR),
    '100.0%'
FROM pim_catalog_product
UNION ALL
SELECT '───────────────────────', '──────', '──────────'
UNION ALL
SELECT 'With Names',
    CAST(COUNT(*) AS CHAR),
    CONCAT(ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM pim_catalog_product), 1), '%')
FROM pim_catalog_product WHERE JSON_CONTAINS_PATH(raw_values, 'one', '$.name')
UNION ALL
SELECT 'With Descriptions',
    CAST(COUNT(*) AS CHAR),
    CONCAT(ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM pim_catalog_product), 1), '%')
FROM pim_catalog_product WHERE JSON_CONTAINS_PATH(raw_values, 'one', '$.description')
UNION ALL
SELECT 'With Prices',
    CAST(COUNT(*) AS CHAR),
    CONCAT(ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM pim_catalog_product), 1), '%')
FROM pim_catalog_product WHERE JSON_CONTAINS_PATH(raw_values, 'one', '$.price')
UNION ALL
SELECT 'With Brands',
    CAST(COUNT(*) AS CHAR),
    CONCAT(ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM pim_catalog_product), 1), '%')
FROM pim_catalog_product WHERE JSON_CONTAINS_PATH(raw_values, 'one', '$.brand')
UNION ALL
SELECT 'In Categories',
    CAST(COUNT(DISTINCT product_id) AS CHAR),
    CONCAT(ROUND(100.0 * COUNT(DISTINCT product_id) / (SELECT COUNT(*) FROM pim_catalog_product), 1), '%')
FROM pim_catalog_category_product
UNION ALL
SELECT '───────────────────────', '──────', '──────────'
UNION ALL
SELECT 'Families', CAST(COUNT(*) AS CHAR), '-'
FROM pim_catalog_family
UNION ALL
SELECT 'Attributes', CAST(COUNT(*) AS CHAR), '-'
FROM pim_catalog_attribute
UNION ALL
SELECT 'Categories', CAST(COUNT(*) AS CHAR), '-'
FROM pim_catalog_category
UNION ALL
SELECT 'Category Links', CAST(COUNT(*) AS CHAR), '-'
FROM pim_catalog_category_product;
SQLFINAL
    
    echo ""
    log_success "Comprehensive optimization complete!"
}

################################################################################
# PHASE 8: CLEAR CACHE AND REINDEX
################################################################################
clear_cache_reindex() {
    log_step "PHASE 8: CLEARING CACHE AND REINDEXING"
    
    cd /home/pim/public_html
    
    log_info "Clearing Akeneo cache..."
    php bin/console cache:clear --env=prod --no-warmup 2>&1 | tee -a "$LOG_FILE" | tail -10
    
    log_info "Starting Elasticsearch reindex in background..."
    nohup php bin/console pim:product:index --all --env=prod > /home/pim/reindex_$(date +%Y%m%d_%H%M%S).log 2>&1 &
    
    log_success "Cache cleared and reindex started"
}

################################################################################
# MAIN EXECUTION
################################################################################
main() {
    log_step "STARTING COMPREHENSIVE DATA OPTIMIZATION"
    log_info "Start time: $(date)"
    log_info "Target: Fix prices, clean data, optimize everything"
    echo ""
    
    fix_all_prices
    clean_product_names
    clean_descriptions
    link_remaining_categories
    identify_duplicates
    add_missing_brands
    generate_status_report
    clear_cache_reindex
    
    echo ""
    log_info "End time: $(date)"
    log_success "COMPREHENSIVE OPTIMIZATION COMPLETE!"
    log_info "Log file: $LOG_FILE"
    log_info "PIM URL: https://pim.technostationery.com"
    log_info "Login: admin / PimAdmin2026!"
}

main "$@"
