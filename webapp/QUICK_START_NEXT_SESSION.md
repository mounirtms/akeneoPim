# ⚡ QUICK START GUIDE - NEXT SESSION
## Get Started Immediately with Phase 7 & 8

**Last Updated:** 2026-05-08  
**Time to First Fix:** 15 minutes  
**Priority:** Fix r.initialize and extensions.json

---

## 🚀 IMMEDIATE ACTIONS (Copy & Paste)

### Step 1: Verify Current State (30 seconds)

```bash
cd /home/pim/public_html/webapp
node advanced_diagnostics.js 2>&1 | grep -E "(✅|❌)" | head -20
```

**Expected Output:**
```
❌ extensions.json errors
❌ r.initialize is not a function
❌ __webpack_require__ defined: false
✅ RequireJS defined: true
✅ Backbone.Router exists: true
```

---

## 🔴 CRITICAL FIX #1: Create extensions.json (5 minutes)

### Execute These Commands:

```bash
# Navigate to Akeneo root
cd /home/pim/public_html

# Create js directory
mkdir -p public/js

# Create minimal extensions.json
cat > public/js/extensions.json << 'ENDOFFILE'
{
  "extensions": []
}
ENDOFFILE

# Set permissions
chmod 644 public/js/extensions.json

# Verify file created
ls -lah public/js/extensions.json
cat public/js/extensions.json

# Clear Varnish cache
varnishadm "ban req.url ~ /js/extensions.json"

# Test HTTP response
curl -I https://pim.technostationery.com/js/extensions.json

# Test in browser context
cd /home/pim/public_html/webapp
node -e "
const https = require('https');
https.get('https://pim.technostationery.com/js/extensions.json', (res) => {
  console.log('Status:', res.statusCode === 200 ? '✅ 200 OK' : '❌ ' + res.statusCode);
  res.on('data', d => console.log('Content:', d.toString()));
});
"
```

**Success Criteria:**
- ✅ File exists at `/home/pim/public_html/public/js/extensions.json`
- ✅ Returns HTTP 200
- ✅ Contains valid JSON: `{"extensions":[]}`

---

## 🔴 CRITICAL FIX #2: Fix r.initialize Error (10-30 minutes)

You have **3 options** - try them in order:

---

### OPTION A: Rebuild JS Assets (RECOMMENDED - 10 minutes)

```bash
cd /home/pim/public_html

# Check if yarn is installed
which yarn

# If yarn exists, rebuild assets
yarn install --frozen-lockfile 2>&1 | tail -20
yarn run webpack:build 2>&1 | tail -20

# Clear Symfony cache
php bin/console cache:clear --env=prod --no-warmup
php bin/console cache:warmup --env=prod

# Restart services
sudo systemctl restart varnish
sudo systemctl restart ea-php83-php-fpm
sudo systemctl reload httpd

# Test immediately
cd /home/pim/public_html/webapp
node advanced_diagnostics.js 2>&1 | grep "initialize"
```

**If yarn is not installed:**
```bash
# Check for npm
which npm

# Use npm if available
npm install
npm run build
```

---

### OPTION B: Quick Patch main.min.js (TEMPORARY - 5 minutes)

Add this to the template **BEFORE** main.min.js loads:

```bash
cd /home/pim/public_html

# Backup current template
cp vendor/akeneo/pim-community-dev/src/Akeneo/Platform/Bundle/UIBundle/Resources/views/index.html.twig \
   vendor/akeneo/pim-community-dev/src/Akeneo/Platform/Bundle/UIBundle/Resources/views/index.html.twig.backup_phase7

# Edit template - add this AFTER vendor libraries load, BEFORE main.min.js
```

**Add this code block to template:**

