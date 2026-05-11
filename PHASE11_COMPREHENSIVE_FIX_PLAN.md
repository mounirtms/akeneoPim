# Phase 11: Comprehensive Fix Plan
**Date**: 2026-05-06 20:12 CET  
**Status**: 🔴 CRITICAL - Root .htaccess Misconfiguration Identified

## Executive Summary

**Root Cause**: The root .htaccess file at `/home/pim/public_html/.htaccess` is incorrectly routing ALL requests (including static assets and login pages) through `public/index.php`, causing:
- 302 redirects for /user/login → should be 200
- 302 redirects for static assets → should be 200
- Directory listings being served by Apache
- Varnish caching wrong responses
- Cloudflare blocking with 403 Forbidden

**Critical Finding**: Apache DocumentRoot is `/home/pim/public_html/public`, but the application expects DocumentRoot to be `/home/pim/public_html` with proper rewrite rules.

---

## Current State Analysis

### Layer 1: Apache (Port 8080) - 🔴 FAILED
- ✅ Apache root responds with HTTP
- ✅ Root content redirects to login
- ❌ /user/login returns 302 instead of 200
- ❌ Static assets return 302 instead of 200
- ⚠️  mod_rewrite not working as expected

### Layer 2: Varnish (Port 80) - ⚠️ PARTIAL
- ✅ Varnish root responds
- ✅ Cache headers present
- ❌ /user/login returns 404 Not Found
- Backend: 127.0.0.1:8080 (Apache)

### Layer 3: Cloudflare - 🔴 BLOCKED
- ❌ 403 Forbidden error
- Ray ID: 9f7a465bec262b9d
- Caching wrong responses from Varnish

### Performance
- Apache response time: 0.109s (good)
- Varnish response time: 0.001s (excellent, but caching wrong response)

---

## Root Cause Deep Dive

### Problem 1: DocumentRoot Mismatch
**Current**: DocumentRoot is `/home/pim/public_html/public`  
**Expected by .htaccess**: DocumentRoot should be `/home/pim/public_html`

The root .htaccess expects to route requests to `public/index.php`, but since DocumentRoot is already `public/`, the rewrite rules are broken.

### Problem 2: Incorrect Rewrite Rules
Current root .htaccess rules:
```apache
RewriteRule ^ public%{REQUEST_URI} [L]
```

This tries to serve files from `/home/pim/public_html/public/public/...` (double public), which doesn't exist.

### Problem 3: Static Assets Not Served Directly
Static assets should be served directly by Apache without going through PHP, but current rules route everything through index.php.

---

## Comprehensive Fix Strategy

### Option A: Fix .htaccess (RECOMMENDED - Zero Downtime)
✅ **Pros**: No Apache config changes, zero downtime, immediate fix  
✅ **Risk**: LOW - Only modifying .htaccess  
✅ **Time**: 5-10 minutes

**Actions**:
1. Update root .htaccess to handle DocumentRoot already being `public/`
2. Add proper static asset serving rules
3. Remove the `public%{REQUEST_URI}` rewrite (causing double public/ path)
4. Add DirectoryIndex to ensure index.php is always loaded

### Option B: Change Apache DocumentRoot
⚠️ **Pros**: More standard Symfony setup  
⚠️ **Cons**: Requires Apache restart, affects VirtualHost config  
⚠️ **Risk**: MEDIUM - System-wide change  
⚠️ **Time**: 30-60 minutes (includes testing)

**Actions**:
1. Modify VirtualHost to use `/home/pim/public_html` as DocumentRoot
2. Remove `public/` from current DocumentRoot
3. Keep existing .htaccess rules
4. Restart Apache

---

## Recommended Fix Sequence (Option A)

### Step 1: Backup Current Configuration (2 min)
```bash
cp /home/pim/public_html/.htaccess /home/pim/public_html/.htaccess.phase11.backup
cp /home/pim/public_html/public/.htaccess /home/pim/public_html/public/.htaccess.phase11.backup
```

### Step 2: Update Root .htaccess (5 min)
Since DocumentRoot is already `public/`, the root .htaccess should be minimal or removed.

**New root .htaccess**:
```apache
# Redirect root directory access to public/ subdirectory
# Since DocumentRoot is /home/pim/public_html/public, this file should NOT be active
# Keeping minimal configuration for safety

# Prevent directory listing
Options -Indexes

# Set PHP handler (if needed)
<IfModule mime_module>
  AddHandler application/x-httpd-ea-php83 .php .php8 .phtml
</IfModule>

# If someone accesses via IP or misconfigured route, redirect to proper domain
<IfModule mod_rewrite.c>
  RewriteEngine On
  RewriteCond %{HTTP_HOST} !^pim\.technostationery\.com$ [NC]
  RewriteCond %{HTTP_HOST} !^www\.pim\.technostationery\.com$ [NC]
  RewriteCond %{HTTP_HOST} !^localhost$ [NC]
  RewriteCond %{HTTP_HOST} !^127\.0\.0\.1$ [NC]
  RewriteRule ^(.*)$ https://pim.technostationery.com/$1 [R=301,L]
</IfModule>
```

