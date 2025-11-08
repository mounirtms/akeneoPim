#!/bin/bash

# Optimized cleanup and build script for Pimcore

# Define variables
PIMCORE_ROOT="/home/pim/public_html"

# Change to Pimcore root directory
cd "$PIMCORE_ROOT" || exit 1

echo "Starting optimized cleanup and build process..."

# Fix permissions (only for files that don't have the correct permissions)
echo "Fixing permissions..."
find . -type d -not -perm 755 -print0 | xargs -0 -r chmod 755
find . -type f -not -perm 644 -print0 | xargs -0 -r chmod 644

# Fix specific Pimcore directories that need write permissions
find var/ -type d -print0 | xargs -0 -r chmod 775
find var/cache/ -type d -print0 | xargs -0 -r chmod 775
find var/logs/ -type d -print0 | xargs -0 -r chmod 775
find var/classes/ -type d -print0 | xargs -0 -r chmod 775
find var/tmp/ -type d -print0 | xargs -0 -r chmod 775
find var/sessions/ -type d -print0 | xargs -0 -r chmod 775
find var/recyclebin/ -type d -print0 | xargs -0 -r chmod 775
find var/versions/ -type d -print0 | xargs -0 -r chmod 775
find var/assets/ -type d -print0 | xargs -0 -r chmod 775

# Fix specific Pimcore files that need write permissions
find var/ -type f -print0 | xargs -0 -r chmod 664
find var/cache/ -type f -print0 | xargs -0 -r chmod 664
find var/logs/ -type f -print0 | xargs -0 -r chmod 664
find var/classes/ -type f -print0 | xargs -0 -r chmod 664
find var/tmp/ -type f -print0 | xargs -0 -r chmod 664
find var/sessions/ -type f -print0 | xargs -0 -r chmod 664
find var/recyclebin/ -type f -print0 | xargs -0 -r chmod 664
find var/versions/ -type f -print0 | xargs -0 -r chmod 664
find var/assets/ -type f -print0 | xargs -0 -r chmod 664

# Fix FOSJsRouting cache directory permissions
mkdir -p var/cache/prod/fosJsRouting
chmod 775 var/cache/prod/fosJsRouting
chown -R pim:nobody var/cache/prod/fosJsRouting

# Fix ownership for all Pimcore directories
chown -R pim:nobody .

# Clear cache
echo "Clearing cache..."
rm -rf var/cache/*

# Rebuild classes
echo "Rebuilding Pimcore classes..."
php bin/console pimcore:build:classes --env=prod

# Warm up cache
echo "Warming up cache..."
php bin/console cache:warmup --env=prod

# Install assets
echo "Installing assets..."
php bin/console assets:install --env=prod

# Generate JavaScript routes
echo "Generating JavaScript routes..."
php bin/console fos:js-routing:dump --format=json --target=public/js/fos_js_routes.json

# Add predefined properties if they don't exist
echo "Adding predefined properties..."
php scripts/add-predefined-properties.php

# Optimize all data types
echo "Optimizing all data types..."
php scripts/optimize-all-types.php

echo "Optimized cleanup and build process completed successfully!"