# Akeneo PIM Build Commands Reference

## Current Working Directory
Always run from: `/home/pim/public_html`

## 1. CSS/LESS Compilation
```bash
cd /home/pim/public_html && yarn run less
```
**What it does:** Compiles all LESS files to CSS and outputs to `public/css/pim.css`
**Expected output:** `public/css/pim.css` (~500KB-2MB)

## 2. JavaScript Production Build
```bash
cd /home/pim/public_html && NODE_OPTIONS="--openssl-legacy-provider --max_old_space_size=4096" yarn run webpack --env=prod
```
**What it does:** Creates production bundles
**Expected output:** 
- `public/dist/main.min.js` (~1.6MB)
- `public/dist/vendor.min.js` (~3.3MB)

## 3. JavaScript Development Build (Watch Mode)
```bash
cd /home/pim/public_html && NODE_OPTIONS="--openssl-legacy-provider --max_old_space_size=4096" yarn run webpack-dev
```
**What it does:** Watches for changes and rebuilds automatically
**Use when:** Actively developing/debugging frontend

## 4. Install Assets
```bash
cd /home/pim/public_html && bin/console pim:installer:assets --symlink --clean --env=prod
```
**What it does:** Copies bundle assets to public directory
**Expected output:** RequireJS configs, locale files, bundle assets

## 5. Clear Cache (Production)
```bash
cd /home/pim/public_html && rm -rf var/cache/prod/* && bin/console cache:warmup --env=prod && chmod -R 775 var/cache var/logs && chown -R pim:pim var/cache var/logs
```
**When to run:** After any configuration or template changes

## 6. Full Frontend Rebuild (Complete)
```bash
cd /home/pim/public_html && \
  echo "Step 1: Installing assets..." && \
  bin/console pim:installer:assets --symlink --clean --env=prod && \
  echo "Step 2: Compiling CSS..." && \
  yarn run less && \
  echo "Step 3: Building JavaScript (production)..." && \
  NODE_OPTIONS="--openssl-legacy-provider --max_old_space_size=4096" yarn run webpack --env=prod && \
  echo "Step 4: Clearing cache..." && \
  rm -rf var/cache/prod/* && \
  bin/console cache:warmup --env=prod && \
  echo "Step 5: Setting permissions..." && \
  chmod -R 644 public/dist/*.js public/dist/*.map public/css/*.css 2>/dev/null && \
  chmod -R 775 var/cache var/logs && \
  chown -R pim:pim public/dist public/css var/cache var/logs && \
  echo "Build complete!"
```

## 7. Verify Build Output
```bash
cd /home/pim/public_html && \
  echo "=== CSS FILES ===" && \
  ls -lh public/css/ && \
  echo "" && \
  echo "=== JS BUNDLES ===" && \
  ls -lh public/dist/*.js && \
  echo "" && \
  echo "=== PERMISSIONS CHECK ===" && \
  stat -c "%a %U:%G %n" public/css/pim.css public/dist/main.min.js public/dist/vendor.min.js 2>/dev/null || echo "Some files missing"
```

## 8. Check Logs for Errors
```bash
cd /home/pim/public_html && tail -100 var/logs/prod.log | grep -i "error\|exception\|404" | tail -20
```

## Common Issues & Fixes

### Missing CSS (pim.css not found)
**Symptom:** Login page has no styles
**Fix:** Run `yarn run less` to compile LESS files

### JavaScript errors "jQuery is not defined"
**Symptom:** Console shows jQuery errors
**Fix:** Run full frontend rebuild (command #6)

### 404 errors for vendor libraries
**Symptom:** Missing jquery.min.js, backbone.min.js, etc.
**Fix:** Run the vendor copy script:
```bash
cd /home/pim/public_html/webapp && ./copy_vendor_libs.sh
```

### Permissions errors
**Symptom:** Cannot write to cache/logs
**Fix:** Run:
```bash
cd /home/pim/public_html && chmod -R 775 var/cache var/logs && chown -R pim:pim var/cache var/logs
```

## File Permissions Reference
- **CSS files:** 644 (rw-r--r--) owned by pim:pim
- **JS bundles:** 644 (rw-r--r--) owned by pim:pim
- **Cache directory:** 775 (rwxrwxr-x) owned by pim:pim
- **Logs directory:** 775 (rwxrwxr-x) owned by pim:pim

## Expected File Sizes
- `public/css/pim.css`: ~500KB - 2MB
- `public/dist/main.min.js`: ~1.6MB
- `public/dist/vendor.min.js`: ~3.3MB
- `public/dist/jquery.min.js`: ~87KB
- `public/dist/backbone.min.js`: ~18KB
- `public/dist/react.min.js`: ~13KB

## Quick Health Check
```bash
cd /home/pim/public_html && \
  echo "CSS: $(test -f public/css/pim.css && echo '✅' || echo '❌')" && \
  echo "Main JS: $(test -f public/dist/main.min.js && echo '✅' || echo '❌')" && \
  echo "Vendor JS: $(test -f public/dist/vendor.min.js && echo '✅' || echo '❌')" && \
  echo "jQuery: $(test -f public/dist/jquery.min.js && echo '✅' || echo '❌')"
```
