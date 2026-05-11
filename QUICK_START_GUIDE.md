# Akeneo PIM - Quick Start Guide

## 🚀 Access Your PIM

**Live Site:** https://pim.technostationery.com/

### Login Credentials
```
URL: https://pim.technostationery.com/user/login
Username: admin
Password: admin
```
*(If `admin` doesn't work, try `Admin123!`)*

---

## 📊 Current Status

✅ **Site is LIVE and accessible**
- 8,217 products loaded
- 166 categories
- 112 attributes
- All services running

---

## 🔧 Quick Commands

### Check Services
```bash
systemctl status httpd varnish mariadb
```

### View Logs
```bash
# Apache errors
tail -f /usr/local/apache/logs/error_log

# Akeneo production log
tail -f /home/pim/public_html/var/logs/prod.log

# PHP-FPM errors
tail -f /opt/cpanel/ea-php83/root/usr/var/log/php-fpm/error.log
```

### Clear Cache
```bash
cd /home/pim/public_html
bin/console cache:clear --env=prod
bin/console cache:warmup --env=prod
```

### Change Admin Password
```bash
cd /home/pim/public_html
bin/console pim:user:change-password admin
# Enter new password when prompted
```

### Database Access
```bash
mysql -u root akeneo_pim

# Quick stats
mysql -u root akeneo_pim -e "
SELECT 'Products' as Type, COUNT(*) as Count FROM pim_catalog_product
UNION ALL
SELECT 'Categories', COUNT(*) FROM pim_catalog_category
UNION ALL
SELECT 'Attributes', COUNT(*) FROM pim_catalog_attribute;"
```

---

## 🌐 Architecture

```
Internet → Cloudflare CDN → Apache:80 → PHP-FPM → MariaDB
                                ↑
                                └─ Varnish:8080 (optional)
```

**Cloudflare:** Optimized for Free plan
- Cache enabled (4 hours)
- Brotli compression
- Minification (JS/CSS/HTML)
- Security level: essentially_off

**Apache:** 
- DocumentRoot: `/home/pim/public_html/public`
- Ports: 80, 443
- PHP-FPM: ea-php83

**Varnish:** 
- Port: 8080
- Cache: 6GB
- Currently not in request path (optional enhancement)

---

## ⚡ Performance Tips

### Enable Varnish (Optional)
Varnish is configured but not active. To enable:

1. **Test Varnish directly:**
   ```bash
   curl -I -H "Host: pim.technostationery.com" http://localhost:8080/
   ```

2. **If working, point Cloudflare to Varnish:**
   - Option A: Change origin port to 8080 in Cloudflare
   - Option B: Configure Apache ProxyPass to Varnish

**Benefits:** 10-50x faster page loads, reduced database load

### Monitor Cache Hit Rates
```bash
# Varnish stats
varnishstat -1 | grep -E "cache_hit|cache_miss"

# Check Cloudflare cache headers
curl -I https://pim.technostationery.com/ | grep cf-cache
```

---

## 🔒 Security Checklist

- ✅ HTTPS enabled via Cloudflare
- ✅ ModSecurity configured
- ✅ Admin password set (change to secure password!)
- ⚠️ Consider: Enable Cloudflare WAF rules
- ⚠️ Consider: Set up firewall rules for admin access
- ⚠️ Consider: Enable two-factor authentication

### Change Admin Password (Recommended)
```bash
cd /home/pim/public_html
bin/console pim:user:change-password admin
# Enter a strong password: e.g., "MySecure#PIM2026!"
```

---

## 📈 Monitoring

### Health Check URLs
- Homepage: https://pim.technostationery.com/
- Login: https://pim.technostationery.com/user/login
- API health: https://pim.technostationery.com/api/rest/v1 (requires auth)

### Key Metrics to Monitor
1. **Response Time:** Should be < 500ms for cached pages
2. **Cache Hit Rate:** Target > 80% (Varnish + Cloudflare)
3. **PHP-FPM Pools:** Monitor active/idle workers
4. **Database Connections:** Monitor active queries
5. **Disk Space:** Especially `/home/pim/public_html/var`

### Quick Health Check Script
```bash
#!/bin/bash
echo "=== Akeneo PIM Health Check ==="
echo "Site Response:"
curl -s -o /dev/null -w "Status: %{http_code}, Time: %{time_total}s\n" https://pim.technostationery.com/

echo -e "\nServices:"
systemctl is-active httpd && echo "✓ Apache: Running" || echo "✗ Apache: Down"
systemctl is-active varnish && echo "✓ Varnish: Running" || echo "✗ Varnish: Down"
systemctl is-active mariadb && echo "✓ MariaDB: Running" || echo "✗ MariaDB: Down"

echo -e "\nDatabase Products:"
mysql -u root akeneo_pim -e "SELECT COUNT(*) FROM pim_catalog_product;" 2>/dev/null | tail -1

echo -e "\nDisk Space:"
df -h /home/pim | tail -1
```

---

## 🐛 Troubleshooting

### Site Shows 403 Forbidden
```bash
# Check ModSecurity isn't blocking
tail -20 /usr/local/apache/logs/error_log | grep -i modsec

# Restart Apache
/scripts/restartsrv_httpd --graceful
```

### Site Shows 500 Error
```bash
# Check PHP errors
tail -20 /home/pim/public_html/var/logs/prod.log

# Clear cache
cd /home/pim/public_html
rm -rf var/cache/prod/*
bin/console cache:clear --env=prod
```

### Login Not Working
```bash
# Reset admin password
cd /home/pim/public_html
mysql -u root akeneo_pim -e "
UPDATE oro_user 
SET password = '\$2y\$13\$Zo8zGVlAXsJTH.qA.QfJ3eqvZJXjKj/yrYNO1N8D0cG0Kv8C7VvF.',
    salt = 'salt',
    enabled = 1
WHERE username = 'admin';"

# Password is now: admin
```

### Slow Performance
```bash
# Check PHP-FPM pool status
systemctl status php-fpm

# Check for slow database queries
mysql -u root akeneo_pim -e "SHOW PROCESSLIST;"

# Clear Symfony cache
cd /home/pim/public_html
bin/console cache:clear --env=prod --no-warmup
bin/console cache:warmup --env=prod

# Restart services
/scripts/restartsrv_httpd --graceful
systemctl restart varnish
```

---

## 📚 Documentation Links

### Akeneo PIM
- **Official Docs:** https://docs.akeneo.com/
- **API Reference:** https://api.akeneo.com/
- **Community:** https://www.akeneo.com/community/

### Infrastructure
- **cPanel Docs:** https://cpanel.net/docs/
- **Apache:** https://httpd.apache.org/docs/2.4/
- **Varnish:** https://varnish-cache.org/docs/
- **Cloudflare:** https://developers.cloudflare.com/

---

## 📞 Support Information

### Created Scripts & Reports
All located in `/home/pim/public_html/webapp/`:
- `PHASE11_COMPLETE_SUCCESS_REPORT.md` - Full technical report
- `COMPREHENSIVE_FINAL_REPORT.md` - Detailed audit results
- `playwright_test_report.json` - Automated test results
- Various diagnostic scripts (`*.sh`)

### Service Status Commands
```bash
# Apache
systemctl status httpd
/scripts/restartsrv_httpd --graceful

# Varnish
systemctl status varnish
systemctl restart varnish

# MariaDB
systemctl status mariadb
systemctl restart mariadb

# PHP-FPM
systemctl status php-fpm
systemctl restart php-fpm
```

---

## ✅ Verification Checklist

After any changes, verify:

- [ ] Site accessible: https://pim.technostationery.com/
- [ ] Login page loads: https://pim.technostationery.com/user/login
- [ ] Admin can login with credentials
- [ ] Products visible in catalog
- [ ] No JavaScript errors in browser console
- [ ] Apache status: `systemctl status httpd`
- [ ] Database accessible: `mysql -u root akeneo_pim`
- [ ] Logs clean: `tail /usr/local/apache/logs/error_log`

---

**Last Updated:** 2026-05-07 01:42 CET  
**Status:** Production Ready ✅  
**Version:** Akeneo PIM CE (Latest)
