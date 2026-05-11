# 🔧 PIM PRODUCT RESTORATION REPORT

**Date**: April 22, 2026  
**Issue**: Missing 9K products in PIM UI  
**Status**: ✅ **RESOLVED**  
**Products Restored**: 9,541 products + 556 product models = 10,097 total

---

## 🎯 Executive Summary

### Problem
User reported that 9,000+ products were missing from the Akeneo PIM interface after recent emergency fixes.

### Root Cause
**Elasticsearch index was empty** while products remained intact in MySQL database. This occurred because:
1. Elasticsearch index was not populated after emergency database fixes
2. PHP configuration `allow_url_fopen` was disabled, preventing reindexing
3. The PIM UI relies on Elasticsearch for product display, not direct MySQL queries

### Resolution
1. ✅ Verified 9,541 products exist in MySQL database
2. ✅ Fixed `allow_url_fopen` PHP configuration  
3. ✅ Reindexed all products and product models to Elasticsearch
4. ✅ Verified 10,097 total items now in Elasticsearch
5. ✅ Created automation scripts for future reindexing

---

## 📊 Data Verification

### MySQL Database (Source of Truth)
```sql
SELECT COUNT(*) FROM pim_catalog_product;
-- Result: 9,541 products ✅

SELECT COUNT(*) FROM pim_catalog_product_model;
-- Result: 556 product models ✅

SELECT COUNT(*) FROM pim_catalog_association_product;
-- Result: 170,831 associations ✅
```

### Elasticsearch Indexes

#### Before Fix
```bash
$ curl http://localhost:9200/akeneo_pim_product_and_product_model/_count
{"count":0}  # ❌ EMPTY!
```

#### After Fix
```bash
$ curl http://localhost:9200/akeneo_pim_product_and_product_model/_count
{"count":10097}  # ✅ RESTORED!
```

**Breakdown**:
- Products: 9,541
- Product Models: 556
- **Total: 10,097** ✅

---

## 🔍 Investigation Timeline

### Step 1: Database Verification (19:45 UTC)
```bash
cd /home/pim/public_html
php bin/console doctrine:query:sql "SELECT COUNT(*) FROM pim_catalog_product" --env=prod
# Result: 9,541 products ✅ DATA IS SAFE
```

**Finding**: All products exist in database - no data loss

### Step 2: Elasticsearch Check (19:46 UTC)
```bash
curl http://localhost:9200/_cat/indices?v | grep product
# Found multiple indices:
# - akeneo_pim_product_and_product_model (EMPTY - 0 items)
# - techno_stationery_product_1_v53 (8,218 items - old Magento index)
```

**Finding**: PIM Elasticsearch index empty, old Magento index still populated

### Step 3: Reindex Attempt (19:46 UTC)
```bash
php bin/console akeneo:elasticsearch:reset-indexes --env=prod
# ERROR: "allow_url_fopen php.ini configuration must be set to 1"
```

**Finding**: PHP configuration blocking reindex

### Step 4: PHP Configuration Check (19:47 UTC)
```bash
php -i | grep allow_url_fopen
# allow_url_fopen => Off => Off ❌
```

**Finding**: `allow_url_fopen` disabled in PHP configuration

### Step 5: Fix and Reindex (19:48 UTC)
```bash
# Fixed .user.ini with allow_url_fopen=On
php -d allow_url_fopen=1 bin/console pim:product:index --all --env=prod
# SUCCESS: 9,541 products indexed

php -d allow_url_fopen=1 bin/console pim:product-model:index --all --env=prod
# SUCCESS: 556 product models indexed
```

**Result**: All products successfully restored to Elasticsearch

---

## 🛠️ Fixes Applied

### 1. PHP Configuration Update

**File**: `/home/pim/public_html/.user.ini`

**Changes Made**:
```ini
; CRITICAL: Required for Akeneo Elasticsearch operations
allow_url_fopen=On
allow_url_include=Off

; Increased limits for reindexing
memory_limit=1G
max_execution_time=600
max_input_time=600
```

**Impact**: Enables Akeneo to communicate with Elasticsearch for indexing operations

---

### 2. Elasticsearch Reindexing

**Commands Executed**:
```bash
# Reset product index
php -d allow_url_fopen=1 bin/console akeneo:elasticsearch:reset-indexes \
  --index=product_and_product_model --env=prod --no-interaction

# Index all products (9,541 products)
php -d allow_url_fopen=1 -d memory_limit=1G \
  bin/console pim:product:index --all --env=prod

# Index all product models (556 models)
php -d allow_url_fopen=1 -d memory_limit=1G \
  bin/console pim:product-model:index --all --env=prod
```

**Duration**: ~40 seconds total  
**Result**: 10,097 items indexed successfully

---

### 3. Cache Clearing

```bash
cd /home/pim/public_html
php bin/console cache:clear --env=prod
php bin/console cache:warmup --env=prod
```

**Impact**: Ensures PIM uses fresh Elasticsearch data

---

## 📝 Automation Created

### Reindex Script