```html
{# TEMPORARY FIX: Mock feature flags manager #}
<script type="text/javascript">
console.log('[Akeneo] Patching feature flags manager...');

// Create mock feature flags manager
if (typeof window.featureFlags === 'undefined') {
    window.featureFlags = {
        initialize: function() {
            console.log('[Akeneo] Feature flags initialized (mock)');
            return jQuery.Deferred().resolve();
        },
        isEnabled: function(feature) {
            console.log('[Akeneo] Checking feature:', feature, '(returning true)');
            return true; // Enable all features
        }
    };
}

// Also try global r
if (typeof window.r === 'undefined' || typeof window.r.initialize !== 'function') {
    window.r = window.featureFlags;
}

console.log('[Akeneo] Feature flags patch applied');
</script>
```

**Location to add:** Between lines where vendor.min.js loads and main.min.js loads

```bash
# Clear caches after edit
php bin/console cache:clear --env=prod
sudo systemctl restart varnish
sudo systemctl restart ea-php83-php-fpm
```

---

### OPTION C: Find and Fix Source (THOROUGH - 30 minutes)

```bash
cd /home/pim/public_html

# Step 1: Find where r is defined
grep -r "var r\s*=" vendor/akeneo/pim-community-dev/src/Akeneo/Platform/Bundle/UIBundle/Resources/public/js/ --include="*.js" | grep -i feature

# Step 2: Find extension fetcher
find vendor/akeneo/pim-community-dev/src/Akeneo/Platform/Bundle/UIBundle/Resources/public/js -name "*extension*" -o -name "*fetcher*"

# Step 3: Check the likely source file
# Based on error context, look for extension/fetcher.js or similar
ls -la vendor/akeneo/pim-community-dev/src/Akeneo/Platform/Bundle/UIBundle/Resources/public/js/extension/

# Step 4: If found, examine the file
cat vendor/akeneo/pim-community-dev/src/Akeneo/Platform/Bundle/UIBundle/Resources/public/js/extension/fetcher.js

# Step 5: Add null check to the source file
# Look for the line with e.when(e.get("/js/extensions.json"), t.initialize(), r.initialize())
# Change to: e.when(e.get("/js/extensions.json"), t.initialize(), r.initialize ? r.initialize() : $.Deferred().resolve())

# Step 6: Rebuild
yarn run webpack:build
```

---

## ✅ VERIFY FIXES (2 minutes)

After applying **both** fixes:

```bash
cd /home/pim/public_html/webapp

# Quick verification
node -e "
const playwright = require('playwright');
(async () => {
    const browser = await playwright.chromium.launch({ headless: true });
    const page = await browser.newPage();
    
    let errors = [];
    page.on('pageerror', err => errors.push(err.message));
    
    console.log('🧪 Testing fixes...\n');
    
    await page.goto('https://pim.technostationery.com/user/login', { 
        waitUntil: 'networkidle', 
        timeout: 30000 
    });
    await page.fill('input[name=\"_username\"]', 'mounir');
    await page.fill('input[name=\"_password\"]', '2026');
    await page.click('button[type=\"submit\"]');
    await page.waitForTimeout(6000);
    
    // Check extensions.json
    const extensionsResponse = await page.evaluate(() => {
        return fetch('/js/extensions.json').then(r => r.status);
    });
    
    // Check for errors
    const hasInitError = errors.some(e => e.includes('r.initialize'));
    const has404 = errors.some(e => e.includes('404'));
    
    console.log('Results:');
    console.log('  extensions.json:', extensionsResponse === 200 ? '✅ HTTP 200' : '❌ HTTP ' + extensionsResponse);
    console.log('  r.initialize error:', hasInitError ? '❌ STILL EXISTS' : '✅ FIXED');
    console.log('  404 errors:', has404 ? '⚠️ SOME EXIST' : '✅ NONE');
    console.log('  Total errors:', errors.length);
    
    if (errors.length > 0) {
        console.log('\nErrors found:');
        errors.forEach(e => console.log('  -', e));
    }
    
    await browser.close();
})();
"
```

**Expected Output After Fixes:**
```
Results:
  extensions.json: ✅ HTTP 200
  r.initialize error: ✅ FIXED
  404 errors: ✅ NONE
  Total errors: 0
```

