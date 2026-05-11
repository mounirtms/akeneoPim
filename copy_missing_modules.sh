#!/bin/bash
# Copy missing AMD modules from vendor source to public bundles

VENDOR_BASE="vendor/akeneo/pim-community-dev/src/Akeneo/Platform/Bundle/UIBundle/Resources/public"
PUBLIC_BASE="public/bundles/pimui"

echo "Copying missing AMD modules..."
echo "================================"

# Copy formatter/choices/base.js
if [ -f "$VENDOR_BASE/js/formatter/choices/base.js" ]; then
  mkdir -p "$PUBLIC_BASE/js/pim/formatter/choices"
  cp -v "$VENDOR_BASE/js/formatter/choices/base.js" "$PUBLIC_BASE/js/pim/formatter/choices/base.js"
fi

# Copy view/base files (search for it)
if [ -f "$VENDOR_BASE/js/view/base.js" ]; then
  mkdir -p "$PUBLIC_BASE/js/view"
  cp -v "$VENDOR_BASE/js/view/base.js" "$PUBLIC_BASE/js/view/base.js"
fi

# Check templates directory
if [ -d "$VENDOR_BASE/templates" ]; then
  cp -rv "$VENDOR_BASE/templates" "$PUBLIC_BASE/"
fi

echo ""
echo "Searching for additional source files..."
find "$VENDOR_BASE/js" -name "base.js" -o -name "*messenger*" -o -name "loading-mask*"
