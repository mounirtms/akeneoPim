#!/bin/bash

# Pimcore Health & Status Verification Script
# This script verifies that all fixes have been properly applied

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║        PIMCORE INSTALLATION - HEALTH CHECK REPORT              ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

PIMCORE_ROOT="/home/pim/public_html"
STATUS_OK=0
STATUS_WARN=0
STATUS_ERROR=0

# Function to print status
check_status() {
    local name="$1"
    local result="$2"
    local details="$3"
    
    if [ "$result" = "OK" ]; then
        echo "   ✅ $name"
        if [ ! -z "$details" ]; then
            echo "      └─ $details"
        fi
        ((STATUS_OK++))
    elif [ "$result" = "WARN" ]; then
        echo "   ⚠️  $name"
        if [ ! -z "$details" ]; then
            echo "      └─ $details"
        fi
        ((STATUS_WARN++))
    else
        echo "   ❌ $name"
        if [ ! -z "$details" ]; then
            echo "      └─ $details"
        fi
        ((STATUS_ERROR++))
    fi
}

# 1. Check permissions
echo "📋 PERMISSIONS CHECK"
echo "─────────────────────────────────────────────────────────────"

if [ -d "$PIMCORE_ROOT/var/cache" ]; then
    CACHE_PERMS=$(stat -c "%a" "$PIMCORE_ROOT/var/cache")
    [ "$CACHE_PERMS" = "775" ] && check_status "Cache directory permissions" "OK" "$CACHE_PERMS" || check_status "Cache directory permissions" "WARN" "$CACHE_PERMS (expected 775)"
fi

if [ -d "$PIMCORE_ROOT/var/sessions" ]; then
    SESSION_PERMS=$(stat -c "%a" "$PIMCORE_ROOT/var/sessions")
    [ "$SESSION_PERMS" = "775" ] && check_status "Session directory permissions" "OK" "$SESSION_PERMS" || check_status "Session directory permissions" "WARN" "$SESSION_PERMS (expected 775)"
fi

# 2. Check configuration files
echo ""
echo "⚙️  CONFIGURATION CHECK"
echo "─────────────────────────────────────────────────────────────"

if [ -f "$PIMCORE_ROOT/config/packages/security.yaml" ]; then
    CSRF_CHECK=$(grep -c "csrf_protection" "$PIMCORE_ROOT/config/packages/security.yaml")
    [ "$CSRF_CHECK" -gt 0 ] && check_status "CSRF protection configured" "OK" "Found in security.yaml" || check_status "CSRF protection configured" "ERROR" "Not found in security.yaml"
fi

if [ -f "$PIMCORE_ROOT/config/packages/framework.yaml" ]; then
    CSRF_CHECK=$(grep -c "csrf_protection:" "$PIMCORE_ROOT/config/packages/framework.yaml")
    [ "$CSRF_CHECK" -gt 0 ] && check_status "Framework CSRF enabled" "OK" "Found in framework.yaml" || check_status "Framework CSRF enabled" "WARN" "Check manually"
fi

# 3. Check cache status
echo ""
echo "💾 CACHE STATUS"
echo "─────────────────────────────────────────────────────────────"

if [ -d "$PIMCORE_ROOT/var/cache/prod" ]; then
    CACHE_SIZE=$(du -sh "$PIMCORE_ROOT/var/cache/prod" 2>/dev/null | cut -f1)
    check_status "Production cache" "OK" "Size: $CACHE_SIZE"
else
    check_status "Production cache" "ERROR" "Directory not found"
fi

if [ -f "$PIMCORE_ROOT/var/cache/prod/ContainerProdRelease.php" ]; then
    check_status "Production container" "OK" "Compiled"
else
    check_status "Production container" "WARN" "Not yet compiled"
fi

# 4. Check assets
echo ""
echo "📦 ASSETS CHECK"
echo "─────────────────────────────────────────────────────────────"

