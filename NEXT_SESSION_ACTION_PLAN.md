# AKENEO PIM - CRITICAL ISSUES & ACTION PLAN FOR NEXT SESSION

**Session Date**: 2026-05-03
**Status**: CRITICAL ISSUES IDENTIFIED - Login Failing

---

## 🔴 CRITICAL ISSUES DISCOVERED

### 1. **CSS Styling Incomplete** ⚠️
- **Problem**: `public/css/pim.css` only has 43 CSS rules (4.3KB)
- **Expected**: Should have thousands of rules (hundreds of KB)
- **Impact**: Login page has minimal styling, missing Akeneo design
- **Root Cause**: LESS compilation generated placeholder CSS instead of full stylesheet

### 2. **Login Failing** ⚠️
- **Problem**: Login always returns to login page (stays at `/user/login`)
- **Credentials Tested**: admin/admin, finaladmin/Admin@2024!
- **Impact**: Cannot access PIM dashboard
- **Error**: Form submits but authentication fails

### 3. **ACL Security System Broken** 🔴 CRITICAL
- **Error**: `Call to a member function putInCache() on null`
- **Location**: `Oro/Bundle/SecurityBundle/Acl/Dbal/MutableAclProvider.php:67`
- **Impact**: Security/ACL system not working, causing login failures
- **Frequency**: Repeated in logs dozens of times

