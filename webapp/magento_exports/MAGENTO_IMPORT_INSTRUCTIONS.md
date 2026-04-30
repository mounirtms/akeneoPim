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
