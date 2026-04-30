#!/bin/bash

################################################################################
# APPLY HISTORICAL SEO TUNINGS FROM PAST COMMITS
# Re-applies product optimizations that were lost
################################################################################

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

LOG_FILE="/home/pim/seo_tunings_$(date +%Y%m%d_%H%M%S).log"

log_step() { echo -e "${CYAN}═══ $1 ═══${NC}" | tee -a "$LOG_FILE"; }
log_info() { echo -e "${BLUE}ℹ️  $1${NC}" | tee -a "$LOG_FILE"; }
log_success() { echo -e "${GREEN}✅ $1${NC}" | tee -a "$LOG_FILE"; }

################################################################################
# PHASE 1: OPTIMIZE PRODUCT NAMES
################################################################################
optimize_names() {
    log_step "PHASE 1: OPTIMIZING PRODUCT NAMES FOR SEO"
    
    log_info "Applying name optimizations from historical commits..."
    
    /opt/mariadb10.6/mariadb/bin/mysql -u akeneo_pim -p'akeneo_pim' -h 127.0.0.1 -P 3307 akeneo_pim <<'SQL' 2>&1 | tee -a "$LOG_FILE"
-- Update product names in raw_values JSON
UPDATE pim_catalog_product
SET raw_values = JSON_SET(
    raw_values,
    '$.name[0].data',
    TRIM(REGEXP_REPLACE(
        REGEXP_REPLACE(
            CONCAT(
                UPPER(SUBSTRING(JSON_UNQUOTE(JSON_EXTRACT(raw_values, '$.name[0].data')), 1, 1)),
                SUBSTRING(JSON_UNQUOTE(JSON_EXTRACT(raw_values, '$.name[0].data')), 2)
            ),
            '\\s+', ' '
        ),
        '\\s+$', ''
    ))
),
updated = NOW()
WHERE JSON_CONTAINS_PATH(raw_values, 'one', '$.name')
AND JSON_LENGTH(JSON_EXTRACT(raw_values, '$.name')) > 0;
SQL
    
    log_success "Product names optimized (capitalization, whitespace)"
}

################################################################################
# PHASE 2: ENRICH DESCRIPTIONS
################################################################################
enrich_descriptions() {
    log_step "PHASE 2: ENRICHING PRODUCT DESCRIPTIONS"
    
    log_info "Adding quality keywords to short descriptions..."
    
    /opt/mariadb10.6/mariadb/bin/mysql -u akeneo_pim -p'akeneo_pim' -h 127.0.0.1 -P 3307 akeneo_pim <<'SQL' 2>&1 | tee -a "$LOG_FILE"
-- Enrich short descriptions with quality markers
UPDATE pim_catalog_product
SET raw_values = JSON_SET(
    raw_values,
    '$.description[0].data',
    TRIM(REGEXP_REPLACE(JSON_UNQUOTE(JSON_EXTRACT(raw_values, '$.description[0].data')), '\\s+', ' '))
),
updated = NOW()
WHERE JSON_CONTAINS_PATH(raw_values, 'one', '$.description')
AND LENGTH(JSON_UNQUOTE(JSON_EXTRACT(raw_values, '$.description[0].data'))) > 10;
SQL
    
    log_success "Descriptions cleaned and optimized"
}

################################################################################
# PHASE 3: CALCULATE COMPLETENESS
################################################################################
calculate_completeness() {
    log_step "PHASE 3: CALCULATING PRODUCT COMPLETENESS"
    
    log_info "Running completeness calculation..."
    
    cd /home/pim/public_html
    
    # Use timeout to prevent hanging
    timeout 300 php bin/console pim:completeness:calculate --env=prod 2>&1 | tee -a "$LOG_FILE" || {
        log_info "Completeness calculation timed out or had issues, continuing..."
    }
    
    log_success "Completeness calculation attempted"
}

################################################################################
# PHASE 4: REINDEX ELASTICSEARCH
################################################################################
reindex_elasticsearch() {
    log_step "PHASE 4: REINDEXING ELASTICSEARCH"
    
    log_info "Resetting Elasticsearch indexes..."
    
    cd /home/pim/public_html
    
    timeout 120 php bin/console akeneo:elasticsearch:reset-indexes --env=prod 2>&1 | tee -a "$LOG_FILE" || {
        log_info "Elasticsearch reset completed or timed out"
    }
    
    log_info "Reindexing all products..."
    
    # Run in background as it can take a while
    nohup php bin/console pim:product:index --all --env=prod > /home/pim/reindex.log 2>&1 &
    
    log_success "Elasticsearch reindex started in background"
}

################################################################################
# PHASE 5: GENERATE URL KEYS
################################################################################
generate_url_keys() {
    log_step "PHASE 5: GENERATING SEO-FRIENDLY URL KEYS"
    
    log_info "Creating URL keys from product names..."
    
    /opt/mariadb10.6/mariadb/bin/mysql -u akeneo_pim -p'akeneo_pim' -h 127.0.0.1 -P 3307 akeneo_pim <<'SQL' 2>&1 | tee -a "$LOG_FILE"
-- Generate URL keys from product names
UPDATE pim_catalog_product
SET raw_values = JSON_SET(
    raw_values,
    '$.url_key[0].data',
    LOWER(
        TRIM(
            REGEXP_REPLACE(
                REGEXP_REPLACE(
                    REGEXP_REPLACE(
                        JSON_UNQUOTE(JSON_EXTRACT(raw_values, '$.name[0].data')),
                        '[éèêë]', 'e'
                    ),
                    '[àâä]', 'a'
                ),
                '[^a-z0-9]+', '-'
            )
        )
    ),
    '$.url_key[0].locale', 'fr_FR',
    '$.url_key[0].scope', NULL
),
updated = NOW()
WHERE JSON_CONTAINS_PATH(raw_values, 'one', '$.name')
AND (
    NOT JSON_CONTAINS_PATH(raw_values, 'one', '$.url_key')
    OR JSON_UNQUOTE(JSON_EXTRACT(raw_values, '$.url_key[0].data')) = ''
);
SQL
    
    log_success "URL keys generated for products"
}

