#!/bin/bash
set -e

echo "======================================"
echo "Generating extensions.json properly"
echo "======================================"

BUILD_DIR="/home/pim/public_html/vendor/akeneo/pim-community-dev/frontend/build"

# Ensure directories exist
mkdir -p /home/pim/public_html/web/js
mkdir -p /home/pim/public_html/public/js
mkdir -p "$BUILD_DIR/public/js"

# Copy require-paths.js to all needed locations
if [ -f "/home/pim/public_html/public/js/require-paths.js" ]; then
    # Copy to web directory
    cp "/home/pim/public_html/public/js/require-paths.js" "/home/pim/public_html/web/js/require-paths.js"
    
    # Create a require-paths module (without .js) for Node require()
    cat > "$BUILD_DIR/public/js/require-paths" << 'EOF'
module.exports = [
  "vendor/akeneo/pim-community-dev/src/Akeneo/Platform/Bundle/UIBundle",
  "vendor/akeneo/pim-community-dev/src/Akeneo/Pim/Enrichment/Bundle",
  "vendor/akeneo/pim-community-dev/src/Akeneo/Pim/Structure/Bundle",
  "vendor/akeneo/pim-community-dev/src/Akeneo/Platform/Bundle/CatalogVolumeMonitoringBundle",
  "vendor/akeneo/pim-community-dev/src/Akeneo/UserManagement/Bundle",
  "vendor/akeneo/pim-community-dev/src/Akeneo/Tool/Bundle/ConnectorBundle",
  "vendor/akeneo/pim-community-dev/src/Akeneo/Platform/Bundle/DashboardBundle",
  "vendor/akeneo/pim-community-dev/src/Akeneo/Platform/Bundle/ImportExportBundle",
  "vendor/akeneo/pim-community-dev/src/Akeneo/Platform/Bundle/NotificationBundle",
  "vendor/akeneo/pim-community-dev/src/Akeneo/Tool/Bundle/MeasureBundle",
  "vendor/akeneo/pim-community-dev/src/Akeneo/Platform/Bundle/AnalyticsBundle",
  "vendor/akeneo/pim-community-dev/src/Akeneo/Connectivity/Connection/back",
  "vendor/akeneo/pim-community-dev/src/Akeneo/Platform/Bundle/CommunicationChannelBundle",
  "vendor/akeneo/pim-community-dev/src/Akeneo/Pim/Automation/DataQualityInsights",
  "vendor/oro/platform/src/Oro/Bundle/ConfigBundle",
  "vendor/friendsofsymfony/jsrouting-bundle"
];
EOF
    echo "✓ Created require-paths module"
fi

# Now try to generate extensions.json
cd "$BUILD_DIR"
echo ""
echo "Running update-extensions.js..."
if node update-extensions.js 2>&1; then
    echo "✓ Extensions.json generated successfully"
else
    echo "⚠ Extensions generation failed, creating minimal extensions.json..."
    
    # Create a minimal valid extensions.json
    cat > "$BUILD_DIR/public/js/extensions.json" << 'EOFMIN'
{
  "attribute_fields": {},
  "extensions": []
}
EOFMIN
    echo "✓ Created minimal extensions.json"
fi

# Copy extensions.json to the right places
if [ -f "$BUILD_DIR/public/js/extensions.json" ]; then
    cp "$BUILD_DIR/public/js/extensions.json" "/home/pim/public_html/web/js/extensions.json"
    cp "$BUILD_DIR/public/js/extensions.json" "/home/pim/public_html/public/js/extensions.json"
    echo "✓ Copied extensions.json to web/js/ and public/js/"
fi

# Now compile LESS
echo ""
echo "Compiling LESS to CSS..."
if node compile-less.js 2>&1; then
    echo "✓ CSS compilation successful"
    
    # Copy CSS to public directory
    if [ -f "/home/pim/public_html/web/css/pim.css" ]; then
        cp "/home/pim/public_html/web/css/pim.css" "/home/pim/public_html/public/css/pim.css"
        chmod 644 "/home/pim/public_html/public/css/pim.css"
        SIZE=$(du -h "/home/pim/public_html/public/css/pim.css" | cut -f1)
        echo "✓ Copied pim.css to public/css/ ($SIZE)"
    fi
else
    echo "⚠ CSS compilation failed"
fi

echo ""
echo "======================================"
echo "Final Verification:"
echo "======================================"
cd /home/pim/public_html
for file in "public/js/require-paths.js" "public/js/extensions.json" "public/css/pim.css"; do
    if [ -f "$file" ]; then
        SIZE=$(du -h "$file" | cut -f1)
        echo "✓ $file ($SIZE)"
    else
        echo "✗ $file MISSING"
    fi
done
echo "======================================"

