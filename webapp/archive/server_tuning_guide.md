# Server Performance Tuning Guide
**Platform:** Akeneo PIM + Magento + Varnish  
**Date:** 2026-04-29  
**Target:** Reduce load from 12+ to < 4.0, optimize performance

---

## 🎯 Current Performance Baseline

### System Metrics (2026-04-29)
- **Load Average:** 12.3 / 7.67 / 7.47 (1min / 5min / 15min)
- **Target Load:** < 4.0 (for 4-core system)
- **Memory Usage:** 15 GB / 31 GB (48%)
- **Disk I/O:** Not measured (needs assessment)
- **Database QPS:** ~1,232 queries/second

### Performance Issues Identified
1. **High CPU Load:** System load > 12 (critical)
2. **PHP-FPM Inactive:** Missing process manager optimization
3. **Apache/Nginx Overlap:** Both services running (inefficient)
4. **Database Load:** High query rate without optimization
5. **Elasticsearch Yellow:** Replica configuration issue

---

## 🔧 Tuning Strategy

### Priority 1: Immediate Load Reduction (Day 1)

#### 1.1 Enable and Optimize PHP-FPM

**Current State:** PHP-FPM inactive, Apache using mod_php (slow)

**Action:**
```bash
# Install PHP-FPM (if not installed)
yum install php-fpm -y

# Configure PHP-FPM pool
cat > /etc/php-fpm.d/akeneo.conf << 'FPM_CONF'
[akeneo]
user = pim
group = pim
listen = /var/run/php-fpm/akeneo.sock
listen.owner = apache
listen.group = apache
listen.mode = 0660

; Process management
pm = dynamic
pm.max_children = 50
pm.start_servers = 10
pm.min_spare_servers = 5
pm.max_spare_servers = 20
pm.max_requests = 500

; Performance tuning
pm.process_idle_timeout = 10s
request_terminate_timeout = 300s

; Resource limits
php_admin_value[memory_limit] = 512M
php_admin_value[max_execution_time] = 300
php_admin_value[upload_max_filesize] = 50M
php_admin_value[post_max_size] = 50M

; OPcache optimization
php_value[opcache.enable] = 1
php_value[opcache.memory_consumption] = 256
php_value[opcache.interned_strings_buffer] = 16
php_value[opcache.max_accelerated_files] = 20000
php_value[opcache.validate_timestamps] = 0
php_value[opcache.revalidate_freq] = 0
FPM_CONF

# Enable and start PHP-FPM
systemctl enable php-fpm
systemctl start php-fpm
systemctl status php-fpm
```

**Expected Impact:** 30-40% load reduction

#### 1.2 Consolidate Web Servers (Choose One: Apache OR Nginx)

**Current State:** Both Apache and Nginx running (conflict/waste)

**Option A: Use Apache with Varnish (Recommended)**
```bash
# Stop Nginx
systemctl stop nginx
systemctl disable nginx

# Configure Apache for PHP-FPM
cat > /etc/httpd/conf.d/php-fpm.conf << 'APACHE_FPM'
<FilesMatch \.php$>
    SetHandler "proxy:unix:/var/run/php-fpm/akeneo.sock|fcgi://localhost"
</FilesMatch>
APACHE_FPM

# Update Apache to listen on port 8080 (behind Varnish)
sed -i 's/^Listen 80$/Listen 8080/' /etc/httpd/conf/httpd.conf

# Enable required modules
echo "LoadModule proxy_module modules/mod_proxy.so" >> /etc/httpd/conf.modules.d/00-proxy.conf
echo "LoadModule proxy_fcgi_module modules/mod_proxy_fcgi.so" >> /etc/httpd/conf.modules.d/00-proxy.conf

# Restart Apache
systemctl restart httpd
```

**Option B: Use Nginx with Varnish (Alternative)**
```bash
# Stop Apache
systemctl stop httpd
systemctl disable httpd

# Configure Nginx for PHP-FPM
cat > /etc/nginx/conf.d/akeneo.conf << 'NGINX_CONF'
upstream php-fpm {
    server unix:/var/run/php-fpm/akeneo.sock;
}

server {
    listen 8080;
    server_name pim.technostationery.com;
    root /home/pim/public_html/public;
    index index.php;
    
    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }
    
    location ~ \.php$ {
        fastcgi_pass php-fpm;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }
}
NGINX_CONF

systemctl restart nginx
```

**Expected Impact:** 15-20% load reduction

