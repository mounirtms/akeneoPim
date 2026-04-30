#!/bin/bash
# Performance and Catalog Quality Test Script
# Date: 2026-04-30
# Purpose: Run additional quality tests and capture metrics

SCRIPT_DIR="/home/pim/public_html/webapp"
LOG_DIR="$SCRIPT_DIR/logs"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
LOG_FILE="$LOG_DIR/quality_tests_${TIMESTAMP}.log"

mkdir -p "$LOG_DIR"

echo "=========================================="
echo "Catalog Quality & Performance Tests"
echo "Started: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=========================================="

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

cd /home/pim/public_html

# Test 1: Data Quality Metrics
log "========== DATA QUALITY METRICS =========="

php -r "
\$conn = new PDO('mysql:host=127.0.0.1;port=3307;dbname=akeneo_pim', 'akeneo_pim', 'akeneo_pim');

echo \"\\n📊 PRODUCT DATA QUALITY\\n\";
echo \"=========================\\n\\n\";

// Total products
\$total = \$conn->query('SELECT COUNT(*) FROM pim_catalog_product WHERE is_enabled = 1')->fetchColumn();
echo \"Total Products: \$total\\n\\n\";

// Products with images
\$with_images = \$conn->query('
    SELECT COUNT(*) FROM pim_catalog_product 
    WHERE is_enabled = 1 
    AND JSON_LENGTH(JSON_EXTRACT(raw_values, \"$.image\")) > 0
')->fetchColumn();
\$image_pct = round(\$with_images / \$total * 100, 2);
echo \"✅ Products with Images: \$with_images (\$image_pct%)\\n\";

// Products with descriptions
\$with_desc = \$conn->query('
    SELECT COUNT(*) FROM pim_catalog_product 
    WHERE is_enabled = 1 
    AND JSON_LENGTH(JSON_EXTRACT(raw_values, \"$.description\")) > 0
')->fetchColumn();
\$desc_pct = round(\$with_desc / \$total * 100, 2);
echo \"✅ Products with Descriptions: \$with_desc (\$desc_pct%)\\n\";

// Products with prices
\$with_price = \$conn->query('
    SELECT COUNT(*) FROM pim_catalog_product 
    WHERE is_enabled = 1 
    AND JSON_LENGTH(JSON_EXTRACT(raw_values, \"$.price\")) > 0
')->fetchColumn();
\$price_pct = round(\$with_price / \$total * 100, 2);
echo \"✅ Products with Prices: \$with_price (\$price_pct%)\\n\";

// Products with SEO metadata
\$with_seo = \$conn->query('
    SELECT COUNT(*) FROM pim_catalog_product 
    WHERE is_enabled = 1 
    AND JSON_LENGTH(JSON_EXTRACT(raw_values, \"$.meta_title\")) > 0
')->fetchColumn();
\$seo_pct = round(\$with_seo / \$total * 100, 2);
echo \"✅ Products with SEO Metadata: \$with_seo (\$seo_pct%)\\n\";

// Products with EAN
\$with_ean = \$conn->query('
    SELECT COUNT(*) FROM pim_catalog_product 
    WHERE is_enabled = 1 
    AND JSON_LENGTH(JSON_EXTRACT(raw_values, \"$.ean\")) > 0
')->fetchColumn();
\$ean_pct = round(\$with_ean / \$total * 100, 2);
echo \"✅ Products with EAN: \$with_ean (\$ean_pct%)\\n\";

// Products with weight
\$with_weight = \$conn->query('
    SELECT COUNT(*) FROM pim_catalog_product 
    WHERE is_enabled = 1 
    AND JSON_LENGTH(JSON_EXTRACT(raw_values, \"$.weight\")) > 0
')->fetchColumn();
\$weight_pct = round(\$with_weight / \$total * 100, 2);
echo \"✅ Products with Weight: \$with_weight (\$weight_pct%)\\n\\n\";

// Category assignments
\$cat_assignments = \$conn->query('SELECT COUNT(*) FROM pim_catalog_category_product')->fetchColumn();
\$avg_cats = round(\$cat_assignments / \$total, 2);
echo \"📁 Category Assignments: \$cat_assignments (avg \$avg_cats per product)\\n\\n\";

// Product model breakdown
echo \"\\n📦 PRODUCT MODEL STRUCTURE\\n\";
echo \"============================\\n\\n\";

\$models = \$conn->query('SELECT COUNT(*) FROM pim_catalog_product_model')->fetchColumn();
\$variants = \$conn->query('SELECT COUNT(*) FROM pim_catalog_product WHERE product_model_id IS NOT NULL')->fetchColumn();
\$simple = \$total - \$variants;

\$variant_pct = round(\$variants / \$total * 100, 2);
\$simple_pct = round(\$simple / \$total * 100, 2);

echo \"Product Models: \$models\\n\";
echo \"Variant Products: \$variants (\$variant_pct%)\\n\";
echo \"Simple Products: \$simple (\$simple_pct%)\\n\\n\";

// Top categories by product count
echo \"\\n🏆 TOP 10 CATEGORIES\\n\";
echo \"=====================\\n\\n\";

\$stmt = \$conn->query('
    SELECT c.code, c.labels, COUNT(cp.product_id) as product_count
    FROM pim_catalog_category c
    LEFT JOIN pim_catalog_category_product cp ON c.id = cp.category_id
    GROUP BY c.id
    ORDER BY product_count DESC
    LIMIT 10
');

\$rank = 1;
while (\$cat = \$stmt->fetch(PDO::FETCH_ASSOC)) {
    \$labels = json_decode(\$cat['labels'], true);
    \$name = \$labels['fr_FR'] ?? \$cat['code'];
    echo \$rank . \". \" . \$name . \": \" . \$cat['product_count'] . \" products\\n\";
    \$rank++;
}

echo \"\\n\\n✅ DATA QUALITY REPORT COMPLETE\\n\";
" | tee -a "$LOG_FILE"

# Test 2: Completeness Analysis
log "========== COMPLETENESS ANALYSIS =========="

php -r "
\$conn = new PDO('mysql:host=127.0.0.1;port=3307;dbname=akeneo_pim', 'akeneo_pim', 'akeneo_pim');

echo \"\\n📈 COMPLETENESS STATISTICS\\n\";
echo \"===========================\\n\\n\";

// Get completeness distribution
\$stmt = \$conn->query('
    SELECT 
        FLOOR(ratio / 10) * 10 as bucket,
        COUNT(*) as count
    FROM pim_catalog_completeness
    WHERE ratio > 0
    GROUP BY bucket
    ORDER BY bucket DESC
');

echo \"Completeness Distribution:\\n\\n\";
while (\$row = \$stmt->fetch(PDO::FETCH_ASSOC)) {
    \$bucket_label = \$row['bucket'] . '-' . (\$row['bucket'] + 9) . '%';
    \$bar = str_repeat('█', intval(\$row['count'] / 100));
    echo str_pad(\$bucket_label, 10) . ': ' . \$bar . ' (' . \$row['count'] . ')' . \"\\n\";
}

// Average completeness
\$avg = \$conn->query('SELECT AVG(ratio) FROM pim_catalog_completeness WHERE ratio > 0')->fetchColumn();
echo \"\\nAverage Completeness: \" . round(\$avg, 2) . \"%\\n\";

// Products by completeness level
\$complete = \$conn->query('SELECT COUNT(DISTINCT product_id) FROM pim_catalog_completeness WHERE ratio = 100')->fetchColumn();
\$high = \$conn->query('SELECT COUNT(DISTINCT product_id) FROM pim_catalog_completeness WHERE ratio >= 80 AND ratio < 100')->fetchColumn();
\$medium = \$conn->query('SELECT COUNT(DISTINCT product_id) FROM pim_catalog_completeness WHERE ratio >= 50 AND ratio < 80')->fetchColumn();
\$low = \$conn->query('SELECT COUNT(DISTINCT product_id) FROM pim_catalog_completeness WHERE ratio > 0 AND ratio < 50')->fetchColumn();

echo \"\\nCompleteness Levels:\\n\";
echo \"  100%: \$complete products\\n\";
echo \"  80-99%: \$high products\\n\";
echo \"  50-79%: \$medium products\\n\";
echo \"  1-49%: \$low products\\n\\n\";
" | tee -a "$LOG_FILE"

# Test 3: Performance Metrics
log "========== PERFORMANCE METRICS =========="

echo ""
echo "🚀 SYSTEM PERFORMANCE"
echo "====================="
echo ""

# Elasticsearch performance
log "Testing Elasticsearch performance..."
for i in {1..5}; do
    START=$(date +%s%N)
    curl -s "http://localhost:9200/beta_techno_stationery_product_1_v7/_search?size=10" > /dev/null 2>&1
    END=$(date +%s%N)
    TIME=$(( (END - START) / 1000000 ))
    echo "  Test $i: ${TIME}ms"
done | tee -a "$LOG_FILE"

# Database performance
log "Testing database performance..."
for i in {1..5}; do
    START=$(date +%s%N)
    php -r "
    \$conn = new PDO('mysql:host=127.0.0.1;port=3307;dbname=akeneo_pim', 'akeneo_pim', 'akeneo_pim');
    \$stmt = \$conn->query('SELECT * FROM pim_catalog_product LIMIT 100');
    \$stmt->fetchAll();
    " > /dev/null 2>&1
    END=$(date +%s%N)
    TIME=$(( (END - START) / 1000000 ))
    echo "  Test $i: ${TIME}ms"
done | tee -a "$LOG_FILE"

# System resources
echo ""
echo "💻 SYSTEM RESOURCES"
echo "==================="
echo ""
echo "CPU Load: $(uptime | awk -F'load average:' '{print $2}')"
echo "Memory: $(free -h | awk 'NR==2 {print $3 "/" $2 " (" int($3/$2*100) "%)"}')"
echo "Disk: $(df -h /home/pim/public_html | awk 'NR==2 {print $3 "/" $2 " (" $5 ")"}')"
echo ""

# Test 4: Image Analysis
log "========== IMAGE ANALYSIS =========="

echo ""
echo "🖼️  IMAGE STATISTICS"
echo "==================="
echo ""

TOTAL_IMAGES=$(find /home/pim/public_html/public/media/product_images -type f | wc -l)
LARGE_IMAGES=$(find /home/pim/public_html/public/media/product_images/large -type f 2>/dev/null | wc -l)
MEDIUM_IMAGES=$(find /home/pim/public_html/public/media/product_images/medium -type f 2>/dev/null | wc -l)
THUMB_IMAGES=$(find /home/pim/public_html/public/media/product_images/thumbnail -type f 2>/dev/null | wc -l)

echo "Total Image Files: $TOTAL_IMAGES"
echo "  - Large: $LARGE_IMAGES"
echo "  - Medium: $MEDIUM_IMAGES"
echo "  - Thumbnail: $THUMB_IMAGES"
echo ""

IMAGE_SIZE=$(du -sh /home/pim/public_html/public/media/product_images 2>/dev/null | cut -f1)
echo "Total Image Storage: $IMAGE_SIZE"
echo ""

# Average file size
AVG_SIZE=$(find /home/pim/public_html/public/media/product_images -type f -exec ls -l {} \; 2>/dev/null | awk '{sum+=$5; count++} END {print int(sum/count/1024)}')
echo "Average File Size: ${AVG_SIZE}KB"
echo ""

log "========== TESTS COMPLETE =========="

echo ""
echo "=========================================="
echo "Quality & Performance Tests Complete"
echo "Completed: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=========================================="
echo ""
echo "Full log: $LOG_FILE"
