# Akeneo PIM Production Stabilization Plan
**Date**: 2026-04-27  
**Status**: 🔴 CRITICAL - Production Issues Detected  
**Priority**: URGENT

---

## 🚨 CRITICAL ISSUE SUMMARY

### Current Problems
1. **Cloudflare Aggressive Caching** - Old assets (v=20260426b) still loading despite server fixes
2. **JavaScript Errors** - pim/form-builder 404, process undefined, analytics 500
3. **Data Not Loading** - Categories show 0, attribute groups incorrect, data insights missing
4. **Product Page Broken** - https://pim.technostationery.com/enrich/product/ not working
5. **Frontend Initialization Failure** - React/Backbone components not starting

### Root Cause
- ✅ Server-side fixes ARE in place (verified)
- ❌ Cloudflare CDN is serving OLD cached HTML/JS
- ❌ Browser cannot load new fixes because it never reaches server

---

## 🆘 IMMEDIATE EMERGENCY FIX (Do This NOW)

###Step 1: Bypass Cloudflare (Test if fixes work)

**Open in INCOGNITO/PRIVATE window**:
```
https://pim.technostationery.com/?nocache=1&t=1777301210
```

**Expected Result**:
- ✅ Console shows: `v=1777301210` (not `v=20260426b`)
- ✅ No pim/form-builder errors
- ✅ No process errors
- ✅ Data loads correctly
- ✅ Categories show 166 (not 0)
- ✅ Product page works

**If this works** → Problem confirmed as Cloudflare caching  
**If this fails** → Deeper server issue

### Step 2: Purge Cloudflare Cache (MANDATORY)

**Option A: Cloudflare Dashboard**
```
1. Login to Cloudflare dashboard
2. Select domain: technostationery.com
3. Go to: Caching → Configuration
4. Click "Purge Everything"
5. Confirm and wait 30-60 seconds
6. Test: https://pim.technostationery.com (normal URL)
```

**Option B: Cloudflare API** (if you have API key)
```bash
curl -X POST "https://api.cloudflare.com/client/v4/zones/{zone_id}/purge_cache" \
     -H "Authorization: Bearer {api_token}" \
     -H "Content-Type: application/json" \
     --data '{"purge_everything":true}'
```

**Option C: Selective Purge** (faster, targeted)
```
Purge these specific URLs:
- https://pim.technostationery.com/
- https://pim.technostationery.com/js/require-paths.js
- https://pim.technostationery.com/dist/vendor.min.js
- https://pim.technostationery.com/dist/main.min.js
- https://pim.technostationery.com/bundles/pimui/js/index.js
```

### Step 3: Verify Fix

**After Cloudflare purge**:
```
1. Close ALL browser tabs for pim.technostationery.com
2. Clear browser cache (Ctrl+Shift+Delete)
3. Open NEW incognito window
4. Go to: https://pim.technostationery.com
5. Open console (F12)
6. Check for: v=1777301210 in asset URLs
7. Verify: No 404 or 500 errors
8. Test: Product page, categories, data insights
```

---

## 📋 COMPREHENSIVE STABILIZATION PLAN

### Phase 1: Cache & Asset Management (URGENT - 30 minutes)

#### 1.1 Cloudflare Configuration
**Priority**: 🔴 CRITICAL  
**Time**: 15 minutes

**Tasks**:
- [ ] Purge Cloudflare cache completely
- [ ] Set Cloudflare cache rules for dynamic content
- [ ] Exclude `/js/`, `/dist/`, `/bundles/` from aggressive caching
- [ ] Set Browser Cache TTL to "Respect Existing Headers"
- [ ] Enable "Development Mode" temporarily (3 hours)

**Cloudflare Page Rules** (Recommended):
```
Rule 1: *technostationery.com/js/*
  - Cache Level: Bypass
  
Rule 2: *technostationery.com/dist/*
  - Cache Level: Bypass
  
Rule 3: *technostationery.com/bundles/*
  - Cache Level: Standard
  - Edge Cache TTL: 2 hours
  
Rule 4: *technostationery.com/enrich/*
  - Cache Level: Bypass
```

#### 1.2 Server-Side Cache Headers
**Priority**: 🔴 CRITICAL  
**Time**: 10 minutes

