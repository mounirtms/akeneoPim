#!/bin/bash
# Akeneo to Magento Product Export & Sync Script
# Date: 2026-04-30
# Purpose: Export products from Akeneo PIM and prepare for Magento import

set -e

SCRIPT_DIR="/home/pim/public_html/webapp"
EXPORT_DIR="$SCRIPT_DIR/magento_exports"
LOG_FILE="$SCRIPT_DIR/logs/magento_sync.log"
DATE=$(date '+%Y%m%d_%H%M%S')

# Create directories
mkdir -p "$EXPORT_DIR" "$SCRIPT_DIR/logs"

echo "==========================================" | tee -a "$LOG_FILE"
echo "Akeneo to Magento Export - $DATE" | tee -a "$LOG_FILE"
echo "==========================================" | tee -a "$LOG_FILE"

cd /home/pim/public_html

# Step 1: Export products with all attributes
echo "[1/6] Exporting products from Akeneo..." | tee -a "$LOG_FILE"

php -r "
\$conn = new PDO('mysql:host=127.0.0.1;port=3307;dbname=akeneo_pim', 'akeneo_pim', 'akeneo_pim');
\$conn->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

\$output = fopen('$EXPORT_DIR/products_export_$DATE.csv', 'w');

// CSV Headers for Magento
\$headers = [
    'sku', 'name', 'description', 'short_description', 'price', 'special_price',
    'weight', 'status', 'visibility', 'tax_class_id', 'qty', 'is_in_stock',
    'categories', 'image', 'small_image', 'thumbnail', 'meta_title', 'meta_description',
    'ean', 'manufacturer', 'color', 'size'
];
fputcsv(\$output, \$headers);

// Get products with all attributes
\$sql = \"
    SELECT 
        p.identifier as sku,
        p.raw_values,
        p.is_enabled,
        pm.code as model_code
    FROM pim_catalog_product p
    LEFT JOIN pim_catalog_product_model pm ON p.product_model_id = pm.id
    WHERE p.is_enabled = 1
    ORDER BY p.identifier
\";

\$stmt = \$conn->query(\$sql);
\$count = 0;

while (\$row = \$stmt->fetch(PDO::FETCH_ASSOC)) {
    \$values = json_decode(\$row['raw_values'], true);
    
    // Extract attribute values (simplified - adjust based on your structure)
    \$product = [
        'sku' => \$row['sku'],
        'name' => \$values['name'][0]['data'] ?? '',
        'description' => \$values['description'][0]['data'] ?? '',
        'short_description' => \$values['short_description'][0]['data'] ?? '',
        'price' => \$values['price'][0]['data'][0]['amount'] ?? '',
        'special_price' => '',
        'weight' => \$values['weight'][0]['data']['amount'] ?? '',
        'status' => \$row['is_enabled'] ? '1' : '2',
        'visibility' => '4', // Catalog, Search
        'tax_class_id' => '2', // Taxable Goods
        'qty' => '100', // Default quantity
        'is_in_stock' => '1',
        'categories' => '', // Will be filled from category assignments
        'image' => \$values['image'][0]['data'] ?? '',
        'small_image' => \$values['small_image'][0]['data'] ?? \$values['image'][0]['data'] ?? '',
        'thumbnail' => \$values['thumbnail'][0]['data'] ?? \$values['image'][0]['data'] ?? '',
        'meta_title' => \$values['meta_title'][0]['data'] ?? '',
        'meta_description' => \$values['meta_description'][0]['data'] ?? '',
        'ean' => \$values['ean'][0]['data'] ?? '',
        'manufacturer' => \$values['manufacturer'][0]['data'] ?? '',
        'color' => \$values['color'][0]['data'] ?? '',
        'size' => \$values['size'][0]['data'] ?? ''
    ];
    
    fputcsv(\$output, \$product);
    \$count++;
    
    if (\$count % 1000 == 0) {
        echo \"Exported \$count products...\\n\";
    }
}

