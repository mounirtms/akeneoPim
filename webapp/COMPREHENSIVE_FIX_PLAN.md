# COMPREHENSIVE AKENEO PIM FIX & OPTIMIZATION PLAN
**Date:** April 23, 2026, 23:30 CET  
**Status:** 🚨 CRITICAL - Multiple Issues Identified  
**Duration:** 8-12 hours estimated  
**Priority:** HIGH

---

## 📋 EXECUTIVE SUMMARY

### Current System Status
```
✅ WORKING:
- Website accessible (HTTP 302)
- Database operational (MariaDB 10.6)
- 9,538 products total
- 3 ERP channels configured

⚠️ ISSUES IDENTIFIED:
1. JavaScript routing errors (high frequency)
2. Database unserialization errors (CRITICAL)
3. CREATE_TIME exception (blocking features)
4. 8,217 products disabled (86%)
5. Performance issues (19MB cron log, 2.7MB prod log)
6. Missing product models
7. No monitoring dashboard
```

---

## 🚨 CRITICAL ERRORS ANALYSIS

### Error Category 1: JavaScript Routing Error (HIGHEST FREQUENCY)
```
ERROR: No route found for "GET /function%20()%20%7B%20[native%20code]%20%7D"
Frequency: ~20+ occurrences in last hour
Pages Affected: /enrich/product/, /collect/import/, /spread/export/
Impact: UI features broken, user experience degraded
```

**Root Cause:** Frontend JavaScript bug - invalid URL being constructed  
**Severity:** 🔴 HIGH - Breaks product editing, import/export

---

### Error Category 2: Database Unserialization Error (CRITICAL)
```
CRITICAL: Could not convert database value to 'array'
Error: unserialize(): Error at offset 0 of 2 bytes
Frequency: Multiple times per hour
Impact: Data corruption, feature failures
```

**Root Cause:** Corrupted serialized data in database  
**Severity:** 🔴 CRITICAL - Data integrity issue

---

### Error Category 3: CREATE_TIME Exception
```
CRITICAL: "CREATE_TIME" not available for table "oro_user"
Impact: Installation status checks failing
Frequency: Every page load attempt
```

**Root Cause:** MySQL information_schema limitation  
**Severity:** 🟡 MEDIUM - Non-critical but annoying

---

### Error Category 4: Disabled Products
```
Products: 9,538 total
Enabled: 1,321 (13.8%)
Disabled: 8,217 (86.2%)
```

**Root Cause:** Products imported as disabled by default  
**Severity:** 🔴 HIGH - Most products not usable

---

### Error Category 5: Performance Issues
```
cron_messenger.log: 19MB (excessive)
prod.log: 2.7MB (excessive)
Log rotation: Not configured properly
Memory: High usage suspected
```

**Severity:** 🟡 MEDIUM - Affects stability long-term

---

## 📊 COMPREHENSIVE TASK PLAN

### PHASE 1: IMMEDIATE FIXES (2-3 hours)
**Priority:** 🔴 CRITICAL  
**Must complete before other work**

#### Task 1.1: Fix JavaScript Routing Error
**Time:** 30 minutes  
**Difficulty:** Medium

**Steps:**
1. Identify JavaScript file causing URL generation bug
2. Clear frontend cache: `rm -rf public/bundles/* public/css/* public/js/*`
3. Rebuild frontend: `php bin/console pim:installer:assets --symlink --clean --env=prod`
4. Clear Symfony cache: `php bin/console cache:clear --env=prod`
5. Test product edit page
6. Verify import/export pages

**Expected Outcome:** No more `/function%20()%20%7B%20[native%20code]%20%7D` errors

---

#### Task 1.2: Fix Database Unserialization Errors
**Time:** 1 hour  
**Difficulty:** Hard

**Investigation:**
```sql
-- Find corrupted data
SELECT id, username, ui_locale_id, catalog_locale_id 
FROM oro_user 
WHERE ui_locale_id IS NULL OR catalog_locale_id IS NULL;

-- Check for corrupted serialized data in user preferences
SELECT id, username, LENGTH(properties) as prop_length
FROM oro_user 
WHERE properties IS NOT NULL AND properties != '';
```

**Fix Strategy:**
1. Identify tables with serialized data issues
2. Find corrupted rows
3. Fix or remove corrupted data
4. Update schema if needed

**SQL Fixes:**
```sql
-- Fix NULL locale issues
UPDATE oro_user 
SET ui_locale_id = (SELECT id FROM pim_catalog_locale WHERE code='en_US' LIMIT 1)
WHERE ui_locale_id IS NULL;

UPDATE oro_user 
SET catalog_locale_id = (SELECT id FROM pim_catalog_locale WHERE code='en_US' LIMIT 1)
WHERE catalog_locale_id IS NULL;
```

