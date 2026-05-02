#!/bin/bash
set -e

LOGFILE="/home/pim/public_html/REBUILD_FRONTEND_$(date +%Y%m%d_%H%M%S).log"
echo "=====================================" | tee -a "$LOGFILE"
echo "Akeneo PIM - Frontend Assets Rebuild" | tee -a "$LOGFILE"
echo "Started: $(date)" | tee -a "$LOGFILE"
echo "=====================================" | tee -a "$LOGFILE"

# Ensure we're in the right directory
cd /home/pim/public_html

# Step 1: Generate require-paths.js
echo "" | tee -a "$LOGFILE"
echo "[Step 1] Generating require-paths.js..." | tee -a "$LOGFILE"
php bin/console pim:installer:dump-require-paths --env=prod 2>&1 | tee -a "$LOGFILE" || {
    echo "⚠ Warning: require-paths generation had issues, trying dev environment..." | tee -a "$LOGFILE"
    php bin/console pim:installer:dump-require-paths --env=dev 2>&1 | tee -a "$LOGFILE" || true
}

if [ -f "public/js/require-paths.js" ]; then
    echo "✓ require-paths.js generated ($(du -h public/js/require-paths.js | cut -f1))" | tee -a "$LOGFILE"
else
    echo "✗ require-paths.js not found" | tee -a "$LOGFILE"
fi

# Step 2: Generate extensions.json
echo "" | tee -a "$LOGFILE"
echo "[Step 2] Generating extensions.json..." | tee -a "$LOGFILE"
cd vendor/akeneo/pim-community-dev/frontend/build
node update-extensions.js 2>&1 | tee -a "$LOGFILE" || {
    echo "⚠ Warning: extensions.json generation failed" | tee -a "$LOGFILE"
}
cd /home/pim/public_html

# Copy extensions.json to public/js if it exists in web/js
if [ -f "web/js/extensions.json" ]; then
    mkdir -p public/js
    cp web/js/extensions.json public/js/extensions.json
    echo "✓ extensions.json copied from web/js to public/js" | tee -a "$LOGFILE"
elif [ -f "public/js/extensions.json" ]; then
    echo "✓ extensions.json already exists in public/js" | tee -a "$LOGFILE"
else
    echo "✗ extensions.json not found" | tee -a "$LOGFILE"
fi

# Step 3: Compile LESS to CSS
echo "" | tee -a "$LOGFILE"
echo "[Step 3] Compiling LESS to CSS..." | tee -a "$LOGFILE"
cd vendor/akeneo/pim-community-dev/frontend/build
node compile-less.js 2>&1 | tee -a "$LOGFILE" || {
    echo "⚠ Warning: CSS compilation failed" | tee -a "$LOGFILE"
}
cd /home/pim/public_html

if [ -f "public/css/pim.css" ]; then
    echo "✓ pim.css generated ($(du -h public/css/pim.css | cut -f1))" | tee -a "$LOGFILE"
    chmod 644 public/css/pim.css
else
    echo "✗ pim.css not found" | tee -a "$LOGFILE"
fi

# Step 4: Install Akeneo assets
echo "" | tee -a "$LOGFILE"
echo "[Step 4] Installing Akeneo assets..." | tee -a "$LOGFILE"
php bin/console pim:installer:assets --symlink --clean --env=prod 2>&1 | tee -a "$LOGFILE" || {
    echo "⚠ Warning: Asset installation had issues" | tee -a "$LOGFILE"
}

# Step 5: Verify critical files
echo "" | tee -a "$LOGFILE"
echo "[Step 5] Verifying critical files..." | tee -a "$LOGFILE"

CRITICAL_FILES=(
    "public/js/require-paths.js"
    "public/js/extensions.json"
    "public/css/pim.css"
    "public/bundles/pimui/js/index.js"
)

for file in "${CRITICAL_FILES[@]}"; do
    if [ -f "$file" ]; then
        SIZE=$(du -h "$file" | cut -f1)
        echo "  ✓ $file ($SIZE)" | tee -a "$LOGFILE"
    else
        echo "  ✗ $file MISSING" | tee -a "$LOGFILE"
    fi
done

# Step 6: Check bundle symlinks
echo "" | tee -a "$LOGFILE"
echo "[Step 6] Checking bundle symlinks..." | tee -a "$LOGFILE"
BUNDLE_COUNT=$(find public/bundles -maxdepth 1 -type l 2>/dev/null | wc -l)
echo "  Total bundle symlinks: $BUNDLE_COUNT" | tee -a "$LOGFILE"

echo "" | tee -a "$LOGFILE"
echo "=====================================" | tee -a "$LOGFILE"
echo "Frontend rebuild completed!" | tee -a "$LOGFILE"
echo "Completed: $(date)" | tee -a "$LOGFILE"
echo "Log file: $LOGFILE" | tee -a "$LOGFILE"
echo "=====================================" | tee -a "$LOGFILE"
