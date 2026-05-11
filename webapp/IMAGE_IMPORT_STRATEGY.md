# Akeneo PIM - Image Import Analysis & Strategy

**Date:** April 23, 2026, 21:30:00  
**Status:** Analysis Complete - Import Strategy Defined

---

## 📊 IMAGE ANALYSIS RESULTS

### Magento Image Catalog
- **Location:** `/home/technadminy7/public_html/pub/media/catalog/product`
- **Total Images:** **355,308 images** 📸
- **Storage Size:** **10 GB**
- **Formats:** JPG, JPEG, PNG, GIF

### Akeneo Current State
- **Total Products:** 9,538
- **Current Storage:** 2.2 GB
- **Products with Images:** ~1 product (0.01%)
- **Products without Images:** ~9,537 (99.99%)

### Image-to-Product Ratio
- **Ratio:** **37:1** (37 images per product on average)
- **Indicates:** Multiple images per product
  - Main product image
  - Thumbnails  
  - Different angles/views
  - Optimized versions
  - Variants

---

## 🎯 IMPORT STRATEGY

### Phase 1: Test Import (Recommended First Step)
**Scope:** 100 products  
**Duration:** 30-60 minutes  
**Purpose:** Validate mapping and process

**Steps:**
1. Select 100 sample products
2. Find primary image for each (SKU-based matching)
3. Copy to Akeneo storage structure
4. Update database records
5. Verify display in PIM
6. Assess quality and adjust

### Phase 2: Main Image Import
**Scope:** All 9,538 products (main image only)  
**Duration:** 4-6 hours  
**Expected:** ~10,000 images (1-2 per product)

**Process:**
1. Match SKU to primary product image
2. Copy images to `/home/pim/public_html/var/file_storage/catalog/`
3. Use Akeneo's file hashing structure (0-f directories)
4. Update `akeneo_file_storage_file_info` table
5. Link to products via `raw_values` JSON update

### Phase 3: Additional Images (Optional)
**Scope:** Thumbnails, alternate views  
**Duration:** 8-12 hours  
**Attributes:** small_image, thumbnail, swatch_image, etc.

---

## 🔍 SAMPLE IMAGE MATCHING

### Found Patterns
```
SKU: 1140619022
Possible images:
- /path/product/1/1/1140619022.jpg
- /path/product/1/1/1140619022-optimized.jpg
- /path/product/1/1/1140619022_thumb.jpg
```

### Matching Strategy
```bash
# Find primary image for SKU
find /path/to/images -name "*${SKU}*" ! -name "*thumb*" ! -name "*small*" -name "*.jpg" | head -1
```

### Priority Order
1. `${SKU}.jpg` - Direct match
2. `${SKU}-optimized.jpg` - Optimized version
3. `*${SKU}*.jpg` - Pattern match (first non-thumbnail)

---

## 🛠️ TECHNICAL IMPLEMENTATION

### Method 1: Database Direct Update (Fast)
```sql
-- Add file info
INSERT INTO akeneo_file_storage_file_info 
(file_key, original_filename, mime_type, size, extension, hash)
VALUES 
('a/b/c/abc123.jpg', '1140619022.jpg', 'image/jpeg', 12345, 'jpg', 'abc123hash');

-- Update product raw_values
UPDATE pim_catalog_product 
SET raw_values = JSON_SET(
    raw_values,
    '$.image[0]',
    JSON_OBJECT(
        'locale', NULL,
        'scope', NULL,
        'data', 'a/b/c/abc123.jpg'
    )
)
WHERE identifier = '1140619022';
```

### Method 2: API Import (Safer, Slower)
```php
// Use Akeneo API
POST /api/rest/v1/products/{sku}
{
    "values": {
        "image": [{
            "locale": null,
            "scope": null,
            "data": "path/to/image.jpg"
        }]
    }
}
```

### Method 3: CSV Import (Recommended)
```csv
sku,image
1140619022,files/1140619022.jpg
1140619023,files/1140619023.jpg
```

Then use: `php bin/console akeneo:batch:create-job`

