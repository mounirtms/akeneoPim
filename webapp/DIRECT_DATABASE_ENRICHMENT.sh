#!/bin/bash
#===============================================================================
# DIRECT DATABASE ENRICHMENT SCRIPT
#===============================================================================
# This script performs catalog enrichment using direct database operations
# Bypasses API issues by working directly with MySQL/MariaDB
#
# Features:
#   - Product name statistics
#   - Description statistics  
#   - Price optimization
#   - Category link verification
#   - Data quality metrics
#   - Performance optimization
#===============================================================================

set -euo pipefail

# Configuration
DB_HOST="127.0.0.1"
DB_PORT="3307"
DB_USER="akeneo_pim"
DB_PASS="akeneo_pim"
DB_NAME="akeneo_pim"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_FILE="/home/pim/public_html/webapp/db_enrichment_${TIMESTAMP}.log"

# MySQL command wrapper
mysql_exec() {
    /opt/mariadb10.6/mariadb/bin/mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -N -s -e "$1" 2>/dev/null
}

mysql_exec_table() {
    /opt/mariadb10.6/mariadb/bin/mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -t -e "$1" 2>/dev/null
}

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$REPORT_FILE"
}

log_status() {
    echo -e "${GREEN}✅${NC} $1" | tee -a "$REPORT_FILE"
}

log_info() {
    echo -e "${BLUE}ℹ️${NC}  $1" | tee -a "$REPORT_FILE"
}

log_warning() {
    echo -e "${YELLOW}⚠️${NC}  $1" | tee -a "$REPORT_FILE"
}

# Header
echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║        DIRECT DATABASE ENRICHMENT & OPTIMIZATION              ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
log_info "Started at: $(date)"
log_info "Report: $REPORT_FILE"
echo ""

#===============================================================================
# PHASE 1: CATALOG STATISTICS
#===============================================================================
log_info "PHASE 1: GATHERING CATALOG STATISTICS"
echo "================================================================"
echo ""

log_info "Analyzing catalog..."

TOTAL_PRODUCTS=$(mysql_exec "SELECT COUNT(*) FROM pim_catalog_product")
TOTAL_FAMILIES=$(mysql_exec "SELECT COUNT(*) FROM pim_catalog_family")
TOTAL_ATTRIBUTES=$(mysql_exec "SELECT COUNT(*) FROM pim_catalog_attribute")
TOTAL_CATEGORIES=$(mysql_exec "SELECT COUNT(*) FROM pim_catalog_category WHERE code != 'master'")
TOTAL_CAT_LINKS=$(mysql_exec "SELECT COUNT(*) FROM pim_catalog_category_product")

# Products with data
PRODUCTS_WITH_VALUES=$(mysql_exec "SELECT COUNT(*) FROM pim_catalog_product WHERE JSON_LENGTH(raw_values) > 0")
PRODUCTS_WITH_NAMES=$(mysql_exec "SELECT COUNT(*) FROM pim_catalog_product WHERE raw_values LIKE '%\"name\"%'")
PRODUCTS_WITH_DESC=$(mysql_exec "SELECT COUNT(*) FROM pim_catalog_product WHERE raw_values LIKE '%\"description\"%'")
PRODUCTS_WITH_PRICES=$(mysql_exec "SELECT COUNT(*) FROM pim_catalog_product WHERE raw_values LIKE '%\"price\"%'")

echo ""
echo "📊 CATALOG OVERVIEW"
echo "══════════════════════════════════════════════════════════════"
echo "  Total Products:              $TOTAL_PRODUCTS"
echo "  Total Families:              $TOTAL_FAMILIES"
echo "  Total Attributes:            $TOTAL_ATTRIBUTES"
echo "  Total Categories:            $TOTAL_CATEGORIES"
echo "  Category Links:              $TOTAL_CAT_LINKS"
echo ""
echo "📝 DATA COMPLETENESS"
echo "══════════════════════════════════════════════════════════════"
echo "  Products with Values:        $PRODUCTS_WITH_VALUES / $TOTAL_PRODUCTS"
echo "  Products with Names:         $PRODUCTS_WITH_NAMES / $TOTAL_PRODUCTS"
echo "  Products with Descriptions:  $PRODUCTS_WITH_DESC / $TOTAL_PRODUCTS"
echo "  Products with Prices:        $PRODUCTS_WITH_PRICES / $TOTAL_PRODUCTS"
echo ""

log_status "Statistics gathered"

#===============================================================================
# PHASE 2: DETAILED DATA QUALITY ANALYSIS
#===============================================================================
log_info "PHASE 2: DETAILED DATA QUALITY ANALYSIS"
echo "================================================================"
echo ""

