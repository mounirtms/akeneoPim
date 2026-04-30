# Quick Optimization Guide - Post-Varnish
**Date:** 2026-04-29  
**Priority:** Immediate Actions for System Optimization

---

## 🚨 CRITICAL - Do Today (P0)

### 1. Investigate High System Load (URGENT)
**Current Load: 12.3 (Target: <5.0)**

```bash
# Check what's consuming resources
top -b -n 1 | head -20
ps auxf --sort=-%cpu | head -20
ps auxf --sort=-%mem | head -20

# Check I/O wait
iostat -x 1 10

# Check disk usage
df -h
du -sh /home/pim/public_html/* | sort -rh | head -10

# Check for zombie processes
ps aux | grep -w Z
```

**Action:** Identify and optimize/kill heavy processes

---

### 2. Set Up Error Monitoring

```bash
# Create monitoring script
mkdir -p /home/pim/scripts
cat > /home/pim/scripts/monitor_errors.sh << 'EOF'
#!/bin/bash
LOG_FILE="/home/pim/public_html/var/logs/prod.log"
ERROR_COUNT=$(tail -1000 $LOG_FILE | grep -c ERROR)
CRITICAL_COUNT=$(tail -1000 $LOG_FILE | grep -c CRITICAL)

if [ $ERROR_COUNT -gt 50 ]; then
    echo "High error count: $ERROR_COUNT errors, $CRITICAL_COUNT critical" | \
    mail -s "Akeneo Error Alert" webmaster@techno-dz.com
fi
EOF

chmod +x /home/pim/scripts/monitor_errors.sh

# Add to cron (every 30 minutes)
(crontab -l 2>/dev/null; echo "*/30 * * * * /home/pim/scripts/monitor_errors.sh") | crontab -
```

---

## ⚡ HIGH PRIORITY - Week 1 (P1)

### 1. Optimize Varnish (40% → 80% hit rate)

```bash
# Backup current VCL
cp /etc/varnish/default.vcl /etc/varnish/default.vcl.backup

# Edit VCL configuration
nano /etc/varnish/default.vcl
```

**Add to VCL:**
```vcl
# Increase TTL for static assets
sub vcl_backend_response {
    # Static files
    if (bereq.url ~ "\.(css|js|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf)$") {
        set beresp.ttl = 1h;
        unset beresp.http.set-cookie;
    }
    
    # Product pages
    if (bereq.url ~ "^/enrich/product/") {
        set beresp.ttl = 15m;
    }
    
    # Add grace period
    set beresp.grace = 6h;
}

# Optimize cache keys
sub vcl_hash {
    hash_data(req.url);
    if (req.http.host) {
        hash_data(req.http.host);
    } else {
        hash_data(server.ip);
    }
    # Don't hash on cookies for static content
    if (req.url !~ "\.(css|js|png|jpg|jpeg|gif|ico|svg)$") {
        if (req.http.Cookie) {
            hash_data(req.http.Cookie);
        }
    }
    return (lookup);
}
```

**Test and reload:**
```bash
varnishd -C -f /etc/varnish/default.vcl
systemctl reload varnish
varnishstat -1 | grep cache_hit
```

---

### 2. Enable PHP-FPM

```bash
# Install PHP-FPM (if not installed)
yum install php-fpm  # CentOS/RHEL
# or
apt-get install php8.3-fpm  # Ubuntu/Debian

# Configure PHP-FPM
nano /etc/php-fpm.d/www.conf
# Set:
# pm = dynamic
# pm.max_children = 50
# pm.start_servers = 10
# pm.min_spare_servers = 5
# pm.max_spare_servers = 20

# Enable and start
systemctl enable php-fpm
systemctl start php-fpm

# Configure Apache to use PHP-FPM
a2enmod proxy_fcgi setenvif
a2enconf php8.3-fpm

# Test configuration
apachectl configtest

# Restart Apache
systemctl restart httpd
```

---

### 3. Fix 404 Errors (5 minutes)

```bash
# Fix favicon
cd /home/pim/public_html/public
# Copy existing or create simple one
wget https://www.akeneo.com/favicon.ico -O favicon.ico
# or create a simple blue one
convert -size 32x32 xc:blue favicon.ico

# Fix translation routing
cd /home/pim/public_html
bin/console oro:translation:dump

# Clear cache
bin/console cache:clear --env=prod
```

---

### 4. Complete Missing Data

```bash
# Check missing products
cd /home/pim/public_html/webapp
php production_optimization.php analyze

# Export missing products list
mysql -u root -pYourNewStrongPassword -h 127.0.0.1 -P 3307 akeneo_pim -e "
SELECT identifier, family 
FROM pim_catalog_product 
WHERE is_enabled = 1 
AND JSON_EXTRACT(raw_values, '$.image') IS NULL 
ORDER BY identifier" > missing_images.txt

mysql -u root -pYourNewStrongPassword -h 127.0.0.1 -P 3307 akeneo_pim -e "
SELECT identifier, family 
FROM pim_catalog_product 
WHERE is_enabled = 1 
AND JSON_EXTRACT(raw_values, '$.weight') IS NULL 
ORDER BY identifier" > missing_weights.txt

# Import data via Akeneo UI or API
```