**Update .htaccess**:
```apache
# In /home/pim/public_html/public/.htaccess

# Prevent caching of dynamic content
<FilesMatch "\.(html|htm|twig|php)$">
    Header set Cache-Control "no-store, no-cache, must-revalidate, max-age=0"
    Header set Pragma "no-cache"
    Header set Expires "0"
</FilesMatch>

# Cache static assets with version parameter
<FilesMatch "\.(js|css|jpg|jpeg|png|gif|svg|woff|woff2)$">
    Header set Cache-Control "public, max-age=31536000"
</FilesMatch>

# Versioned assets can be cached forever
<If "%{QUERY_STRING} =~ /v=/">
    Header set Cache-Control "public, max-age=31536000, immutable"
</If>
```

**Script to apply**:
```bash
cd /home/pim/public_html
php webapp/update_htaccess_headers.php
```

#### 1.3 Verify All Assets
**Priority**: 🟡 HIGH  
**Time**: 5 minutes

**Run verification**:
```bash
cd /home/pim/public_html
bash webapp/final_verification.sh
```

**Expected**:
- ✅ require-paths.js: Browser-compatible
- ✅ jquery.js: Symlink exists
- ✅ process-polyfill.js: 144 bytes
- ✅ Template: v=1777301210
- ✅ Analytics: Disabled

---

### Phase 2: JavaScript & Frontend Fixes (1 hour)

#### 2.1 Fix pim/form-builder Error
**Priority**: 🔴 CRITICAL  
**Time**: 20 minutes

**Root Cause**: RequireJS trying to load non-existent `/bundles/pim/form-builder.js`

**Fix**:
The module is loaded via Akeneo's module registry, not RequireJS paths. Need to ensure module-registry.js is loaded properly.

**Script**:
```bash
cd /home/pim/public_html
cat > webapp/fix_form_builder.php << 'SCRIPT'
<?php
// Check if form-builder is in module registry
$registry = file_get_contents('public/js/module-registry.js');

if (strpos($registry, 'pim/form') !== false) {
    echo "✅ pim/form modules found in registry\n";
} else {
    echo "❌ pim/form modules missing - regenerating...\n";
    system('php bin/console pim:installer:assets --env=prod --symlink');
}

// Verify module-registry is not using module.exports
if (strpos($registry, 'module.exports') !== false) {
    echo "⚠️  module-registry.js has Node.js syntax\n";
    // Fix needed
}
SCRIPT

php webapp/fix_form_builder.php
```

#### 2.2 Ensure process Polyfill Loads First
**Priority**: 🔴 CRITICAL  
**Time**: 10 minutes

**Verify loading order**:
```bash
cd /home/pim/public_html
grep -n "process-polyfill\|vendor.min.js" \
  vendor/akeneo/pim-community-dev/src/Akeneo/Platform/Bundle/UIBundle/Resources/views/index.html.twig
```

**Expected order**:
1. jquery.min.js
2. underscore.min.js  
3. backbone.min.js
4. react.min.js
5. react-dom.min.js
6. router.min.js (FOS)
7. require.min.js
8. require-paths.js
9. **process-polyfill.js** ← MUST be here
10. vendor.min.js
11. main.min.js

#### 2.3 Analytics Error Fix (Permanent)
**Priority**: 🟡 HIGH  
**Time**: 15 minutes

**Current**: Analytics disabled in config (still tries to load)  
**Better**: Remove analytics initialization completely

**Script**:
```bash
cd /home/pim/public_html

# Find where analytics is initialized
grep -r "analytics/collect_data" vendor/akeneo/pim-community-dev/src/Akeneo/Platform/Bundle/AnalyticsBundle/

# Option 1: Disable at route level
cat > config/routes/analytics_override.yaml << 'YAML'
# Disable analytics route
pim_analytics_data_collect:
    path: /analytics/collect_data
    controller: Symfony\Bundle\FrameworkBundle\Controller\RedirectController::urlRedirectAction
    defaults:
        path: /
        statusCode: 410  # Gone
YAML

# Option 2: Override controller
# Create empty controller that returns 204 No Content
```

#### 2.4 Module Registry Verification
**Priority**: 🟡 HIGH  
**Time**: 15 minutes

**Check**:
```bash
cd /home/pim/public_html

# Verify module-registry.js format
head -20 public/js/module-registry.js

# Should be: module.exports = function(moduleName) { ... }
# This is CORRECT for webpack, NOT for browser

# The issue: This file is for webpack bundling, not RequireJS
# RequireJS should NOT load this file
```

**Fix**: Ensure `module-registry.js` is NOT loaded by RequireJS - only by webpack during build

---

### Phase 3: Data Loading & Database (1 hour)

#### 3.1 Verify Database Connectivity
**Priority**: 🔴 CRITICAL  
**Time**: 10 minutes

**Test**:
```bash
cd /home/pim/public_html
php webapp/system_health_check.php
```

