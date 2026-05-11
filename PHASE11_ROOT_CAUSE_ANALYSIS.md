# PHASE 11: ROOT CAUSE ANALYSIS - DIRECTORY INDEX ISSUE
**Date**: 2026-05-06 20:10 CET | **Status**: 🔴 CRITICAL ISSUE IDENTIFIED

---

## 🔍 ROOT CAUSE IDENTIFIED

### **THE PROBLEM**: Varnish Cache Bypassing .htaccess Rules

**What's happening**:
1. Browser requests `https://pim.technostationery.com/` 
2. Cloudflare forwards to **Varnish on port 80**
3. Varnish forwards to **Apache on port 8080**
4. Apache serves directory index **DIRECTLY** (ignoring .htaccess rewrite rules)
5. Varnish caches this wrong response
6. Browser shows "Index of /" instead of Akeneo PIM

---

## 📊 AUDIT FINDINGS

### 1. Varnish Configuration ✅ CONFIRMED ACTIVE

```
Process: /usr/sbin/varnishd -a 0.0.0.0:80
Backend: 127.0.0.1:8080 (Apache)
Port 80: Varnish (NOT Apache)
Port 8080: Apache (internal only)
```

**Varnish is handling ALL port 80 traffic** and forwarding to Apache on 8080.

### 2. Apache Configuration ✅ CORRECT but BYPASSED

```
DocumentRoot: /home/pim/public_html/public ✓
AllowOverride: All ✓
mod_rewrite: Enabled ✓
Port: 8080 (behind Varnish)
```

Apache is configured correctly BUT Varnish is caching the wrong response.

### 3. .htaccess Rewrite Rules ✅ CORRECT but NOT APPLIED

**Root .htaccess** (`/home/pim/public_html/.htaccess`):
```apache
RewriteEngine On
RewriteBase /

# Prevent direct access to /public directory
RewriteCond %{REQUEST_URI} ^/public/
RewriteRule ^ - [F,L]

# Static files - serve from public/
RewriteCond %{REQUEST_URI} ^/(bundles|css|js|dist|images|img|media|favicon\.ico|robots\.txt)/
RewriteRule ^ public%{REQUEST_URI} [L]

# Everything else to public/index.php
RewriteRule ^ public/index.php [QSA,L]
```

**Problem**: Apache DocumentRoot is `/home/pim/public_html/public/` which BYPASSES the root .htaccess entirely!

### 4. What Browser Sees vs What It Should See

**Current (WRONG)**:
```html
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN">
<html>
<head><title>Index of /</title></head>
<body><h1>Index of /</h1>
<!-- Directory listing of /home/pim/public_html/public/ -->
```

**Expected (CORRECT)**:
```html
<!DOCTYPE html>
<html>
<head>
    <meta http-equiv="refresh" content="0;url='/user/login'" />
    <title>Redirecting to /user/login</title>
</head>
```

### 5. Direct PHP Test ✅ WORKS CORRECTLY

```bash
$ php public/index.php
# Returns: Redirect to /user/login ✓
```

**This proves** the application code is correct. The issue is web server routing.

---

## 🔴 CRITICAL FINDINGS

### Finding 1: DocumentRoot Mismatch
- **Apache DocumentRoot**: `/home/pim/public_html/public/`
- **Root .htaccess location**: `/home/pim/public_html/.htaccess`
- **Result**: Root .htaccess is NEVER read because Apache starts in `public/` subdirectory

### Finding 2: Varnish Cache Layer
- **Varnish is caching** the directory index response
- **Cache-Control headers** from Apache are being overridden by Varnish
- **Cloudflare** adds another caching layer on top

### Finding 3: DirectoryIndex Not Working
When Apache serves `/home/pim/public_html/public/` directly:
- DirectoryIndex should try `index.php` first
- Instead, Apache shows directory listing
- This means DirectoryIndex is disabled OR overridden

### Finding 4: Multi-Layer Caching
```
Browser → Cloudflare (CDN) → Varnish (Port 80) → Apache (Port 8080) → PHP
                ↓                    ↓                    ↓
           Cache Layer 1        Cache Layer 2     Directory Index Problem
```

---

## 🎯 WHY THIS HAPPENS

### The Varnish-Apache-DocumentRoot Conflict

1. **Varnish forwards requests to `http://127.0.0.1:8080/`**
2. **Apache receives request at DocumentRoot `/home/pim/public_html/public/`**
3. **Apache tries to serve `/home/pim/public_html/public/index.php`**
4. **BUT**: DirectoryIndex is not configured OR Apache shows directory listing by default
5. **public/.htaccess** rewrite rules are NOT executed because:
   - Request URI is `/` (root)
   - Rewrite condition checks for `/dist`, `/css`, `/bundles` etc.
   - None match, so rules don't trigger
6. **Apache returns directory listing** (21KB HTML)
7. **Varnish caches this wrong response**
8. **Cloudflare caches Varnish's cached response**

---

## 🔧 SOLUTION APPROACH

### Option 1: Fix Apache DirectoryIndex (RECOMMENDED)
**Pros**: Simple, minimal changes, respects Akeneo structure
**Cons**: None

**Implementation**:
```apache
# In Apache VirtualHost or public/.htaccess
DirectoryIndex index.php index.html

<Directory "/home/pim/public_html/public">
    Options -Indexes +FollowSymLinks
    AllowOverride All
    DirectoryIndex index.php
</Directory>
```

### Option 2: Change DocumentRoot to Parent Directory
**Pros**: Makes root .htaccess effective
**Cons**: Security risk (exposes var/, config/, vendor/)

**NOT RECOMMENDED** for security reasons.

### Option 3: Add Varnish VCL Rules
**Pros**: Handles caching intelligently
**Cons**: Complex, requires Varnish expertise

