#!/bin/bash
# COMPREHENSIVE CATALOG AUDIT SCRIPT
# Date: 2026-04-29
# Purpose: Analyze Akeneo catalog structure, metadata, images, and completeness

MYSQL="/opt/mariadb10.6/mariadb/bin/mysql"
DB_USER="root"
DB_PASS="YourNewStrongPassword"
DB_HOST="127.0.0.1"
DB_PORT="3307"
DB_NAME="akeneo_pim"
OUTPUT_DIR="/home/pim/public_html/webapp/catalog_audit_$(date +%Y%m%d_%H%M%S)"

mkdir -p "$OUTPUT_DIR"
REPORT="$OUTPUT_DIR/catalog_audit_report.txt"

# Helper function
query() {
    $MYSQL -u $DB_USER -p"$DB_PASS" -h $DB_HOST -P $DB_PORT $DB_NAME -e "$1" 2>/dev/null
}

echo "=====================================" > "$REPORT"
echo "AKENEO CATALOG COMPREHENSIVE AUDIT" >> "$REPORT"
echo "Date: $(date)" >> "$REPORT"
echo "=====================================" >> "$REPORT"
echo "" >> "$REPORT"

# 1. PRODUCT STATISTICS
echo "=== PRODUCT STATISTICS ===" >> "$REPORT"
query "SELECT COUNT(*) as total_products FROM pim_catalog_product;" >> "$REPORT"
query "SELECT COUNT(*) as enabled_products FROM pim_catalog_product WHERE is_enabled = 1;" >> "$REPORT"
query "SELECT 
    CASE WHEN is_enabled = 1 THEN 'Enabled' ELSE 'Disabled' END as status,
    COUNT(*) as count
FROM pim_catalog_product 
GROUP BY is_enabled;" >> "$REPORT"
echo "" >> "$REPORT"

# 2. PRODUCT MODELS
echo "=== PRODUCT MODELS ===" >> "$REPORT"
query "SELECT COUNT(*) as total_product_models FROM pim_catalog_product_model;" >> "$REPORT"
echo "" >> "$REPORT"

# 3. CATEGORIES
echo "=== CATEGORIES ===" >> "$REPORT"
query "SELECT COUNT(*) as total_categories FROM pim_catalog_category;" >> "$REPORT"
query "SELECT code, JSON_EXTRACT(labels, '$.en_US') as label, parent_id, root 
FROM pim_catalog_category 
ORDER BY parent_id, code 
LIMIT 50;" >> "$REPORT"
echo "" >> "$REPORT"

# 4. ATTRIBUTES
echo "=== ATTRIBUTES ===" >> "$REPORT"
query "SELECT COUNT(*) as total_attributes FROM pim_catalog_attribute;" >> "$REPORT"
query "SELECT 
    attribute_type,
    COUNT(*) as count
FROM pim_catalog_attribute 
GROUP BY attribute_type 
ORDER BY count DESC;" >> "$REPORT"
echo "" >> "$REPORT"

# 5. ATTRIBUTE GROUPS
echo "=== ATTRIBUTE GROUPS ===" >> "$REPORT"
query "SELECT COUNT(*) as total_attribute_groups FROM pim_catalog_attribute_group;" >> "$REPORT"
query "SELECT code, sort_order FROM pim_catalog_attribute_group ORDER BY sort_order;" >> "$REPORT"
echo "" >> "$REPORT"

# 6. FAMILIES
echo "=== FAMILIES ===" >> "$REPORT"
query "SELECT COUNT(*) as total_families FROM pim_catalog_family;" >> "$REPORT"
query "SELECT 
    f.code as family_code,
    COUNT(DISTINCT p.id) as product_count
FROM pim_catalog_family f
LEFT JOIN pim_catalog_product p ON p.family_id = f.id
GROUP BY f.code
ORDER BY product_count DESC
LIMIT 20;" >> "$REPORT"
echo "" >> "$REPORT"

# 7. LOCALES
echo "=== LOCALES ===" >> "$REPORT"
query "SELECT code, is_activated FROM pim_catalog_locale ORDER BY code;" >> "$REPORT"
echo "" >> "$REPORT"

