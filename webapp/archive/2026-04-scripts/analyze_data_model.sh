#!/bin/bash

echo "================================================================"
echo "   AKENEO PIM DATA MODEL ENHANCEMENT"
echo "================================================================"
echo "Date: $(date)"
echo ""

BASE_DIR="/home/pim/public_html"
cd "$BASE_DIR"

# 1. Create Enhanced Attribute Groups
echo "================================================================"
echo "1. ATTRIBUTE GROUP OPTIMIZATION"
echo "================================================================"
echo ""

echo "Current attribute groups:"
php bin/console doctrine:query:sql "
SELECT code, sort_order, label 
FROM pim_catalog_attribute_group 
ORDER BY sort_order
" 2>/dev/null

echo ""
echo "Recommendations:"
echo "  - Organize attributes into logical groups"
echo "  - Use consistent naming conventions"
echo "  - Set appropriate sort orders for UI"
echo ""

# 2. Analyze Attribute Types
echo "================================================================"
echo "2. ATTRIBUTE TYPE ANALYSIS"
echo "================================================================"
echo ""

echo "Attribute distribution by type:"
php bin/console doctrine:query:sql "
SELECT 
    attribute_type,
    COUNT(*) as count,
    SUM(is_required) as required_count,
    SUM(is_unique) as unique_count,
    SUM(is_localizable) as localizable_count,
    SUM(is_scopable) as scopable_count
FROM pim_catalog_attribute
GROUP BY attribute_type
ORDER BY count DESC
" 2>/dev/null

echo ""

# 3. Review Family Structure
echo "================================================================"
echo "3. FAMILY STRUCTURE ANALYSIS"
echo "================================================================"
echo ""

echo "Families with attribute counts:"
php bin/console doctrine:query:sql "
SELECT 
    f.code,
    f.label,
    COUNT(DISTINCT fa.attribute_id) as attribute_count,
    COUNT(DISTINCT far.attribute_id) as required_attributes,
    COUNT(DISTINCT p.id) as product_count
FROM pim_catalog_family f
LEFT JOIN pim_catalog_family_attribute fa ON f.id = fa.family_id
LEFT JOIN pim_catalog_family_attribute_requirement far ON f.id = far.family_id
LEFT JOIN pim_catalog_product p ON f.id = p.family_id
GROUP BY f.id, f.code, f.label
ORDER BY product_count DESC
LIMIT 15
" 2>/dev/null

echo ""

# 4. Check Reference Data
echo "================================================================"
echo "4. REFERENCE DATA CONFIGURATION"
echo "================================================================"
echo ""

echo "Reference data entities:"
php bin/console doctrine:query:sql "
SELECT 
    a.code,
    a.attribute_type,
    a.reference_data_name
FROM pim_catalog_attribute a
WHERE a.attribute_type LIKE '%reference_data%'
" 2>/dev/null

echo ""

# 5. Analyze Asset Collections
echo "================================================================"
echo "5. ASSET COLLECTION ANALYSIS"
echo "================================================================"
echo ""

echo "Checking for asset attributes:"
php bin/console doctrine:query:sql "
SELECT 
    code,
    attribute_type,
    max_file_size,
    allowed_extensions
FROM pim_catalog_attribute
WHERE attribute_type IN ('pim_catalog_image', 'pim_catalog_file', 'pim_assets_collection')
" 2>/dev/null

echo ""

# 6. Category Tree Structure
echo "================================================================"
echo "6. CATEGORY TREE OPTIMIZATION"
echo "================================================================"
echo ""

echo "Category tree depth and breadth:"
php bin/console doctrine:query:sql "
SELECT 
    c.code,
    c.label,
    c.level,
    COUNT(DISTINCT child.id) as child_categories,
    COUNT(DISTINCT pc.product_id) as direct_products
FROM pim_catalog_category c
LEFT JOIN pim_catalog_category child ON c.id = child.parent_id
LEFT JOIN pim_catalog_category_product pc ON c.id = pc.category_id
GROUP BY c.id, c.code, c.label, c.level
HAVING c.level <= 2
ORDER BY c.level, direct_products DESC
LIMIT 20
" 2>/dev/null

echo ""

# 7. Product Association Types
echo "================================================================"
echo "7. PRODUCT ASSOCIATION CONFIGURATION"
echo "================================================================"
echo ""

echo "Association types usage:"
php bin/console doctrine:query:sql "
SELECT 
    at.code,
    at.label,
    at.is_two_way_association,
    COUNT(DISTINCT pa.owner_id) as usage_count
FROM pim_catalog_association_type at
LEFT JOIN pim_catalog_association pa ON at.id = pa.association_type_id
GROUP BY at.id, at.code, at.label, at.is_two_way_association
ORDER BY usage_count DESC
" 2>/dev/null

echo ""

# 8. Variant Configuration
echo "================================================================"
echo "8. PRODUCT VARIANT ANALYSIS"
echo "================================================================"
echo ""

echo "Family variants and axis:"
php bin/console doctrine:query:sql "
SELECT 
    fv.code as variant_code,
    f.code as family_code,
    COUNT(DISTINCT pm.id) as model_count,
    COUNT(DISTINCT vsa.attribute_id) as variant_axes_count
