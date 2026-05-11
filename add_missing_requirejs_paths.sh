#!/bin/bash
# Add missing RequireJS paths for view/base module

echo "🔧 Adding missing RequireJS paths"
echo "=================================="

file="public/js/requirejs-config.js"
cp "$file" "$file.bak3"

# Find the line with 'pim/form': 'pimui/js/view/base'
# Add a new line after it for the direct path
sed -i "/        'pim\/form': 'pimui\/js\/view\/base',/a\\        'pimui\/js\/view\/base': 'pimui\/js\/view\/base'," "$file"

echo "✅ Added 'pimui/js/view/base' path to RequireJS config"

# Verify
echo ""
echo "Verifying..."
grep "'pimui/js/view/base'" "$file" && echo "✅ Path exists" || echo "❌ Path not found"