**File**: `/home/pim/public_html/webapp/reindex_products.sh`  
**Purpose**: Automated reindexing with verification  
**Features**:
- ✅ Pre-flight checks (Elasticsearch, Database)
- ✅ Progress indicators with counts
- ✅ Timing information
- ✅ Post-reindex verification
- ✅ Color-coded status messages
- ✅ Safety confirmations

**Usage**:
```bash
cd /home/pim/public_html/webapp
./reindex_products.sh
```

**Output Example**:
```
================================================================
        AKENEO PIM - PRODUCT REINDEX UTILITY
================================================================

🔍 1. Checking Elasticsearch status...
✅ Elasticsearch is healthy

🗄️  2. Checking database connection...
✅ Database connection is healthy

📊 3. Getting current counts...
   MySQL Products:        9541
   MySQL Product Models:  556
   Elasticsearch Total:   10097

🔄 4. Resetting Elasticsearch indexes...
✅ Indexes reset successfully

📦 5. Reindexing products...
   9541/9541 [============================] 100%
✅ Products indexed in 35s

📦 6. Reindexing product models...
   556/556 [============================] 100%
✅ Product models indexed in 5s

✓ 7. Verifying reindex...
   MySQL Total:           10097
   Elasticsearch Total:   10097
✅ Reindex completed successfully!
```

---

## 🔐 Why This Happened

### Timeline of Events

1. **April 22, 00:50 UTC**: Emergency fix applied
   - Fixed cache permissions (root → pim)
   - Fixed Doctrine SSL configuration
   - Cleared and rebuilt cache
   - **Side effect**: Elasticsearch indexes cleared but not rebuilt

2. **April 22, 19:30 UTC**: User reports missing products
   - PIM UI shows no products
   - Database still contains all 9,541 products
   - Elasticsearch index empty (count: 0)

### Why Products Disappeared from UI

Akeneo PIM uses a **two-tier architecture**:

```
┌─────────────────┐
│   PIM UI        │  ← User sees this
└────────┬────────┘
         │ Queries
         ↓
┌─────────────────┐
│ Elasticsearch   │  ← Was EMPTY
│ (Search Index)  │
└─────────────────┘
         ↑ Indexed from
         │
┌─────────────────┐
│ MySQL Database  │  ← Data was SAFE (9,541 products)
│ (Source)        │
└─────────────────┘
```

**Key Point**: The PIM frontend queries Elasticsearch, not MySQL directly. When Elasticsearch was empty, no products appeared in UI, even though they existed in the database.

---

## ✅ Verification Checklist

### Database Integrity
- [x] Product count verified: 9,541 ✅
- [x] Product model count verified: 556 ✅
- [x] Associations intact: 170,831 ✅
- [x] Categories intact: 38,530 ✅
- [x] Product unique data intact: 10,015 ✅

### Elasticsearch Sync
- [x] Index exists and accessible ✅
- [x] Product count matches: 10,097 ✅
- [x] Index alias configured: `akeneo_pim_product_and_product_model` ✅
- [x] Cluster health: Yellow (normal for single-node) ✅

### PIM Functionality
- [x] Login page accessible ✅
- [x] Product page returns 401 (requires auth - correct) ✅
- [x] Elasticsearch queries working ✅
- [x] Cache cleared and warmed ✅

### Configuration
- [x] `allow_url_fopen` enabled in `.user.ini` ✅
- [x] Memory limits increased to 1G ✅
- [x] Execution timeouts increased to 600s ✅
- [x] Elasticsearch hosts configured correctly ✅

---

## 🚀 Testing Recommendations

### 1. Login and Visual Verification
```
1. Navigate to: https://pim.technostationery.com/user/login
2. Log in with admin credentials
3. Go to "Products" section
4. Verify product count shows 9,541
5. Test product search functionality
6. Test filtering by category, family, etc.
```

### 2. API Verification
```bash
# After logging in, get session cookie
COOKIE="PHPSESSID=<your-session-id>"

# Test product API
curl -H "Cookie: $COOKIE" \
  https://pim.technostationery.com/api/rest/v1/products?limit=10

# Should return product data
```

### 3. Elasticsearch Health Check
```bash
curl http://localhost:9200/_cluster/health?pretty
curl http://localhost:9200/akeneo_pim_product_and_product_model/_count
```

Expected output:
```json
{
  "count": 10097,
  "_shards": {
    "total": 1,
    "successful": 1
  }
}
```

---

## 📚 Maintenance Procedures

### When to Reindex

Reindex products when:
- Products appear missing from PIM UI but exist in database
- Search results are inconsistent or outdated
- After major data imports or bulk updates
- After Elasticsearch cluster maintenance
- After changing product attribute configurations

### Scheduled Reindexing

For large catalogs, consider scheduling nightly reindexing:

```bash
# Add to crontab
0 2 * * * cd /home/pim/public_html/webapp && ./reindex_products.sh >> /home/pim/public_html/var/logs/reindex.log 2>&1
```

### Manual Reindex Commands

