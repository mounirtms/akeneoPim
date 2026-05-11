#!/bin/bash

# Akeneo Image Import - Test Phase (100 Products)
# Date: April 23, 2026
# Purpose: Import main product images from Magento to Akeneo

set -e

echo "============================================"
echo "AKENEO IMAGE IMPORT - TEST PHASE"
echo "============================================"
echo ""

# Configuration
MAGENTO_IMAGES="/home/technadminy7/public_html/pub/media/catalog/product"
AKENEO_STORAGE="/home/pim/public_html/var/file_storage/catalog"
DB_HOST="127.0.0.1"
DB_PORT="3307"
DB_USER="akeneo_pim"
DB_PASS="akeneo_pim"
DB_NAME="akeneo_pim"
BATCH_SIZE=100
LOG_FILE="/home/pim/public_html/webapp/image_import_$(date +%Y%m%d_%H%M%S).log"

# Create temporary directory
TEMP_DIR="/tmp/akeneo_image_import_$$"
mkdir -p "$TEMP_DIR"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting image import test..." | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Step 1: Get sample products (100)
echo "Step 1: Getting $BATCH_SIZE sample products..." | tee -a "$LOG_FILE"
mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" --skip-ssl "$DB_NAME" \
  -sN -e "SELECT identifier FROM pim_catalog_product LIMIT $BATCH_SIZE" \
  > "$TEMP_DIR/sample_skus.txt" 2>>"$LOG_FILE"

PRODUCT_COUNT=$(wc -l < "$TEMP_DIR/sample_skus.txt")
echo "✓ Retrieved $PRODUCT_COUNT products" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Step 2: Find images for each SKU
echo "Step 2: Finding images for products..." | tee -a "$LOG_FILE"
> "$TEMP_DIR/image_mapping.csv"
FOUND_COUNT=0
MISSING_COUNT=0

while IFS= read -r sku; do
    # Try multiple image patterns
    IMAGE_PATH=""
    
    # Pattern 1: Direct match ${SKU}.jpg
    if [ -z "$IMAGE_PATH" ]; then
        FOUND=$(find "$MAGENTO_IMAGES" -type f -name "${sku}.jpg" 2>/dev/null | head -1)
        [ -n "$FOUND" ] && IMAGE_PATH="$FOUND"
    fi
    
    # Pattern 2: ${SKU}-optimized.jpg
    if [ -z "$IMAGE_PATH" ]; then
        FOUND=$(find "$MAGENTO_IMAGES" -type f -name "${sku}-optimized.jpg" 2>/dev/null | head -1)
        [ -n "$FOUND" ] && IMAGE_PATH="$FOUND"
    fi
    
    # Pattern 3: Any file containing SKU (excluding cache, thumb, small)
    if [ -z "$IMAGE_PATH" ]; then
        FOUND=$(find "$MAGENTO_IMAGES" -type f -name "*${sku}*.jpg" \
                ! -path "*/cache/*" ! -name "*thumb*" ! -name "*small*" 2>/dev/null | head -1)
        [ -n "$FOUND" ] && IMAGE_PATH="$FOUND"
    fi
    
    if [ -n "$IMAGE_PATH" ]; then
        echo "$sku,$IMAGE_PATH" >> "$TEMP_DIR/image_mapping.csv"
        ((FOUND_COUNT++))
    else
        echo "$sku,NOT_FOUND" >> "$TEMP_DIR/image_mapping.csv"
        ((MISSING_COUNT++))
    fi
    
    # Progress indicator
    if [ $((FOUND_COUNT + MISSING_COUNT)) -eq $PRODUCT_COUNT ] || [ $(( (FOUND_COUNT + MISSING_COUNT) % 10 )) -eq 0 ]; then
        echo -ne "\rProcessed: $((FOUND_COUNT + MISSING_COUNT))/$PRODUCT_COUNT | Found: $FOUND_COUNT | Missing: $MISSING_COUNT"
    fi
done < "$TEMP_DIR/sample_skus.txt"

echo "" | tee -a "$LOG_FILE"
echo "✓ Image mapping complete" | tee -a "$LOG_FILE"
echo "  - Images found: $FOUND_COUNT" | tee -a "$LOG_FILE"
echo "  - Images missing: $MISSING_COUNT" | tee -a "$LOG_FILE"
echo "  - Success rate: $(awk "BEGIN {printf \"%.1f\", ($FOUND_COUNT/$PRODUCT_COUNT)*100}")%" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Step 3: Copy images to Akeneo storage
echo "Step 3: Copying images to Akeneo storage..." | tee -a "$LOG_FILE"
COPIED_COUNT=0
ERROR_COUNT=0

