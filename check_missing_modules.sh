#!/bin/bash
echo "Checking for missing AMD modules..."
echo "====================================="

missing_modules=(
  "public/bundles/pimui/templates/app.js"
  "public/bundles/pimui/js/fetcher-registry.js"
  "public/bundles/pimui/js/view/base.js"
  "public/bundles/pimui/js/messenger.js"
  "public/bundles/require-polyfill.js"
  "public/bundles/pimui/js/pim/template/error/error.js"
  "public/bundles/oro/loading-mask.js"
  "public/bundles/pimui/js/pim/formatter/choices/base.js"
  "public/bundles/pimui/js/translator.js"
)

for module in "${missing_modules[@]}"; do
  if [ -f "$module" ]; then
    echo "✅ EXISTS: $module"
  else
    echo "❌ MISSING: $module"
  fi
done
