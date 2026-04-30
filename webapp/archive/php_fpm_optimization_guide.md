# PHP-FPM OPTIMIZATION ANALYSIS & RECOMMENDATIONS
**Date**: 2026-04-29 14:50
**Current Status**: PHP-FPM is ACTIVE but severely UNDER-CONFIGURED

## CURRENT CONFIGURATION ISSUES

### Critical Problems Found:
1. **pm = ondemand** - Workers created on-demand, causing latency
2. **pm.max_children = 25** - TOO LOW for high-traffic site (need 50+)
3. **pm.max_requests = 128** - TOO LOW, causing frequent worker recycling
4. **pm.process_idle_timeout = 30** - Workers die too quickly

### Current Pool Settings:
```
Pool: pim_technostationery_com
Mode: ondemand (INEFFICIENT for high traffic)
Max Children: 25 (INSUFFICIENT)
Max Requests: 128 (TOO LOW)
Idle Timeout: 30s (TOO SHORT)
Active Workers: ~10 (UNDERUTILIZED)
```

## RECOMMENDED CONFIGURATION

### Optimal Settings for 31GB RAM Server:
```ini
[pim_technostationery_com]
pm = dynamic                    # Change from ondemand to dynamic
pm.max_children = 60            # Increase from 25 to 60
pm.start_servers = 15           # Start with 15 workers (25% of max)
pm.min_spare_servers = 10       # Keep 10 idle workers ready
pm.max_spare_servers = 25       # Cap idle workers at 25
pm.max_requests = 1000          # Increase from 128 to 1000
pm.process_idle_timeout = 60s   # Increase from 30s to 60s
```

### Why These Numbers?

**Memory Calculation:**
- Average PHP-FPM worker: ~80-120MB RAM
- 60 workers × 100MB = 6GB RAM (19% of 31GB total)
- Safe allocation considering MariaDB (8GB) + other services

**Performance Impact:**
- Dynamic mode keeps workers ready (no spawn delay)
- 15 pre-started workers handle immediate traffic
- 10-25 spare workers buffer traffic spikes
- 1000 max_requests reduces restart overhead

## CPANEL CONFIGURATION METHOD

Since this is a cPanel server, modifications must be done via:

### Option 1: WHM Interface (RECOMMENDED)
```
WHM → MultiPHP Manager → FPM Settings
1. Select domain: pim.technostationery.com
2. Choose PHP version: 8.3 (ea-php83)
3. Set Process Manager: dynamic
4. Max Children: 60
5. Start Servers: 15
6. Min Spare Servers: 10
7. Max Spare Servers: 25
8. Max Requests: 1000
9. Process Idle Timeout: 60
```

### Option 2: cPanel API (Command Line)
```bash
# Via cPanel UAPI
uapi --user=pim LangPHP php_set_vhost_versions \
  version=ea-php83 \
  vhost-0=pim.technostationery.com

# Then edit pool via WHM API
whmapi1 php_fpm_set_pool_option \
  pool=pim_technostationery_com \
  option=pm value=dynamic

whmapi1 php_fpm_set_pool_option \
  pool=pim_technostationery_com \
  option=pm.max_children value=60
```

### Option 3: Direct File Edit (NOT RECOMMENDED - cPanel will overwrite)
```bash
# If you must edit directly (not persistent):
sudo nano /opt/cpanel/ea-php83/root/etc/php-fpm.d/pim.technostationery.com.conf

# Then restart:
sudo systemctl restart ea-php83-php-fpm
```

## EXPECTED RESULTS

### Before Optimization:
- Load Average: 2.10, 2.06, 3.16
- Active Workers: ~10
- Mode: ondemand (spawn on demand)
- Response Time: 16s average

### After Optimization:
- Load Average: 1.0-1.5 (30-50% reduction)
- Active Workers: 15-25 (always ready)
- Mode: dynamic (persistent workers)
- Response Time: 5-8s average (50-70% improvement)

## MONITORING COMMANDS

### Check Current Workers:
```bash
ps aux | grep "php-fpm: pool pim_technostationery_com" | grep -v grep | wc -l
```

### Check FPM Status:
```bash
systemctl status ea-php83-php-fpm
```

### Monitor Worker Activity:
```bash
watch -n 2 'ps aux | grep "php-fpm: pool" | grep -v grep'
```

### Check Pool Status (if status_path enabled):
```bash
curl http://localhost/status?full
```

## VALIDATION CHECKLIST

After applying changes:
- [ ] Verify pm = dynamic in config
- [ ] Confirm pm.max_children = 60
- [ ] See 15+ workers running immediately
- [ ] Check load average drops within 15-30 minutes
- [ ] Test page load times improved
- [ ] Monitor for 1 hour to confirm stability

## ADDITIONAL TUNING

### PHP OPcache (Already Enabled):
```ini
opcache.enable=1
opcache.memory_consumption=256
opcache.interned_strings_buffer=16
opcache.max_accelerated_files=10000
opcache.revalidate_freq=2
```

### PHP-FPM Slow Log (for debugging):
```ini
slowlog = /home/pim/logs/php-fpm-slow.log
request_slowlog_timeout = 10s
```

## ROLLBACK PROCEDURE

If issues occur:
```bash
# Revert to original settings via WHM
WHM → MultiPHP Manager → FPM Settings
Set pm = ondemand
Set pm.max_children = 25

# Or restart service
sudo systemctl restart ea-php83-php-fpm
```

## NEXT STEPS

1. **IMMEDIATE**: Change pm=ondemand to pm=dynamic via WHM
2. **IMMEDIATE**: Increase pm.max_children to 60
3. **WAIT 30 MIN**: Monitor load average and worker count
4. **VALIDATE**: Run daily monitoring script
5. **PROCEED**: Move to Task 2 (MariaDB optimization)

## NOTES

- cPanel manages PHP-FPM configs - use WHM interface
- Direct file edits will be overwritten on cPanel updates
- Test during low-traffic period if possible
- Keep monitoring for 1-2 hours after change

---
**Configuration File**: `/opt/cpanel/ea-php83/root/etc/php-fpm.d/pim.technostationery.com.conf`
**Service**: `ea-php83-php-fpm.service`
**Status**: NEEDS OPTIMIZATION - current config insufficient for load
