#!/bin/bash
set -e

LOGFILE="/home/pim/public_html/CLEAN_INSTALL_$(date +%Y%m%d_%H%M%S).log"
echo "=====================================" | tee -a "$LOGFILE"
echo "Akeneo PIM - Complete Clean Install" | tee -a "$LOGFILE"
echo "Started: $(date)" | tee -a "$LOGFILE"
echo "=====================================" | tee -a "$LOGFILE"
echo "" | tee -a "$LOGFILE"

# Step 1: Backup critical files
echo "[Step 1] Backing up critical files..." | tee -a "$LOGFILE"
mkdir -p backups/clean_install_$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="backups/clean_install_$(date +%Y%m%d_%H%M%S)"
cp .env "$BACKUP_DIR/.env" 2>/dev/null || true
cp config/packages/security.yml "$BACKUP_DIR/security.yml" 2>/dev/null || true
echo "✓ Backups created in $BACKUP_DIR" | tee -a "$LOGFILE"

# Step 2: Clean directories
echo "" | tee -a "$LOGFILE"
echo "[Step 2] Removing old directories..." | tee -a "$LOGFILE"

if [ -d "var/cache" ]; then
    echo "  Removing var/cache..." | tee -a "$LOGFILE"
    rm -rf var/cache/*
    echo "  ✓ var/cache cleared" | tee -a "$LOGFILE"
fi

if [ -d "public/css" ]; then
    echo "  Removing public/css..." | tee -a "$LOGFILE"
    rm -rf public/css/*
    echo "  ✓ public/css cleared" | tee -a "$LOGFILE"
fi

if [ -d "public/js" ]; then
    echo "  Removing public/js..." | tee -a "$LOGFILE"
    rm -rf public/js/*
    echo "  ✓ public/js cleared" | tee -a "$LOGFILE"
fi

if [ -d "public/dist" ]; then
    echo "  Removing public/dist..." | tee -a "$LOGFILE"
    rm -rf public/dist/*
    echo "  ✓ public/dist cleared" | tee -a "$LOGFILE"
fi

if [ -d "public/bundles" ]; then
    echo "  Removing public/bundles..." | tee -a "$LOGFILE"
    rm -rf public/bundles/*
    echo "  ✓ public/bundles cleared" | tee -a "$LOGFILE"
fi

if [ -d "node_modules" ]; then
    echo "  Removing node_modules..." | tee -a "$LOGFILE"
    rm -rf node_modules
    echo "  ✓ node_modules removed" | tee -a "$LOGFILE"
fi

echo "✓ All target directories cleaned" | tee -a "$LOGFILE"

# Step 3: Remove vendor (optional - keeping it for now)
# echo "" | tee -a "$LOGFILE"
# echo "[Step 3] Removing vendor directory..." | tee -a "$LOGFILE"
# if [ -d "vendor" ]; then
#     rm -rf vendor
#     echo "✓ vendor removed" | tee -a "$LOGFILE"
# fi

echo "" | tee -a "$LOGFILE"
echo "[Step 3] Keeping vendor directory (skipping removal)" | tee -a "$LOGFILE"

# Step 4: Install Composer dependencies
echo "" | tee -a "$LOGFILE"
echo "[Step 4] Installing Composer dependencies..." | tee -a "$LOGFILE"
if [ -f "composer.json" ]; then
    php composer.phar install --no-dev --optimize-autoloader --ignore-platform-reqs 2>&1 | tee -a "$LOGFILE" || echo "⚠ Composer install had issues" | tee -a "$LOGFILE"
    echo "✓ Composer install attempted" | tee -a "$LOGFILE"
else
    echo "✗ composer.json not found" | tee -a "$LOGFILE"
fi

# Step 5: Install Node dependencies (root level)
echo "" | tee -a "$LOGFILE"
echo "[Step 5] Installing Node.js dependencies (root)..." | tee -a "$LOGFILE"
if [ -f "package.json" ]; then
    npm install --legacy-peer-deps 2>&1 | tee -a "$LOGFILE" || echo "⚠ npm install had issues" | tee -a "$LOGFILE"
    echo "✓ Root npm install attempted" | tee -a "$LOGFILE"
else
    echo "✗ package.json not found in root" | tee -a "$LOGFILE"
fi

# Step 6: Install Node dependencies in vendor build dir
echo "" | tee -a "$LOGFILE"
echo "[Step 6] Installing Node.js dependencies in vendor build directory..." | tee -a "$LOGFILE"
if [ -d "vendor/akeneo/pim-community-dev/frontend/build" ]; then
    cd vendor/akeneo/pim-community-dev/frontend/build
    if [ -f "package.json" ]; then
        npm install --legacy-peer-deps 2>&1 | tee -a "$LOGFILE" || echo "⚠ Build dir npm install had issues" | tee -a "$LOGFILE"
        echo "✓ Build directory npm install attempted" | tee -a "$LOGFILE"
    fi
    cd /home/pim/public_html
else
    echo "✗ Build directory not found" | tee -a "$LOGFILE"
fi

# Step 7: Verify required modules
echo "" | tee -a "$LOGFILE"
echo "[Step 7] Verifying required Node modules..." | tee -a "$LOGFILE"
MODULES=("colors" "less" "deepmerge" "yamljs" "glob" "semver")
for module in "${MODULES[@]}"; do
    if npm list "$module" >/dev/null 2>&1 || npm list -g "$module" >/dev/null 2>&1; then
        echo "  ✓ $module found" | tee -a "$LOGFILE"
    else
        echo "  ✗ $module missing - installing..." | tee -a "$LOGFILE"
        npm install "$module" --legacy-peer-deps 2>&1 | tee -a "$LOGFILE" || true
    fi
done

echo "" | tee -a "$LOGFILE"
echo "=====================================" | tee -a "$LOGFILE"
echo "Clean installation phase completed!" | tee -a "$LOGFILE"
echo "Completed: $(date)" | tee -a "$LOGFILE"
echo "Log file: $LOGFILE" | tee -a "$LOGFILE"
echo "=====================================" | tee -a "$LOGFILE"
