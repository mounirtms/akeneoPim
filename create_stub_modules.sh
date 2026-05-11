#!/bin/bash
# Create stub modules for optional dependencies

echo "📦 Creating Stub Modules for Optional Dependencies"
echo "===================================================="

# 1. Create require-polyfill.js (empty AMD wrapper)
cat > public/bundles/require-polyfill.js << 'POLYFILL'
// Require polyfill stub - AMD wrapper
define(function() {
    'use strict';
    console.log('[require-polyfill] Stub loaded');
    return {};
});
POLYFILL
echo "✅ Created: public/bundles/require-polyfill.js"

# 2. Create oro/loading-mask.js (minimal implementation)
mkdir -p public/bundles/oro
cat > public/bundles/oro/loading-mask.js << 'LOADING'
// Loading mask stub - AMD wrapper
define(['jquery'], function($) {
    'use strict';
    console.log('[oro/loading-mask] Stub loaded');
    
    return {
        show: function() { console.log('[loading-mask] show called'); },
        hide: function() { console.log('[loading-mask] hide called'); },
        toggle: function() { console.log('[loading-mask] toggle called'); }
    };
});
LOADING
echo "✅ Created: public/bundles/oro/loading-mask.js"

# 3. Create pim/template/error/error.js (simple error template)
mkdir -p public/bundles/pimui/js/pim/template/error
cat > public/bundles/pimui/js/pim/template/error/error.js << 'ERROR'
// Error template - AMD wrapper
define(function() {
    'use strict';
    console.log('[pim/template/error/error] Template loaded');
    
    return '<div class="AknMessageBox AknMessageBox--error">' +
           '<%= message %>' +
           '</div>';
});
ERROR
echo "✅ Created: public/bundles/pimui/js/pim/template/error/error.js"

# 4. Check templates/app.js - it should already exist
if [ -f "public/bundles/pimui/templates/app.js" ]; then
  echo "✅ Already exists: public/bundles/pimui/templates/app.js"
else
  echo "⚠️  Missing: public/bundles/pimui/templates/app.js (should be in templates directory)"
  # It's already created as public/bundles/pimui/js/template/app.js
  # Create a symlink or copy
  if [ -f "public/bundles/pimui/js/template/app.js" ]; then
    cp public/bundles/pimui/js/template/app.js public/bundles/pimui/templates/app.js
    echo "✅ Copied from js/template/app.js"
  fi
fi

echo ""
echo "✅ All stub modules created"
echo ""
echo "📋 Summary of created/fixed files:"
ls -lh public/bundles/require-polyfill.js
ls -lh public/bundles/oro/loading-mask.js
ls -lh public/bundles/pimui/js/view/base.js
ls -lh public/bundles/pimui/js/messenger.js
ls -lh public/bundles/pimui/js/fetcher-registry.js
ls -lh public/bundles/pimui/js/pim/formatter/choices/base.js
ls -lh public/bundles/pimui/js/pim/template/error/error.js

