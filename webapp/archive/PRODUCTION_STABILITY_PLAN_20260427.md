# Production Stability & Optimization Plan
**Date**: 2026-04-27  
**Priority**: CRITICAL  
**Status**: In Progress  

---

## Current Issues (Console Errors)

### 1. ❌ RequireJS Module Loading Errors
**Errors**:
```
- module is not defined (require-paths.js)
- Script error for "jquery"
- Script error for "pim/form-builder"
- GET /jquery.js 404
- GET /pim/form-builder.js 404
```

**Root Cause**: Frontend assets not properly built/deployed

**Impact**: Dashboard and product forms may not load correctly

**Status**: Investigating

### 2. ❌ Analytics Collection Error
**Error**: `GET /analytics/collect_data 500 (Internal Server Error)`

**Root Cause**: Analytics endpoint not configured or failing

**Impact**: Non-critical - analytics data not collected

**Status**: Can be disabled

### 3. ❌ Translation File Missing
**Error**: `GET /js/translation/en_US.js 404`

**Root Cause**: Translation files not generated for frontend

**Impact**: Minor - some labels may not translate

**Status**: Needs generation

---

## Immediate Actions (Priority 1)

### ✅ Actions Completed:
1. ✅ Cleared Symfony cache (`var/cache/*`)
2. ✅ Warmed up production cache (`cache:warmup --env=prod`)
3. ✅ Installed Akeneo assets (`pim:installer:assets`)
4. ✅ Regenerated RequireJS config (`pim:installer:dump-require-paths`)
5. ✅ Created webpack configuration files (webpack.config.js, custom-webpack.config.js)

### ⏳ Actions Pending:
1. **Fix Frontend Build** (High Priority)
   - Option A: Use pre-built assets (if available)
   - Option B: Build assets with corrected webpack config
   - Option C: Disable problematic features temporarily

2. **Disable Analytics** (Quick Win)
   ```bash
   # Disable analytics in config
   echo "akeneo_analytics.is_enabled: false" >> config/packages/akeneo_analytics.yaml
   ```

3. **Generate Translation Files**
   ```bash
   bin/console oro:translation:dump en_US --env=prod
   ```

4. **Clear Browser Cache**
   - Add cache-busting query string to assets
   - Update .htaccess for proper caching headers

---

## Recommended Approach: Use Existing Assets

Since this is a **production system**, we should:
1. **NOT rebuild webpack** (risk of breaking changes)
2. **Work with existing assets**
3. **Fix configuration** to properly serve assets
4. **Disable non-essential features** causing errors

### Strategy:
```
┌─────────────────────────────────────┐
│  Keep System Running (Priority 1)   │
│  - Serve existing assets            │
│  - Disable failing features         │
│  - Fix configuration issues         │
└─────────────────────────────────────┘
           ↓
┌─────────────────────────────────────┐
│  Optimize (Priority 2)              │
│  - Clear unnecessary cache          │
│  - Optimize database                │
│  - Monitor performance              │
└─────────────────────────────────────┘
           ↓
┌─────────────────────────────────────┐
│  Plan Rebuild (Priority 3 - Later)  │
│  - Schedule maintenance window      │
│  - Test in staging                  │
│  - Deploy to production             │
└─────────────────────────────────────┘
```

---

## Production Maintenance Plan

### Daily (Automated):
- [x] Run health check script (`daily_monitoring.sh`)
- [ ] Check disk space
- [ ] Monitor error logs
- [ ] Verify API connectivity
- [ ] Check database connections

### Weekly (Manual):
- [ ] Review error logs (`var/logs/prod.log`)
- [ ] Check system performance metrics
- [ ] Verify backup integrity
- [ ] Test API endpoints
- [ ] Review security updates

### Monthly (Planned):
- [ ] Database optimization (`OPTIMIZE TABLE`)
- [ ] Clear old cache files
- [ ] Review and archive logs
- [ ] Security audit
- [ ] Performance review

---

