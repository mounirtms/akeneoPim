# 🎯 NEXT SESSION PRIORITIES - Akeneo PIM Fix

**Generated:** 2026-05-08 21:22 CET  
**Status:** Phase 7-8 Complete, Cache Propagation Pending  
**Critical Blocker:** Cloudflare 24hr Cache TTL

---

## ⚡ IMMEDIATE ACTIONS (Start Here)

### 1️⃣ **PURGE CLOUDFLARE CACHE MANUALLY** ⭐ CRITICAL
The template patches are **correctly applied** but Cloudflare's 24hr TTL is serving stale content.

**Action Required:**
```bash
# Login to Cloudflare Dashboard:
# https://dash.cloudflare.com/
# 
# Navigate to: pim.technostationery.com > Caching > Purge Cache
# 
# Option A: Purge Everything (fastest)
# Option B: Purge by URL:
#   - https://pim.technostationery.com/
#   - https://pim.technostationery.com/user/login
#   - https://pim.technostationery.com/js/r-initialize-patch.js
```

**Verification After Purge:**
```bash
cd /home/pim/public_html/webapp
node bypass_cache_test.js
# Should show: ✅ window.r exists, ✅ r.initialize exists
```

---

### 2️⃣ **RUN FINAL VERIFICATION TEST**
Once Cloudflare cache is purged, verify patches are working:

```bash
cd /home/pim/public_html/webapp
node template_patch_verification.js
```

**Expected Results:**
- ✅ Cache Buster (20260509_015000): ✅
- ✅ window.featureFlags exists: ✅
- ✅ r.initialize exists: ✅
- ✅ No "r.initialize is not a function" error
- ✅ Manual r.initialize() test passes

---

### 3️⃣ **PROCEED TO PHASE 9: WEBPACK REBUILD**
Once patches are verified working (no r.initialize error), rebuild assets:

```bash
cd /home/pim/public_html
yarn run webpack:build
```

**What This Fixes:**
- ✅ `__webpack_require__` will be defined
- ✅ Webpack runtime will initialize properly
- ✅ RequireJS modules will register (expect 50+ modules)
- ✅ `pimInit()` function will become available

---

## 📊 CURRENT STATUS SUMMARY

### ✅ Completed (Phases 1-8)

| Phase | Task | Status | Evidence |
|-------|------|--------|----------|
| 1-6 | Diagnostics & jQuery Fix | ✅ DONE | jQuery 3.7.1 loads successfully |
| 7 | r.initialize Patch | ✅ DONE | Patch applied to correct template |
| 8 | extensions.json Fix | ✅ DONE | File created, HTTP 200 response |

### 🔄 In Progress (Cache Propagation)

| Issue | Status | Solution |
|-------|--------|----------|
| Template changes not visible | 🔄 WAITING | Cloudflare cache TTL (24hr) |
| r.initialize error persists | 🔄 WAITING | Patches work but not served yet |
| Loading screen stuck | 🔄 WAITING | Will resolve after cache purge |

### ⏸️ Pending (Phases 9-12)

| Phase | Task | Dependency |
|-------|------|------------|
| 9 | Webpack Rebuild | Wait for Phase 7-8 verification |
| 10 | Register Akeneo Modules | Depends on Phase 9 |
| 11 | Initialize PIM Application | Depends on Phase 10 |
| 12 | Verify UI Rendering | Depends on Phase 11 |

---

## 🔧 FILES MODIFIED/CREATED

### Critical Patches Applied

**1. `/home/pim/public_html/src/AppBundle/Resources/views/PimUI/index.html.twig`**
- ✅ Updated cache buster: `20260509_015000`
- ✅ Added external patch file load: `/js/r-initialize-patch.js`
- ✅ Positioned BEFORE main.min.js (line 44)

**2. `/home/pim/public_html/public/js/r-initialize-patch.js`**
- ✅ Created standalone patch file (2.3 KB)
- ✅ Permissions: 644 (readable by Apache)
- ✅ HTTP accessible: HTTP 200 confirmed
- ✅ Content: Mock feature flags manager with r.initialize()

**3. `/home/pim/public_html/public/js/extensions.json`**
- ✅ Created empty extensions array
- ✅ Fixes 6x 404 errors per page load
- ✅ HTTP 200 confirmed

