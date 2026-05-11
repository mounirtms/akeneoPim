#!/bin/bash
set -e

AUDIT_FILE="/home/pim/public_html/CRITICAL_AUDIT_FULL_$(date +%Y%m%d_%H%M%S).md"

cat > "$AUDIT_FILE" << 'EOFAUDIT'
# 🚨 AKENEO PIM - CRITICAL AUDIT & RECOVERY PLAN

**Date:** $(date)
**Status:** PLATFORM COMPROMISED - DATA LOSS SUSPECTED
**Priority:** CRITICAL

---

## 🔥 CRITICAL SITUATION

Platform is currently non-functional:
- ❌ Catalog data missing/corrupted
- ❌ Product images lost
- ❌ System in broken state
- ⚠️ Need to restore to working state from 2 weeks ago

---

## 📊 CURRENT STATE ANALYSIS

### Git History Analysis
EOFAUDIT

echo "Analyzing git history..." | tee -a "$AUDIT_FILE"

# Get commits from last 30 days
git log --since="30 days ago" --oneline --decorate --all >> "$AUDIT_FILE" 2>&1

cat >> "$AUDIT_FILE" << 'EOFAUDIT'

### Branch Status
EOFAUDIT

git branch -a >> "$AUDIT_FILE" 2>&1

cat >> "$AUDIT_FILE" << 'EOFAUDIT'

### Recent Changes (Last 14 days)
EOFAUDIT

git log --since="14 days ago" --pretty=format:"%h - %an, %ar : %s" >> "$AUDIT_FILE" 2>&1

cat >> "$AUDIT_FILE" << 'EOFAUDIT'

---

## 🗄️ DATABASE STATUS

### Database Size & Tables
EOFAUDIT

mariadb -u pim_ntdbusr24 -p'PIM2024Secure!' -h 127.0.0.1 -P 3307 --ssl=0 pim_dBT8x12y22 -e "
SELECT 
  table_name, 
  ROUND(((data_length + index_length) / 1024 / 1024), 2) AS 'Size (MB)',
  table_rows
FROM information_schema.TABLES 
WHERE table_schema = 'pim_dBT8x12y22'
ORDER BY (data_length + index_length) DESC
LIMIT 20;" 2>&1 >> "$AUDIT_FILE" || echo "Database query failed" >> "$AUDIT_FILE"

cat >> "$AUDIT_FILE" << 'EOFAUDIT'

### Product Count
EOFAUDIT

mariadb -u pim_ntdbusr24 -p'PIM2024Secure!' -h 127.0.0.1 -P 3307 --ssl=0 pim_dBT8x12y22 -e "
SELECT 'Products' as Type, COUNT(*) as Count FROM pim_catalog_product
UNION ALL
SELECT 'Categories', COUNT(*) FROM pim_catalog_category
UNION ALL
SELECT 'Attributes', COUNT(*) FROM pim_catalog_attribute
UNION ALL
SELECT 'Families', COUNT(*) FROM pim_catalog_family;" 2>&1 >> "$AUDIT_FILE" || echo "Product count query failed" >> "$AUDIT_FILE"

cat >> "$AUDIT_FILE" << 'EOFAUDIT'

---

## 📁 FILE SYSTEM STATUS

### Critical Directories
EOFAUDIT

echo "Checking directory sizes..." | tee -a "$AUDIT_FILE"
du -sh public/media 2>/dev/null >> "$AUDIT_FILE" || echo "Media directory size check failed" >> "$AUDIT_FILE"
du -sh var/file_storage 2>/dev/null >> "$AUDIT_FILE" || echo "File storage check failed" >> "$AUDIT_FILE"
du -sh uploads 2>/dev/null >> "$AUDIT_FILE" || echo "Uploads check failed" >> "$AUDIT_FILE"

cat >> "$AUDIT_FILE" << 'EOFAUDIT'

### Media Files Count
EOFAUDIT

find public/media -type f 2>/dev/null | wc -l | xargs -I {} echo "Media files: {}" >> "$AUDIT_FILE"
find var/file_storage -type f 2>/dev/null | wc -l | xargs -I {} echo "Storage files: {}" >> "$AUDIT_FILE"

cat >> "$AUDIT_FILE" << 'EOFAUDIT'

### Recent File Modifications
EOFAUDIT

find . -type f -mtime -14 -not -path "./.git/*" -not -path "./vendor/*" -exec ls -lh {} \; 2>/dev/null | head -30 >> "$AUDIT_FILE"

cat >> "$AUDIT_FILE" << 'EOFAUDIT'

---

## 🔍 IDENTIFYING WORKING STATE (2 WEEKS AGO)

### Commits from 2 weeks ago
EOFAUDIT

git log --since="14 days ago" --until="13 days ago" --pretty=format:"%H - %ai - %s" >> "$AUDIT_FILE" 2>&1

cat >> "$AUDIT_FILE" << 'EOFAUDIT'

### Available Backups
EOFAUDIT

ls -lh /home/pim/backups/ 2>/dev/null >> "$AUDIT_FILE" || echo "No backups directory found" >> "$AUDIT_FILE"
ls -lh backups/ 2>/dev/null >> "$AUDIT_FILE" || echo "No local backups found" >> "$AUDIT_FILE"

cat >> "$AUDIT_FILE" << 'EOFAUDIT'

---

## 📋 CONFIGURATION FILES STATUS

### Current .env
EOFAUDIT

cat .env | grep -v "PASSWORD" | grep -v "SECRET" >> "$AUDIT_FILE" 2>&1

cat >> "$AUDIT_FILE" << 'EOFAUDIT'

### Symfony Version
EOFAUDIT

php bin/console --version 2>&1 >> "$AUDIT_FILE" || echo "Symfony console not working" >> "$AUDIT_FILE"

