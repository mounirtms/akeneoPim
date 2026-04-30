# REDIS OPTIMIZATION FOR AKENEO PIM
**Date**: 2026-04-29 14:55
**Status**: Redis ACTIVE, needs Akeneo integration

## CURRENT STATUS

### Redis Service:
- ✅ **Status**: ACTIVE and running
- ✅ **Port**: 6379
- ✅ **Memory**: 557.3M
- ✅ **Operations**: 172 ops/sec (6M+ total commands)
- ✅ **Performance**: Excellent response time

### Integration Status:
- ❌ **Akeneo**: NOT CONFIGURED in .env.local
- ⚠️ **Usage**: Redis running but not utilized by application

## RECOMMENDED CONFIGURATION

### 1. Redis Configuration (/etc/redis.conf)
```ini
# Memory Management
maxmemory 2gb
maxmemory-policy allkeys-lru
maxmemory-samples 5

# Persistence (disable for cache/session - faster)
save ""
appendonly no

# Performance
tcp-backlog 511
timeout 0
tcp-keepalive 300

# Threading (Redis 6.0+)
io-threads 4
io-threads-do-reads yes

# Lazy freeing
lazyfree-lazy-eviction yes
lazyfree-lazy-expire yes
lazyfree-lazy-server-del yes
```

### 2. Akeneo Integration (.env.local)
```bash
# Redis Connection
REDIS_HOST=127.0.0.1
REDIS_PORT=6379
REDIS_DB=0

# Session Storage
SESSION_HANDLER=redis
SESSION_SAVE_PATH=tcp://127.0.0.1:6379/1

# Cache Backend
CACHE_DRIVER=redis
REDIS_CACHE_DB=2

# Queue Backend (optional)
QUEUE_CONNECTION=redis
REDIS_QUEUE_DB=3
```

### 3. Symfony Cache Configuration (config/packages/cache.yaml)
```yaml
framework:
    cache:
        app: cache.adapter.redis
        default_redis_provider: 'redis://127.0.0.1:6379/2'
        
        pools:
            cache.adapter.redis:
                adapter: cache.adapter.redis
                provider: 'redis://127.0.0.1:6379/2'
                default_lifetime: 3600
```

## EXPECTED BENEFITS

### Before Redis Integration:
- Sessions: File-based (slow disk I/O)
- Cache: File-based or database
- QPS: 1,201 queries/sec
- Page Load: 16s average

### After Redis Integration:
- Sessions: In-memory (instant)
- Cache: In-memory (microsecond access)
- QPS: 800-900 (25% reduction)
- Page Load: 10-12s (30% improvement)

## IMPLEMENTATION STEPS

### Step 1: Verify Redis Config
```bash
# Check current config
redis-cli CONFIG GET maxmemory
redis-cli CONFIG GET maxmemory-policy

# Set optimal values (runtime)
redis-cli CONFIG SET maxmemory 2gb
redis-cli CONFIG SET maxmemory-policy allkeys-lru

# Make persistent
sudo nano /etc/redis.conf
# Add lines above, then:
sudo systemctl restart redis
```

### Step 2: Update Akeneo Configuration
```bash
cd /home/pim/public_html/webapp

# Backup current config
cp .env.local .env.local.backup_$(date +%Y%m%d)

# Add Redis configuration
cat >> .env.local << 'REDIS_CONFIG'

# Redis Configuration (added 2026-04-29)
REDIS_HOST=127.0.0.1
REDIS_PORT=6379
REDIS_DB=0
SESSION_HANDLER=redis
SESSION_SAVE_PATH=tcp://127.0.0.1:6379/1
REDIS_CONFIG
```

### Step 3: Clear Akeneo Cache
```bash
cd /home/pim/public_html/webapp
rm -rf var/cache/*
bin/console cache:clear --env=prod
bin/console cache:warmup --env=prod
```

### Step 4: Verify Integration
```bash
# Check Redis connections
redis-cli CLIENT LIST | grep -c "127.0.0.1"

# Monitor keys being created
redis-cli MONITOR | head -20

# Check database usage
redis-cli INFO keyspace
```

## MONITORING COMMANDS

### Check Redis Performance:
```bash
# Current memory usage
redis-cli INFO memory | grep used_memory_human

# Hit rate (evictions should be low)
redis-cli INFO stats | grep keyspace

# Connected clients
redis-cli INFO clients | grep connected_clients

# Operations per second
redis-cli INFO stats | grep instantaneous_ops_per_sec
```

### Expected Healthy Metrics:
- Memory usage: < 2GB
- Connected clients: 10-50
- Ops/sec: 200-500
- Hit rate: >90%
- Evictions: <100/sec

## VALIDATION CHECKLIST

After integration:
- [ ] Redis config updated (maxmemory, policy)
- [ ] .env.local contains Redis settings
- [ ] Akeneo cache cleared and warmed
- [ ] Redis shows connected clients (10+)
- [ ] Keys visible in databases 1, 2, 3
- [ ] Session files no longer created
- [ ] Page load time improved

## ROLLBACK PROCEDURE

If issues occur:
```bash
cd /home/pim/public_html/webapp

# Restore original .env.local
cp .env.local.backup_YYYYMMDD .env.local

# Clear cache
rm -rf var/cache/*
bin/console cache:clear --env=prod

# Restart services
sudo systemctl restart httpd
sudo systemctl restart ea-php83-php-fpm
```

## CURRENT STATUS: ⚠️ NEEDS INTEGRATION

**Priority**: HIGH - Redis running but unused
**Expected Impact**: 25-30% QPS reduction, 30% faster page loads
**Risk**: LOW - Easy rollback if issues

---
**Service**: redis.service
**Port**: 6379
**Status**: ACTIVE, awaiting Akeneo integration