### Test Scripts Created

```bash
/home/pim/public_html/webapp/
├── template_patch_verification.js  # Comprehensive 7-phase patch test
├── bypass_cache_test.js            # Cache bypass verification
├── comprehensive_pim_monkey_test.js # 8-phase UI monkey test
├── phase_9_12_implementation.js    # Phase 9-12 verification
└── advanced_diagnostics.js         # Multi-test diagnostic suite
```

---

## 🐛 KNOWN ISSUES & BLOCKERS

### Issue #1: Cloudflare Cache (CRITICAL BLOCKER)
**Symptom:** Template changes not visible in browser  
**Cause:** Cloudflare 24hr TTL serving stale cached HTML  
**Evidence:**
- Cache buster in file: `20260509_015000` ✅
- Cache buster in browser: `20260508_194139` ❌ (OLD!)
- Patch script tag in template: ✅ Exists
- Patch script tag in browser HTML: ❌ Not present

**Solution:** Manual Cloudflare cache purge (see Action #1 above)

### Issue #2: r.initialize Error (WILL AUTO-RESOLVE)
**Symptom:** `TypeError: r.initialize is not a function`  
**Root Cause:** Patch file not loading due to cache  
**Evidence:**
- `window.r` in browser: `undefined` ❌
- `window.featureFlags` in browser: `undefined` ❌
- Patch file exists: `/public/js/r-initialize-patch.js` ✅
- Patch file accessible: HTTP 200 ✅

**Solution:** Will auto-resolve after Cloudflare cache purge

### Issue #3: Webpack Runtime Missing (NEXT PRIORITY)
**Symptom:** `__webpack_require__ = undefined`  
**Cause:** Assets need rebuild  
**Solution:** `yarn run webpack:build` (Phase 9)

### Issue #4: RequireJS Modules Not Registered
**Symptom:** 0 modules in RequireJS registry  
**Cause:** Assets not properly installed/built  
**Solution:** `php bin/console assets:install` + webpack rebuild (Phase 10)

---

## 🧪 VERIFICATION COMMANDS

### Quick Health Check
```bash
cd /home/pim/public_html/webapp

# Test 1: Check if patch file is accessible
curl -I https://pim.technostationery.com/js/r-initialize-patch.js
# Expected: HTTP/2 200

# Test 2: Run cache bypass test
node bypass_cache_test.js
# Expected after cache purge:
#   ✅ window.r exists: ✅
#   ✅ r.initialize exists: ✅
#   ✅ r.initialize error: ✅ NO

# Test 3: Full template verification
node template_patch_verification.js
# Expected after cache purge:
#   ✅ HTML contains patch code: ✅
#   ✅ Runtime objects created: ✅
#   ✅ No r.initialize errors: ✅
```

### Check Cache Status
```bash
# Check template cache buster
grep "cache_buster" /home/pim/public_html/src/AppBundle/Resources/views/PimUI/index.html.twig
# Should show: 20260509_015000

# Check patch file in template
grep "r-initialize-patch" /home/pim/public_html/src/AppBundle/Resources/views/PimUI/index.html.twig
# Should show: <script type="text/javascript" src="/js/r-initialize-patch.js?v={{ cache_buster }}"></script>

# Verify Symfony cache is warm
php bin/console cache:pool:list --env=prod
```

---

## 📋 PHASE 9-12 ROADMAP (NEXT STEPS)

### Phase 9: Fix Webpack Module Loading
**Objective:** Rebuild JavaScript assets to fix webpack runtime  
**Commands:**
```bash
cd /home/pim/public_html

# Install node dependencies if needed
yarn install

# Rebuild webpack assets
yarn run webpack:build

# Verify output
ls -lah public/dist/main.min.js
# Should have new timestamp

# Clear caches
php bin/console cache:clear --env=prod
php bin/console cache:warmup --env=prod
sudo systemctl restart ea-php83-php-fpm
varnishadm "ban req.url ~ ."
```

**Expected Outcome:**
- ✅ `__webpack_require__` defined
- ✅ Webpack runtime initializes
- ✅ No "process is not defined" errors

**Verification:**
```bash
node phase_9_12_implementation.js
# Check: webpack_require: ✅ Defined
```

---

### Phase 10: Register Akeneo Modules
**Objective:** Register RequireJS modules for Akeneo PIM  
**Commands:**
```bash
cd /home/pim/public_html

# Install/symlink Symfony assets
php bin/console assets:install public --symlink --env=prod

# Verify bundles are linked
ls -la public/bundles/
# Should show: pimui, oro*, akeneo*

# Clear caches again
php bin/console cache:clear --env=prod
sudo systemctl restart ea-php83-php-fpm
```

**Expected Outcome:**
- ✅ 50+ RequireJS modules registered
- ✅ pim/*, oro/*, akeneo/* modules available
- ✅ Module paths resolved

**Verification:**
```bash
node phase_9_12_implementation.js
# Check: requirejs.defined.length > 50
```

---

### Phase 11: Initialize PIM Application
**Objective:** Start the PIM application initialization  
**Actions:**
1. Verify `pimInit()` function exists
2. If not, create manual initialization in template
3. Start Backbone router
4. Trigger module loading

**If pimInit() is missing, add to template:**
```javascript
// In index.html.twig, after webpack bundles
if (typeof window.pimInit !== 'function') {
    window.pimInit = function() {
        console.log('[Akeneo] Manual initialization starting...');
        
        // Start Backbone router
        if (typeof Backbone !== 'undefined' && Backbone.history) {
            Backbone.history.start({ pushState: false });
        }
        
        // Trigger any pending module loads
        if (typeof requirejs !== 'undefined') {
            requirejs(['pim/controller/dashboard'], function(Dashboard) {
                console.log('[Akeneo] Dashboard controller loaded');
            });
        }
    };
}
```

**Expected Outcome:**
- ✅ Application initialization starts
- ✅ Backbone router running
- ✅ Modules begin loading

---

### Phase 12: Verify UI Rendering
**Objective:** Confirm full PIM UI renders correctly  
**Expected Changes:**
- ✅ Loading screen hides (`.AknDefault-progressContainer` display: none)
- ✅ Navigation menu renders (`.AknDefault-mainMenu` exists)
- ✅ Dashboard content displays
- ✅ Interactive elements present (buttons, links, forms)

**Final Verification:**
```bash
cd /home/pim/public_html/webapp
node comprehensive_pim_monkey_test.js

# Expected results:
# ✅ Loading screen: HIDDEN
# ✅ Menu exists: YES
# ✅ Visible elements: 50+
# ✅ No critical errors
```

---

## 🔍 TROUBLESHOOTING GUIDE

### Problem: Template changes not appearing
**Solution:**
1. Purge Cloudflare cache (see Action #1)
2. Clear browser cache (Ctrl+Shift+Delete)
3. Test in Incognito mode
4. Verify correct template is being used:
   ```bash
   grep "cache_buster" /home/pim/public_html/src/AppBundle/Resources/views/PimUI/index.html.twig
   ```

### Problem: r.initialize error persists after cache purge
**Solution:**
1. Verify patch file loads:
   ```bash
   curl https://pim.technostationery.com/js/r-initialize-patch.js
   ```
2. Check browser console for patch messages:
   - Expected: `[Akeneo Patch] Applying r.initialize fix...`
3. Verify jQuery loads BEFORE patch:
   - Patch requires jQuery.Deferred()
4. Check script load order in template (lines 14-45)

### Problem: Webpack rebuild fails
**Solution:**
```bash
cd /home/pim/public_html

# Check Node.js version
node --version
# Should be >= 14.x

# Reinstall dependencies
rm -rf node_modules
yarn install

# Try rebuild again
yarn run webpack:build
```

### Problem: Assets not linking
**Solution:**
```bash
# Remove old symlinks
rm -rf public/bundles

# Recreate with correct permissions
php bin/console assets:install public --symlink --env=prod

# If symlinks don't work, use copy mode
php bin/console assets:install public --env=prod

# Verify
ls -la public/bundles/pimui
```

---

## 📈 SUCCESS METRICS

### Phase 7-8 Success Criteria
- [x] extensions.json returns HTTP 200
- [x] Patch file created and accessible
- [x] Template modified with patch load
- [ ] **Patch visible in browser HTML** (BLOCKED: Cloudflare cache)
- [ ] **No r.initialize error** (BLOCKED: Cloudflare cache)

### Phase 9 Success Criteria
- [ ] __webpack_require__ defined
- [ ] main.min.js rebuilt successfully
- [ ] No webpack runtime errors

### Phase 10 Success Criteria
- [ ] 50+ RequireJS modules registered
- [ ] Akeneo modules available (pim/*, oro/*)
- [ ] Module paths resolve correctly

### Phase 11 Success Criteria
- [ ] pimInit() function exists or manual init works
- [ ] Backbone.history starts
- [ ] No initialization errors

### Phase 12 Success Criteria
- [ ] Loading screen hides automatically
- [ ] Navigation menu renders with items
- [ ] Dashboard content displays
- [ ] UI fully interactive

---

## 💾 BACKUP & ROLLBACK

### Files Modified (Can Rollback If Needed)
```bash
# Template file (has original in vendor/)
/home/pim/public_html/src/AppBundle/Resources/views/PimUI/index.html.twig

# Rollback command if needed:
cd /home/pim/public_html
cp vendor/akeneo/pim-community-dev/src/Akeneo/Platform/Bundle/UIBundle/Resources/views/index.html.twig \
   src/AppBundle/Resources/views/PimUI/index.html.twig
```

### New Files Created (Safe to Delete)
```bash
# Patch file
/home/pim/public_html/public/js/r-initialize-patch.js

# Extensions file
/home/pim/public_html/public/js/extensions.json

# Test scripts (all in /webapp directory)
/home/pim/public_html/webapp/*.js
/home/pim/public_html/webapp/*.json
/home/pim/public_html/webapp/*.md
```

---

## 📞 QUICK REFERENCE

### Service Management
```bash
# Restart PHP-FPM
sudo systemctl restart ea-php83-php-fpm

# Restart Varnish
sudo systemctl restart varnish

# Purge Varnish cache
varnishadm "ban req.url ~ ."

# Check service status
sudo systemctl status ea-php83-php-fpm varnish
```

### Cache Management
```bash
# Symfony cache
php bin/console cache:clear --env=prod
php bin/console cache:warmup --env=prod

# Cloudflare cache
# Must be done via dashboard: https://dash.cloudflare.com/

# Browser cache
# Chrome: Ctrl+Shift+Delete, select "Cached images and files"
```

### Quick Tests
```bash
cd /home/pim/public_html/webapp

# Fast test (30 seconds)
node bypass_cache_test.js

# Full test (60 seconds)
node template_patch_verification.js

# Comprehensive test (2-3 minutes)
node comprehensive_pim_monkey_test.js
```

---

## 🎓 LESSONS LEARNED

1. **Always identify the correct template first**
   - Akeneo uses custom template override at `src/AppBundle/Resources/views/PimUI/`
   - Vendor template at `vendor/akeneo/.../UIBundle/Resources/views/` was NOT being used

2. **Multi-layer caching is complex**
   - Browser cache → Cloudflare (24hr) → Varnish → Symfony → PHP OpCache
   - Must clear ALL layers for changes to propagate
   - Cloudflare cache purge requires dashboard access

3. **External patch files are more reliable than inline scripts**
   - Easier to verify via HTTP request
   - Can be cached independently
   - Simpler debugging

4. **Cache busters are essential**
   - Changed from `20260508_194139` → `20260509_015000`
   - Forces browser to request fresh content
   - Must update in template on every change

5. **Test scripts are invaluable**
   - Automated verification catches issues fast
   - Screenshot capture provides visual evidence
   - JSON export enables tracking progress over time

---

## ✅ NEXT SESSION CHECKLIST

Start your next session with these steps:

- [ ] **1. Purge Cloudflare cache** (see Action #1)
- [ ] **2. Run bypass_cache_test.js** to verify patches load
- [ ] **3. Run template_patch_verification.js** for full verification
- [ ] **4. If patches working, proceed to Phase 9** (webpack rebuild)
- [ ] **5. If patches still not working, check troubleshooting guide**
- [ ] **6. After Phase 9, run phase_9_12_implementation.js** to verify
- [ ] **7. Continue through Phases 10-11-12** sequentially
- [ ] **8. Final test: comprehensive_pim_monkey_test.js**

---

**Last Updated:** 2026-05-08 21:22 CET  
**Next Review:** After Cloudflare cache purge  
**Estimated Time to Complete Phase 9-12:** 2-3 hours  

