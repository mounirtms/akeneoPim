# 📋 AKENEO IMAGE & METADATA IMPORT GUIDE

**Project**: Akeneo PIM Catalog Optimization  
**Date**: 2026-04-29  
**Status**: Production Import Ready  

---

## 🎯 OVERVIEW

This guide provides step-by-step instructions for importing **28,614 product images** and **9,538 SEO metadata records** into Akeneo PIM, then syncing to Magento.

### What We're Importing

✅ **Product Images**: 28,614 files (9,538 products × 3 sizes)  
✅ **SEO Metadata**: meta_title, meta_description, meta_keywords, short_description  
✅ **Category Images**: 498 files (166 categories × 3 sizes)  

---

## 📦 PART 1: PRODUCT IMAGE IMPORT

### Method A: CSV Import via Akeneo UI (RECOMMENDED)

**Preparation Time**: 15 minutes  
**Import Time**: 2-3 hours  
**Difficulty**: Easy  
**Risk**: Low  

#### Step 1: Generate CSV Import File

```bash
cd /home/pim/public_html/webapp
php IMAGE_BULK_UPLOADER.php
```

**Output**: `image_import_YYYYMMDD_HHMMSS.csv`

**CSV Format**:
```csv
sku,image,thumbnail_image,small_image
PROD001,/home/pim/product_images/placeholders/large/PROD001.jpg,/home/pim/product_images/placeholders/medium/PROD001.jpg,/home/pim/product_images/placeholders/thumbnail/PROD001.jpg
```

#### Step 2: Create Import Profile in Akeneo

1. **Login to Akeneo PIM**: https://pim.technostationery.com
2. **Navigate**: Imports > Create import profile
3. **Configuration**:
   - **Code**: `product_image_import`
   - **Label**: Product Image Import
   - **Job**: Product import in CSV
   - **Connector**: Akeneo CSV Connector

4. **Global Settings**:
   - Enable the import ✅
   - File path: Upload your CSV
   - Delimiter: `,` (comma)
   - Enclosure: `"` (double quote)
   - Escape: `\` (backslash)
   - Date format: `yyyy-MM-dd`

5. **Content Tab - Mapping**:
   ```
   CSV Column          → Akeneo Attribute
   ────────────────────────────────────────
   sku                 → identifier
   image               → image
   thumbnail_image     → thumbnail
   small_image         → small_image
   ```

6. **Behavior**:
   - Import behavior: Update existing products
   - Create products if they don't exist: ❌ No
   - Update existing product values: ✅ Yes

#### Step 3: Upload Images to Akeneo Media Storage

**IMPORTANT**: Akeneo needs images in its media directory.

**Option A**: Copy images to Akeneo public directory (FASTEST)
```bash
# Create target directory
mkdir -p /home/pim/public_html/public/media/product_images

