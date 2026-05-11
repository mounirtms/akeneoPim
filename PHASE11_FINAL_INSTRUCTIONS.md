# Phase 11: Final Instructions & Manual Fix Guide

**Date**: 2026-05-06  
**Status**: AWAITING MANUAL APACHE CONFIGURATION FIX  
**Critical Blocker**: AllowOverride setting must be fixed before site can function

---

## Current Situation Summary

### What's Working ✅
- **Apache**: Running on port 80 (7 processes)
- **PHP-FPM**: Active (1 process)
- **MariaDB**: Running, 9,538 products loaded
- **Symfony Cache**: Warmed (5,988 files)
- **Cloudflare**: Passing traffic (no longer blocking with 403)
- **File Structure**: All files in correct locations

### What's Broken ❌
- **Routing**: All requests return 404 (index.php not invoked)
- **.htaccess Processing**: Apache ignoring .htaccess files
- **Varnish**: Disabled (port 80 conflict)
- **Production Site**: https://pim.technostationery.com/ shows 404

### Root Cause 🎯
**Apache VirtualHost configuration does NOT have `AllowOverride All`** in the Directory block for `/home/pim/public_html/public`, causing:
1. `.htaccess` files to be completely ignored by Apache
2. No URL rewriting (mod_rewrite rules not executed)
3. All dynamic routes returning 404 Not Found
4. Apache serving raw directory structure instead of routing through index.php

---

## Required Fix: Apache VirtualHost Configuration

### Option A: Using WHM/cPanel (Recommended)

#### Step 1: Access WHM
1. Login to WHM as root
2. Navigate to: **Service Configuration** → **Apache Configuration** → **Include Editor**

#### Step 2: Add Pre-VirtualHost Include
1. Select: **Pre-VirtualHost Include**
2. Select version: **All Versions**
3. Add the following configuration:

```apache
# Phase 11 Fix: Enable .htaccess for Akeneo PIM
<Directory /home/pim/public_html/public>
    AllowOverride All
    Require all granted
    Options -Indexes +FollowSymLinks
</Directory>
```

4. Click **Update**

#### Step 3: Rebuild Apache Configuration
Run these commands via SSH:
```bash
/scripts/rebuildhttpdconf
/scripts/restartsrv_httpd
```

#### Step 4: Verify Fix
```bash
# Test should return HTTP 200 or 302 (not 404)
curl -I http://localhost/user/login

# Should see "200 OK" or "302 Found"
# Currently returns: 404 Not Found
```

---

### Option B: Manual Apache Configuration (If WHM Access Not Available)

#### Step 1: Locate Apache Configuration
Find the main Apache configuration file:
```bash
# Common locations
ls -l /etc/apache2/conf/httpd.conf
ls -l /usr/local/apache/conf/httpd.conf
ls -l /etc/httpd/conf/httpd.conf
```

#### Step 2: Backup Current Configuration
```bash
cp /etc/apache2/conf/httpd.conf /etc/apache2/conf/httpd.conf.phase11.backup.$(date +%Y%m%d_%H%M%S)
```

#### Step 3: Find VirtualHost for pim.technostationery.com
```bash
grep -n "pim.technostationery.com" /etc/apache2/conf/httpd.conf
```

#### Step 4: Edit VirtualHost Configuration
Add or modify the Directory block inside the VirtualHost:

```apache
<VirtualHost *:80>
    ServerName pim.technostationery.com
    ServerAlias www.pim.technostationery.com
    DocumentRoot /home/pim/public_html/public
    
    # ADD OR MODIFY THIS BLOCK:
    <Directory /home/pim/public_html/public>
        AllowOverride All          # ← CRITICAL FIX
        Require all granted
        Options -Indexes +FollowSymLinks
        DirectoryIndex index.php
    </Directory>
    
    # Enable mod_rewrite
    <IfModule mod_rewrite.c>
        RewriteEngine On
    </IfModule>
    
    # Other configuration...
</VirtualHost>
```

#### Step 5: Test Configuration Syntax
```bash
apachectl configtest
# Should return: Syntax OK
```

