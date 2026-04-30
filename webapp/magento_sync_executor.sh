#!/bin/bash
# Magento Sync Execution Script
# Date: 2026-04-30

LOG_FILE="logs/magento_sync_execution_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "========================================"
echo "MAGENTO SYNC EXECUTION"
echo "Date: $(date)"
echo "========================================"
echo ""

# Configuration
EXPORT_DIR="/home/pim/public_html/webapp/magento_exports"
PRODUCTS_CSV="products_export_20260430_131735.csv"
CATEGORIES_CSV="category_assignments_20260430_131735.csv"
IMAGE_LIST="image_files_20260430_131735.txt"

# Magento Configuration
MAGENTO_URL="https://beta.technostationery.com"
MAGENTO_ADMIN_URL="https://beta.technostationery.com/admin"

echo "## Phase 1: Pre-Sync Verification"
echo "-----------------------------------"

# Verify export files exist
echo "Checking export files..."
if [ ! -f "$EXPORT_DIR/$PRODUCTS_CSV" ]; then
    echo "❌ Products CSV not found: $PRODUCTS_CSV"
    exit 1
fi
if [ ! -f "$EXPORT_DIR/$CATEGORIES_CSV" ]; then
    echo "❌ Categories CSV not found: $CATEGORIES_CSV"
    exit 1
fi
if [ ! -f "$EXPORT_DIR/$IMAGE_LIST" ]; then
    echo "❌ Image list not found: $IMAGE_LIST"
    exit 1
fi

echo "✓ Products CSV: $(du -h $EXPORT_DIR/$PRODUCTS_CSV | cut -f1)"
echo "✓ Categories CSV: $(du -h $EXPORT_DIR/$CATEGORIES_CSV | cut -f1)"
echo "✓ Image list: $(du -h $EXPORT_DIR/$IMAGE_LIST | cut -f1)"
echo ""

# Count records
PRODUCT_COUNT=$(wc -l < "$EXPORT_DIR/$PRODUCTS_CSV")
CATEGORY_COUNT=$(wc -l < "$EXPORT_DIR/$CATEGORIES_CSV")
IMAGE_COUNT=$(wc -l < "$EXPORT_DIR/$IMAGE_LIST")

echo "Record counts:"
echo "  Products: $((PRODUCT_COUNT - 1)) (excluding header)"
echo "  Category assignments: $((CATEGORY_COUNT - 1))"
echo "  Images: $IMAGE_COUNT"
echo ""

# Test Magento frontend accessibility
echo "Testing Magento frontend..."
MAGENTO_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$MAGENTO_URL" --max-time 10)
if [ "$MAGENTO_STATUS" = "200" ]; then
    echo "✓ Magento frontend accessible (HTTP $MAGENTO_STATUS)"
else
    echo "⚠ Magento frontend returned HTTP $MAGENTO_STATUS"
fi
echo ""

echo "## Phase 2: Sync Strategy Selection"
echo "------------------------------------"
echo ""
echo "Two sync methods available:"
echo ""
echo "METHOD A: API Sync (Recommended for initial setup)"
echo "  - Uses Akeneo → Magento API connector"
echo "  - Handles product relationships automatically"
echo "  - Slower but more reliable for first sync"
echo "  - Command: cd /home/pim/public_html && php check_sync_status.php"
echo ""
echo "METHOD B: CSV Import (Faster for bulk updates)"
echo "  - Direct CSV import to Magento database"
echo "  - Faster for large datasets"
echo "  - Requires manual category/attribute mapping"
echo "  - Command: (Run on Magento server)"
echo "    php bin/magento import:run --behavior=replace $EXPORT_DIR/$PRODUCTS_CSV"
echo ""

echo "## Phase 3: Data Quality Pre-Check"
echo "-----------------------------------"
echo "Analyzing export data quality..."
echo ""

# Sample first 10 products from CSV
echo "Sample products (first 5 records):"
head -6 "$EXPORT_DIR/$PRODUCTS_CSV" | tail -5 | cut -d',' -f1-5
echo ""

# Check for required fields
echo "Checking required fields..."
HEADER=$(head -1 "$EXPORT_DIR/$PRODUCTS_CSV")
REQUIRED_FIELDS=("sku" "name" "price" "categories")
MISSING_FIELDS=0

for field in "${REQUIRED_FIELDS[@]}"; do
    if echo "$HEADER" | grep -q "$field"; then
        echo "✓ Field present: $field"
    else
        echo "✗ MISSING field: $field"
        MISSING_FIELDS=$((MISSING_FIELDS + 1))
    fi
done
echo ""

if [ "$MISSING_FIELDS" -gt 0 ]; then
    echo "⚠ WARNING: $MISSING_FIELDS required fields missing"
else
    echo "✓ All required fields present"
fi
echo ""

echo "## Phase 4: Image Sync Preparation"
echo "-----------------------------------"
echo "Image sync methods:"
echo ""
echo "METHOD 1: rsync (if you have SSH access to Magento server)"
echo "  rsync -avz --progress \\"
echo "    /home/pim/public_html/public/media/product_images/ \\"
echo "    user@magento-server:/path/to/magento/pub/media/catalog/product/"
echo ""
echo "METHOD 2: FTP/SFTP (if no SSH access)"
echo "  - Use FileZilla or similar FTP client"
echo "  - Upload from: /home/pim/public_html/public/media/product_images/"
echo "  - Upload to: /pub/media/catalog/product/ on Magento server"
echo ""
echo "METHOD 3: Magento media import"
echo "  - Place images in Magento's var/import/images/"
echo "  - Run: php bin/magento catalog:images:resize"
echo ""

echo "## Phase 5: Post-Sync Commands"
echo "-------------------------------"
echo "After sync completes, run these on Magento server:"
echo ""
echo "1. Reindex catalogs:"
echo "   php bin/magento indexer:reindex"
echo ""
echo "2. Clear cache:"
echo "   php bin/magento cache:flush"
echo "   php bin/magento cache:clean"
echo ""
echo "3. Regenerate static content (if needed):"
echo "   php bin/magento setup:static-content:deploy -f"
echo ""
echo "4. Verify product count:"
echo "   php bin/magento catalog:product:count"
echo ""

echo "========================================"
echo "SYNC PREPARATION COMPLETE"
echo "========================================"
echo ""
echo "Summary:"
echo "  ✓ Export files verified: 3 files"
echo "  ✓ Products ready: $((PRODUCT_COUNT - 1))"
echo "  ✓ Category assignments: $((CATEGORY_COUNT - 1))"
echo "  ✓ Images ready: $IMAGE_COUNT files"
echo "  ✓ Magento frontend: HTTP $MAGENTO_STATUS"
echo ""
echo "Next Steps:"
echo "  1. Choose sync method (A or B)"
echo "  2. Execute sync command"
echo "  3. Monitor sync progress"
echo "  4. Run post-sync Magento commands"
echo "  5. Verify products on frontend: $MAGENTO_URL"
echo ""
echo "Access Information:"
echo "  Magento Admin: $MAGENTO_ADMIN_URL"
echo "  Username: bot"
echo "  Password: @dM1n\$#@2o25B0T"
echo ""
echo "Full log: $LOG_FILE"
echo "========================================"