while IFS=, read -r sku image_path; do
    if [ "$image_path" != "NOT_FOUND" ] && [ -f "$image_path" ]; then
        # Generate hash for Akeneo storage structure
        HASH=$(echo -n "$sku-$(basename "$image_path")" | md5sum | cut -d' ' -f1)
        
        # Create Akeneo directory structure (first character as subdirectory)
        FIRST_CHAR="${HASH:0:1}"
        SECOND_CHAR="${HASH:1:1}"
        TARGET_DIR="$AKENEO_STORAGE/$FIRST_CHAR/$SECOND_CHAR/$HASH"
        
        mkdir -p "$TARGET_DIR" 2>>"$LOG_FILE"
        
        # Copy image
        if cp "$image_path" "$TARGET_DIR/$(basename "$image_path")" 2>>"$LOG_FILE"; then
            # Store mapping for database update
            echo "$sku,$FIRST_CHAR/$SECOND_CHAR/$HASH/$(basename "$image_path"),$(stat -c%s "$image_path"),$(file -b --mime-type "$image_path")" \
                >> "$TEMP_DIR/db_mapping.csv"
            ((COPIED_COUNT++))
        else
            ((ERROR_COUNT++))
        fi
        
        # Progress
        if [ $((COPIED_COUNT + ERROR_COUNT)) -eq $FOUND_COUNT ] || [ $(( (COPIED_COUNT + ERROR_COUNT) % 10 )) -eq 0 ]; then
            echo -ne "\rCopied: $COPIED_COUNT/$FOUND_COUNT | Errors: $ERROR_COUNT"
        fi
    fi
done < "$TEMP_DIR/image_mapping.csv"

echo "" | tee -a "$LOG_FILE"
echo "✓ Image copy complete" | tee -a "$LOG_FILE"
echo "  - Successfully copied: $COPIED_COUNT" | tee -a "$LOG_FILE"
echo "  - Errors: $ERROR_COUNT" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Step 4: Update database
echo "Step 4: Updating database..." | tee -a "$LOG_FILE"

# First, insert into file storage table
DB_UPDATED=0
while IFS=, read -r sku file_key size mime_type; do
    EXTENSION="${file_key##*.}"
    HASH=$(echo -n "$file_key" | md5sum | cut -d' ' -f1)
    
    # Insert file info
    mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" --skip-ssl "$DB_NAME" <<SQL 2>>"$LOG_FILE"
INSERT INTO akeneo_file_storage_file_info (file_key, original_filename, mime_type, size, extension, hash)
VALUES ('$file_key', SUBSTRING_INDEX('$file_key', '/', -1), '$mime_type', $size, '$EXTENSION', '$HASH')
ON DUPLICATE KEY UPDATE file_key=file_key;
SQL
    
    # Update product raw_values with image reference
    mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" --skip-ssl "$DB_NAME" <<SQL 2>>"$LOG_FILE"
UPDATE pim_catalog_product 
SET raw_values = JSON_SET(
    COALESCE(raw_values, '{}'),
    '$.image[0]',
    JSON_OBJECT(
        'locale', NULL,
        'scope', NULL,
        'data', '$file_key'
    )
)
WHERE identifier = '$sku';
SQL
    
    ((DB_UPDATED++))
    
    # Progress
    echo -ne "\rDatabase updated: $DB_UPDATED/$COPIED_COUNT"
done < "$TEMP_DIR/db_mapping.csv"

echo "" | tee -a "$LOG_FILE"
echo "✓ Database update complete" | tee -a "$LOG_FILE"
echo "  - Products updated: $DB_UPDATED" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Step 5: Set permissions
echo "Step 5: Setting file permissions..." | tee -a "$LOG_FILE"
chown -R pim:pim "$AKENEO_STORAGE" 2>>"$LOG_FILE"
chmod -R 755 "$AKENEO_STORAGE" 2>>"$LOG_FILE"
echo "✓ Permissions set" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Cleanup
rm -rf "$TEMP_DIR"

# Summary
echo "============================================" | tee -a "$LOG_FILE"
echo "IMPORT SUMMARY" | tee -a "$LOG_FILE"
echo "============================================" | tee -a "$LOG_FILE"
echo "Total products: $PRODUCT_COUNT" | tee -a "$LOG_FILE"
echo "Images found: $FOUND_COUNT ($(awk "BEGIN {printf \"%.1f\", ($FOUND_COUNT/$PRODUCT_COUNT)*100}")%)" | tee -a "$LOG_FILE"
echo "Images copied: $COPIED_COUNT" | tee -a "$LOG_FILE"
echo "Database updated: $DB_UPDATED" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
echo "Status: ✓ Test import complete" | tee -a "$LOG_FILE"
echo "Log file: $LOG_FILE" | tee -a "$LOG_FILE"
echo "============================================" | tee -a "$LOG_FILE"

# Show sample products with images
echo "" | tee -a "$LOG_FILE"
echo "Sample products with images:" | tee -a "$LOG_FILE"
mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" --skip-ssl "$DB_NAME" \
  -e "SELECT identifier, 
      JSON_EXTRACT(raw_values, '$.image[0].data') as image_path 
      FROM pim_catalog_product 
      WHERE JSON_EXTRACT(raw_values, '$.image[0].data') IS NOT NULL 
      LIMIT 5;" 2>>"$LOG_FILE" | tee -a "$LOG_FILE"

echo "" | tee -a "$LOG_FILE"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Import test complete!" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
echo "Next steps:" | tee -a "$LOG_FILE"
echo "1. Verify images in Akeneo PIM UI" | tee -a "$LOG_FILE"
echo "2. If successful, run full import with: ./image_import_full.sh" | tee -a "$LOG_FILE"
echo "3. Clear cache: cd /home/pim/public_html && php bin/console cache:clear --env=prod" | tee -a "$LOG_FILE"
echo ""
