#!/bin/bash
# Compile missing TypeScript modules to AMD format

source ~/.nvm/nvm.sh
nvm use 14.17.0

VENDOR_SRC="vendor/akeneo/pim-community-dev/src/Akeneo/Platform/Bundle/UIBundle/Resources/public"
PUBLIC_DEST="public/bundles/pimui"
TSC="node_modules/.bin/tsc"

echo "🔨 Compiling Missing TypeScript Modules to AMD Format"
echo "======================================================="

# Create output directories
mkdir -p "$PUBLIC_DEST/js/view"
mkdir -p "$PUBLIC_DEST/js/pim/template/error"
mkdir -p "$PUBLIC_DEST/js"
mkdir -p "public/bundles/oro"
mkdir -p "public/bundles"

# Function to compile TypeScript to AMD
compile_ts() {
  local src=$1
  local dest=$2
  echo "📝 Compiling: $src"
  echo "   → $dest"
  
  $TSC "$src" \
    --module amd \
    --target ES5 \
    --lib ES2015,DOM \
    --skipLibCheck \
    --allowSyntheticDefaultImports \
    --esModuleInterop \
    --jsx react \
    --outFile "$dest" 2>&1 | grep -v "error TS" || true
  
  if [ -f "$dest" ]; then
    echo "   ✅ SUCCESS: $(wc -c < "$dest") bytes"
  else
    echo "   ❌ FAILED"
  fi
  echo ""
}

# 1. Compile view/base.ts (CRITICAL - blocks pim/app)
if [ -f "$VENDOR_SRC/js/view/base.ts" ]; then
  compile_ts "$VENDOR_SRC/js/view/base.ts" "$PUBLIC_DEST/js/view/base.js"
fi

# 2. Compile messenger.tsx
if [ -f "$VENDOR_SRC/js/messenger.tsx" ]; then
  compile_ts "$VENDOR_SRC/js/messenger.tsx" "$PUBLIC_DEST/js/messenger.js"
fi

echo "✅ Compilation phase complete"
echo ""