#### Step 6: Restart Apache
```bash
# Choose appropriate method:
systemctl restart httpd
# OR
/scripts/restartsrv_httpd
# OR
apachectl graceful
```

#### Step 7: Verify Fix
```bash
curl -I http://localhost/user/login
# Expected: HTTP/1.1 200 OK or 302 Found
# Current: HTTP/1.1 404 Not Found
```

---

## Post-Fix Verification Steps

### 1. Test Localhost Routing
```bash
cd /home/pim/public_html
./PHASE11_LOCALHOST_COMPREHENSIVE_TEST.sh
```

**Expected Results**:
- ✅ Apache `/` returns 200 or 302
- ✅ Apache `/user/login` returns 200
- ✅ Apache static assets return 200
- ✅ .htaccess is being processed

### 2. Re-enable Varnish (After Apache Fix)

Once Apache is working on port 80, switch to proper architecture:

```bash
# Step 1: Update Apache to listen on port 8080
# Add to httpd.conf:
Listen 8080

# Change VirtualHost to:
<VirtualHost *:8080>
    # ... rest of config
</VirtualHost>

# Step 2: Rebuild and restart
/scripts/rebuildhttpdconf
/scripts/restartsrv_httpd

# Step 3: Test Apache on 8080
curl -I http://localhost:8080/user/login

# Step 4: Start Varnish
systemctl start varnish
systemctl enable varnish

# Step 5: Test Varnish on port 80
curl -I http://localhost/user/login
# Should see X-Varnish and Via headers
```

### 3. Clear Cloudflare Cache

**Manual Method** (No API key found):
1. Visit: https://dash.cloudflare.com/
2. Select domain: **technostationery.com**
3. Go to: **Caching** → **Configuration**
4. Click: **Purge Everything**
5. Confirm purge

**Recommended Cloudflare Settings**:
- **Security Level**: Medium (NOT High)
- **WAF**: Review rules, disable aggressive ones
- **Page Rules**: Add rule for `pim.technostationery.com/*`:
  - Cache Level: Bypass (for dynamic content)
  - OR Cache Level: Standard with specific rules for `/bundles/*`

### 4. Run Playwright Browser Tests

```bash
cd /home/pim/public_html
./RUN_PHASE11_PLAYWRIGHT_TESTS.sh
```

**Expected Results**:
- ✅ Production Homepage: 200 or 302
- ✅ Login Page: 200 with form visible
- ✅ Static Assets: 200 with correct content-type
- ✅ Cache Headers: Present (Cloudflare, optionally Varnish)
- ✅ Performance: <1000ms load time
- ✅ Console Errors: 0 JavaScript errors
- ✅ Network Requests: All successful

### 5. Test Production URL

```bash
# Test production site
curl -I https://pim.technostationery.com/user/login

# Expected: HTTP/2 200 or 302
# Current: HTTP/2 404
```

**Browser Test**:
1. Open: https://pim.technostationery.com/
2. Should redirect to: https://pim.technostationery.com/user/login
3. Login form should be visible
4. No 404 errors
5. Static assets (CSS, JS, images) should load

---

## Expected Outcomes After Fix

### Apache Configuration ✅
```bash
grep -A5 "Directory /home/pim/public_html/public" /etc/apache2/conf/httpd.conf
```
**Should show**:
```apache
<Directory /home/pim/public_html/public>
    AllowOverride All
    Require all granted
    Options -Indexes +FollowSymLinks
</Directory>
```

### Localhost Tests ✅
```bash
curl -I http://localhost/user/login
HTTP/1.1 200 OK  # ← Success!
```

### Production Tests ✅
```bash
curl -I https://pim.technostationery.com/user/login
HTTP/2 200  # ← Success!
cf-cache-status: DYNAMIC
```

### Browser Access ✅
- Homepage: Redirects to login
- Login page: Form visible, no errors
- Static assets: Load correctly
- Performance: Fast (<1 second)

---

## Architecture After Full Fix