---

## 🎯 IF BOTH FIXES WORK - NEXT STEPS

### Phase 11: Initialize PIM Application

```bash
cd /home/pim/public_html

# Check if pimInit exists after fixes
node -e "
const playwright = require('playwright');
(async () => {
    const browser = await playwright.chromium.launch();
    const page = await browser.newPage();
    await page.goto('https://pim.technostationery.com/user/login');
    await page.fill('input[name=\"_username\"]', 'mounir');
    await page.fill('input[name=\"_password\"]', '2026');
    await page.click('button[type=\"submit\"]');
    await page.waitForTimeout(6000);
    
    const check = await page.evaluate(() => ({
        pimInit: typeof pimInit === 'function',
        pimApp: typeof window.pim !== 'undefined' && typeof window.pim.app !== 'undefined',
        requireDefined: typeof require === 'function',
        backboneRouter: typeof Backbone !== 'undefined' && Backbone.history !== undefined
    }));
    
    console.log('Application State:');
    console.log('  pimInit():', check.pimInit ? '✅ EXISTS' : '❌ MISSING');
    console.log('  pim.app:', check.pimApp ? '✅ EXISTS' : '❌ MISSING');
    console.log('  require():', check.requireDefined ? '✅ EXISTS' : '❌ MISSING');
    console.log('  Backbone.history:', check.backboneRouter ? '✅ EXISTS' : '❌ MISSING');
    
    await browser.close();
})();
"
```

If pimInit doesn't exist, add initialization code to template:

```javascript
// Add AFTER all scripts load in template
<script type="text/javascript">
(function() {
    console.log('[Akeneo] Attempting to initialize application...');
    
    // Check dependencies
    if (typeof $ === 'undefined') {
        console.error('[Akeneo] jQuery not loaded');
        return;
    }
    
    if (typeof Backbone === 'undefined') {
        console.error('[Akeneo] Backbone not loaded');
        return;
    }
    
    if (typeof require === 'undefined') {
        console.error('[Akeneo] RequireJS not loaded');
        return;
    }
    
    // Try to start via RequireJS
    $(document).ready(function() {
        console.log('[Akeneo] DOM ready, loading app module...');
        
        require(['pim/app'], function(App) {
            console.log('[Akeneo] App module loaded, starting...');
            try {
                App.start();
                console.log('[Akeneo] ✅ App started successfully');
                
                // Hide loading screen
                setTimeout(function() {
                    $('.AknDefault-progressContainer').fadeOut();
                }, 1000);
            } catch (e) {
                console.error('[Akeneo] Failed to start app:', e);
            }
        }, function(err) {
            console.error('[Akeneo] Failed to load app module:', err);
            
            // Fallback: hide loading screen anyway
            setTimeout(function() {
                $('.AknDefault-progressContainer').fadeOut();
                console.warn('[Akeneo] Loading screen hidden (fallback)');
            }, 3000);
        });
    });
})();
</script>
```

---

## 📊 FULL STATUS CHECK (1 minute)

Run comprehensive test:

```bash
cd /home/pim/public_html/webapp
node comprehensive_error_capture.js 2>&1 | tail -50
```

**What to look for:**
- ✅ jQuery loaded: 3.7.1
- ✅ Dashboard reached: #/dashboard
- ✅ extensions.json: 0 errors
- ✅ initialize errors: 0
- ❓ Menu visible: check this
- ❓ Loading stuck: check this

---

## 🔍 TROUBLESHOOTING

### If extensions.json still 404:

```bash
# Check file exists
ls -lah /home/pim/public_html/public/js/extensions.json

# Check Apache can read it
sudo -u apache cat /home/pim/public_html/public/js/extensions.json

# Check .htaccess isn't blocking
cat /home/pim/public_html/public/.htaccess | grep -i "deny\|block"

# Bypass Varnish temporarily
curl -H "Cache-Control: no-cache" https://pim.technostationery.com/js/extensions.json

# Check actual server response
curl -v https://pim.technostationery.com/js/extensions.json 2>&1 | grep -E "HTTP|Content-Type"
```

