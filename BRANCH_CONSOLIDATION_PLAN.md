# Branch Consolidation & Cleanup Plan
**Date:** 2026-05-01  
**Status:** Ready for Execution

---

## 🎯 Executive Summary

The repository has 3 main branches with overlapping fixes. This plan consolidates the best changes, eliminates duplicates, and establishes a clean structure.

### Current State
- **main**: Latest stable (58b17f4) - Working login, documentation, utility scripts
- **pimAkeno**: 82 commits ahead, 39 behind - Contains authentication fixes, CSS fixes, loading screen fixes
- **oldbranch**: 7 commits ahead, 4 behind - Contains cache config, service manager scripts

---

## 📋 Cherry-Pick Strategy

### Phase 1: From pimAkeno Branch (Priority Commits)

#### Critical Authentication & UI Fixes
```bash
# These commits fixed fundamental login and UI issues
721bfe8  # fix: Resolve loading screen issue - extensions.json 404 fixed
9eeaad1  # fix: Resolve CSS 404 and rebuild all assets - PARTIAL FIX
a372422  # feat: Fix authentication & implement comprehensive testing
```

#### Platform Stability Commits
```bash
302ad2f  # fix: Phase 1 Critical Fixes Complete - Platform Stabilized
b4cdbe9  # fix: MariaDB audit and instance cleanup - CRITICAL FIX
```

#### Configuration Improvements
```bash
da631fd  # fix: Cloudflare trusted proxy configuration for login
61f91f3  # fix: Cloudflare trusted proxy + admin password reset + env sync
```

### Phase 2: From oldbranch Branch (Operational Tools)

```bash
38ef446  # ✅ STABLE: Akeneo PIM Cache Fixed + 90.5% Test Success
94bf43c  # ✅ COMPLETE: Security + Frontend + Magento Sync Ready
62626f3  # feat: Comprehensive system improvements - monitoring, automation
```

---

## 🗑️ Scripts Cleanup Plan

### Current Situation
- **17 shell scripts** in webapp/ directory
- Many duplicates and outdated scripts
- No clear organization

### Recommended Structure

```
scripts/
├── core/                          # Essential scripts (keep)
│   ├── build.sh                   # Build & deployment
│   ├── warmup.sh                  # Cache warmup
│   ├── permissions.sh             # Fix permissions
│   └── quick-fix.sh               # Emergency fixes
│
├── testing/                       # Consolidated test scripts
│   ├── stability-test.sh          # Master stability test
│   ├── ui-test.sh                 # UI/frontend tests
│   └── health-check.sh            # Quick health check
│
├── maintenance/                   # Maintenance utilities
│   ├── cache-clear.sh            # Cache management
│   ├── service-manager.sh        # Service control
│   └── backup.sh                 # Backup utilities
│
└── monitoring/                    # Monitoring scripts
    ├── check-status.sh           # Status monitoring
    └── performance-monitor.sh    # Performance checks
```

### Scripts to Keep (Consolidate)

**Test Scripts (Merge into 3 files):**
- ✅ `akeneo_stability_tests.sh` → `testing/stability-test.sh`
- ✅ `comprehensive_pim_ui_tests.sh` → `testing/ui-test.sh`
- ✅ `quick_health_check.sh` → `testing/health-check.sh`
- ❌ Delete: `final_stability_test.sh`, `quality_performance_tests.sh` (redundant)

**Utility Scripts:**
- ✅ Keep: `scripts/utilities/build.sh`
- ✅ Keep: `scripts/utilities/warmup.sh`
- ✅ Keep: `scripts/utilities/permissions.sh`
- ✅ Keep: `scripts/utilities/quick-fix.sh`

**Scripts to Delete:**
- ❌ `check_pim_data.sh` (replaced by health-check)
- ❌ `fix_critical_issues.sh` (merged into quick-fix)
- ❌ `fix_css_and_styles.sh` (one-time fix, no longer needed)
- ❌ `comprehensive_test_import.sh` (obsolete)

---

## 🔐 Credentials Consolidation

### Master Credentials File Location
```
/home/pim/public_html/config/credentials.vault.txt
```

### Verified Working Credentials

#### Akeneo PIM Users
| Username | Password | Role | Status | Notes |
|----------|----------|------|--------|-------|
| testfix | Admin@123 | Administrator | ✅ Working | Created 2026-05-01, fully functional |
| testadmin | testpass | Administrator | ⚠️ Verify | Needs verification |
| admin | *needs reset* | Administrator | ❌ Reset Required | Original admin account |
| apiconnector | *needs reset* | User | ❌ Reset Required | API integration account |

#### Database
| Parameter | Value | Status |
|-----------|-------|--------|
| Host | 127.0.0.1 | ✅ |
| Port | 3307 | ✅ |
| Database | akeneo_pim | ✅ |
| Username | akeneo_pim | ✅ |
| Password | akeneo_pim | ✅ |
| Root Password | LXEais3qfmlaMCH3 | ✅ |