---

#### Task 1.3: Suppress CREATE_TIME Exception
**Time:** 15 minutes  
**Difficulty:** Easy

**Options:**
A. Patch InstallStatusManager.php to handle exception
B. Create database view with CREATE_TIME
C. Disable install status check (production-safe)

**Recommended:** Option C (quick fix)

**Create config override:**
```yaml
# config/packages/prod/installer.yaml
akeneo_platform_installer:
    check_installation_status: false
```

---

#### Task 1.4: Enable Products (Bulk Operation)
**Time:** 30 minutes  
**Difficulty:** Easy

**Strategy:** Enable all products that should be active

```sql
-- Enable all products (can be selective later)
UPDATE pim_catalog_product 
SET is_enabled = 1 
WHERE is_enabled = 0;

-- Or selective by family:
UPDATE pim_catalog_product p
INNER JOIN pim_catalog_family f ON p.family_id = f.id
SET p.is_enabled = 1
WHERE f.code = 'products' AND p.is_enabled = 0;
```

**Verification:**
```sql
SELECT 
    is_enabled, 
    COUNT(*) as count 
FROM pim_catalog_product 
GROUP BY is_enabled;
```

---

### PHASE 2: DATA QUALITY & DASHBOARD (2-3 hours)
**Priority:** 🟡 HIGH  
**Build monitoring and quality tools**

#### Task 2.1: Create Real-Time Data Quality Dashboard
**Time:** 2 hours  
**Difficulty:** Medium

**Dashboard Features:**
- Product completeness by channel
- Enabled/disabled product ratio
- Products missing required attributes
- Image coverage percentage
- Category distribution
- Family distribution
- Recent updates timeline
- Error log summary

**File:** `webapp/quality_dashboard_realtime.php`

**Metrics:**
```sql
-- Product completeness
-- Missing names (fr_FR)
-- Missing prices
-- Missing categories
-- Images linked vs total
-- Enabled vs disabled
```

---

#### Task 2.2: Create Data Quality Repair Scripts
**Time:** 1 hour

**Scripts to create:**
1. `fix_missing_names.php` - Auto-generate from English or SKU
2. `fix_product_status.php` - Enable products based on rules
3. `fix_missing_prices.php` - Identify products without prices
4. `validate_categories.php` - Ensure all products have categories

---

### PHASE 3: PERFORMANCE OPTIMIZATION (1-2 hours)
**Priority:** 🟡 MEDIUM  
**Improve stability and speed**

#### Task 3.1: Configure Log Rotation
**Time:** 15 minutes

**Create:** `/etc/logrotate.d/akeneo-pim`
```bash
/home/pim/public_html/var/logs/*.log {
    daily
    rotate 7
    compress
    delaycompress
    notifempty
    create 0660 pim pim
    sharedscripts
    postrotate
        /bin/kill -SIGUSR1 $(cat /var/run/php-fpm/php-fpm.pid 2>/dev/null) 2>/dev/null || true
    endscript
}
```

---

#### Task 3.2: Optimize Messenger Queue
**Time:** 30 minutes

**Issue:** cron_messenger.log is 19MB (excessive)

**Actions:**
1. Clear old messenger messages
2. Optimize queue processing
3. Configure message TTL
4. Set up failed message handling

```bash
# Clear failed messages
php bin/console messenger:failed:show
php bin/console messenger:failed:remove -vv

# Process stuck messages
php bin/console messenger:consume --limit=100 --time-limit=60
```

---

#### Task 3.3: Database Optimization
**Time:** 30 minutes

**Actions:**
```sql
-- Analyze tables
ANALYZE TABLE pim_catalog_product, 
              pim_catalog_category, 
              akeneo_file_storage_file_info;

-- Optimize tables
OPTIMIZE TABLE pim_catalog_product, 
               pim_catalog_category;

-- Check for fragmentation
SELECT 
    table_name, 
    ROUND(data_length/1024/1024,2) as data_mb,
    ROUND(index_length/1024/1024,2) as index_mb,
    ROUND(data_free/1024/1024,2) as free_mb
FROM information_schema.tables
WHERE table_schema='akeneo_pim'
ORDER BY data_free DESC
LIMIT 10;
```

---

#### Task 3.4: Configure PHP-FPM Optimization
**Time:** 30 minutes

**Check current config:**
```bash
# Find PHP-FPM config
php --ini | grep fpm

# Optimize settings
pm = dynamic
pm.max_children = 50
pm.start_servers = 10
pm.min_spare_servers = 5
pm.max_spare_servers = 20
pm.max_requests = 500
```

