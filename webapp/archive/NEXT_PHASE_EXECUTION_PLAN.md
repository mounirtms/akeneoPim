# 🚀 NEXT PHASE EXECUTION PLAN
**Date**: 2026-04-29  
**Status**: READY FOR EXECUTION  
**Platform**: Akeneo PIM + Magento + Varnish Stack  
**Current Health**: 30/100 (Grade F) → Target: 85/100 (Grade B)

---

## 📊 CURRENT STATE SUMMARY

### Critical Metrics (Current → Target)
| Metric | Current | Target | Gap |
|--------|---------|--------|-----|
| System Load | 9.58 | <4.0 | -58% |
| Cache Hit Rate | 41% | >80% | +95% |
| Page Load Time | 16s | <5s | -69% |
| DB QPS | 1,201 | <500 | -58% |
| PHP-FPM Status | ❌ INACTIVE | ✅ ACTIVE | BLOCKED |

### Platform Health
- ✅ **Perfect Sync**: 9,538 products (Akeneo ↔ Magento 100%)
- ✅ **Clean Logs**: 0 critical errors in last 24h
- ✅ **DB Health**: 0 slow queries, 3/200 connections
- ❌ **Performance**: System overloaded (240% above target)
- ❌ **Cache**: Severely underperforming (49% below target)

---

## 🎯 EXECUTION TIMELINE - 3 WEEKS

### **WEEK 1: CRITICAL OPTIMIZATION** (May 29 - June 5, 2026)

#### **DAY 1 - THURSDAY (P0 URGENT)** ⚠️
**Task**: Enable PHP-FPM  
**Time**: 2-3 hours  
**Impact**: Load 9.58 → 5.5-6.0 (35% reduction)  
**Status**: 🔴 BLOCKING ALL OTHER TASKS

**Pre-Flight Checklist**:
- [ ] Backup current Apache configuration
- [ ] Verify PHP-FPM package installed
- [ ] Check port 9000 availability
- [ ] Document current load average

**Execution Steps**:
```bash
# 1. Check current status
cd /home/pim/public_html/webapp
uptime
php -v
systemctl status php-fpm

# 2. Backup configurations
sudo cp /etc/httpd/conf/httpd.conf /etc/httpd/conf/httpd.conf.backup_$(date +%Y%m%d)
sudo cp /etc/php-fpm.d/www.conf /etc/php-fpm.d/www.conf.backup_$(date +%Y%m%d)

# 3. Configure PHP-FPM pool
sudo nano /etc/php-fpm.d/www.conf
# Verify/set:
# user = apache
# group = apache
# listen = 127.0.0.1:9000
# pm = dynamic
# pm.max_children = 50
# pm.start_servers = 10
# pm.min_spare_servers = 5
# pm.max_spare_servers = 20
# pm.max_requests = 500

# 4. Enable and start PHP-FPM
sudo systemctl enable php-fpm
sudo systemctl start php-fpm
sudo systemctl status php-fpm

# 5. Configure Apache for FastCGI
sudo nano /etc/httpd/conf/httpd.conf
# Add inside <VirtualHost> or main config:
# <FilesMatch \.php$>
#     SetHandler "proxy:fcgi://127.0.0.1:9000"
# </FilesMatch>

# 6. Test and restart Apache
sudo apachectl configtest
sudo systemctl restart httpd

# 7. Verify
curl -I https://pim.technostationery.com
ps aux | grep php-fpm | wc -l
```

**Validation Criteria**:
- [ ] PHP-FPM process running (10+ workers)
- [ ] Apache serving PHP via FastCGI
- [ ] PIM homepage loads successfully
- [ ] Load average drops to 5.5-6.0 within 1 hour
- [ ] No error logs in `/var/log/httpd/error_log`

**Rollback Plan**:
```bash
# If issues occur
sudo systemctl stop php-fpm
sudo cp /etc/httpd/conf/httpd.conf.backup_$(date +%Y%m%d) /etc/httpd/conf/httpd.conf
sudo systemctl restart httpd
```

---

#### **DAY 2 - FRIDAY** 
**Task**: MariaDB Optimization (Part 1)  
**Time**: 3-4 hours  
**Impact**: Load 6.0 → 4.5-5.0 (25% reduction)  
**Dependencies**: ✅ PHP-FPM enabled

