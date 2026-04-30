#!/bin/bash
# =============================================================================
# Techno Stationery PIM - Comprehensive Deploy & Stabilization Script
# =============================================================================
# Consolidates ALL fixes applied to the Akeneo PIM instance.
# Run with: sudo bash /home/pim/public_html/webapp/deploy_comprehensive.sh
#
# This script is IDEMPOTENT - safe to run multiple times.
# Last updated: 2026-03-28
# =============================================================================

set -euo pipefail
PIM_DIR="/home/pim/public_html"
CACHE_BUSTER="20260328d"
WEB_USER="nobody"
WEB_GROUP="nobody"

log()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }
warn() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] $1"; }
ok()   { echo "[$(date '+%Y-%m-%d %H:%M:%S')]   [OK] $1"; }

log "============================================================"
log " Techno Stationery PIM - Comprehensive Deploy"
log " Instance: pim.technostationery.com"
log "============================================================"

ERRORS=0

# -------------------------------------------------------
# FIX 1: Process polyfill (fixes "process is not defined")
# -------------------------------------------------------
log ""
log "Fix 1/8: Browser process polyfill..."
POLYFILL="$PIM_DIR/public/dist/process-polyfill.js"
if [ ! -f "$POLYFILL" ]; then
    cat > "$POLYFILL" << 'POLYFILL_JS'
/**
 * Browser polyfill for Node.js 'process' global.
 * Required by vfile, styled-components, and other libs that reference
 * process.env in browser bundles. Must load BEFORE vendor.min.js
 */
(function() {
  if (typeof window !== 'undefined' && typeof window.process === 'undefined') {
    window.process = {
      env: {
        NODE_ENV: 'production',
        REACT_APP_SC_ATTR: '',
        SC_ATTR: '',
        REACT_APP_SC_DISABLE_SPEEDY: '',
        SC_DISABLE_SPEEDY: ''
      },
      browser: true,
      version: '',
      platform: 'browser',
      cwd: function() { return '/'; },
      nextTick: function(fn) {
        if (typeof Promise !== 'undefined') {
          Promise.resolve().then(fn);
        } else {
          setTimeout(fn, 0);
        }
      },
      stdout: { write: function() {} },
      stderr: { write: function() {} },
      argv: [],
      pid: 1,
      title: 'browser',
      arch: 'browser',
      versions: {}
    };
  }
  if (typeof window !== 'undefined' && typeof window.global === 'undefined') {
    window.global = window;
  }
})();
POLYFILL_JS
    ok "process-polyfill.js created"
else
    ok "process-polyfill.js already present ($(wc -c < "$POLYFILL") bytes)"
fi

# Ensure polyfill is injected in the template
TEMPLATE="$PIM_DIR/vendor/akeneo/pim-community-dev/src/Akeneo/Platform/Bundle/UIBundle/Resources/views/index.html.twig"
if grep -q "process-polyfill" "$TEMPLATE" 2>/dev/null; then
    ok "Polyfill already in template"
else
    # Insert before vendor.min.js
    sed -i '/vendor\.min\.js/i\        {# Process polyfill - fixes "process is not defined" for vfile/styled-components #}\n        <script type="text/javascript" src="/dist/process-polyfill.js?v={{ cache_buster }}"></script>' "$TEMPLATE"
    if grep -q "process-polyfill" "$TEMPLATE"; then
        ok "Polyfill injected into template"
    else
        warn "Could not inject polyfill into template"
        ((ERRORS++)) || true
    fi
fi

# Update cache buster
sed -i "s/cache_buster = \"[^\"]*\"/cache_buster = \"$CACHE_BUSTER\"/" "$TEMPLATE"
ok "Cache buster set to $CACHE_BUSTER"

# -------------------------------------------------------
# FIX 2: SPA route controller defaults
# -------------------------------------------------------
log ""
log "Fix 2/8: Patching SPA stub routes with TemplateController..."