---

### PHASE 4: PRODUCT MODELS & VARIANTS (2-3 hours)
**Priority:** 🟡 MEDIUM  
**Implement product families properly**

#### Task 4.1: Analyze Current Product Structure
**Time:** 30 minutes

**Check:**
```sql
-- Check if product models exist
SELECT COUNT(*) FROM pim_catalog_product_model;

-- Check family variants
SELECT code, family_id FROM pim_catalog_family_variant;

-- Identify products that should be variants
SELECT 
    f.code as family,
    COUNT(p.id) as product_count
FROM pim_catalog_product p
JOIN pim_catalog_family f ON p.family_id = f.id
GROUP BY f.code;
```

---

#### Task 4.2: Create Product Models (If Needed)
**Time:** 2 hours

**Strategy:**
1. Identify product groups (by SKU pattern, name, etc.)
2. Create family variants
3. Create product models
4. Link variant products to models

**Only implement if business needs variants**

---

### PHASE 5: MONITORING & ALERTING (1-2 hours)
**Priority:** 🟡 MEDIUM  
**Set up proactive monitoring**

#### Task 5.1: Create System Health Monitor
**Time:** 1 hour

**Monitor:**
- Database connection health
- Disk space usage
- Log file sizes
- Error rate (errors per hour)
- Queue message count
- Cache size
- PHP-FPM status

**File:** `webapp/system_health_monitor.php`

**Run via cron:** Every 5 minutes
```bash
*/5 * * * * php /home/pim/public_html/webapp/system_health_monitor.php
```

---

#### Task 5.2: Create Error Alert System
**Time:** 30 minutes

**Alert when:**
- Error rate > 10 per minute
- Disk space < 10%
- Database connection fails
- Queue has > 1000 messages
- Log files > 100MB

**Send alerts to:** webmaster@techno-dz.com

---

#### Task 5.3: Create Daily Status Report
**Time:** 30 minutes

**Report includes:**
- Product counts (total, enabled, disabled)
- Error summary
- Performance metrics
- Backup status
- Disk usage
- Top 10 errors

**Email:** Daily at 8:00 AM to stakeholders

---

### PHASE 6: IMAGE IMPORT (6-8 hours)
**Priority:** 🔴 HIGH  
**Major task - separate session recommended**

**See:** Dedicated image import plan (previous work)

**Steps:**
1. Index all 355,000 images
2. Map to 9,538 products
3. Copy to Akeneo storage
4. Update database references
5. Verify in UI

---

## 🎯 EXECUTION ORDER (Recommended)

### Session 1: Critical Fixes (2-3 hours) - DO NOW
✅ Task 1.1: Fix JavaScript errors  
✅ Task 1.2: Fix unserialization errors  
✅ Task 1.3: Suppress CREATE_TIME exception  
✅ Task 1.4: Enable disabled products  
✅ Task 3.1: Configure log rotation  
✅ Test and verify fixes

---

### Session 2: Dashboard & Monitoring (2-3 hours) - DO TODAY
✅ Task 2.1: Create quality dashboard  
✅ Task 2.2: Create repair scripts  
✅ Task 5.1: Create health monitor  
✅ Task 5.2: Create alert system  
✅ Test and deploy

---

### Session 3: Performance Optimization (1-2 hours) - DO TODAY
✅ Task 3.2: Optimize messenger queue  
✅ Task 3.3: Database optimization  
✅ Task 3.4: PHP-FPM tuning  
✅ Measure improvements

---

### Session 4: Product Models (2-3 hours) - DO THIS WEEK
✅ Task 4.1: Analyze structure  
✅ Task 4.2: Implement if needed  
✅ Test variants

---

### Session 5: Image Import (6-8 hours) - SCHEDULE SEPARATELY
✅ Full image import process  
✅ Verification  
✅ UI testing

---

## 📝 DETAILED SCRIPT SPECIFICATIONS

### Script 1: JavaScript Error Fix
**File:** `webapp/fix_javascript_errors.sh`
```bash
#!/bin/bash
# Clear and rebuild frontend assets
cd /home/pim/public_html

# Clear old assets
rm -rf public/bundles/*
rm -rf public/css/*
rm -rf public/js/*

# Rebuild
php bin/console pim:installer:assets --symlink --clean --env=prod

# Clear cache
php bin/console cache:clear --env=prod

# Fix permissions
bash webapp/fix_cache_permissions.sh

echo "Frontend assets rebuilt"
```

---

### Script 2: Database Health Check
**File:** `webapp/database_health_check.php`
```php
<?php
// Check for common database issues
// - Corrupted serialized data
// - NULL foreign keys
// - Orphaned records
// - Index fragmentation
// Generate report with fixes
```

