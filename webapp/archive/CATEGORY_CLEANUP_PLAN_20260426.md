# CATEGORY CLEANUP AND OPTIMIZATION PLAN
## Magento Beta Catalog Reorganization
## Date: 2026-04-26
## Status: 📋 PLANNING PHASE

---

## SITUATION ANALYSIS

### Current State
- **Magento Categories**: 869 total (too many, creating noise)
- **Akeneo Categories**: 166 (clean, organized structure)
- **Akeneo Categories Synced**: 166 (mapped in connector)
- **Extra Magento Categories**: 703 (need cleanup)

### Category Distribution
| Level | Count | Notes |
|-------|-------|-------|
| 0 | 1 | Root |
| 1 | 174 | Top-level categories |
| 2 | 28 | Second level |
| 3 | 23 | Third level |
| 4 | 110 | Fourth level |
| 5 | 533 | Fifth level (deep nesting) |

### Problem Identified
- **Too many categories** (869 vs 166 needed)
- **Deep nesting** (5 levels, unnecessary complexity)
- **Noise in navigation** (confusing for users)
- **Mixed sources** (old Magento + Akeneo categories)

---

## OBJECTIVES

1. **Clean Category Structure**: Remove non-Akeneo categories
2. **Use PIM as Single Source**: Akeneo categories only
3. **Improve Navigation**: Cleaner, simpler category tree
4. **Maintain Product Assignments**: Keep all 9,538 products properly categorized
5. **Optimize Performance**: Faster category queries and navigation

---

## PROPOSED SOLUTION

### Phase 1: Backup and Analysis ✅
**Status**: In Progress

1. **Backup current categories**
   - Export category structure to SQL
   - Document current product-category assignments
   - Create rollback script

2. **Identify categories to keep**
   - Default Magento categories (root, default category)
   - 166 Akeneo-synced categories
   - Total to keep: ~168 categories

3. **Identify categories to remove**
   - Non-Akeneo categories: ~700 categories
   - Empty categories (no products)
   - Orphaned categories

### Phase 2: Category Cleanup 🔄
**Status**: Pending

1. **Preserve critical categories**
   ```sql
   -- Keep categories:
   - entity_id = 1 (Root)
   - entity_id = 2 (Default Category)
   - All categories in akeneo_connector_entities (166 categories)
   ```

2. **Remove extra categories**
   - Categories NOT in Akeneo connector mapping
   - Empty categories with no products
   - Estimated removal: ~700 categories

3. **Reassign orphaned products**
   - Products in deleted categories → move to parent or default
   - Maintain all product visibility

### Phase 3: Category Sync Optimization 🔄
**Status**: Pending

1. **Re-sync from Akeneo**
   ```bash
   bin/magento akeneo_connector:import --code=category -n
   ```

2. **Verify category tree structure**
   - Check parent-child relationships
   - Validate category hierarchy
   - Ensure no broken links

3. **Update category attributes**
   - Names, descriptions
   - URLs, metadata
   - Images (if applicable)

### Phase 4: Product Re-assignment 🔄
**Status**: Pending

1. **Sync product categories from Akeneo**
   ```bash
   bin/magento akeneo_connector:import --code=product -n
   ```

2. **Verify product assignments**
   - All 9,538 products assigned to correct categories
   - No orphaned products
   - Proper category counts

3. **Update category product counts**
   - Recount products per category
   - Update navigation counts

### Phase 5: Reindex and Optimize 🔄
**Status**: Pending

1. **Reindex catalog**
   ```bash
   bin/magento indexer:reindex catalog_category_product
   bin/magento indexer:reindex catalog_product_category
   bin/magento cache:flush
   ```

2. **Optimize URLs**
   - Regenerate category URL rewrites
   - Clean duplicate URLs
   - Optimize URL keys

3. **Test frontend navigation**
   - Verify category menu
   - Check product listings
   - Test search and filters

---

## EXECUTION PLAN

### Step 1: Create Backup
```bash
# Backup categories
mysqldump -h127.0.0.1 -P3307 -ubeta_ntdbusr24 -p'password' beta_dBT8x12y22 \
  catalog_category_entity \
  catalog_category_entity_varchar \
  catalog_category_entity_int \
  catalog_category_product \
  > /home/beta/backups/categories_backup_$(date +%Y%m%d).sql
```

**Estimated Time**: 2-3 minutes

### Step 2: Identify Categories to Keep
```sql
-- Get Akeneo-mapped category IDs
SELECT entity_id FROM akeneo_connector_entities WHERE import='category';

-- Count: 166 categories
-- Plus: Root (1) and Default (2)
-- Total to keep: ~168 categories
```