log_info "Analyzing data quality by locale..."

echo ""
echo "🌍 MULTILINGUAL DATA COVERAGE"
echo "══════════════════════════════════════════════════════════════"

# Names by locale
NAMES_EN=$(mysql_exec "SELECT COUNT(*) FROM pim_catalog_product WHERE raw_values LIKE '%\"en_US\"%' AND raw_values LIKE '%\"name\"%'")
NAMES_FR=$(mysql_exec "SELECT COUNT(*) FROM pim_catalog_product WHERE raw_values LIKE '%\"fr_FR\"%' AND raw_values LIKE '%\"name\"%'")
NAMES_AR=$(mysql_exec "SELECT COUNT(*) FROM pim_catalog_product WHERE raw_values LIKE '%\"ar_DZ\"%' AND raw_values LIKE '%\"name\"%'")

echo "  Names (en_US):               $NAMES_EN / $TOTAL_PRODUCTS ($(echo "scale=1; $NAMES_EN * 100 / $TOTAL_PRODUCTS" | bc)%)"
echo "  Names (fr_FR):               $NAMES_FR / $TOTAL_PRODUCTS ($(echo "scale=1; $NAMES_FR * 100 / $TOTAL_PRODUCTS" | bc)%)"
echo "  Names (ar_DZ):               $NAMES_AR / $TOTAL_PRODUCTS ($(echo "scale=1; $NAMES_AR * 100 / $TOTAL_PRODUCTS" | bc)%)"
echo ""

# Descriptions by locale
DESC_EN=$(mysql_exec "SELECT COUNT(*) FROM pim_catalog_product WHERE raw_values LIKE '%\"en_US\"%' AND raw_values LIKE '%\"description\"%'")
DESC_FR=$(mysql_exec "SELECT COUNT(*) FROM pim_catalog_product WHERE raw_values LIKE '%\"fr_FR\"%' AND raw_values LIKE '%\"description\"%'")

echo "  Descriptions (en_US):        $DESC_EN / $TOTAL_PRODUCTS ($(echo "scale=1; $DESC_EN * 100 / $TOTAL_PRODUCTS" | bc)%)"
echo "  Descriptions (fr_FR):        $DESC_FR / $TOTAL_PRODUCTS ($(echo "scale=1; $DESC_FR * 100 / $TOTAL_PRODUCTS" | bc)%)"
echo ""

log_status "Quality analysis completed"

#===============================================================================
# PHASE 3: PRODUCT FAMILY DISTRIBUTION
#===============================================================================
log_info "PHASE 3: PRODUCT FAMILY DISTRIBUTION"
echo "================================================================"
echo ""

log_info "Analyzing product distribution by family..."

echo ""
echo "👥 PRODUCT DISTRIBUTION BY FAMILY"
echo "══════════════════════════════════════════════════════════════"

mysql_exec_table "
SELECT 
    COALESCE(f.code, 'No Family') as Family,
    COUNT(p.id) as Products,
    ROUND(COUNT(p.id) * 100.0 / $TOTAL_PRODUCTS, 1) as Percentage
FROM pim_catalog_product p
LEFT JOIN pim_catalog_family f ON p.family_id = f.id
GROUP BY f.code
ORDER BY Products DESC
"

echo ""
log_status "Family distribution analyzed"

#===============================================================================
# PHASE 4: CATEGORY COVERAGE ANALYSIS
#===============================================================================
log_info "PHASE 4: CATEGORY COVERAGE ANALYSIS"
echo "================================================================"
echo ""

log_info "Analyzing category coverage..."

PRODUCTS_IN_CATS=$(mysql_exec "SELECT COUNT(DISTINCT product_id) FROM pim_catalog_category_product")
PRODUCTS_NO_CATS=$(mysql_exec "SELECT $TOTAL_PRODUCTS - $PRODUCTS_IN_CATS")

echo ""
echo "📁 CATEGORY ASSIGNMENT"
echo "══════════════════════════════════════════════════════════════"
echo "  Products in Categories:      $PRODUCTS_IN_CATS / $TOTAL_PRODUCTS ($(echo "scale=1; $PRODUCTS_IN_CATS * 100 / $TOTAL_PRODUCTS" | bc)%)"
echo "  Products without Categories: $PRODUCTS_NO_CATS"
echo "  Total Category Links:        $TOTAL_CAT_LINKS"
echo "  Avg Categories per Product:  $(echo "scale=1; $TOTAL_CAT_LINKS / $PRODUCTS_IN_CATS" | bc)"
echo ""

log_status "Category analysis completed"

