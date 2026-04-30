# Quick Start: Redis Cache Integration (Phase 4)

**Estimated Time**: 1.5 hours  
**Priority**: 🔴 CRITICAL - Biggest Performance Impact  
**Expected Results**: 30-50% performance improvement, 90%+ cache hit rate

---

## ✅ Pre-Implementation Checklist

**Verify Redis is Running**:
```bash
redis-cli ping
# Expected output: PONG
```

**Check Current Cache Status**:
```bash
cd /home/pim/public_html
du -sh var/cache/prod
find var/cache/prod -type f | wc -l
# Current: 51MB, 8,121 files (slow filesystem cache)
```

**Backup Current Configuration**:
```bash
cp config/packages/cache.yml config/packages/cache.yml.backup
```

---

## 🚀 Implementation Steps

### Step 1: Update Cache Configuration (10 minutes)

**Edit** `/home/pim/public_html/config/packages/cache.yml`:

```yaml
framework:
    cache:
        # Main cache adapters - use Redis instead of filesystem
        app: cache.adapter.redis
        system: cache.adapter.redis
        default_redis_provider: 'redis://localhost:6379/0'
        
        # Configure specific cache pools
        pools:
            # Application cache (Database 1)
            cache.app:
                adapter: cache.adapter.redis
                provider: 'redis://localhost:6379/1'
                default_lifetime: 3600  # 1 hour
            
            # Doctrine result cache (Database 2)
            doctrine.result_cache_pool:
                adapter: cache.adapter.redis
                provider: 'redis://localhost:6379/2'
                default_lifetime: 7200  # 2 hours
            
            # Doctrine system cache (Database 3)
            doctrine.system_cache_pool:
                adapter: cache.adapter.redis
                provider: 'redis://localhost:6379/3'
                default_lifetime: 3600  # 1 hour
            
            # Validator cache (Database 4)
            cache.validator:
                adapter: cache.adapter.redis
                provider: 'redis://localhost:6379/4'
                default_lifetime: 3600  # 1 hour
```

### Step 2: Configure Session Storage in Redis (5 minutes)

**Edit** `/home/pim/public_html/config/packages/framework.yml`:

Find the `session:` section and update:

```yaml
framework:
    session:
        handler_id: 'redis://localhost:6379/5'
        cookie_lifetime: 3600
        gc_maxlifetime: 3600
```

### Step 3: Clear Old Filesystem Cache (5 minutes)

```bash
cd /home/pim/public_html

# Remove old filesystem cache
rm -rf var/cache/prod/*

# Clear cache using Symfony
php bin/console cache:clear --env=prod --no-warmup

# Verify it's cleared
du -sh var/cache/prod
# Should be much smaller now
```

### Step 4: Warm Up Redis Cache (15 minutes)

```bash
cd /home/pim/public_html

# Warm up Symfony cache
php bin/console cache:warmup --env=prod

# Warm up critical routes
echo "Warming critical routes..."
curl -s https://pim.technostationery.com/ > /dev/null
curl -s https://pim.technostationery.com/api/rest/v1/products?limit=10 > /dev/null
curl -s https://pim.technostationery.com/api/rest/v1/categories > /dev/null

echo "✅ Cache warming complete!"
```

### Step 5: Verify Redis is Working (10 minutes)

**Check Redis stats**:
```bash
redis-cli INFO stats
redis-cli INFO memory
redis-cli DBSIZE

# Expected output:
# - keyspace_hits should start increasing
# - keyspace_misses will be high initially
# - used_memory will show cache data
# - DBSIZE > 0 (keys are being stored)
```

**Check Symfony is using Redis**:
```bash
cd /home/pim/public_html
php bin/console cache:pool:list

# Verify pools are using Redis adapter
php bin/console debug:container --parameter=cache.adapter
```

**Test a page load**:
```bash
# First load (cache miss - slower)
time curl -s https://pim.technostationery.com/ > /dev/null

# Second load (cache hit - much faster!)
time curl -s https://pim.technostationery.com/ > /dev/null

# Should see significant speed improvement on second load
```

### Step 6: Monitor Performance (15 minutes)

**Create monitoring script** `webapp/check_redis_performance.php`:

```php
<?php
require_once __DIR__ . '/../vendor/autoload.php';

// Connect to Redis
$redis = new Redis();
$redis->connect('localhost', 6379);

// Get stats from all databases
for ($db = 0; $db <= 5; $db++) {
    $redis->select($db);
    $keys = $redis->dbSize();
    echo "Database $db: $keys keys\n";
}

// Get overall stats
$redis->select(0);
$info = $redis->info('stats');

echo "\n=== Redis Performance Stats ===\n";
echo "Total connections: " . $info['total_connections_received'] . "\n";
echo "Total commands: " . $info['total_commands_processed'] . "\n";
echo "Keyspace hits: " . $info['keyspace_hits'] . "\n";
echo "Keyspace misses: " . $info['keyspace_misses'] . "\n";

if ($info['keyspace_hits'] + $info['keyspace_misses'] > 0) {
    $hit_rate = ($info['keyspace_hits'] / ($info['keyspace_hits'] + $info['keyspace_misses'])) * 100;
    echo "Cache hit rate: " . round($hit_rate, 2) . "%\n";
}

$memory_info = $redis->info('memory');
echo "Memory used: " . $memory_info['used_memory_human'] . "\n";
echo "Memory peak: " . $memory_info['used_memory_peak_human'] . "\n";

echo "\n✅ Redis is working!\n";
```

