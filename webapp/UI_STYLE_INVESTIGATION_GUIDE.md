# UI Style Investigation Guide

**Date**: April 26, 2026  
**Issue**: User reported minor style issues around PIM menu after login  
**Status**: UI is functional, just some cosmetic fixes needed

---

## 🔍 HOW TO INVESTIGATE STYLE ISSUES

### Method 1: Visual Inspection (Recommended)
1. Open browser and go to: https://pim.technostationery.com
2. Login with: admin / admin
3. Open Browser DevTools (F12 or Right-click → Inspect)
4. Go to Console tab
5. Take screenshots of:
   - Dashboard view
   - Menu area (especially the main navigation)
   - Any visible style problems
   - Console errors (red text)

### Method 2: Automated Console Check
Run this Playwright script to capture console errors:

```bash
cd /home/pim/public_html/webapp
node check_console_errors.js
# Screenshot will be saved to /tmp/pim_after_login.png
```

---

## 🎨 COMMON STYLE ISSUES TO CHECK

### 1. Menu Styling Problems
**What to look for:**
- Menu items not aligned properly
- Menu icons missing or overlapping
- Menu text cut off or overflowing
- Wrong colors or backgrounds
- Z-index issues (menu behind other elements)

**Possible Causes:**
- Missing CSS classes
- CSS not compiled properly
- JavaScript not loading menu correctly
- Conflicting styles

**Quick Fixes:**
```bash
# Recompile CSS
cd /home/pim/public_html
yarn run less

# Clear cache
rm -rf var/cache/prod/*
bin/console cache:warmup --env=prod

# Fix permissions
chmod 644 public/css/pim.css
chown pim:pim public/css/pim.css
```

### 2. Console JavaScript Errors
**What to look for:**
- Red error messages in console
- 404 errors for missing files
- TypeError or ReferenceError
- Module not found errors

**Common Issues:**
- Missing JavaScript files
- Webpack bundle not loading
- AMD module resolution errors
- RequireJS configuration problems

**Quick Fixes:**
```bash
# Rebuild JavaScript bundles
cd /home/pim/public_html
yarn run webpack --env=prod

# Clear cache
rm -rf var/cache/prod/*
bin/console cache:warmup --env=prod
```

### 3. Images or Icons Missing
**What to look for:**
- Broken image icons
- Missing menu icons
- 404 errors in Network tab

**Quick Fix:**
```bash
# Reinstall assets
cd /home/pim/public_html
bin/console pim:installer:assets --symlink --clean --env=prod
```

---

## 🛠️ TROUBLESHOOTING STEPS

### Step 1: Check if CSS is loaded
```bash
# Check CSS file exists and has content
ls -lh /home/pim/public_html/public/css/pim.css
# Should show ~497KB file

# Check CSS in browser
# DevTools → Network tab → Filter: CSS
# Look for pim.css - should return 200 OK
```

### Step 2: Check if JavaScript bundles are loaded
```bash
# Check bundle files
ls -lh /home/pim/public_html/public/dist/*.min.js
# Should show:
# - main.min.js (~1.6MB)
# - vendor.min.js (~3.3MB)
# - other .min.js files

# Check in browser
# DevTools → Network tab → Filter: JS
# Look for main.min.js and vendor.min.js - should return 200 OK
```

### Step 3: Check console for errors
```
Open Browser Console (F12)
Look for:
- Red error messages
- Yellow warning messages
- Any 404 Not Found errors
```

### Step 4: Check PHP errors
```bash
# Check production log
tail -50 /home/pim/public_html/var/logs/prod.log

# Look for errors related to:
# - Routing errors
# - Authentication issues
# - Missing files
# - Permission problems
```

---

## 🔧 STANDARD FIX PROCEDURE

If style issues are found, run this complete rebuild:

```bash
cd /home/pim/public_html

# 1. Recompile LESS to CSS
echo "=== Compiling CSS ==="
yarn run less

# 2. Rebuild JavaScript bundles
echo "=== Building JavaScript ==="
yarn run webpack --env=prod

# 3. Reinstall assets
echo "=== Installing Assets ==="
bin/console pim:installer:assets --symlink --clean --env=prod

# 4. Clear and warm cache
echo "=== Clearing Cache ==="
rm -rf var/cache/prod/*
bin/console cache:warmup --env=prod

# 5. Fix permissions
echo "=== Fixing Permissions ==="
chmod 644 public/css/pim.css public/dist/*.min.js
chown pim:pim public/css/pim.css public/dist/*.min.js

echo "=== Complete! ==="
echo "Now refresh browser with Ctrl+Shift+R (hard refresh)"
```

---

## 📝 DOCUMENTING ISSUES

When you find style issues, document them like this:

```
Issue: Menu items not aligned
Location: Main navigation menu at top
Screenshot: /tmp/menu-alignment-issue.png
Console Error: None OR "Cannot read property 'render' of undefined"
Expected Behavior: Menu items should be horizontal and evenly spaced
Actual Behavior: Menu items are stacked vertically

Possible Cause: CSS not loaded or wrong CSS class
Fix Applied: Recompiled LESS and cleared cache
Status: ✅ Fixed / ❌ Not Fixed / ⏳ In Progress
```

---

## 🎯 SPECIFIC AREAS TO CHECK

### 1. Main Menu (Top Navigation)
- Dashboard link
- Products menu
- Settings menu
- System menu
- User dropdown

### 2. Left Sidebar (if present)
- Category tree
- Filter panels
- Quick links

### 3. Content Area
- Data grids
- Form elements
- Buttons
- Icons

### 4. Footer
- System information
- Version number
- Links

---

## ⚡ QUICK DIAGNOSTICS

Run this one-liner to check everything:

```bash
cd /home/pim/public_html && \
echo "CSS: $(ls -lh public/css/pim.css 2>&1)" && \
echo "JS Main: $(ls -lh public/dist/main.min.js 2>&1)" && \
echo "JS Vendor: $(ls -lh public/dist/vendor.min.js 2>&1)" && \
echo "Recent Errors: $(grep -c ERROR var/logs/prod.log 2>/dev/null || echo 0)" && \
echo "Cache Status: $(ls var/cache/prod/ 2>/dev/null | wc -l) files"
```

---

## 📸 SCREENSHOTS NEEDED

Please take screenshots of:
1. Full dashboard view after login
2. Main menu area (zoomed in if needed)
3. Any visible style problems
4. Browser console (F12 → Console tab)
5. Network tab showing failed requests (if any)

Save screenshots with descriptive names:
- `dashboard-view.png`
- `menu-style-issue.png`
- `console-errors.png`
- `network-404s.png`

---

## ✅ VERIFICATION CHECKLIST

After fixes, verify:
- [ ] Login page loads with proper styles
- [ ] Dashboard loads after login
- [ ] Main menu is visible and clickable
- [ ] Menu items have proper alignment
- [ ] No console errors (red text)
- [ ] No 404 errors in Network tab
- [ ] All icons display properly
- [ ] Navigation works correctly

---

## 💡 NOTES

- **Current branch**: main (confirmed working)
- **UI Status**: Functional, cosmetic issues only
- **Database**: ✅ Complete (166 categories, 112 attributes, 9,538 products)
- **Priority**: Low (not blocking data sync)
- **Estimated fix time**: 30 minutes - 1 hour

---

**Next Steps:**
1. Investigate and document style issues
2. Apply fixes using standard procedure above
3. Verify fixes work correctly
4. Continue with Magento sync preparation

---

Generated: April 26, 2026  
Location: `/home/pim/public_html/webapp/UI_STYLE_INVESTIGATION_GUIDE.md`
