# Phase 3 Optimization Roadmap - Performance & Stability
**Date:** 2026-04-29  
**Status:** Planning Complete  
**Target:** Achieve <4.0 system load, 80%+ cache hit rate, <5s page load

---

## 📋 Executive Summary

**Current State:** Platform operational but under critical load (9.58)  
**Target State:** Production-optimized with <4.0 load, 80%+ cache efficiency  
**Timeline:** 3 weeks (Day 1 critical, Week 1 optimization, Week 2 validation)  
**Risk Level:** LOW (all changes reversible with documented rollback)

**Expected Improvements:**
- System Load: 9.58 → 2.5-3.0 (70% reduction)
- Cache Hit Rate: 41% → 80%+ (95% improvement)
- Page Load: 16s → <5s (69% improvement)
- Database QPS: 1,201 → <500 (58% reduction)

---

## 🎯 Phase 3 Timeline & Milestones

### **Week 1: Critical Performance Optimization**
**Target:** Load <6.0, Cache >60%, Page load <10s

#### **Day 1 (April 29) - CRITICAL**
**Priority:** P0 - URGENT  
**Time Required:** 2-3 hours  
**Risk:** LOW

**Milestone 1.1: Enable PHP-FPM**
```bash
# Task 1: Install/verify PHP-FPM
yum list installed | grep php-fpm  # Check if installed
yum install php-fpm -y             # Install if needed

# Task 2: Configure PHP-FPM pool for Akeneo
cat > /etc/php-fpm.d/akeneo.conf << 'EOF'
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
EOF

# Task 3: Configure Apache to use PHP-FPM
cat > /etc/httpd/conf.d/php-fpm.conf << 'EOF'
<FilesMatch \.php$>
    SetHandler "proxy:unix:/var/run/php-fpm/akeneo.sock|fcgi://localhost"
</FilesMatch>

# Enable proxy modules
LoadModule proxy_module modules/mod_proxy.so
LoadModule proxy_fcgi_module modules/mod_proxy_fcgi.so
EOF

# Task 4: Enable and start PHP-FPM
systemctl enable php-fpm
systemctl start php-fpm

# Task 5: Restart Apache
systemctl restart httpd

# Task 6: Verify deployment
systemctl status php-fpm
ps aux | grep php-fpm | wc -l  # Should show 10+ processes
```

**Success Criteria:**
- ✓ PHP-FPM service active with 10+ worker processes
- ✓ System load drops below 6.0 within 30 minutes
- ✓ Page load time reduces to <12 seconds
- ✓ Apache logs show PHP-FPM handling requests
- ✓ No errors in /var/log/php-fpm/error.log

**Expected Impact:**
- Load: 9.58 → 5.5-6.0 (35% reduction)
- Response time: 40% improvement
- Worker efficiency: 50% improvement

**Validation Commands:**
```bash
# Check PHP-FPM status
systemctl status php-fpm
ps aux | grep php-fpm

# Monitor load
watch -n 10 'uptime'

# Test page load
time curl -s -o /dev/null -w "Time: %{time_total}s\n" \
  https://pim.technostationery.com/user/login

# Check error logs
tail -f /var/log/php-fpm/error.log
tail -f /home/pim/public_html/var/logs/prod.log
```

**Rollback Plan:**
```bash
# If issues occur
systemctl stop php-fpm
rm /etc/httpd/conf.d/php-fpm.conf
systemctl restart httpd
# Apache reverts to mod_php automatically
```

---

#### **Days 2-3 (April 30-May 1) - Database Optimization**
**Priority:** P1 - HIGH  
**Time Required:** 3-4 hours  
**Risk:** LOW

**Milestone 1.2: Optimize MariaDB Configuration**

**Pre-requisites:**
- Backup current configuration
- Schedule during low-traffic window (if possible)
- Have rollback plan ready

