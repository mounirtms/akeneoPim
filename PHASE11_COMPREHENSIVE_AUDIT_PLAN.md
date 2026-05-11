# Phase 11: Comprehensive Cache & Configuration Audit Plan

**Date**: 2026-05-06  
**Status**: CRITICAL - 404 Routing Issues Blocking Production Access  
**Current State**: Apache running on port 80, .htaccess not being processed

---

## Executive Summary

### Current Situation
- ✅ **Apache**: Running on port 80 (7 processes)
- ❌ **Routing**: All requests return 404 (index.php not being invoked)
- ⚠️ **Varnish**: Disabled (port 80 conflict)
- ✅ **PHP-FPM**: Active (1 process)
- ❌ **Production URL**: https://pim.technostationery.com/ returns 404
- ⚠️ **Cloudflare**: Changed from 403 → 404 (passing traffic but site broken)

### Root Cause
**AllowOverride is NOT set to "All"** in the Apache VirtualHost configuration for `/home/pim/public_html/public`, causing:
1. `.htaccess` files to be completely ignored
2. No URL rewriting to `index.php`
3. Apache serving raw directory structure
4. All dynamic routes returning 404

---

## Multi-Site Architecture Analysis

### Current Stack
```
Internet → Cloudflare (CDN/WAF) → Varnish (Port 80) → Apache (Port 8080) → PHP-FPM → Symfony
                                      ↓ (currently disabled)
                                   Apache on Port 80 (temporary)
```

### Correct Production Stack
```
Internet → Cloudflare → Varnish (Port 80) → Apache (Port 8080) → PHP-FPM → Symfony
           │                                    │
           ├─ Cache Layer 1                    ├─ Cache Layer 2 (.htaccess rules)
           ├─ WAF/Security                     ├─ OPcache
           └─ CDN                              └─ Rewrite Rules
```

---

## Audit Areas

### 1. Apache Configuration Audit

#### Critical Files to Check
- `/etc/apache2/conf/httpd.conf` - Main Apache config
- `/usr/local/apache/conf/httpd.conf` - Alternative location
- VirtualHost entries for `pim.technostationery.com`

#### Required Settings
```apache
<VirtualHost *:8080>
    ServerName pim.technostationery.com
    DocumentRoot /home/pim/public_html/public
    
    <Directory /home/pim/public_html/public>
        AllowOverride All          # ← CRITICAL: Currently missing or set to None
        Require all granted
        Options -Indexes +FollowSymLinks
    </Directory>
    
    # Enable mod_rewrite
    RewriteEngine On
</VirtualHost>

# Listen on port 8080 (for Varnish backend)
Listen 8080
```

#### Diagnostic Commands
```bash
# Find all Apache configs
find /etc -name "httpd.conf" -o -name "apache*.conf" 2>/dev/null

# Check current Listen directives
grep -r "^Listen" /etc/apache2/ /usr/local/apache/ 2>/dev/null

# Check AllowOverride settings
grep -r "AllowOverride" /etc/apache2/ /usr/local/apache/ 2>/dev/null | grep -v "^#"

# Check loaded modules
apachectl -M 2>/dev/null | grep rewrite
```

---

### 2. .htaccess Configuration Audit

#### Root .htaccess (`/home/pim/public_html/.htaccess`)
**Current Status**: ✅ Updated (minimal root config)
```apache
# Prevent directory listings
Options -Indexes

# Security headers
<IfModule mod_headers.c>
    Header set X-Content-Type-Options "nosniff"
</IfModule>

# Block access to sensitive files
<FilesMatch "^\.">
    Require all denied
</FilesMatch>
```

#### Public .htaccess (`/home/pim/public_html/public/.htaccess`)
**Current Status**: ✅ Updated but NOT BEING READ
```apache
DirectoryIndex index.php

# Symfony front controller
<IfModule mod_rewrite.c>
    RewriteEngine On
    RewriteBase /
    
    # Serve static files directly
    RewriteCond %{REQUEST_FILENAME} -f
    RewriteRule ^ - [L]
    
    # Route everything else to index.php
    RewriteCond %{REQUEST_FILENAME} !-f
    RewriteRule ^ index.php [L]
</IfModule>

# Security, compression, caching headers
# ... (full rules in place)
```

