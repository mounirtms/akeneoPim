#!/bin/bash

# Akeneo Image Import - Optimized Version
# Uses faster search strategy with indexed file list

set -e

echo "============================================"
echo "AKENEO IMAGE IMPORT - OPTIMIZED"
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
BATCH_SIZE="${1:-100}"  # Default 100, can pass different number
LOG_FILE="/home/pim/public_html/webapp/image_import_$(date +%Y%m%d_%H%M%S).log"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting optimized image import..." | tee "$LOG_FILE"
echo "Batch size: $BATCH_SIZE products" | tee -a "$LOG_FILE"
echo ""

# Step 1: Create image index (much faster than repeated finds)
echo "Step 1: Creating image index (this may take 2-3 minutes)..." | tee -a "$LOG_FILE"
IMAGE_INDEX="/tmp/image_index_$$.txt"
find "$MAGENTO_IMAGES" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" \) \
    ! -path "*/cache/*" ! -name "*thumb*" ! -name "*small*" \
    2>/dev/null > "$IMAGE_INDEX"

IMAGE_COUNT=$(wc -l < "$IMAGE_INDEX")
echo "✓ Indexed $IMAGE_COUNT images" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Step 2: Get products
echo "Step 2: Getting $BATCH_SIZE sample products..." | tee -a "$LOG_FILE"
mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" --skip-ssl "$DB_NAME" \
  -sN -e "SELECT identifier FROM pim_catalog_product LIMIT $BATCH_SIZE" \
  > /tmp/sample_skus_$$.txt 2>>"$LOG_FILE"

PRODUCT_COUNT=$(wc -l < /tmp/sample_skus_$$.txt)
echo "✓ Retrieved $PRODUCT_COUNT products" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Step 3: Match products to images using index
echo "Step 3: Matching products to images..." | tee -a "$LOG_FILE"
> /tmp/image_mapping_$$.csv
FOUND_COUNT=0
MISSING_COUNT=0

while IFS= read -r sku; do
    # Search in pre-built index
    IMAGE_PATH=$(grep -m1 "/${sku}\\.\\|/${sku}-optimized\\|/${sku}_" "$IMAGE_INDEX" 2>/dev/null || echo "")
    
    if [ -n "$IMAGE_PATH" ] && [ -f "$IMAGE_PATH" ]; then
        echo "$sku,$IMAGE_PATH" >> /tmp/image_mapping_$$.csv
        ((FOUND_COUNT++))
    else
        ((MISSING_COUNT++))
    fi
    
    # Progress every 10 products
    if [ $(( (FOUND_COUNT + MISSING_COUNT) % 10 )) -eq 0 ] || [ $((FOUND_COUNT + MISSING_COUNT)) -eq $PRODUCT_COUNT ]; then
        echo -ne "\rProgress: $((FOUND_COUNT + MISSING_COUNT))/$PRODUCT_COUNT | Found: $FOUND_COUNT | Missing: $MISSING_COUNT"
    fi
done < /tmp/sample_skus_$$.txt

echo "" | tee -a "$LOG_FILE"
echo "✓ Matching complete" | tee -a "$LOG_FILE"
echo "  - Images found: $FOUND_COUNT" | tee -a "$LOG_FILE"
echo "  - Images missing: $MISSING_COUNT" | tee -a "$LOG_FILE"
echo "  - Success rate: $(awk "BEGIN {printf \"%.1f\", ($FOUND_COUNT/$PRODUCT_COUNT)*100}")%" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Step 4: Copy images and update database
if [ $FOUND_COUNT -gt 0 ]; then
    echo "Step 4: Copying images and updating database..." | tee -a "$LOG_FILE"
    COPIED_COUNT=0
    
    while IFS=, read -r sku image_path; do
        if [ -f "$image_path" ]; then
            # Generate storage path
            FILENAME=$(basename "$image_path")
            HASH=$(echo -n "${sku}-${FILENAME}" | md5sum | cut -d' ' -f1)
            FIRST="${HASH:0:1}"
            SECOND="${HASH:1:1}"
            STORAGE_KEY="$FIRST/$SECOND/$HASH/$FILENAME"
            TARGET_DIR="$AKENEO_STORAGE/$FIRST/$SECOND/$HASH"
            
            # Create directory and copy
            mkdir -p "$TARGET_DIR" 2>>"$LOG_FILE"
            if cp "$image_path" "$TARGET_DIR/$FILENAME" 2>>"$LOG_FILE"; then
                # Get file info
                SIZE=$(stat -c%s "$image_path")
                MIME=$(file -b --mime-type "$image_path")
                EXT="${FILENAME##*.}"
                
                # Insert file info (ignore duplicates)
                mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" --skip-ssl "$DB_NAME" <<SQL 2>>"$LOG_FILE"
INSERT IGNORE INTO akeneo_file_storage_file_info (file_key, original_filename, mime_type, size, extension, hash)
VALUES ('$STORAGE_KEY', '$FILENAME', '$MIME', $SIZE, '$EXT', '$HASH');
SQL
                
                # Update product
                mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" --skip-ssl "$DB_NAME" <<SQL 2>>"$LOG_FILE"
UPDATE pim_catalog_product 
SET raw_values = JSON_SET(
    COALESCE(raw_values, '{}'),
    '$.image[0]',
    JSON_OBJECT('locale', NULL, 'scope', NULL, 'data', '$STORAGE_KEY')
)
WHERE identifier = '$sku';
SQL
                
                ((COPIED_COUNT++))
                echo -ne "\rCopied and linked: $COPIED_COUNT/$FOUND_COUNT"
            fi
        fi
    done < /tmp/image_mapping_$$.csv
    
    echo "" | tee -a "$LOG_FILE"
    echo "✓ Import complete" | tee -a "$LOG_FILE"
    echo "  - Successfully imported: $COPIED_COUNT images" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    
    # Set permissions
    chown -R pim:pim "$AKENEO_STORAGE" 2>>"$LOG_FILE"
    chmod -R 755 "$AKENEO_STORAGE" 2>>"$LOG_FILE"
fi

# Cleanup
rm -f "$IMAGE_INDEX" /tmp/sample_skus_$$.txt /tmp/image_mapping_$$.csv

# Summary
echo "============================================" | tee -a "$LOG_FILE"
echo "IMPORT SUMMARY" | tee -a "$LOG_FILE"
echo "============================================" | tee -a "$LOG_FILE"
echo "Products processed: $PRODUCT_COUNT" | tee -a "$LOG_FILE"
echo "Images found: $FOUND_COUNT" | tee -a "$LOG_FILE"
echo "Images imported: $COPIED_COUNT" | tee -a "$LOG_FILE"
echo "Success rate: $(awk "BEGIN {printf \"%.1f\", ($COPIED_COUNT/$PRODUCT_COUNT)*100}")%" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
echo "Log: $LOG_FILE" | tee -a "$LOG_FILE"
echo "============================================" | tee -a "$LOG_FILE"

# Verify
echo "" | tee -a "$LOG_FILE"
echo "Verification - Products with images:" | tee -a "$LOG_FILE"
PRODUCTS_WITH_IMAGES=$(mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" --skip-ssl "$DB_NAME" \
  -sN -e "SELECT COUNT(*) FROM pim_catalog_product WHERE JSON_EXTRACT(raw_values, '$.image[0].data') IS NOT NULL" 2>>"$LOG_FILE")
echo "Total products with images in database: $PRODUCTS_WITH_IMAGES" | tee -a "$LOG_FILE"

echo "" | tee -a "$LOG_FILE"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Import complete!" | tee -a "$LOG_FILE"
echo ""