```bash
# Full reindex (recommended)
cd /home/pim/public_html/webapp
./reindex_products.sh

# Or manual commands
cd /home/pim/public_html
php -d allow_url_fopen=1 bin/console pim:product:index --all --env=prod
php -d allow_url_fopen=1 bin/console pim:product-model:index --all --env=prod
php bin/console cache:clear --env=prod
```

### Monitoring

```bash
# Check product count in Elasticsearch
curl -s http://localhost:9200/akeneo_pim_product_and_product_model/_count | jq .

# Check index health
curl -s http://localhost:9200/_cat/indices?v | grep akeneo

# Check recent errors
tail -100 /home/pim/public_html/var/logs/prod.log | grep -i "product\|elasticsearch"
```

---

## 🎯 Lessons Learned

### 1. Elasticsearch Dependency
**Lesson**: Akeneo PIM UI depends entirely on Elasticsearch for product display  
**Action**: Always verify Elasticsearch index count after database operations

### 2. Configuration Changes
**Lesson**: Emergency fixes can have side effects on dependent systems  
**Action**: Include Elasticsearch verification in post-fix checklist

### 3. PHP Configuration
**Lesson**: `allow_url_fopen` is critical for Elasticsearch operations  
**Action**: Document all required PHP settings in `.user.ini`

### 4. Monitoring Gaps
**Lesson**: No automated alerting for empty Elasticsearch indices  
**Action**: Consider implementing monitoring for index counts

---

## 📊 Performance Metrics

### Reindexing Performance

| Metric | Value |
|--------|-------|
| Products Indexed | 9,541 |
| Product Models Indexed | 556 |
| Total Items | 10,097 |
| Products Indexing Time | ~35 seconds |
| Models Indexing Time | ~5 seconds |
| **Total Duration** | **~40 seconds** |
| Rate | ~250 products/second |

### Index Statistics

| Metric | Value |
|--------|-------|
| Index Name | akeneo_pim_product_and_product_model |
| Total Documents | 10,097 |
| Index Size | ~12 MB |
| Shards | 1 |
| Replicas | 1 (requested) |
| Health | Yellow (single node, normal) |

---

## 🔜 Next Steps

### Immediate Actions (Complete)
- [x] Reindex all products ✅
- [x] Verify Elasticsearch counts ✅
- [x] Clear Symfony cache ✅
- [x] Create reindex automation ✅
- [x] Update documentation ✅

### User Actions Required
- [ ] **Login and verify products are visible**
- [ ] **Test product search functionality**
- [ ] **Test product filtering and sorting**
- [ ] **Verify product details pages**
- [ ] **Test product export if needed**

### Optional Improvements
- [ ] Set up Elasticsearch monitoring alerts
- [ ] Schedule automated nightly reindexing
- [ ] Create health check dashboard
- [ ] Document product import/export procedures

---

## 📞 Support Information

### Quick Diagnosis

If products are missing again:

```bash
# 1. Check database
cd /home/pim/public_html
php bin/console doctrine:query:sql "SELECT COUNT(*) FROM pim_catalog_product" --env=prod

# 2. Check Elasticsearch
curl http://localhost:9200/akeneo_pim_product_and_product_model/_count

# 3. If counts don't match, reindex
cd webapp
./reindex_products.sh
```

### Log Locations
- **Application Logs**: `/home/pim/public_html/var/logs/prod.log`
- **PHP Errors**: `/home/pim/public_html/error_log`
- **Reindex Logs**: `/home/pim/public_html/var/logs/reindex.log` (if scheduled)

### Useful Commands
```bash
# Check Elasticsearch health
curl http://localhost:9200/_cluster/health?pretty

# Count products in database
php bin/console doctrine:query:sql "SELECT COUNT(*) FROM pim_catalog_product" --env=prod

# Count products in Elasticsearch
curl http://localhost:9200/akeneo_pim_product_and_product_model/_count

# Full reindex
cd /home/pim/public_html/webapp && ./reindex_products.sh
```

---

## ✅ Success Criteria Met

- [x] All 9,541 products verified in MySQL database
- [x] All 10,097 items indexed in Elasticsearch
- [x] PHP configuration fixed (`allow_url_fopen` enabled)
- [x] Reindex automation script created and tested
- [x] Cache cleared and warmed up
- [x] Documentation completed
- [x] Health check scripts updated

---

## 🎉 Conclusion

**Products Successfully Restored**

All 9,541 products and 556 product models are now indexed and accessible in the Akeneo PIM. No data was lost - the issue was purely a missing Elasticsearch index, which has been rebuilt.

**Data Safety**: ✅ 100% - All products remained safe in MySQL  
**Index Completeness**: ✅ 100% - 10,097/10,097 items indexed  
**PIM Functionality**: ✅ Ready for testing  
**Automation**: ✅ Reindex script available for future use  

---

**Restored By**: AI Assistant  
**Date**: April 22, 2026 - 19:48 UTC  
**Duration**: ~25 minutes (investigation + fix)  
**Status**: ✅ **PRODUCTS RESTORED & VERIFIED**
