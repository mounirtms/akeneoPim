#!/bin/bash
echo "=========================================="
echo "AKENEO PIM QUICK VALIDATION TEST"
echo "Date: $(date)"
echo "Branch: $(git branch --show-current)"
echo "=========================================="
echo ""

# Infrastructure Tests
echo "1. INFRASTRUCTURE CHECKS"
echo "------------------------"
echo "PHP Version: $(php --version | head -1)"
echo "Symfony Version: $(php bin/console --version 2>&1 | head -1)"
echo ""

# Database Tests
echo "2. DATABASE CHECKS"
echo "------------------"
mysql -h 127.0.0.1 -P 3307 -u akeneo_pim -pakeneo_pim --skip-ssl akeneo_pim -e "
SELECT 'Products' as Type, COUNT(*) as Count FROM pim_catalog_product
UNION ALL SELECT 'Users', COUNT(*) FROM oro_user
UNION ALL SELECT 'Families', COUNT(*) FROM pim_catalog_family
UNION ALL SELECT 'Channels', COUNT(*) FROM pim_catalog_channel
UNION ALL SELECT 'Locales', COUNT(*) FROM pim_catalog_locale
UNION ALL SELECT 'Categories', COUNT(*) FROM pim_catalog_category;
" 2>/dev/null | grep -v "Deprecated"
echo ""

# File System Tests
echo "3. FILE SYSTEM CHECKS"
echo "---------------------"
echo "Frontend Assets:"
ls -lh public/css/pim.css public/dist/main.min.js public/bundles/pimui/manifest.json 2>/dev/null | awk '{print $9, $5}'
echo ""
echo "Critical Directories:"
for dir in var/cache var/logs var/sessions public/media vendor; do
  if [ -d "$dir" ]; then echo "✓ $dir"; else echo "✗ $dir MISSING"; fi
done
echo ""

# Elasticsearch Tests
echo "4. ELASTICSEARCH CHECKS"
echo "-----------------------"
curl -s http://localhost:9200/_cluster/health?pretty 2>/dev/null | grep -E "(status|number_of_nodes)"
echo "Indices:"
curl -s http://localhost:9200/_cat/indices 2>/dev/null | grep akeneo | awk '{print $3, $6, $7}'
echo ""

# Web Interface Tests
echo "5. WEB INTERFACE CHECKS"
echo "-----------------------"
echo -n "Login Page: "
curl -s -o /dev/null -w "HTTP %{http_code} (%{time_total}s)\n" https://pim.technostationery.com/user/login
echo -n "Dashboard: "
curl -s -o /dev/null -w "HTTP %{http_code} (%{time_total}s)\n" https://pim.technostationery.com/
echo ""

# Configuration Tests
echo "6. CONFIGURATION CHECKS"
echo "-----------------------"
echo "Environment files:"
for file in .env .env.local config/packages/security.yml; do
  if [ -f "$file" ]; then echo "✓ $file"; else echo "✗ $file MISSING"; fi
done
echo ""

# Cache Tests
echo "7. CACHE STATUS"
echo "---------------"
if [ -d "var/cache/prod" ]; then
  CACHE_COUNT=$(find var/cache/prod -type f 2>/dev/null | wc -l)
  echo "Symfony cache files: $CACHE_COUNT"
else
  echo "✗ Production cache directory missing"
fi
echo "OPcache enabled: $(php -r 'echo ini_get("opcache.enable");')"
echo ""

echo "=========================================="
echo "VALIDATION COMPLETE"
echo "=========================================="
