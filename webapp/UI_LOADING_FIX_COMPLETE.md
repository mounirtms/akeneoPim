# Akeneo PIM UI Loading Issue - FINAL FIX
**Date:** April 26, 2026  
**Status:** ✅ **ROOT CAUSE IDENTIFIED & PARTIAL FIX APPLIED**

## Problem Summary
The Akeneo PIM dashboard showed a perpetual "Loading..." screen after login. The UI never initialized despite successful authentication.

## Root Cause Analysis

### Issue 1: AMD vs ES6 Module System Conflict ✅ FIXED
- **Problem:** The webpack entry point (`public/bundles/pimui/js/index.js`) used AMD `define()` syntax
- **Impact:** Webpack 5 bundles AMD modules but doesn't auto-execute them without a global AMD loader
- **Solution Applied:** Converted `index.js` from AMD to ES6 module format using `module-registry` import

**Original AMD Code:**
```javascript
define(['jquery', 'pim/form-builder'], function ($, formBuilder) {
  formBuilder.build('pim-app').then(function (form) {
    form.setElement($('.app'));
    form.render();
  });
});
```

**Fixed ES6 Code:**
```javascript
import $ from 'jquery';
import moduleRegistry from 'module-registry';

const formBuilder = moduleRegistry('pim/form-builder');
formBuilder.build('pim-app').then(function (form) {
  form.setElement($('.app'));
  form.render();
});
```

### Issue 2: Form Extension Registry Not Loaded ⚠️ IN PROGRESS
- **Problem:** The `pim-app` form extension is not found in the form registry
- **Error:** `The extension "pim-app" was not found. Are you sure you registered it properly?`
- **Cause:** Form extensions are registered through Symfony configuration (`app.yml`) but the JavaScript form registry is not properly initialized
- **Location:** `vendor/akeneo/pim-community-dev/src/Akeneo/Platform/Bundle/UIBundle/Resources/config/form_extensions/common/app.yml`

## Progress Made

### ✅ Completed
1. Identified AMD/Webpack incompatibility as root cause
2. Converted entry point from AMD to ES6 module format
3. Successfully loaded `formBuilder` module using `module-registry`
4. Webpack bundles rebuild successfully (main.min.js: 1.59 MiB, vendor.min.js: 3.29 MiB)
5. Entry point now auto-executes (verified via Playwright console logs)

### ⚠️ Remaining Issue
The form extension registry system needs to be properly initialized. The `pim-app` extension is defined in YAML configuration but isn't being registered in the JavaScript runtime.

## Console Log Evidence (Playwright Test)
```
✓ [log] PIM: Loading form-builder from registry...
✓ [log] PIM: form-builder loaded, building pim-app...
❌ [error] PIM: Failed to build/render form: Error: 
   The extension "pim-app" was not found. Are you sure you registered it properly?
   Check your form_extension files and be sure to clear your prod cache before proceeding
```

## Technical Details

### Form Extension Configuration
File: `vendor/akeneo/pim-community-dev/src/Akeneo/Platform/Bundle/UIBundle/Resources/config/form_extensions/common/app.yml`
```yaml
extensions:
    pim-app:
        module: pim/app
```

### PIM App Module
File: `public/bundles/pimui/js/pim-app.ts`
- Exports a `PimApp` class extending `BaseView`
- Handles app initialization, layout, translator, user context
- Registered in requirejs.yml as `pim/app: pimui/js/pim-app.ts`

## Next Steps Required

### Option 1: Fix Form Registry Loading (Recommended)
The form extension registry needs to be properly loaded into the JavaScript runtime. This requires:
1. Understanding how Akeneo CE 6.0 loads form extensions from YAML config
2. Ensuring the form registry is dumped/cached correctly
3. Possibly running additional Symfony console commands to generate the registry

### Option 2: Direct Module Loading (Workaround)
Instead of using `formBuilder.build('pim-app')`, directly import and instantiate the PimApp class:
```javascript
import $ from 'jquery';
import PimApp from 'pimui/js/pim-app';

const app = new PimApp();
app.setElement($('.app'));
app.configure().then(() => {
  app.render();
});
```

### Option 3: Contact Original Developer
**Mounir Abderrahmani** (mounir.ab@techno-dz.com) created the working webpack configuration in commit `216568f`. He would know:
- The correct sequence of build commands
- Any missing configuration steps
- How form extensions should be registered in the webpack build

## Commands Used

### Build Commands
```bash
# Compile CSS from LESS
yarn run less

# Rebuild webpack bundles (production)
yarn run webpack --env=prod

# Install assets
bin/console pim:installer:assets --symlink --clean --env=prod

# Dump require paths
bin/console pim:installer:dump-require-paths

# Clear production cache
rm -rf var/cache/prod/*
bin/console cache:warmup --env=prod --no-debug
```

## Files Modified

### 1. public/bundles/pimui/js/index.js
**Purpose:** Webpack entry point  
**Change:** Converted from AMD to ES6 module with module-registry

### 2. Backup Created
- `public/bundles/pimui/js/index.js.backup` - Original AMD version

## Test Results

### Playwright Test Output
```
✓ Dashboard URL reached
✓ App element exists
✓ Loading screen visible (but should be hidden after render)
✓ formBuilder module loaded successfully
❌ pim-app form extension not found in registry
```

### Current State
- Login: ✅ Working
- Authentication: ✅ Working  
- Redirect to dashboard: ✅ Working
- CSS styles: ✅ Loading correctly
- JavaScript bundles: ✅ Loading correctly
- Entry point execution: ✅ Working
- FormBuilder module: ✅ Loading
- Form extension registry: ❌ **Not initialized**
- UI rendering: ❌ Blocked by registry issue

## Recommendations

**Immediate Action:**  
Contact Mounir Abderrahmani or an Akeneo CE 6.0 specialist who understands the form extension registry system in webpack-based builds.

**Timeline Estimate:**  
With proper expertise: 2-4 hours to complete the form registry fix.

## Repository
- Branch: `pimAkeno`
- Latest commits include AMD-to-ES6 conversion and webpack rebuild

---
**Conclusion:** We've made significant progress by fixing the AMD/Webpack incompatibility. The entry point now executes correctly and loads the formBuilder module. The remaining blocker is the form extension registry initialization, which requires Akeneo-specific knowledge or assistance from the original developer.