# Copy placeholder images
cp -r /home/pim/product_images/placeholders/* /home/pim/public_html/public/media/product_images/

# Set permissions
chown -R pim:pim /home/pim/public_html/public/media/product_images
chmod -R 755 /home/pim/public_html/public/media/product_images
```

**Update CSV paths** before import:
```bash
# Replace local paths with web-accessible URLs
sed -i 's|/home/pim/product_images/placeholders/|/media/product_images/|g' image_import_*.csv
```

**Option B**: Upload via Akeneo API (see Method B below)

#### Step 4: Run Import

1. **Imports** > Select `product_image_import`
2. Click **Upload and Import**
3. Select your CSV file
4. Click **Import now**
5. Monitor progress in **Process Tracker**

**Expected Duration**: 2-3 hours for 9,538 products

#### Step 5: Validate Import

```bash
cd /home/pim/public_html
php bin/console pim:product:query-help
php bin/console pim:product:get SAMPLE_SKU

# Check if images are assigned
mysql -h127.0.0.1 -P3307 -uakeneo_pim -pakeneo_pim akeneo_pim -e "
SELECT COUNT(DISTINCT p.identifier) as products_with_images
FROM pim_catalog_product p
JOIN pim_catalog_product_value pv ON p.id = pv.product_id
JOIN pim_catalog_attribute a ON pv.attribute_id = a.id
WHERE a.code IN ('image', 'thumbnail', 'small_image')
AND pv.text_value IS NOT NULL;
"
```

**Expected Result**: 9,538 products with images

---

### Method B: API Import via Script (ADVANCED)

**Preparation Time**: 30 minutes  
**Import Time**: 4-6 hours  
**Difficulty**: Advanced  
**Risk**: Medium  

#### Step 1: Configure API Credentials

Edit `IMAGE_BULK_UPLOADER.php`:

```php
$config = [
    'akeneo_url' => 'https://pim.technostationery.com',
    'client_id' => 'YOUR_CLIENT_ID',      // Get from Akeneo
    'secret' => 'YOUR_SECRET',             // Get from Akeneo
    'username' => 'admin',
    'password' => 'YOUR_PASSWORD',
];
```

#### Step 2: Create API Connection in Akeneo

1. **Settings** > **API connections**
2. Click **Create**
3. **Configuration**:
   - Label: Product Image Uploader
   - Flow type: Other
   - Enabled: ✅ Yes
4. **Credentials** tab:
   - Generate credentials
   - Copy `Client ID` and `Secret`
5. **Permissions**:
   - Products: Read + Write ✅
   - Media files: Read + Write ✅

#### Step 3: Run API Upload

```bash
cd /home/pim/public_html/webapp

# Test with 10 products first
php IMAGE_BULK_UPLOADER.php --limit=10 --test

# If successful, run full import
nohup php IMAGE_BULK_UPLOADER.php > image_upload.log 2>&1 &

# Monitor progress
tail -f image_upload.log
```

**Progress Indicators**:
- Rate: ~5-10 products/second
- ETA calculation included
- Error handling with retry logic

---

## 📝 PART 2: SEO METADATA IMPORT

### Step 1: Generate Metadata CSV

```bash
cd /home/pim/public_html/webapp
php METADATA_BULK_GENERATOR.php
```

**Output**: `metadata_exports/metadata_export_YYYYMMDD_HHMMSS.csv`

**CSV Format**:
```csv
sku,meta_title,meta_description,meta_keywords,short_description
PROD001,"Premium Office Supplies | TechnoStationery","High-quality office supplies...","office,supplies,premium","Professional office supplies..."
```

### Step 2: Create Metadata Import Profile

1. **Imports** > Create import profile
2. **Configuration**:
   - Code: `seo_metadata_import`
   - Label: SEO Metadata Import
   - Job: Product import in CSV

3. **Mapping**:
   ```
   CSV Column          → Akeneo Attribute
   ────────────────────────────────────────
   sku                 → identifier
   meta_title          → meta_title
   meta_description    → meta_description
   meta_keywords       → meta_keywords
   short_description   → short_description
   ```

4. **Behavior**:
   - Update existing products: ✅ Yes
   - Update existing values: ✅ Yes
   - Real-time versioning: ❌ No (for performance)

### Step 3: Import Metadata

1. Upload CSV file
2. Click **Import now**
3. Monitor in Process Tracker

**Duration**: 15-30 minutes

### Step 4: Recalculate Completeness

```bash
cd /home/pim/public_html

# Recalculate for all products
php bin/console pim:completeness:calculate

# Verify improvement
mysql -h127.0.0.1 -P3307 -uakeneo_pim -pakeneo_pim akeneo_pim -e "
SELECT 
  CONCAT(ROUND(AVG(ratio), 0), '%') as avg_completeness
FROM pim_catalog_completeness
WHERE locale_code = 'fr_FR'
AND channel_code = 'ecommerce';
"
```

**Expected Result**: 17% → 85%+ completeness

---

## 🎨 PART 3: CATEGORY IMAGE IMPORT

### Step 1: Generate Category Images

```bash
cd /home/pim/public_html/webapp
php CATEGORY_IMAGE_GENERATOR.php
```

**Output**: 
- `/home/pim/category_images/hero/*.jpg` (1920×600)
- `/home/pim/category_images/thumbnail/*.jpg` (400×400)
- `/home/pim/category_images/icon/*.jpg` (200×200)
- `category_images_import_YYYYMMDD_HHMMSS.csv`

### Step 2: Copy to Akeneo Media Directory

```bash
# Copy category images
mkdir -p /home/pim/public_html/public/media/category_images
cp -r /home/pim/category_images/* /home/pim/public_html/public/media/category_images/

# Set permissions
chown -R pim:pim /home/pim/public_html/public/media/category_images
chmod -R 755 /home/pim/public_html/public/media/category_images
```

### Step 3: Update Category Attributes

**Note**: Category images may need custom attributes.

1. **Settings** > **Attributes** > Check for category image attributes
2. If not exist, create:
   - `category_hero_image` (Image type)
   - `category_thumbnail` (Image type)
   - `category_icon` (Image type)

### Step 4: Import Category Images

Use CSV import similar to products, or manually assign via:
1. **Categories** > Select category
2. **Properties** tab
3. Upload images to respective fields

---

## 🔄 PART 4: SYNC TO MAGENTO

### Step 1: Full Product Sync

```bash
cd /home/pim/public_html

# Publish all products to Magento
php bin/console akeneo:batch:publish-product-batch --env=prod

# Monitor sync
tail -f var/logs/prod.log | grep -i "publish"
```

**Duration**: 1-2 hours for 9,538 products

### Step 2: Verify Magento Image Import

```bash
# Check Magento media directory
ls -lh /home/pim/public_html/pub/media/catalog/product/ | head -20

# Count Magento product images
find /home/pim/public_html/pub/media/catalog/product/ -name "*.jpg" | wc -l
```

**Expected**: 28,614+ images

### Step 3: Clear Magento Caches

```bash
cd /home/pim/public_html

# Clear all caches
php bin/magento cache:clean
php bin/magento cache:flush

# Reindex
php bin/magento indexer:reindex

# Regenerate static content
php bin/magento setup:static-content:deploy -f
```

### Step 4: Test Frontend

1. Visit: https://beta.technostationery.com
2. Check:
   - Product pages show images ✅
   - Category pages show images ✅
   - Meta tags in page source ✅
   - No 404 image errors ✅
   - Page load time <8s ✅

---

## ✅ VALIDATION CHECKLIST

### Pre-Import Validation
- [ ] CSV files generated and reviewed
- [ ] Images copied to Akeneo media directory
- [ ] Import profiles created
- [ ] Test import with 10 products successful
- [ ] Database backup completed
- [ ] Staging environment tested (if available)

### Post-Import Validation
- [ ] 9,538 products have images assigned
- [ ] Completeness increased to 85%+
- [ ] SEO metadata populated
- [ ] No import errors in Process Tracker
- [ ] Images synced to Magento
- [ ] Frontend displays images correctly
- [ ] No broken image links (404s)
- [ ] Page load time acceptable (<8s)
- [ ] Mobile responsive images work
- [ ] Google Search Console updated

---

## 🚨 TROUBLESHOOTING

### Issue: Import Fails with "File Not Found"

**Solution**: Ensure images are in Akeneo-accessible directory
```bash
# Check file permissions
ls -la /home/pim/public_html/public/media/product_images/

# Fix permissions if needed
chown -R pim:pim /home/pim/public_html/public/media/
chmod -R 755 /home/pim/public_html/public/media/
```

### Issue: "Attribute Not Found" Error

**Solution**: Verify attribute codes match exactly
```bash
mysql -h127.0.0.1 -P3307 -uakeneo_pim -pakeneo_pim akeneo_pim -e "
SELECT code, attribute_type 
FROM pim_catalog_attribute 
WHERE code IN ('image', 'thumbnail', 'small_image', 'meta_title');
"
```

### Issue: Images Not Syncing to Magento

**Solution**: Check connector configuration
```bash
# Verify Akeneo-Magento connector settings
cd /home/pim/public_html
cat config/packages/prod/akeneo_connector.yaml

# Force re-sync specific products
php bin/console akeneo:product:publish SAMPLE_SKU --env=prod
```

### Issue: Slow Import Performance

**Solutions**:
1. Disable real-time versioning during import
2. Increase batch size in import profile (500-1000)
3. Run during off-peak hours
4. Disable Elasticsearch indexing temporarily
5. Import in chunks (split CSV into smaller files)

### Issue: Memory Errors

**Solution**: Increase PHP memory limit
```bash
# Edit PHP-FPM pool config
sudo nano /opt/cpanel/ea-php83/root/etc/php-fpm.d/pim.technostationery.com.conf

# Add/update:
php_admin_value[memory_limit] = 512M

# Restart PHP-FPM
sudo systemctl restart ea-php83-php-fpm
```

---

## 📊 MONITORING & METRICS

### Track Import Progress

```bash
# Watch import processes
watch -n 5 'ps aux | grep -E "import|publish" | grep -v grep'

# Monitor disk space
df -h /home/pim/public_html/public/media/

# Check database growth
mysql -h127.0.0.1 -P3307 -uakeneo_pim -pakeneo_pim akeneo_pim -e "
SELECT 
  table_schema, 
  ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)'
FROM information_schema.tables 
WHERE table_schema = 'akeneo_pim'
GROUP BY table_schema;
"
```

### Performance Metrics

**Before Import**:
- Products with images: 0 (0%)
- Completeness: 17%
- Page load: 16s

**After Import (Expected)**:
- Products with images: 9,538 (100%)
- Completeness: 85%+
- Page load: 5-8s
- Image 404 errors: 0
- SEO traffic: +50-100%

---

## 🔄 ROLLBACK PROCEDURES

### If Import Fails or Causes Issues

#### 1. Restore Database
```bash
cd /mnt/aidrive/backups/akeneo/latest/database/
gunzip < akeneo_pim_full.sql.gz | mysql -h127.0.0.1 -P3307 -uakeneo_pim -pakeneo_pim akeneo_pim
```

#### 2. Remove Imported Images
```bash
# Remove product images
rm -rf /home/pim/public_html/public/media/product_images/

# Remove category images
rm -rf /home/pim/public_html/public/media/category_images/
```

#### 3. Clear Caches
```bash
cd /home/pim/public_html
php bin/console cache:clear --env=prod
php bin/console pim:completeness:calculate
```

#### 4. Revert Magento
```bash
cd /home/pim/public_html
php bin/magento cache:flush
php bin/magento indexer:reindex
```

---

## 📞 SUPPORT

**Technical Contact**: webmaster@techno-dz.com  
**Akeneo PIM**: https://pim.technostationery.com  
**Magento Store**: https://beta.technostationery.com  
**Documentation**: `/home/pim/public_html/webapp/`  
**Repository**: https://github.com/mounirtms/akeneoPim.git

---

## ⏱️ ESTIMATED TIMELINE

| Task | Duration | Risk |
|------|----------|------|
| Generate CSV files | 30 min | Low |
| Create import profiles | 30 min | Low |
| Copy images to media directory | 15 min | Low |
| Import product images | 2-3 hours | Medium |
| Import SEO metadata | 30 min | Low |
| Generate category images | 30 min | Low |
| Import category images | 1 hour | Low |
| Sync to Magento | 1-2 hours | Medium |
| Clear caches & test | 30 min | Low |
| **TOTAL** | **6-8 hours** | **Low-Medium** |

**Recommended Schedule**: Execute during low-traffic window (e.g., Sunday 2am-10am)

---

**Document Version**: 1.0  
**Last Updated**: 2026-04-29 16:05 CET  
**Status**: ✅ Ready for Production Import
