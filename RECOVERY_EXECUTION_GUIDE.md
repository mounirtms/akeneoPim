# 🚀 AKENEO PIM RECOVERY - EXECUTION GUIDE

**Date:** May 6, 2026  
**Version:** 1.0  
**Status:** READY TO EXECUTE

---

## 📋 QUICK START

### Prerequisites Checklist
Before starting the recovery process, ensure:

- [ ] SSH access to server confirmed
- [ ] Database credentials verified (`akeneo_pim` / `akeneo_pim`)
- [ ] Maintenance mode enabled (optional but recommended)
- [ ] All users notified of downtime
- [ ] At least 20 GB free disk space available
- [ ] Estimated downtime communicated: **2-3 hours**

### Quick Execution Commands

```bash
# Navigate to project directory
cd /home/pim/public_html

# Review the comprehensive analysis
less COMPREHENSIVE_SITUATION_ANALYSIS.md

# Execute automated recovery
./execute_recovery.sh

# After recovery, run tests
./test_recovery.sh

# Clean up old files (optional, after testing)
./cleanup_old_audits.sh
```

---

## 📚 AVAILABLE DOCUMENTATION

### 1. **COMPREHENSIVE_SITUATION_ANALYSIS.md** (This file's companion)
- **Purpose:** Complete analysis of current situation
- **Contains:**
  - Detailed timeline of what happened
  - Comparison of healthy vs broken state
  - 7 critical issues identified
  - Available backups inventory
  - Three recovery options with risk assessment
  - Detailed step-by-step recovery procedures
  - Post-recovery checklist

### 2. **AKENEO_TECHNICAL_REPORT.md** (Original technical analysis)
- **Purpose:** Deep technical dive into system configuration
- **Contains:**
  - System environment details
  - PHP version conflicts
  - Database configuration issues
  - Elasticsearch status
  - Authentication system analysis
  - Asset pipeline status
  - Git history from last 3 weeks

### 3. **CRITICAL_AUDIT_FULL_20260506_062034.md** (Latest audit)
- **Purpose:** Current state snapshot
- **Contains:**
  - Git history analysis
  - Directory size analysis
  - Backup availability verification
  - Configuration file status

---

## 🔧 RECOVERY SCRIPTS

### 1. **execute_recovery.sh** (Main Recovery Script)

**What it does:**
- Creates emergency backups of current state
- Restores database from April 26, 2026
- Recovers configuration files from stable git commit
- Resets all caches (Symfony, OPcache)
- Reindexes Elasticsearch
- Commits recovery changes to git

**Estimated time:** 2-3 hours

**Usage:**
```bash
cd /home/pim/public_html
./execute_recovery.sh
```

**Output:**
- Log file: `recovery_log_YYYYMMDD_HHMMSS.txt`
- Backup files: `/home/pim/backups/emergency_*`
- Git branch: `backup-broken-state-YYYYMMDD_HHMMSS`
- Git tag: `restore-april26-YYYYMMDD_HHMMSS`

### 2. **test_recovery.sh** (Testing Suite)

**What it does:**
- Tests HTTP endpoints (login, CSS, JS)
- Tests database connectivity and data
- Tests Elasticsearch indices
- Verifies critical files exist
- Checks permissions
- Validates configuration

**Estimated time:** 5 minutes

**Usage:**
```bash
cd /home/pim/public_html
./test_recovery.sh
```

**Output:**
- Test log: `test_recovery_YYYYMMDD_HHMMSS.log`
- Pass/Fail summary
- Exit codes:
  - `0` = All tests passed
  - `1` = Minor issues (warnings)
  - `2` = Critical failures

### 3. **cleanup_old_audits.sh** (Cleanup Script)

**What it does:**
- Archives old audit files
- Removes temporary files
- Compresses old logs
- Cleans webapp documentation

**Estimated time:** 2 minutes

**Usage:**
```bash
cd /home/pim/public_html
./cleanup_old_audits.sh
```

**Output:**
- Archive: `archived_audits_YYYYMMDD.tar.gz`

---

## 📊 STEP-BY-STEP EXECUTION

### Phase 1: Pre-Execution Review (15 minutes)

```bash
# 1. Read the comprehensive analysis
cd /home/pim/public_html
less COMPREHENSIVE_SITUATION_ANALYSIS.md

# 2. Verify backups exist
ls -lh /home/pim/backups/ | grep "akeneo_backup_20260426"
ls -lh /home/pim/backups/ | grep "akeneo_files_20260426"

# 3. Check disk space
df -h /home/pim/backups
df -h /home/pim/public_html

# 4. Test database connection
mysql -u akeneo_pim -p'akeneo_pim' -h 127.0.0.1 -P 3307 --ssl=0 -e "SELECT 1"

# 5. Check current git status
git status
git branch -a
```

### Phase 2: Execute Recovery (2-3 hours)

```bash
cd /home/pim/public_html

# Run the automated recovery script
./execute_recovery.sh
```

**What happens during execution:**

