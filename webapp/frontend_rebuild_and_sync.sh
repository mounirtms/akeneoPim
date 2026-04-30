#!/bin/bash
# Phase 1: Frontend Asset Rebuild + Phase 2: Magento Sync Preparation
# Date: 2026-04-30

LOG_FILE="logs/frontend_rebuild_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "========================================"
echo "PHASE 1: FRONTEND ASSET REBUILD"
echo "Date: $(date)"
echo "========================================"
echo ""

cd /home/pim/public_html

# Step 1: Check for existing assets
echo "## Step 1: Current Asset Status"
echo "--------------------------------"
echo "JavaScript bundles: $(find public/bundles -name "*.js" 2>/dev/null | wc -l)"
echo "CSS files: $(find public/css -name "*.css" 2>/dev/null | wc -l)"
echo "require.min.js exists: $([ -f public/bundles/pimui/js/require.min.js ] && echo "YES" || echo "NO")"
echo ""

# Step 2: Check if Akeneo uses webpack or just symlinks
echo "## Step 2: Build System Detection"
echo "----------------------------------"
if [ -f "package.json" ]; then
    echo "✓ package.json found"
    echo "Build scripts available:"
    grep -A 5 '"scripts"' package.json 2>/dev/null | head -10
else
    echo "⚠ No package.json - Akeneo may use symlinks only"
fi
echo ""

# Step 3: Check if assets are symlinked (Akeneo 6.0+ uses symlinks, not webpack)
echo "## Step 3: Akeneo Asset Architecture"
echo "-------------------------------------"
echo "Checking public/bundles structure..."
ls -la public/bundles/ 2>&1 | head -10
echo ""

# Step 4: Verify if require.min.js should exist
echo "## Step 4: RequireJS Investigation"
echo "-----------------------------------"
echo "Searching for require.js/require.min.js in vendor bundles..."
find vendor/akeneo -name "require*.js" 2>/dev/null | head -5
find public/bundles -name "require*.js" 2>/dev/null | head -5
echo ""

# Step 5: Check Akeneo version and architecture
echo "## Step 5: Akeneo Version Check"
echo "--------------------------------"
php bin/console --version 2>&1
echo ""

# Step 6: Regenerate routes (for fos-routing issues)
echo "## Step 6: Regenerate JavaScript Routes"
echo "----------------------------------------"
echo "Generating fos_js_routes.json..."
php bin/console fos:js-routing:dump --format=json --target=public/js/fos_js_routes.json --env=prod 2>&1
if [ -f "public/js/fos_js_routes.json" ]; then
    echo "✓ fos_js_routes.json created ($(du -h public/js/fos_js_routes.json | cut -f1))"
else
    echo "⚠ fos_js_routes.json not created"
fi
echo ""

# Step 7: Clear Symfony cache again
echo "## Step 7: Cache Rebuild"
echo "------------------------"
php bin/console cache:clear --env=prod --no-warmup 2>&1 | tail -5
php bin/console cache:warmup --env=prod 2>&1 | tail -5
echo ""

# Step 8: Verify critical JavaScript files
echo "## Step 8: Critical File Verification"
echo "--------------------------------------"
CRITICAL_FILES=(
    "public/js/fos_js_routes.json"
    "public/bundles/fosjsrouting/js/router.js"
    "public/bundles/pimui/js/form/common/creation/modal.js"
)

for file in "${CRITICAL_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "✓ $file ($(du -h "$file" | cut -f1))"
    else
        echo "✗ MISSING: $file"
    fi
done
echo ""

echo "========================================"
echo "PHASE 2: MAGENTO SYNC PREPARATION"
echo "========================================"
echo ""

# Step 9: Verify export files
echo "## Step 9: Export Files Verification"
echo "-------------------------------------"
EXPORT_DIR="webapp/magento_exports"
if [ -d "$EXPORT_DIR" ]; then
    echo "✓ Export directory exists"
    ls -lh "$EXPORT_DIR"/*.csv "$EXPORT_DIR"/*.txt 2>&1 | tail -10
else
    echo "⚠ Export directory not found"
fi
echo ""

# Step 10: Database connectivity test (with SSL workaround)
echo "## Step 10: Database Connection Test"
echo "-------------------------------------"
mysql -h 127.0.0.1 -P 3307 -u akeneo_pim -pLZVvxnY9vskG --ssl=0 akeneo_pim \
    -e "SELECT 
        COUNT(*) as total_products,
        SUM(CASE WHEN is_enabled = 1 THEN 1 ELSE 0 END) as enabled_products
    FROM pim_catalog_product;" 2>&1
echo ""

# Step 11: Elasticsearch reindex verification
echo "## Step 11: Elasticsearch Verification"
echo "---------------------------------------"
ES_COUNT=$(curl -s "http://localhost:9200/akeneo_pim_product_and_product_model*/_count" | grep -o '"count":[0-9]*' | cut -d':' -f2)
echo "Products in Elasticsearch: $ES_COUNT"
if [ "$ES_COUNT" -gt 9000 ]; then
    echo "✓ Elasticsearch index healthy"
else
    echo "⚠ Reindexing may be needed"
fi
echo ""

# Step 12: Image inventory
echo "## Step 12: Product Images Inventory"
echo "-------------------------------------"
IMAGE_DIR="public/media/product_images"
if [ -d "$IMAGE_DIR" ]; then
    TOTAL_IMAGES=$(find "$IMAGE_DIR" -type f 2>/dev/null | wc -l)
    TOTAL_SIZE=$(du -sh "$IMAGE_DIR" 2>/dev/null | cut -f1)
    echo "Total images: $TOTAL_IMAGES files"
    echo "Total size: $TOTAL_SIZE"
    echo ""
    echo "Breakdown by size:"
    for subdir in large medium thumbnail; do
        if [ -d "$IMAGE_DIR/$subdir" ]; then
            COUNT=$(find "$IMAGE_DIR/$subdir" -type f 2>/dev/null | wc -l)
            SIZE=$(du -sh "$IMAGE_DIR/$subdir" 2>/dev/null | cut -f1)
            echo "  $subdir: $COUNT files ($SIZE)"
        fi
    done
else
    echo "⚠ Image directory not found"
fi
echo ""

echo "========================================"
echo "COMPLETION SUMMARY"
echo "========================================"
echo ""

# Final status check
CRITICAL_ISSUES=0

# Check 1: JavaScript routes
if [ ! -f "public/js/fos_js_routes.json" ]; then
    echo "❌ fos_js_routes.json missing"
    CRITICAL_ISSUES=$((CRITICAL_ISSUES + 1))
else
    echo "✓ fos_js_routes.json present"
fi

# Check 2: Export files
if [ ! -f "$EXPORT_DIR/products_export_20260430_131735.csv" ]; then
    echo "❌ Magento exports missing"
    CRITICAL_ISSUES=$((CRITICAL_ISSUES + 1))
else
    echo "✓ Magento exports ready"
fi

# Check 3: Images
if [ "$TOTAL_IMAGES" -lt 25000 ]; then
    echo "⚠ Image count low: $TOTAL_IMAGES"
else
    echo "✓ Images ready: $TOTAL_IMAGES files"
fi

echo ""
if [ "$CRITICAL_ISSUES" -eq 0 ]; then
    echo "🎉 ALL SYSTEMS READY FOR MAGENTO SYNC"
else
    echo "⚠ $CRITICAL_ISSUES critical issues need attention"
fi

echo ""
echo "Log file: $LOG_FILE"
echo "========================================"
