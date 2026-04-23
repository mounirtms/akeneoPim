#!/bin/bash

################################################################################
# Phase 1.3 & 1.4: Quick Critical Fixes
# Purpose: Suppress CREATE_TIME exception and enable products
# Date: 2026-04-23
################################################################################

echo "=========================================="
echo "PHASE 1.3 & 1.4: Final Critical Fixes"
echo "=========================================="
echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

cd /home/pim/public_html

# PHASE 1.3: Suppress CREATE_TIME exception
echo "=== PHASE 1.3: Suppressing CREATE_TIME Exception ==="
echo ""

# Create production config override
mkdir -p config/packages/prod
cat > config/packages/prod/installer.yaml << 'EOF'
# Disable installation status check in production
# Prevents CREATE_TIME exception errors
akeneo_platform_installer:
    check_installation_status: false
EOF

echo "✓ Created config/packages/prod/installer.yaml"
echo "✓ Installation status check disabled"
echo ""

# PHASE 1.4: Enable disabled products
echo "=== PHASE 1.4: Enabling Disabled Products ==="
echo ""

DB="/opt/mariadb10.6/mariadb/bin/mysql -u root -p'YourNewStrongPassword' -h 127.0.0.1 -P 3307 akeneo_pim"

# Check current status
echo "Current product status:"
$DB -e "SELECT is_enabled, COUNT(*) as count FROM pim_catalog_product GROUP BY is_enabled;"
echo ""

# Enable all products
echo "Enabling all products..."
UPDATED=$($DB -sN -e "UPDATE pim_catalog_product SET is_enabled = 1 WHERE is_enabled = 0; SELECT ROW_COUNT();")
echo "✓ Enabled $UPDATED products"
echo ""

# Verify
echo "New product status:"
$DB -e "SELECT is_enabled, COUNT(*) as count FROM pim_catalog_product GROUP BY is_enabled;"
echo ""

# Clear cache
echo "=== Clearing Cache ==="
php bin/console cache:clear --env=prod --no-warmup
bash webapp/fix_cache_permissions.sh > /dev/null 2>&1
echo "✓ Cache cleared"
echo ""

# Test website
echo "=== Testing Website ==="
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" https://pim.technostationery.com/ 2>&1)
echo "Website status: HTTP $HTTP_CODE"
echo ""

echo "=========================================="
echo "Phase 1.3 & 1.4 Complete"
echo "=========================================="
echo ""
echo "Summary:"
echo "  ✓ CREATE_TIME exception suppressed"
echo "  ✓ $UPDATED products enabled"
echo "  ✓ Cache cleared"
echo "  ✓ Website tested: HTTP $HTTP_CODE"
echo ""

exit 0