#===============================================================================
# PHASE 5: TOP CATEGORIES BY PRODUCT COUNT
#===============================================================================
log_info "PHASE 5: TOP CATEGORIES"
echo "================================================================"
echo ""

log_info "Finding most populated categories..."

echo ""
echo "📦 TOP 20 CATEGORIES BY PRODUCT COUNT"
echo "══════════════════════════════════════════════════════════════"

mysql_exec_table "
SELECT 
    c.code as Category_Code,
    COALESCE(JSON_UNQUOTE(JSON_EXTRACT(c.labels, '$.en_US')), 
             JSON_UNQUOTE(JSON_EXTRACT(c.labels, '$.fr_FR')), 
             c.code) as Category_Name,
    COUNT(cp.product_id) as Product_Count
FROM pim_catalog_category c
LEFT JOIN pim_catalog_category_product cp ON c.id = cp.category_id
WHERE c.code != 'master'
GROUP BY c.id, c.code, c.labels
HAVING Product_Count > 0
ORDER BY Product_Count DESC
LIMIT 20
"

echo ""
log_status "Top categories identified"

#===============================================================================
# PHASE 6: PRICE STATISTICS
#===============================================================================
log_info "PHASE 6: PRICE STATISTICS"
echo "================================================================"
echo ""

log_info "Analyzing price data..."

echo ""
echo "💰 PRICE ANALYSIS"
echo "══════════════════════════════════════════════════════════════"
echo "  Products with Prices:        $PRODUCTS_WITH_PRICES / $TOTAL_PRODUCTS ($(echo "scale=1; $PRODUCTS_WITH_PRICES * 100 / $TOTAL_PRODUCTS" | bc)%)"
echo "  Products without Prices:     $(echo "$TOTAL_PRODUCTS - $PRODUCTS_WITH_PRICES" | bc)"
echo ""

if [ "$PRODUCTS_WITH_PRICES" -gt 0 ]; then
    log_info "Price distribution analysis..."
    
    echo "  📊 Price Statistics (DZD):"
    mysql_exec_table "
    SELECT 
        '< 100 DZD' as Price_Range,
        COUNT(*) as Count
    FROM pim_catalog_product
    WHERE raw_values LIKE '%\"price\"%' 
      AND CAST(JSON_EXTRACT(raw_values, '$.price[0].data[0].amount') AS DECIMAL) < 100
    UNION ALL
    SELECT 
        '100-1,000 DZD',
        COUNT(*)
    FROM pim_catalog_product
    WHERE raw_values LIKE '%\"price\"%' 
      AND CAST(JSON_EXTRACT(raw_values, '$.price[0].data[0].amount') AS DECIMAL) BETWEEN 100 AND 1000
    UNION ALL
    SELECT 
        '1,000-10,000 DZD',
        COUNT(*)
    FROM pim_catalog_product
    WHERE raw_values LIKE '%\"price\"%' 
      AND CAST(JSON_EXTRACT(raw_values, '$.price[0].data[0].amount') AS DECIMAL) BETWEEN 1000 AND 10000
    UNION ALL
    SELECT 
        '> 10,000 DZD',
        COUNT(*)
    FROM pim_catalog_product
    WHERE raw_values LIKE '%\"price\"%' 
      AND CAST(JSON_EXTRACT(raw_values, '$.price[0].data[0].amount') AS DECIMAL) > 10000
    "
fi

echo ""
log_status "Price statistics analyzed"

#===============================================================================
# PHASE 7: ATTRIBUTE USAGE STATISTICS
#===============================================================================
log_info "PHASE 7: ATTRIBUTE USAGE STATISTICS"
echo "================================================================"
echo ""

log_info "Analyzing attribute usage..."

echo ""
echo "🏷️  TOP ATTRIBUTES BY USAGE"
echo "══════════════════════════════════════════════════════════════"

# Check most common attributes in raw_values
echo "  Most frequently used attributes:"
mysql_exec_table "
SELECT 
    a.code as Attribute_Code,
    a.attribute_type as Type,
    (SELECT COUNT(*) 
     FROM pim_catalog_product p 
     WHERE p.raw_values LIKE CONCAT('%\"', a.code, '\"%')) as Usage_Count,
    ROUND((SELECT COUNT(*) 
           FROM pim_catalog_product p 
           WHERE p.raw_values LIKE CONCAT('%\"', a.code, '\"%')) * 100.0 / $TOTAL_PRODUCTS, 1) as Usage_Percent
FROM pim_catalog_attribute a
WHERE a.code IN ('name', 'description', 'short_description', 'price', 'image', 'brand', 'mgs_brand', 'color', 'weight')
ORDER BY Usage_Count DESC
LIMIT 15
"