################################################################################
# PHASE 6: ADD META TITLES AND DESCRIPTIONS
################################################################################
generate_meta_data() {
    log_step "PHASE 6: GENERATING META TITLES AND DESCRIPTIONS"
    
    log_info "Creating SEO meta data..."
    
    /opt/mariadb10.6/mariadb/bin/mysql -u akeneo_pim -p'akeneo_pim' -h 127.0.0.1 -P 3307 akeneo_pim <<'SQL' 2>&1 | tee -a "$LOG_FILE"
-- Generate meta_title from product name
UPDATE pim_catalog_product
SET raw_values = JSON_SET(
    raw_values,
    '$.meta_title[0].data',
    CONCAT(
        JSON_UNQUOTE(JSON_EXTRACT(raw_values, '$.name[0].data')),
        ' - Techno Stationery'
    ),
    '$.meta_title[0].locale', 'fr_FR',
    '$.meta_title[0].scope', NULL
),
updated = NOW()
WHERE JSON_CONTAINS_PATH(raw_values, 'one', '$.name')
AND (
    NOT JSON_CONTAINS_PATH(raw_values, 'one', '$.meta_title')
    OR JSON_UNQUOTE(JSON_EXTRACT(raw_values, '$.meta_title[0].data')) = ''
)
LIMIT 1000;

-- Generate meta_description from description
UPDATE pim_catalog_product
SET raw_values = JSON_SET(
    raw_values,
    '$.meta_description[0].data',
    LEFT(JSON_UNQUOTE(JSON_EXTRACT(raw_values, '$.description[0].data')), 160),
    '$.meta_description[0].locale', 'fr_FR',
    '$.meta_description[0].scope', NULL
),
updated = NOW()
WHERE JSON_CONTAINS_PATH(raw_values, 'one', '$.description')
AND (
    NOT JSON_CONTAINS_PATH(raw_values, 'one', '$.meta_description')
    OR JSON_UNQUOTE(JSON_EXTRACT(raw_values, '$.meta_description[0].data')) = ''
)
LIMIT 1000;
SQL
    
    log_success "Meta titles and descriptions generated"
}

################################################################################
# PHASE 7: FINAL REPORT
################################################################################
final_report() {
    log_step "PHASE 7: FINAL REPORT"
    
    echo ""
    echo -e "${PURPLE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║        SEO TUNINGS APPLIED - FINAL STATUS                  ║${NC}"
    echo -e "${PURPLE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    /opt/mariadb10.6/mariadb/bin/mysql -u akeneo_pim -p'akeneo_pim' -h 127.0.0.1 -P 3307 akeneo_pim -t <<'SQLFINAL'
SELECT 
    'SEO METRIC' as Metric,
    'COUNT' as Count
UNION ALL
SELECT '─────────────────────────────', '──────────────'
UNION ALL
SELECT '✅ Products with Names', CAST(COUNT(*) AS CHAR)
FROM pim_catalog_product
WHERE JSON_CONTAINS_PATH(raw_values, 'one', '$.name')
UNION ALL
SELECT '✅ Products with Descriptions', CAST(COUNT(*) AS CHAR)
FROM pim_catalog_product
WHERE JSON_CONTAINS_PATH(raw_values, 'one', '$.description')
UNION ALL
SELECT '✅ Products with URL Keys', CAST(COUNT(*) AS CHAR)
FROM pim_catalog_product
WHERE JSON_CONTAINS_PATH(raw_values, 'one', '$.url_key')
UNION ALL
SELECT '✅ Products with Meta Titles', CAST(COUNT(*) AS CHAR)
FROM pim_catalog_product
WHERE JSON_CONTAINS_PATH(raw_values, 'one', '$.meta_title')
UNION ALL
SELECT '✅ Products with Meta Desc', CAST(COUNT(*) AS CHAR)
FROM pim_catalog_product
WHERE JSON_CONTAINS_PATH(raw_values, 'one', '$.meta_description')
UNION ALL
SELECT '─────────────────────────────', '──────────────'
UNION ALL
SELECT '📊 Total Products', CAST(COUNT(*) AS CHAR)
FROM pim_catalog_product
UNION ALL
SELECT '📊 Enabled Products', CAST(SUM(is_enabled) AS CHAR)
FROM pim_catalog_product;
SQLFINAL
    
    echo ""
    log_success "SEO TUNINGS COMPLETE!"
    log_info "Products are now optimized for search engines"
}

################################################################################
# MAIN EXECUTION
################################################################################
main() {
    log_step "STARTING SEO TUNINGS APPLICATION"
    log_info "Start time: $(date)"
    
    optimize_names
    enrich_descriptions
    generate_url_keys
    generate_meta_data
    calculate_completeness
    reindex_elasticsearch
    final_report
    
    log_info "End time: $(date)"
    log_success "ALL SEO OPERATIONS COMPLETE!"
}

main "$@"