**Implementation:**
```bash
# Task 1: Backup current configuration
cp /etc/my.cnf /etc/my.cnf.backup.$(date +%Y%m%d)
cp -r /etc/my.cnf.d /etc/my.cnf.d.backup.$(date +%Y%m%d)

# Task 2: Stop MariaDB (brief downtime ~2 minutes)
systemctl stop mariadb

# Task 3: Update MariaDB configuration
cat >> /etc/my.cnf.d/server.cnf << 'EOF'

[mysqld]
# Connection settings
max_connections = 200
thread_cache_size = 16
table_open_cache = 4000
table_definition_cache = 2000

# InnoDB optimization for 31GB RAM system
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

# Binary logging (disable if not using replication)
skip-log-bin

# Performance optimization
innodb_io_capacity = 2000
innodb_io_capacity_max = 4000
innodb_read_io_threads = 8
innodb_write_io_threads = 8
EOF

# Task 4: Ensure log directory exists
mkdir -p /var/log/mysql
chown mysql:mysql /var/log/mysql

# Task 5: Start MariaDB
systemctl start mariadb

# Task 6: Verify startup
systemctl status mariadb
```

**Success Criteria:**
- ✓ MariaDB starts successfully
- ✓ Database connections stable
- ✓ QPS reduces from 1,201 to <900
- ✓ Query response time improves by 20-30%
- ✓ No slow queries in logs

**Expected Impact:**
- Load: 6.0 → 4.5-5.0 (20-25% reduction)
- QPS: 1,201 → 800-900 (25% reduction)
- Query latency: -30%

**Validation:**
```bash
# Check MariaDB status
/opt/mariadb10.6/mariadb/bin/mysql -u root -pYourNewStrongPassword \
  -h 127.0.0.1 -P 3307 -e "SHOW GLOBAL VARIABLES LIKE 'innodb_buffer_pool_size';"

# Monitor performance
/opt/mariadb10.6/mariadb/bin/mysql -u root -pYourNewStrongPassword \
  -h 127.0.0.1 -P 3307 -e "SHOW GLOBAL STATUS WHERE Variable_name IN ('Questions', 'Uptime', 'Slow_queries', 'Threads_running');"

# Calculate QPS
watch -n 5 "/opt/mariadb10.6/mariadb/bin/mysql -u root -pYourNewStrongPassword \
  -h 127.0.0.1 -P 3307 -sN -e \"SHOW GLOBAL STATUS LIKE 'Questions';\" | awk '{print \$2}'"
```

**Rollback Plan:**
```bash
systemctl stop mariadb
cp /etc/my.cnf.backup.YYYYMMDD /etc/my.cnf
cp -r /etc/my.cnf.d.backup.YYYYMMDD/* /etc/my.cnf.d/
systemctl start mariadb
```

---

#### **Days 4-5 (May 2-3) - Varnish Optimization**
**Priority:** P1 - HIGH  
**Time Required:** 3-4 hours  
**Risk:** LOW

**Milestone 1.3: Optimize Varnish Cache**

