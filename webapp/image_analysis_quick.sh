#!/bin/bash
#
# Akeneo Image Import - Quick Analysis
# Fast analysis of Magento images and Akeneo products
#

set -e

echo "========================================="
echo "Akeneo Image Import - Quick Analysis"
echo "========================================="
echo ""

MAGENTO_IMG_PATH="/home/technadminy7/public_html/pub/media/catalog/product"
AKENEO_STORAGE="/home/pim/public_html/var/file_storage/catalog"

# Database connection
DB_HOST="127.0.0.1"
DB_PORT="3307"
DB_USER="akeneo_pim"
DB_PASS="akeneo_pim"
DB_NAME="akeneo_pim"

MYSQL_CMD="mysql -h $DB_HOST -P $DB_PORT -u $DB_USER -p'$DB_PASS' --skip-ssl $DB_NAME"

echo "📊 STEP 1: Magento Images"
echo "-------------------------------------------"
echo "Counting images (this may take a minute)..."
IMAGE_COUNT=$(find $MAGENTO_IMG_PATH -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" \) 2>/dev/null | wc -l)
echo "Total images found: $(printf "%'d" $IMAGE_COUNT)"

echo ""
echo "Sample images:"
find $MAGENTO_IMG_PATH -type f -name "*.jpg" 2>/dev/null | head -3

echo ""
echo "📊 STEP 2: Akeneo Products"
echo "-------------------------------------------"
TOTAL_PRODUCTS=$($MYSQL_CMD -e "SELECT COUNT(*) FROM pim_catalog_product;" 2>&1 | grep -v "Deprecated" | tail -1)
echo "Total products: $(printf "%'d" $TOTAL_PRODUCTS)"

echo ""
echo "📊 STEP 3: Current Image Status"
echo "-------------------------------------------"
PRODUCTS_WITH_IMG=$($MYSQL_CMD -e "
SELECT COUNT(*) 
FROM pim_catalog_product 
WHERE raw_values LIKE '%\"image\":%'
AND raw_values NOT LIKE '%\"image\":null%';
" 2>&1 | grep -v "Deprecated" | tail -1)

PRODUCTS_WITHOUT_IMG=$((TOTAL_PRODUCTS - PRODUCTS_WITH_IMG))

echo "Products with images: $(printf "%'d" $PRODUCTS_WITH_IMG)"
echo "Products without images: $(printf "%'d" $PRODUCTS_WITHOUT_IMG)"
echo "Image coverage: $(awk "BEGIN {printf \"%.1f\", ($PRODUCTS_WITH_IMG/$TOTAL_PRODUCTS)*100}")%"

echo ""
echo "📊 STEP 4: Storage Analysis"
echo "-------------------------------------------"
MAGENTO_SIZE=$(du -sh $MAGENTO_IMG_PATH 2>/dev/null | cut -f1)
AKENEO_SIZE=$(du -sh $AKENEO_STORAGE 2>/dev/null | cut -f1)

echo "Magento image storage: $MAGENTO_SIZE"
echo "Akeneo current storage: $AKENEO_SIZE"

echo ""
echo "📊 STEP 5: Sample SKU Matching"
echo "-------------------------------------------"
echo "Testing if we can match SKUs to images..."

# Get 3 sample SKUs
SAMPLE_SKUS=$($MYSQL_CMD -e "SELECT identifier FROM pim_catalog_product LIMIT 3;" 2>&1 | grep -v "Deprecated" | grep -v "identifier")

for SKU in $SAMPLE_SKUS; do
    # Try to find image for this SKU
    IMG_FOUND=$(find $MAGENTO_IMG_PATH -type f -name "*${SKU}*" 2>/dev/null | head -1)
    if [ -n "$IMG_FOUND" ]; then
        echo "✅ SKU $SKU: $(basename $IMG_FOUND)"
    else
        echo "❌ SKU $SKU: No image found"
    fi
done

echo ""
echo "📊 STEP 6: Recommendations"
echo "-------------------------------------------"

RATIO=$(awk "BEGIN {printf \"%.0f\", $IMAGE_COUNT/$TOTAL_PRODUCTS}")

echo "Image-to-Product Ratio: $RATIO:1"

if [ $RATIO -gt 20 ]; then
    echo ""
    echo "⚠️  WARNING: Very high image count!"
    echo "   Multiple images per product (thumbnails, variants, etc.)"
    echo ""
fi

echo "Recommended Strategy:"
echo "1. Import main product images first (not all variants)"
echo "2. Start with 100 products as test"
echo "3. Use pattern: find images containing SKU"
echo "4. Copy to Akeneo storage with proper structure"
echo "5. Update database with file paths"

echo ""
echo "📊 NEXT STEPS"
echo "-------------------------------------------"
echo "1. Create image mapping file (SKU -> image path)"
echo "2. Copy images to Akeneo storage"
echo "3. Update product records in database"
echo "4. Verify in Akeneo PIM"

echo ""
echo "========================================="
echo "Analysis Complete!"
echo "========================================="
echo ""
