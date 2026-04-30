# Next Session Plan - Akeneo PIM to Magento Sync
**Date**: 2026-05-01  
**Current Status**: ✅ Akeneo PIM Stable (90.5% test success)

---

## Session Overview

**Goal**: Complete Magento synchronization and validate frontend functionality  
**Estimated Duration**: 2-3 hours  
**Prerequisites**: Akeneo PIM stable (✅ Complete)

---

## Phase 1: Pre-Sync Validation (15 minutes)

### 1.1 Verify Akeneo PIM Status
```bash
cd /home/pim/public_html/webapp
./akeneo_ui_monkey_tests.sh
```
**Expected Result**: 90%+ success rate

### 1.2 Verify Export Files
```bash
cd /home/pim/public_html/webapp/magento_exports
ls -lh *.csv *.txt
```
**Expected Files**:
- `products_export_20260430_131735.csv` (5.4 MB)
- `category_assignments_20260430_131735.csv` (445 KB)
- `image_files_20260430_131735.txt` (2.0 MB)

### 1.3 Check System Resources
```bash
uptime
free -h
df -h
```
**Healthy Thresholds**:
- CPU Load: < 10
- Memory: < 80%
- Disk: < 80%

---

## Phase 2: Magento Frontend Fix (30 minutes)

### 2.1 Identify Magento Installation Path
```bash
# Typical locations
find /home -name "bin/magento" 2>/dev/null | head -5
# Or check cPanel/hosting panel for Magento path
```

### 2.2 Check Magento Error Logs
```bash
MAGENTO_PATH="/path/to/magento"  # Update this path
tail -100 $MAGENTO_PATH/var/log/system.log
tail -100 $MAGENTO_PATH/var/log/exception.log
tail -100 $MAGENTO_PATH/var/log/debug.log
```

### 2.3 Basic Magento Fixes
```bash
cd $MAGENTO_PATH

# Clear all caches
php bin/magento cache:flush
php bin/magento cache:clean

# Check maintenance mode
php bin/magento maintenance:status
# If enabled, disable it
php bin/magento maintenance:disable

# Run setup upgrade
php bin/magento setup:upgrade

# Recompile dependency injection
php bin/magento setup:di:compile

# Deploy static content
php bin/magento setup:static-content:deploy -f en_US

# Reindex all
php bin/magento indexer:reindex

# Check status
php bin/magento --version
php bin/magento module:status
```

### 2.4 Verify Frontend Access
```bash
curl -I https://beta.technostationery.com/
# Expected: HTTP 200 or 302 (not 500)
```

---

## Phase 3: Magento Sync Execution (60-90 minutes)

### Method A: API Sync (Recommended if connector exists)

#### 3.1 Check Akeneo-Magento Connector
```bash
cd /home/pim/public_html
ls -la | grep -i connector
php bin/console list | grep -i magento
```

#### 3.2 Run Connector Sync
```bash
# If connector exists
php check_sync_status.php

# Or use Akeneo command if available
php bin/console akeneo:magento:sync --env=prod
```

### Method B: CSV Import (Manual)

#### 3.1 Prepare Magento Import Directory
```bash
cd $MAGENTO_PATH
mkdir -p var/import
chmod 777 var/import
```

#### 3.2 Copy Export Files
```bash
cp /home/pim/public_html/webapp/magento_exports/products_export_20260430_131735.csv \
   $MAGENTO_PATH/var/import/

cp /home/pim/public_html/webapp/magento_exports/category_assignments_20260430_131735.csv \
   $MAGENTO_PATH/var/import/
```

#### 3.3 Run Magento Import
```bash
cd $MAGENTO_PATH

# Import products
php bin/magento import:run \
  --behavior=replace \
  --entity=catalog_product \
  var/import/products_export_20260430_131735.csv

# Import categories (if supported)
php bin/magento import:run \
  --behavior=replace \
  --entity=catalog_category \
  var/import/category_assignments_20260430_131735.csv
```

### Method C: Image Sync via rsync