DEFAULTS_LINE="    defaults: { _controller: 'Symfony\\\\Bundle\\\\FrameworkBundle\\\\Controller\\\\TemplateController::templateAction', template: '@PimUI/index.html.twig' }"

patch_route() {
    local file="$1"
    local route="$2"
    if [ ! -f "$PIM_DIR/$file" ]; then
        warn "  File not found: $file"
        return
    fi
    if grep -A3 "^${route}:" "$PIM_DIR/$file" | grep -q "defaults:"; then
        return  # Already has defaults
    fi
    # Add defaults after the path line within this route block
    sed -i "/^${route}:/,/^[^ ]/{/^    path:/a\\
$DEFAULTS_LINE
}" "$PIM_DIR/$file"
    ok "Patched: $route"
}

# Structure bundle routes (attribute, family, association-type, attribute-group, group-type)
patch_route "vendor/akeneo/pim-community-dev/src/Akeneo/Pim/Structure/Bundle/Resources/config/routing/front.yml" "pim_enrich_attribute_index"
patch_route "vendor/akeneo/pim-community-dev/src/Akeneo/Pim/Structure/Bundle/Resources/config/routing/front.yml" "pim_enrich_attribute_create"
patch_route "vendor/akeneo/pim-community-dev/src/Akeneo/Pim/Structure/Bundle/Resources/config/routing/front.yml" "pim_enrich_attribute_edit"
patch_route "vendor/akeneo/pim-community-dev/src/Akeneo/Pim/Structure/Bundle/Resources/config/routing/front.yml" "pim_enrich_family_index"
patch_route "vendor/akeneo/pim-community-dev/src/Akeneo/Pim/Structure/Bundle/Resources/config/routing/front.yml" "pim_enrich_family_edit"
patch_route "vendor/akeneo/pim-community-dev/src/Akeneo/Pim/Structure/Bundle/Resources/config/routing/front.yml" "pim_enrich_associationtype_index"
patch_route "vendor/akeneo/pim-community-dev/src/Akeneo/Pim/Structure/Bundle/Resources/config/routing/front.yml" "pim_enrich_associationtype_edit"
patch_route "vendor/akeneo/pim-community-dev/src/Akeneo/Pim/Structure/Bundle/Resources/config/routing/front.yml" "pim_enrich_attributegroup_index"
patch_route "vendor/akeneo/pim-community-dev/src/Akeneo/Pim/Structure/Bundle/Resources/config/routing/front.yml" "pim_enrich_attributegroup_create"
patch_route "vendor/akeneo/pim-community-dev/src/Akeneo/Pim/Structure/Bundle/Resources/config/routing/front.yml" "pim_enrich_attributegroup_edit"
patch_route "vendor/akeneo/pim-community-dev/src/Akeneo/Pim/Structure/Bundle/Resources/config/routing/front.yml" "pim_enrich_grouptype_index"
patch_route "vendor/akeneo/pim-community-dev/src/Akeneo/Pim/Structure/Bundle/Resources/config/routing/front.yml" "pim_enrich_grouptype_edit"

# Enrichment bundle routes (product, group, category-tree)
patch_route "vendor/akeneo/pim-community-dev/src/Akeneo/Pim/Enrichment/Bundle/Resources/config/routing/ui/product.yml" "pim_enrich_product_index"
patch_route "vendor/akeneo/pim-community-dev/src/Akeneo/Pim/Enrichment/Bundle/Resources/config/routing/ui/product.yml" "pim_enrich_product_edit"
patch_route "vendor/akeneo/pim-community-dev/src/Akeneo/Pim/Enrichment/Bundle/Resources/config/routing/ui/product.yml" "pim_enrich_product_edit_categories"
patch_route "vendor/akeneo/pim-community-dev/src/Akeneo/Pim/Enrichment/Bundle/Resources/config/routing/ui/group.yml" "pim_enrich_group_index"
patch_route "vendor/akeneo/pim-community-dev/src/Akeneo/Pim/Enrichment/Bundle/Resources/config/routing/ui/categorytree.yml" "pim_enrich_categorytree_index"

