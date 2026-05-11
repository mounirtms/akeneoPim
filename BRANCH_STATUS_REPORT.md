# 🌿 GIT BRANCH STATUS ANALYSIS

## Production Branches

### `main` (ORIGIN)
- Last Commit: `063cd6a` - QUICK REFERENCE doc
- Age: ~9 days
- Status: ⚠️ **OUTDATED** - Does not include recovery work
- Action: **NEEDS UPDATE** - Should be reset to working state

### `pimAkeno` (BACKUP - LAST GOOD STATE)
- Last Commit: `9ceeb11` - ✅ RECOVERY COMPLETE (9,538 products restored)
- Previous: `0e8a247` - "tunings to revert back in time"
- Status: ✅ **STABLE** - Last confirmed working state
- Action: **USE AS BASELINE** for recovery

### `recovery-testing-phase3-20260506_091124` (CURRENT)
- Last Commit: `c9a33d5` - CSS path + form-config-provider fix
- Status: 🔄 **TESTING** - Most recent changes
- Issue: Website still showing 404 errors
- Action: **FIX OR REVERT**

---

## Recovery Branches

### `backlastchanges` (SNAPSHOT)
- Last Commit: `5a98ea6` - Production build cleanup
- Purpose: ❓ Unclear - appears to be old snapshot
- Status: ⚠️ STALE
- Action: Review & document purpose or archive

### `backup-broken-state-20260506_085935`
- Last Commit: `ad77dc9` - COMPREHENSIVE RECOVERY PACKAGE
- Purpose: Backup before recovery execution
- Status: ℹ️ ARCHIVE

### `pimAkeno-backup` (TAG)
- Commit: `fe1f7f3`
- Purpose: Backup before critical changes
- Status: ℹ️ ARCHIVE

---

## Feature Branches

### `feature/system-improvements-clean`
- Last Commit: `fb888e9` - Merge from main
- Status: ⚠️ STALE - Last activity May 1
- Action: Review changes & decide: merge or delete

### `fix/akeneo-default-ui`
- Last Commit: `af1488d` - Single commit: "copilot"
- Status: ❓ UNCLEAR - Minimal work
- Action: Review or delete

---

## Archive Branches

### Local Only (Not on Remote):
- `oldbranch`
- `oldbranch-clean`
- `oldbranch-current-state`

---

## 📊 Branch Recommendation Matrix

| Branch | Keep | Action | Reason |
|--------|------|--------|--------|
| `main` | ✅ | Reset to `pimAkeno` | Production source |
| `pimAkeno` | ✅ | Mark as stable | Known good state |
| `recovery-testing-phase3-*` | ❓ | Fix or revert | Currently broken |
| `backlastchanges` | ❓ | Document or delete | Unclear purpose |
| `feature/system-improvements-clean` | ❓ | Review & merge/delete | Check changes |
| `fix/akeneo-default-ui` | ❌ | Delete | Minimal content |
| `backup-broken-state-*` | ❌ | Delete | Archive, then delete |
| `pimAkeno-backup` | ❌ | Delete | Has pimAkeno already |
| Old branches | ❌ | Delete | Historical only |

---

## Critical Path Forward

### IMMEDIATE (Do Now):
```bash
# 1. Backup current state
git checkout recovery-testing-phase3-20260506_091124
git log --oneline -1 > /tmp/current_state.txt

# 2. Reset main to last known good
git checkout main
git reset --hard pimAkeno
git push --force-with-lease origin main

# 3. Verify recovery branch against main
git diff main..recovery-testing-phase3-20260506_091124 --stat
```

### SHORT TERM (Next Steps):
```bash
# 4. Clean up branches
git branch -d oldbranch oldbranch-clean oldbranch-current-state
git push origin --delete pimAkeno-backup  # if remote

# 5. Keep only essential branches
# - main (production)
# - pimAkeno (backup/stable)
# - recovery-testing-* (current work)
```

### MEDIUM TERM (Within 24h):
```bash
# 6. Merge recovery fixes into main (after verification)
git checkout main
git merge --no-ff recovery-testing-phase3-20260506_091124 -m "Fix: Complete Akeneo recovery"
git tag -a v1.0-stable -m "Stable recovery version"
git push origin main --tags
```