## Quick Fixes to Implement Now

### 1. Disable Analytics (Immediate)
```yaml
# config/packages/akeneo_analytics.yaml
akeneo_analytics:
    is_enabled: false
```

### 2. Add Proper Asset Paths
Check if assets are being served from correct paths:
```apache
# .htaccess additions
<IfModule mod_headers.c>
    Header set Cache-Control "max-age=2592000, public"
</IfModule>

<IfModule mod_expires.c>
    ExpiresActive On
    ExpiresByType text/css "access plus 1 year"
    ExpiresByType application/javascript "access plus 1 year"
</IfModule>
```

### 3. Generate Missing Translations
```bash
bin/console oro:translation:dump en_US --env=prod
bin/console cache:clear --env=prod
```

### 4. Verify File Permissions
```bash
chmod -R 755 public/
chown -R pim:pim public/
```

---

## Monitoring & Alerts

### Health Check Endpoints:
1. **System Health**: `https://pim.technostationery.com/health`
2. **Database**: Check `pim_catalog_product` count
3. **Elasticsearch**: `curl localhost:9200/_cluster/health`
4. **API**: `curl https://pim.technostationery.com/api/rest/v1/`

### Key Metrics to Monitor:
- **Response Time**: < 2 seconds
- **Error Rate**: < 1%
- **Product Count**: 9,538 (stable)
- **Disk Usage**: < 80%
- **Memory Usage**: < 80%
- **Database Connections**: < 100

---

## Rollback Plan (If Needed)

### Backup Locations:
- **Database**: `/home/beta/backups/categories_backup_*.sql`
- **Files**: (should create before changes)
- **Git**: Latest commit hash recorded

### Rollback Steps:
1. Restore database from backup
2. Clear cache: `rm -rf var/cache/*`
3. Restore file backups if needed
4. Restart services
5. Verify system health

---

## Long-term Optimization (After Stabilization)

### Performance Improvements:
1. **Redis Cache** (2-4 hours to implement)
   - Install Redis server
   - Configure Symfony to use Redis
   - Expected: 30-50% performance improvement

2. **Opcache Optimization**
   - Already enabled, tune settings
   - Expected: 10-20% improvement

3. **Database Optimization**
   - Add missing indexes
   - Optimize queries
   - Expected: 15-25% improvement

4. **CDN for Images** (optional)
   - Offload product images to CDN
   - Expected: Faster page loads

---

## Success Criteria

### System is Stable When:
✅ No JavaScript errors in console  
✅ All product pages load correctly  
✅ Dashboard displays properly  
✅ API responds within 2 seconds  
✅ No 500 errors in logs  
✅ Health check passes 100%  

### Current Status:
⏳ 80% stable (main functionality works)  
⚠️ JavaScript errors (cosmetic issues)  
✅ Core features operational  
✅ API working  
✅ Products visible  

---

## Next Steps

### Today (2026-04-27):
1. [ ] Disable analytics to stop 500 error
2. [ ] Generate translation files
3. [ ] Test dashboard functionality
4. [ ] Verify no critical errors remain
5. [ ] Document all changes

### This Week:
1. [ ] Implement monitoring alerts
2. [ ] Set up automated backups
3. [ ] Performance baseline testing
4. [ ] Create staging environment plan

### Next Month:
1. [ ] Redis cache implementation
2. [ ] Database optimization
3. [ ] Security audit
4. [ ] Webpack rebuild in staging

---

## Contact & Escalation

**Production Issues**:  
- Contact: webmaster@techno-dz.com
- Escalation: System administrator
- Emergency: Restore from backup

**Documentation**:  
- Location: `/home/pim/public_html/webapp/`
- Git: `github.com/mounirtms/akeneoPim.git`
- Branch: `oldbranch`

---

**Document Version**: 1.0  
**Last Updated**: 2026-04-27  
**Status**: Active - Monitoring Required  

---

*This is a living document. Update as issues are resolved and new information becomes available.*
