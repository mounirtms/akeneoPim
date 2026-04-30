#!/bin/bash
#
# Dashboard Fix Script
# Fixes the dashboard routing issue (404 error)
#
# Date: 2026-04-30
# Repository: https://github.com/mounirtms/akeneoPim.git

set -e

PIM_DIR="/home/pim/public_html"
PUBLIC_DIR="$PIM_DIR/public"
DASHBOARD_FILE="$PUBLIC_DIR/dashboard.php"

echo "=== Dashboard Fix Script ==="
echo ""

# Check if dashboard file exists
if [ ! -f "$DASHBOARD_FILE" ]; then
    echo "ERROR: Dashboard file not found at $DASHBOARD_FILE"
    exit 1
fi

echo "✓ Dashboard file exists: $DASHBOARD_FILE"
echo "  Size: $(du -h "$DASHBOARD_FILE" | cut -f1)"

# Check .htaccess in public directory
HTACCESS_FILE="$PUBLIC_DIR/.htaccess"

if [ -f "$HTACCESS_FILE" ]; then
    echo "✓ .htaccess exists"
    
    # Backup .htaccess
    cp "$HTACCESS_FILE" "$HTACCESS_FILE.backup.$(date +%Y%m%d_%H%M%S)"
    echo "✓ .htaccess backed up"
    
    # Check if dashboard rewrite rule exists
    if grep -q "dashboard.php" "$HTACCESS_FILE"; then
        echo "✓ Dashboard rule already exists in .htaccess"
    else
        echo "Adding dashboard rewrite rule..."
        
        # Add rule before the main rewrite rules
        sed -i '/RewriteEngine On/a \
    # Dashboard access\
    RewriteRule ^dashboard$ dashboard.php [L]\
    RewriteRule ^dashboard/$ dashboard.php [L]' "$HTACCESS_FILE"
        
        echo "✓ Dashboard rule added to .htaccess"
    fi
else
    echo "Creating .htaccess file..."
    cat > "$HTACCESS_FILE" << 'EOF'
# Dashboard access
<IfModule mod_rewrite.c>
    RewriteEngine On
    RewriteRule ^dashboard$ dashboard.php [L]
    RewriteRule ^dashboard/$ dashboard.php [L]
</IfModule>

# Security
<FilesMatch "dashboard\.php$">
    Require all granted
</FilesMatch>
EOF
    echo "✓ .htaccess created with dashboard rules"
fi

# Fix permissions
chmod 644 "$DASHBOARD_FILE"
chmod 644 "$HTACCESS_FILE"

echo ""
echo "=== Dashboard URLs ==="
echo "  Direct: https://pim.technostationery.com/public/dashboard.php"
echo "  Rewrite: https://pim.technostationery.com/dashboard"
echo ""

# Test dashboard file
echo "=== Testing Dashboard File ==="
cd "$PIM_DIR"
php "$DASHBOARD_FILE" > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✓ Dashboard PHP file is valid"
else
    echo "⚠ Dashboard PHP file has syntax errors"
fi

echo ""
echo "=== Fix Complete ==="
echo "Please test the dashboard at: https://pim.technostationery.com/dashboard"

exit 0