FROM pim_catalog_family_variant fv
JOIN pim_catalog_family f ON fv.family_id = f.id
LEFT JOIN pim_catalog_product_model pm ON fv.id = pm.family_variant_id
LEFT JOIN pim_catalog_family_variant_set_attribute vsa ON fv.id = vsa.family_variant_id
GROUP BY fv.id, fv.code, f.code
ORDER BY model_count DESC
" 2>/dev/null

echo ""

# 9. Measurement Families
echo "================================================================"
echo "9. MEASUREMENT & UNIT CONFIGURATION"
echo "================================================================"
echo ""

echo "Measurement attributes:"
php bin/console doctrine:query:sql "
SELECT 
    code,
    metric_family,
    default_metric_unit,
    decimals_allowed,
    negative_allowed
FROM pim_catalog_attribute
WHERE attribute_type = 'pim_catalog_metric'
" 2>/dev/null

echo ""

# 10. Channel Configuration
echo "================================================================"
echo "10. CHANNEL & LOCALE SETUP"
echo "================================================================"
echo ""

echo "Channels with currencies and locales:"
php bin/console doctrine:query:sql "
SELECT 
    ch.code as channel_code,
    ch.label,
    GROUP_CONCAT(DISTINCT cu.code) as currencies,
    GROUP_CONCAT(DISTINCT l.code) as locales
FROM pim_catalog_channel ch
LEFT JOIN pim_catalog_channel_currency chcu ON ch.id = chcu.channel_id
LEFT JOIN pim_catalog_currency cu ON chcu.currency_id = cu.id
LEFT JOIN pim_catalog_channel_locale chl ON ch.id = chl.channel_id
LEFT JOIN pim_catalog_locale l ON chl.locale_id = l.id
GROUP BY ch.id, ch.code, ch.label
" 2>/dev/null

echo ""

# 11. Generate Enhancement Recommendations
echo "================================================================"
echo "11. DATA MODEL ENHANCEMENT RECOMMENDATIONS"
echo "================================================================"
echo ""

# Get statistics
TOTAL_ATTRS=$(php bin/console doctrine:query:sql "SELECT COUNT(*) FROM pim_catalog_attribute" 2>/dev/null | tail -1 | grep -oE '[0-9]+')
REQUIRED_ATTRS=$(php bin/console doctrine:query:sql "SELECT COUNT(*) FROM pim_catalog_attribute WHERE is_required = 1" 2>/dev/null | tail -1 | grep -oE '[0-9]+')
LOCALIZABLE_ATTRS=$(php bin/console doctrine:query:sql "SELECT COUNT(*) FROM pim_catalog_attribute WHERE is_localizable = 1" 2>/dev/null | tail -1 | grep -oE '[0-9]+')
SCOPABLE_ATTRS=$(php bin/console doctrine:query:sql "SELECT COUNT(*) FROM pim_catalog_attribute WHERE is_scopable = 1" 2>/dev/null | tail -1 | grep -oE '[0-9]+')

echo "📊 Data Model Statistics:"
echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  📝 Total Attributes:        $TOTAL_ATTRS"
echo "  ⚠️  Required Attributes:     $REQUIRED_ATTRS"
echo "  🌐 Localizable Attributes:  $LOCALIZABLE_ATTRS"
echo "  🎯 Scopable Attributes:     $SCOPABLE_ATTRS"
echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "💡 Enhancement Recommendations:"
echo ""
echo "1. ATTRIBUTE ORGANIZATION:"
echo "   ✓ Review attribute groups and organize logically"
echo "   ✓ Ensure consistent naming conventions"
echo "   ✓ Archive unused or duplicate attributes"
echo ""
echo "2. FAMILY STRUCTURE:"
echo "   ✓ Consolidate similar families where appropriate"
echo "   ✓ Review required attributes per family"
echo "   ✓ Optimize attribute requirements for completeness"
echo ""
echo "3. CATEGORY STRUCTURE:"
echo "   ✓ Review category tree depth (recommend max 4 levels)"
echo "   ✓ Ensure balanced product distribution"
echo "   ✓ Clean up empty or redundant categories"
echo ""
echo "4. VARIANTS & MODELS:"
echo "   ✓ Validate family variant configurations"
echo "   ✓ Ensure proper variant axis setup"
echo "   ✓ Review product model inheritance"
echo ""
echo "5. REFERENCE DATA:"
echo "   ✓ Populate reference data entities"
echo "   ✓ Maintain data consistency"
echo "   ✓ Enable translations where needed"
echo ""
echo "6. ASSETS & MEDIA:"
echo "   ✓ Configure asset collections properly"
echo "   ✓ Set appropriate file size limits"
echo "   ✓ Validate media transformations"
echo ""
echo "7. LOCALIZATION:"
echo "   ✓ Enable appropriate locales for markets"
echo "   ✓ Configure channel-locale relationships"
echo "   ✓ Ensure attribute translations complete"
echo ""
echo "8. ASSOCIATIONS:"
echo "   ✓ Define relevant product associations"
echo "   ✓ Use two-way associations where appropriate"
echo "   ✓ Populate cross-sell/upsell relationships"
echo ""

echo "================================================================"
echo "Data model analysis completed at: $(date)"
echo "================================================================"