**Implementation:**
```bash
# Task 1: Backup current Varnish config
cp /etc/varnish/default.vcl /etc/varnish/default.vcl.backup.$(date +%Y%m%d)
cp /etc/varnish/varnish.params /etc/varnish/varnish.params.backup.$(date +%Y%m%d)

# Task 2: Update Varnish memory allocation
cat > /etc/varnish/varnish.params << 'EOF'
VARNISH_LISTEN_PORT=6081
VARNISH_ADMIN_LISTEN_ADDRESS=127.0.0.1
VARNISH_ADMIN_LISTEN_PORT=6082
VARNISH_SECRET_FILE=/etc/varnish/secret
VARNISH_STORAGE="malloc,2G"
VARNISH_TTL=120
DAEMON_OPTS="-p thread_pools=4 -p thread_pool_min=100 -p thread_pool_max=5000 -p http_resp_hdr_len=65536 -p http_resp_size=98304"
EOF

# Task 3: Update VCL configuration for better caching
cat > /etc/varnish/default.vcl << 'EOF'
vcl 4.1;

backend default {
    .host = "127.0.0.1";
    .port = "8080";
    .connect_timeout = 600s;
    .first_byte_timeout = 600s;
    .between_bytes_timeout = 600s;
}

sub vcl_recv {
    # Remove port from host header
    set req.http.Host = regsub(req.http.Host, ":[0-9]+", "");
    
    # Akeneo PIM - bypass cache for authenticated users
    if (req.http.host ~ "pim\.technostationery\.com") {
        if (req.http.Cookie ~ "PHPSESSID" || req.http.Cookie ~ "REMEMBERME") {
            return (pass);
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
        if (req.url ~ "^/checkout" || req.url ~ "^/customer" || req.url ~ "^/cart") {
            return (pass);
        }
        
        if (req.http.Cookie ~ "frontend=") {
            return (pass);
        }
        
        if (req.method == "POST") {
            return (pass);
        }
    }
    
    # Remove analytics cookies (don't affect caching)
    set req.http.Cookie = regsuball(req.http.Cookie, "(^|;\s*)(_ga|_gid|_gat|__utm|_fbp|_fbc)=[^;]*", "");
    set req.http.Cookie = regsuball(req.http.Cookie, "^;\s*", "");
    
    if (req.http.Cookie == "") {
        unset req.http.Cookie;
    }
}

sub vcl_backend_response {
    # Don't cache responses with Set-Cookie
    if (beresp.http.Set-Cookie) {
        set beresp.ttl = 0s;
        set beresp.uncacheable = true;
        return (deliver);
    }
    
    # Cache static assets for 24 hours
    if (bereq.url ~ "\.(js|css|jpg|jpeg|png|gif|ico|svg|woff|woff2|ttf|eot|webp)$") {
        unset beresp.http.Set-Cookie;
        set beresp.ttl = 24h;
        set beresp.http.Cache-Control = "public, max-age=86400";
    }
    
    # Cache HTML pages for 1 hour
    if (beresp.http.Content-Type ~ "text/html") {
        set beresp.ttl = 1h;
    }
    
    # Enable grace mode (serve stale content if backend is down)
    set beresp.grace = 6h;
}

sub vcl_deliver {
    # Add cache debugging headers
    if (obj.hits > 0) {
        set resp.http.X-Cache = "HIT";
        set resp.http.X-Cache-Hits = obj.hits;
    } else {
        set resp.http.X-Cache = "MISS";
    }
    
    # Remove backend headers (security)
    unset resp.http.X-Powered-By;
    unset resp.http.Server;
}
EOF

# Task 4: Validate VCL syntax
varnishd -C -f /etc/varnish/default.vcl

# Task 5: Reload Varnish
systemctl reload varnish

# Task 6: Verify service
systemctl status varnish
```

**Success Criteria:**
- ✓ Varnish reloads without errors
- ✓ Hit rate improves from 41% to >65% within 1 hour
- ✓ Backend requests reduce by 30-40%
- ✓ Page load time reduces to <8 seconds
- ✓ No increase in error rate

**Expected Impact:**
- Hit rate: 41% → 70%+ (70% improvement)
- Backend load: -40%
- Page load: 12s → 7-8s

**Validation:**
```bash
# Monitor cache stats
varnishstat -1 | grep -E 'cache_hit|cache_miss|client_req'

# Calculate hit rate
watch -n 10 'varnishstat -1 | grep -E "MAIN.cache_hit|MAIN.cache_miss" | awk "{sum+=\$2} END {print sum}"'

# Test caching
curl -I https://pim.technostationery.com/user/login
curl -I https://pim.technostationery.com/user/login  # Should show X-Cache: HIT

# Monitor real-time logs
varnishlog -q 'ReqMethod eq "GET"' | grep -E 'Hit|Miss'
```

**Rollback Plan:**
```bash
cp /etc/varnish/default.vcl.backup.YYYYMMDD /etc/varnish/default.vcl
cp /etc/varnish/varnish.params.backup.YYYYMMDD /etc/varnish/varnish.params
systemctl reload varnish
```

---

#### **Days 6-7 (May 4-5) - Redis & Elasticsearch**
**Priority:** P1 - HIGH  
**Time Required:** 2-3 hours  
**Risk:** LOW

**Milestone 1.4: Deploy Redis for Session Management**

```bash
# Task 1: Install Redis
yum install redis -y

# Task 2: Configure Redis
cat > /etc/redis.conf << 'EOF'
bind 127.0.0.1
port 6379
timeout 0
tcp-keepalive 300
daemonize yes
supervised no
pidfile /var/run/redis_6379.pid
loglevel notice
logfile /var/log/redis/redis.log
databases 16
save 900 1
save 300 10
save 60 10000
maxmemory 2gb
maxmemory-policy allkeys-lru
EOF

# Task 3: Enable and start Redis
mkdir -p /var/log/redis
systemctl enable redis
systemctl start redis

# Task 4: Configure Akeneo to use Redis
cat >> /home/pim/public_html/.env.local << 'EOF'

# Redis configuration
REDIS_HOST=127.0.0.1
REDIS_PORT=6379
SESSION_HANDLER=redis
SESSION_SAVE_PATH=tcp://127.0.0.1:6379?database=0
EOF

# Task 5: Clear Akeneo cache
cd /home/pim/public_html
bin/console cache:clear --env=prod
bin/console cache:warmup --env=prod
```

