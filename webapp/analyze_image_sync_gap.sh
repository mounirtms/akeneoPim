#!/bin/bash
# Analyze Image Sync Gap and Create Import Strategy
# Critical: 11,561 files vs 99 DB records

echo "=========================================="
echo "IMAGE SYNC GAP ANALYSIS"
echo "=========================================="
echo "Date: $(date)"
echo ""

# 1. Analyze physical files
echo "=== 1. Physical File Analysis ==="
CATALOG_PATH="/home/pim/public_html/var/file_storage/catalog"
TOTAL_FILES=$(find "$CATALOG_PATH" -type f | wc -l)
echo "Total files in catalog: $TOTAL_FILES"

# Sample files to understand naming pattern
echo ""
echo "Sample file names (first 10):"
find "$CATALOG_PATH" -type f | head -10

# File extensions
echo ""
echo "File types distribution:"
find "$CATALOG_PATH" -type f | sed 's/.*\.//' | sort | uniq -c | sort -rn

# File sizes
echo ""
echo "Total storage size:"
du -sh "$CATALOG_PATH"
echo ""

# 2. Database records analysis
echo "=== 2. Database Records Analysis ==="
/opt/mariadb10.6/mariadb/bin/mysql -u root -p'YourNewStrongPassword' -h 127.0.0.1 -P 3307 akeneo_pim << 'SQL'
SELECT 
    'Total file records' as metric,
    COUNT(*) as count
FROM akeneo_file_storage_file_info
UNION ALL
SELECT 'Sample file keys', file_key
FROM akeneo_file_storage_file_info
LIMIT 5;

-- Check image attributes
SELECT 
    'Image attributes' as info,
    code,
    attribute_type
FROM pim_catalog_attribute
WHERE attribute_type = 'pim_catalog_image';

-- Check products with image values
SELECT 
    'Products with image data in raw_values' as info,
    COUNT(*) as count
FROM pim_catalog_product
WHERE raw_values LIKE '%image%';
SQL
echo ""

# 3. Identify the gap
echo "=== 3. Gap Analysis ==="
DB_RECORDS=$(/opt/mariadb10.6/mariadb/bin/mysql -u root -p'YourNewStrongPassword' -h 127.0.0.1 -P 3307 akeneo_pim -e "SELECT COUNT(*) FROM akeneo_file_storage_file_info;" 2>&1 | tail -1)
GAP=$((TOTAL_FILES - DB_RECORDS))
echo "Physical files: $TOTAL_FILES"
echo "Database records: $DB_RECORDS"
echo "Gap: $GAP files ($((GAP * 100 / TOTAL_FILES))% of total)"
echo ""

# 4. Magento image catalog check
echo "=== 4. Magento Image Catalog Check ==="
MAGENTO_PATH="/home/technadminy7/public_html/pub/media/catalog/product"
if [ -d "$MAGENTO_PATH" ]; then
    MAGENTO_IMAGES=$(find "$MAGENTO_PATH" -type f 2>/dev/null | wc -l)
    echo "Magento product images: $MAGENTO_IMAGES"
    echo "Magento storage size: $(du -sh $MAGENTO_PATH 2>/dev/null | awk '{print $1}')"
    
    # Sample Magento image names
    echo ""
    echo "Sample Magento images (first 10):"
    find "$MAGENTO_PATH" -type f | head -10
else
    echo "⚠ Magento image directory not found: $MAGENTO_PATH"
fi
echo ""

# 5. Recommendations
echo "=== 5. Import Strategy Recommendations ==="
echo ""
echo "CRITICAL FINDINGS:"
echo "1. Large sync gap: $GAP files not registered in Akeneo database"
echo "2. Files exist physically but are not linked to products"
echo "3. This prevents products from displaying images in Akeneo UI"
echo ""
echo "RECOMMENDED ACTIONS:"
echo ""
echo "Option A: Direct Database Import (Fastest)"
echo "  - Parse existing file_storage directory structure"
echo "  - Insert records into akeneo_file_storage_file_info"
echo "  - Update product raw_values with image references"
echo "  - Estimated time: 2-3 hours"
echo "  - Risk: Medium (requires careful validation)"
echo ""
echo "Option B: API Import via Akeneo Commands (Safest)"
echo "  - Use Akeneo import commands to process images"
echo "  - Create CSV mapping file: SKU, image_path"
echo "  - Run: php bin/console akeneo:batch:job"
echo "  - Estimated time: 6-8 hours"
echo "  - Risk: Low (uses official import mechanism)"
echo ""
echo "Option C: Hybrid Approach (Recommended)"
echo "  - Analyze existing patterns to create mapping"
echo "  - Import in batches of 1000 images"
echo "  - Validate after each batch"
echo "  - Estimated time: 4-5 hours"
echo "  - Risk: Low-Medium (controlled batches)"
echo ""

echo "=========================================="
echo "ANALYSIS COMPLETE"
echo "=========================================="