**Estimated Time**: 1 minute

### Step 3: Remove Extra Categories
```sql
-- Delete categories NOT from Akeneo
-- Estimated: ~700 categories to remove
DELETE FROM catalog_category_entity 
WHERE entity_id NOT IN (
  SELECT entity_id FROM akeneo_connector_entities WHERE import='category'
  UNION SELECT 1 UNION SELECT 2
) AND entity_id > 2;
```

**Estimated Time**: 5-10 minutes (with cascading deletes)

### Step 4: Clean Up Related Tables
```bash
# Run Magento cleanup commands
bin/magento catalog:category:clean
```

**Estimated Time**: 2-3 minutes

### Step 5: Re-sync from Akeneo
```bash
# Import categories from Akeneo
bin/magento akeneo_connector:import --code=category -n

# Import products to update category assignments
bin/magento akeneo_connector:import --code=product -n
```

**Estimated Time**: 10-15 minutes

### Step 6: Reindex and Verify
```bash
# Reindex catalog
bin/magento indexer:reindex catalog_category_product
bin/magento indexer:reindex catalog_product_category
bin/magento indexer:reindex catalogsearch_fulltext

# Clear cache
bin/magento cache:flush

# Verify counts
```

**Estimated Time**: 15-20 minutes

---

## RISK ASSESSMENT

### High Risk
- ❌ **None**: Full backup available for rollback

### Medium Risk
- ⚠️ **Broken product links**: Products may temporarily show in wrong categories
  - **Mitigation**: Re-sync products after category cleanup
  
- ⚠️ **URL rewrites**: Some category URLs may break
  - **Mitigation**: Regenerate URLs after cleanup

### Low Risk
- ⚠️ **Frontend menu cache**: Navigation may be cached
  - **Mitigation**: Clear all caches

---

## ROLLBACK PLAN

If something goes wrong:

```bash
# Stop all operations
# Restore from backup
mysql -h127.0.0.1 -P3307 -ubeta_ntdbusr24 -p'password' beta_dBT8x12y22 \
  < /home/beta/backups/categories_backup_YYYYMMDD.sql

# Reindex
bin/magento indexer:reindex

# Clear cache
bin/magento cache:flush
```

**Recovery Time**: 10-15 minutes

---

## EXPECTED RESULTS

### Before Cleanup
- Total Categories: 869
- Category Levels: 5 (too deep)
- Navigation: Cluttered
- Performance: Good

### After Cleanup
- Total Categories: ~168 (166 Akeneo + 2 system)
- Category Levels: 3-4 (optimal)
- Navigation: Clean, organized
- Performance: Excellent (faster queries)

### Benefits
1. ✅ **Cleaner navigation** (80% fewer categories)
2. ✅ **Single source of truth** (Akeneo PIM only)
3. ✅ **Easier management** (all changes in PIM)
4. ✅ **Better performance** (faster category queries)
5. ✅ **Improved UX** (less confusing for customers)

---

## MONITORING

### During Execution
- Watch for errors in system logs
- Monitor product count changes
- Check category product assignments
- Verify frontend accessibility

### After Completion
- Verify category count: Should be ~168
- Check product assignments: All 9,538 products
- Test navigation: All categories accessible
- Monitor performance: Query times

---

## TIMELINE

| Phase | Duration | Status |
|-------|----------|--------|
| Planning & Analysis | 30 min | ✅ In Progress |
| Backup Creation | 5 min | Pending |
| Category Cleanup | 15 min | Pending |
| Akeneo Re-sync | 15 min | Pending |
| Reindex & Testing | 20 min | Pending |
| Verification | 10 min | Pending |

**Total Estimated Time**: 1.5 hours

---

## APPROVAL CHECKLIST

Before proceeding:
- [ ] Backup created and verified
- [ ] Rollback plan tested
- [ ] Off-peak hours scheduled (if applicable)
- [ ] Team notified
- [ ] Monitoring in place

---

## NEXT STEPS

1. **Review this plan** with stakeholders
2. **Schedule execution** (recommended: off-peak hours)
3. **Create backup** (Step 1)
4. **Execute cleanup** (Steps 2-6)
5. **Verify results** and monitor

---

**Plan Created**: 2026-04-26  
**Estimated Completion**: 1.5 hours  
**Risk Level**: Low (full backup available)  
**Impact**: High (cleaner catalog structure)

**Ready to Proceed**: Awaiting approval