**Milestone 1.5: Optimize Elasticsearch**

```bash
# Task 1: Set replicas to 0 for single-node setup
curl -X PUT "localhost:9200/_settings" -H 'Content-Type: application/json' -d'
{
  "index": {
    "number_of_replicas": 0
  }
}'

# Task 2: Increase heap size
echo 'ES_JAVA_OPTS="-Xms4g -Xmx4g"' >> /etc/elasticsearch/jvm.options

# Task 3: Restart Elasticsearch
systemctl restart elasticsearch

# Task 4: Verify cluster health
curl -X GET "localhost:9200/_cluster/health?pretty"
```

**Success Criteria:**
- ✓ Redis active and handling sessions
- ✓ Elasticsearch cluster status: GREEN
- ✓ Database session queries reduced by 80%
- ✓ QPS drops from 900 to <600
- ✓ No session-related errors

**Expected Impact:**
- QPS: 900 → 600 (33% reduction)
- Session performance: 5x improvement
- Elasticsearch: Yellow → Green

---

### **Week 2: Validation & Fine-Tuning**
**Target:** Load <4.0, Cache >80%, Page load <5s

#### **Days 8-10 (May 6-8) - Testing & Validation**
**Priority:** P1  
**Time Required:** 4-6 hours

**Milestone 2.1: Comprehensive Testing**

**Test Suite:**
1. **Load Testing**
   ```bash
   # Apache Bench
   ab -n 1000 -c 50 https://pim.technostationery.com/user/login
   
   # Monitor during test
   watch -n 2 'uptime; varnishstat -1 | grep cache'
   ```

2. **Varnish User Access Testing**
   - Admin login/logout (should bypass cache)
   - Product edit immediate visibility (cache invalidation)
   - Customer cart operations (session persistence)
   - Guest browsing (full caching)
   - API endpoint freshness

3. **Database Performance Testing**
   ```bash
   # Run stress test
   cd /home/pim/public_html
   bin/console pim:product:query-help --env=prod
   
   # Monitor QPS
   watch -n 5 'mysql -u root -p... -e "SHOW GLOBAL STATUS LIKE \"Questions\";"'
   ```

4. **Error Log Review**
   ```bash
   # Check for new errors after changes
   tail -1000 /home/pim/public_html/var/logs/prod.log | grep -E 'ERROR|CRITICAL'
   tail -500 /var/log/php-fpm/error.log
   tail -500 /var/log/mysql/error.log
   ```

**Success Criteria:**
- ✓ Load stable at <4.0 under normal traffic
- ✓ Cache hit rate >80%
- ✓ Page load time <5s for 95% of requests
- ✓ No critical errors in logs
- ✓ All user scenarios tested successfully

---

#### **Days 11-12 (May 9-10) - Minor Fixes**
**Priority:** P2  
**Time Required:** 2-3 hours

**Milestone 2.2: Address Remaining Issues**

**Fix 404 Errors:**
```bash
# Add favicon.ico
cd /home/pim/public_html/public
cp /path/to/favicon.ico .

# Fix translation routing
# Review routing configuration
cd /home/pim/public_html
bin/console debug:router | grep translation
```

**Review 48h Monitoring Data:**
```bash
# Analyze monitoring logs
cd /home/pim/public_html/webapp/logs/db_monitor

# Check for anomalies
cat monitor_log_*.txt | grep -E "Load|Products|Errors"

# Compare snapshots
diff akeneo_pim_snapshot_20260429*.txt
diff beta_dBT8x12y22_snapshot_20260429*.txt
```

---

#### **Days 13-14 (May 11-12) - Documentation**
**Priority:** P2  
**Time Required:** 3-4 hours

**Milestone 2.3: Final Documentation**

**Create Operational Runbooks:**
1. **Daily Operations**
   - Health check procedures
   - Monitoring commands
   - Log review process

2. **Incident Response**
   - High load troubleshooting
   - Cache issues resolution
   - Database performance problems

3. **Backup & Recovery**
   - Configuration backup procedures
   - Rollback procedures
   - Emergency contacts