### 4. **File Permissions Issues** ⚠️
- **Issue**: Many files owned by `root` instead of `pim` user
- **Impact**: Potential write permission problems
- **Affected**: public/bundles/pimui/*, public/css/*, public/js/*

---

## 📋 COMPREHENSIVE ACTION PLAN FOR NEXT SESSION

### PHASE 1: Fix File Permissions (PRIORITY 1)
```bash
cd /home/pim/public_html

# Fix ownership
sudo chown -R pim:pim public/
sudo chown -R pim:pim var/
sudo chown -R pim:pim vendor/
sudo chown -R pim:pim webapp/

# Fix permissions
find public/ -type f -exec chmod 644 {} \;
find public/ -type d -exec chmod 755 {} \;
find var/ -type f -exec chmod 664 {} \;
find var/ -type d -exec chmod 775 {} \;
find var/cache/ -type d -exec chmod 777 {} \;
find var/logs/ -type d -exec chmod 777 {} \;

# Verify
ls -la public/bundles/pimui/
ls -la public/css/
ls -la var/cache/
```

### PHASE 2: Fix ACL Security System (PRIORITY 1) 🔴
```bash
cd /home/pim/public_html

# Clear all caches
rm -rf var/cache/*

# Re-initialize ACL
php bin/console cache:clear --no-warmup --env=prod
php bin/console cache:warmup --env=prod

# Install ACL tables (if missing)
php bin/console pim:installer:db --env=prod

# OR reset ACL
php bin/console oro:security:acl:clear --env=prod
php bin/console oro:security:acl:load --env=prod
```

### PHASE 3: Rebuild Frontend Assets Properly (PRIORITY 1)
```bash
cd /home/pim/public_html

# Delete broken CSS
rm -f public/css/pim.css

# Method 1: Use Akeneo's build system
cd vendor/akeneo/pim-community-dev/frontend/build
npm install
npm run less
npm run webpack

# Copy generated files
cp -r public/* /home/pim/public_html/public/

# Method 2: Use symfony assets install
cd /home/pim/public_html
php bin/console assets:install public --symlink --relative --env=prod

# Method 3: Full rebuild
rm -rf public/css/* public/js/* public/bundles/*
php bin/console pim:installer:assets --env=prod
```

### PHASE 4: Check Database Configuration
```bash
cd /home/pim/public_html

# Verify .env file
cat .env | grep DATABASE

# Test database connection
php bin/console doctrine:database:connect --env=prod

# Check if users exist
php bin/console doctrine:query:sql "SELECT username, email FROM oro_user" --env=prod

# Verify ACL tables exist
php bin/console doctrine:query:sql "SHOW TABLES LIKE '%acl%'" --env=prod
```

### PHASE 5: Verify/Reset Admin Credentials
```bash
cd /home/pim/public_html

# Check existing admin user
php bin/console pim:user:list

# Reset admin password
php bin/console pim:user:create admin admin@example.com admin Admin Admin --env=prod

# OR update existing
php bin/console fos:user:change-password admin admin --env=prod
```

### PHASE 6: Check Logs and Debug
```bash
cd /home/pim/public_html

# Clear old logs
> var/logs/prod.log
> var/logs/dev.log

# Watch logs in real-time during login test
tail -f var/logs/prod.log

# Check for specific errors
grep -i "error\|critical\|exception" var/logs/prod.log | tail -50

# Check PHP error log
tail -50 /var/log/php-error.log
```

### PHASE 7: Test Login with Debug Mode
```bash
cd /home/pim/public_html

# Enable debug mode temporarily
export APP_ENV=dev
export APP_DEBUG=1

# Start server with verbose output
php -S 0.0.0.0:8000 -t public/

# Monitor in separate terminal
tail -f var/logs/dev.log

# Test login via browser
# Check detailed error messages
```

### PHASE 8: Alternative CSS Solution
If LESS compilation keeps failing, copy CSS from a working Akeneo installation:

```bash
cd /home/pim/public_html

# Find all LESS source files
find vendor/akeneo/pim-community-dev/ -name "*.less" | wc -l

# Check if pre-compiled CSS exists anywhere
find vendor/ -name "pim.css" -o -name "main.css" 2>/dev/null

# Use Webpack if available
cd vendor/akeneo/pim-community-dev
npm run webpack:build

# Copy compiled assets
cp -r public/css/* /home/pim/public_html/public/css/
```

---

## 🧪 COMPREHENSIVE TESTING CHECKLIST

After fixes, test in this order:

### Test 1: File Permissions
```bash
ls -la public/bundles/pimui/manifest.json  # Should be pim:pim 644
ls -la public/css/pim.css  # Should be pim:pim 644
ls -la var/cache/  # Should be pim:pim 775
```

### Test 2: CSS Loading
```bash
curl -I http://localhost:8000/css/pim.css
# Should return: 200 OK
# Content-Length: should be > 100000 (not 4.3KB)

# Check CSS rules count
grep -o "{" public/css/pim.css | wc -l
# Should be > 1000 rules
```

### Test 3: Database/ACL
```bash
php bin/console doctrine:schema:validate --env=prod
# Should show: database schema is in sync

php bin/console pim:user:list
# Should show admin user

php bin/console cache:clear --env=prod
# Should complete without errors
```

### Test 4: Login Flow (Browser)
```javascript
// Use Playwright to test
- Navigate to http://localhost:8000/
- Fill username: admin
- Fill password: admin
- Click submit
- EXPECT: Redirect to /dashboard or /index.php#/
- VERIFY: .AknHeader element present
- VERIFY: URL changed from /login
```

### Test 5: Server Logs
```bash
# During login attempt, check logs:
tail -f var/logs/prod.log | grep -i "authentication\|login\|security"

# Should see:
# - "Successful authentication" OR
# - "User loaded from database"
# NOT: "putInCache() on null"
```

---

## 📊 EXPECTED RESULTS AFTER FIXES

### CSS File
- **Size**: ~500KB - 2MB (not 4.3KB)
- **Rules**: 5,000+ CSS rules (not 43)
- **Content**: Full Akeneo design system

### Login Behavior
- **Submit**: Form POST to /user/login-check
- **Response**: 302 redirect to /dashboard or /index.php#/
- **Final URL**: NOT /user/login (should change)
- **Page Elements**: .AknHeader, navigation menu visible

### Logs
- **No Errors**: ACL putInCache errors should disappear
- **Auth Success**: "Security:info: User authenticated successfully"
- **No 401**: Login page should not return 401 status

---

## 🔍 DIAGNOSTIC COMMANDS

Run these to gather information:

```bash
# System info
php -v
node -v
npm -v
composer --version

# Akeneo version
cat composer.json | grep "akeneo/pim"

# Database status
php bin/console doctrine:database:connect --env=prod

# Cache status
du -sh var/cache/*

# Asset status
ls -lh public/css/pim.css
ls -lh public/js/extensions.json
ls -lh public/bundles/pimui/manifest.json

# Permissions check
find public/ -not -user pim | head -20
find var/ -not -user pim | head -20

# Service status
ps aux | grep php
netstat -tlnp | grep 8000

# Recent errors
grep "CRITICAL\|ERROR" var/logs/prod.log | tail -20
```

---

## 📝 KNOWN WORKING SOLUTIONS FROM RESEARCH

### Solution 1: ACL Cache Fix
From Akeneo GitHub issues:
```bash
php bin/console doctrine:schema:update --force --env=prod
php bin/console oro:security:acl:load --env=prod
```

### Solution 2: Frontend Assets
From Akeneo documentation:
```bash
# In vendor/akeneo/pim-community-dev/
make assets
make css

# Or
yarn install
yarn run webpack
```

### Solution 3: User Reset
```bash
php bin/console pim:user:create \
  admin \
  admin@example.com \
  Admin \
  Admin \
  Admin \
  --admin \
  --env=prod
```

---

## 🎯 SUCCESS CRITERIA

Session is successful when:
1. ✅ CSS file is 500KB+ with thousands of rules
2. ✅ Login with admin/admin succeeds
3. ✅ Redirect to dashboard occurs
4. ✅ Akeneo header and navigation visible
5. ✅ No ACL errors in logs
6. ✅ All files have correct permissions
7. ✅ PIM menu accessible and functional
8. ✅ Screenshot shows full Akeneo UI styling

---

## 💾 FILES TO BACKUP BEFORE CHANGES

```bash
# Backup current state
cp public/css/pim.css public/css/pim.css.backup.$(date +%Y%m%d)
cp .env .env.backup.$(date +%Y%m%d)
tar -czf var_backup_$(date +%Y%m%d).tar.gz var/

# Database dump
php bin/console doctrine:database:dump backup_$(date +%Y%m%d).sql --env=prod
```

---

## 📞 REFERENCE LINKS

- Akeneo Installation Docs: https://docs.akeneo.com/latest/install_pim/index.html
- Akeneo Asset Build: https://docs.akeneo.com/latest/technical_architecture/frontend/index.html
- Symfony Security: https://symfony.com/doc/current/security.html
- ACL Documentation: https://doc.oroinc.com/backend/security/acl-manager/

---

**NEXT SESSION PRIORITY**: 
1. Fix ACL security system (CRITICAL)
2. Fix file permissions
3. Rebuild frontend assets properly
4. Test login flow completely
5. Verify PIM dashboard and menu access

**ESTIMATED TIME**: 2-3 hours for complete resolution