### If r.initialize still fails:

```bash
# Check if patch was applied
grep -n "featureFlags" /home/pim/public_html/vendor/akeneo/pim-community-dev/src/Akeneo/Platform/Bundle/UIBundle/Resources/views/index.html.twig

# Check cache was cleared
ls -la /home/pim/public_html/var/cache/prod/

# Force template reload
php bin/console cache:clear --env=prod --no-warmup
sudo systemctl restart varnish

# Check browser console directly
firefox https://pim.technostationery.com/user/login
# Login and check console for errors
```

### If nothing works:

```bash
# Restore backup
cp /home/pim/public_html/vendor/akeneo/pim-community-dev/src/Akeneo/Platform/Bundle/UIBundle/Resources/views/index.html.twig.backup_phase7 \
   /home/pim/public_html/vendor/akeneo/pim-community-dev/src/Akeneo/Platform/Bundle/UIBundle/Resources/views/index.html.twig

# Clear everything
php bin/console cache:clear --env=prod
sudo systemctl restart varnish
sudo systemctl restart ea-php83-php-fpm
sudo systemctl reload httpd

# Try Option A (rebuild) instead
```

---

## 📝 DOCUMENT YOUR CHANGES

After each fix:

```bash
cd /home/pim/public_html/webapp

# Update log
echo "$(date): Applied Fix - extensions.json created" >> session_log.txt
echo "$(date): Applied Fix - r.initialize patched" >> session_log.txt

# Take screenshots
node -e "
const playwright = require('playwright');
(async () => {
    const browser = await playwright.chromium.launch();
    const page = await browser.newPage();
    await page.goto('https://pim.technostationery.com/user/login');
    await page.fill('input[name=\"_username\"]', 'mounir');
    await page.fill('input[name=\"_password\"]', '2026');
    await page.click('button[type=\"submit\"]');
    await page.waitForTimeout(6000);
    await page.screenshot({ path: 'phase7_after_fixes.png', fullPage: true });
    await browser.close();
    console.log('Screenshot saved: phase7_after_fixes.png');
})();
"
```

---

## ⏱️ TIME ESTIMATES

```
Create extensions.json:     5 minutes
Fix r.initialize (Option B): 5 minutes
Verify fixes:                2 minutes
Initialize PIM:             10 minutes
Full testing:                5 minutes
Documentation:               3 minutes
────────────────────────────────────
Total (Quick Path):         30 minutes
Total (Full Rebuild):       45 minutes
```

---

## 🎯 SUCCESS CRITERIA

**After Phase 7 & 8:**
- [ ] extensions.json returns HTTP 200
- [ ] No "r.initialize is not a function" error
- [ ] No 404 errors for extensions.json
- [ ] Promise chain completes
- [ ] Dashboard initialization proceeds

**Bonus (if time allows):**
- [ ] Menu renders
- [ ] Loading screen hides
- [ ] Dashboard content visible

---

## 📞 QUICK REFERENCE

**Test Scripts:**
```bash
advanced_diagnostics.js           # Full diagnostic
comprehensive_error_capture.js    # Error capture
```

**Important Files:**
```
Template: vendor/akeneo/.../UIBundle/Resources/views/index.html.twig
Extensions: public/js/extensions.json
Main JS: public/dist/main.min.js
```

**Cache Commands:**
```bash
php bin/console cache:clear --env=prod
sudo systemctl restart varnish
sudo systemctl restart ea-php83-php-fpm
```

---

**Ready to Start!** 🚀

1. Run Step 1 verification
2. Apply Critical Fix #1 (extensions.json)
3. Apply Critical Fix #2 (r.initialize)
4. Verify both fixes
5. Proceed to initialization

*Good luck! You got this!* 💪
