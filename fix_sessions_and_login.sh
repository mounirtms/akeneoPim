#!/bin/bash

echo "=== SESSION 3: FIXING SESSION STORAGE & LOGIN ==="
echo "Started: $(date)"
echo ""

# STEP 1: Create local session directory
echo "### STEP 1: Creating Session Directory ###"
mkdir -p var/sessions/prod
mkdir -p var/sessions/dev
chmod -R 777 var/sessions/
chown -R pim:pim var/sessions/

echo "Session directories created:"
ls -la var/sessions/

echo ""
echo "### STEP 2: Checking Current Session Path ###"
php -r "echo 'Current session.save_path: ' . ini_get('session.save_path') . PHP_EOL;"
php -r "echo 'Writable: '; var_dump(is_writable(ini_get('session.save_path')));"

echo ""
echo "### STEP 3: Configuring Symfony to Use Local Sessions ###"

# Check if framework.yaml exists
if [ -f "config/packages/framework.yaml" ]; then
    echo "Found config/packages/framework.yaml"
    
    # Backup original
    cp config/packages/framework.yaml config/packages/framework.yaml.backup_$(date +%Y%m%d_%H%M%S)
    
    # Check if session config already exists
    if grep -q "save_path:" config/packages/framework.yaml; then
        echo "Session save_path already configured, updating..."
        sed -i 's|save_path:.*|save_path: "%kernel.project_dir%/var/sessions/%kernel.environment%"|' config/packages/framework.yaml
    else
        echo "Adding session configuration..."
        # Add session config under framework
        sed -i '/^framework:/a\    session:\n        handler_id: session.handler.native_file\n        save_path: "%kernel.project_dir%/var/sessions/%kernel.environment%"' config/packages/framework.yaml
    fi
    
    echo "Configuration updated!"
    grep -A5 "session:" config/packages/framework.yaml
else
    echo "WARNING: framework.yaml not found at expected location"
    echo "Searching for config files..."
    find config/ -name "*framework*" -o -name "*session*" 2>/dev/null
fi

echo ""
echo "### STEP 4: Testing Session Creation ###"
php -r "
    ini_set('session.save_path', '/home/pim/public_html/var/sessions/prod');
    session_start();
    echo 'Session started successfully!' . PHP_EOL;
    echo 'Session ID: ' . session_id() . PHP_EOL;
    echo 'Session save path: ' . session_save_path() . PHP_EOL;
"

echo ""
echo "### STEP 5: Clearing Cache ###"
rm -rf var/cache/*
echo "Cache cleared"

echo ""
echo "=== Session Fix Complete at: $(date) ==="