fclose(\$output);
echo \"✅ Total products exported: \$count\\n\";
" 2>&1 | tee -a "$LOG_FILE"

# Step 2: Export category assignments
echo "[2/6] Exporting category assignments..." | tee -a "$LOG_FILE"

php -r "
\$conn = new PDO('mysql:host=127.0.0.1;port=3307;dbname=akeneo_pim', 'akeneo_pim', 'akeneo_pim');

\$output = fopen('$EXPORT_DIR/category_assignments_$DATE.csv', 'w');
fputcsv(\$output, ['sku', 'categories']);

\$sql = \"
    SELECT 
        p.identifier as sku,
        GROUP_CONCAT(c.code SEPARATOR ',') as categories
    FROM pim_catalog_product p
    JOIN pim_catalog_category_product cp ON p.id = cp.product_id
    JOIN pim_catalog_category c ON cp.category_id = c.id
    WHERE p.is_enabled = 1
    GROUP BY p.identifier
\";

\$stmt = \$conn->query(\$sql);
\$count = 0;

while (\$row = \$stmt->fetch(PDO::FETCH_ASSOC)) {
    fputcsv(\$output, [\$row['sku'], \$row['categories']]);
    \$count++;
}

fclose(\$output);
echo \"✅ Category assignments exported: \$count products\\n\";
" 2>&1 | tee -a "$LOG_FILE"

# Step 3: Create image export list
echo "[3/6] Creating image export list..." | tee -a "$LOG_FILE"

find /home/pim/public_html/public/media/product_images -type f \( -name "*.jpg" -o -name "*.png" -o -name "*.jpeg" \) > "$EXPORT_DIR/image_files_$DATE.txt"

IMAGE_COUNT=$(wc -l < "$EXPORT_DIR/image_files_$DATE.txt")
echo "✅ Found $IMAGE_COUNT image files" | tee -a "$LOG_FILE"

# Step 4: Generate sync report
echo "[4/6] Generating sync report..." | tee -a "$LOG_FILE"

cat > "$EXPORT_DIR/sync_report_$DATE.txt" << EOF
Akeneo to Magento Export Report
Generated: $(date '+%Y-%m-%d %H:%M:%S')

Files Created:
- products_export_$DATE.csv
- category_assignments_$DATE.csv
- image_files_$DATE.txt

Statistics:
- Total Products: $(wc -l < "$EXPORT_DIR/products_export_$DATE.csv")
- Category Assignments: $(wc -l < "$EXPORT_DIR/category_assignments_$DATE.csv")
- Image Files: $IMAGE_COUNT

Next Steps:
1. Review exported CSV files
2. Copy images to Magento server: 
   rsync -av /home/pim/public_html/public/media/product_images/ user@magento-server:/path/to/magento/pub/media/catalog/product/
3. Import products to Magento:
   php bin/magento import:run --behavior=replace $EXPORT_DIR/products_export_$DATE.csv
4. Reindex Magento:
   php bin/magento indexer:reindex
5. Clear Magento cache:
   php bin/magento cache:flush

Magento Frontend: https://beta.technostationery.com
EOF

cat "$EXPORT_DIR/sync_report_$DATE.txt" | tee -a "$LOG_FILE"

# Step 5: Create Magento import instructions
echo "[5/6] Creating Magento import instructions..." | tee -a "$LOG_FILE"

cat > "$EXPORT_DIR/MAGENTO_IMPORT_INSTRUCTIONS.md" << 'EOF'
# Magento Import Instructions

## Prerequisites
- SSH access to Magento server
- Magento 2.x installed at the target location
- Database credentials for Magento

## Import Steps