#### 1.3 Optimize MariaDB Configuration

**Current Load:** 1,232 QPS, likely unbuffered queries

**Action:**
```bash
# Backup current config
cp /etc/my.cnf /etc/my.cnf.backup.$(date +%Y%m%d)

# Add optimizations to /etc/my.cnf.d/server.cnf
cat >> /etc/my.cnf.d/server.cnf << 'MYSQL_TUNE'

[mysqld]
# Connection settings
max_connections = 200
thread_cache_size = 16
table_open_cache = 4000
table_definition_cache = 2000

# InnoDB optimization
innodb_buffer_pool_size = 8G
innodb_log_file_size = 512M
innodb_flush_log_at_trx_commit = 2
innodb_flush_method = O_DIRECT
innodb_file_per_table = 1
innodb_buffer_pool_instances = 8

# Query cache (disabled for modern workloads)
query_cache_type = 0
query_cache_size = 0

# Slow query logging
slow_query_log = 1
slow_query_log_file = /var/log/mysql/slow.log
long_query_time = 2

# Tmp table optimization
tmp_table_size = 64M
max_heap_table_size = 64M

# Binary logging (if not using replication, disable)
skip-log-bin
MYSQL_TUNE

# Restart MariaDB
systemctl restart mariadb
```

**Expected Impact:** 20-30% load reduction

---

### Priority 2: Medium-Term Optimization (Week 1)

#### 2.1 Akeneo Cache Optimization

```bash
cd /home/pim/public_html

# Enable production-optimized caching
bin/console cache:clear --env=prod --no-warmup
bin/console cache:warmup --env=prod

# Enable OPcache preloading (PHP 7.4+)
echo "opcache.preload=/home/pim/public_html/var/cache/prod/App_KernelProdContainer.preload.php" >> /etc/php.d/10-opcache.ini

# Optimize Doctrine metadata caching
bin/console doctrine:cache:clear-metadata --env=prod
bin/console doctrine:cache:clear-query --env=prod
bin/console doctrine:cache:clear-result --env=prod
```

#### 2.2 Elasticsearch Optimization

**Current Issue:** Cluster status yellow (replica issue)

```bash
# Disable replicas for single-node setup
curl -X PUT "localhost:9200/_settings" -H 'Content-Type: application/json' -d'
{
  "index": {
    "number_of_replicas": 0
  }
}'

# Increase heap size (50% of available RAM, max 32GB)
echo "ES_JAVA_OPTS=\"-Xms4g -Xmx4g\"" >> /etc/elasticsearch/jvm.options

# Restart Elasticsearch
systemctl restart elasticsearch
```

#### 2.3 Varnish Tuning

```bash
# Increase Varnish memory allocation
cat > /etc/varnish/varnish.params << 'VARNISH_PARAMS'
VARNISH_LISTEN_PORT=6081
VARNISH_ADMIN_LISTEN_ADDRESS=127.0.0.1
VARNISH_ADMIN_LISTEN_PORT=6082
VARNISH_SECRET_FILE=/etc/varnish/secret
VARNISH_STORAGE="malloc,2G"
VARNISH_TTL=120
DAEMON_OPTS="-p thread_pools=4 -p thread_pool_min=100 -p thread_pool_max=5000"
VARNISH_PARAMS

systemctl restart varnish
```

---

### Priority 3: Long-Term Optimization (Month 1)

#### 3.1 Implement CDN for Static Assets

```bash
# Configure Akeneo to use CDN for media
cat >> /home/pim/public_html/.env.local << 'CDN_CONFIG'
AKENEO_PIM_URL=https://cdn.technostationery.com
AKENEO_PIM_UPLOAD_DIR=/home/pim/public_html/public/media
CDN_CONFIG
```

#### 3.2 Database Query Optimization

```bash
# Analyze slow queries
cd /home/pim/public_html/webapp
cat > analyze_slow_queries.php << 'SLOW_QUERY'
<?php
$db = new PDO('mysql:host=127.0.0.1;port=3307;dbname=akeneo_pim', 'root', 'YourNewStrongPassword');

// Find tables without indexes
$tables = $db->query("
    SELECT 
        t.TABLE_NAME,
        t.TABLE_ROWS,
        COUNT(s.INDEX_NAME) as index_count
    FROM information_schema.TABLES t
    LEFT JOIN information_schema.STATISTICS s ON t.TABLE_SCHEMA = s.TABLE_SCHEMA AND t.TABLE_NAME = s.TABLE_NAME
    WHERE t.TABLE_SCHEMA = 'akeneo_pim'
    GROUP BY t.TABLE_NAME
    HAVING index_count < 2
    ORDER BY t.TABLE_ROWS DESC
    LIMIT 20;
")->fetchAll(PDO::FETCH_ASSOC);

echo "Tables with insufficient indexes:\n";
print_r($tables);
SLOW_QUERY

php analyze_slow_queries.php
```