**Test**: Create test file to verify .htaccess is being read
```bash
echo "INVALID SYNTAX TO TRIGGER 500" >> /home/pim/public_html/public/.htaccess
curl -I http://localhost/
# Should return 500 if .htaccess is being read
# Currently returns 404 → .htaccess NOT being read
```

---

### 3. Varnish Configuration Audit

#### Configuration Files
- `/etc/varnish/default.vcl` - Varnish cache logic
- `/etc/systemd/system/varnish.service` - Varnish service config

#### Required Settings
```vcl
vcl 4.1;

backend default {
    .host = "127.0.0.1";
    .port = "8080";          # ← Apache backend port
    .connect_timeout = 600s;
    .first_byte_timeout = 600s;
    .between_bytes_timeout = 600s;
}

sub vcl_recv {
    # Pass admin/login requests
    if (req.url ~ "^/(user/login|admin|api)") {
        return (pass);
    }
    
    # Cache static assets
    if (req.url ~ "\.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2)$") {
        return (hash);
    }
}

sub vcl_backend_response {
    # Cache static assets for 1 hour
    if (bereq.url ~ "\.(jpg|jpeg|png|gif|ico|css|js|svg)$") {
        set beresp.ttl = 1h;
    }
    
    # Don't cache dynamic content
    if (bereq.url ~ "^/(user/login|admin|api)") {
        set beresp.ttl = 0s;
        set beresp.uncacheable = true;
    }
}
```

#### Diagnostic Commands
```bash
# Check Varnish status
systemctl status varnish

# Check Varnish config syntax
varnishd -C -f /etc/varnish/default.vcl

# Check backend health
varnishadm backend.list

# View cache stats
varnishstat -1 | grep -E "cache_hit|cache_miss"
```

---

### 4. Cloudflare Configuration Audit

#### Settings to Check (via Dashboard: https://dash.cloudflare.com/)

**SSL/TLS**
- Mode: Full (strict) or Flexible
- Edge Certificates: Active
- Always Use HTTPS: Enabled

**Speed → Optimization**
- Auto Minify: CSS, JS, HTML
- Brotli: Enabled
- Early Hints: Enabled

**Caching**
- Caching Level: Standard
- Browser Cache TTL: Respect Existing Headers
- Cache Everything Page Rules: Review

**Firewall**
- WAF Managed Rules: Review for false positives
- Security Level: Medium (NOT High - causes 403s)
- Rate Limiting: Review rules
- IP Access Rules: Check for blocks

**Page Rules** (Critical for PIM subdomain)
```
URL Pattern: pim.technostationery.com/*
Settings:
  - Cache Level: Bypass (for dynamic content)
  - OR specific rules for /bundles/*, /assets/*
  
URL Pattern: pim.technostationery.com/bundles/*
Settings:
  - Cache Level: Cache Everything
  - Edge Cache TTL: 1 month
```

#### Diagnostic API Calls (if Cloudflare API key found)
```bash
# Purge entire cache
curl -X POST "https://api.cloudflare.com/client/v4/zones/{zone_id}/purge_cache" \
  -H "Authorization: Bearer {api_token}" \
  -H "Content-Type: application/json" \
  --data '{"purge_everything":true}'

# Check firewall events
curl "https://api.cloudflare.com/client/v4/zones/{zone_id}/firewall/events" \
  -H "Authorization: Bearer {api_token}"
```

---

### 5. PHP OPcache Configuration Audit

#### Configuration File
- `/usr/local/lib/php.ini` or `/etc/php.ini`

#### Recommended Settings
```ini
[opcache]
opcache.enable=1
opcache.memory_consumption=256        ; Increase for large apps
opcache.interned_strings_buffer=16   ; Increase for Symfony
opcache.max_accelerated_files=20000  ; Symfony has many files
opcache.validate_timestamps=0        ; Disable in production
opcache.save_comments=1              ; Required for Symfony
opcache.enable_file_override=0
```