### 1. Transfer Files to Magento Server
```bash
# Copy product export CSV
scp /home/pim/public_html/webapp/magento_exports/products_export_*.csv user@magento-server:/var/www/magento/var/import/

# Sync product images (may take time for 28K+ images)
rsync -avz --progress \
    /home/pim/public_html/public/media/product_images/ \
    user@magento-server:/var/www/magento/pub/media/catalog/product/
```

### 2. On Magento Server - Import Products
```bash
cd /var/www/magento

# Import products
php bin/magento import:run \
    --behavior=append \
    --import-source=/var/www/magento/var/import/products_export_*.csv

# Or use Magento Admin:
# System > Data Transfer > Import
# Entity Type: Products
# Import Behavior: Add/Update
# Select file and validate
```

### 3. Reindex Everything
```bash
cd /var/www/magento

# Reindex all
php bin/magento indexer:reindex

# Or specific indices:
php bin/magento indexer:reindex catalog_product_attribute
php bin/magento indexer:reindex catalog_product_price
php bin/magento indexer:reindex catalogsearch_fulltext
php bin/magento indexer:reindex catalog_category_product
```

### 4. Clear Caches
```bash
cd /var/www/magento

# Clear all caches
php bin/magento cache:flush
php bin/magento cache:clean

# Clear page cache
php bin/magento cache:clean full_page

# Clear static files (if needed)
rm -rf pub/static/* var/view_preprocessed/*
php bin/magento setup:static-content:deploy -f
```

### 5. Generate Image Cache
```bash
cd /var/www/magento

# Resize product images for catalog
php bin/magento catalog:images:resize

# This may take 30+ minutes for 9,538 products
```

### 6. Verify Import
```bash
# Check product count
php bin/magento db:query "SELECT COUNT(*) FROM catalog_product_entity"

# Check enabled products
php bin/magento db:query "SELECT COUNT(*) FROM catalog_product_entity WHERE status = 1"

# Test frontend
curl -I https://beta.technostationery.com
curl -s https://beta.technostationery.com/catalogsearch/result/?q=pen | grep -c "product"
```

## Troubleshooting

### Images Not Showing
```bash
# Check image permissions
chmod -R 755 pub/media/catalog/product/
chown -R www-data:www-data pub/media/catalog/product/

# Regenerate image cache
php bin/magento catalog:images:resize
```

### Products Not Visible
```bash
# Check product status
php bin/magento db:query "SELECT sku, status, visibility FROM catalog_product_entity LIMIT 10"

# Reindex
php bin/magento indexer:reindex catalog_product_flat

# Check category assignments
php bin/magento db:query "SELECT COUNT(*) FROM catalog_category_product"
```

### Search Not Working
```bash
# Reindex search
php bin/magento indexer:reindex catalogsearch_fulltext

# Check Elasticsearch connection (if used)
curl http://localhost:9200/_cat/indices?v | grep magento
```

## Performance Tips

1. **Disable indexers during import:**
   ```bash
   php bin/magento indexer:set-mode schedule
   ```

2. **Import in batches** if experiencing timeouts

3. **Use flat catalog** for better performance:
   ```bash
   php bin/magento config:set catalog/frontend/flat_catalog_product 1
   php bin/magento indexer:reindex catalog_product_flat
   ```

4. **Enable production mode:**
   ```bash
   php bin/magento deploy:mode:set production
   ```

## Automated Sync (Future)

Set up cron job for daily sync:
```bash
0 2 * * * /home/pim/public_html/webapp/magento_export_sync.sh
```
EOF

echo "✅ Magento import instructions created" | tee -a "$LOG_FILE"

# Step 6: Summary
echo "[6/6] Export complete!" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
echo "==========================================" | tee -a "$LOG_FILE"
echo "Export Location: $EXPORT_DIR" | tee -a "$LOG_FILE"
echo "Log File: $LOG_FILE" | tee -a "$LOG_FILE"
echo "==========================================" | tee -a "$LOG_FILE"

ls -lh "$EXPORT_DIR/"*"$DATE"* | tee -a "$LOG_FILE"