---

### Script 3: Enable Products Script
**File:** `webapp/enable_products.php`
```php
<?php
// Bulk enable products based on rules
// - Has required attributes
// - Has valid price
// - Belongs to active category
// - Has family assigned
```

---

### Script 4: Quality Dashboard
**File:** `webapp/quality_dashboard_realtime.php`
```php
<?php
// Real-time dashboard showing:
// - Product statistics
// - Completeness scores
// - Error rates
// - Performance metrics
// - Recent changes
// Auto-refresh every 30 seconds
```

---

### Script 5: System Health Monitor
**File:** `webapp/system_health_monitor.php`
```php
<?php
// Check system health:
// - Database connection
// - Disk space
// - Memory usage
// - Error log size
// - Queue depth
// Send alerts if thresholds exceeded
```

---

## 🔧 CONFIGURATION FILES TO CREATE

### 1. Log Rotation Config
**File:** `/etc/logrotate.d/akeneo-pim`

### 2. Monitoring Cron Jobs
**File:** `/home/pim/cron_monitoring.txt`
```bash
*/5 * * * * php /home/pim/public_html/webapp/system_health_monitor.php
0 8 * * * php /home/pim/public_html/webapp/daily_status_report.php
```

### 3. Performance Config
**File:** `/home/pim/public_html/config/packages/prod/performance.yaml`
```yaml
framework:
    cache:
        app: cache.adapter.redis
        default_redis_provider: redis://localhost

doctrine:
    orm:
        metadata_cache_driver:
            type: redis
        query_cache_driver:
            type: redis
```

---

## 📊 SUCCESS METRICS

### After Phase 1 (Critical Fixes):
- [ ] Zero JavaScript routing errors in last hour
- [ ] Zero unserialization errors
- [ ] Products enabled: >90%
- [ ] Error log size: <100MB/day

### After Phase 2 (Dashboard):
- [ ] Quality dashboard accessible
- [ ] Data quality score visible
- [ ] Real-time metrics updating

### After Phase 3 (Performance):
- [ ] Log files: <50MB/day
- [ ] Page load time: <2 seconds
- [ ] Queue processing: <100 messages
- [ ] Memory usage: <70%

### After Phase 4 (Models):
- [ ] Product models created (if needed)
- [ ] Variants properly structured
- [ ] Family hierarchy correct

### After Phase 5 (Monitoring):
- [ ] Health monitor running
- [ ] Alerts configured
- [ ] Daily reports sending

---

## ⚠️ RISKS & MITIGATION

### Risk 1: Database Corruption
**Mitigation:** Create backup before any DB operations
```bash
/opt/mariadb10.6/mariadb/bin/mysqldump \
  -u root -p'YourNewStrongPassword' \
  -h 127.0.0.1 -P 3307 akeneo_pim \
  | gzip > /home/pim/backups/pre_fixes_$(date +%Y%m%d_%H%M%S).sql.gz
```

### Risk 2: Frontend Breaking
**Mitigation:** Keep backup of working assets
```bash
tar -czf /home/pim/backups/public_assets_backup.tar.gz public/
```

### Risk 3: Performance Degradation
**Mitigation:** Monitor during changes, rollback if needed

---

## 📋 COMPLETION CHECKLIST

### Phase 1: Critical Fixes
- [ ] JavaScript errors fixed
- [ ] Unserialization errors resolved
- [ ] CREATE_TIME exception suppressed
- [ ] Products enabled (target: 90%+)
- [ ] Log rotation configured
- [ ] Website tested and working
- [ ] Backup created

### Phase 2: Dashboard & Quality
- [ ] Quality dashboard created
- [ ] Metrics displaying correctly
- [ ] Repair scripts created
- [ ] Data quality >95%

### Phase 3: Performance
- [ ] Logs under control (<50MB/day)
- [ ] Queue optimized
- [ ] Database optimized
- [ ] PHP-FPM tuned
- [ ] Load time <2 seconds

### Phase 4: Models
- [ ] Structure analyzed
- [ ] Models created (if needed)
- [ ] Variants working

### Phase 5: Monitoring
- [ ] Health monitor deployed
- [ ] Alerts configured
- [ ] Reports sending
- [ ] Cron jobs scheduled

---

## 🚀 READY TO START

**Recommended Start:** Phase 1 (Critical Fixes) - 2-3 hours

**Steps:**
1. Create database backup
2. Run Script 1: Fix JavaScript errors
3. Run Script 2: Database health check
4. Run Script 3: Enable products
5. Configure log rotation
6. Test website
7. Commit changes

**Would you like me to begin with Phase 1?**

