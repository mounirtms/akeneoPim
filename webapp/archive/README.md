# Webapp Directory Structure

## Current Structure

```
webapp/
├── docs/                          # Current documentation (KEEP)
│   ├── CREDENTIALS_AND_QUICK_REFERENCE.md  # Master credentials & quick reference
│   ├── PRODUCTION_STABILITY_FIX_20260429.md # Latest production fixes
│   └── COMPLETE_DEPLOYMENT_GUIDE.md        # Full deployment guide
│
├── logs/                          # Application logs
│   └── *.log                      # Recent log files
│
├── archive/                       # Old files (can be deleted if needed)
│   ├── 2026-04-audits/           # Old audit reports
│   ├── 2026-04-reports/          # Old status reports
│   └── 2026-04-scripts/          # Old scripts
│
└── node_modules/                  # Test dependencies (Playwright)
```

## What Was Cleaned

- ✅ 200+ old audit files moved to archive
- ✅ Old reports and summaries archived
- ✅ Legacy scripts archived
- ✅ Log files consolidated in logs/ directory
- ✅ Current documentation centralized in docs/

## What to Keep

Only the files in `webapp/docs/` are actively maintained:
1. **CREDENTIALS_AND_QUICK_REFERENCE.md** - System access, commands, troubleshooting
2. **PRODUCTION_STABILITY_FIX_20260429.md** - Details of all production fixes
3. **COMPLETE_DEPLOYMENT_GUIDE.md** - Full deployment instructions

All other documentation is in `archive/` and can be safely deleted to save space.