4. **Performance Maintenance**
   - Weekly cache clearing
   - Monthly performance review
   - Quarterly optimization review

---

### **Week 3: Content & Long-term Planning**
**Target:** Address content blockers, plan scaling

#### **Days 15-18 (May 13-16) - English Content Strategy**
**Priority:** P3 (Content, not stability)  
**Time Required:** 30-40 hours (developer time)

**Milestone 3.1: English Translation Planning**

**Options Review:**
1. **Option A: Manual Translation** (~40h, $0, highest quality)
2. **Option B: Machine + Review** (~20h, $100-500, recommended)
3. **Option C: Professional Service** (~2 weeks, $3,000+, best quality)

**Recommendation:** Option B

**Implementation Plan:**
```bash
# Phase 1: Export products for translation
cd /home/pim/public_html
bin/console pim:product:export-translations --locale=fr_FR > /tmp/products_fr.csv

# Phase 2: Machine translate (using API)
# Use Google Translate API or DeepL API

# Phase 3: Import English translations
bin/console pim:product:import-translations --locale=en_US /tmp/products_en.csv

# Phase 4: Manual review critical products
# Priority: Top 100 selling products
```

---

#### **Days 19-21 (May 17-19) - SEO & Final Optimization**
**Priority:** P3  
**Time Required:** 4-6 hours

**Milestone 3.2: SEO Metadata Generation**

```bash
# Generate URL keys from names
cd /home/pim/public_html
bin/console pim:product:generate-url-keys --env=prod

# Generate meta titles (name + brand)
# Generate meta descriptions (short_description + category)
```

**Milestone 3.3: Completeness Recalculation**

```bash
# After English translation
bin/console pim:completeness:calculate --env=prod

# Verify improved completeness
# Target: 80%+ for ecommerce channel (en_US)
```

---

## 📊 Success Metrics & KPIs

### **Performance Metrics**

| Metric | Baseline | Week 1 Target | Week 2 Target | Final Target |
|--------|----------|---------------|---------------|--------------|
| System Load (1min) | 9.58 | < 6.0 | < 4.5 | < 4.0 |
| Varnish Hit Rate | 41.37% | > 60% | > 75% | > 80% |
| Page Load Time | 16s | < 10s | < 6s | < 5s |
| Database QPS | 1,201 | < 900 | < 700 | < 500 |
| Error Rate (/day) | 0 | 0 | 0 | 0 |
| Uptime | 99% | 99.5% | 99.9% | 99.9% |

### **Data Quality Metrics**

| Metric | Current | Week 2 | Final |
|--------|---------|--------|-------|
| Price Coverage | 100% | 100% | 100% |
| Weight Coverage | 95% | 97% | 98% |
| Image Coverage | 92% | 94% | 96% |
| English Content | 0% | 0% | 80%+ |
| SEO Metadata | 0% | 0% | 90%+ |
| Completeness | 17% | 20% | 80%+ |

---

## 🚨 Risk Management

### **Identified Risks**

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| PHP-FPM misconfiguration | LOW | HIGH | Test on staging first, have rollback ready |
| MariaDB restart downtime | MEDIUM | MEDIUM | Schedule during low-traffic, 2min max |
| Varnish cache invalidation | LOW | MEDIUM | Monitor cache stats closely |
| Redis memory exhaustion | LOW | LOW | Set maxmemory limits, monitor usage |
| Performance regression | LOW | HIGH | Baseline metrics before each change |

### **Rollback Procedures**

All configurations backed up before changes:
```bash
# Configuration backups location
/etc/my.cnf.backup.YYYYMMDD
/etc/varnish/default.vcl.backup.YYYYMMDD
/etc/php-fpm.d/akeneo.conf.backup.YYYYMMDD
/home/pim/public_html/.env.local.backup.YYYYMMDD
```

**Emergency Rollback:**
```bash
# Stop all new services
systemctl stop php-fpm
systemctl stop redis

# Restore configs
cp /etc/httpd/conf.d/php-fpm.conf.backup /etc/httpd/conf.d/php-fpm.conf
cp /etc/my.cnf.backup.YYYYMMDD /etc/my.cnf
cp /etc/varnish/default.vcl.backup.YYYYMMDD /etc/varnish/default.vcl

# Restart services
systemctl restart httpd
systemctl restart mariadb
systemctl reload varnish
```