cat >> "$AUDIT_FILE" << 'EOFAUDIT'

---

## 🔧 CURRENT ISSUES DETECTED

EOFAUDIT

echo "### Frontend Assets" >> "$AUDIT_FILE"
test -f "public/bundles/pimui/manifest.json" && echo "✓ manifest.json exists" >> "$AUDIT_FILE" || echo "✗ manifest.json MISSING" >> "$AUDIT_FILE"
test -f "public/css/pim.css" && echo "✓ pim.css exists" >> "$AUDIT_FILE" || echo "✗ pim.css MISSING" >> "$AUDIT_FILE"
test -f "public/js/extensions.json" && echo "✓ extensions.json exists" >> "$AUDIT_FILE" || echo "✗ extensions.json MISSING" >> "$AUDIT_FILE"

cat >> "$AUDIT_FILE" << 'EOFAUDIT'

---

## 🎯 RECOVERY PLAN OPTIONS

### Option 1: Git Rollback (RECOMMENDED)
Find stable commit from 2 weeks ago and rollback

**Steps:**
1. Identify stable commit hash from git log above
2. Create backup branch of current state
3. Checkout stable commit
4. Test system functionality
5. If working, create new branch from stable state

**Commands:**
```bash
# Backup current state
git branch backup-broken-state-$(date +%Y%m%d)
git add -A
git commit -m "Backup before rollback"

# Find stable commit (example: abc1234)
git log --since="14 days ago" --until="13 days ago" --oneline

# Rollback to stable commit
git checkout <STABLE_COMMIT_HASH>

# Test system
# If working, create new branch
git checkout -b recovery-from-stable
```

### Option 2: Database Restore
Restore database from backup

**Requirements:**
- Database backup file from 2 weeks ago
- Location: Check /home/pim/backups/ or server backups

**Steps:**
1. Locate database backup file
2. Create current database backup
3. Restore old database
4. Test system

### Option 3: Selective File Restore
Restore only critical files from git history

**Files to restore:**
- public/media/* (product images)
- Database export
- .env configuration
- Custom modules/extensions

---

## 📊 COMPARISON ANALYSIS

### Git Diff Analysis (Current vs 2 weeks ago)
EOFAUDIT

STABLE_COMMIT=$(git log --since="14 days ago" --until="13 days ago" --pretty=format:"%H" | head -1)
if [ ! -z "$STABLE_COMMIT" ]; then
  echo "Comparing with commit: $STABLE_COMMIT" >> "$AUDIT_FILE"
  git diff --stat "$STABLE_COMMIT" HEAD >> "$AUDIT_FILE" 2>&1 || echo "Diff failed" >> "$AUDIT_FILE"
else
  echo "Could not find stable commit from 2 weeks ago" >> "$AUDIT_FILE"
fi

cat >> "$AUDIT_FILE" << 'EOFAUDIT'

---

## 🚨 IMMEDIATE ACTIONS REQUIRED

### Priority 1: Backup Current State (CRITICAL)
```bash
# Create full backup before any changes
cd /home/pim/public_html
tar -czf /home/pim/backups/emergency_backup_$(date +%Y%m%d_%H%M%S).tar.gz \
  --exclude='./vendor' \
  --exclude='./node_modules' \
  --exclude='./.git' \
  .

# Backup database
mysqldump -u pim_ntdbusr24 -p'PIM2024Secure!' -h 127.0.0.1 -P 3307 --ssl=0 \
  pim_dBT8x12y22 > /home/pim/backups/emergency_db_$(date +%Y%m%d_%H%M%S).sql
```

### Priority 2: Identify Stable Commit
Review git log above and identify commit hash from 2 weeks ago when system was working

### Priority 3: Test Rollback in Safe Environment
```bash
# Create test branch
git checkout -b test-rollback-$(date +%Y%m%d)

# Rollback to stable commit
git reset --hard <STABLE_COMMIT_HASH>

# Test system
# - Check login works
# - Check products visible
# - Check images loading
```

---

## 📝 DETAILED RECOVERY STEPS

### Phase 1: Preparation (15 min)
1. ✅ Create emergency backups (files + database)
2. ✅ Document current state
3. ✅ Identify stable commit hash
4. ✅ Review what changed between stable and broken state

### Phase 2: Rollback Execution (30 min)
1. Create backup branch
2. Checkout stable commit
3. Verify database compatibility
4. Test critical functionality
5. Clear caches
6. Regenerate assets if needed

### Phase 3: Verification (30 min)
1. Test login
2. Verify product catalog
3. Check image loading
4. Test product creation
5. Verify API endpoints
6. Check Elasticsearch index

### Phase 4: Data Recovery (if needed)
1. Compare database states
2. Identify missing data
3. Restore from backups
4. Verify data integrity

---

## 📞 NEXT STEPS

1. **IMMEDIATELY**: Review this audit report
2. **IMMEDIATELY**: Create emergency backups (see Priority 1 above)
3. **URGENT**: Identify stable commit from 2 weeks ago
4. **URGENT**: Execute rollback plan
5. **FOLLOW-UP**: Verify system functionality
6. **FOLLOW-UP**: Document what went wrong

---

## ⚠️ WARNINGS

- ❌ DO NOT delete any files until backups are complete
- ❌ DO NOT run cleanup scripts until recovery is complete
- ❌ DO NOT make new commits until stable state is restored
- ✅ DO create backups before ANY changes
- ✅ DO document every step taken
- ✅ DO test in isolated environment first

---

**Audit completed:** $(date)
**Report location:** $AUDIT_FILE
**Status:** Ready for recovery decision

EOFAUDIT

echo "$AUDIT_FILE"