#### 3.4 Sync Product Images
```bash
# If Magento is on same server
rsync -avz --progress \
  /home/pim/public_html/public/media/product_images/ \
  $MAGENTO_PATH/pub/media/catalog/product/

# If Magento is on remote server
rsync -avz -e ssh --progress \
  /home/pim/public_html/public/media/product_images/ \
  user@magento-server:/path/to/magento/pub/media/catalog/product/
```

#### 3.5 Fix Image Permissions
```bash
cd $MAGENTO_PATH
find pub/media/catalog/product -type f -exec chmod 644 {} \;
find pub/media/catalog/product -type d -exec chmod 755 {} \;
```

### 3.6 Post-Import Commands
```bash
cd $MAGENTO_PATH

# Reindex everything
php bin/magento indexer:reindex

# Flush cache
php bin/magento cache:flush

# Regenerate product URLs
php bin/magento catalog:product:url:reindex

# Resize images
php bin/magento catalog:images:resize

# Check product count
php bin/magento catalog:product:count
```

---

## Phase 4: Frontend Validation (30 minutes)

### 4.1 Manual Testing Checklist

#### Homepage
- [ ] https://beta.technostationery.com/ loads (HTTP 200)
- [ ] Navigation menu displays correctly
- [ ] Featured products visible
- [ ] Images loading properly

#### Product Grid
- [ ] Navigate to product category
- [ ] Product thumbnails display
- [ ] Product count matches expected (9,538)
- [ ] Filters working
- [ ] Pagination working

#### Product Detail Page
- [ ] Click on a product
- [ ] Product images load (all variants: large, medium, thumbnail)
- [ ] Product title and description display
- [ ] Price displays correctly
- [ ] Add to cart button works
- [ ] SEO metadata present (view page source)

#### Category Navigation
- [ ] All 166 categories accessible
- [ ] Breadcrumbs working
- [ ] Category descriptions display
- [ ] Products assigned to correct categories

#### Search Functionality
- [ ] Search bar functional
- [ ] Search results accurate
- [ ] Product images in search results
- [ ] Filters work in search

### 4.2 Automated Validation Script
```bash
cd /home/pim/public_html/webapp

cat > magento_frontend_validation.sh << 'SCRIPT'
#!/bin/bash
echo "=== Magento Frontend Validation ==="

# Test homepage
echo "1. Testing homepage..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" https://beta.technostationery.com/)
echo "Homepage HTTP: $HTTP_CODE"

# Test product page (example SKU)
echo "2. Testing product page..."
PRODUCT_CODE=$(curl -s "https://beta.technostationery.com/catalog/product/view/id/1" -w "%{http_code}")
echo "Product page HTTP: $PRODUCT_CODE"

# Test category page
echo "3. Testing category page..."
CATEGORY_CODE=$(curl -s "https://beta.technostationery.com/category.html" -w "%{http_code}")
echo "Category page HTTP: $CATEGORY_CODE"

# Test search
echo "4. Testing search..."
SEARCH_CODE=$(curl -s "https://beta.technostationery.com/catalogsearch/result/?q=test" -w "%{http_code}")
echo "Search HTTP: $SEARCH_CODE"

echo "=== Validation Complete ==="
SCRIPT

chmod +x magento_frontend_validation.sh
./magento_frontend_validation.sh
```

---

## Phase 5: Data Verification (20 minutes)

### 5.1 Database Verification
```bash
cd $MAGENTO_PATH

# Count products in Magento
php bin/magento dbal:run-sql "SELECT COUNT(*) FROM catalog_product_entity" 2>/dev/null || \
  mysql -h localhost -u magento_user -p magento_db -e "SELECT COUNT(*) FROM catalog_product_entity;"

# Expected: ~9,538 products

# Count categories
php bin/magento dbal:run-sql "SELECT COUNT(*) FROM catalog_category_entity" 2>/dev/null || \
  mysql -h localhost -u magento_user -p magento_db -e "SELECT COUNT(*) FROM catalog_category_entity;"

# Expected: ~166 categories
```

### 5.2 Image Verification
```bash
# Count product images in Magento
find $MAGENTO_PATH/pub/media/catalog/product -type f \( -name "*.jpg" -o -name "*.png" \) | wc -l
# Expected: ~28,200 images
```

