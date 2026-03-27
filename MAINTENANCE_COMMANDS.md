# Akeneo PIM - Complete Maintenance & Deployment Guide

## ✅ FINAL WORKING SOLUTION

### Root Cause of JavaScript Errors
The `vendor.min.js` file expects these libraries to be loaded **BEFORE** it runs:
1. **jQuery** - for DOM manipulation
2. **underscore.js** - for utility functions (`_` object)
3. **Backbone.js** - for MVC framework
4. **FOS Routing** - for `Routing.generate()` function (MUST use callback method, NOT direct JSON)

**Critical:** The FOS routes JSON file CANNOT be loaded directly as a script - it must use the callback method: `/js/routing?callback=fos.Router.setData`

### Root Cause of 500 Errors
**CRITICAL:** Permissions must be set AFTER cache:clear, not before!
- When you run `cache:clear`, it creates files as YOUR user
- Apache runs as `nobody` on cPanel
- If permissions aren't fixed AFTER cache clear, Apache can't write to cache

---

## Quick Fix Script (RECOMMENDED)

Save as `/home/pim/public_html/fix_akeneo.sh`:

```bash
#!/bin/bash
cd /home/pim/public_html

echo "=== Akeneo PIM Maintenance ==="

# Clear cache FIRST
rm -rf var/cache/prod/*
rm -rf var/sessions/*

# Rebuild cache
php bin/console cache:clear --env=prod

# NOW fix permissions (MUST be after cache:clear!)
chown -R nobody:nobody var/
chmod -R 777 var/
chmod -R 777 public/css/ public/js/ public/media/ public/bundles/ public/dist/

# Reinstall assets
php bin/console pim:installer:assets --symlink --clean --env=prod
chown -R nobody:nobody public/bundles/
chmod -R 777 public/bundles/

echo "=== Done! ==="
echo "Clear browser cache (Ctrl+Shift+Delete) or use Incognito mode"
```

**Make executable and run:**
```bash
chmod +x /home/pim/public_html/fix_akeneo.sh
/home/pim/public_html/fix_akeneo.sh
```

---

## 1. Fix Permissions (CRITICAL ORDER!)

**MUST run AFTER cache:clear, not before:**

```bash
cd /home/pim/public_html

# Fix ownership for Apache (nobody on cPanel)
chown -R nobody:nobody var/
chown -R nobody:nobody public/css/
chown -R nobody:nobody public/js/
chown -R nobody:nobody public/media/
chown -R nobody:nobody public/bundles/
chown -R nobody:nobody public/dist/

# Set writable permissions
chmod -R 777 var/
chmod -R 777 public/css/
chmod -R 777 public/js/
chmod -R 777 public/media/
chmod -R 777 public/bundles/
chmod -R 777 public/dist/
```

---

## 2. Clear Cache (Proper Sequence)

```bash
cd /home/pim/public_html

# Step 1: Clear cache
rm -rf var/cache/prod/*
rm -rf var/sessions/*

# Step 2: Rebuild cache
php bin/console cache:clear --env=prod

# Step 3: NOW fix permissions (CRITICAL!)
chown -R nobody:nobody var/
chmod -R 777 var/
```

---

## 3. Deploy Static Assets

```bash
cd /home/pim/public_html

# Install dependencies (if package.json changed)
yarn install

# Build production webpack assets
yarn webpack

# Generate FOS JS routes
php bin/console fos:js-routing:dump --format=json --target=public/js/fos_js_routes.json --env=prod

# Install Akeneo assets (symlinks bundles)
php bin/console pim:installer:assets --symlink --clean --env=prod

# Fix permissions
chown -R nobody:nobody public/css/ public/js/ public/dist/ public/bundles/
chmod -R 777 public/css/ public/js/ public/dist/ public/bundles/
```

---

## 4. Database Maintenance

```bash
# Clear old sessions (older than 1 day)
/opt/mariadb10.6/mariadb/bin/mysql -u root -p'YourNewStrongPassword' -h 127.0.0.1 -P 3307 \
  -e "USE akeneo_pim; DELETE FROM pim_session WHERE sess_time < UNIX_TIMESTAMP(NOW() - INTERVAL 1 DAY);"

# Optimize session table
/opt/mariadb10.6/mariadb/bin/mysql -u root -p'YourNewStrongPassword' -h 127.0.0.1 -P 3307 \
  -e "USE akeneo_pim; OPTIMIZE TABLE pim_session;"
```

---

## 5. Elasticsearch Maintenance