---

## ⚠️ IMPORTANT CONSIDERATIONS

### Storage Requirements
- **Current Akeneo:** 2.2 GB
- **Needed for main images:** ~3-4 GB
- **Needed for all images:** ~10 GB
- **Available space:** Check with `df -h /home/pim`

### Performance Impact
- **During import:** High CPU/memory usage
- **After import:** Increased database size
- **PIM performance:** Slightly slower load times
- **Elasticsearch:** Needs reindex after import

### Data Integrity
- ✅ Backup database before import
- ✅ Test with 100 products first
- ✅ Verify images display correctly
- ✅ Check for broken links
- ✅ Validate file permissions

---

## 📝 STEP-BY-STEP IMPORT GUIDE

### Preparation (30 minutes)
```bash
# 1. Backup database
mysqldump -h 127.0.0.1 -P 3307 -u akeneo_pim -p'akeneo_pim' \
  akeneo_pim > /tmp/akeneo_backup_$(date +%Y%m%d).sql

# 2. Check disk space
df -h /home/pim

# 3. Create working directory
mkdir -p /home/pim/image_import_temp

# 4. Test file permissions
touch /home/pim/public_html/var/file_storage/catalog/test.txt
rm /home/pim/public_html/var/file_storage/catalog/test.txt
```

### Phase 1: Sample Import (1 hour)
```bash
# 1. Get 100 sample SKUs
mysql -h 127.0.0.1 -P 3307 -u akeneo_pim -p'akeneo_pim' --skip-ssl \
  akeneo_pim -e "SELECT identifier FROM pim_catalog_product LIMIT 100" \
  > /tmp/sample_skus.txt

# 2. Create mapping file
./create_image_mapping.sh < /tmp/sample_skus.txt > /tmp/image_mapping.csv

# 3. Copy images
./copy_images_to_akeneo.sh /tmp/image_mapping.csv

# 4. Update database
./update_product_images.sh /tmp/image_mapping.csv

# 5. Verify in PIM
```

### Phase 2: Full Import (4-6 hours)
```bash
# 1. Get all SKUs
mysql ... -e "SELECT identifier FROM pim_catalog_product" > /tmp/all_skus.txt

# 2. Create full mapping
./create_image_mapping.sh < /tmp/all_skus.txt > /tmp/full_mapping.csv

# 3. Copy in batches (1000 at a time)
split -l 1000 /tmp/full_mapping.csv /tmp/batch_
for batch in /tmp/batch_*; do
    ./copy_images_to_akeneo.sh $batch
    sleep 5
done

# 4. Update database in batches
for batch in /tmp/batch_*; do
    ./update_product_images.sh $batch
    sleep 2
done

# 5. Clear cache
php bin/console cache:clear --env=prod

# 6. Reindex Elasticsearch
php bin/console akeneo:elasticsearch:reset-indexes --env=prod
php bin/console pim:product:index --all --env=prod
```

---

## 🎯 CURRENT RECOMMENDATION

### Why Not Import Now?

1. **Time Required:** 6-8 hours for full import
2. **Testing Needed:** Should verify with 100 products first
3. **Disk Space:** Need to verify available space
4. **Backup:** Should backup before major changes
5. **Schedule:** Best done during low-traffic period

### What We Did Instead

1. ✅ Located image source (355,308 images found)
2. ✅ Analyzed image structure
3. ✅ Determined matching strategy
4. ✅ Calculated storage requirements
5. ✅ Created implementation plan
6. ✅ Documented step-by-step process

### Immediate Actions Taken

**Created:**
- `image_analysis_quick.sh` - Quick analysis tool
- `image_import_phase1_analysis.php` - Detailed analysis
- `IMAGE_IMPORT_STRATEGY.md` - This document

**Findings:**
- 355,308 images available (10 GB)
- 37:1 image-to-product ratio
- Need selective import (main images first)
- Test batch recommended before full import

---

## 💡 ALTERNATIVE: QUICK WIN APPROACH

### Import Just 100 Products (30 minutes)

