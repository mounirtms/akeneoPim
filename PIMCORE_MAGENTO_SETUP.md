# 🚀 Pimcore + Magento 2.4.6 - Complete Setup & Optimization Guide

## Date: November 17, 2025
## Environment: Production Ready

---

## 📋 PHASE 1: PIMCORE INSTALLATION VERIFICATION & FIX

### Step 1.1: Run Health Check
```bash
bash scripts/health-check.sh
```
**Expected:** All green checkmarks, production environment confirmed.

### Step 1.2: Verify Current Status
```bash
# Check Pimcore version
php bin/console --version

# Verify database connection
php bin/console doctrine:database:version

# Check installed bundles
php bin/console debug:container --parameter=kernel.bundles
```

### Step 1.3: Fix Any Outstanding Issues
```bash
# Fix permissions (if needed)
bash scripts/fix-permissions-smart.sh

# Clear and rebuild cache
php bin/console cache:clear --no-warmup
php bin/console cache:warmup

# Rebuild classes
php bin/console pimcore:build:classes

# Install/Update assets
php bin/console assets:install --symlink
php bin/console fos:js-routing:dump
```

### Step 1.4: Create Required Data Classes
```bash
# Ensure Product and Category classes exist
php create_classes_manually.php

# Verify classes
php bin/console pimcore:definition:list
```

---

## 📦 PHASE 2: MAGENTO 2.4.6 OPTIMIZATION

### Step 2.1: Magento Environment Check
Create optimization script for Magento 2.4.6:

```bash
# Run the Magento optimization script
bash scripts/magento-246-optimize.sh
```

### Step 2.2: Key Magento 2.4.6 Optimizations
✅ **Performance:**
- Enable flat catalog (products & categories)
- Configure Redis/Varnish caching
- Enable JavaScript bundling & minification
- Set up image optimization
- Configure MySQL query cache

✅ **Database:**
- Optimize catalog tables
- Clean old logs and reports
- Reindex all indexers
- Clean cache storage

✅ **Configuration:**
- Set production mode
- Disable unnecessary modules
- Configure cron jobs properly
- Set up queue consumers

---

## 🔄 PHASE 3: DATA IMPORT FROM MAGENTO TO PIMCORE

### Step 3.1: Prepare Import Environment
```bash
# Verify CSV file exists
ls -lh products.csv

# Check first few lines
head -20 products.csv

# Count products
wc -l products.csv
```

### Step 3.2: Category Import
```bash
# Import categories first (products depend on them)
php import/import-categories-from-magento.php

# Verify categories imported
php import/check-data.php
```

### Step 3.3: Product Import
```bash
# Start product import
php import/import-products-from-magento.php

# Monitor progress (in separate terminal)
php import/check-import-progress.php

# For detailed import (if needed)
php import/import-products-detailed.php
```

### Step 3.4: Asset Import (Images)
```bash
# Display products with images to verify
php import/display-products-with-images.php

# If assets need setup
php import/setup-complete-product-model.php
```

---

## 🎯 PHASE 4: POST-IMPORT OPTIMIZATION

### Step 4.1: Data Verification
```bash
# Check imported data
php import/check-data.php

# Display products
php import/display-products.php

# Verify image assignments
php import/display-products-with-images.php
```

### Step 4.2: Optimize Pimcore
```bash
# Optimize all data types
php scripts/optimize-all-types.php

# Add predefined properties
php scripts/add-predefined-properties.php

# Rebuild everything
php bin/console pimcore:deployment:classes-rebuild
php bin/console pimcore:thumbnails:optimize
```

### Step 4.3: Final Cache & Performance
```bash
# Clear all caches
bash scripts/clean-cache.sh

# Full rebuild
bash scripts/unified-build.sh

# Fix permissions one final time
bash scripts/fix-permissions-smart.sh
```

---

## 🔍 PHASE 5: VERIFICATION & TESTING

### Step 5.1: System Health Check
```bash
# Run comprehensive health check
bash scripts/health-check.sh

# Check logs for errors
tail -100 var/logs/prod.log
tail -100 var/logs/dev.log
```

### Step 5.2: Verify Data Integrity
```bash
# Count objects in Pimcore
php bin/console pimcore:maintenance:object-count

# Verify relationships
php import/check-data.php
```

### Step 5.3: Performance Testing
```bash
# Monitor CPU/Memory
bash scripts/cpu_monitor.sh &

# Test admin panel load time
curl -w "@-" -o /dev/null -s 'http://localhost/admin/login'
```

---

## 📊 MONITORING & MAINTENANCE

### Daily Tasks
```bash
# Quick health check
bash scripts/health-check.sh

# Check error logs
tail -50 error_log
tail -50 var/logs/prod.log
```

