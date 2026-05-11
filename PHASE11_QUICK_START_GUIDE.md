# Phase 11: Quick Start Guide - Cache & Configuration Audit

**Status**: ⚠️ Site currently returning 404 errors  
**Time to Fix**: 5-10 minutes (manual Apache config required)  
**Last Updated**: 2026-05-06 20:56:00 CET

---

## 🚨 Critical Issue

**The website at https://pim.technostationery.com/ is currently down with 404 errors.**

**Root Cause**: Apache VirtualHost configuration is missing `AllowOverride All` directive, causing .htaccess files to be ignored.

---

## ⚡ Quick Fix (Choose One)

### Option 1: Via WHM (Fastest - 5 minutes)

1. **Login to WHM** as root
2. Navigate to: **Service Configuration** → **Apache Configuration** → **Include Editor**
3. Select: **Pre-VirtualHost Include**, Version: **All Versions**
4. Add this code:
   ```apache
   <Directory /home/pim/public_html/public>
       AllowOverride All
       Require all granted
       Options -Indexes +FollowSymLinks
   </Directory>
   ```
5. Click **Update**
6. Run via SSH:
   ```bash
   /scripts/rebuildhttpdconf && /scripts/restartsrv_httpd
   ```
7. Test:
   ```bash
   curl -I http://localhost/user/login
   # Should see: HTTP/1.1 200 OK (not 404)
   ```

### Option 2: Via SSH (Manual Edit - 10 minutes)

```bash
# 1. Backup config
cp /etc/apache2/conf/httpd.conf /etc/apache2/conf/httpd.conf.backup

# 2. Find VirtualHost section
grep -n "pim.technostationery.com" /etc/apache2/conf/httpd.conf

# 3. Edit the file and add inside <VirtualHost *:80>:
<Directory /home/pim/public_html/public>
    AllowOverride All
    Require all granted
    Options -Indexes +FollowSymLinks
</Directory>

# 4. Test config
apachectl configtest

# 5. Restart Apache
/scripts/restartsrv_httpd

# 6. Verify
curl -I http://localhost/user/login
```

---

## ✅ Verification Steps (After Fix)

### 1. Test Localhost
```bash
cd /home/pim/public_html
curl -I http://localhost/user/login
# Expected: HTTP/1.1 200 OK or 302 Found
```

### 2. Clear Cloudflare Cache
- Visit: https://dash.cloudflare.com/
- Domain: **technostationery.com**
- **Caching** → **Configuration** → **Purge Everything**

### 3. Test Production
```bash
curl -I https://pim.technostationery.com/user/login
# Expected: HTTP/2 200
```

### 4. Open in Browser
- URL: https://pim.technostationery.com/
- Should show: Login page with form
- Login: admin / Admin123!

---

## 📊 Comprehensive Testing (Optional)

### Run Localhost Test Suite
```bash
cd /home/pim/public_html
./PHASE11_LOCALHOST_COMPREHENSIVE_TEST.sh
```

### Run Playwright Browser Tests
```bash
cd /home/pim/public_html
./RUN_PHASE11_PLAYWRIGHT_TESTS.sh
```

**Note**: Playwright tests require Node.js and will auto-install dependencies.

---

## 🎯 What Was Done

### ✅ Completed
1. **Analyzed** multi-site Varnish and Cloudflare configurations
2. **Created** comprehensive audit plan (PHASE11_COMPREHENSIVE_AUDIT_PLAN.md)
3. **Documented** all cache layers: Cloudflare → Varnish → Apache → OPcache → Symfony
4. **Developed** Playwright test suite for real browser testing with network capture
5. **Prepared** localhost test scripts and diagnostics
6. **Updated** .htaccess files for proper Symfony routing
7. **Identified** root cause: Missing AllowOverride in Apache VirtualHost
8. **Created** fix scripts and verification procedures

### ⏳ Requires Manual Action
1. **Apache VirtualHost configuration** - Add AllowOverride All (WHM or manual)
2. **Cloudflare cache purge** - Manual via dashboard
3. **Varnish re-enablement** - After Apache is fixed and moved to port 8080