**Expected**:
- ✅ Database: PASS
- ✅ Product count: 9,538
- ✅ Elasticsearch: PASS (9,538 indexed)
- ✅ Categories: 166
- ✅ Attributes: 112
- ✅ Families: 18

**If failing**: Check database credentials in `.env`

#### 3.2 Elasticsearch Reindex
**Priority**: 🟡 HIGH  
**Time**: 20 minutes

**Reason**: Data insights not showing = Elasticsearch index stale

**Commands**:
```bash
cd /home/pim/public_html

# 1. Check Elasticsearch health
curl http://127.0.0.1:9200/_cat/health?v

# 2. Check index status
curl http://127.0.0.1:9200/_cat/indices?v | grep akeneo

# 3. Reindex products
php bin/console akeneo:elasticsearch:reset-indexes --env=prod
# This takes ~10-15 minutes for 9,538 products

# 4. Verify count
curl http://127.0.0.1:9200/akeneo_pim_product/_count

# Expected: {"count":9538,...}
```

#### 3.3 Clear Data Quality Insights Cache
**Priority**: 🟡 HIGH  
**Time**: 10 minutes

**Issue**: "Sorry, we don't have enough data yet" = cache issue

**Fix**:
```bash
cd /home/pim/public_html

# Clear DQI cache
php bin/console akeneo:data-quality-insights:schedule-periodic-tasks --env=prod

# Force recalculation
php bin/console akeneo:data-quality-insights:evaluate-products --env=prod

# Check messenger queue
php bin/console messenger:consume --limit=100 --env=prod
```

#### 3.4 Category & Attribute Verification
**Priority**: 🟡 HIGH  
**Time**: 20 minutes

**Test categories**:
```bash
cd /home/pim/public_html

# Count categories
php -r "
\$pdo = new PDO('mysql:host=127.0.0.1;port=3307;dbname=akeneo_pim', 'akeneo_pim', 'akeneo_pim');
\$count = \$pdo->query('SELECT COUNT(*) FROM pim_catalog_category')->fetchColumn();
echo \"Categories: \$count\n\";
"

# Expected: 166
```

**Test attributes**:
```bash
# Count attributes
php -r "
\$pdo = new PDO('mysql:host=127.0.0.1;port=3307;dbname=akeneo_pim', 'akeneo_pim', 'akeneo_pim');
\$count = \$pdo->query('SELECT COUNT(*) FROM pim_catalog_attribute')->fetchColumn();
echo \"Attributes: \$count\n\";
"

# Expected: 112
```

---

### Phase 4: Product Page Fix (30 minutes)

#### 4.1 Test Product List Page
**Priority**: 🔴 CRITICAL  
**Time**: 10 minutes

**URL**: https://pim.technostationery.com/enrich/product/

**Diagnostics**:
```bash
cd /home/pim/public_html

# Check route exists
php bin/console debug:router | grep enrich

# Expected:
# pim_enrich_product_index    GET    /enrich/product/
```

**If 404**: Route configuration issue  
**If blank**: JavaScript initialization failure (frontend errors)  
**If 500**: Server error (check logs)

#### 4.2 Check Error Logs
**Priority**: 🔴 CRITICAL  
**Time**: 10 minutes

**Logs to check**:
```bash
cd /home/pim/public_html

# Symfony logs
tail -50 var/logs/prod.log

# PHP error log
tail -50 error_log

# Specific to products
grep "product" var/logs/prod.log | tail -20
```

#### 4.3 Clear Product Cache
**Priority**: 🟡 HIGH  
**Time**: 10 minutes

**Commands**:
```bash
cd /home/pim/public_html

# Clear product query cache
php bin/console pim:versioning:purge --more-than-days=0 --force --env=prod

# Clear completeness cache
php bin/console pim:completeness:calculate --env=prod

# Verify products load via API
curl -X GET "http://127.0.0.1:8080/api/rest/v1/products?limit=10" \
  -H "Authorization: Bearer {token}"
```

---

### Phase 5: Monitoring & Prevention (Ongoing)

#### 5.1 Real-Time Monitoring Setup
**Priority**: 🟡 HIGH  
**Time**: 30 minutes

