# Varnish Post-Implementation User Access Plan
**Date:** 2026-04-29  
**Platform:** Akeneo PIM & Magento Beta  
**Objective:** Ensure seamless user access after Varnish cache deployment

---

## 🎯 Executive Summary

This plan ensures that all users (admin, editors, customers) can access the platform correctly after Varnish implementation, with proper cache handling for authenticated sessions and dynamic content.

---

## 📋 Current Architecture

### Before Varnish
```
User → Apache/Nginx → PHP → Akeneo/Magento
```

### After Varnish
```
User → Varnish (Port 6081/80) → Apache/Nginx (Port 8080) → PHP → Akeneo/Magento
```

---

## 🔐 User Access Requirements

### 1. **Akeneo PIM Users** (pim.technostationery.com)
- **Admin Users:** Need real-time data, no caching
- **Editor Users:** Need fresh product data, minimal caching
- **Requirements:**
  - Cookie-based session handling
  - Bypass cache for authenticated users
  - Preserve CSRF tokens

### 2. **Magento Frontend Users** (beta.technostationery.com)
- **Guest Users:** Full caching for speed
- **Logged-in Customers:** Personalized content, selective caching
- **Requirements:**
  - Shopping cart state preservation
  - Personalized pricing display
  - Account page bypass

### 3. **API Access**
- **REST API calls:** Should bypass cache
- **Webhook endpoints:** Must receive real-time data

---

## ⚙️ Varnish Configuration Strategy

### VCL Rules for User Access

```vcl
# /etc/varnish/default.vcl

vcl 4.1;

backend default {
    .host = "127.0.0.1";
    .port = "8080";
    .connect_timeout = 600s;
    .first_byte_timeout = 600s;
    .between_bytes_timeout = 600s;
}

# Bypass cache for authenticated users
sub vcl_recv {
    # Remove port from host header
    set req.http.Host = regsub(req.http.Host, ":[0-9]+", "");
    
    # Akeneo PIM - bypass cache for logged-in users
    if (req.http.host ~ "pim\.technostationery\.com") {
        if (req.http.Cookie ~ "PHPSESSID" || req.http.Cookie ~ "REMEMBERME") {
            return (pass);  # Bypass cache for authenticated users
        }
        
        # Always bypass for POST/PUT/DELETE
        if (req.method != "GET" && req.method != "HEAD") {
            return (pass);
        }
        
        # Bypass for admin/API URLs
        if (req.url ~ "^/api/" || req.url ~ "^/admin" || req.url ~ "^/connect" || req.url ~ "^/user") {
            return (pass);
        }
    }
    
    # Magento - bypass cache for logged-in users
    if (req.http.host ~ "beta\.technostationery\.com") {
        # Bypass for shopping cart and checkout
        if (req.url ~ "^/checkout" || req.url ~ "^/customer" || req.url ~ "^/cart") {
            return (pass);
        }
        
        # Bypass if user has customer session cookie
        if (req.http.Cookie ~ "frontend=") {
            return (pass);
        }
        
        # Bypass for POST requests (form submissions)
        if (req.method == "POST") {
            return (pass);
        }
    }
    
    # Remove tracking cookies (don't affect caching)
    set req.http.Cookie = regsuball(req.http.Cookie, "(^|;\s*)(_ga|_gid|_gat|__utm)=[^;]*", "");
    set req.http.Cookie = regsuball(req.http.Cookie, "^;\s*", "");
    
    # If no cookies remain, unset the header
    if (req.http.Cookie == "") {
        unset req.http.Cookie;
    }
}

# Don't cache responses with Set-Cookie
sub vcl_backend_response {
    if (beresp.http.Set-Cookie) {
        set beresp.ttl = 0s;
        set beresp.uncacheable = true;
        return (deliver);
    }
    
    # Cache static assets for longer
    if (bereq.url ~ "\.(js|css|jpg|jpeg|png|gif|ico|svg|woff|woff2|ttf|eot)$") {
        unset beresp.http.Set-Cookie;
        set beresp.ttl = 1h;
    }
}

# Add cache hit/miss header for debugging
sub vcl_deliver {
    if (obj.hits > 0) {
        set resp.http.X-Cache = "HIT";
        set resp.http.X-Cache-Hits = obj.hits;
    } else {
        set resp.http.X-Cache = "MISS";
    }
}
```

---

## 🛠️ Implementation Steps

### Phase 1: Pre-Deployment (Day 0)

1. **Backup Current Configuration**
   ```bash
   cp /etc/varnish/default.vcl /etc/varnish/default.vcl.backup.$(date +%Y%m%d)
   systemctl status varnish > /tmp/varnish_status_before.txt
   ```

2. **Test Environment Setup**
   ```bash
   # Create test VCL
   cp /etc/varnish/default.vcl /etc/varnish/test.vcl
   # Validate VCL syntax
   varnishd -C -f /etc/varnish/test.vcl
   ```

3. **User Communication**
   - Notify admin users of maintenance window
   - Prepare rollback plan
   - Document emergency contacts

### Phase 2: Varnish Configuration (Day 1)

1. **Update VCL Configuration**
   ```bash
   # Edit Varnish configuration
   vim /etc/varnish/default.vcl
   # (Apply VCL rules from above)
   ```

2. **Reload Varnish**
   ```bash
   systemctl reload varnish
   # Verify no errors
   journalctl -u varnish -n 50
   ```