# 8. CHANNELS
echo "=== CHANNELS ===" >> "$REPORT"
query "SELECT code, category_tree_id FROM pim_catalog_channel;" >> "$REPORT"
echo "" >> "$REPORT"

# 9. IMAGE ATTRIBUTES
echo "=== IMAGE ATTRIBUTES ===" >> "$REPORT"
query "SELECT 
    code,
    attribute_type,
    is_required,
    is_unique
FROM pim_catalog_attribute 
WHERE attribute_type IN ('pim_catalog_image', 'pim_catalog_file')
ORDER BY code;" >> "$REPORT"
echo "" >> "$REPORT"

# 10. PRODUCTS WITH/WITHOUT IMAGES
echo "=== PRODUCTS WITH IMAGES ===" >> "$REPORT"
query "SELECT 
    a.code as attribute_code,
    COUNT(DISTINCT v.entity_id) as products_with_value
FROM pim_catalog_attribute a
LEFT JOIN pim_catalog_product_unique_data v ON a.id = v.attribute_id
WHERE a.attribute_type = 'pim_catalog_image'
GROUP BY a.code
ORDER BY products_with_value DESC;" >> "$REPORT"
echo "" >> "$REPORT"

# 11. COMPLETENESS STATISTICS
echo "=== COMPLETENESS STATISTICS ===" >> "$REPORT"
query "SELECT 
    ROUND(AVG(ratio), 2) as avg_completeness,
    MIN(ratio) as min_completeness,
    MAX(ratio) as max_completeness,
    COUNT(*) as total_records
FROM pim_catalog_completeness;" >> "$REPORT"

query "SELECT 
    CASE 
        WHEN ratio = 100 THEN '100% Complete'
        WHEN ratio >= 75 THEN '75-99% Complete'
        WHEN ratio >= 50 THEN '50-74% Complete'
        WHEN ratio >= 25 THEN '25-49% Complete'
        ELSE '0-24% Complete'
    END as completeness_range,
    COUNT(*) as product_count
FROM pim_catalog_completeness
GROUP BY completeness_range
ORDER BY MIN(ratio) DESC;" >> "$REPORT"
echo "" >> "$REPORT"

# 12. MISSING REQUIRED ATTRIBUTES
echo "=== PRODUCTS MISSING REQUIRED ATTRIBUTES ===" >> "$REPORT"
query "SELECT 
    p.identifier,
    COUNT(DISTINCT mr.attribute_id) as missing_required_count
FROM pim_catalog_product p
JOIN pim_catalog_completeness c ON p.id = c.product_id
JOIN pim_catalog_family_attribute fa ON p.family_id = fa.family_id
JOIN pim_catalog_attribute a ON fa.attribute_id = a.id
LEFT JOIN pim_catalog_completeness_missing_required mr ON p.id = mr.product_id
WHERE a.is_required = 1
GROUP BY p.id, p.identifier
HAVING missing_required_count > 0
ORDER BY missing_required_count DESC
LIMIT 20;" >> "$REPORT"
echo "" >> "$REPORT"

# 13. SEO METADATA ATTRIBUTES
echo "=== SEO METADATA ATTRIBUTES ===" >> "$REPORT"
query "SELECT code, attribute_type, is_localizable, is_scopable
FROM pim_catalog_attribute 
WHERE code LIKE '%meta%' OR code LIKE '%seo%' OR code LIKE '%description%'
ORDER BY code;" >> "$REPORT"
echo "" >> "$REPORT"

# 14. EXPORT SAMPLE PRODUCTS
echo "=== SAMPLE PRODUCTS (First 10) ===" >> "$REPORT"
query "SELECT 
    p.identifier,
    f.code as family,
    p.is_enabled,
    p.created,
    p.updated
FROM pim_catalog_product p
LEFT JOIN pim_catalog_family f ON p.family_id = f.id
ORDER BY p.created DESC
LIMIT 10;" >> "$REPORT"
echo "" >> "$REPORT"

echo "Audit complete! Report saved to: $REPORT"
cat "$REPORT"