---

## 📞 Support & Escalation

### **Team Responsibilities**

| Role | Responsibility | Contact |
|------|---------------|---------|
| DevOps Lead | Infrastructure changes, monitoring | TBD |
| Akeneo Developer | Application optimization, testing | TBD |
| DBA | Database tuning, query optimization | TBD |
| QA Engineer | Performance testing, validation | TBD |

### **Escalation Path**

1. **P0 Issues** (service down): Immediate escalation to DevOps Lead
2. **P1 Issues** (degraded performance): 1-hour response time
3. **P2 Issues** (minor problems): 4-hour response time
4. **P3 Issues** (improvements): Next business day

### **On-Call Schedule**

Week 1 (May 29-6): 24/7 monitoring required  
Week 2 (May 6-12): Business hours monitoring  
Week 3+: Normal operations

---

## 📈 Monitoring & Alerting

### **Real-Time Monitoring**

```bash
# Create monitoring dashboard script
cat > /home/pim/scripts/realtime_monitor.sh << 'EOF'
#!/bin/bash
while true; do
    clear
    echo "=== PLATFORM HEALTH DASHBOARD - $(date) ==="
    echo ""
    
    # System load
    echo "📊 SYSTEM LOAD:"
    uptime | awk -F'load average:' '{print $2}'
    echo ""
    
    # PHP-FPM
    echo "🐘 PHP-FPM:"
    systemctl is-active php-fpm
    ps aux | grep php-fpm | wc -l
    echo ""
    
    # Varnish
    echo "🚀 VARNISH CACHE:"
    varnishstat -1 | grep -E 'cache_hit|cache_miss' | awk '{print $1": "$2}'
    echo ""
    
    # Database
    echo "🗄️ DATABASE:"
    /opt/mariadb10.6/mariadb/bin/mysql -u root -pYourNewStrongPassword \
      -h 127.0.0.1 -P 3307 -sN -e "SHOW GLOBAL STATUS WHERE Variable_name IN ('Threads_connected', 'Questions');"
    echo ""
    
    # Redis
    echo "💾 REDIS:"
    redis-cli ping
    redis-cli INFO | grep -E 'used_memory_human|connected_clients'
    echo ""
    
    sleep 10
done
EOF

chmod +x /home/pim/scripts/realtime_monitor.sh
```

### **Alert Thresholds**

| Metric | Warning | Critical |
|--------|---------|----------|
| System Load | > 6.0 | > 8.0 |
| CPU Usage | > 75% | > 90% |
| Memory Usage | > 80% | > 90% |
| Disk Usage | > 80% | > 90% |
| Varnish Hit Rate | < 70% | < 50% |
| Database QPS | > 800 | > 1000 |
| Page Load Time | > 6s | > 10s |
| Error Rate | > 10/hr | > 50/hr |

---

## ✅ Phase 3 Completion Checklist

### **Week 1 - Critical Optimization**
- [ ] PHP-FPM enabled and verified (10+ workers)
- [ ] System load reduced to <6.0
- [ ] MariaDB optimized (8GB buffer, binlog disabled)
- [ ] QPS reduced to <900
- [ ] Varnish cache increased to 2GB
- [ ] Cache hit rate improved to >65%
- [ ] Redis deployed and handling sessions
- [ ] Elasticsearch replicas set to 0, status GREEN
- [ ] All services stable with no errors

### **Week 2 - Validation**
- [ ] Load testing completed successfully
- [ ] User access scenarios validated
- [ ] Performance benchmarks meet targets
- [ ] 48h monitoring data reviewed
- [ ] 404 errors fixed
- [ ] Operational runbooks created
- [ ] Documentation updated

### **Week 3 - Content Planning**
- [ ] English translation strategy defined
- [ ] Translation vendor/tool selected
- [ ] SEO metadata generation planned
- [ ] Completeness targets set

### **Final Validation**
- [ ] System load: <4.0 ✓
- [ ] Varnish hit rate: >80% ✓
- [ ] Page load: <5s ✓
- [ ] Database QPS: <500 ✓
- [ ] Uptime: 99.9% ✓
- [ ] Zero critical errors ✓

---

**Document Version:** 1.0  
**Created:** 2026-04-29  
**Status:** APPROVED FOR IMPLEMENTATION  
**Next Review:** 2026-05-06