#### Diagnostic Commands
```bash
# Check OPcache status
php -r "print_r(opcache_get_status());" 2>/dev/null | head -30

# Check OPcache configuration
php -i | grep opcache

# Clear OPcache (via script)
php -r "opcache_reset();"
```

---

### 6. Symfony Cache Audit

#### Cache Directories
- `/home/pim/public_html/var/cache/prod/` - Production cache (5,988 files)
- `/home/pim/public_html/var/log/` - Application logs

#### Diagnostic Commands
```bash
# Cache statistics
cd /home/pim/public_html && \
du -sh var/cache/prod && \
find var/cache/prod -type f | wc -l

# Check cache warmup
php bin/console cache:warmup --env=prod

# Check routing cache
php bin/console debug:router --env=prod | head -20
```

---

## Playwright Test Plan

### Test Scenarios

#### 1. Homepage Access Test
```javascript
// Test: Homepage loads correctly
const response = await page.goto('https://pim.technostationery.com/');
console.log('Status:', response.status());
console.log('Headers:', response.headers());
// Expected: 200 or 302 to /user/login
```

#### 2. Login Page Test
```javascript
// Test: Login page accessible
const response = await page.goto('https://pim.technostationery.com/user/login');
console.log('Status:', response.status());
console.log('Final URL:', page.url());
// Expected: 200, form visible
```

#### 3. Static Asset Test
```javascript
// Test: Static assets load
const response = await page.goto('https://pim.technostationery.com/bundles/oroui/img/logo.svg');
console.log('Status:', response.status());
console.log('Content-Type:', response.headers()['content-type']);
// Expected: 200, image/svg+xml
```

#### 4. Cache Header Test
```javascript
// Test: Cache headers present
const response = await page.goto('https://pim.technostationery.com/');
console.log('Cache-Control:', response.headers()['cache-control']);
console.log('X-Cache:', response.headers()['x-cache']);
console.log('CF-Cache-Status:', response.headers()['cf-cache-status']);
// Expected: Appropriate cache headers from Varnish and Cloudflare
```

#### 5. Network Timing Test
```javascript
// Test: Performance metrics
const [response] = await Promise.all([
  page.waitForResponse(resp => resp.url().includes('pim.technostationery.com')),
  page.goto('https://pim.technostationery.com/user/login')
]);
const timing = response.timing();
console.log('DNS:', timing.dnsEnd - timing.dnsStart);
console.log('Connect:', timing.connectEnd - timing.connectStart);
console.log('Response:', timing.responseEnd - timing.responseStart);
// Expected: Fast response times with caching
```

---

## Fix Implementation Phases

### Phase 11.1: Apache VirtualHost Fix (CRITICAL - IMMEDIATE)
**Priority**: P0 (Blocking)  
**Duration**: 5-10 minutes  
**Risk**: Low (can rollback)

**Steps**:
1. Backup current Apache config
2. Access WHM/cPanel → Apache Configuration → Include Editor
3. Add Pre-VirtualHost Include:
   ```apache
   <Directory /home/pim/public_html/public>
       AllowOverride All
       Require all granted
       Options -Indexes +FollowSymLinks
   </Directory>
   ```
4. Rebuild Apache config: `/scripts/rebuildhttpdconf`
5. Restart Apache: `/scripts/restartsrv_httpd`
6. Test: `curl -I http://localhost/user/login`
   - Expected: HTTP 200 or 302 to login
   - Current: HTTP 404

**Success Criteria**:
- ✅ Apache config includes `AllowOverride All`
- ✅ `curl http://localhost/user/login` returns 200
- ✅ `.htaccess` test triggers 500 error when syntax is invalid

---

### Phase 11.2: Port Configuration Fix
**Priority**: P1 (High)  
**Duration**: 10-15 minutes  
**Risk**: Medium (brief downtime)

**Steps**:
1. Add `Listen 8080` to Apache config
2. Update VirtualHost to `<VirtualHost *:8080>`
3. Restart Apache
4. Test Apache on port 8080: `curl -I http://localhost:8080/`
5. Start Varnish: `systemctl start varnish`
6. Test Varnish on port 80: `curl -I http://localhost/`