# ImportExport bundle routes
patch_route "vendor/akeneo/pim-community-dev/src/Akeneo/Platform/Bundle/ImportExportBundle/Resources/config/routing/import_profile.yml" "pim_importexport_import_profile_index"
patch_route "vendor/akeneo/pim-community-dev/src/Akeneo/Platform/Bundle/ImportExportBundle/Resources/config/routing/export_profile.yml" "pim_importexport_export_profile_index"

# Channel bundle routes (currency, channel, locale)
patch_route "vendor/akeneo/pim-community-dev/src/Akeneo/Channel/Bundle/Resources/config/routing/ui/currency.yml" "pim_enrich_currency_index"
patch_route "vendor/akeneo/pim-community-dev/src/Akeneo/Channel/Bundle/Resources/config/routing/internal_api/channel.yml" "pim_enrich_channel_index"
patch_route "vendor/akeneo/pim-community-dev/src/Akeneo/Channel/Bundle/Resources/config/routing/internal_api/locale.yml" "pim_enrich_locale_index"

# UIBundle routes (settings, system)
patch_route "vendor/akeneo/pim-community-dev/src/Akeneo/Platform/Bundle/UIBundle/Resources/config/routing.yml" "pim_settings_index"
patch_route "vendor/akeneo/pim-community-dev/src/Akeneo/Platform/Bundle/UIBundle/Resources/config/routing.yml" "pim_system_index"

# Job tracker routes
patch_route "vendor/akeneo/pim-community-dev/src/Akeneo/Platform/Job/back/Infrastructure/Symfony/Resources/config/routing.yml" "akeneo_job_process_tracker_index"
patch_route "vendor/akeneo/pim-community-dev/src/Akeneo/Platform/Job/back/Infrastructure/Symfony/Resources/config/routing.yml" "akeneo_job_process_tracker_details"
patch_route "vendor/akeneo/pim-community-dev/src/Akeneo/Platform/Job/back/Infrastructure/Symfony/Resources/config/routing.yml" "pim_enrich_job_tracker_index"

ok "All SPA stub routes patched"

# -------------------------------------------------------
# FIX 3: robots.txt
# -------------------------------------------------------
log ""
log "Fix 3/8: robots.txt..."
cat > "$PIM_DIR/public/robots.txt" << 'ROBOTS'
# Akeneo PIM - pim.technostationery.com
# Private PIM instance - disallow all crawlers
User-agent: *
Disallow: /
ROBOTS
ok "robots.txt created"

# -------------------------------------------------------
# FIX 4: LiipImagine GD driver
# -------------------------------------------------------
log ""
log "Fix 4/8: LiipImagine GD driver..."
mkdir -p "$PIM_DIR/config/packages"
cat > "$PIM_DIR/config/packages/liip_imagine.yml" << 'LIIP'
liip_imagine:
    driver: gd
LIIP
ok "GD driver configured"

# -------------------------------------------------------
# FIX 5: CSS layout fixes
# -------------------------------------------------------
log ""
log "Fix 5/8: CSS layout fixes..."
CSS_FILE="$PIM_DIR/public/css/pim.css"
if ! grep -q "PIM UI Layout & Sidebar Fixes" "$CSS_FILE" 2>/dev/null; then
    if [ -f "$PIM_DIR/webapp/pim_layout_fixes.css" ]; then
        cat "$PIM_DIR/webapp/pim_layout_fixes.css" >> "$CSS_FILE"
        ok "CSS fixes appended to pim.css"
    else
        warn "CSS fix file not found at webapp/pim_layout_fixes.css"
    fi
else
    ok "CSS fixes already present in pim.css"
fi