**Execution Steps**:
```bash
# 1. Backup database and configuration
cd /home/pim/public_html/webapp
sudo cp /etc/my.cnf /etc/my.cnf.backup_$(date +%Y%m%d)

# 2. Create optimized configuration
sudo nano /etc/my.cnf

# Add/modify under [mysqld]:
[mysqld]
# Connection Settings
max_connections = 200
max_connect_errors = 1000000

# InnoDB Settings (8GB buffer for 31GB RAM)
innodb_buffer_pool_size = 8G
innodb_buffer_pool_instances = 8
innodb_log_file_size = 512M
innodb_log_buffer_size = 32M
innodb_flush_log_at_trx_commit = 2
innodb_flush_method = O_DIRECT
innodb_file_per_table = 1

# Query Cache (deprecated but still useful)
query_cache_type = 1
query_cache_size = 256M
query_cache_limit = 2M

# Temporary Tables
tmp_table_size = 256M
max_heap_table_size = 256M

# Thread Settings
thread_cache_size = 50
table_open_cache = 4000

# Binary Logging (DISABLE for performance)
skip-log-bin

# 3. Test and restart MariaDB
sudo systemctl restart mariadb@3307
sudo systemctl status mariadb@3307

# 4. Verify settings
/opt/mariadb10.6/mariadb/bin/mysql -u root -p'YourNewStrongPassword' -h 127.0.0.1 -P 3307 -e "SHOW VARIABLES LIKE 'innodb_buffer_pool_size';"
```

**Validation Criteria**:
- [ ] MariaDB restarts successfully
- [ ] InnoDB buffer pool = 8GB
- [ ] Binary logging disabled
- [ ] Query cache enabled
- [ ] DB QPS decreases by 20-30%

---

#### **DAY 3 - SATURDAY**
**Task**: Varnish Cache Optimization  
**Time**: 2-3 hours  
**Impact**: Cache hit 41% → 70%+  
**Dependencies**: ✅ PHP-FPM enabled

**Execution Steps**:
```bash
# 1. Backup Varnish configuration
cd /home/pim/public_html/webapp
sudo cp /etc/varnish/default.vcl /etc/varnish/default.vcl.backup_$(date +%Y%m%d)

# 2. Update VCL configuration
sudo nano /etc/varnish/default.vcl

# Key optimizations:
# - Increase malloc to 2GB
# - Set TTL for static assets to 24h
# - Strip unnecessary cookies
# - Add X-Cache debugging headers

# 3. Update systemd service
sudo nano /etc/systemd/system/varnish.service

# Modify ExecStart:
# ExecStart=/usr/sbin/varnishd \
#   -a :80 \
#   -T localhost:6082 \
#   -f /etc/varnish/default.vcl \
#   -s malloc,2G \
#   -p thread_pool_min=100 \
#   -p thread_pool_max=1000

# 4. Reload and restart
sudo systemctl daemon-reload
sudo systemctl restart varnish
sudo systemctl status varnish

# 5. Test cache
curl -I https://pim.technostationery.com | grep X-Cache
varnishstat -1 | grep cache_hit
```

**Validation Criteria**:
- [ ] Varnish using 2GB malloc storage
- [ ] Static assets cached with 24h TTL
- [ ] X-Cache headers visible in responses
- [ ] Cache hit rate increases to 60%+ within 2 hours
- [ ] Admin login still works (cache bypass)

---

#### **DAY 4 - SUNDAY**
**Task**: Redis Deployment  
**Time**: 3-4 hours  
**Impact**: Session handling offload, 15-20% QPS reduction  
**Dependencies**: ✅ PHP-FPM enabled

**Execution Steps**:
```bash
# 1. Install Redis
sudo yum install redis -y
sudo systemctl enable redis
sudo systemctl start redis

# 2. Configure Redis
sudo nano /etc/redis.conf

# Key settings:
# maxmemory 2gb
# maxmemory-policy allkeys-lru
# save ""  # Disable persistence for sessions

sudo systemctl restart redis

# 3. Update Akeneo configuration
cd /home/pim/public_html/webapp
nano .env.local

# Add Redis configuration:
# REDIS_HOST=127.0.0.1
# REDIS_PORT=6379
# REDIS_DB=0

# Session configuration
# SESSION_HANDLER=redis
# SESSION_REDIS_DSN=redis://127.0.0.1:6379/1

# Cache configuration
# CACHE_ADAPTER=redis
# CACHE_REDIS_DSN=redis://127.0.0.1:6379/2

# 4. Clear Akeneo cache
bin/console cache:clear --env=prod
bin/console cache:warmup --env=prod

# 5. Verify Redis
redis-cli ping
redis-cli info stats
```

**Validation Criteria**:
- [ ] Redis running and responding to PING
- [ ] Akeneo using Redis for sessions
- [ ] Cache keys visible in Redis (redis-cli KEYS *)
- [ ] Session count in Redis matches active users
- [ ] Page load time decreases by 10-15%

---

