#!/bin/bash

# Cache cleaning script for Pimcore

echo "Starting cache cleaning for Pimcore..."

# Define variables
PIMCORE_ROOT="/home/pim/public_html"

# Change to Pimcore root directory
cd "$PIMCORE_ROOT" || exit 1

# Clean Pimcore cache
echo "Cleaning Pimcore cache..."
rm -rf var/cache/*

# Rebuild Pimcore classes
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

echo "Cache cleaning and optimization completed!"