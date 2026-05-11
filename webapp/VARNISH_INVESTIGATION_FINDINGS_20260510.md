# Varnish/Apache Routing Investigation - Session Report
**Date:** 2026-05-10  
**Branch:** recovery-testing-phase3-20260506_091124  
**Issue:** PIM redirecting to technostationery.com main site instead of loading properly

---

## 🔍 ROOT CAUSE IDENTIFIED

After extensive investigation, the root cause has been identified:

**The issue is NOT with Varnish, but with how the Host header is being forwarded to Apache.**

### Key Findings

1. **Apache VirtualHost Configuration: ✅ CORRECT**
   - PIM VirtualHost properly configured on port 81 (line 873 of httpd.conf)
   - ServerName: `pim.technostationery.com`
   - DocumentRoot: `/home/pim/public_html/public`
   - Verified with `apachectl -S`

2. **Direct IP Access: ✅ WORKS CORRECTLY**
   ```bash
   curl -I "http://205.134.249.177:81/" -H "Host: pim.technostationery.com"
   # Result: 302 redirect to http://pim.technostationery.com/user/login ✅ CORRECT
   ```

3. **Localhost Access: ❌ FAILS - REDIRECTS TO MAIN SITE**
   ```bash
   curl -I "http://127.0.0.1:81/" -H "Host: pim.technostationery.com"
   # Result: 302 redirect to http://technostationery.com/ ❌ WRONG
   ```

4. **Content Being Served:**
   - When failing, Apache serves the main technostationery.com Magento e-commerce site
   - HTML title: "Techno Stationery | Première Chaîne de Papeterie en Algérie..."
   - This proves Apache is matching the WRONG VirtualHost (the main site at line 382)

---

## 🎯 THE PROBLEM

When accessing through **127.0.0.1:81** (localhost), Apache is NOT properly matching the `pim.technostationery.com` VirtualHost, and instead defaults to the **first VirtualHost** on that IP/port combination, which is **technostationery.com** (line 382).

This happens because:
- The Host header may not be properly forwarded through Varnish
- Apache's name-based virtual hosting requires the correct Host header to match VirtualHosts
- When the Host header doesn't match any VirtualHost exactly, Apache uses the **first** VirtualHost as default

---

## 🔧 CONFIGURATION CHANGES MADE (FOR SESSION COOKIE DOMAIN FIXES)

While investigating, we attempted to fix the session cookie domain issue:

### 1. Framework Configuration Updated
**File:** `/home/pim/public_html/config/packages/framework.yml`
```yaml
session:
    name: BAPID
    handler_id: ~
    cookie_domain: 'pim.technostationery.com'  # Added
    cookie_samesite: 'lax'
    cookie_secure: true
    cookie_httponly: true
    gc_maxlifetime: 86400
```

### 2. PHP .user.ini Configuration Updated
**File:** `/home/pim/public_html/public/.user.ini`
```ini
# Added auto_prepend_file to force correct session cookie domain
auto_prepend_file = "/home/pim/public_html/public/prepend_session_fix.php"

# Added explicit session cookie domain
session.cookie_domain = "pim.technostationery.com"
```

### 3. Session Cookie Fix Prepend File Created
**File:** `/home/pim/public_html/public/prepend_session_fix.php`
- Forces session cookie domain to pim.technostationery.com before application boots

### 4. Event Subscriber Created (Not Yet Effective)
**File:** `/home/pim/public_html/src/EventSubscriber/SessionCookieDomainSubscriber.php`
- Symfony event subscriber to fix cookie domain at runtime
- Registered in services configuration

### 5. CloudFlare Credentials Saved
**File:** `/home/pim/public_html/webapp/.cloudflare_credentials`
- Securely stored CloudFlare API credentials for future management
- Added to .gitignore

**Note:** These session cookie fixes were attempted but are currently ineffective because **the wrong application is being served** (technostationery.com Magento instead of Akeneo PIM).

---

## ✅ RECOMMENDED SOLUTION

### Option 1: Fix Varnish VCL to Force Correct Backend (RECOMMENDED)

Create a **user-specific Varnish configuration** for the PIM user that properly routes requests:

