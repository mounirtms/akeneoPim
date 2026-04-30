#!/bin/bash
# Fix Critical Issues Found in Stability Tests
# Date: 2026-04-30

LOG_FILE="logs/critical_fixes_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "========================================"
echo "FIXING CRITICAL ISSUES"
echo "Date: $(date)"
echo "========================================"
echo ""

cd /home/pim/public_html

# Issue 1: Frontend Assets Missing (require.min.js)
echo "## Fix 1: Regenerate Frontend Assets"
echo "-------------------------------------"
echo "Installing assets..."
php bin/console pim:installer:assets --symlink --clean --env=prod 2>&1 | tail -20
echo ""

# Issue 2: Clear and warm up cache
echo "## Fix 2: Clear and Rebuild Cache"
echo "----------------------------------"
echo "Clearing cache..."
php bin/console cache:clear --env=prod 2>&1 | tail -10
echo ""
echo "Warming up cache..."
php bin/console cache:warmup --env=prod 2>&1 | tail -10
echo ""

# Issue 3: Reindex Elasticsearch
echo "## Fix 3: Reindex Products"
echo "--------------------------"
echo "Reindexing products..."
php bin/console pim:product:index --all --env=prod 2>&1 | tail -20
echo ""
echo "Reindexing product models..."
php bin/console pim:product-model:index --all --env=prod 2>&1 | tail -20
echo ""

# Issue 4: Verify JavaScript bundles
echo "## Fix 4: Check Frontend Assets"
echo "--------------------------------"
echo "Checking require.min.js:"
ls -lh public/bundles/pimui/js/require.min.js 2>&1 || echo "Still missing - may need webpack rebuild"
echo ""
echo "JavaScript bundles:"
find public/bundles -name "*.js" | wc -l
echo ""
echo "CSS files:"
find public/css -name "*.css" | wc -l
echo ""

# Issue 5: Database connectivity test
echo "## Fix 5: Database Connectivity"
echo "--------------------------------"
php -r '
$dsn = "mysql:host=127.0.0.1;port=3307;dbname=akeneo_pim";
try {
    $pdo = new PDO($dsn, "akeneo_pim", "LZVvxnY9vskG");
    $stmt = $pdo->query("SELECT COUNT(*) FROM pim_catalog_product WHERE is_enabled = 1");
    echo "✅ Products: " . $stmt->fetchColumn() . "\n";
    $stmt = $pdo->query("SELECT COUNT(*) FROM pim_catalog_product_model");
    echo "✅ Models: " . $stmt->fetchColumn() . "\n";
    $stmt = $pdo->query("SELECT COUNT(*) FROM pim_catalog_category");
    echo "✅ Categories: " . $stmt->fetchColumn() . "\n";
} catch (Exception $e) {
    echo "❌ Database Error: " . $e->getMessage() . "\n";
}
' 2>&1
echo ""

echo "========================================"
echo "FIXES COMPLETE"
echo "========================================"
echo "Log: $LOG_FILE"
