#!/bin/bash
echo "=================================="
echo "AKENEO RECOVERY VERIFICATION"
echo "Date: $(date)"
echo "=================================="
echo ""

echo "1. DATABASE VERIFICATION"
echo "------------------------"
mysql -h 127.0.0.1 -P 3307 -u akeneo_pim -pakeneo_pim --skip-ssl akeneo_pim -e "
SELECT 'Products' as Type, COUNT(*) as Count FROM pim_catalog_product
UNION ALL
SELECT 'Users', COUNT(*) FROM oro_user
UNION ALL
SELECT 'Families', COUNT(*) FROM pim_catalog_family
UNION ALL
SELECT 'Channels', COUNT(*) FROM pim_catalog_channel
UNION ALL
SELECT 'Locales', COUNT(*) FROM pim_catalog_locale
UNION ALL
SELECT 'Categories', COUNT(*) FROM pim_catalog_category;
" 2>/dev/null | grep -v Deprecated

echo ""
echo "2. ELASTICSEARCH VERIFICATION"
echo "------------------------------"
curl -s http://localhost:9200/_cat/indices?v 2>/dev/null | grep akeneo || echo "ES indices check failed"

echo ""
echo "3. FILE SYSTEM VERIFICATION"
echo "----------------------------"
echo "public/css/pim.css: $(ls -lh public/css/pim.css 2>/dev/null | awk '{print $5}' || echo 'MISSING')"
echo "public/dist/main.min.js: $(ls -lh public/dist/main.min.js 2>/dev/null | awk '{print $5}' || echo 'MISSING')"
echo "public/bundles/pimui/manifest.json: $(ls -lh public/bundles/pimui/manifest.json 2>/dev/null | awk '{print $5}' || echo 'MISSING')"

echo ""
echo "4. CACHE STATUS"
echo "----------------"
ls -ld var/cache/prod/ 2>/dev/null && echo "✓ Cache directory exists" || echo "✗ Cache directory missing"
ls var/cache/prod/*.php 2>/dev/null | wc -l | xargs echo "Cache files count:"

echo ""
echo "5. PERMISSIONS CHECK"
echo "--------------------"
ls -ld var/sessions/ var/logs/ var/cache/ | awk '{print $1, $3, $4, $9}'

echo ""
echo "6. WEB INTERFACE TEST"
echo "----------------------"
curl -s -o /dev/null -w "Login Page: %{http_code} (%{time_total}s)\n" https://pim.technostationery.com/user/login
curl -s -o /dev/null -w "Dashboard: %{http_code} (%{time_total}s)\n" https://pim.technostationery.com/

echo ""
echo "7. PHP ENVIRONMENT"
echo "------------------"
php --version | head -1
php -m | grep -E "(pdo|mysql|curl|intl|gd)" | xargs echo "Extensions:"

echo ""
echo "8. SYMFONY STATUS"
echo "------------------"
php bin/console --version 2>&1 | head -1

echo ""
echo "=================================="
echo "VERIFICATION COMPLETE"
echo "=================================="
