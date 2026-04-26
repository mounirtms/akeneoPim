# Akeneo → Magento 2 Beta Sync - Phased Implementation Plan

**Date**: 2026-04-26  
**Status**: Ready to Execute (Awaiting Magento Beta URL)  
**Branch**: oldbranch  

---

## 🎯 Objectives

Synchronize 9,538 products from Akeneo PIM to Magento 2 Beta using REST API integration.

---

## 📊 Current State

### Akeneo PIM (Source)
- ✅ **Status**: Stable and Production Ready
- ✅ **Products**: 9,538 products
- ✅ **Categories**: 166 categories
- ✅ **Attributes**: 112 attributes
- ✅ **Families**: 18 product families
- ✅ **Channels**: 3 (ecommerce, mobile, print)
- ✅ **API**: Functional and tested
- ✅ **Authentication**: Working (testadmin/testpass, apiconnector)

### Magento 2 Beta (Target)
- ⏳ **URL**: [AWAITING] - Need Beta instance URL
- ✅ **Admin Credentials**: bot / @dM1n$#@2o25B0T
- ⏳ **API Token**: To be generated
- ⏳ **Current Catalog**: Empty (confirmed by user)
- ⏳ **Status**: Need to verify instance accessibility

---

## 🔄 Phase 1: Pre-Sync Preparation (1-2 hours)

### Task 1.1: Verify Magento Beta Access ⏳
**Priority**: HIGH  
**Blocker**: Yes

**Actions**:
```bash
# Once Magento URL provided, test access
curl -I "https://[MAGENTO-BETA-URL]/"
curl -I "https://[MAGENTO-BETA-URL]/admin"
```

**Success Criteria**:
- [ ] Magento Beta URL accessible (HTTP 200/302)
- [ ] Admin panel accessible
- [ ] Can login with bot credentials

### Task 1.2: Generate Magento API Token ⏳
**Priority**: HIGH  
**Blocker**: Yes

**Actions**:
1. Login to Magento Admin: `https://[MAGENTO-URL]/admin`
2. Navigate to: System → Integrations → Add New Integration
3. Create integration: "Akeneo PIM Sync"
4. Grant permissions:
   - ✅ Catalog (all)
   - ✅ Products (all)
   - ✅ Categories (all)
   - ✅ Attributes (all)
5. Activate integration
6. Copy tokens:
   - Consumer Key
   - Consumer Secret
   - Access Token
   - Access Token Secret

**OR** Generate via CLI:
```bash
# On Magento server
php bin/magento admin:user:create \
  --admin-user="api_bot" \
  --admin-password="SecurePassword123!" \
  --admin-email="api@pim.technostationery.com" \
  --admin-firstname="API" \
  --admin-lastname="Bot"

# Generate token
php bin/magento integration:create \
  --name="akeneo_sync" \
  --email="api@pim.technostationery.com"
```

**Success Criteria**:
- [ ] API token generated
- [ ] Token documented in CREDENTIALS_MASTER_DOCUMENT.md
- [ ] Test API call succeeds

### Task 1.3: Test Magento API Connectivity ⏳
**Priority**: HIGH

**Actions**:
```bash
# Test authentication
curl -X GET "https://[MAGENTO-URL]/rest/V1/products?searchCriteria[pageSize]=1" \
  -H "Authorization: Bearer [ACCESS_TOKEN]"

# Test product creation (dry run)
curl -X POST "https://[MAGENTO-URL]/rest/V1/products" \
  -H "Authorization: Bearer [ACCESS_TOKEN]" \
  -H "Content-Type: application/json" \
  -d '{"product":{"sku":"TEST-001","name":"Test Product"}}'
```

**Success Criteria**:
- [ ] GET request returns valid JSON
- [ ] POST request accepted (or returns validation errors)
- [ ] No authentication errors

### Task 1.4: Map Akeneo Data to Magento Schema ⏳
**Priority**: HIGH

**Mapping Requirements**:

#### Attribute Mapping
| Akeneo Attribute | Magento Attribute | Type | Required |
|------------------|-------------------|------|----------|
| sku | sku | text | Yes |
| name | name | text | Yes |
| description | description | textarea | No |
| price | price | decimal | Yes |
| image | image | media_image | No |
| categories | category_ids | array | No |
| family | attribute_set_id | int | Yes |

#### Category Mapping Strategy
- Option A: Flat import (all 166 categories at root)
- Option B: Maintain hierarchy (parse parent_code)
- **Recommended**: Option B with hierarchy

#### Family to Attribute Set Mapping
- Map Akeneo families (18) to Magento attribute sets
- Default: Create matching attribute sets in Magento

**Success Criteria**:
- [ ] Mapping document created
- [ ] Required fields identified
- [ ] Default values defined

---

## 🔄 Phase 2: Pilot Sync (30 minutes - 1 hour)

### Task 2.1: Create Sync Script ⏳
**Priority**: HIGH

**Script Location**: `/home/pim/public_html/webapp/magento_sync.php`

**Key Features**:
- Fetch products from Akeneo API
- Transform data to Magento format
- Send to Magento API
- Error handling and logging
- Progress tracking

