# Production to Staging Migration Plan

**Document Version:** 1.0  
**Date Generated:** 2026-04-18  
**Production Environment:** `/home/technadminy7/public_html`  
**Staging Environment:** `/home/beta/public_html`  
**Status:** Ready for Execution

---

## Executive Summary

This document outlines the comprehensive migration plan for transferring production assets, configurations, and data to the staging environment at `/home/beta/public_html`. The staging environment currently has **99.3% data quality** but is missing critical production assets.

### Key Findings

| Asset Type | Production | Staging | Gap | Priority |
|------------|-----------|---------|-----|----------|
| **Product Images** | 328,678 files (9.3GB) | 0 files | 100% | 🔴 CRITICAL |
| **WYSIWYG Media** | 996 files (274MB) | 0 files | 100% | 🟡 HIGH |
| **Custom Scripts** | 20 files | 30 files | -50% | 🟡 MEDIUM |
| **Database** | technadminy7_dBT8x12y22 | beta_dBT8x12y22 | Separate | ✅ OK |

---

## Phase 1: Critical Asset Migration (HIGH PRIORITY)

### 1.1 Product Images Migration
**Goal:** Transfer all 328,678 product images (9.3GB) from production to staging

**Source:** `/home/technadminy7/public_html/pub/media/catalog/product/`  
**Destination:** `/home/beta/public_html/pub/media/catalog/product/`

**Image Breakdown:**
- `.jpg` images: 311,593 files
- `.png` images: 16,972 files
- `.jpeg` images: 85 files
- `.gif` images: 28 files

**Migration Methods:**

#### Option A: Rsync (Recommended - Incremental)
```bash
rsync -avz --progress \
  /home/technadminy7/public_html/pub/media/catalog/product/ \
  /home/beta/public_html/pub/media/catalog/product/
```

**Advantages:**
- Incremental transfer (only new/changed files)
- Preserves file permissions and timestamps
- Resume capability if interrupted
- Fast for subsequent syncs

**Estimated Time:** 45-90 minutes (first run), 5-10 minutes (subsequent runs)

#### Option B: Tar Archive + Transfer (Bulk)
```bash
# Create archive in production
cd /home/technadminy7/public_html
tar -czf /tmp/product_images_$(date +%Y%m%d).tar.gz pub/media/catalog/product/

# Extract in staging
cd /home/beta/public_html
tar -xzf /tmp/product_images_20260418.tar.gz
```

**Advantages:**
- Single large transfer
- Compressed (reduces size by ~10-20%)
- Atomic operation

**Estimated Time:** 60-120 minutes

#### Option C: Smart Sync Script (Custom)
Create a smart sync script that:
1. Compares file hashes between production and staging
2. Only transfers missing or modified files
3. Provides detailed progress reporting
4. Handles errors gracefully
5. Creates a migration log

**Implementation:** See `scripts/sync_product_images.php`

### 1.2 WYSIWYG Media Migration
**Goal:** Transfer banners, icons, and other frontend assets

**Source:** `/home/technadminy7/public_html/pub/media/wysiwyg/`  
**Destination:** `/home/beta/public_html/pub/media/wysiwyg/`

**Method:**
```bash
rsync -avz --progress \
  /home/technadminy7/public_html/pub/media/wysiwyg/ \
  /home/beta/public_html/pub/media/wysiwyg/
```

**Estimated Time:** 5-10 minutes  
**Size:** 274MB, 996 files

---

## Phase 2: Custom Scripts & Automation (MEDIUM PRIORITY)

### 2.1 Production Scripts Analysis

**Production Scripts Found (20 files):**
1. `performance_tuning.sh` - Performance optimization
2. `enable_custom_module.php` - Module management
3. `queue_consumer_watchdog.sh` - Queue monitoring
4. `smart_log_cleanup.sh` - Log rotation
5. `apply_cpu_tuning.sh` - CPU optimization
6. `quick_status.sh` - System status check
7. `add_products_to_category_1798.php` - Category assignment
8. `nightly_cache_flush.sh` - Cache management
9. `configure_redis_memory.sh` - Redis optimization
10. `configure_persistent_login.php` - Authentication setup
11. *(Additional 10 scripts)*

**Staging Scripts Status (30 files):**
- Performance optimization suite: ✅ Created (11 scripts)
- Data quality checks: ✅ Created (4 scripts)
- Cron job management: ✅ Created (3 scripts)
- Missing from production: 12 scripts

### 2.2 Script Migration Strategy

