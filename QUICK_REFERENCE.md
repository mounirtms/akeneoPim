# Akeneo PIM - Quick Reference Guide
**Last Updated:** 2026-05-01  
**Status:** ✅ Production Ready

---

## 🚀 Instant Access

### Login
```
URL:      https://pim.technostationery.com
Username: testfix
Password: Admin@123
```

---

## ⚡ Essential Commands

### Health Check (5 seconds)
```bash
bash scripts/testing/health-check.sh
```

### Full System Test (30 seconds)
```bash
bash scripts/testing/stability-test.sh
```

### Cache Management
```bash
# Rebuild cache
bash scripts/maintenance/cache-manager.sh rebuild prod

# Clear all caches
bash scripts/maintenance/cache-manager.sh full

# Show cache stats
bash scripts/maintenance/cache-manager.sh stats
```

### Emergency Fix
```bash
bash scripts/utilities/quick-fix.sh
```

---

## 📁 Key Files

| File | Location | Purpose |
|------|----------|---------|
| **Credentials** | `config/credentials.vault.txt` | All login credentials |
| **Quick Reference** | `QUICK_REFERENCE.md` | This file |
| **Full Documentation** | `README.md` | Complete user guide |
| **Technical Report** | `CONSOLIDATION_COMPLETE_20260501.md` | Full session report |
| **Executive Summary** | `EXECUTIVE_SUMMARY_20260501.md` | High-level overview |

---

## 🛠️ Script Locations

### Testing
- `scripts/testing/health-check.sh` - Quick diagnostics
- `scripts/testing/stability-test.sh` - Comprehensive tests

### Maintenance
- `scripts/maintenance/cache-manager.sh` - Cache operations

### Utilities
- `scripts/utilities/build.sh` - Full build
- `scripts/utilities/warmup.sh` - Cache warmup
- `scripts/utilities/permissions.sh` - Fix permissions
- `scripts/utilities/quick-fix.sh` - Emergency fixes

---

## 📊 System Status

**All Green:** ✅ Login, Database, Cache, Redis, Elasticsearch, Assets

**Test Pass Rate:** 93%

**Performance:** < 3 second page load

---

## 🆘 Common Issues

### Login Not Working
```bash
# Create new admin user
php bin/console pim:user:create testuser Admin@123 \
  testuser@test.com Test User en_US --admin -n --env=prod
```

### Assets Not Loading
```bash
bash scripts/utilities/quick-fix.sh
```

### Cache Problems
```bash
bash scripts/maintenance/cache-manager.sh rebuild prod
```

---

## 📞 Support

**Technical Lead:** mounir.ab@techno-dz.com  
**System Admin:** khaled.ke@techno-dz.com

**Logs:** `var/logs/prod.log`

---

**Print this page for quick access!**