### Weekly Tasks
```bash
# Clear old cache
bash scripts/clean-cache.sh

# Optimize database
php scripts/optimize-all-types.php

# Check disk space
df -h
```

### Monthly Tasks
```bash
# Full system rebuild
bash scripts/unified-build.sh

# Update dependencies
composer update --no-dev --optimize-autoloader

# Backup database
# (Add your backup command)
```

---

## 🛠️ TROUBLESHOOTING

### Import Issues
**Problem:** Import stops or fails
```bash
# Resume import
php import/import_resume.php

# Check specific products
php import/check-import-progress.php
```

**Problem:** Missing images
```bash
# Check asset directory permissions
ls -la var/assets/
ls -la public/var/assets/

# Fix permissions
bash scripts/fix-permissions-smart.sh
```

### Performance Issues
**Problem:** Slow admin panel
```bash
# Clear opcache
php -r "opcache_reset();"

# Rebuild assets
php bin/console assets:install --symlink
php bin/console fos:js-routing:dump
```

**Problem:** High CPU usage
```bash
# Check running processes
bash scripts/cpu_monitor.sh

# Kill high CPU PHP processes (if safe)
bash scripts/kill_high_cpu_php.sh
```

### Database Issues
**Problem:** Connection errors
```bash
# Test database connection
php bin/console doctrine:schema:validate

# Check database status
php bin/console doctrine:database:version
```

---

## 📁 KEY FILES & DIRECTORIES

### Configuration
- `.env` - Environment configuration
- `config/packages/` - Symfony/Pimcore configs
- `composer.json` - Dependencies

### Scripts
- `scripts/health-check.sh` - System verification
- `scripts/magento-246-optimize.sh` - Magento optimization
- `scripts/unified-build.sh` - Complete rebuild
- `scripts/fix-permissions-smart.sh` - Permission fixes

### Import
- `import/import-categories-from-magento.php` - Category import
- `import/import-products-from-magento.php` - Product import
- `import/check-data.php` - Data verification
- `products.csv` - Magento export (23MB)

### Data
- `var/classes/` - Data object classes
- `var/assets/` - Asset files
- `var/cache/` - Cache storage
- `var/logs/` - Application logs

---

## ✅ SUCCESS CRITERIA

### Pimcore Installation
- [x] Health check passes all tests
- [x] Production environment active
- [x] All permissions correct
- [x] Classes defined (Product, Category)
- [x] Assets installed
- [x] Cache optimized

### Magento Integration
- [ ] Magento 2.4.6 optimized
- [ ] Export working
- [ ] CSV file generated
- [ ] Database connection verified

### Data Import
- [ ] Categories imported successfully
- [ ] Products imported successfully
- [ ] Images linked correctly
- [ ] Relationships maintained
- [ ] No data corruption

### Performance
- [ ] Admin panel loads < 3 seconds
- [ ] API responses < 1 second
- [ ] No memory leaks
- [ ] CPU usage normal
- [ ] Cache hit ratio > 90%

---

## 🚨 EMERGENCY PROCEDURES

### System Down
```bash
# 1. Check web server
sudo systemctl status httpd

# 2. Restart if needed
sudo systemctl restart httpd

# 3. Check PHP-FPM
sudo systemctl status php-fpm

# 4. Clear cache
rm -rf var/cache/*
php bin/console cache:warmup
```

### Database Corruption
```bash
# 1. Stop web server
# 2. Backup current database
# 3. Run repair
php bin/console doctrine:schema:update --force
# 4. Rebuild classes
php bin/console pimcore:build:classes
# 5. Start web server
```

### Import Failure Recovery
```bash
# 1. Check last imported ID
php import/check-import-progress.php

# 2. Resume from checkpoint
php import/import_resume.php

# 3. If corrupted, restore backup and restart
```

---

## 📞 SUPPORT & RESOURCES

### Pimcore
- Documentation: https://pimcore.com/docs/
- Forum: https://github.com/pimcore/pimcore/discussions
- Admin: /admin/login

### Magento 2.4.6
- DevDocs: https://devdocs.magento.com/
- Performance: https://experienceleague.adobe.com/docs/commerce-operations/performance-best-practices/

### Local Logs
- Pimcore: `var/logs/`
- Apache: `/var/log/httpd/`
- System: `error_log`

---

## 📝 NOTES

- **Backup before any major operation**
- **Test in dev environment first** (set APP_ENV=dev)
- **Monitor logs continuously during import**
- **Keep maintenance window for large imports**
- **Document any custom modifications**

---

**Status:** Ready for Phase 3 - Data Import 🚀
**Last Updated:** November 17, 2025
**Maintained by:** Automated Build System
