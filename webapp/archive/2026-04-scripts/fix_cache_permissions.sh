#!/bin/bash
# Akeneo PIM - Cache Permission Fix Script
# This script fixes recurring cache permission issues
# Run after any cache operations

set -e

WORK_DIR="/home/pim/public_html"
cd "$WORK_DIR"

echo "🔧 Fixing Akeneo PIM cache permissions..."

# Fix ownership recursively
echo "   ↳ Fixing file ownership (pim:pim)..."
find var/cache -type d -user root -exec chown pim:pim {} \; 2>/dev/null || true
find var/cache -type f -user root -exec chown pim:pim {} \; 2>/dev/null || true
find var/logs -type d -user root -exec chown pim:pim {} \; 2>/dev/null || true
find var/logs -type f -user root -exec chown pim:pim {} \; 2>/dev/null || true

# Fix permissions
echo "   ↳ Fixing permissions (777)..."
chmod -R 777 var/cache var/logs 2>/dev/null || true

echo "✅ Cache permissions fixed!"
echo ""
echo "Verification:"
ls -la var/cache/prod/ | head -5