1. **Pre-flight checks** (1 min)
   - Verifies backup files exist
   - Checks disk space
   - Tests database connection
   - Validates git repository

2. **Emergency backup** (15 min)
   - Backs up current files to `/home/pim/backups/emergency_files_*.tar.gz`
   - Backs up current database to `/home/pim/backups/current_broken_*.sql.gz`
   - Creates git branch `backup-broken-state-*`

3. **Database restoration** (20 min)
   - Extracts backup from April 26
   - Drops and recreates database
   - Imports backup
   - Verifies user/product/category counts

4. **File recovery** (30 min)
   - Restores config files from stable git commit (April 22)
   - Updates .env for current environment
   - Creates .env.local with correct password
   - Creates .env.local.php with force override

5. **Cache & index reset** (30 min)
   - Resets OPcache
   - Clears Symfony cache
   - Reinstalls bundle assets
   - Resets Elasticsearch indices
   - **Reindexes products** (this takes 10-20 minutes)

6. **Verification** (15 min)
   - Tests HTTP endpoints
   - Checks database
   - Verifies Elasticsearch
   - Tests file permissions

7. **Commit recovery** (10 min)
   - Commits all changes to git
   - Creates tag for restore point

**Monitor the script output:**
- Green ✓ = Success
- Red ✗ = Error (script will exit)
- Yellow ⚠ = Warning (continues)

**If script fails:**
1. Check the log file: `recovery_log_*.txt`
2. Review error messages
3. Restore from backup if needed:
   ```bash
   git checkout backup-broken-state-YYYYMMDD_HHMMSS
   ```

### Phase 3: Testing (15 minutes)

```bash
cd /home/pim/public_html

# Run automated tests
./test_recovery.sh
```

**Review test results:**
- Look for any FAIL results
- Warnings are usually acceptable
- Check the test log for details

**Manual testing (REQUIRED):**

1. **Test Login:**
   ```bash
   # Open in browser
   https://pim.technostationery.com/user/login
   ```
   - Try logging in with credentials from April 26 backup
   - Default was likely: `admin` / `admin` or `Admin123!`

2. **Test Product Catalog:**
   - Navigate to Products menu
   - Verify products are visible
   - Check product count matches expectations

3. **Test Images:**
   - Open a product with images
   - Verify images load correctly
   - Check thumbnails work

4. **Test Product Editing:**
   - Try editing a product
   - Save changes
   - Verify changes persist

5. **Test API (if needed):**
   ```bash
   curl -u admin:password https://pim.technostationery.com/api/rest/v1/products?limit=10
   ```

### Phase 4: Cleanup (Optional, 5 minutes)

**Only after confirming recovery is successful:**

```bash
cd /home/pim/public_html

# Archive old audit files
./cleanup_old_audits.sh

# Review what was archived
ls -lh archived_audits_*.tar.gz
```

---

## 🚨 TROUBLESHOOTING

### Problem: Script fails during database restoration

**Solution:**
1. Check database credentials are correct
2. Verify MariaDB is running on port 3307
3. Ensure backup file is not corrupted:
   ```bash
   gunzip -t /home/pim/backups/akeneo_backup_20260426_020001.sql.gz
   ```

### Problem: Elasticsearch reindexing fails

**Solution:**
1. Check Elasticsearch is running:
   ```bash
   curl http://localhost:9200
   ```
2. Manually reset and reindex:
   ```bash
   php bin/console akeneo:elasticsearch:reset-indexes --env=prod -n
   php bin/console pim:product:index --env=prod -n
   ```

### Problem: Login still doesn't work after recovery

**Solution:**
1. Check error logs:
   ```bash
   tail -100 var/logs/prod.log | grep -i error
   ```
2. Verify session directory is writable:
   ```bash
   ls -ld var/sessions
   chmod 755 var/sessions
   ```
3. Try resetting admin password:
   ```bash
   php bin/console pim:user:create testadmin \
     test@example.com testadmin Admin123! \
     --admin -n
   ```

### Problem: CSS or JS files return 404

**Solution:**
1. Reinstall assets:
   ```bash
   php bin/console pim:installer:assets --symlink --clean --env=prod
   ```
2. Check .htaccess files exist:
   ```bash
   ls -l .htaccess public/.htaccess
   ```

### Problem: Products not visible in catalog

**Solution:**
1. Check Elasticsearch index:
   ```bash
   curl http://localhost:9200/akeneo_pim_product_and_product_model/_count
   ```
2. If count is 0, reindex:
   ```bash
   php bin/console pim:product:index --env=prod -n
   ```

---

## 📞 ROLLBACK PROCEDURE

If recovery fails and you need to restore the broken state:

```bash
cd /home/pim/public_html

# Find your backup branch
git branch | grep backup-broken-state

# Checkout the backup
git checkout backup-broken-state-YYYYMMDD_HHMMSS

# Restore database backup
cd /home/pim/backups
gunzip -c current_broken_YYYYMMDD_HHMMSS.sql.gz | \
  mysql -u akeneo_pim -p'akeneo_pim' -h 127.0.0.1 -P 3307 akeneo_pim

# Clear caches
cd /home/pim/public_html
php -r "opcache_reset();"
php bin/console cache:clear --env=prod
```