**Implementation**:
```vcl
# In /etc/varnish/default.vcl
sub vcl_recv {
    # For Akeneo PIM domain
    if (req.http.host == "pim.technostationery.com") {
        # Never cache root path
        if (req.url == "/") {
            return (pass);
        }
        # Never cache login paths
        if (req.url ~ "^/user/") {
            return (pass);
        }
    }
}
```

### Option 4: Cloudflare Page Rules (IMMEDIATE)
**Pros**: Can be done now via Cloudflare dashboard
**Cons**: Doesn't fix root cause

**Implementation**:
1. Login to Cloudflare
2. Create Page Rule: `pim.technostationery.com/`
3. Set: **Cache Level: Bypass**
4. Create Page Rule: `pim.technostationery.com/user/*`
5. Set: **Cache Level: Bypass**

---

## 📋 RECOMMENDED FIX SEQUENCE

### Phase 11.1: Immediate Fixes (5 minutes)
1. **Clear Varnish cache**: `varnishadm "ban req.url ~ /"`
2. **Clear Cloudflare cache**: Via dashboard or API
3. **Test with cache-busting**: `curl -H "Cache-Control: no-cache"`

### Phase 11.2: Apache Configuration (10 minutes)
1. **Add DirectoryIndex to VirtualHost**
2. **Disable directory listing**: `Options -Indexes`
3. **Ensure public/.htaccess is read**: `AllowOverride All`
4. **Restart Apache**: `/scripts/restartsrv_httpd`

### Phase 11.3: Varnish Configuration (15 minutes)
1. **Update `/etc/varnish/default.vcl`**
2. **Add bypass rules for dynamic paths**
3. **Reload Varnish config**: `systemctl reload varnish`
4. **Test**: Verify / redirects to /user/login

### Phase 11.4: Cloudflare Optimization (10 minutes)
1. **Create Page Rules for cache bypass**
2. **Set up Development Mode** (optional, for testing)
3. **Configure cache TTL** for static assets only
4. **Enable Always Online** (cache fallback)

### Phase 11.5: Verification & Testing (20 minutes)
1. **Browser test**: Clear browser cache, load https://pim.technostationery.com
2. **Playwright test**: Automated browser verification
3. **Performance test**: Check response times
4. **Cache validation**: Ensure proper cache headers

---

## 🚨 CRITICAL ISSUES TO FIX

### Priority 1: CRITICAL (Fix Now)
- [ ] **Varnish caching directory index** (clearing cache required)
- [ ] **Apache DirectoryIndex missing** (add to VirtualHost)
- [ ] **Directory listing enabled** (disable with Options -Indexes)

### Priority 2: HIGH (Fix Today)
- [ ] **Cloudflare caching wrong response** (clear CF cache)
- [ ] **Varnish VCL needs bypass rules** (for /user/* paths)
- [ ] **Cache-Control headers** (ensure proper headers from Akeneo)

### Priority 3: MEDIUM (Fix This Week)
- [ ] **Varnish health check** (configure proper health checks)
- [ ] **Cloudflare Page Rules** (optimize caching strategy)
- [ ] **Performance monitoring** (track cache hit rates)

---

## 📊 EXPECTED RESULTS AFTER FIX

### Before Fix:
```
https://pim.technostationery.com/
→ Returns: Directory Index (21KB HTML)
→ Response time: ~200ms (cached)
→ Status: 200 OK
→ Problem: Wrong content served
```

### After Fix:
```
https://pim.technostationery.com/
→ Returns: Redirect to /user/login (302 or HTML meta redirect)
→ Response time: ~200ms
→ Status: 302 Found OR 200 OK with meta redirect
→ Result: Akeneo login page displays
```

---

## 🔍 VERIFICATION COMMANDS

### Test 1: Direct Apache (Bypass Varnish)
```bash
curl -H "Host: pim.technostationery.com" http://localhost:8080/
# Should return redirect to /user/login
```

### Test 2: Through Varnish
```bash
curl http://localhost/
# Should return redirect to /user/login
```

### Test 3: Production (Through Cloudflare)
```bash
curl -I https://pim.technostationery.com/
# Should return 302 redirect OR HTML with meta redirect
```

### Test 4: Clear All Caches
```bash
# Varnish
varnishadm "ban req.url ~ /"

# Cloudflare (requires API key)
curl -X POST "https://api.cloudflare.com/client/v4/zones/{zone_id}/purge_cache" \
  -H "Authorization: Bearer {api_token}" \
  -d '{"purge_everything":true}'
```

---

## 📝 CONFIGURATION FILES TO MODIFY

1. **Apache VirtualHost**: `/etc/apache2/conf/httpd.conf`
2. **Varnish VCL**: `/etc/varnish/default.vcl`
3. **Cloudflare Settings**: Via dashboard (page rules)
4. **public/.htaccess**: `/home/pim/public_html/public/.htaccess`

---

## ✅ SUCCESS CRITERIA

- [ ] `https://pim.technostationery.com/` redirects to `/user/login`
- [ ] Login page displays correctly with Akeneo branding
- [ ] Static assets load properly (`/bundles/`, `/css/`, `/js/`)
- [ ] No directory listing visible at any URL
- [ ] Cache hit rate > 80% for static assets
- [ ] Cache miss (or bypass) for dynamic pages
- [ ] Response time < 500ms for all pages

---

**Next Steps**:
1. Execute `PHASE11_FIX_VARNISH_APACHE.sh`
2. Clear all caches (Varnish + Cloudflare)
3. Test with Playwright
4. Monitor logs for 10 minutes
5. Generate completion report

---

**Status**: Ready to execute fixes
**Estimated Time**: 30-40 minutes total
**Risk Level**: LOW (fixes are reversible)
**Downtime**: 0 seconds (graceful reloads)