```
┌─────────────────────────────────────────────────────────────┐
│                         Internet                            │
└───────────────────────────┬─────────────────────────────────┘
                            │
                    ┌───────▼────────┐
                    │   Cloudflare   │
                    │   (CDN/WAF)    │
                    │   Port 443     │
                    └───────┬────────┘
                            │
                    ┌───────▼────────┐
                    │    Varnish     │
                    │  (Cache L1)    │
                    │   Port 80      │
                    └───────┬────────┘
                            │
                    ┌───────▼────────┐
                    │    Apache      │
                    │  (Web Server)  │
                    │   Port 8080    │
                    │  .htaccess ✅   │
                    └───────┬────────┘
                            │
                    ┌───────▼────────┐
                    │   PHP-FPM      │
                    │   (Runtime)    │
                    │   OPcache ✅    │
                    └───────┬────────┘
                            │
                    ┌───────▼────────┐
                    │   Symfony      │
                    │   (Akeneo)     │
                    │  Cache ✅       │
                    └───────┬────────┘
                            │
                    ┌───────▼────────┐
                    │    MariaDB     │
                    │  (Database)    │
                    │  9,538 Products│
                    └────────────────┘
```

**Current State**: Apache on port 80 (bypassing Varnish)  
**Target State**: Full stack with Varnish caching

---

## Troubleshooting

### If Still Getting 404 After Fix

#### Check 1: Verify AllowOverride is Set
```bash
grep -r "AllowOverride" /etc/apache2/conf/httpd.conf | grep -v "^#"
# Should include: AllowOverride All
```

#### Check 2: Verify mod_rewrite is Loaded
```bash
apachectl -M | grep rewrite
# Should show: rewrite_module (shared)
```

#### Check 3: Test .htaccess Syntax
```bash
# Add invalid syntax to trigger error
echo "INVALID SYNTAX" >> /home/pim/public_html/public/.htaccess
curl -I http://localhost/
# Should return 500 if .htaccess is being read
# Remove the invalid line after test
sed -i '/INVALID SYNTAX/d' /home/pim/public_html/public/.htaccess
```

#### Check 4: Review Apache Error Logs
```bash
tail -50 /usr/local/apache/logs/error_log
# Look for .htaccess related errors
```

#### Check 5: Verify DocumentRoot
```bash
grep "DocumentRoot" /etc/apache2/conf/httpd.conf | grep pim
# Should show: DocumentRoot /home/pim/public_html/public
```

### If Varnish Won't Start

#### Check 1: Port 80 Availability
```bash
netstat -tlnp | grep :80
# Should show only Varnish, not Apache
```

#### Check 2: Varnish Backend Configuration
```bash
cat /etc/varnish/default.vcl | grep -A3 "backend default"
# Should point to: .host = "127.0.0.1"; .port = "8080";
```

#### Check 3: Varnish Logs
```bash
journalctl -u varnish -n 50 --no-pager
# Look for connection errors
```

---

## Files Created in Phase 11

### Documentation
- ✅ `PHASE11_COMPREHENSIVE_AUDIT_PLAN.md` - Complete audit plan
- ✅ `PHASE11_COMPREHENSIVE_FIX_PLAN.md` - Original fix plan
- ✅ `PHASE11_COMPLETE_STATUS_AND_NEXT_STEPS.md` - Status tracking
- ✅ `PHASE11_FINAL_COMPREHENSIVE_REPORT.md` - Detailed analysis
- ✅ `PHASE11_COMPLETE_FINAL_REPORT.md` - System state report
- ✅ `ROOT_CAUSE_ANALYSIS.md` - Root cause documentation
- ✅ `CLOUDFLARE_FIX_INSTRUCTIONS.md` - Cloudflare guide
- ✅ **`PHASE11_FINAL_INSTRUCTIONS.md`** ← This document

### Test Scripts
- ✅ `PHASE11_PLAYWRIGHT_COMPREHENSIVE_TEST.js` - Playwright test suite
- ✅ `RUN_PHASE11_PLAYWRIGHT_TESTS.sh` - Test runner script
- ✅ `PHASE11_LOCALHOST_COMPREHENSIVE_TEST.sh` - Localhost tests

