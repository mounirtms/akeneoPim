#!/bin/bash
# Quick Phase 2 Audit - Core System Check
set -e

echo "================================"
echo "PHASE 2: QUICK CORE AUDIT"
echo "================================"
echo ""

# PHP Version
echo "1. PHP CLI Version:"
php -v | head -1

# PHP Extensions
echo ""
echo "2. Critical PHP Extensions:"
for ext in pdo pdo_mysql mysqli mbstring json curl xml zip intl bcmath gd; do
    if php -m | grep -qi "^$ext$"; then
        echo "  ✓ $ext"
    else
        echo "  ✗ $ext (MISSING)"
    fi
done

# Directories
echo ""
echo "3. Critical Directories:"
for dir in var/cache var/logs var/sessions public/media public/bundles vendor; do
    if [ -d "$dir" ]; then
        echo "  ✓ $dir"
    else
        echo "  ✗ $dir (MISSING)"
    fi
done

# Symfony Console
echo ""
echo "4. Symfony Console:"
if php bin/console --version 2>&1 | grep -q "Symfony"; then
    php bin/console --version | head -1
    echo "  ✓ Console accessible"
else
    echo "  ✗ Console not accessible"
fi

# Database Connection
echo ""
echo "5. Database Connection:"
if mysql -u akeneo_pim -p'akeneo_pim' -h 127.0.0.1 -P 3307 --ssl=0 -e "SELECT 1" 2>/dev/null; then
    echo "  ✓ MySQL connection successful"
    # Get counts
    USER_COUNT=$(mysql -u akeneo_pim -p'akeneo_pim' -h 127.0.0.1 -P 3307 --ssl=0 akeneo_pim -se "SELECT COUNT(*) FROM oro_user" 2>/dev/null)
    PRODUCT_COUNT=$(mysql -u akeneo_pim -p'akeneo_pim' -h 127.0.0.1 -P 3307 --ssl=0 akeneo_pim -se "SELECT COUNT(*) FROM pim_catalog_product" 2>/dev/null)
    echo "  - Users: $USER_COUNT"
    echo "  - Products: $PRODUCT_COUNT"
else
    echo "  ✗ Cannot connect to database"
fi

# Elasticsearch
echo ""
echo "6. Elasticsearch:"
if curl -s "http://localhost:9200" >/dev/null 2>&1; then
    echo "  ✓ Elasticsearch running"
    ES_COUNT=$(curl -s "http://localhost:9200/akeneo_pim_product_and_product_model/_count" 2>/dev/null | grep -o '"count":[0-9]*' | cut -d: -f2)
    echo "  - Products indexed: $ES_COUNT"
else
    echo "  ✗ Cannot connect to Elasticsearch"
fi

# Configuration Files
echo ""
echo "7. Configuration Files:"
for file in .env config/packages/security.yml config/packages/framework.yml; do
    if [ -f "$file" ]; then
        echo "  ✓ $file"
    else
        echo "  ✗ $file (MISSING)"
    fi
done

# Assets
echo ""
echo "8. Frontend Assets:"
for file in public/css/pim.css public/dist/main.min.js public/bundles/pimui/manifest.json; do
    if [ -f "$file" ] && [ -s "$file" ]; then
        SIZE=$(ls -lh "$file" | awk '{print $5}')
        echo "  ✓ $file ($SIZE)"
    elif [ -f "$file" ]; then
        echo "  ⚠ $file (EMPTY)"
    else
        echo "  ✗ $file (MISSING)"
    fi
done

echo ""
echo "================================"
echo "Quick audit complete!"
echo "================================"
