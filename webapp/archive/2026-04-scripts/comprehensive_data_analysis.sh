#!/bin/bash

# Comprehensive Data Quality Analysis for Akeneo PIM
# Date: April 23, 2026
# Focus: French locale data quality assessment

REPORT_FILE="comprehensive_analysis_$(date +%Y%m%d_%H%M%S).txt"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

echo "=====================================================================" | tee $REPORT_FILE
echo "COMPREHENSIVE DATA QUALITY ANALYSIS - Akeneo PIM" | tee -a $REPORT_FILE
echo "Date: $TIMESTAMP" | tee -a $REPORT_FILE
echo "Locale Focus: French (fr_FR)" | tee -a $REPORT_FILE
echo "=====================================================================" | tee -a $REPORT_FILE
echo "" | tee -a $REPORT_FILE

# Database credentials
DB_USER="u341287766_akeneodb"
DB_PASS="TmsPim2o24"
DB_NAME="u341287766_akeneodb"

echo "1. LOCALE CONFIGURATION ANALYSIS" | tee -a $REPORT_FILE
echo "-----------------------------------" | tee -a $REPORT_FILE

# Check available locales
echo "Available Locales:" | tee -a $REPORT_FILE
mysql -u $DB_USER -p$DB_PASS $DB_NAME -e "
SELECT code, is_activated 
FROM pim_catalog_locale 
ORDER BY code;" 2>/dev/null | tee -a $REPORT_FILE