**Create monitoring script**:
```bash
cd /home/pim/public_html
cat > webapp/production_monitor.sh << 'MONITOR'
#!/bin/bash
# Production Monitoring - Run every 5 minutes

LOG_FILE="webapp/logs/production_monitor_$(date +%Y%m%d).log"

echo "=== $(date) ===" >> "$LOG_FILE"

# 1. Check if site is responding
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" https://pim.technostationery.com/)
echo "HTTP Status: $HTTP_CODE" >> "$LOG_FILE"

if [ "$HTTP_CODE" != "200" ]; then
    echo "❌ ALERT: Site not responding with 200" >> "$LOG_FILE"
    # Send alert email
    echo "Site down: HTTP $HTTP_CODE" | mail -s "PIM ALERT" webmaster@techno-dz.com
fi

# 2. Check Elasticsearch
ES_STATUS=$(curl -s http://127.0.0.1:9200/_cluster/health | grep -o '"status":"[^"]*"')
echo "Elasticsearch: $ES_STATUS" >> "$LOG_FILE"

# 3. Check database
DB_CHECK=$(php bin/console dbal:run-sql "SELECT 1" 2>&1)
if echo "$DB_CHECK" | grep -q "error"; then
    echo "❌ ALERT: Database connection failed" >> "$LOG_FILE"
else
    echo "✅ Database OK" >> "$LOG_FILE"
fi

# 4. Check product count
PRODUCT_COUNT=$(php -r "\$pdo = new PDO('mysql:host=127.0.0.1;port=3307;dbname=akeneo_pim', 'akeneo_pim', 'akeneo_pim'); echo \$pdo->query('SELECT COUNT(*) FROM pim_catalog_product')->fetchColumn();")
echo "Products: $PRODUCT_COUNT" >> "$LOG_FILE"

if [ "$PRODUCT_COUNT" != "9538" ]; then
    echo "⚠️  WARNING: Product count mismatch" >> "$LOG_FILE"
fi

# 5. Check for JavaScript errors (sample page)
JS_ERRORS=$(curl -s https://pim.technostationery.com/ | grep -o "v=[0-9]*")
echo "Cache version: $JS_ERRORS" >> "$LOG_FILE"

echo "" >> "$LOG_FILE"
MONITOR

chmod +x webapp/production_monitor.sh

# Add to crontab
echo "*/5 * * * * cd /home/pim/public_html && bash webapp/production_monitor.sh" >> /tmp/cron_addition.txt
echo "To add to cron: crontab -e and add the line from /tmp/cron_addition.txt"
```

#### 5.2 Cloudflare Monitoring
**Priority**: 🟡 HIGH  
**Time**: 15 minutes

**Setup**:
1. Enable Cloudflare Analytics
2. Set up alerts for:
   - High error rate (4xx, 5xx)
   - Cache hit ratio drop
   - Origin response time increase

**Cloudflare Page Rule for Bypass** (permanent):
```
URL: *technostationery.com/*nocache=1*
Settings:
  - Cache Level: Bypass
  - Disable Performance
```

#### 5.3 Daily Health Check Automation
**Priority**: 🟡 HIGH  
**Time**: 15 minutes

**Add to existing daily_monitoring.sh**:
```bash
cd /home/pim/public_html

cat >> webapp/daily_monitoring.sh << 'DAILY'

# Frontend checks
echo "=== Frontend Health ==="
echo "1. Checking require-paths.js format..."
if grep -q "module.exports" public/js/require-paths.js; then
    echo "❌ ALERT: require-paths.js has Node.js syntax - needs fixing"
    php webapp/fix_require_paths.php
fi

echo "2. Checking jquery symlink..."
if [ ! -L "public/jquery.js" ]; then
    echo "❌ ALERT: jquery.js symlink missing"
    ln -sf dist/jquery.min.js public/jquery.js
fi

echo "3. Checking process polyfill..."
if [ ! -f "public/dist/process-polyfill.js" ]; then
    echo "❌ ALERT: process-polyfill.js missing"
fi

echo "4. Verifying cache buster..."
CURRENT_CACHE=$(grep "cache_buster" vendor/akeneo/pim-community-dev/src/Akeneo/Platform/Bundle/UIBundle/Resources/views/index.html.twig | head -1)
echo "   $CURRENT_CACHE"

echo "5. Testing product page..."
HTTP_PRODUCT=$(curl -s -o /dev/null -w "%{http_code}" https://pim.technostationery.com/enrich/product/)
echo "   Product page HTTP: $HTTP_PRODUCT"

if [ "$HTTP_PRODUCT" != "200" ]; then
    echo "❌ ALERT: Product page not responding"
fi
DAILY
```

---

## 🎯 SUCCESS CRITERIA

### Phase 1 Complete When:
- [ ] Cloudflare cache purged
- [ ] Emergency bypass URL shows correct version
- [ ] No caching of dynamic pages
- [ ] Asset version parameters working

### Phase 2 Complete When:
- [ ] Browser console shows v=1777301210 (or newer)
- [ ] Zero 404 errors for pim/form-builder
- [ ] Zero "process is not defined" errors
- [ ] Analytics either works or gives 410 Gone (not 500)