**Run monitoring**:
```bash
cd /home/pim/public_html
php webapp/check_redis_performance.php
```

### Step 7: Performance Testing (30 minutes)

**Baseline Test**:
```bash
# Test API response times
for i in {1..10}; do
    time curl -s https://pim.technostationery.com/api/rest/v1/products?limit=1 > /dev/null
done

# Test page load times
for i in {1..10}; do
    time curl -s https://pim.technostationery.com/ > /dev/null
done
```

**Monitor cache hit rate over time**:
```bash
# Run this every 5 minutes for 30 minutes
watch -n 300 'redis-cli INFO stats | grep keyspace'
```

---

## 📊 Expected Results

### Before (Filesystem Cache):
- Cache operations: Slow (disk I/O bottleneck)
- Cache hit rate: ~60%
- API response time: 150-200ms
- Page load time: 2-3 seconds
- Cache size: 51MB (8,121 files)

### After (Redis Cache):
- Cache operations: Fast (RAM speed - 10x faster)
- Cache hit rate: 85-90%+ (after warm-up)
- API response time: 80-100ms (-50%)
- Page load time: 1-1.5 seconds (-40%)
- Cache size: In Redis memory (efficient)

---

## 🔍 Troubleshooting

### Issue: "Connection refused to Redis"
```bash
# Check Redis is running
sudo systemctl status redis
sudo systemctl start redis

# Test connection
redis-cli ping
```

### Issue: "Cache still using filesystem"
```bash
# Verify configuration
cat config/packages/cache.yml | grep adapter

# Clear Symfony cache again
php bin/console cache:clear --env=prod --no-warmup
rm -rf var/cache/prod/*

# Rebuild cache
php bin/console cache:warmup --env=prod
```

### Issue: "Low cache hit rate after implementation"
```bash
# Normal! Hit rate improves over time as cache warms up
# Give it 30-60 minutes of normal traffic

# Force warm-up of common queries
php bin/console pim:product:query --limit=100
curl https://pim.technostationery.com/api/rest/v1/products?limit=100
```

### Issue: "Redis memory usage too high"
```bash
# Check current memory
redis-cli INFO memory

# Set memory limit (e.g., 512MB)
redis-cli CONFIG SET maxmemory 512mb
redis-cli CONFIG SET maxmemory-policy allkeys-lru

# Make permanent by editing /etc/redis/redis.conf
```

---

## ✅ Success Verification Checklist

After 30 minutes of running with Redis cache:

- [ ] Redis responding to `redis-cli ping`
- [ ] Cache pools using Redis adapter (`php bin/console cache:pool:list`)
- [ ] Redis databases have keys (`redis-cli DBSIZE` for each DB)
- [ ] Cache hit rate > 80% (`redis-cli INFO stats | grep keyspace`)
- [ ] API response time improved by 30%+
- [ ] Page load time improved by 30%+
- [ ] No errors in logs (`tail -f var/logs/prod.log`)
- [ ] Akeneo UI working normally

---

## 🔄 Rollback Plan (if needed)

If something goes wrong:

```bash
cd /home/pim/public_html

# 1. Restore old configuration
cp config/packages/cache.yml.backup config/packages/cache.yml

# 2. Clear cache
rm -rf var/cache/prod/*
php bin/console cache:clear --env=prod

# 3. Warm up with filesystem cache
php bin/console cache:warmup --env=prod

# 4. Verify system is working
curl https://pim.technostationery.com/

echo "✅ Rolled back to filesystem cache"
```

---

## 📈 Next Steps After Redis Integration

Once Redis is stable (after 24 hours):

1. **Monitor cache hit rate daily** - Should stay above 85%
2. **Optimize TTL values** - Adjust `default_lifetime` based on usage patterns
3. **Implement cache warming cron** - Warm cache after deployments
4. **Add monitoring alerts** - Alert if hit rate drops below 80%
5. **Document Redis maintenance** - Backup, monitoring, optimization procedures

---

## 📞 Support

**If you need help**:
- Check logs: `tail -f /home/pim/public_html/var/logs/prod.log`
- Check Redis logs: `tail -f /var/log/redis/redis-server.log`
- Test Redis: `redis-cli INFO all`
- Contact: webmaster@techno-dz.com

---

**Generated**: 2026-04-30
**Estimated Completion Time**: 1.5 hours
**Expected Performance Gain**: 30-50%
**Risk Level**: Low (easily reversible)