**Success Criteria**:
- ✅ Apache listens on port 8080
- ✅ Varnish listens on port 80
- ✅ Varnish successfully proxies to Apache backend

---

### Phase 11.3: Varnish Configuration Optimization
**Priority**: P2 (Medium)  
**Duration**: 15-20 minutes  
**Risk**: Low

**Steps**:
1. Review `/etc/varnish/default.vcl`
2. Update backend to point to `127.0.0.1:8080`
3. Add cache rules for static assets
4. Add pass rules for admin/API
5. Reload Varnish: `systemctl reload varnish`
6. Clear cache: `varnishadm ban req.url '~' .`

**Success Criteria**:
- ✅ Static assets cached (X-Cache: HIT)
- ✅ Admin pages bypassed (X-Cache: PASS)
- ✅ Fast response times (<100ms for cached)

---

### Phase 11.4: Cloudflare Configuration Review
**Priority**: P2 (Medium)  
**Duration**: 10-15 minutes  
**Risk**: Low

**Steps**:
1. Login to Cloudflare dashboard
2. Review Security Level (set to Medium)
3. Review WAF rules (disable aggressive rules)
4. Create Page Rule for `pim.technostationery.com/*`
5. Purge entire cache
6. Test production URL

**Success Criteria**:
- ✅ No 403 errors from Cloudflare
- ✅ Correct cache headers (CF-Cache-Status)
- ✅ Fast global response times

---

### Phase 11.5: OPcache & Symfony Cache Optimization
**Priority**: P3 (Low)  
**Duration**: 10 minutes  
**Risk**: Very Low

**Steps**:
1. Review PHP OPcache settings
2. Set `opcache.validate_timestamps=0`
3. Clear Symfony cache: `php bin/console cache:clear --env=prod`
4. Warm Symfony cache: `php bin/console cache:warmup --env=prod`
5. Clear OPcache: `php -r "opcache_reset();"`

**Success Criteria**:
- ✅ OPcache hit rate >95%
- ✅ Symfony cache fully warmed
- ✅ Fast application response times

---

### Phase 11.6: Comprehensive Testing & Monitoring
**Priority**: P1 (High)  
**Duration**: 20-30 minutes  
**Risk**: None (read-only)

**Steps**:
1. Run Playwright test suite
2. Capture network logs
3. Analyze cache hit rates
4. Review application logs
5. Performance baseline
6. Generate comprehensive report

**Success Criteria**:
- ✅ All tests pass
- ✅ Cache hit rate >80%
- ✅ Response times <500ms
- ✅ No errors in logs

---

## Success Metrics

| Metric | Current | Target | Status |
|--------|---------|--------|--------|
| Homepage Response | 404 | 200/302 | ❌ |
| Login Page Response | 404 | 200 | ❌ |
| Static Assets | 404 | 200 | ❌ |
| Apache Port | 80 | 8080 | ❌ |
| Varnish Status | Stopped | Running | ❌ |
| .htaccess Processing | No | Yes | ❌ |
| AllowOverride Setting | None/Missing | All | ❌ |
| Cache Hit Rate | 0% | >80% | ❌ |
| Response Time | N/A | <500ms | ⏳ |
| Cloudflare Errors | 404 | None | ❌ |

**Overall Progress**: 0/10 (0%) - All fixes blocked by AllowOverride issue

---

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Apache config breaks site | Low | High | Keep backups, test in staging |
| Port conflict during switch | Medium | Medium | Plan maintenance window |
| Cloudflare cache issues | Low | Low | Manual cache purge available |
| Performance degradation | Low | Medium | Rollback Varnish if needed |
| Data loss | Very Low | High | No database changes |

---

## Rollback Plan

### If Apache Fix Fails
1. Restore backup: `/scripts/rebuildhttpdconf`
2. Restart Apache: `/scripts/restartsrv_httpd`
3. Verify site accessible

### If Varnish Causes Issues
1. Stop Varnish: `systemctl stop varnish`
2. Keep Apache on port 80 (current temporary state)
3. Investigate Varnish logs: `journalctl -u varnish -n 100`