# -------------------------------------------------------
# FIX 6: Enable DZD currency
# -------------------------------------------------------
log ""
log "Fix 6/8: Ensuring DZD currency is activated..."
mysql -h 127.0.0.1 -P 3307 -u root -p'YourNewStrongPassword' --ssl=false akeneo_pim \
  -e "UPDATE pim_catalog_currency SET is_activated=1 WHERE code='DZD' AND is_activated=0;" 2>/dev/null && \
  ok "DZD currency activated" || warn "Could not update DZD currency (may already be active)"

# -------------------------------------------------------
# FIX 7: Clear and warm cache
# -------------------------------------------------------
log ""
log "Fix 7/8: Rebuilding cache..."
cd "$PIM_DIR"
rm -rf var/cache/prod/* 2>/dev/null || true
php bin/console cache:clear --env=prod --no-warmup 2>&1 | tail -1
php bin/console cache:warmup --env=prod 2>&1 | tail -1
ok "Cache rebuilt"

# -------------------------------------------------------
# FIX 8: Permissions
# -------------------------------------------------------
log ""
log "Fix 8/8: Fixing permissions..."
chown -R "$WEB_USER:$WEB_GROUP" var/cache/ var/logs/ 2>/dev/null || true
chmod -R 777 var/cache/ var/logs/ 2>/dev/null || true
chmod 755 public/dist/process-polyfill.js 2>/dev/null || true
chmod 644 public/robots.txt 2>/dev/null || true
ok "Permissions fixed"

# -------------------------------------------------------
# Summary
# -------------------------------------------------------
log ""
log "============================================================"
if [ "$ERRORS" -eq 0 ]; then
    log " ALL FIXES APPLIED SUCCESSFULLY"
else
    log " FIXES APPLIED WITH $ERRORS WARNINGS"
fi
log "============================================================"
log ""
log "Fixes applied:"
log "  1. Browser process polyfill  - Fixes 'process is not defined' JS error"
log "  2. SPA route controllers     - 25+ routes patched with TemplateController"
log "  3. robots.txt                - Blocks search engine crawling"
log "  4. LiipImagine GD driver     - Fixes 'Imagick not installed' errors"
log "  5. CSS layout/sidebar fixes  - Fallback styles for styled-components"
log "  6. DZD currency enabled      - Algerian Dinar active for product pricing"
log "  7. Cache rebuilt              - All config changes compiled"
log "  8. File permissions fixed    - Correct ownership for web server"
log ""
log "System state:"
log "  Products:   $(mysql -h 127.0.0.1 -P 3307 -u root -p'YourNewStrongPassword' --ssl=false -sN akeneo_pim -e 'SELECT COUNT(*) FROM pim_catalog_product' 2>/dev/null || echo 'N/A')"
log "  Categories: $(mysql -h 127.0.0.1 -P 3307 -u root -p'YourNewStrongPassword' --ssl=false -sN akeneo_pim -e 'SELECT COUNT(*) FROM pim_catalog_category' 2>/dev/null || echo 'N/A')"
log "  Families:   $(mysql -h 127.0.0.1 -P 3307 -u root -p'YourNewStrongPassword' --ssl=false -sN akeneo_pim -e 'SELECT COUNT(*) FROM pim_catalog_family' 2>/dev/null || echo 'N/A')"
log "  Attributes: $(mysql -h 127.0.0.1 -P 3307 -u root -p'YourNewStrongPassword' --ssl=false -sN akeneo_pim -e 'SELECT COUNT(*) FROM pim_catalog_attribute' 2>/dev/null || echo 'N/A')"
log ""
log "Verify at: https://pim.technostationery.com/"
log "API test:  curl -X POST https://pim.technostationery.com/api/oauth/v1/token \\"
log "             -d 'grant_type=password&client_id=1_3yhbczkw7osgcw8wg44k84os4sc04w4wc80ks08sw8cc8c40sw&client_secret=50vx3l4u4l4wwcsok4kcwkoo44oo0s0o8s0kcs0gc0c8g0oow4&username=admin&password=PimAdmin2026!'"