3. **Update Apache/Nginx Backend Port**
   ```bash
   # Ensure Apache listens on 8080
   # /etc/httpd/conf/httpd.conf
   Listen 8080
   systemctl restart httpd
   ```

### Phase 3: Access Testing (Day 1-2)

1. **Akeneo PIM Testing**
   ```bash
   # Test guest access (should be cached)
   curl -I https://pim.technostationery.com/user/login
   # Check X-Cache header: MISS first time, HIT second time
   
   # Test authenticated access (should bypass cache)
   curl -I -b "PHPSESSID=test123" https://pim.technostationery.com/
   # Check X-Cache header: Should not be present or show PASS
   ```

2. **Magento Testing**
   ```bash
   # Test homepage (should be cached)
   curl -I https://beta.technostationery.com/
   
   # Test cart page (should bypass)
   curl -I https://beta.technostationery.com/checkout/cart
   
   # Test customer session (should bypass)
   curl -I -b "frontend=abc123" https://beta.technostationery.com/customer/account
   ```

3. **Manual User Testing**
   - Admin login to Akeneo → Verify real-time updates
   - Editor creates product → Check immediate visibility
   - Customer adds to cart → Verify cart persistence
   - Guest browses catalog → Check page load speed

### Phase 4: Monitoring (Day 2-30)

1. **Cache Performance Monitoring**
   ```bash
   # Real-time cache stats
   varnishstat -1 | grep -E 'cache_hit|cache_miss'
   
   # Hit rate calculation
   watch -n 5 'varnishstat -1 | grep -E "MAIN.cache_hit|MAIN.cache_miss|MAIN.client_req"'
   ```

2. **User Session Monitoring**
   ```bash
   # Check active sessions
   /opt/mariadb10.6/mariadb/bin/mysql -u root -pYourNewStrongPassword -h 127.0.0.1 -P 3307 akeneo_pim \
     -e "SELECT COUNT(*) as active_sessions FROM pim_user_user WHERE last_login > DATE_SUB(NOW(), INTERVAL 1 HOUR);"
   ```

3. **Error Log Monitoring**
   ```bash
   # Watch for authentication issues
   tail -f /home/pim/public_html/var/logs/prod.log | grep -E 'auth|session|cookie'
   ```

---

## 🚨 Troubleshooting Guide

### Issue 1: Users Can't Log In

**Symptoms:**
- Login page loads but authentication fails
- "Session expired" errors

**Diagnosis:**
```bash
# Check if Varnish is caching login pages
curl -I https://pim.technostationery.com/user/login | grep X-Cache
# Should show MISS or no X-Cache header
```

**Solution:**
```vcl
# Add to vcl_recv in /etc/varnish/default.vcl
if (req.url ~ "^/user/login" || req.url ~ "^/security/login") {
    return (pass);
}
```

### Issue 2: Stale Data After Login

**Symptoms:**
- Users see outdated product information
- Changes don't appear immediately

**Diagnosis:**
```bash
# Check if authenticated requests are cached
varnishlog -q 'ReqHeader:Cookie ~ "PHPSESSID"' -g request
```

**Solution:**
```vcl
# Ensure authenticated users bypass cache
if (req.http.Cookie ~ "PHPSESSID") {
    return (pass);
}
```

### Issue 3: Cart/Checkout Issues (Magento)

**Symptoms:**
- Cart empties unexpectedly
- Checkout fails

**Solution:**
```vcl
# Add to vcl_recv
if (req.url ~ "^/(checkout|cart|customer)/") {
    return (pass);
}
```

---

## 📊 Success Metrics

### Week 1 Targets
- **Cache Hit Rate:** > 60%
- **User Login Success:** > 99%
- **Session Errors:** < 5 per day
- **Page Load Time:** < 3 seconds (cached pages)

### Month 1 Targets
- **Cache Hit Rate:** > 80%
- **User Complaints:** 0 authentication issues
- **Availability:** 99.9% uptime
- **Performance:** 50% reduction in server load

---

## 🔄 Rollback Plan

If critical issues arise:

1. **Immediate Rollback**
   ```bash
   # Stop Varnish
   systemctl stop varnish
   
   # Reconfigure Apache to listen on port 80
   sed -i 's/Listen 8080/Listen 80/' /etc/httpd/conf/httpd.conf
   systemctl restart httpd
   
   # Update DNS/Load balancer to point directly to Apache
   ```

2. **Partial Rollback (Keep Varnish for Static Assets Only)**
   ```bash
   # Restore backup VCL
   cp /etc/varnish/default.vcl.backup.* /etc/varnish/default.vcl
   systemctl reload varnish
   ```

---

## 📞 Support Contacts

- **System Administrator:** webmaster@techno-dz.com
- **Varnish Documentation:** https://varnish-cache.org/docs/
- **Emergency Rollback Authority:** [Primary Admin]

---

## ✅ Sign-Off Checklist

- [ ] VCL configuration reviewed and tested
- [ ] Backup configuration saved
- [ ] User access tested for all roles
- [ ] Monitoring scripts deployed
- [ ] Rollback plan documented
- [ ] Team trained on troubleshooting
- [ ] Emergency contacts updated

---

**Document Version:** 1.0  
**Last Updated:** 2026-04-29  
**Next Review:** 2026-05-06