**Success Criteria**:
- [ ] Script created and tested
- [ ] Dry-run mode working
- [ ] Logging functional

### Task 2.2: Sync 10 Test Products ⏳
**Priority**: HIGH

**Actions**:
```bash
# Run pilot sync
php webapp/magento_sync.php --limit=10 --dry-run
php webapp/magento_sync.php --limit=10 --execute
```

**Test Products Selection**:
- 2 simple products (no variants)
- 2 products with images
- 2 products with categories
- 2 products from different families
- 2 products with special characters in names

**Success Criteria**:
- [ ] 10 products successfully created in Magento
- [ ] Images transferred correctly
- [ ] Categories assigned
- [ ] Attributes mapped properly
- [ ] No duplicate SKUs
- [ ] Magento admin shows products

### Task 2.3: Verify Pilot Results ⏳
**Priority**: HIGH

**Verification Steps**:
1. Check Magento Admin → Catalog → Products
2. Verify product count: 10
3. Open each product and check:
   - ✅ Name correct
   - ✅ SKU correct
   - ✅ Description present
   - ✅ Price correct
   - ✅ Image displayed
   - ✅ Categories assigned
   - ✅ Attributes populated

**Success Criteria**:
- [ ] All 10 products visible
- [ ] Data accuracy: 100%
- [ ] No errors in Magento logs
- [ ] Frontend displays products

---

## 🔄 Phase 3: Batch Sync Strategy (2-4 hours)

### Task 3.1: Design Batch Processing ⏳
**Priority**: HIGH

**Batch Strategy**:
- **Batch Size**: 100 products per batch
- **Total Batches**: 96 batches (9,538 ÷ 100)
- **Interval**: 5 seconds between batches
- **Estimated Time**: ~8-10 minutes for all products

**Rate Limiting**:
```php
// Magento API rate limits (typical)
// - 20 requests per 10 seconds
// - Adjust batch size accordingly

$batchSize = 100;
$delayBetweenBatches = 5; // seconds
```

**Success Criteria**:
- [ ] Batch logic implemented
- [ ] Progress tracking added
- [ ] Resume capability (in case of failure)
- [ ] Logging per batch

### Task 3.2: Handle Special Cases ⏳
**Priority**: MEDIUM

**Special Scenarios**:

1. **Products with Variants**
   - Configurable products in Magento
   - Parent-child relationships
   - Action: Sync simple products first, then configurables

2. **Products Missing Required Fields**
   - Handle products without prices
   - Handle products without images
   - Action: Log and skip, or use defaults

3. **Category Hierarchy**
   - Create parent categories first
   - Then child categories
   - Action: Sort categories by depth

4. **Large Images**
   - Compress before upload
   - Action: Use Akeneo's cached thumbnails

**Success Criteria**:
- [ ] Edge cases documented
- [ ] Fallback logic implemented
- [ ] Error handling robust

---

## 🔄 Phase 4: Full Sync Execution (2-3 hours)

### Task 4.1: Pre-Flight Checks ✅
**Priority**: HIGH

**Checklist**:
- [x] Akeneo system stable
- [x] Database verified (9,538 products)
- [x] API credentials valid
- [ ] Magento Beta accessible
- [ ] Magento API token active
- [ ] Backup created (if any existing data)
- [ ] Sync script tested (pilot 10 products)
- [ ] Monitoring in place

### Task 4.2: Execute Full Sync ⏳
**Priority**: HIGH

**Execution Plan**:

**Step 1: Sync Categories (166 total)**
```bash
php webapp/magento_sync.php --categories-only
```
- Estimated time: 2-3 minutes
- Verification: Check Magento category tree

**Step 2: Sync Attribute Sets/Families (18 total)**
```bash
php webapp/magento_sync.php --families-only
```
- Estimated time: 1 minute
- Verification: Check Magento attribute sets

**Step 3: Sync Products (9,538 total)**
```bash
# Dry run first
php webapp/magento_sync.php --products --dry-run

# Real sync
php webapp/magento_sync.php --products --batch-size=100 --delay=5

# OR use background job
nohup php webapp/magento_sync.php --products --batch-size=100 > var/logs/magento_sync.log 2>&1 &
```
- Estimated time: 8-10 minutes
- Monitor: `tail -f var/logs/magento_sync.log`

**Success Criteria**:
- [ ] All 166 categories synced
- [ ] All 18 families/attribute sets created
- [ ] All 9,538 products synced
- [ ] Error rate < 1%
- [ ] No duplicate SKUs

### Task 4.3: Post-Sync Verification ⏳
**Priority**: HIGH

**Verification Commands**:

```bash
# Check Magento product count
curl -X GET "https://[MAGENTO-URL]/rest/V1/products?searchCriteria[pageSize]=1" \
  -H "Authorization: Bearer [TOKEN]" | jq '.total_count'

# Expected: 9538

# Check categories
curl -X GET "https://[MAGENTO-URL]/rest/V1/categories" \
  -H "Authorization: Bearer [TOKEN]" | jq '.children_data | length'

# Expected: 166
```