#### 3.3 Implement Redis for Session/Cache

```bash
# Install Redis
yum install redis -y
systemctl enable redis
systemctl start redis

# Configure Akeneo to use Redis
cat >> /home/pim/public_html/.env.local << 'REDIS_CONFIG'
REDIS_HOST=127.0.0.1
REDIS_PORT=6379
SESSION_HANDLER=redis
SESSION_SAVE_PATH=tcp://127.0.0.1:6379
REDIS_CONFIG
```

---

## 📊 Monitoring & Validation

### Real-Time Performance Monitoring

```bash
# Create monitoring script
cat > /home/pim/scripts/performance_monitor.sh << 'PERF_MONITOR'
#!/bin/bash
while true; do
    clear
    echo "=== PERFORMANCE DASHBOARD - $(date) ==="
    echo ""
    
    # System load
    echo "📊 System Load:"
    uptime
    echo ""
    
    # PHP-FPM status
    echo "🐘 PHP-FPM:"
    systemctl is-active php-fpm
    ps aux | grep php-fpm | wc -l
    echo ""
    
    # Database performance
    echo "🗄️ Database:"
    /opt/mariadb10.6/mariadb/bin/mysql -u root -pYourNewStrongPassword -h 127.0.0.1 -P 3307 -e "SHOW GLOBAL STATUS LIKE 'Threads_connected';"
    /opt/mariadb10.6/mariadb/bin/mysql -u root -pYourNewStrongPassword -h 127.0.0.1 -P 3307 -e "SHOW GLOBAL STATUS LIKE 'Questions';"
    echo ""
    
    # Varnish cache
    echo "🚀 Varnish Cache:"
    varnishstat -1 | grep -E 'cache_hit|cache_miss'
    echo ""
    
    sleep 10
done
PERF_MONITOR

chmod +x /home/pim/scripts/performance_monitor.sh
```

### Performance Benchmarking

```bash
# Before/After comparison script
cat > /home/pim/scripts/benchmark.sh << 'BENCHMARK'
#!/bin/bash
echo "Starting benchmark..."

# Test Akeneo login page load time
time curl -s -o /dev/null -w "Time: %{time_total}s\n" https://pim.technostationery.com/user/login

# Test Magento homepage
time curl -s -o /dev/null -w "Time: %{time_total}s\n" https://beta.technostationery.com/

# Apache Bench test
ab -n 100 -c 10 https://pim.technostationery.com/user/login
BENCHMARK

chmod +x /home/pim/scripts/benchmark.sh
```

---

## ✅ Tuning Checklist & Expected Results

| Task | Status | Expected Load Impact | Notes |
|------|--------|----------------------|-------|
| Enable PHP-FPM | ⏳ | -30% to -40% | Critical |
| Consolidate Web Servers | ⏳ | -15% to -20% | Choose Apache OR Nginx |
| Optimize MariaDB | ⏳ | -20% to -30% | Buffer pool key |
| Fix Elasticsearch | ⏳ | -5% to -10% | Replica = 0 |
| Optimize Varnish | ⏳ | -10% to -15% | Increase cache |
| Implement Redis | ⏳ | -5% to -10% | Session management |

**Total Expected Load Reduction:** 85-125% (from 12.3 to ~3-6)

---

## 🎯 Success Metrics

### Week 1 Targets
- **System Load:** < 6.0
- **Page Load Time:** < 5 seconds
- **Database QPS:** < 800
- **PHP-FPM:** Active with 20+ workers

### Month 1 Targets
- **System Load:** < 4.0
- **Page Load Time:** < 3 seconds
- **Varnish Hit Rate:** > 80%
- **Zero Critical Errors**

---

## 📞 Support Resources

- **Performance Tuning:** https://www.akeneo.com/documentation/
- **PHP-FPM Guide:** https://www.php.net/manual/en/install.fpm.php
- **MariaDB Optimization:** https://mariadb.com/kb/en/optimization/

---

**Document Version:** 1.0  
**Last Updated:** 2026-04-29  
**Next Review:** 2026-05-06
