# Akeneo PIM - Old Branch Build & Fix Plan

## Current Status (oldbranch)

### ✅ What's Working
1. **Authentication** - Login works (testadmin/testpass)
2. **Assets Present** - All files exist:
   - `/public/css/pim.css` (497 KB)
   - `/public/dist/main.min.js` (1.6 MB)
   - `/public/dist/vendor.min.js` (3.3 MB)
   - `/public/js/extensions.json` (515 B)
   - `/public/js/module-registry.js` (101 KB)
3. **No Loading Screen** - The loading spinner clears
4. **Assets Load** - HTTP 200 for all assets

### ❌ What's NOT Working
1. **Dashboard UI** - After login, dashboard menu doesn't render
2. **App Container** - Div with class="app" visible but empty (no content)
3. **PIM Initialization** - JavaScript not executing to build the dashboard

### 🔍 Root Cause Analysis

**Problem**: The PIM application is not initializing after page load.

**Investigation Findings**:
- ✅ All asset files (CSS, JS) load successfully
- ✅ No 404 errors in console
- ✅ No JavaScript errors
- ❌ The webpack entry point is NOT executing
- ❌ PIM form-builder is not being called

**Comparison with pimAkeno Branch**:
Both branches have the SAME issue - the dashboard doesn't render after login.

This suggests the **webpack bundles themselves** have a build issue, not the template.

## Solution Strategy

### Option 1: Use Pre-Built Working Assets (RECOMMENDED)
If we have a known working commit where the dashboard WAS rendering:
1. Checkout that commit
2. Copy the working `main.min.js` and `vendor.min.js`
3. Use those assets with current database

### Option 2: Debug Webpack Bundle
1. Check webpack configuration
2. Verify entry points
3. Rebuild with verbose logging
4. Test bundle execution

### Option 3: Use API-Only Approach
Since backend/API is fully functional:
1. Skip UI debugging
2. Use REST API directly for Magento sync
3. Document UI as known issue

## Key Files & Locations

### Critical Build Files
```
/home/pim/public_html/
├── public/
│   ├── css/pim.css (✅ 497 KB)
│   ├── dist/
│   │   ├── main.min.js (✅ 1.6 MB)
│   │   ├── vendor.min.js (✅ 3.3 MB)
│   │   ├── process-polyfill.js (✅ 144 B)
│   │   ├── jquery.min.js
│   │   ├── underscore.min.js
│   │   ├── backbone.min.js
│   │   ├── react.min.js
│   │   ├── react-dom.min.js
│   │   └── require.min.js (✅ 85 KB)
│   └── js/
│       ├── extensions.json (✅ 515 B)
│       ├── module-registry.js (✅ 101 KB)
│       ├── require-paths.js (✅ 3.3 KB)
│       └── fos_js_routes.json (✅ 79 KB)
```

### UI Template
```
vendor/akeneo/pim-community-dev/src/Akeneo/Platform/Bundle/UIBundle/Resources/views/index.html.twig
```

**Current Template Issues**:
- Missing RequireJS paths loading: `/js/require-paths.js`
- Missing PIM initialization script
- Not loading `process-polyfill.js`

### Build Commands
```bash
# Compile CSS
yarn run less

# Build JavaScript (WARNING: Currently fails with webpack conflict)
yarn run webpack --env=prod

# Install Symfony assets
bin/console assets:install public --symlink --env=prod

# Clear and warm cache
rm -rf var/cache/prod/*
bin/console cache:warmup --env=prod
```

## Useful Changes from pimAkeno Branch

### Documentation Files to Copy
```
webapp/
├── BUILD_COMMANDS.md
├── AUTHENTICATION_FIXED_SYSTEM_STABLE.md
├── LOADING_SCREEN_FIX_COMPLETE.md
├── DATABASE_VERIFICATION_COMPLETE.md
└── build.sh (comprehensive build script)
```

### Test Scripts to Copy
```
webapp/
├── test_loading_screen_fix.js
├── comprehensive_ui_test.js
└── test_login_properly.js
```

### Build Scripts
The `webapp/build.sh` from pimAkeno contains:
1. CSS compilation
2. Webpack build
3. Extensions.json copy fix
4. Asset installation
5. Cache management
6. Permission fixes
7. Verification steps

## Recommended Next Steps

1. **Find Working Commit**
   ```bash
   git log --all --oneline | grep -i "working\|success\|fix"
   ```

2. **Test Each Commit**
   - Checkout each candidate
   - Test dashboard rendering
   - Note which commit works

3. **Extract Working Assets**
   - From working commit, copy:
     - `public/dist/main.min.js`
     - `public/dist/vendor.min.js`
   - Apply to current oldbranch

4. **Update Template**
   - Add RequireJS configuration
   - Add PIM initialization script
   - Add process-polyfill.js loading

5. **Test & Verify**
   - Login
   - Check dashboard renders
   - Verify menu appears
   - Test navigation

## Database Status
```
✅ MariaDB 10.6.17
✅ 9,538 products
✅ 166 categories
✅ 112 attributes
✅ 18 families
✅ REST API functional
```

## Access Information
- **URL**: https://pim.technostationery.com/
- **Login**: testadmin / testpass
- **Repository**: https://github.com/mounirtms/akeneoPim.git
- **Current Branch**: oldbranch
- **Working Directory**: /home/pim/public_html/

## Time Estimate
- Option 1 (Use working assets): 30 minutes
- Option 2 (Debug webpack): 2-3 hours
- Option 3 (API-only): Immediate (proceed with sync)

## Success Criteria
✅ Login works
✅ Dashboard renders after login
✅ Navigation menu visible
✅ Can navigate to Products, Categories, etc.
✅ No console errors
✅ All assets load (HTTP 200)