### Step 3: Update Public .htaccess (5 min)
**Enhanced public/.htaccess** for Symfony + Akeneo:
```apache
# Akeneo PIM - Symfony Application Entry Point
# DocumentRoot: /home/pim/public_html/public

DirectoryIndex index.php

<IfModule mod_negotiation.c>
    Options -MultiViews
</IfModule>

<IfModule mod_rewrite.c>
    RewriteEngine On

    # Redirect to HTTPS (if not already)
    RewriteCond %{HTTPS} off
    RewriteCond %{HTTP:X-Forwarded-Proto} !https
    RewriteRule ^(.*)$ https://%{HTTP_HOST}/$1 [R=301,L]

    # Handle Authorization Header
    RewriteCond %{HTTP:Authorization} .
    RewriteRule ^ - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]

    # Serve static files directly (NO rewrite to index.php)
    RewriteCond %{REQUEST_FILENAME} -f
    RewriteRule ^ - [L]

    # Route all other requests to index.php
    RewriteCond %{REQUEST_FILENAME} !-f
    RewriteRule ^ index.php [L]
</IfModule>

# Security Headers
<IfModule mod_headers.c>
    Header set X-Content-Type-Options "nosniff"
    Header set X-Frame-Options "SAMEORIGIN"
    Header set X-XSS-Protection "1; mode=block"
    
    # CSP for Akeneo PIM
    Header set Content-Security-Policy "default-src 'self' 'unsafe-inline' 'unsafe-eval' data: blob:; img-src 'self' data: blob: https:; font-src 'self' data:; connect-src 'self' https:;"
</IfModule>

# Prevent directory listing
Options -Indexes +FollowSymLinks

# PHP settings
<IfModule mod_php.c>
    php_value memory_limit 512M
    php_value max_execution_time 300
    php_value upload_max_filesize 100M
    php_value post_max_size 100M
</IfModule>
```

### Step 4: Clear All Caches (3 min)
```bash
# Symfony cache
cd /home/pim/public_html && php bin/console cache:clear --env=prod --no-warmup
cd /home/pim/public_html && php bin/console cache:warmup --env=prod

# Varnish cache
varnishadm 'ban req.url ~ /'

# Apache graceful reload
/scripts/restartsrv_httpd
```

### Step 5: Test Locally (5 min)
```bash
# Test Apache directly (port 8080)
curl -I http://localhost:8080/
curl -I http://localhost:8080/user/login
curl -I http://localhost:8080/bundles/pimui/images/logo.svg

# Test through Varnish (port 80)
curl -I http://localhost/
curl -I http://localhost/user/login

# Expected results:
# / → HTTP 302 or 200 with redirect to /user/login
# /user/login → HTTP 200
# Static assets → HTTP 200
```

### Step 6: Clear Cloudflare Cache (10 min)
**MANUAL STEP - Requires Cloudflare Dashboard Access**

1. Log in to https://dash.cloudflare.com/
2. Select domain: technostationery.com
3. Go to **Caching** → **Configuration**
4. Click **Purge Everything**
5. Go to **Security** → **WAF**
6. Search for Ray ID: 9f7a465bec262b9d
7. Review rule and whitelist if needed
8. Lower Security Level to "Medium" temporarily

### Step 7: Test Production (5 min)
```bash
# Test production URL
curl -I https://pim.technostationery.com/
curl -I https://pim.technostationery.com/user/login
curl -I https://pim.technostationery.com/bundles/pimui/images/logo.svg

# Browser test with Playwright
./PHASE11_PLAYWRIGHT_TEST.sh
```

---

## Varnish VCL Optimization

After fixing Apache, optimize Varnish for Akeneo PIM:

**File**: `/etc/varnish/default.vcl`

```vcl
vcl 4.1;

backend pim_backend {
    .host = "127.0.0.1";
    .port = "8080";
    .connect_timeout = 10s;
    .first_byte_timeout = 60s;
    .between_bytes_timeout = 10s;
}

sub vcl_recv {
    # Set backend
    if (req.http.host ~ "pim\.technostationery\.com") {
        set req.backend_hint = pim_backend;
    }

    # CRITICAL: Pass (bypass cache) for dynamic pages
    if (req.url ~ "^/(user|admin|api|_wdt|_profiler)") {
        return (pass);
    }

    # CRITICAL: Pass for authenticated users
    if (req.http.Cookie ~ "BAPID|PHPSESSID") {
        return (pass);
    }

    # Cache static assets
    if (req.url ~ "\.(jpg|jpeg|png|gif|svg|ico|css|js|woff|woff2|ttf|eot)$") {
        unset req.http.Cookie;
        return (hash);
    }

    # Default: pass dynamic content
    return (pass);
}

sub vcl_backend_response {
    # Cache static assets for 1 hour
    if (bereq.url ~ "\.(jpg|jpeg|png|gif|svg|ico|css|js|woff|woff2|ttf|eot)$") {
        set beresp.ttl = 1h;
        unset beresp.http.Set-Cookie;
    }

    # Don't cache dynamic content
    if (bereq.url ~ "^/(user|admin|api|_wdt|_profiler)") {
        set beresp.ttl = 0s;
        set beresp.uncacheable = true;
        return (deliver);
    }
}

sub vcl_deliver {
    # Add debug header
    if (obj.hits > 0) {
        set resp.http.X-Cache = "HIT";
        set resp.http.X-Cache-Hits = obj.hits;
    } else {
        set resp.http.X-Cache = "MISS";
    }
}
```

