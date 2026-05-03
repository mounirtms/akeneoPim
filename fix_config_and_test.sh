#!/bin/bash

echo "=== FIXING CONFIGURATION AND TESTING ==="
echo ""

# Step 1: Fix the duplicate session config in framework.yaml
echo "### Step 1: Fixing framework.yaml ###"
cp config/packages/framework.yaml config/packages/framework.yaml.backup2

cat > config/packages/framework.yaml << 'YAML'
framework:
    secret: "%env(APP_SECRET)%"
    session:
        handler_id: session.handler.native_file
        save_path: "%kernel.project_dir%/var/sessions/%kernel.environment%"
        cookie_secure: false
        cookie_samesite: lax
        cookie_httponly: true
    assets: null
    error_handler:
        log: true
        throw: true
    csrf_protection:
        enabled: true
YAML

echo "✓ Configuration fixed"
cat config/packages/framework.yaml | head -15

echo ""
echo "### Step 2: Clearing Cache ###"
rm -rf var/cache/*
echo "✓ Cache cleared"

echo ""
echo "### Step 3: Testing Session Creation ###"
php -r "
require 'vendor/autoload.php';
ini_set('session.save_path', '/home/pim/public_html/var/sessions/prod');
session_start();
\$_SESSION['test'] = 'working';
echo 'Session test: ' . \$_SESSION['test'] . PHP_EOL;
echo 'Session ID: ' . session_id() . PHP_EOL;
"

echo ""
echo "### Step 4: Checking Admin User Password ###"
php bin/console doctrine:query:sql "
SELECT username, email, LEFT(password, 30) as pwd_hash 
FROM oro_user 
WHERE username = 'admin'
" --env=prod 2>&1 | grep -A5 "array"

echo ""
echo "=== Configuration Fix Complete ==="
