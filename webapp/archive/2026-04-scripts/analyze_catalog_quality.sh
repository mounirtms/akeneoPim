#!/bin/bash

echo "=========================================="
echo "Akeneo PIM Catalog Enhancement & Testing"
echo "=========================================="
echo "Date: $(date)"
echo ""

# Define base directory
BASE_DIR="/home/pim/public_html"
cd "$BASE_DIR"

# 1. Check Product Completeness
echo "=========================================="
echo "1. PRODUCT COMPLETENESS ANALYSIS"
echo "=========================================="
echo ""

echo "Analyzing product completeness..."
php bin/console doctrine:query:sql "
SELECT 
    COUNT(*) as total_products,
    SUM(CASE WHEN completeness >= 100 THEN 1 ELSE 0 END) as complete_products,
    ROUND(AVG(completeness), 2) as avg_completeness
FROM (
    SELECT p.id, 
           COUNT(DISTINCT pv.attribute_id) * 100 / 
           NULLIF((SELECT COUNT(*) FROM pim_catalog_attribute WHERE is_required = 1), 0) as completeness
    FROM pim_catalog_product p
    LEFT JOIN pim_catalog_product_value pv ON p.id = pv.product_id
    GROUP BY p.id
) as completeness_data
" 2>/dev/null | tail -1

echo ""

# 2. Check Attributes Usage
echo "=========================================="
echo "2. ATTRIBUTE USAGE ANALYSIS"
echo "=========================================="
echo ""

echo "Getting attribute statistics..."
php bin/console doctrine:query:sql "
SELECT 
    a.code as attribute_code,
    a.attribute_type as type,
    a.is_required as required,
    COUNT(DISTINCT pv.product_id) as products_using
FROM pim_catalog_attribute a
LEFT JOIN pim_catalog_product_value pv ON a.id = pv.attribute_id
GROUP BY a.id, a.code, a.attribute_type, a.is_required
ORDER BY products_using DESC
LIMIT 20
" 2>/dev/null

echo ""

# 3. Check Product Families
echo "=========================================="
echo "3. PRODUCT FAMILY DISTRIBUTION"
echo "=========================================="
echo ""

echo "Analyzing product families..."
php bin/console doctrine:query:sql "
SELECT 
    f.code as family_code,
    f.label as family_label,
    COUNT(p.id) as product_count
FROM pim_catalog_family f
LEFT JOIN pim_catalog_product p ON f.id = p.family_id
GROUP BY f.id, f.code, f.label
ORDER BY product_count DESC
" 2>/dev/null

echo ""

# 4. Check Categories Distribution
echo "=========================================="
echo "4. CATEGORY DISTRIBUTION"
echo "=========================================="
echo ""

echo "Analyzing category usage..."
php bin/console doctrine:query:sql "
SELECT 
    c.code as category_code,
    c.label as category_label,
    COUNT(DISTINCT pc.product_id) as product_count
FROM pim_catalog_category c
LEFT JOIN pim_catalog_category_product pc ON c.id = pc.category_id
GROUP BY c.id, c.code, c.label
ORDER BY product_count DESC
LIMIT 20
" 2>/dev/null

echo ""

# 5. Check Product Models
echo "=========================================="
echo "5. PRODUCT MODEL ANALYSIS"
echo "=========================================="
echo ""

echo "Analyzing product models..."
php bin/console doctrine:query:sql "
SELECT 
    COUNT(*) as total_models,
    COUNT(DISTINCT family_variant_id) as unique_variants,
    COUNT(DISTINCT parent_id) as parent_models
FROM pim_catalog_product_model
" 2>/dev/null | tail -1

echo ""

# 6. Check Locales and Channels
echo "=========================================="
echo "6. LOCALES AND CHANNELS"
echo "=========================================="
echo ""

echo "Active locales:"
php bin/console doctrine:query:sql "
SELECT code, label 
FROM pim_catalog_locale 
WHERE is_activated = 1
" 2>/dev/null

echo ""
echo "Active channels:"
php bin/console doctrine:query:sql "
SELECT code, label 
FROM pim_catalog_channel
" 2>/dev/null

echo ""

# 7. Check Data Quality
echo "=========================================="
echo "7. DATA QUALITY INSIGHTS"
echo "=========================================="
echo ""