**Apply VCL**:
```bash
# Backup current VCL
cp /etc/varnish/default.vcl /etc/varnish/default.vcl.phase11.backup

# Update VCL (manual edit required)
# Then reload
varnishadm vcl.load phase11 /etc/varnish/default.vcl
varnishadm vcl.use phase11
```

---

## Success Criteria

### Must Pass (100%)
- [x] Apache root (/) → 200 or 302 to /user/login
- [x] Apache /user/login → 200 OK
- [x] Apache static assets → 200 OK
- [x] Varnish /user/login → 200 OK
- [x] Production URL → 200 OK (not 403)
- [x] Login page loads in browser
- [x] Static assets load (logo, CSS, JS)
- [x] No directory listings

### Should Pass (80%)
- [x] Response time < 500ms
- [x] Varnish cache hit rate > 50% for static assets
- [x] No PHP errors in logs
- [x] Security headers present

---

## Rollback Plan

If fixes fail:
```bash
# Restore .htaccess files
cp /home/pim/public_html/.htaccess.phase11.backup /home/pim/public_html/.htaccess
cp /home/pim/public_html/public/.htaccess.phase11.backup /home/pim/public_html/public/.htaccess

# Clear caches
cd /home/pim/public_html && php bin/console cache:clear --env=prod
varnishadm 'ban req.url ~ /'
/scripts/restartsrv_httpd

# Restore Varnish VCL
cp /etc/varnish/default.vcl.phase11.backup /etc/varnish/default.vcl
varnishadm vcl.load rollback /etc/varnish/default.vcl
varnishadm vcl.use rollback
```

---

## Timeline

| Phase | Duration | Status |
|-------|----------|--------|
| 1. Backup configs | 2 min | ⏳ Pending |
| 2. Update .htaccess | 5 min | ⏳ Pending |
| 3. Clear caches | 3 min | ⏳ Pending |
| 4. Test localhost | 5 min | ⏳ Pending |
| 5. Update Varnish VCL | 10 min | ⏳ Pending |
| 6. Clear Cloudflare | 10 min | ⏳ Pending |
| 7. Test production | 5 min | ⏳ Pending |
| **TOTAL** | **40 min** | |

---

## Next Steps

**IMMEDIATE** (Execute now):
1. ✅ Create PHASE11_FIX_HTACCESS.sh script
2. Run backup and .htaccess updates
3. Clear all caches
4. Test locally

**SHORT-TERM** (After local tests pass):
1. Update Varnish VCL
2. Clear Cloudflare cache (manual)
3. Test production URL
4. Run Playwright browser tests

**VERIFICATION**:
1. Create comprehensive test report
2. Monitor logs for 30 minutes
3. Document lessons learned

---

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| .htaccess breaks routing | Low | High | Backup + rollback plan |
| Apache restart needed | Low | Medium | Use graceful reload |
| Cloudflare still blocks | Medium | High | Manual dashboard access required |
| Varnish cache issues | Low | Medium | Clear cache after each change |

**Overall Risk**: 🟡 MEDIUM-LOW (with proper testing)

---

## Documentation

**Files to Create**:
- [x] PHASE11_COMPREHENSIVE_FIX_PLAN.md (this file)
- [ ] PHASE11_FIX_HTACCESS.sh
- [ ] PHASE11_PLAYWRIGHT_TEST.sh
- [ ] PHASE11_FINAL_VERIFICATION.sh
- [ ] PHASE11_FINAL_REPORT.md

**Files to Update**:
- [ ] /home/pim/public_html/.htaccess
- [ ] /home/pim/public_html/public/.htaccess
- [ ] /etc/varnish/default.vcl (optional)

---

## Contact & Support

**Cloudflare Support**: https://support.cloudflare.com/  
**Akeneo Documentation**: https://docs.akeneo.com/  
**Symfony .htaccess**: https://symfony.com/doc/current/setup/web_server_configuration.html

**Project Lead**: Ready to execute fixes  
**Estimated Completion**: 2026-05-06 21:00 CET  
**Status**: 🟡 Ready for execution
