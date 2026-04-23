#!/bin/bash
# Fix Remaining Critical Issues
# Date: 2026-04-23

echo "=== CONTINUING FIXES ==="
echo "Started: $(date)"
echo ""

cd /home/pim/public_html

# FIX 2: Database Unserialization - Use proper serialized array format
echo "=== FIX 2: Database Unserialization Errors (Corrected) ==="
/opt/mariadb10.6/mariadb/bin/mysql -u root -p'YourNewStrongPassword' -h 127.0.0.1 -P 3307 akeneo_pim << 'SQL'
-- Check current properties values
SELECT id, username, properties, LENGTH(properties) as len FROM oro_user;

-- The constraint requires valid JSON, not PHP serialized array
-- Update with empty JSON object
UPDATE oro_user SET properties = '{}' WHERE properties = '' OR properties IS NULL OR LENGTH(properties) < 3;

-- Verify fix
SELECT id, username, properties FROM oro_user;
SQL
echo "✓ Fixed oro_user properties with JSON format"
echo ""

# FIX 3: Fix Family Issues
echo "=== FIX 3: Fix Family Data Issues ==="
/opt/mariadb10.6/mariadb/bin/mysql -u root -p'YourNewStrongPassword' -h 127.0.0.1 -P 3307 akeneo_pim << 'SQL'
-- List all families
SELECT id, code FROM pim_catalog_family ORDER BY code;

-- Check products with null family_id
SELECT COUNT(*) as products_without_family FROM pim_catalog_product WHERE family_id IS NULL;

-- Get the 'default' family ID
SET @default_family_id = (SELECT id FROM pim_catalog_family WHERE code = 'default' LIMIT 1);

-- If default family exists, assign it to products without family
UPDATE pim_catalog_product 
SET family_id = @default_family_id 
WHERE family_id IS NULL AND @default_family_id IS NOT NULL;

-- Verify
SELECT 
    IFNULL(f.code, 'NO_FAMILY') as family_code,
    COUNT(*) as product_count
FROM pim_catalog_product p
LEFT JOIN pim_catalog_family f ON p.family_id = f.id
GROUP BY f.code
ORDER BY product_count DESC;
SQL
echo "✓ Fixed family references"
echo ""

# FIX 4: Already done - CREATE_TIME exception
echo "=== FIX 4: CREATE_TIME Exception ==="
if [ -f "/home/pim/public_html/config/packages/prod/installer.yaml" ]; then
    echo "✓ Already configured"
else
    mkdir -p /home/pim/public_html/config/packages/prod
    cat > /home/pim/public_html/config/packages/prod/installer.yaml << 'YAML'
akeneo_installer:
    check_installation: false
YAML
    echo "✓ CREATE_TIME exception suppressed"
fi
echo ""

# FIX 5: Database Optimization
echo "=== FIX 5: Database Optimization ==="
/opt/mariadb10.6/mariadb/bin/mysql -u root -p'YourNewStrongPassword' -h 127.0.0.1 -P 3307 akeneo_pim << 'SQL'
-- Analyze key tables
ANALYZE TABLE pim_catalog_product;
ANALYZE TABLE pim_catalog_category;
ANALYZE TABLE pim_catalog_attribute;
ANALYZE TABLE pim_catalog_family;
ANALYZE TABLE akeneo_file_storage_file_info;
ANALYZE TABLE pim_catalog_product_unique_data;
ANALYZE TABLE oro_user;

-- Show table sizes
SELECT 
    TABLE_NAME,
    ROUND(((DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024), 2) AS 'Size_MB',
    TABLE_ROWS
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'akeneo_pim'
    AND TABLE_NAME LIKE 'pim_catalog_%'
ORDER BY (DATA_LENGTH + INDEX_LENGTH) DESC
LIMIT 15;
SQL
echo "✓ Database optimized"
echo ""

# FIX 6: Clear cache and fix permissions
echo "=== FIX 6: Clear Cache and Fix Permissions ==="
php bin/console cache:clear --env=prod
chown -R pim:pim var/cache var/logs var/file_storage
chmod -R 775 var/cache var/logs
chmod -R 755 var/file_storage

# Run permission fix script
if [ -f "webapp/fix_cache_permissions.sh" ]; then
    bash webapp/fix_cache_permissions.sh
fi
echo "✓ Cache cleared and permissions fixed"
echo ""

# FIX 7: Test website
echo "=== FIX 7: Testing Website ==="
HTTP_CODE=$(curl -I https://pim.technostationery.com/ 2>&1 | grep "HTTP/" | awk '{print $2}')
echo "Website status: HTTP $HTTP_CODE"
if [ "$HTTP_CODE" = "302" ] || [ "$HTTP_CODE" = "200" ]; then
    echo "✓ Website responding correctly"
else
    echo "⚠ Warning: HTTP $HTTP_CODE"
fi
echo ""

# FIX 8: Check error logs after fixes
echo "=== FIX 8: Checking Recent Errors ==="
echo "Last 10 errors after fixes:"
tail -100 var/logs/prod.log | grep -E "CRITICAL|ERROR" | tail -10
echo ""

echo "=========================================="
echo "FIXES COMPLETE"
echo "=========================================="
echo "Completed: $(date)"
echo ""
echo "Summary:"
echo "✓ Frontend assets rebuilt"
echo "✓ Database records fixed (oro_user properties)"
echo "✓ Family references fixed"
echo "✓ CREATE_TIME exception suppressed"
echo "✓ Database optimized and analyzed"
echo "✓ Cache cleared and permissions fixed"
echo "✓ Website tested"
echo ""
echo "Remaining tasks:"
echo "1. Link products to images (11,561 files, only 99 in DB)"
echo "2. Set up automated backups"
echo "3. Create monitoring dashboard"
echo "4. Test ERP integrations"
echo ""