---

## 🔧 MEDIUM PRIORITY - Week 2 (P2)

### 1. Fix Media Permissions

```bash
# Fix overly permissive media directory
chmod 0755 /home/pim/public_html/public/media
find /home/pim/public_html/public/media -type d -exec chmod 0755 {} \;
find /home/pim/public_html/public/media -type f -exec chmod 0644 {} \;
chown -R pim:pim /home/pim/public_html/public/media
```

---

### 2. Optimize Elasticsearch

```bash
# Check cluster status
curl -XGET 'localhost:9200/_cluster/health?pretty'

# For single-node setup, set replicas to 0
curl -XPUT 'localhost:9200/_all/_settings' -H 'Content-Type: application/json' -d '
{
  "index": {
    "number_of_replicas": 0
  }
}'

# Verify
curl -XGET 'localhost:9200/_cluster/health?pretty'
# Should show "green" now
```

---

### 3. Browser Caching

**Add to Apache config:**
```apache
<IfModule mod_expires.c>
    ExpiresActive On
    
    # Images
    ExpiresByType image/jpeg "access plus 1 year"
    ExpiresByType image/gif "access plus 1 year"
    ExpiresByType image/png "access plus 1 year"
    ExpiresByType image/svg+xml "access plus 1 year"
    
    # CSS and JavaScript
    ExpiresByType text/css "access plus 1 month"
    ExpiresByType application/javascript "access plus 1 month"
    
    # Fonts
    ExpiresByType font/woff2 "access plus 1 year"
    ExpiresByType font/woff "access plus 1 year"
    ExpiresByType font/ttf "access plus 1 year"
</IfModule>

<IfModule mod_headers.c>
    # Cache static assets
    <FilesMatch "\.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf)$">
        Header set Cache-Control "max-age=31536000, public"
    </FilesMatch>
</IfModule>
```

---

## 📊 Monitoring Commands

### Check System Health
```bash
# Load average
uptime

# Top processes
top -b -n 1 | head -20

# Memory usage
free -h

# Disk space
df -h

# Disk I/O
iostat -x 1 5
```

### Check Varnish Performance
```bash
# Hit rate
varnishstat -1 | grep cache_hit

# Live stats
varnishstat -l

# Top requests
varnishlog -q "VCL_call eq MISS"
```

### Check Application Performance
```bash
# Apache status
systemctl status httpd

# PHP-FPM status (if enabled)
systemctl status php-fpm

# Check PHP-FPM processes
ps aux | grep php-fpm | wc -l

# Database performance
mysql -u root -pYourNewStrongPassword -h 127.0.0.1 -P 3307 -e "SHOW GLOBAL STATUS LIKE 'Questions'; SHOW GLOBAL STATUS LIKE 'Uptime';"
```

### Check Error Logs
```bash
# Recent errors
tail -100 /home/pim/public_html/var/logs/prod.log | grep ERROR

# Error count
tail -1000 /home/pim/public_html/var/logs/prod.log | grep -c ERROR

# Critical errors
tail -1000 /home/pim/public_html/var/logs/prod.log | grep CRITICAL
```

---

## 📈 Performance Benchmarking

### Before Optimization
```bash
# Test page load time
curl -o /dev/null -s -w 'Total: %{time_total}s\n' https://pim.technostationery.com

# Apache Bench
ab -n 100 -c 10 https://pim.technostationery.com/

# Save results
ab -n 100 -c 10 https://pim.technostationery.com/ > benchmark_before.txt
```

### After Optimization
```bash
# Re-run same tests
ab -n 100 -c 10 https://pim.technostationery.com/ > benchmark_after.txt

# Compare
diff benchmark_before.txt benchmark_after.txt
```

---

## 🎯 Success Criteria

**Week 1 Targets:**
- [ ] System load: <5.0 (currently 12.3)
- [ ] Varnish hit rate: >80% (currently 40.7%)
- [ ] Akeneo load time: <10s (currently 14.3s)
- [ ] ERROR logs: <10/day (currently 125/day)
- [ ] Image coverage: >98% (currently 92%)
- [ ] Weight coverage: >98% (currently 95%)

**Check Progress:**
```bash
# Run daily audit
cd /home/pim/public_html/webapp
php post_varnish_comprehensive_audit.php | tee logs/daily_audit_$(date +%Y%m%d).log
```

---

## 📞 Quick Reference

**Akeneo Commands:**
```bash
cd /home/pim/public_html
bin/console cache:clear --env=prod
bin/console pim:completeness:calculate --env=prod
bin/console oro:translation:dump
```

**Varnish Commands:**
```bash
systemctl restart varnish
varnishstat -1
varnishadm ban req.url "~" "."  # Purge all cache
```

**Database Commands:**
```bash
mysql -u root -pYourNewStrongPassword -h 127.0.0.1 -P 3307 akeneo_pim
mysql -u root -pYourNewStrongPassword -h 127.0.0.1 -P 3307 beta_dBT8x12y22
```

---

**Last Updated:** 2026-04-29 12:00:00  
**Next Review:** Daily until targets met  
**Priority:** Follow P0 → P1 → P2 order