#### **DAY 5 - MONDAY**
**Task**: Elasticsearch Optimization  
**Time**: 1-2 hours  
**Impact**: Search performance improvement  
**Dependencies**: None

**Execution Steps**:
```bash
# 1. Check current status
curl http://localhost:9200/_cluster/health?pretty

# 2. Update Elasticsearch configuration
sudo nano /etc/elasticsearch/elasticsearch.yml

# Set replicas to 0 for single-node
# index.number_of_replicas: 0

# Increase heap to 4GB
sudo nano /etc/elasticsearch/jvm.options
# -Xms4g
# -Xmx4g

# 3. Restart Elasticsearch
sudo systemctl restart elasticsearch
sudo systemctl status elasticsearch

# 4. Rebuild Akeneo index
cd /home/pim/public_html/webapp
bin/console akeneo:elasticsearch:reset-indexes --env=prod
bin/console pim:product:index --all --env=prod

# 5. Verify
curl http://localhost:9200/_cat/indices?v
curl http://localhost:9200/_cluster/health?pretty
```

**Validation Criteria**:
- [ ] Cluster status = GREEN
- [ ] All indices show 0 replicas
- [ ] Heap usage = 4GB
- [ ] Product search works in PIM
- [ ] Index size reasonable (~100-200MB)

---

#### **DAY 6-7 - TUESDAY/WEDNESDAY**
**Task**: Integration Testing & Fine-Tuning  
**Time**: 4-6 hours  
**Impact**: Validation of all Week 1 changes

**Test Checklist**:
- [ ] PHP-FPM: 30-50 workers running
- [ ] MariaDB: Buffer pool 8GB, QPS <800
- [ ] Varnish: Hit rate >70%, 2GB cache
- [ ] Redis: Session count = active users
- [ ] Elasticsearch: Cluster GREEN, search working
- [ ] System load: <6.0 average
- [ ] Page load: <8 seconds
- [ ] No critical errors in logs

**Week 1 Target Metrics**:
```
System Load:     <6.0    (current: 9.58)
Cache Hit Rate:  >70%    (current: 41%)
Page Load Time:  <8s     (current: 16s)
DB QPS:          <800    (current: 1,201)
```

---

### **WEEK 2: VALIDATION & REFINEMENT** (June 6-12, 2026)

#### **Focus Areas**:
1. **Performance Validation**
   - Run load tests with Apache Bench
   - Measure page load times for key pages
   - Analyze 48-hour monitoring results (completes May 1)

2. **Bug Fixes**
   - Fix 404 errors (favicon.ico, translation files)
   - Review error logs for new issues
   - Optimize slow queries (if any appear)

3. **User Acceptance Testing**
   - Admin login/logout flows
   - Product editing and saving
   - API endpoint performance
   - Magento frontend browsing
   - Cart and checkout (Varnish bypass)

4. **Documentation**
   - Create operational runbooks
   - Document final configurations
   - Write troubleshooting guides

**Week 2 Target Metrics**:
```
System Load:     <4.0    (target achieved)
Cache Hit Rate:  >80%    (target achieved)
Page Load Time:  <5s     (target achieved)
DB QPS:          <500    (target achieved)
Uptime:          99.9%   (production ready)
```

---

### **WEEK 3: CONTENT & PLANNING** (June 13-19, 2026)

#### **Focus Areas**:
1. **English Translation Strategy**
   - Current: 0% completion (9,538 products)
   - Options:
     - A: Manual translation (200h, $10k-20k)
     - B: API translation (20h, $100-500) ✅ RECOMMENDED
     - C: Hybrid approach (80h, $3k-5k)

2. **SEO Metadata Generation**
   - Generate meta titles (0% → 100%)
   - Generate meta descriptions (0% → 100%)
   - Auto-generate from attributes

3. **Completeness Recalculation**
   - Current: 17% average
   - Target: 90%+ after translations

**Week 3 Deliverables**:
- Translation strategy document
- SEO metadata generation script
- Updated completeness metrics
- Long-term content roadmap

---

## 📋 EXECUTION CHECKLIST

### Pre-Execution Readiness
- [x] Comprehensive audit completed
- [x] Baseline metrics documented (load 9.58, cache 41%, QPS 1,201)
- [x] 48-hour DB monitoring started (April 29, 12:07:50)
- [x] All optimization plans documented
- [x] Repository up-to-date (branch: oldbranch)
- [ ] **APPROVAL REQUIRED**: Management sign-off to proceed

### Week 1 Execution
- [ ] Day 1: PHP-FPM enabled and validated
- [ ] Day 2: MariaDB optimized
- [ ] Day 3: Varnish tuned
- [ ] Day 4: Redis deployed
- [ ] Day 5: Elasticsearch optimized
- [ ] Day 6-7: Integration testing complete