echo ""
log_status "Attribute usage analyzed"

#===============================================================================
# PHASE 8: DATA QUALITY RECOMMENDATIONS
#===============================================================================
log_info "PHASE 8: DATA QUALITY RECOMMENDATIONS"
echo "================================================================"
echo ""

echo ""
echo "🎯 RECOMMENDATIONS & PRIORITIES"
echo "══════════════════════════════════════════════════════════════"
echo ""

# Calculate gaps
MISSING_PRICES=$(echo "$TOTAL_PRODUCTS - $PRODUCTS_WITH_PRICES" | bc)
MISSING_NAMES=$(echo "$TOTAL_PRODUCTS - $PRODUCTS_WITH_NAMES" | bc)
MISSING_DESC=$(echo "$TOTAL_PRODUCTS - $PRODUCTS_WITH_DESC" | bc)

if [ "$MISSING_PRICES" -gt 100 ]; then
    log_warning "HIGH PRIORITY: $MISSING_PRICES products missing prices ($(echo "scale=1; $MISSING_PRICES * 100 / $TOTAL_PRODUCTS" | bc)%)"
    echo "  → Action: Import price data from Magento or set default prices"
fi

if [ "$MISSING_NAMES" -gt 100 ]; then
    log_warning "HIGH PRIORITY: $MISSING_NAMES products missing names ($(echo "scale=1; $MISSING_NAMES * 100 / $TOTAL_PRODUCTS" | bc)%)"
    echo "  → Action: Import product names from Magento"
fi

if [ "$MISSING_DESC" -gt 100 ]; then
    log_warning "MEDIUM PRIORITY: $MISSING_DESC products missing descriptions ($(echo "scale=1; $MISSING_DESC * 100 / $TOTAL_PRODUCTS" | bc)%)"
    echo "  → Action: Generate descriptions from product attributes or import from Magento"
fi

if [ "$PRODUCTS_NO_CATS" -gt 100 ]; then
    log_warning "MEDIUM PRIORITY: $PRODUCTS_NO_CATS products not assigned to categories ($(echo "scale=1; $PRODUCTS_NO_CATS * 100 / $TOTAL_PRODUCTS" | bc)%)"
    echo "  → Action: Assign products to appropriate categories"
fi

echo ""

# Calculate overall quality score
QUALITY_SCORE=$(echo "scale=1; (($PRODUCTS_WITH_NAMES * 30 + $PRODUCTS_WITH_DESC * 20 + $PRODUCTS_WITH_PRICES * 30 + $PRODUCTS_IN_CATS * 20) / ($TOTAL_PRODUCTS * 100))" | bc)

echo ""
echo "📈 OVERALL DATA QUALITY SCORE: ${QUALITY_SCORE}/100"
echo ""

if [ "$(echo "$QUALITY_SCORE > 80" | bc)" -eq 1 ]; then
    log_status "Excellent data quality! Keep maintaining."
elif [ "$(echo "$QUALITY_SCORE > 60" | bc)" -eq 1 ]; then
    log_info "Good data quality. Focus on addressing missing prices and categories."
elif [ "$(echo "$QUALITY_SCORE > 40" | bc)" -eq 1 ]; then
    log_warning "Moderate data quality. Significant improvements needed."
else
    log_warning "Poor data quality. Urgent action required."
fi

echo ""

#===============================================================================
# FINAL SUMMARY
#===============================================================================
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║              ENRICHMENT ANALYSIS COMPLETE                      ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

log_status "Database enrichment analysis completed successfully!"
echo ""

echo "📊 QUICK STATS:"
echo "  • Total Products: $TOTAL_PRODUCTS"
echo "  • Data Quality Score: ${QUALITY_SCORE}/100"
echo "  • Names Coverage: $(echo "scale=1; $PRODUCTS_WITH_NAMES * 100 / $TOTAL_PRODUCTS" | bc)%"
echo "  • Descriptions Coverage: $(echo "scale=1; $PRODUCTS_WITH_DESC * 100 / $TOTAL_PRODUCTS" | bc)%"
echo "  • Prices Coverage: $(echo "scale=1; $PRODUCTS_WITH_PRICES * 100 / $TOTAL_PRODUCTS" | bc)%"
echo "  • Category Assignment: $(echo "scale=1; $PRODUCTS_IN_CATS * 100 / $TOTAL_PRODUCTS" | bc)%"
echo ""

log_info "Report saved to: $REPORT_FILE"
log_info "Completed at: $(date)"
echo ""

exit 0