# Check active locales
ACTIVE_LOCALES=$(mysql -u $DB_USER -p$DB_PASS $DB_NAME -sN -e "
SELECT COUNT(*) FROM pim_catalog_locale WHERE is_activated = 1;" 2>/dev/null)
echo "" | tee -a $REPORT_FILE
echo "Active Locales Count: $ACTIVE_LOCALES" | tee -a $REPORT_FILE

# Check if fr_FR is active
FR_ACTIVE=$(mysql -u $DB_USER -p$DB_PASS $DB_NAME -sN -e "
SELECT is_activated FROM pim_catalog_locale WHERE code = 'fr_FR';" 2>/dev/null)
echo "French (fr_FR) Status: ${FR_ACTIVE:-'NOT FOUND'}" | tee -a $REPORT_FILE
echo "" | tee -a $REPORT_FILE

echo "2. CHANNEL CONFIGURATION" | tee -a $REPORT_FILE
echo "-------------------------" | tee -a $REPORT_FILE

# List all channels
echo "Available Channels:" | tee -a $REPORT_FILE
mysql -u $DB_USER -p$DB_PASS $DB_NAME -e "
SELECT code, category_tree, conversion_units 
FROM pim_catalog_channel;" 2>/dev/null | tee -a $REPORT_FILE

# Check channel-locale associations
echo "" | tee -a $REPORT_FILE
echo "Channel-Locale Associations:" | tee -a $REPORT_FILE
mysql -u $DB_USER -p$DB_PASS $DB_NAME -e "
SELECT c.code as channel_code, l.code as locale_code 
FROM pim_catalog_channel c
LEFT JOIN pim_catalog_channel_locale cl ON c.id = cl.channel_id
LEFT JOIN pim_catalog_locale l ON cl.locale_id = l.id
ORDER BY c.code, l.code;" 2>/dev/null | tee -a $REPORT_FILE
echo "" | tee -a $REPORT_FILE

echo "3. FAMILY ANALYSIS" | tee -a $REPORT_FILE
echo "-------------------" | tee -a $REPORT_FILE

# Count families
FAMILY_COUNT=$(mysql -u $DB_USER -p$DB_PASS $DB_NAME -sN -e "
SELECT COUNT(*) FROM pim_catalog_family;" 2>/dev/null)
echo "Total Families: ${FAMILY_COUNT:-0}" | tee -a $REPORT_FILE

# List top 20 families with product counts
echo "" | tee -a $REPORT_FILE
echo "Top 20 Families (by product count):" | tee -a $REPORT_FILE
mysql -u $DB_USER -p$DB_PASS $DB_NAME -e "
SELECT f.code, 
       COUNT(DISTINCT p.identifier) as product_count
FROM pim_catalog_family f
LEFT JOIN pim_catalog_product p ON p.family_id = f.id
GROUP BY f.id, f.code
ORDER BY product_count DESC
LIMIT 20;" 2>/dev/null | tee -a $REPORT_FILE
echo "" | tee -a $REPORT_FILE

echo "4. ATTRIBUTE ANALYSIS" | tee -a $REPORT_FILE
echo "----------------------" | tee -a $REPORT_FILE

# Count attributes by type
echo "Attributes by Type:" | tee -a $REPORT_FILE
mysql -u $DB_USER -p$DB_PASS $DB_NAME -e "
SELECT attribute_type, COUNT(*) as count
FROM pim_catalog_attribute
GROUP BY attribute_type
ORDER BY count DESC;" 2>/dev/null | tee -a $REPORT_FILE

# Check localizable attributes
LOCALIZABLE_COUNT=$(mysql -u $DB_USER -p$DB_PASS $DB_NAME -sN -e "
SELECT COUNT(*) FROM pim_catalog_attribute WHERE is_localizable = 1;" 2>/dev/null)
echo "" | tee -a $REPORT_FILE
echo "Localizable Attributes: ${LOCALIZABLE_COUNT:-0}" | tee -a $REPORT_FILE

# Check scopable attributes
SCOPABLE_COUNT=$(mysql -u $DB_USER -p$DB_PASS $DB_NAME -sN -e "
SELECT COUNT(*) FROM pim_catalog_attribute WHERE is_scopable = 1;" 2>/dev/null)
echo "Scopable Attributes: ${SCOPABLE_COUNT:-0}" | tee -a $REPORT_FILE
echo "" | tee -a $REPORT_FILE

echo "5. PRODUCT DATA ANALYSIS" | tee -a $REPORT_FILE
echo "-------------------------" | tee -a $REPORT_FILE

# Count products
PRODUCT_COUNT=$(mysql -u $DB_USER -p$DB_PASS $DB_NAME -sN -e "
SELECT COUNT(*) FROM pim_catalog_product;" 2>/dev/null)
echo "Total Products: ${PRODUCT_COUNT:-0}" | tee -a $REPORT_FILE

# Count product models
MODEL_COUNT=$(mysql -u $DB_USER -p$DB_PASS $DB_NAME -sN -e "
SELECT COUNT(*) FROM pim_catalog_product_model;" 2>/dev/null)
echo "Total Product Models: ${MODEL_COUNT:-0}" | tee -a $REPORT_FILE

# Products without family
PRODUCTS_NO_FAMILY=$(mysql -u $DB_USER -p$DB_PASS $DB_NAME -sN -e "
SELECT COUNT(*) FROM pim_catalog_product WHERE family_id IS NULL;" 2>/dev/null)
echo "Products without Family: ${PRODUCTS_NO_FAMILY:-0}" | tee -a $REPORT_FILE

# Products enabled/disabled
ENABLED_COUNT=$(mysql -u $DB_USER -p$DB_PASS $DB_NAME -sN -e "
SELECT COUNT(*) FROM pim_catalog_product WHERE is_enabled = 1;" 2>/dev/null)
echo "Enabled Products: ${ENABLED_COUNT:-0}" | tee -a $REPORT_FILE
echo "" | tee -a $REPORT_FILE

echo "6. CATEGORY ANALYSIS" | tee -a $REPORT_FILE
echo "---------------------" | tee -a $REPORT_FILE

# Count categories
CATEGORY_COUNT=$(mysql -u $DB_USER -p$DB_PASS $DB_NAME -sN -e "
SELECT COUNT(*) FROM pim_catalog_category;" 2>/dev/null)
echo "Total Categories: ${CATEGORY_COUNT:-0}" | tee -a $REPORT_FILE

# Category tree depth
echo "" | tee -a $REPORT_FILE
echo "Category Tree Structure:" | tee -a $REPORT_FILE
mysql -u $DB_USER -p$DB_PASS $DB_NAME -e "
SELECT code, parent_id, lvl
FROM pim_catalog_category
ORDER BY lvl, code
LIMIT 30;" 2>/dev/null | tee -a $REPORT_FILE
echo "" | tee -a $REPORT_FILE

echo "7. COMPLETENESS ANALYSIS" | tee -a $REPORT_FILE
echo "-------------------------" | tee -a $REPORT_FILE

# Check completeness table
echo "Completeness by Channel and Locale (Sample):" | tee -a $REPORT_FILE
mysql -u $DB_USER -p$DB_PASS $DB_NAME -e "
SELECT 
    c.code as channel,
    l.code as locale,
    AVG(pc.ratio) as avg_completeness,
    COUNT(*) as product_count
FROM pim_catalog_completeness pc
JOIN pim_catalog_channel c ON pc.channel_id = c.id
JOIN pim_catalog_locale l ON pc.locale_id = l.id
GROUP BY c.code, l.code
ORDER BY c.code, l.code;" 2>/dev/null | tee -a $REPORT_FILE

# Find products with low completeness
echo "" | tee -a $REPORT_FILE
echo "Products with Completeness < 50% (Sample of 10):" | tee -a $REPORT_FILE
mysql -u $DB_USER -p$DB_PASS $DB_NAME -e "
SELECT 
    p.identifier,
    c.code as channel,
    l.code as locale,
    pc.ratio as completeness
FROM pim_catalog_completeness pc
JOIN pim_catalog_product p ON pc.product_id = p.id
JOIN pim_catalog_channel c ON pc.channel_id = c.id
JOIN pim_catalog_locale l ON pc.locale_id = l.id
WHERE pc.ratio < 50
ORDER BY pc.ratio ASC
LIMIT 10;" 2>/dev/null | tee -a $REPORT_FILE
echo "" | tee -a $REPORT_FILE

echo "8. ELASTICSEARCH INDEX STATUS" | tee -a $REPORT_FILE
echo "-------------------------------" | tee -a $REPORT_FILE

# Check ES indices
curl -s "http://localhost:9200/_cat/indices/akeneo*?v&h=index,docs.count,store.size,health" | tee -a $REPORT_FILE
echo "" | tee -a $REPORT_FILE

echo "9. DATA QUALITY ISSUES DETECTION" | tee -a $REPORT_FILE
echo "----------------------------------" | tee -a $REPORT_FILE

# Check for products with missing required attributes
echo "Sample Products Missing Required Attributes:" | tee -a $REPORT_FILE
mysql -u $DB_USER -p$DB_PASS $DB_NAME -e "
SELECT p.identifier, f.code as family_code
FROM pim_catalog_product p
JOIN pim_catalog_family f ON p.family_id = f.id
WHERE p.id IN (
    SELECT DISTINCT product_id 
    FROM pim_catalog_completeness 
    WHERE missing_count > 0
    LIMIT 10
);" 2>/dev/null | tee -a $REPORT_FILE
echo "" | tee -a $REPORT_FILE

echo "10. SYSTEM RECOMMENDATIONS" | tee -a $REPORT_FILE
echo "---------------------------" | tee -a $REPORT_FILE

cat << 'RECOMMENDATIONS' | tee -a $REPORT_FILE

CRITICAL ACTIONS REQUIRED:
==========================

1. LOCALE CONFIGURATION
   - Verify fr_FR locale is activated
   - If not active, activate via: System > Configuration > Locales
   - Configure channels to use French locale
   - Set fr_FR as primary locale for all channels

2. ATTRIBUTE LOCALIZATION
   - Review localizable attributes (currently: see count above)
   - Ensure all user-facing attributes are marked as localizable
   - Add French translations for all attribute labels and descriptions

3. FAMILY CONFIGURATION
   - Review family structures for French market requirements
   - Ensure required attributes are properly defined
   - Configure completeness requirements per family

4. PRODUCT ENRICHMENT
   - Address products with < 50% completeness
   - Focus on products without families
   - Add missing French descriptions and translations

5. CATEGORY MANAGEMENT
   - Review category tree structure
   - Add French translations for all category labels
   - Optimize category depth (max 4-5 levels recommended)

TOOLS NEEDED:
=============

Phase 1 - Immediate (Week 1-2):
- French locale activation tool
- Bulk attribute translation tool
- Completeness calculator and reporter
- Missing data identifier

Phase 2 - Short-term (Week 3-4):
- Data quality dashboard
- Bulk product enrichment tool
- Asset management and upload tool
- Translation workflow automation

Phase 3 - Medium-term (Month 2):
- Advanced quality gates
- Automated validation rules
- Import/export optimization
- API integration tools

Phase 4 - Long-term (Month 3+):
- ML-based data quality suggestions
- Automated translation integration
- Advanced reporting and analytics
- Multi-channel synchronization

PERFORMANCE METRICS:
===================

Current Status:
- Products: Check count above
- Elasticsearch sync: ~100% (10,095 docs)
- Average completeness: See data above
- Active locales: Check count above

Target Metrics (30 days):
- Average completeness: > 80%
- Products with completeness < 50%: < 5%
- All critical attributes localized: 100%
- French translations complete: > 90%

RECOMMENDATIONS

echo "" | tee -a $REPORT_FILE
echo "=====================================================================" | tee -a $REPORT_FILE
echo "ANALYSIS COMPLETE" | tee -a $REPORT_FILE
echo "Report saved to: $REPORT_FILE" | tee -a $REPORT_FILE
echo "=====================================================================" | tee -a $REPORT_FILE