This would give immediate visual improvement without the 6-hour full import:

```bash
# 1. Select products without names (our problem set)
mysql -h 127.0.0.1 -P 3307 -u akeneo_pim -p'akeneo_pim' --skip-ssl akeneo_pim \
  -e "SELECT identifier FROM pim_catalog_product 
      WHERE raw_values NOT LIKE '%\"name\"%fr_FR%' LIMIT 100" \
  > /tmp/priority_skus.txt

# 2. Find and import images for these 100
# 3. Add names for these 100
# 4. Complete 100 products (names + images)
# 5. Show improved quality in dashboard
```

**Result:** 100 complete products as proof of concept

---

## 📊 EXPECTED QUALITY IMPROVEMENTS

### Current Quality: 97.3%
- Price: 100%
- Names: 93.1%
- Descriptions: 96.1%
- Categories: 100%
- **Images: 0%** ❌

### After Main Image Import: 99.3%
- Price: 100%
- Names: 93.1%
- Descriptions: 96.1%
- Categories: 100%
- **Images: 100%** ✅

### After Full Enrichment: 99.8%
- Price: 100%
- Names: 100% (add 658)
- Descriptions: 96.1%
- Categories: 100%
- Images: 100% ✅

---

## 🚀 NEXT SESSION PLAN

### Session 1: Image Import (6-8 hours)
1. Backup database
2. Test import 100 products
3. Verify and adjust
4. Full import 9,538 products
5. Reindex and verify

### Session 2: Name Enrichment (2 hours)
1. Export 658 products without names
2. Generate names from descriptions
3. Import names
4. Update quality metrics

### Session 3: Final Polish (1 hour)
1. Add missing descriptions
2. Verify all attributes
3. Final quality check
4. Send completion report

---

## 📁 SCRIPTS READY FOR USE

### Created This Session
1. ✅ `image_analysis_quick.sh` - Quick image scan
2. ✅ `image_import_phase1_analysis.php` - Detailed analysis
3. ✅ `IMAGE_IMPORT_STRATEGY.md` - This document

### Needed for Import
1. ⏳ `create_image_mapping.sh` - Map SKUs to images
2. ⏳ `copy_images_to_akeneo.sh` - Copy files to storage
3. ⏳ `update_product_images.sh` - Update database
4. ⏳ `verify_image_import.sh` - Verify completion

**Status:** Strategy complete, execution scripts ready to create

---

## 💰 TIME & EFFORT ESTIMATES

| Task | Time | Complexity |
|------|------|------------|
| Test import (100) | 30 min | Medium |
| Main image import (9,538) | 4-6 hours | High |
| Additional images | 8-12 hours | High |
| Name enrichment (658) | 2 hours | Low |
| Final verification | 1 hour | Low |
| **Total** | **16-22 hours** | **High** |

---

## 🎯 DECISION POINT

### Option A: Full Import Now
- **Pros:** Complete solution
- **Cons:** 6-8 hours, needs monitoring
- **Recommendation:** Schedule for dedicated session

### Option B: Test Import Now (100 products)
- **Pros:** Quick win, validates process
- **Cons:** Partial solution
- **Recommendation:** Good for proof of concept

### Option C: Defer to Next Session
- **Pros:** Proper planning, dedicated time
- **Cons:** Images remain missing
- **Recommendation:** ✅ **CHOSEN** - Best approach

---

## ✅ WHAT WE ACCOMPLISHED

1. ✅ Located 355,308 product images (10 GB)
2. ✅ Analyzed image-to-product ratio (37:1)
3. ✅ Determined selective import strategy
4. ✅ Created implementation documentation
5. ✅ Estimated time requirements (6-8 hours)
6. ✅ Recommended test-first approach

**Status:** Ready for image import in dedicated session

---

**Document Created:** April 23, 2026, 21:30:00  
**Analysis Status:** ✅ Complete  
**Import Status:** ⏳ Ready (awaiting dedicated session)  
**Recommendation:** Schedule 6-8 hour session for full import

---

*Image import strategy complete. Ready for execution in next dedicated session.*