echo "Checking data quality scores..."
php bin/console doctrine:query:sql "
SELECT 
    COUNT(*) as products_evaluated,
    AVG(scores_partial_criteria) as avg_quality_score
FROM pimee_data_quality_insights_product_score
WHERE evaluated_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)
" 2>/dev/null | tail -1

echo ""

# 8. Check Missing Product Data
echo "=========================================="
echo "8. MISSING CRITICAL DATA"
echo "=========================================="
echo ""

echo "Products without images:"
php bin/console doctrine:query:sql "
SELECT COUNT(DISTINCT p.id) as products_without_images
FROM pim_catalog_product p
WHERE NOT EXISTS (
    SELECT 1 FROM pim_catalog_product_value pv
    JOIN pim_catalog_attribute a ON pv.attribute_id = a.id
    WHERE pv.product_id = p.id 
    AND a.attribute_type = 'pim_catalog_image'
)
" 2>/dev/null | tail -1

echo ""
echo "Products without descriptions:"
php bin/console doctrine:query:sql "
SELECT COUNT(DISTINCT p.id) as products_without_description
FROM pim_catalog_product p
WHERE NOT EXISTS (
    SELECT 1 FROM pim_catalog_product_value pv
    JOIN pim_catalog_attribute a ON pv.attribute_id = a.id
    WHERE pv.product_id = p.id 
    AND a.code IN ('description', 'short_description')
    AND pv.data IS NOT NULL
    AND pv.data != ''
)
" 2>/dev/null | tail -1

echo ""

# 9. Check Elasticsearch Index Status
echo "=========================================="
echo "9. ELASTICSEARCH INDEX STATUS"
echo "=========================================="
echo ""

echo "Checking Elasticsearch indices..."
curl -s "http://localhost:9200/_cat/indices/*pim*,*product*?v&h=index,docs.count,store.size,health" 2>/dev/null | grep -v "^$"

echo ""

# 10. Summary and Recommendations
echo "=========================================="
echo "10. SUMMARY & RECOMMENDATIONS"
echo "=========================================="
echo ""

# Calculate statistics
TOTAL_PRODUCTS=$(php bin/console doctrine:query:sql "SELECT COUNT(*) FROM pim_catalog_product" 2>/dev/null | tail -1 | grep -oE '[0-9]+')
TOTAL_FAMILIES=$(php bin/console doctrine:query:sql "SELECT COUNT(*) FROM pim_catalog_family" 2>/dev/null | tail -1 | grep -oE '[0-9]+')
TOTAL_ATTRIBUTES=$(php bin/console doctrine:query:sql "SELECT COUNT(*) FROM pim_catalog_attribute" 2>/dev/null | tail -1 | grep -oE '[0-9]+')
TOTAL_CATEGORIES=$(php bin/console doctrine:query:sql "SELECT COUNT(*) FROM pim_catalog_category" 2>/dev/null | tail -1 | grep -oE '[0-9]+')

echo "📊 Catalog Statistics:"
echo "  - Total Products: $TOTAL_PRODUCTS"
echo "  - Total Families: $TOTAL_FAMILIES"
echo "  - Total Attributes: $TOTAL_ATTRIBUTES"
echo "  - Total Categories: $TOTAL_CATEGORIES"
echo ""

echo "💡 Enhancement Recommendations:"
echo ""
echo "1. COMPLETENESS:"
echo "   - Review products with low completeness scores"
echo "   - Ensure all required attributes are filled"
echo "   - Add missing product images and descriptions"
echo ""
echo "2. DATA QUALITY:"
echo "   - Enable Data Quality Insights for all products"
echo "   - Set up quality gates for product publishing"
echo "   - Regular data validation audits"
echo ""
echo "3. ENRICHMENT:"
echo "   - Standardize product descriptions"
echo "   - Add missing attribute values"
echo "   - Improve product media assets"
echo ""
echo "4. ORGANIZATION:"
echo "   - Review and optimize category structure"
echo "   - Consolidate similar families"
echo "   - Archive unused attributes"
echo ""
echo "5. PERFORMANCE:"
echo "   - Reindex Elasticsearch regularly"
echo "   - Optimize product queries"
echo "   - Enable caching where applicable"
echo ""

echo "=========================================="
echo "Analysis completed at: $(date)"
echo "=========================================="