**Database Verification**:
```sql
-- On Magento database
SELECT COUNT(*) FROM catalog_product_entity;  -- Should be 9538
SELECT COUNT(*) FROM catalog_category_entity; -- Should be 166+
```

**Success Criteria**:
- [ ] Product count matches: 9,538
- [ ] Category count matches: 166
- [ ] Sample random products and verify data accuracy
- [ ] Check frontend product display
- [ ] Verify product images load

---

## 🔄 Phase 5: Post-Sync Optimization (1 hour)

### Task 5.1: Reindex Magento ⏳
**Priority**: HIGH

**Actions**:
```bash
# On Magento server
php bin/magento indexer:reindex
php bin/magento cache:flush
```

**Success Criteria**:
- [ ] All indexes green
- [ ] Cache cleared
- [ ] Frontend shows products

### Task 5.2: Verify Frontend Display ⏳
**Priority**: HIGH

**Checks**:
1. Navigate to Magento storefront
2. Check category pages (sample 10 categories)
3. Check product detail pages (sample 20 products)
4. Verify:
   - ✅ Products visible
   - ✅ Images display
   - ✅ Prices show
   - ✅ Attributes present
   - ✅ Add to cart works

**Success Criteria**:
- [ ] Products browsable on frontend
- [ ] Search works
- [ ] Filters work
- [ ] No broken images

### Task 5.3: Setup Incremental Sync ⏳
**Priority**: MEDIUM

**Strategy**:
- Track last sync timestamp
- Sync only updated products
- Schedule: Daily or on-demand

**Cron Setup**:
```bash
# Add to crontab
0 2 * * * cd /home/pim/public_html && php webapp/magento_sync.php --incremental
```

**Success Criteria**:
- [ ] Incremental sync logic implemented
- [ ] Timestamp tracking working
- [ ] Cron job scheduled

---

## 📊 Monitoring & Logging

### Sync Logs Location
```
/home/pim/public_html/var/logs/magento_sync.log
/home/pim/public_html/var/logs/magento_sync_errors.log
```

### Monitoring Commands
```bash
# Watch sync progress
tail -f var/logs/magento_sync.log

# Count synced products
grep "SUCCESS" var/logs/magento_sync.log | wc -l

# Check errors
grep "ERROR" var/logs/magento_sync_errors.log

# Monitor Elasticsearch reindex (still running)
tail -f var/logs/elasticsearch_reindex.log
```

---

## 🚨 Troubleshooting Guide

### Issue: API Rate Limit Exceeded
**Solution**: Increase delay between batches
```php
$delayBetweenBatches = 10; // Increase from 5 to 10 seconds
```

### Issue: Duplicate SKU Error
**Solution**: Check for existing products first
```php
// Before creating product
$existing = $magento->getProductBySku($sku);
if ($existing) {
    // Update instead of create
    $magento->updateProduct($sku, $data);
}
```

### Issue: Image Upload Fails
**Solution**: Use direct URL or base64 encode
```php
// Option 1: Direct URL
$imageUrl = "https://pim.technostationery.com/media/cache/preview/{$imageCode}.jpg";

// Option 2: Base64 encode
$imageData = base64_encode(file_get_contents($imageUrl));
```

### Issue: Category Not Found
**Solution**: Sync categories first, then products
```bash
php webapp/magento_sync.php --categories-only
# Wait for completion
php webapp/magento_sync.php --products
```

---

## ✅ Success Metrics

### Data Accuracy
- [ ] 100% SKU match
- [ ] 95%+ attribute completeness
- [ ] 90%+ images transferred
- [ ] 100% categories mapped

### Performance
- [ ] Sync completed in < 4 hours (full sync)
- [ ] Error rate < 1%
- [ ] API response time < 500ms average

### Business Impact
- [ ] Magento catalog populated
- [ ] Products visible on storefront
- [ ] Ready for customer orders
- [ ] Search and filtering work

---

## 📋 Deliverables

1. **Sync Script** (`webapp/magento_sync.php`)
2. **Configuration File** (`webapp/magento_sync_config.json`)
3. **Sync Logs** (`var/logs/magento_sync*.log`)
4. **Mapping Document** (`webapp/AKENEO_MAGENTO_MAPPING.md`)
5. **Post-Sync Report** (`webapp/MAGENTO_SYNC_COMPLETE_REPORT.md`)

---

## 🎯 Next Immediate Actions

**Awaiting from User**:
1. ❗ **Magento 2 Beta URL** (High Priority - Blocker)
2. Confirm bot admin access works
3. Provide any specific attribute mapping requirements
4. Confirm category structure preference (flat vs hierarchy)

**Once URL Provided**:
1. Generate API token
2. Test connectivity
3. Run pilot sync (10 products)
4. Execute full sync (9,538 products)

---

**Status**: ⏸️ READY - Awaiting Magento Beta URL  
**ETA**: 4-6 hours from receiving URL to complete sync  
**Risk Level**: 🟢 LOW (Akeneo stable, well-prepared)

---

**Plan Created**: 2026-04-26  
**Last Updated**: 2026-04-26  
**Next Review**: After pilot sync completion
