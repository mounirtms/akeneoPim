#!/bin/bash

echo "================================================================"
echo "   AKENEO PIM DATA QUALITY & LOCALE ANALYSIS"
echo "================================================================"
echo "Date: $(date)"
echo ""

BASE_DIR="/home/pim/public_html"
cd "$BASE_DIR"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${GREEN}✅${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠️${NC}  $1"; }
print_error() { echo -e "${RED}❌${NC} $1"; }
print_info() { echo -e "${BLUE}ℹ️${NC}  $1"; }
print_section() { echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n$1\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"; }

# 1. LOCALE CONFIGURATION ANALYSIS
print_section "1. LOCALE CONFIGURATION"

print_info "Checking active locales..."
php bin/console doctrine:query:sql "
SELECT 
    code,
    name,
    is_activated
FROM pim_catalog_locale
ORDER BY is_activated DESC, code
" 2>/dev/null

echo ""
print_info "Locale statistics:"
ACTIVE_LOCALES=$(php bin/console doctrine:query:sql "SELECT COUNT(*) FROM pim_catalog_locale WHERE is_activated = 1" 2>/dev/null | grep -oE '[0-9]+')
TOTAL_LOCALES=$(php bin/console doctrine:query:sql "SELECT COUNT(*) FROM pim_catalog_locale" 2>/dev/null | grep -oE '[0-9]+')
echo "  Active locales: $ACTIVE_LOCALES"
echo "  Total locales: $TOTAL_LOCALES"

# 2. CHANNEL CONFIGURATION
print_section "2. CHANNEL CONFIGURATION"

print_info "Checking channels and their locales..."
php bin/console doctrine:query:sql "
SELECT 
    c.code as channel_code,
    c.label as channel_label,
    GROUP_CONCAT(l.code) as locales
FROM pim_catalog_channel c
LEFT JOIN pim_catalog_channel_locale cl ON c.id = cl.channel_id
LEFT JOIN pim_catalog_locale l ON cl.locale_id = l.id
GROUP BY c.id, c.code, c.label
" 2>/dev/null

# 3. ATTRIBUTE LOCALIZATION
print_section "3. ATTRIBUTE LOCALIZATION"

print_info "Checking localizable attributes..."
php bin/console doctrine:query:sql "
SELECT 
    COUNT(*) as total_attributes,
    SUM(is_localizable) as localizable_attributes,
    SUM(is_scopable) as scopable_attributes,
    ROUND(SUM(is_localizable) * 100.0 / COUNT(*), 2) as localization_percentage
FROM pim_catalog_attribute
" 2>/dev/null | tail -5

print_info "Localizable attributes by type:"
php bin/console doctrine:query:sql "
SELECT 
    attribute_type,
    COUNT(*) as total,
    SUM(is_localizable) as localizable,
    SUM(is_scopable) as scopable
FROM pim_catalog_attribute
GROUP BY attribute_type
ORDER BY total DESC
LIMIT 15
" 2>/dev/null

# 4. PRODUCT DATA IN FRENCH
print_section "4. PRODUCT DATA LOCALIZATION"

print_info "Checking product values by locale..."
php bin/console doctrine:query:sql "
SELECT 
    l.code as locale,
    COUNT(DISTINCT pv.product_id) as products_with_values,
    COUNT(pv.id) as total_values
FROM pim_catalog_product_value pv
LEFT JOIN pim_catalog_locale l ON pv.locale_id = l.id
GROUP BY l.code
ORDER BY total_values DESC
" 2>/dev/null

# 5. FAMILY LOCALIZATION
print_section "5. FAMILY & ATTRIBUTE GROUP LABELS"

print_info "Checking family label translations..."
php bin/console doctrine:query:sql "
SELECT 
    f.code,
    COUNT(ft.id) as translations,
    GROUP_CONCAT(ft.locale SEPARATOR ', ') as available_locales
FROM pim_catalog_family f
LEFT JOIN pim_catalog_family_translation ft ON f.id = ft.foreign_key
GROUP BY f.id, f.code
ORDER BY translations DESC
LIMIT 10
" 2>/dev/null

# 6. CATEGORY LOCALIZATION
print_section "6. CATEGORY TRANSLATIONS"

print_info "Checking category translations..."
php bin/console doctrine:query:sql "
SELECT 
    c.code,
    c.level,
    COUNT(ct.id) as translations,
    GROUP_CONCAT(ct.locale SEPARATOR ', ') as available_locales
FROM pim_catalog_category c
LEFT JOIN pim_catalog_category_translation ct ON c.id = ct.foreign_key
WHERE c.level <= 2
GROUP BY c.id, c.code, c.level
ORDER BY c.level, translations DESC
LIMIT 15
" 2>/dev/null

# 7. ATTRIBUTE LABELS
print_section "7. ATTRIBUTE LABEL TRANSLATIONS"

print_info "Checking attribute translations..."
php bin/console doctrine:query:sql "
SELECT 
    a.code,
    a.attribute_type,
    a.is_localizable,
    COUNT(at.id) as label_translations
FROM pim_catalog_attribute a
LEFT JOIN pim_catalog_attribute_translation at ON a.id = at.foreign_key
GROUP BY a.id, a.code, a.attribute_type, a.is_localizable
HAVING label_translations < 2
ORDER BY label_translations ASC
LIMIT 20
" 2>/dev/null

# 8. COMPLETENESS BY LOCALE
print_section "8. COMPLETENESS ANALYSIS BY LOCALE"

print_info "Checking completeness scores by locale..."
php bin/console doctrine:query:sql "
SELECT 
    l.code as locale,
    ch.code as channel,
    ROUND(AVG(pc.ratio), 2) as avg_completeness,
    COUNT(DISTINCT pc.product_id) as products_evaluated
FROM pim_catalog_completeness pc
JOIN pim_catalog_locale l ON pc.locale_id = l.id
JOIN pim_catalog_channel ch ON pc.channel_id = ch.id
GROUP BY l.code, ch.code
ORDER BY avg_completeness DESC
" 2>/dev/null

# 9. MISSING TRANSLATIONS
print_section "9. MISSING TRANSLATIONS ANALYSIS"

print_info "Products without French descriptions:"
MISSING_FR_DESC=$(php bin/console doctrine:query:sql "
SELECT COUNT(DISTINCT p.id)
FROM pim_catalog_product p
WHERE NOT EXISTS (
    SELECT 1 FROM pim_catalog_product_value pv
    JOIN pim_catalog_attribute a ON pv.attribute_id = a.id
    JOIN pim_catalog_locale l ON pv.locale_id = l.id
    WHERE pv.product_id = p.id 
    AND a.code IN ('description', 'short_description', 'name')
    AND l.code = 'fr_FR'
    AND pv.text_value IS NOT NULL
    AND pv.text_value != ''
)
" 2>/dev/null | grep -oE '[0-9]+')
echo "  Products missing French descriptions: $MISSING_FR_DESC"

print_info "Products without images:"
MISSING_IMAGES=$(php bin/console doctrine:query:sql "
SELECT COUNT(DISTINCT p.id)
FROM pim_catalog_product p
WHERE NOT EXISTS (
    SELECT 1 FROM pim_catalog_product_value pv
    JOIN pim_catalog_attribute a ON pv.attribute_id = a.id
    WHERE pv.product_id = p.id 
    AND a.attribute_type = 'pim_catalog_image'
    AND pv.media_id IS NOT NULL
)
" 2>/dev/null | grep -oE '[0-9]+')
echo "  Products without images: $MISSING_IMAGES"

# 10. DATA QUALITY METRICS
print_section "10. DATA QUALITY METRICS"

TOTAL_PRODUCTS=$(php bin/console doctrine:query:sql "SELECT COUNT(*) FROM pim_catalog_product" 2>/dev/null | grep -oE '[0-9]+')
TOTAL_MODELS=$(php bin/console doctrine:query:sql "SELECT COUNT(*) FROM pim_catalog_product_model" 2>/dev/null | grep -oE '[0-9]+')
TOTAL_CATEGORIES=$(php bin/console doctrine:query:sql "SELECT COUNT(*) FROM pim_catalog_category" 2>/dev/null | grep -oE '[0-9]+')
TOTAL_ATTRIBUTES=$(php bin/console doctrine:query:sql "SELECT COUNT(*) FROM pim_catalog_attribute" 2>/dev/null | grep -oE '[0-9]+')
TOTAL_FAMILIES=$(php bin/console doctrine:query:sql "SELECT COUNT(*) FROM pim_catalog_family" 2>/dev/null | grep -oE '[0-9]+')

echo "📊 CATALOG STATISTICS:"
echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  📦 Total Products:        $TOTAL_PRODUCTS"
echo "  🔄 Product Models:        $TOTAL_MODELS"
echo "  📁 Categories:            $TOTAL_CATEGORIES"
echo "  📝 Attributes:            $TOTAL_ATTRIBUTES"
echo "  👨‍👩‍👧‍👦 Families:              $TOTAL_FAMILIES"
echo "  🌍 Active Locales:        $ACTIVE_LOCALES"
echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 11. RECOMMENDATIONS
print_section "11. DATA QUALITY RECOMMENDATIONS"

echo "💡 PRIORITY ACTIONS:"
echo ""
echo "1. LOCALE CONFIGURATION:"
echo "   ✓ Verify French (fr_FR) is primary locale"
echo "   ✓ Enable additional locales as needed (en_US, ar_DZ, etc.)"
echo "   ✓ Configure fallback locale hierarchy"
echo ""
echo "2. TRANSLATIONS:"
echo "   ⚠️  $MISSING_FR_DESC products missing French descriptions"
echo "   ✓ Translate attribute labels to French"
echo "   ✓ Translate category names to French"
echo "   ✓ Translate family labels to French"
echo ""
echo "3. MEDIA ASSETS:"
echo "   ⚠️  $MISSING_IMAGES products without images"
echo "   ✓ Upload product images"
echo "   ✓ Configure image transformations"
echo "   ✓ Set up asset management workflow"
echo ""
echo "4. COMPLETENESS:"
echo "   ✓ Review completeness requirements per family"
echo "   ✓ Fill required attributes for French locale"
echo "   ✓ Set up quality gates for publishing"
echo ""
echo "5. ATTRIBUTE MANAGEMENT:"
echo "   ✓ Mark important attributes as localizable"
echo "   ✓ Configure scopable attributes for channels"
echo "   ✓ Review and update attribute groups"
echo ""

# 12. FRENCH LOCALE VERIFICATION
print_section "12. FRENCH LOCALE VERIFICATION"

print_info "Checking if French is configured..."
FR_ACTIVE=$(php bin/console doctrine:query:sql "SELECT is_activated FROM pim_catalog_locale WHERE code = 'fr_FR'" 2>/dev/null | grep -oE '[0-9]+')
if [ "$FR_ACTIVE" = "1" ]; then
    print_status "French locale (fr_FR) is ACTIVE"
else
    print_error "French locale (fr_FR) is NOT ACTIVE"
fi

echo ""
print_info "Checking default locale in configuration..."
if grep -q "fr_FR" .env 2>/dev/null; then
    print_status "French found in .env configuration"
else
    print_warning "Check default locale setting in .env"
fi

# 13. EXPORT DETAILED REPORT
print_section "13. GENERATING DETAILED REPORT"

REPORT_FILE="/home/pim/public_html/webapp/data_quality_report_$(date +%Y%m%d_%H%M%S).txt"

cat > "$REPORT_FILE" << EOF
================================================================
AKENEO PIM DATA QUALITY & LOCALE ANALYSIS REPORT
================================================================
Generated: $(date)

CATALOG OVERVIEW
----------------
Total Products:        $TOTAL_PRODUCTS
Product Models:        $TOTAL_MODELS
Categories:            $TOTAL_CATEGORIES
Attributes:            $TOTAL_ATTRIBUTES
Families:              $TOTAL_FAMILIES
Active Locales:        $ACTIVE_LOCALES

LOCALE CONFIGURATION
--------------------
Primary Locale:        French (fr_FR)
Status:                $([ "$FR_ACTIVE" = "1" ] && echo "Active ✅" || echo "Inactive ⚠️")

DATA QUALITY ISSUES
-------------------
Missing French Descriptions:  $MISSING_FR_DESC products
Missing Product Images:       $MISSING_IMAGES products

RECOMMENDATIONS
---------------
1. Enable and configure French as primary locale
2. Translate all attribute labels to French
3. Translate category and family names to French
4. Fill missing product descriptions in French
5. Upload product images for $MISSING_IMAGES products
6. Configure completeness requirements for French locale
7. Set up localizable attributes for multilingual content
8. Implement data quality gates

NEXT STEPS
----------
1. Run locale configuration script
2. Enable required locales (fr_FR, en_US, ar_DZ if needed)
3. Translate metadata (attributes, families, categories)
4. Fill product data in French
5. Upload missing media assets
6. Calculate and monitor completeness

================================================================
Report saved to: $REPORT_FILE
================================================================
EOF

print_status "Detailed report generated: $REPORT_FILE"

echo ""
echo "================================================================"
echo "Analysis completed at: $(date)"
echo "================================================================"