### 5.3 SEO Metadata Check
```bash
# Test meta tags on a random product
curl -s "https://beta.technostationery.com/" | grep -i "meta"
```

---

## Phase 6: Performance Testing (15 minutes)

### 6.1 Page Load Speed
```bash
# Test with curl timing
curl -w "\nTotal Time: %{time_total}s\n" -o /dev/null -s https://beta.technostationery.com/

# Expected: < 3 seconds
```

### 6.2 Magento Cache Status
```bash
cd $MAGENTO_PATH
php bin/magento cache:status
# All caches should be enabled
```

### 6.3 Varnish/Full Page Cache
```bash
# Check if Varnish is configured
php bin/magento config:show system/full_page_cache/caching_application
```

---

## Phase 7: Issue Resolution (As Needed)

### Common Issues & Fixes

#### Issue 1: Products Not Appearing
```bash
cd $MAGENTO_PATH
php bin/magento indexer:reindex catalog_product_attribute
php bin/magento indexer:reindex catalog_product_price
php bin/magento cache:flush
```

#### Issue 2: Images Not Loading
```bash
# Check image permissions
find pub/media/catalog/product -type f ! -perm 644 -exec chmod 644 {} \;
find pub/media/catalog/product -type d ! -perm 755 -exec chmod 755 {} \;

# Regenerate images
php bin/magento catalog:images:resize
```

#### Issue 3: Categories Empty
```bash
# Reindex categories
php bin/magento indexer:reindex catalog_category_product
php bin/magento cache:flush
```

#### Issue 4: 404 Errors
```bash
# Regenerate URL rewrites
php bin/magento catalog:product:url:reindex
php bin/magento cache:flush
```

---

## Phase 8: Final Report & Documentation (15 minutes)

### 8.1 Generate Sync Report
```bash
cd /home/pim/public_html/webapp

cat > MAGENTO_SYNC_REPORT.md << 'REPORT'
# Magento Sync Report
Date: $(date)

## Summary
- Products Synced: X
- Categories Synced: X
- Images Synced: X
- Errors: X
- Duration: X minutes

## Verification
- Frontend Status: [PASS/FAIL]
- Product Count Match: [PASS/FAIL]
- Images Loading: [PASS/FAIL]
- Categories Active: [PASS/FAIL]

## Issues Encountered
[List any issues and resolutions]

## Next Steps
[List any remaining tasks]
REPORT
```

### 8.2 Update Action Plan
- Mark completed tasks
- Add any new issues discovered
- Update timeline for remaining work

---

## Success Criteria

Before ending the session, verify:

- [x] Akeneo PIM stable (90%+ test success)
- [ ] Magento frontend accessible (HTTP 200)
- [ ] Products visible on Magento (9,538 products)
- [ ] Categories functional (166 categories)
- [ ] Product images loading (28,200 images)
- [ ] Search working
- [ ] SEO metadata present
- [ ] No critical errors in logs
- [ ] Performance acceptable (< 3s page load)
- [ ] All caches enabled and warm

---

## Emergency Rollback Plan

If sync fails catastrophically:

```bash
# Restore Magento database backup
mysql -u magento_user -p magento_db < backup_before_sync.sql

# Clear import files
rm -rf $MAGENTO_PATH/var/import/*

# Reindex and cache clear
cd $MAGENTO_PATH
php bin/magento indexer:reindex
php bin/magento cache:flush
```

---

## Contact & Access Information

### Akeneo PIM
- URL: https://pim.technostationery.com
- User: apiconnector
- Pass: ApiConnector@2026!Secure

### Magento Admin
- URL: https://beta.technostationery.com/admin
- User: bot
- Pass: @dM1n$#@2o25B0T

### Database
- Host: 127.0.0.1:3307
- DB: akeneo_pim
- User: akeneo_pim
- Pass: LZVvxnY9vskG

---

## Notes

- Take database backup before starting sync
- Monitor system resources during import
- Keep terminal logs for troubleshooting
- Document any custom fixes applied
- Update this plan if steps change

---

**Plan Created**: 2026-05-01 00:09 CET  
**Last Updated**: 2026-05-01 00:09 CET  
**Status**: Ready for next session