### Fix Scripts
- ✅ `PHASE11_FIX_HTACCESS.sh` - .htaccess updater
- ✅ `PHASE11_FIX_HTACCESS_V2.sh` - .htaccess v2
- ✅ `PHASE11_DEEP_DIAGNOSTIC.sh` - Diagnostics
- ✅ `PHASE11_EXECUTE_FIXES.sh` - Automated fixes
- ✅ `PHASE11_FINAL_FIX_AND_TEST.sh` - Final test

### Backups
- `/home/pim/public_html/.htaccess.phase11.backup.*`
- `/home/pim/public_html/public/.htaccess.phase11.backup.*`
- `/home/pim/public_html/backups/phase11_*/`

---

## Success Criteria Checklist

### Phase 11.1: Apache Fix ✓
- [ ] AllowOverride All is set in VirtualHost config
- [ ] Apache config syntax passes validation
- [ ] Apache restarts successfully
- [ ] `curl http://localhost/user/login` returns 200 (not 404)
- [ ] `.htaccess` test triggers 500 error

### Phase 11.2: Localhost Tests ✓
- [ ] Homepage returns 200 or 302
- [ ] Login page returns 200
- [ ] Static assets return 200
- [ ] No 404 errors on any endpoint

### Phase 11.3: Varnish Re-enablement ✓
- [ ] Apache listening on port 8080
- [ ] Varnish running on port 80
- [ ] Varnish backend health: healthy
- [ ] Cache headers present (X-Varnish, Via)

### Phase 11.4: Cloudflare Configuration ✓
- [ ] Cache purged
- [ ] Security level: Medium
- [ ] No 403 errors
- [ ] CF-Cache-Status header present

### Phase 11.5: Production Tests ✓
- [ ] https://pim.technostationery.com/ accessible
- [ ] Login page shows form
- [ ] Admin login works (admin/Admin123!)
- [ ] Static assets load
- [ ] Performance <1 second

### Phase 11.6: Playwright Tests ✓
- [ ] All 8 tests pass
- [ ] No console errors
- [ ] Network requests successful
- [ ] Cache headers correct
- [ ] Performance metrics good

---

## Timeline Estimate

| Task | Duration | Status |
|------|----------|--------|
| Manual Apache config fix | 5-10 min | ⏳ Pending |
| Apache restart & test | 2-3 min | ⏳ Pending |
| Varnish re-enablement | 10-15 min | ⏳ Pending |
| Cloudflare cache clear | 2-3 min | ⏳ Pending |
| Production testing | 5-10 min | ⏳ Pending |
| Playwright test suite | 3-5 min | ⏳ Pending |
| **Total** | **27-46 min** | **0% Complete** |

---

## Next Immediate Actions

### Step 1: Fix Apache Configuration (CRITICAL)
Choose Option A (WHM) or Option B (Manual) above and apply the fix.

### Step 2: Verify Fix
```bash
curl -I http://localhost/user/login
```
**Must see**: HTTP 200 or 302 (not 404)

### Step 3: Clear Cloudflare Cache
Visit https://dash.cloudflare.com/ and purge cache.

### Step 4: Test Production
```bash
curl -I https://pim.technostationery.com/user/login
```
**Must see**: HTTP/2 200

### Step 5: Run Comprehensive Tests
```bash
cd /home/pim/public_html
./RUN_PHASE11_PLAYWRIGHT_TESTS.sh
```

---

## Support & References

- **Apache .htaccess**: https://httpd.apache.org/docs/2.4/howto/htaccess.html
- **Apache AllowOverride**: https://httpd.apache.org/docs/2.4/mod/core.html#allowoverride
- **cPanel WHM**: https://docs.cpanel.net/
- **Symfony Routing**: https://symfony.com/doc/current/routing.html
- **Varnish Cache**: https://varnish-cache.org/docs/
- **Cloudflare**: https://developers.cloudflare.com/

---

**End of Phase 11 Final Instructions**  
**Created**: 2026-05-06 20:55:00 CET  
**Status**: Awaiting manual Apache configuration fix via WHM or direct edit  
**Next**: Apply Apache fix, then run verification tests