### If Cloudflare Blocks Traffic
1. Set Security Level to "Essentially Off"
2. Disable WAF Managed Rules temporarily
3. Purge cache manually

---

## Timeline Estimate

| Phase | Duration | Dependencies |
|-------|----------|--------------|
| 11.1 Apache VirtualHost Fix | 5-10 min | None (IMMEDIATE) |
| 11.2 Port Configuration | 10-15 min | Phase 11.1 |
| 11.3 Varnish Optimization | 15-20 min | Phase 11.2 |
| 11.4 Cloudflare Review | 10-15 min | Phase 11.3 |
| 11.5 OPcache/Symfony | 10 min | Phase 11.1 |
| 11.6 Testing & Monitoring | 20-30 min | All phases |
| **Total** | **70-100 min** | Sequential execution |

---

## Immediate Next Steps

### 1. Fix AllowOverride (CRITICAL - DO FIRST)
```bash
# Manual method via WHM or direct edit
# Then rebuild and restart Apache
/scripts/rebuildhttpdconf && /scripts/restartsrv_httpd
```

### 2. Verify Fix
```bash
curl -I http://localhost/user/login
# Expected: HTTP 200 (currently 404)
```

### 3. Run Comprehensive Test
```bash
cd /home/pim/public_html && ./PHASE11_FINAL_FIX_AND_TEST.sh
```

### 4. Clear Cloudflare Cache
- Visit: https://dash.cloudflare.com/
- Navigate to: Caching → Configuration → Purge Everything

### 5. Test Production
```bash
curl -I https://pim.technostationery.com/user/login
# Expected: HTTP 200 (currently 404)
```

---

## Documentation & Scripts Created

### Phase 11 Documentation
- ✅ `PHASE11_COMPREHENSIVE_FIX_PLAN.md` - Initial fix plan
- ✅ `PHASE11_COMPLETE_STATUS_AND_NEXT_STEPS.md` - Status update
- ✅ `PHASE11_FINAL_COMPREHENSIVE_REPORT.md` - Detailed report
- ✅ `PHASE11_COMPLETE_FINAL_REPORT.md` - Complete analysis
- ✅ `ROOT_CAUSE_ANALYSIS.md` - Root cause documentation
- ✅ `CLOUDFLARE_FIX_INSTRUCTIONS.md` - Cloudflare guide
- ✅ **`PHASE11_COMPREHENSIVE_AUDIT_PLAN.md`** ← This document

### Phase 11 Scripts
- ✅ `PHASE11_FIX_HTACCESS.sh` - Initial .htaccess fix
- ✅ `PHASE11_FIX_HTACCESS_V2.sh` - Updated .htaccess fix
- ✅ `PHASE11_LOCALHOST_COMPREHENSIVE_TEST.sh` - Local testing
- ✅ `PHASE11_DEEP_DIAGNOSTIC.sh` - Deep diagnostics
- ✅ `PHASE11_EXECUTE_FIXES.sh` - Execute fixes
- ✅ `PHASE11_FIX_APACHE_CRITICAL.sh` - Apache fix attempt
- ✅ `PHASE11_FIX_PORT_CONFIGURATION.sh` - Port config
- ✅ `PHASE11_FINAL_FIX_AND_TEST.sh` - Final fix and test

### Backup Files
- `/home/pim/public_html/.htaccess.phase11.backup.*`
- `/home/pim/public_html/public/.htaccess.phase11.backup.*`
- `/home/pim/public_html/backups/phase11_*/`

---

## Support Resources

- **cPanel Documentation**: https://docs.cpanel.net/
- **Apache .htaccess**: https://httpd.apache.org/docs/2.4/howto/htaccess.html
- **Varnish Cache**: https://varnish-cache.org/docs/
- **Cloudflare Docs**: https://developers.cloudflare.com/
- **Symfony Performance**: https://symfony.com/doc/current/performance.html

---

**End of Phase 11 Comprehensive Audit Plan**  
**Created**: 2026-05-06 20:52:00 CET  
**Next Action**: Execute Phase 11.1 (Apache VirtualHost Fix) immediately to restore site functionality.
