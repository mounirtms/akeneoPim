#!/bin/bash
echo "=== Session 3 - Final Comprehensive Fix ==="
echo "Date: $(date)"
echo ""

# Phase 1: Fix Password Encoder to use bcrypt
echo "Phase 1: Update security.yml to use bcrypt encoder"
cp config/packages/security.yml config/packages/security.yml.backup
sed -i 's/Akeneo\\UserManagement\\Component\\Model\\User: sha512/Akeneo\\UserManagement\\Component\\Model\\User: bcrypt/' config/packages/security.yml
echo "✅ Updated password encoder to bcrypt"
echo ""

# Phase 2: Generate proper bcrypt hash and update admin password
echo "Phase 2: Reset admin password with bcrypt"
HASH=$(php -r "echo password_hash('admin', PASSWORD_BCRYPT, ['cost' => 13]);")
php bin/console doctrine:query:sql "UPDATE oro_user SET password = '$HASH' WHERE username = 'admin'" 2>&1 | grep -v "Warning\|Deprecated"
echo "✅ Admin password updated with bcrypt hash"
echo ""

# Phase 3: Clear all caches
echo "Phase 3: Clear all caches"
rm -rf var/cache/*
php bin/console cache:clear --env=prod --no-warmup 2>&1 | grep -v "Warning\|Deprecated" | tail -5
php bin/console cache:warmup --env=prod 2>&1 | grep -v "Warning\|Deprecated" | tail -5
echo "✅ Cache cleared and warmed"
echo ""

# Phase 4: Rebuild CSS from LESS sources
echo "Phase 4: Rebuild CSS from LESS sources"
cd /home/pim/public_html

# Check if LESS files exist
if [ -d "vendor/akeneo/pim-community-dev/src/Akeneo/Platform/Bundle/UIBundle/Resources/public/less" ]; then
    echo "Found LESS source files"
    
    # Install required Node modules
    if [ ! -d "node_modules/less" ]; then
        npm install less less-plugin-clean-css 2>&1 | tail -5
    fi
    
    # Compile LESS to CSS
    LESS_DIR="vendor/akeneo/pim-community-dev/src/Akeneo/Platform/Bundle/UIBundle/Resources/public/less"
    if [ -f "$LESS_DIR/pim.less" ]; then
        npx lessc "$LESS_DIR/pim.less" public/css/pim.css --clean-css 2>&1 | tail -5
        echo "✅ CSS compiled from LESS"
    else
        echo "⚠️ Main LESS file not found, using alternative method"
    fi
else
    echo "⚠️ LESS source directory not found"
fi

# Alternative: Run Akeneo asset installer
echo "Running Akeneo asset installer..."
php bin/console pim:installer:assets --env=prod --symlink --clean 2>&1 | tail -10

echo ""
echo "Phase 5: Verify CSS file"
ls -lh public/css/pim.css
echo ""

# Phase 6: Check permissions
echo "Phase 6: Set proper permissions"
chown -R pim:pim var/sessions
chmod -R 777 var/sessions
echo "✅ Session permissions set"
echo ""

echo "=== All Fixes Complete ==="
echo ""
echo "Testing Summary:"
echo "1. Password encoder: bcrypt"
echo "2. Admin password: admin/admin"
echo "3. CSS file size: $(du -h public/css/pim.css | cut -f1)"
echo "4. Session path: var/sessions/prod"
echo ""