```bash
# Check cluster health
curl -X GET "http://localhost:9200/_cluster/health?pretty"

# Check indices
curl -X GET "http://localhost:9200/_cat/indices?v"

# Clear cache
curl -X POST "http://localhost:9200/_cache/clear"

# Reindex products (from Akeneo root)
cd /home/pim/public_html
php bin/console pim:product:index
php bin/console pim:product-model:index
```

---

## 6. Check Logs

```bash
# Application logs (last 100 lines)
tail -100 /home/pim/public_html/var/logs/prod.log

# Watch logs in real-time
tail -f /home/pim/public_html/var/logs/prod.log

# Apache error logs
tail -100 /var/log/apache2/error_log

# PHP error log
tail -100 /home/pim/public_html/error_log
```

---

## 7. Verify Installation

```bash
# Check PHP version
php -v

# Check Symfony console
php bin/console --version

# Check database connection
/opt/mariadb10.6/mariadb/bin/mysql -u root -p'YourNewStrongPassword' -h 127.0.0.1 -P 3307 \
  -e "USE akeneo_pim; SELECT COUNT(*) as users FROM oro_user;"

# Check Elasticsearch
curl -X GET "http://localhost:9200/_cat/indices?v"

# Test login page
curl -s -k https://pim.technostationery.com/user/login | grep -o "csrf_token"
```

---

## 8. Emergency Reset (If Everything Breaks)

```bash
cd /home/pim/public_html

# Stop any running processes
pkill -f "php.*bin/console"

# Complete cache reset
rm -rf var/cache/prod/*
rm -rf var/sessions/*
rm -rf var/logs/*

# Rebuild cache FIRST
php bin/console cache:clear --env=prod
php bin/console cache:warmup --env=prod

# NOW fix permissions (CRITICAL ORDER!)
chown -R nobody:nobody var/ public/
chmod -R 777 var/
chmod -R 755 public/
chmod -R 777 public/css/ public/js/ public/media/ public/bundles/ public/dist/

# Reinstall assets
php bin/console pim:installer:assets --symlink --clean --env=prod

# Regenerate FOS routes
php bin/console fos:js-routing:dump --format=json --target=public/js/fos_js_routes.json --env=prod

echo "Emergency reset complete!"
```

---

## Access Information

- **URL:** https://pim.technostationery.com
- **Username:** admin
- **Password:** Admin123!

---

## Troubleshooting

### 500 Internal Server Error - Permission Denied
**This is the most common issue!**

Check logs for: `"The directory .../var/cache/prod/oro_acl" is not writable`

**Solution:**
```bash
# Run cache clear FIRST
php bin/console cache:clear --env=prod

# THEN fix permissions (order matters!)
chown -R nobody:nobody var/
chmod -R 777 var/
```

### Permission Denied Errors
```bash
chown -R nobody:nobody var/
chmod -R 777 var/
```

### Session Issues
```bash
rm -rf var/sessions/*
chown -R nobody:nobody var/sessions/
chmod -R 777 var/sessions/
```

### JavaScript Errors (jQuery, _, Routing not defined)
Ensure these files are loaded in order in `index.html.twig`:
1. jQuery CDN
2. underscore.js CDN
3. backbone.js CDN
4. FOS router.min.js
5. FOS routing with callback: `/js/routing?callback=fos.Router.setData`
6. vendor.min.js
7. main.min.js

### FOS Routing SyntaxError: Unexpected token ':'
**WRONG:** `<script src="/js/fos_js_routes.json"></script>`
**CORRECT:** `<script src="/js/routing?callback=fos.Router.setData"></script>`

The JSON file cannot be loaded directly as a script - it must use the callback method!

### Browser Cache Issues
Even in Incognito mode, you might see cached content if:
1. Cloudflare is enabled (purge Cloudflare cache)
2. Service workers are active (clear all site data)

**Solution:**
- Press Ctrl+Shift+Delete
- Select "All time"
- Check "Cached images and files"
- Click "Clear data"
- Close ALL browser windows
- Reopen browser in Incognito mode

### Assets Not Loading
```bash
php bin/console pim:installer:assets --symlink --clean --env=prod
chmod -R 777 public/bundles/ public/css/ public/js/
chown -R nobody:nobody public/bundles/ public/css/ public/js/
```

### FOS Routing Errors
```bash
# Regenerate routes
php bin/console fos:js-routing:dump --format=json --target=public/js/fos_js_routes.json --env=prod

# Reinstall assets
php bin/console assets:install public --symlink --relative --env=prod
```