### Phase 3 Complete When:
- [ ] Categories show 166 (not 0)
- [ ] Attributes show correct counts
- [ ] Data Quality Insights displays data
- [ ] Elasticsearch has 9,538 products indexed

### Phase 4 Complete When:
- [ ] Product list page loads: https://pim.technostationery.com/enrich/product/
- [ ] Can create/edit products
- [ ] Product grid shows data
- [ ] Filters and search work

### Phase 5 Complete When:
- [ ] Monitoring script running every 5 minutes
- [ ] Daily health check automated
- [ ] Alerting configured
- [ ] Documentation updated

---

## 📞 ESCALATION & SUPPORT

### If Emergency Bypass Doesn't Work
1. Check `.htaccess` is active: `php -i | grep "Loaded Configuration File"`
2. Check Apache modules: `apache2ctl -M | grep headers`
3. Verify PHP is executing: `echo '<?php phpinfo(); ?>' > public/test.php`
4. Check file permissions: `ls -la public/js/require-paths.js`

### If Cloudflare Purge Doesn't Help
1. **Disable Cloudflare temporarily**:
   - Cloudflare Dashboard → DNS
   - Click orange cloud icon to make it gray (DNS only)
   - Wait 5 minutes
   - Test direct to server
   
2. **Check origin server directly**:
   ```
   curl -H "Host: pim.technostationery.com" http://[SERVER_IP]/ -I
   ```

3. **Verify .htaccess headers**:
   ```bash
   curl -I https://pim.technostationery.com/js/require-paths.js
   # Look for: Cache-Control: no-store, no-cache
   ```

### If Data Still Not Loading
1. **Check Elasticsearch**:
   ```bash
   curl http://127.0.0.1:9200/_cluster/health?pretty
   ```
   
2. **Verify MySQL connection**:
   ```bash
   mysql -h 127.0.0.1 -P 3307 -u akeneo_pim -pakeneo_pim -e "SELECT COUNT(*) FROM akeneo_pim.pim_catalog_product"
   ```

3. **Check Messenger queue**:
   ```bash
   php bin/console messenger:stats --env=prod
   ```

### Contact Information
- **Technical Contact**: webmaster@techno-dz.com
- **Repository**: https://github.com/mounirtms/akeneoPim.git
- **Documentation**: `/home/pim/public_html/webapp/`

---

## 📝 EXECUTION CHECKLIST

### Immediate (Next 30 minutes)
- [ ] Test emergency bypass URL in incognito
- [ ] Purge Cloudflare cache (all files)
- [ ] Verify new assets load (v=1777301210)
- [ ] Test product page functionality
- [ ] Check categories/attributes display
- [ ] Verify console has no critical errors

### Short-term (Next 2 hours)
- [ ] Configure Cloudflare page rules
- [ ] Update .htaccess with proper headers
- [ ] Reindex Elasticsearch
- [ ] Clear Data Quality Insights cache
- [ ] Run full system health check
- [ ] Test all major workflows

### Today (Next 8 hours)
- [ ] Set up monitoring script
- [ ] Configure alerting
- [ ] Document issues encountered
- [ ] Create runbook for future
- [ ] Train team on monitoring
- [ ] Schedule follow-up check

### This Week
- [ ] Monitor for 48 hours continuously
- [ ] Optimize cache strategy
- [ ] Review error logs daily
- [ ] Performance testing
- [ ] User acceptance testing

---

## 🔄 ROLLBACK PLAN

If all fixes fail and system remains unstable:

### Option 1: Restore from Backup
```bash
# If you have a working backup from April 26
cd /home/pim
# Restore database
# Restore files
# Restore configuration
```

### Option 2: Disable Cloudflare
```
1. Cloudflare Dashboard → DNS
2. Set all records to "DNS only" (gray cloud)
3. Wait for DNS propagation (5-15 minutes)
4. Test direct server access
5. Debug without CDN interference
```

### Option 3: Minimal Mode
```bash
# Disable all non-essential features
cd /home/pim/public_html

# Disable analytics
echo "akeneo_analytics:" > config/packages/akeneo_analytics.yaml
echo "    is_enabled: false" >> config/packages/akeneo_analytics.yaml

# Disable data quality insights (temporarily)
# Comment out in bundles.php

# Clear all caches
rm -rf var/cache/*

# Restart services
```

---

**Report Generated**: 2026-04-27 15:40:00  
**Priority**: 🔴 CRITICAL  
**Status**: Awaiting User Action (Cloudflare Purge)
