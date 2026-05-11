#!/bin/bash

echo "========================================"
echo "MAGENTO IMAGE MAPPING EXTRACTION"
echo "========================================"
echo ""

# Magento database credentials
DB_NAME="technadminy7_dBT8x12y22"
DB_HOST="127.0.0.1"
DB_PORT="3307"
DB_USER="root"
DB_PASS="YourNewStrongPassword"

# MySQL command
MYSQL_CMD="/opt/mariadb10.6/mariadb/bin/mysql -u $DB_USER -p'$DB_PASS' -h $DB_HOST -P $DB_PORT $DB_NAME"

echo "1. Analyzing Magento Product-Image Structure..."
echo ""

# Get Magento product count
echo "Total Products in Magento:"
$MYSQL_CMD -e "SELECT COUNT(*) as total FROM catalog_product_entity;" 2>/dev/null

echo ""
echo "2. Product-Image Relationships:"
$MYSQL_CMD -e "
SELECT 
    COUNT(DISTINCT cpe.sku) as products_with_images
FROM catalog_product_entity cpe
INNER JOIN catalog_product_entity_media_gallery_value_to_entity mgve ON cpe.entity_id = mgve.entity_id
;" 2>/dev/null

echo ""
echo "3. Sample Product-Image Mappings (First 20):"
$MYSQL_CMD -e "
SELECT 
    cpe.sku,
    cpe.entity_id,
    mg.value as image_path,
    mg.media_type
FROM catalog_product_entity cpe
INNER JOIN catalog_product_entity_media_gallery_value_to_entity mgve ON cpe.entity_id = mgve.entity_id
INNER JOIN catalog_product_entity_media_gallery mg ON mgve.value_id = mg.value_id
WHERE mg.media_type = 'image'
ORDER BY cpe.sku
LIMIT 20;
" 2>/dev/null

echo ""
echo "4. Extracting Full Product-Image Mapping to CSV..."

# Export to CSV
OUTPUT_FILE="/home/pim/public_html/webapp/magento_image_mapping.csv"

$MYSQL_CMD -e "
SELECT 
    cpe.sku as 'Product SKU',
    mg.value as 'Image Path',
    SUBSTRING_INDEX(mg.value, '/', -1) as 'Image Filename',
    cpevarchar.value as 'Product Name'
FROM catalog_product_entity cpe
INNER JOIN catalog_product_entity_media_gallery_value_to_entity mgve ON cpe.entity_id = mgve.entity_id
INNER JOIN catalog_product_entity_media_gallery mg ON mgve.value_id = mg.value_id
LEFT JOIN catalog_product_entity_varchar cpevarchar ON cpe.entity_id = cpevarchar.entity_id 
    AND cpevarchar.attribute_id = (SELECT attribute_id FROM eav_attribute WHERE attribute_code = 'name' AND entity_type_id = 4)
    AND cpevarchar.store_id = 0
WHERE mg.media_type = 'image'
ORDER BY cpe.sku;
" 2>/dev/null > "$OUTPUT_FILE"

if [ -f "$OUTPUT_FILE" ]; then
    LINES=$(wc -l < "$OUTPUT_FILE")
    echo "✓ Exported $LINES product-image mappings to:"
    echo "  $OUTPUT_FILE"
    echo ""
    echo "Sample entries:"
    head -5 "$OUTPUT_FILE"
else
    echo "✗ Export failed"
fi

echo ""
echo "5. Image File Type Analysis:"
$MYSQL_CMD -e "
SELECT 
    SUBSTRING_INDEX(mg.value, '.', -1) as file_extension,
    COUNT(*) as count
FROM catalog_product_entity_media_gallery mg
WHERE mg.media_type = 'image'
GROUP BY file_extension
ORDER BY count DESC;
" 2>/dev/null

echo ""
echo "========================================" 
echo "NEXT STEPS"
echo "========================================"
echo ""
echo "1. Review the exported CSV:"
echo "   cat $OUTPUT_FILE | head -20"
echo ""
echo "2. Create Akeneo import mapping:"
echo "   php webapp/create_akeneo_image_import.php"
echo ""
echo "3. Import images to Akeneo:"
echo "   php bin/console akeneo:batch:publish-job-to-queue csv_product_import"
echo ""
echo "✓ Analysis complete!"