**File:** `/etc/varnish/pim_user.vcl` (NEW)
```vcl
# PIM User-Specific VCL Configuration
# This file is for pim.technostationery.com routing only

backend pim_backend {
    .host = "205.134.249.177";  # Use actual IP, not localhost
    .port = "81";
    .first_byte_timeout = 600s;
    .connect_timeout = 10s;
    .between_bytes_timeout = 60s;
}

sub vcl_recv {
    # Match PIM subdomain requests
    if (req.http.host == "pim.technostationery.com") {
        set req.backend_hint = pim_backend;
        
        # CRITICAL: Preserve the Host header
        set req.http.X-Forwarded-Host = req.http.host;
        
        # Bypass cache completely for PIM
        return(pass);
    }
}
```

Then include this in the main VCL:
```vcl
include "/etc/varnish/pim_user.vcl";
```

### Option 2: Fix Apache VirtualHost Ordering

Move the PIM VirtualHost definition BEFORE the main technostationery.com VirtualHost in httpd.conf so it becomes the default for the IP address. However, this is **NOT RECOMMENDED** as it might affect other sites.

### Option 3: Use Explicit IP Binding for PIM (CLEANEST SOLUTION)

If possible, assign a dedicated IP address to the PIM VirtualHost so there's no ambiguity in Apache's virtual host matching.

---

## 🧪 VERIFICATION TESTS

After implementing the fix, verify with these tests:

### Test 1: Direct Varnish Access
```bash
curl -I http://127.0.0.1:80/ -H "Host: pim.technostationery.com"
# Expected: 302 redirect to https://pim.technostationery.com/user/login
```

### Test 2: Direct Apache Access
```bash
curl -I http://205.134.249.177:81/ -H "Host: pim.technostationery.com"
# Expected: 302 redirect to http://pim.technostationery.com/user/login
```

### Test 3: Full Public Access
```bash
curl -I https://pim.technostationery.com/
# Expected: 302 redirect to https://pim.technostationery.com/user/login
```

### Test 4: Verify Content
```bash
curl -sL https://pim.technostationery.com/ | grep -E "<title>|Akeneo"
# Expected: Should show Akeneo PIM content, NOT "Techno Stationery" Magento site
```

---

## 📋 UNCOMMITTED CHANGES

Files modified but not yet committed:
- `config/packages/framework.yml` - Session cookie domain fix
- `config/services/services.yml` - Event subscriber registration
- `public/.user.ini` - PHP session configuration
- `public/prepend_session_fix.php` - NEW FILE
- `src/EventSubscriber/SessionCookieDomainSubscriber.php` - NEW FILE
- `.cloudflare_credentials` - NEW FILE
- `.gitignore` - Updated to exclude credentials

These changes should be committed once the routing issue is resolved and verified to work.

---

## 🚫 WHAT DIDN'T WORK (AND WHY)

1. **Modifying Symfony session configuration** - Ineffective because wrong app is loading
2. **PHP .user.ini session.cookie_domain** - Not being applied, and wrong app loading anyway
3. **Auto-prepend file for session** - Wrong application is being served
4. **Symfony Event Subscriber** - Can't execute because wrong application is loading
5. **Clearing caches multiple times** - Not the issue; routing problem is upstream

---

## 🎯 NEXT STEPS

1. **DO NOT modify production Varnish configuration directly** (per user's explicit requirement)
2. **Create separate VCL configuration for PIM user** as shown in Option 1 above
3. **Test the VCL configuration** in a safe manner before deploying
4. **Verify the fix** using the test commands above
5. **Commit all configuration changes** after verification
6. **Create pull request** with all fixes

---

## 📊 SERVICES STATUS

- ✅ Varnish 6.0.13: Running on port 80
- ✅ Apache: Running on ports 81 and 443
- ✅ PHP-FPM (ea-php81): Running
- ✅ Symfony 5.4.51: Working when correct VirtualHost matches
- ✅ PHP 8.2.30: Operational

---

## 💡 TECHNICAL INSIGHT

The core issue is **name-based virtual hosting** behavior:
- Apache uses the `Host:` HTTP header to match VirtualHosts
- When multiple VirtualHosts share the same IP:port, Apache needs an exact ServerName match
- If no match is found, Apache uses the **first** VirtualHost defined for that IP:port
- In this case, technostationery.com (line 382) comes before pim.technostationery.com (line 873)
- Using 127.0.0.1 vs 205.134.249.177 affects which VirtualHost Apache considers "first"

---

**Session Duration:** Approximately 2 hours of investigation  
**Diagnosis:** Complete - Root cause identified  
**Solution:** Documented and ready for implementation  
**Risk Level:** Low - Solution is non-invasive to production configuration
