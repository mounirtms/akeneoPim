#!/bin/bash
# Fix all __moduleConfig references to use module.config()

echo "🔧 Fixing __moduleConfig references in all JavaScript files"
echo "=============================================================="

# Function to fix a file
fix_file() {
    local file=$1
    echo "📝 Processing: $file"
    
    # Backup original
    cp "$file" "$file.bak"
    
    # Check if file already has 'module' in define dependencies
    if grep -q "define(\['module'" "$file" 2>/dev/null; then
        echo "   ✓ Already has module dependency"
    elif grep -q "define(\[" "$file" 2>/dev/null; then
        # Add 'module' to existing dependencies
        sed -i "s/define(\[/define(['module', /" "$file"
        echo "   ✓ Added module to dependencies"
    else
        echo "   ⚠️  No define() found, skipping"
        rm "$file.bak"
        return
    fi
    
    # Replace __moduleConfig with module.config()
    sed -i 's/__moduleConfig/module.config()/g' "$file"
    
    # Update function parameters to include module
    sed -i "s/function (/function (module, /" "$file"
    
    echo "   ✅ Fixed"
}

# Fix critical files first
echo ""
echo "Phase 1: Fixing critical initialization files"
echo "----------------------------------------------"

fix_file "public/bundles/pimui/js/fetcher-registry.js"
fix_file "public/bundles/pimui/js/controller/group.js"
fix_file "public/bundles/pimui/js/router.js"

echo ""
echo "Phase 2: Fixing fetcher files"
echo "------------------------------"

fix_file "public/bundles/pimui/js/fetcher/fetcher-registry.js"

echo ""
echo "Phase 3: Fixing form files"
echo "--------------------------"

fix_file "public/bundles/pimui/js/form/common/edit-form.js"
fix_file "public/bundles/pimui/js/form/cache-invalidator.js"

echo ""
echo "Phase 4: Fixing saver files"
echo "---------------------------"

for file in public/bundles/pimui/js/saver/*.js; do
    if grep -q "__moduleConfig" "$file" 2>/dev/null; then
        fix_file "$file"
    fi
done

echo ""
echo "Phase 5: Fixing remover files"
echo "-----------------------------"

for file in public/bundles/pimui/js/remover/*.js; do
    if grep -q "__moduleConfig" "$file" 2>/dev/null; then
        fix_file "$file"
    fi
done

echo ""
echo "Phase 6: Fixing attribute and grid files"
echo "----------------------------------------"

fix_file "public/bundles/pimui/js/attribute/form/type-specific-form-registry.js"
fix_file "public/bundles/pimui/js/grid/view-selector.js"

echo ""
echo "✅ All files fixed!"
echo ""
echo "Verifying changes..."
remaining=$(grep -r "__moduleConfig" public/bundles/pimui/js/ --include="*.js" 2>/dev/null | grep -v ".bak" | wc -l)
echo "Remaining __moduleConfig references: $remaining"

if [ $remaining -eq 0 ]; then
    echo "🎉 SUCCESS! All __moduleConfig references have been replaced!"
else
    echo "⚠️  Some references remain, checking..."
    grep -r "__moduleConfig" public/bundles/pimui/js/ --include="*.js" 2>/dev/null | grep -v ".bak"
fi