### Week 2 Validation
- [ ] Load testing completed
- [ ] Bug fixes deployed
- [ ] UAT completed successfully
- [ ] Documentation finalized
- [ ] Performance targets achieved

### Week 3 Content
- [ ] Translation strategy approved
- [ ] SEO metadata plan ready
- [ ] Completeness roadmap documented

---

## 🎯 SUCCESS CRITERIA

### Week 1 (End of Critical Optimization)
✅ System load **<6.0**  
✅ Cache hit rate **>70%**  
✅ Page load time **<8s**  
✅ All services healthy (PHP-FPM, Redis, Varnish, ES)

### Week 2 (End of Validation)
✅ System load **<4.0**  
✅ Cache hit rate **>80%**  
✅ Page load time **<5s**  
✅ DB QPS **<500**  
✅ Zero critical errors  
✅ Documentation complete

### Week 3 (End of Planning)
✅ Translation strategy approved  
✅ Content roadmap documented  
✅ Platform production-ready

---

## 📊 MONITORING & REPORTING

### Daily Reports During Week 1
```bash
cd /home/pim/public_html/webapp
./scripts/daily_status_check.sh
```

**Metrics to Track**:
- System load (1-min, 5-min, 15-min averages)
- PHP-FPM worker count
- Varnish cache hit rate
- MariaDB QPS and connections
- Redis memory usage
- Elasticsearch cluster health
- Error log count

### Communication Plan
- **Daily updates**: Email status report to webmaster@techno-dz.com
- **Weekly summary**: Comprehensive metrics vs targets
- **Issues escalation**: Immediate notification for critical errors

---

## ⚠️ RISK MITIGATION

### High-Risk Changes
1. **PHP-FPM Migration** (Day 1)
   - Risk: Site downtime if misconfigured
   - Mitigation: Tested rollback plan, backup configs
   - Window: Execute during low-traffic hours

2. **MariaDB Tuning** (Day 2)
   - Risk: Database restart required
   - Mitigation: Backup config, quick restart (<30s)
   - Window: Early morning

### Rollback Strategy
Each day has documented rollback procedures:
- Config backups timestamped
- Service stop/start commands ready
- Previous working state documented

**Rollback SLA**: <15 minutes to restore previous state

---

## 💰 INVESTMENT SUMMARY

### Phase 3 (Weeks 1-3)
- **Infrastructure**: $0 (existing resources)
- **Labor**: 20-30 hours DevOps/SysAdmin
- **Estimated Cost**: $1,000-$1,500
- **Timeline**: May 29 - June 19, 2026

### Expected ROI
- **Load Reduction**: 58% (9.58 → 4.0)
- **Cache Improvement**: 95% (41% → 80%+)
- **Page Speed**: 69% faster (16s → 5s)
- **Capacity Increase**: 3× current throughput
- **Avoided Costs**: Defer infrastructure upgrade ($5k-10k)

---

## 📞 CONTACT & ESCALATION

**Primary Contact**: webmaster@techno-dz.com  
**Repository**: https://github.com/mounirtms/akeneoPim.git (branch: oldbranch)  
**Live Sites**:
- Akeneo PIM: https://pim.technostationery.com
- Magento: https://beta.technostationery.com

**Escalation Path**:
1. Technical issues → DevOps team
2. Business decisions → Management approval
3. Critical outage → Immediate rollback + notification

---

## 📚 REFERENCE DOCUMENTS

Created during audit phase:
1. `COMPREHENSIVE_STABILITY_AUDIT_REPORT_20260429.md` (23 KB)
2. `PHASE_3_OPTIMIZATION_ROADMAP.md` (23 KB)
3. `varnish_access_plan.md` (17 KB)
4. `server_tuning_guide.md` (15 KB)
5. `NEXT_STEPS_EXECUTIVE_BRIEF.md` (7.8 KB)
6. `AUDIT_SUMMARY_QUICK_VIEW.md` (5.9 KB)

All located in: `/home/pim/public_html/webapp/`

---

## 🚦 EXECUTION STATUS

**Overall Status**: ⏳ READY TO START  
**Next Action**: Enable PHP-FPM (Day 1)  
**Blocking Issues**: None  
**Approval Required**: YES - Management sign-off  

**Start Date**: Upon approval  
**Expected Completion**: June 19, 2026  
**Current Phase**: Pre-execution planning complete  

---

**Document Version**: 1.0  
**Last Updated**: 2026-04-29  
**Next Review**: After Week 1 completion (June 5, 2026)