#### Magento Admin
| Parameter | Value | Status |
|-----------|-------|--------|
| URL | https://beta.technostationery.com/admin | ⚠️ HTTP 500 |
| Username | bot | ⚠️ |
| Password | @dM1n$#@2o25B0T | ⚠️ |

---

## 📁 Configuration Files Analysis

### Files to Merge from pimAkeno

**Framework Configuration:**
- `config/packages/framework.yml` - Contains Cloudflare proxy settings
- `config/routes.yaml` - Route optimizations

**Keep Changes:**
```yaml
# framework.yml additions
framework:
    trusted_proxies: ['REMOTE_ADDR']
    trusted_headers: ['x-forwarded-for', 'x-forwarded-proto', 'x-forwarded-port']
```

### Files to Merge from oldbranch

**Cache Configuration:**
- `config/packages/cache.yml` - Redis/APCu optimizations

**Doctrine Configuration:**
- `config/packages/doctrine.yml` - Connection pool improvements

**Keep Changes:**
```yaml
# cache.yml additions
framework:
    cache:
        app: cache.adapter.redis
        default_redis_provider: redis://127.0.0.1:6379
```

---

## 🎬 Execution Plan

### Step 1: Backup Current State
```bash
cd /home/pim/public_html
git branch backup-main-$(date +%Y%m%d) main
git tag before-consolidation-$(date +%Y%m%d)
```

### Step 2: Create Working Branch
```bash
git checkout -b consolidation-2026-05-01 main
```

### Step 3: Cherry-Pick from pimAkeno
```bash
# Authentication & UI fixes
git cherry-pick 721bfe8  # Loading screen fix
git cherry-pick 9eeaad1  # CSS 404 fix
git cherry-pick a372422  # Authentication fix

# Configuration improvements
git cherry-pick da631fd  # Cloudflare proxy
git cherry-pick 302ad2f  # Platform stabilization
```

### Step 4: Cherry-Pick from oldbranch
```bash
# Cache & Performance
git cherry-pick 38ef446  # Cache fix
git cherry-pick 94bf43c  # Security & Frontend
```

### Step 5: Manual Configuration Merge
- Merge `framework.yml` changes
- Merge `cache.yml` changes
- Update `routes.yaml` if needed

### Step 6: Scripts Reorganization
```bash
# Create new structure
mkdir -p scripts/{testing,maintenance,monitoring}

# Move and consolidate
mv scripts/utilities/build.sh scripts/core/
# ... (detailed in scripts section)
```

### Step 7: Testing
```bash
# Run stability tests
bash scripts/testing/stability-test.sh

# Verify login
bash scripts/testing/ui-test.sh

# Health check
bash scripts/testing/health-check.sh
```

### Step 8: Documentation Update
- Update README.md with new structure
- Update credentials documentation
- Create migration guide

---

## 🧪 Validation Checklist

- [ ] Login works (testfix / Admin@123)
- [ ] Dashboard loads properly
- [ ] JavaScript libraries load (jQuery, Backbone, etc.)
- [ ] Static assets return HTTP 200
- [ ] Navigation menu functional
- [ ] Product CRUD operations work
- [ ] Cache system operational
- [ ] Database connections stable
- [ ] All tests pass (100% success rate)
- [ ] Page load time < 3 seconds

---

## 📊 Expected Outcomes

### Code Quality
- ✅ Remove ~500+ lines of duplicate code
- ✅ Consolidate 17 scripts into 8 organized scripts
- ✅ Single source of truth for configuration
- ✅ Clear documentation structure

### Performance
- ✅ Faster cache operations (Redis)
- ✅ Optimized database connections
- ✅ Reduced asset load times

### Maintainability
- ✅ Clear script organization
- ✅ Consolidated credentials management
- ✅ Better documentation
- ✅ Easier troubleshooting

---

## 🔄 Rollback Plan

If consolidation causes issues:

```bash
# Return to backup
git checkout backup-main-$(date +%Y%m%d)
git branch -D consolidation-2026-05-01

# Or use tag
git checkout before-consolidation-$(date +%Y%m%d)
```

---

## 📝 Notes

### Key Findings
1. **pimAkeno** has valuable authentication fixes that are NOT in main
2. **oldbranch** has cache optimizations that improve performance
3. Main branch has best documentation and organization
4. Many test scripts are duplicates with minor variations

### Recommendations
1. Execute cherry-picks carefully (test after each)
2. Merge configuration files manually (avoid conflicts)
3. Delete obsolete branches after successful merge
4. Create comprehensive test suite from best scripts
5. Document all credentials in secure location

---

## 🎯 Next Steps After Consolidation

1. **Security Hardening**
   - Reset admin and apiconnector passwords
   - Implement password rotation policy
   - Enable 2FA if available

2. **Performance Optimization**
   - Enable Redis cache fully
   - Configure OPcache
   - Implement CDN for static assets

3. **Monitoring Setup**
   - Configure automated health checks
   - Set up error alerting
   - Performance monitoring dashboard

4. **Backup Strategy**
   - Automated daily backups
   - Disaster recovery testing
   - Off-site backup storage

---

**Created:** 2026-05-01  
**Author:** System Consolidation  
**Status:** Ready for Execution