---

## ✅ SUCCESS CRITERIA

Recovery is successful when:

1. ✅ Login page loads (HTTP 200)
2. ✅ Can log in with valid credentials
3. ✅ Products visible in catalog
4. ✅ Product count matches expectations (check with DBA)
5. ✅ Images load correctly
6. ✅ Can create/edit products
7. ✅ API endpoints respond (if used)
8. ✅ No critical errors in logs
9. ✅ Elasticsearch has indexed products
10. ✅ All automated tests pass

---

## 📝 POST-RECOVERY TASKS

### Immediate (Day 1)

- [ ] Document any issues encountered during recovery
- [ ] Take screenshots of successful login and product catalog
- [ ] Update team on recovery status
- [ ] Monitor error logs for 24 hours
- [ ] Keep backup files for at least 7 days

### Short Term (Week 1)

- [ ] Review git history to identify root cause of breakage
- [ ] Create post-mortem document
- [ ] Update deployment procedures
- [ ] Add pre-deployment testing checklist
- [ ] Set up automated health checks
- [ ] Configure better backup retention policy

### Medium Term (Month 1)

- [ ] Fix PHP version conflicts (standardize on 8.3)
- [ ] Remove system environment variable override
- [ ] Set up proper OPcache exclusions for .env files
- [ ] Configure monitoring and alerting
- [ ] Implement blue-green deployment strategy
- [ ] Set up staging environment for testing changes
- [ ] Plan Akeneo upgrade to 7.x or 8.x

---

## 📊 RECOVERY METRICS

Track these metrics during recovery:

| Metric | Target | How to Measure |
|--------|--------|----------------|
| **Total Downtime** | < 3 hours | Start to successful login |
| **Database Size** | ~2-3 MB | `ls -lh /home/pim/backups/*.sql.gz` |
| **Product Count** | Check with DBA | `SELECT COUNT(*) FROM pim_catalog_product` |
| **ES Index Count** | Match DB count | `curl localhost:9200/akeneo_pim_product/_count` |
| **Test Success Rate** | > 90% | `./test_recovery.sh` output |
| **Error Log Size** | < 1 MB/day | `ls -lh var/logs/prod.log` |

---

## 🔐 SECURITY NOTES

### Credentials in Scripts

The recovery scripts contain database credentials. After recovery:

1. Review and sanitize all scripts
2. Remove any hardcoded passwords
3. Consider using environment variables
4. Restrict file permissions:
   ```bash
   chmod 700 execute_recovery.sh test_recovery.sh
   ```

### Backup File Security

Backup files contain sensitive data:

1. Store in secure location
2. Set restrictive permissions:
   ```bash
   chmod 600 /home/pim/backups/*.sql.gz
   chmod 600 /home/pim/backups/*.tar.gz
   ```
3. Delete old backups after retention period
4. Consider encrypting backups for long-term storage

---

## 📚 ADDITIONAL RESOURCES

### Configuration Files
- `.env` - Base environment variables
- `.env.local` - Local overrides
- `.env.local.php` - PHP-specific overrides (OPcache workaround)
- `config/packages/security.yml` - Authentication system
- `config/packages/framework.yml` - Symfony framework config

### Key Directories
- `var/cache/` - Symfony cache
- `var/logs/` - Application logs
- `var/sessions/` - Session storage
- `public/bundles/` - Symfony bundle assets
- `public/media/` - Product images

### Useful Commands
```bash
# Clear cache
php bin/console cache:clear --env=prod

# Reindex products
php bin/console pim:product:index --env=prod

# Check Elasticsearch
curl http://localhost:9200/_cat/indices?v

# Test database
php bin/console doctrine:query:sql "SELECT 1"

# Reset OPcache
php -r "opcache_reset();"

# View recent errors
tail -100 var/logs/prod.log | grep ERROR
```

---

## 🎯 FINAL CHECKLIST

Before declaring recovery complete:

- [ ] Automated tests passed (>90% success rate)
- [ ] Manual login test successful
- [ ] Products visible and correct count
- [ ] Images loading properly
- [ ] Can create/edit products
- [ ] No critical errors in logs
- [ ] Elasticsearch indices populated
- [ ] All caches cleared and warmed
- [ ] Recovery documented in git commit
- [ ] Backups verified and secured
- [ ] Team notified of completion
- [ ] Maintenance mode disabled

---

**Good luck with the recovery!** 🚀

For questions or issues during recovery, refer to:
1. `recovery_log_*.txt` - Detailed execution log
2. `test_recovery_*.log` - Test results
3. `COMPREHENSIVE_SITUATION_ANALYSIS.md` - Full analysis
4. `AKENEO_TECHNICAL_REPORT.md` - Technical details