**Step 1: Review & Comparison**
- Compare production scripts vs staging scripts
- Identify duplicates and conflicts
- Determine which scripts to keep/merge

**Step 2: Migration**
```bash
# Copy production scripts to staging review directory
cp /home/technadminy7/public_html/scripts/*.php \
   /home/beta/public_html/scripts/from_production/

cp /home/technadminy7/public_html/scripts/*.sh \
   /home/beta/public_html/scripts/from_production/
```

**Step 3: Integration**
- Test each production script in staging
- Merge functionality where applicable
- Update cron jobs if needed

---

## Phase 3: Configuration Review (MEDIUM PRIORITY)

### 3.1 Configuration Files Comparison

#### app/etc/env.php
- **Production:** 13,460 bytes (Modified: 2026-04-11)
- **Staging:** 13,570 bytes (Modified: 2026-04-16)
- **Action:** Review database connections, cache settings, Redis configuration
- **Status:** ⚠️ Minor differences - review needed

#### app/etc/config.php
- **Production:** 19,980 bytes
- **Staging:** 20,758 bytes  
- **Action:** Compare module enable/disable status
- **Status:** ⚠️ Staging has additional modules - review needed

#### .htaccess
- **Production:** 1,403 bytes (Modified: 2026-04-11)
- **Staging:** 214 bytes (Modified: 2026-04-16)
- **Action:** 🔴 **CRITICAL** - Staging .htaccess is minimal, missing important rules
- **Status:** 🚨 MUST REVIEW - production has extensive configuration

#### composer.json
- **Production:** 8,254 bytes
- **Staging:** 8,472 bytes
- **Action:** Review dependency differences
- **Status:** ✅ Staging is newer - likely OK

### 3.2 .htaccess Migration Plan

**Production .htaccess Features (1,403 bytes):**
- Likely includes:
  - URL rewrite rules
  - Security headers
  - PHP settings
  - Cache control
  - Bot protection
  - Compression settings

**Action Required:**
```bash
# Backup staging .htaccess
cp /home/beta/public_html/.htaccess /home/beta/public_html/.htaccess.backup

# Compare production vs staging
diff /home/technadminy7/public_html/.htaccess \
     /home/beta/public_html/.htaccess > /home/beta/public_html/.htaccess.diff

# Review differences and merge critical rules
```

---

## Phase 4: Database Synchronization (LOW PRIORITY)

### 4.1 Database Status

**Production Database:**
- Host: 127.0.0.1:3307
- Database: `technadminy7_dBT8x12y22`
- Username: `technadminy7_ntdbusr24`

**Staging Database:**
- Host: 127.0.0.1:3307
- Database: `beta_dBT8x12y22`
- Username: `beta_ntdbusr24`

### 4.2 Data Quality Status

Based on recent quality checks:
- **Products:** 9,538 (100% enabled)
- **Names:** 100% complete
- **Descriptions:** 99.6% complete (34 missing)
- **Prices:** 100% complete
- **Images:** 91.3% complete (832 missing references)
- **Overall Quality Score:** 99.3/100

**Conclusion:** Staging database is already excellent quality. Image migration will resolve the 832 missing image references.

### 4.3 Database Sync Recommendations

**NOT RECOMMENDED** to sync entire database because:
- Staging database already has 99.3% quality score
- Extensive work already done on staging (optimization, quality checks)
- Risk of overwriting improvements

**RECOMMENDED Selective Sync:**
Only sync specific data if needed:
- Product images references (will be fixed by image migration)
- Custom CMS blocks/pages (if different)
- Customer data (⚠️ be careful with PII)

---

## Phase 5: Post-Migration Tasks

### 5.1 Image Cache Regeneration
After migrating images, regenerate Magento image cache:

```bash
cd /home/beta/public_html
php bin/magento catalog:images:resize
```

**Expected Results:**
- Thumbnails generated for all 9,538 products
- Product pages will display images correctly
- Image quality score increases from 91.3% to ~100%

**Estimated Time:** 2-4 hours (depends on server resources)

### 5.2 Cache Clearing
```bash
cd /home/beta/public_html
php bin/magento cache:clean
php bin/magento cache:flush
```

### 5.3 Reindexing
```bash
cd /home/beta/public_html
php bin/magento indexer:reindex
```

### 5.4 Verification
Run quality checks to confirm successful migration:
```bash
cd /home/beta/public_html
php scripts/detailed_quality_check.php
php scripts/accurate_quality_check.php
```