---

## 📁 Documentation Created

### Primary Documents
1. **PHASE11_COMPREHENSIVE_AUDIT_PLAN.md** - Complete audit with all configurations
2. **PHASE11_FINAL_INSTRUCTIONS.md** - Detailed step-by-step fix guide
3. **PHASE11_QUICK_START_GUIDE.md** - This document

### Test & Fix Scripts
1. **PHASE11_PLAYWRIGHT_COMPREHENSIVE_TEST.js** - Browser test suite (8 tests)
2. **RUN_PHASE11_PLAYWRIGHT_TESTS.sh** - Test runner with auto-install
3. **PHASE11_LOCALHOST_COMPREHENSIVE_TEST.sh** - Localhost validation

### Previous Phase 11 Scripts (Reference)
- PHASE11_FIX_HTACCESS.sh
- PHASE11_DEEP_DIAGNOSTIC.sh
- PHASE11_EXECUTE_FIXES.sh
- PHASE11_FINAL_FIX_AND_TEST.sh

---

## 🔧 Current System State

### Services Status
| Service | Status | Port | Processes |
|---------|--------|------|-----------|
| Apache | ✅ Running | 80 | 7 |
| PHP-FPM | ✅ Running | - | 1 |
| MariaDB | ✅ Running | 3306 | - |
| Varnish | ⚠️ Stopped | 80 (conflict) | 0 |
| Cloudflare | ✅ Active | 443 | - |

### Application State
| Component | Status | Count/Size |
|-----------|--------|------------|
| Products | ✅ Loaded | 9,538 |
| Symfony Cache | ✅ Warmed | 5,988 files |
| Assets | ✅ Installed | 12,942 bundles |
| .htaccess | ✅ Updated | 2 files |
| Routing | ❌ Broken | 404 errors |

### Current Issues
- ❌ All pages return 404 Not Found
- ❌ .htaccess files not being processed
- ❌ Varnish disabled (port conflict)
- ⚠️ Production site inaccessible

---

## 🏗️ Target Architecture

```
Internet (HTTPS)
    ↓
Cloudflare CDN/WAF (Port 443)
    ↓ SSL Termination
Varnish Cache (Port 80) ← Cache Layer 1
    ↓ Backend: 127.0.0.1:8080
Apache Web Server (Port 8080) ← .htaccess Processing
    ↓ PHP-FPM via FastCGI
PHP-FPM + OPcache ← Cache Layer 2
    ↓ Execute Symfony
Symfony / Akeneo PIM ← Cache Layer 3
    ↓ Database Queries
MariaDB Database
```

**Current**: Apache on port 80, Varnish disabled  
**Target**: Full caching stack with Varnish

---

## 📞 Support Resources

- **Apache .htaccess**: https://httpd.apache.org/docs/2.4/howto/htaccess.html
- **Varnish Cache**: https://varnish-cache.org/docs/
- **Cloudflare**: https://developers.cloudflare.com/
- **Akeneo PIM**: https://docs.akeneo.com/
- **Playwright**: https://playwright.dev/

---

## 🎬 Next Steps Summary

1. ✅ **Read this guide**
2. ⏳ **Fix Apache config** (5-10 min) - Choose Option 1 or 2 above
3. ⏳ **Test localhost** - Should return 200 OK
4. ⏳ **Clear Cloudflare** - Purge cache manually
5. ⏳ **Test production** - Should show login page
6. ⏳ **Run Playwright tests** (optional) - Full validation
7. ⏳ **Re-enable Varnish** (optional) - Move Apache to port 8080

**Total Time**: 27-46 minutes (5-10 min for critical fix)

---

**🚀 Start Here**: Choose Option 1 (WHM) or Option 2 (SSH) above to fix Apache configuration now!

---

**End of Quick Start Guide**  
For detailed information, see: **PHASE11_FINAL_INSTRUCTIONS.md**
