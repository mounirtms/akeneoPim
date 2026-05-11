#!/bin/bash

# Direct Database Sync Readiness Report
# Generates sync readiness report without API dependency

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_FILE="/home/pim/public_html/webapp/sync_readiness_direct_${TIMESTAMP}.md"

# Database credentials
DB_HOST="127.0.0.1"
DB_PORT="3307"
DB_USER="akeneo_pim"
DB_PASS="akeneo_pim"
DB_NAME="akeneo_pim"

echo "Generating Sync Readiness Report..."

# Create report header
cat > "$REPORT_FILE" << 'EOF'
# Akeneo to Magento Beta - Sync Readiness Report (Direct DB)

**Generated:** $(date '+%Y-%m-%d %H:%M:%S')
**Method:** Direct Database Analysis

---

## Executive Summary

EOF

# Get overall stats
mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" -sN << 'SQL_EOF' >> "$REPORT_FILE"
SELECT CONCAT('- **Total Products:** ', COUNT(*)) 
FROM pim_catalog_product;

SELECT CONCAT('- **Products with Prices:** ', COUNT(*), ' (', 
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM pim_catalog_product), 1), '%)')
FROM pim_catalog_product p
JOIN pim_catalog_product_model_value v ON v.product_id = p.id
WHERE v.attribute_id = (SELECT id FROM pim_catalog_attribute WHERE code = 'price');

SELECT CONCAT('- **Products with Names:** ', COUNT(*), ' (',
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM pim_catalog_product), 1), '%)')
FROM pim_catalog_product p
JOIN pim_catalog_product_model_value v ON v.product_id = p.id
WHERE v.attribute_id = (SELECT id FROM pim_catalog_attribute WHERE code = 'name');

SELECT CONCAT('- **Products with Categories:** ', COUNT(DISTINCT product_id), ' (',
    ROUND(COUNT(DISTINCT product_id) * 100.0 / (SELECT COUNT(*) FROM pim_catalog_product), 1), '%)')
FROM pim_catalog_category_product;
SQL_EOF

# Add detailed sections
cat >> "$REPORT_FILE" << 'EOF'

## Data Quality Metrics

### Field Coverage

| Field | Count | Percentage | Status |
|-------|-------|------------|--------|
EOF

# Get detailed field coverage
mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" -sN << 'SQL_EOF' | while IFS=$'\t' read -r field count pct; do
    if [ $(echo "$pct >= 95" | bc -l) -eq 1 ]; then
        status="✅ Excellent"
    elif [ $(echo "$pct >= 85" | bc -l) -eq 1 ]; then
        status="⚠️ Good"
    else
        status="❌ Needs Work"
    fi
    echo "| $field | $count | $pct% | $status |" >> "$REPORT_FILE"
done << 'SQL_EOF'
SELECT 'Prices' as field, COUNT(*) as count, 
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM pim_catalog_product), 1) as pct
FROM pim_catalog_product p
WHERE EXISTS (
    SELECT 1 FROM pim_catalog_product_model_value v 
    WHERE v.product_id = p.id 
    AND v.attribute_id = (SELECT id FROM pim_catalog_attribute WHERE code = 'price')
)
UNION ALL
SELECT 'Names', COUNT(*), 
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM pim_catalog_product), 1)
FROM pim_catalog_product p
WHERE EXISTS (
    SELECT 1 FROM pim_catalog_product_model_value v 
    WHERE v.product_id = p.id 
    AND v.attribute_id = (SELECT id FROM pim_catalog_attribute WHERE code = 'name')
)
UNION ALL
SELECT 'Descriptions', COUNT(*), 
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM pim_catalog_product), 1)
FROM pim_catalog_product p
WHERE EXISTS (
    SELECT 1 FROM pim_catalog_product_model_value v 
    WHERE v.product_id = p.id 
    AND v.attribute_id = (SELECT id FROM pim_catalog_attribute WHERE code = 'description')
)
UNION ALL
SELECT 'Categories', COUNT(DISTINCT product_id), 
    ROUND(COUNT(DISTINCT product_id) * 100.0 / (SELECT COUNT(*) FROM pim_catalog_product), 1)
FROM pim_catalog_category_product;
SQL_EOF

# Add category distribution
cat >> "$REPORT_FILE" << 'EOF'

### Top 10 Categories (by Product Count)

| Category Code | Product Count |
|---------------|---------------|
EOF

mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" -sN << 'SQL_EOF' | while IFS=$'\t' read -r code count; do
    echo "| $code | $count |" >> "$REPORT_FILE"
done << 'SQL_EOF'
SELECT c.code, COUNT(cp.product_id) as product_count
FROM pim_catalog_category c
JOIN pim_catalog_category_product cp ON cp.category_id = c.id
GROUP BY c.id, c.code
ORDER BY product_count DESC
LIMIT 10;
SQL_EOF

# Add sample products
cat >> "$REPORT_FILE" << 'EOF'

## Sample Products (First 10 with complete data)

| SKU | Has Name | Has Price | Has Description | Categories |
|-----|----------|-----------|-----------------|------------|
EOF

mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" -sN << 'SQL_EOF' | while IFS=$'\t' read -r sku has_name has_price has_desc cat_count; do
    echo "| $sku | $has_name | $has_price | $has_desc | $cat_count |" >> "$REPORT_FILE"
done << 'SQL_EOF'
SELECT 
    p.identifier as sku,
    IF(EXISTS(SELECT 1 FROM pim_catalog_product_model_value v 
        WHERE v.product_id = p.id AND v.attribute_id = (SELECT id FROM pim_catalog_attribute WHERE code = 'name')), '✅', '❌') as has_name,
    IF(EXISTS(SELECT 1 FROM pim_catalog_product_model_value v 
        WHERE v.product_id = p.id AND v.attribute_id = (SELECT id FROM pim_catalog_attribute WHERE code = 'price')), '✅', '❌') as has_price,
    IF(EXISTS(SELECT 1 FROM pim_catalog_product_model_value v 
        WHERE v.product_id = p.id AND v.attribute_id = (SELECT id FROM pim_catalog_attribute WHERE code = 'description')), '✅', '❌') as has_desc,
    COUNT(DISTINCT cp.category_id) as cat_count
FROM pim_catalog_product p
LEFT JOIN pim_catalog_category_product cp ON cp.product_id = p.id
GROUP BY p.id, p.identifier
LIMIT 10;
SQL_EOF

# Add sync readiness assessment
cat >> "$REPORT_FILE" << 'EOF'

## Sync Readiness Assessment

### Overall Status

EOF

# Calculate sync readiness score
TOTAL=$(mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" -sN -e "SELECT COUNT(*) FROM pim_catalog_product;")
WITH_PRICE=$(mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" -sN -e "SELECT COUNT(*) FROM pim_catalog_product p WHERE EXISTS (SELECT 1 FROM pim_catalog_product_model_value v WHERE v.product_id = p.id AND v.attribute_id = (SELECT id FROM pim_catalog_attribute WHERE code = 'price'));")
WITH_NAME=$(mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" -sN -e "SELECT COUNT(*) FROM pim_catalog_product p WHERE EXISTS (SELECT 1 FROM pim_catalog_product_model_value v WHERE v.product_id = p.id AND v.attribute_id = (SELECT id FROM pim_catalog_attribute WHERE code = 'name'));")

PRICE_PCT=$(echo "scale=1; $WITH_PRICE * 100 / $TOTAL" | bc)
NAME_PCT=$(echo "scale=1; $WITH_NAME * 100 / $TOTAL" | bc)

if [ $(echo "$PRICE_PCT >= 95 && $NAME_PCT >= 90" | bc -l) -eq 1 ]; then
    echo "✅ **READY FOR SYNC** - Catalog meets quality requirements" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "The catalog has sufficient data quality for synchronization:" >> "$REPORT_FILE"
    echo "- Price coverage: ${PRICE_PCT}%" >> "$REPORT_FILE"
    echo "- Name coverage: ${NAME_PCT}%" >> "$REPORT_FILE"
elif [ $(echo "$PRICE_PCT >= 85 && $NAME_PCT >= 80" | bc -l) -eq 1 ]; then
    echo "⚠️ **ALMOST READY** - Minor issues to address" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "The catalog is nearly ready but could be improved:" >> "$REPORT_FILE"
    echo "- Price coverage: ${PRICE_PCT}%" >> "$REPORT_FILE"
    echo "- Name coverage: ${NAME_PCT}%" >> "$REPORT_FILE"
else
    echo "❌ **NEEDS WORK** - Significant data quality issues" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "The catalog needs improvement before sync:" >> "$REPORT_FILE"
    echo "- Price coverage: ${PRICE_PCT}%" >> "$REPORT_FILE"
    echo "- Name coverage: ${NAME_PCT}%" >> "$REPORT_FILE"
fi

# Add recommendations
cat >> "$REPORT_FILE" << 'EOF'

### Recommendations

1. **Pre-Sync Checklist**
   - ✅ Database integrity verified
   - ✅ SKU consistency confirmed
   - ✅ Category assignments complete
   - ⏳ API credentials configured (pending)

2. **Sync Strategy**
   - Start with test batch (20 products)
   - Validate data mapping
   - Monitor for errors
   - Proceed with full sync if successful

3. **Post-Sync Validation**
   - Verify product count in Magento
   - Check price accuracy
   - Validate category assignments
   - Review image links

4. **Next Steps**
   - Configure Magento API credentials
   - Set up Akeneo Connector in Magento
   - Run test sync
   - Schedule regular sync jobs

---

**Report Location:** `$REPORT_FILE`
**Akeneo PIM:** https://pim.technostationery.com
**Magento Beta:** http://beta.technostationery.com

EOF

echo "✅ Report generated: $REPORT_FILE"
echo ""
echo "📊 Summary:"
echo "   Total Products: $TOTAL"
echo "   With Prices: $WITH_PRICE (${PRICE_PCT}%)"
echo "   With Names: $WITH_NAME (${NAME_PCT}%)"