if [ -f "$PIMCORE_ROOT/public/js/fos_js_routes.json" ]; then
    ROUTES_SIZE=$(wc -c < "$PIMCORE_ROOT/public/js/fos_js_routes.json")
    [ "$ROUTES_SIZE" -gt 10000 ] && check_status "JavaScript routes" "OK" "$ROUTES_SIZE bytes" || check_status "JavaScript routes" "WARN" "$ROUTES_SIZE bytes"
else
    check_status "JavaScript routes" "ERROR" "fos_js_routes.json not found"
fi

BUNDLE_COUNT=$(find "$PIMCORE_ROOT/public/bundles" -maxdepth 1 -type d -name "pimcore*" 2>/dev/null | wc -l)
[ "$BUNDLE_COUNT" -gt 3 ] && check_status "Admin bundles" "OK" "$BUNDLE_COUNT bundles installed" || check_status "Admin bundles" "WARN" "$BUNDLE_COUNT bundles found"

# 5. Check environment
echo ""
echo "🌍 ENVIRONMENT CHECK"
echo "─────────────────────────────────────────────────────────────"

if [ -f "$PIMCORE_ROOT/.env" ]; then
    APP_ENV=$(grep "^APP_ENV=" "$PIMCORE_ROOT/.env" | cut -d= -f2)
    APP_DEBUG=$(grep "^APP_DEBUG=" "$PIMCORE_ROOT/.env" | cut -d= -f2)
    
    if [ "$APP_ENV" = "prod" ]; then
        check_status "Environment" "OK" "APP_ENV=prod"
    else
        check_status "Environment" "WARN" "APP_ENV=$APP_ENV (not production)"
    fi
    
    if [ "$APP_DEBUG" = "0" ]; then
        check_status "Debug mode" "OK" "APP_DEBUG=0 (disabled)"
    else
        check_status "Debug mode" "WARN" "APP_DEBUG=$APP_DEBUG (should be 0 in prod)"
    fi
fi

# 6. Check database
echo ""
echo "🗄️  DATABASE CHECK"
echo "─────────────────────────────────────────────────────────────"

if [ -f "$PIMCORE_ROOT/.env" ]; then
    DATABASE_URL=$(grep "^DATABASE_URL=" "$PIMCORE_ROOT/.env" | cut -d= -f2-)
    if [ ! -z "$DATABASE_URL" ]; then
        check_status "Database configured" "OK" "MySQL connection string found"
    else
        check_status "Database configured" "ERROR" "DATABASE_URL not found"
    fi
fi

# 7. Check key files
echo ""
echo "📄 KEY FILES CHECK"
echo "─────────────────────────────────────────────────────────────"

[ -f "$PIMCORE_ROOT/public/index.php" ] && check_status "Index.php" "OK" "Entry point exists" || check_status "Index.php" "ERROR" "Entry point missing"
[ -f "$PIMCORE_ROOT/bin/console" ] && check_status "Console CLI" "OK" "Available" || check_status "Console CLI" "ERROR" "Missing"
[ -f "$PIMCORE_ROOT/src/Kernel.php" ] && check_status "Kernel" "OK" "Configured" || check_status "Kernel" "ERROR" "Missing"

# Summary
echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                     SUMMARY REPORT                             ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "   ✅ Checks Passed:  $STATUS_OK"
echo "   ⚠️  Warnings:      $STATUS_WARN"
echo "   ❌ Errors:        $STATUS_ERROR"
echo ""

if [ $STATUS_ERROR -eq 0 ]; then
    if [ $STATUS_WARN -eq 0 ]; then
        echo "🎉 ALL SYSTEMS GO! Installation is ready for production."
    else
        echo "⚠️  Installation is operational but review warnings above."
    fi
else
    echo "❌ Installation has errors that need attention."
fi

echo ""
echo "═════════════════════════════════════════════════════════════════"
echo ""
echo "🔍 Quick Links:"
echo "   • Admin Login:     /admin/login"
echo "   • Dashboard:       /admin/"
echo "   • Health Check:    /health"
echo "   • Logs:            var/logs/"
echo "   • Config:          config/packages/"
echo ""
echo "📚 Documentation:"
echo "   • Maintenance Report: MAINTENANCE_REPORT.md"
echo "   • Pimcore Docs:     https://pimcore.com/en/docs"
echo ""