**Expected Quality Score After Migration:** 99.8-100%

---

## Migration Timeline

### Week 1: Critical Assets (HIGH PRIORITY)
| Day | Task | Duration | Status |
|-----|------|----------|--------|
| Day 1 | Image migration planning & testing | 2 hours | ⏳ Pending |
| Day 1-2 | Product images sync (9.3GB) | 1-2 hours | ⏳ Pending |
| Day 2 | WYSIWYG media sync (274MB) | 30 mins | ⏳ Pending |
| Day 2-3 | Image cache regeneration | 2-4 hours | ⏳ Pending |
| Day 3 | Verification & quality check | 1 hour | ⏳ Pending |

**Total Time: 6-10 hours over 3 days**

### Week 2: Scripts & Configuration (MEDIUM PRIORITY)
| Day | Task | Duration | Status |
|-----|------|----------|--------|
| Day 4 | Review production scripts | 2 hours | ⏳ Pending |
| Day 4-5 | Migrate & test scripts | 4 hours | ⏳ Pending |
| Day 5 | .htaccess review & merge | 2 hours | ⏳ Pending |
| Day 5 | Config file comparison | 1 hour | ⏳ Pending |

**Total Time: 9 hours over 2 days**

### Week 3: Final Touches (LOW PRIORITY)
| Day | Task | Duration | Status |
|-----|------|----------|--------|
| Day 6 | Generate 34 missing descriptions | 1 hour | ⏳ Pending |
| Day 6 | Submit sitemap to Google | 30 mins | ⏳ Pending |
| Day 7 | Google Merchant Center setup | 2 hours | ⏳ Pending |
| Day 7 | Final verification | 1 hour | ⏳ Pending |

**Total Time: 4.5 hours over 2 days**

---

## Resource Requirements

### Storage Space
- Production images: 9.3GB
- WYSIWYG media: 274MB
- Image cache (after resize): ~3-5GB
- **Total needed:** ~12.5-15GB free space in `/home/beta/public_html`

### Bandwidth
- First sync: 9.5GB transfer
- Subsequent syncs: Incremental (MB range)

### Server Resources During Migration
- CPU: Medium usage during rsync
- RAM: Low (rsync is efficient)
- I/O: High during image cache regeneration

### Estimated Costs
- **Time investment:** 20-25 hours total
- **Server resources:** Included (no additional cost)
- **Risk level:** Low (non-destructive operations)
- **ROI:** High (completes final 1% to reach 100% quality)

---

## Risk Assessment & Mitigation

### Risk 1: Storage Space Exhaustion
**Probability:** Low  
**Impact:** High  
**Mitigation:**
- Check available space before starting: `df -h /home/beta`
- Clean up unnecessary files in staging
- Monitor during transfer

### Risk 2: Transfer Interruption
**Probability:** Medium  
**Impact:** Low (if using rsync)  
**Mitigation:**
- Use rsync (supports resume)
- Run during low-traffic hours
- Monitor network connectivity

### Risk 3: File Permission Issues
**Probability:** Medium  
**Impact:** Medium  
**Mitigation:**
- Use rsync with `-a` flag (preserves permissions)
- Fix permissions after transfer:
  ```bash
  find /home/beta/public_html/pub/media -type d -exec chmod 755 {} \;
  find /home/beta/public_html/pub/media -type f -exec chmod 644 {} \;
  chown -R beta:beta /home/beta/public_html/pub/media
  ```

### Risk 4: .htaccess Conflicts
**Probability:** Medium  
**Impact:** High (site could break)  
**Mitigation:**
- Always backup current .htaccess
- Test changes on staging before production
- Keep previous version for rollback
- Review each rule carefully

### Risk 5: Image Cache Generation Timeout
**Probability:** Medium  
**Impact:** Low (can be rerun)  
**Mitigation:**
- Run `catalog:images:resize` in screen/tmux session
- Use `--async` flag for background processing
- Run during off-peak hours
- Split into batches if needed

---

## Success Criteria

### ✅ Phase 1 Complete When:
- [ ] All 328,678 product images transferred successfully
- [ ] All 996 WYSIWYG media files transferred
- [ ] Image cache regenerated for all products
- [ ] Quality check shows ~100% image availability
- [ ] No broken image links on product pages

### ✅ Phase 2 Complete When:
- [ ] All 20 production scripts reviewed
- [ ] Critical scripts migrated to staging
- [ ] No conflicting/duplicate scripts
- [ ] All scripts tested and working

### ✅ Phase 3 Complete When:
- [ ] .htaccess rules merged and tested
- [ ] Configuration differences documented
- [ ] No site functionality broken
- [ ] Security features intact

### ✅ Overall Migration Success:
- [ ] **Quality Score:** 99.8-100%
- [ ] **Image Availability:** 100%
- [ ] **Site Functionality:** 100%
- [ ] **Performance:** Maintained or improved
- [ ] **Zero Critical Issues:** No blockers for launch

---

## Execution Commands Reference

### Quick Start (Recommended Sequence)

```bash
# Step 1: Check available space
df -h /home/beta/public_html

# Step 2: Backup staging (optional but recommended)
cd /home/beta/public_html
tar -czf /tmp/staging_backup_$(date +%Y%m%d).tar.gz pub/media/

# Step 3: Sync product images (first run)
rsync -avz --progress \
  /home/technadminy7/public_html/pub/media/catalog/product/ \
  /home/beta/public_html/pub/media/catalog/product/

# Step 4: Sync WYSIWYG media
rsync -avz --progress \
  /home/technadminy7/public_html/pub/media/wysiwyg/ \
  /home/beta/public_html/pub/media/wysiwyg/

# Step 5: Fix permissions
cd /home/beta/public_html
find pub/media -type d -exec chmod 755 {} \;
find pub/media -type f -exec chmod 644 {} \;

# Step 6: Regenerate image cache (run in screen/tmux)
cd /home/beta/public_html
php bin/magento catalog:images:resize

# Step 7: Clear cache
php bin/magento cache:clean
php bin/magento cache:flush

# Step 8: Reindex
php bin/magento indexer:reindex

# Step 9: Verify
php scripts/detailed_quality_check.php
```

### Incremental Sync (Subsequent Runs)

```bash
# Quick sync of new/changed images only
rsync -avz --progress --update \
  /home/technadminy7/public_html/pub/media/catalog/product/ \
  /home/beta/public_html/pub/media/catalog/product/
```

---

## Monitoring & Logging

### During Migration
Monitor progress:
```bash
# Watch disk usage
watch -n 10 'df -h | grep beta'

# Monitor rsync progress
# (rsync with --progress flag shows real-time stats)

# Check file counts
find /home/beta/public_html/pub/media/catalog/product -type f | wc -l
```

### Post-Migration Logs
Review logs for issues:
```bash
tail -f /home/beta/public_html/var/log/system.log
tail -f /home/beta/public_html/var/log/exception.log
```

---

## Rollback Plan

If migration causes issues:

### Rollback Images
```bash
# If backup was created:
cd /home/beta/public_html
rm -rf pub/media/*
tar -xzf /tmp/staging_backup_20260418.tar.gz
```

### Rollback .htaccess
```bash
cd /home/beta/public_html
cp .htaccess.backup .htaccess
```

### Rollback Scripts
```bash
# Remove migrated scripts
rm /home/beta/public_html/scripts/from_production/*
```

---

## Contact & Support

**Migration Owner:** AI Development Team  
**Staging Environment:** `/home/beta/public_html`  
**Production Environment:** `/home/technadminy7/public_html`  
**Git Repository:** https://github.com/mounirtms/techno-magento  
**Branch:** `oldbetbranch-working-change`

---

## Appendix: File Structure Comparison

### Production Directory Structure
```
/home/technadminy7/public_html/
├── pub/media/catalog/product/    (9.3GB, 344,769 files)
├── pub/media/wysiwyg/             (274MB, 996 files)
├── scripts/                       (20 custom scripts)
├── app/etc/env.php               (13,460 bytes)
├── app/etc/config.php            (19,980 bytes)
└── .htaccess                     (1,403 bytes)
```

### Staging Directory Structure
```
/home/beta/public_html/
├── pub/media/catalog/product/    (0 files) ⚠️ EMPTY
├── pub/media/wysiwyg/             (0 files) ⚠️ EMPTY
├── scripts/                       (30 optimization scripts) ✅
├── app/etc/env.php               (13,570 bytes) ✅
├── app/etc/config.php            (20,758 bytes) ✅
└── .htaccess                     (214 bytes) ⚠️ MINIMAL
```

---

**Document Status:** ✅ COMPLETE  
**Ready for Execution:** YES  
**Approval Required:** YES (from stakeholders)  
**Estimated Completion:** 2-3 weeks (part-time)  
**Budget:** $0 (internal resources only)  
**ROI:** Complete final 1% → Launch-ready platform

---

*End of Document*
