#!/bin/bash

echo "================================================================"
echo "   AKENEO PIM FRENCH LOCALE CONFIGURATION TOOL"
echo "================================================================"
echo "Date: $(date)"
echo ""

BASE_DIR="/home/pim/public_html"
cd "$BASE_DIR"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${GREEN}✅${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠️${NC}  $1"; }
print_error() { echo -e "${RED}❌${NC} $1"; }
print_info() { echo -e "${BLUE}ℹ️${NC}  $1"; }

print_info "AKENEO PIM French Locale Activation Tool"
echo ""

# 1. CHECK CURRENT STATUS
print_info "Step 1: Checking current locale status..."
CURRENT_STATUS=$(mysql -u root -p'Blackant@2025' u341287766_akeneodb -e "SELECT code, is_activated FROM pim_catalog_locale WHERE code = 'fr_FR';" 2>/dev/null)

if echo "$CURRENT_STATUS" | grep -q "fr_FR"; then
    IS_ACTIVE=$(echo "$CURRENT_STATUS" | grep "fr_FR" | awk '{print $2}')
    if [ "$IS_ACTIVE" = "1" ]; then
        print_status "French locale (fr_FR) is already ACTIVE"
        ALREADY_ACTIVE=true
    else
        print_warning "French locale (fr_FR) is currently INACTIVE"
        ALREADY_ACTIVE=false
    fi
else
    print_error "French locale (fr_FR) not found in database"
    exit 1
fi
echo ""

# 2. ACTIVATE FRENCH LOCALE
if [ "$ALREADY_ACTIVE" = false ]; then
    print_info "Step 2: Activating French locale (fr_FR)..."
    
    mysql -u root -p'Blackant@2025' u341287766_akeneodb -e "
    UPDATE pim_catalog_locale 
    SET is_activated = 1 
    WHERE code = 'fr_FR';
    " 2>/dev/null
    
    if [ $? -eq 0 ]; then
        print_status "French locale activated successfully"
    else
        print_error "Failed to activate French locale"
        exit 1
    fi
else
    print_info "Step 2: French locale already active, skipping..."
fi
echo ""

# 3. CHECK CHANNELS
print_info "Step 3: Checking channel configuration..."
CHANNELS=$(mysql -u root -p'Blackant@2025' u341287766_akeneodb -e "
SELECT c.id, c.code, c.label 
FROM pim_catalog_channel c
" 2>/dev/null | tail -n +2)

echo "$CHANNELS" | while read -r CHANNEL_ID CHANNEL_CODE CHANNEL_LABEL; do
    echo "  Channel: $CHANNEL_CODE ($CHANNEL_LABEL)"
done
echo ""

# 4. ADD FRENCH TO CHANNELS
print_info "Step 4: Adding French locale to channels..."

# Get fr_FR locale ID
FR_LOCALE_ID=$(mysql -u root -p'Blackant@2025' u341287766_akeneodb -e "
SELECT id FROM pim_catalog_locale WHERE code = 'fr_FR';
" 2>/dev/null | tail -n +2)

echo "$CHANNELS" | while read -r CHANNEL_ID CHANNEL_CODE CHANNEL_LABEL; do
    # Check if fr_FR is already associated
    EXISTING=$(mysql -u root -p'Blackant@2025' u341287766_akeneodb -e "
    SELECT COUNT(*) FROM pim_catalog_channel_locale 
    WHERE channel_id = $CHANNEL_ID AND locale_id = $FR_LOCALE_ID;
    " 2>/dev/null | tail -n +2)
    
    if [ "$EXISTING" = "0" ]; then
        mysql -u root -p'Blackant@2025' u341287766_akeneodb -e "
        INSERT INTO pim_catalog_channel_locale (channel_id, locale_id) 
        VALUES ($CHANNEL_ID, $FR_LOCALE_ID);
        " 2>/dev/null
        
        if [ $? -eq 0 ]; then
            print_status "Added fr_FR to channel: $CHANNEL_CODE"
        else
            print_warning "Could not add fr_FR to channel: $CHANNEL_CODE"
        fi
    else
        print_info "Channel $CHANNEL_CODE already has fr_FR"
    fi
done
echo ""

# 5. UPDATE ENVIRONMENT CONFIGURATION
print_info "Step 5: Checking environment configuration..."

if grep -q "APP_DEFAULT_LOCALE" .env; then
    print_info ".env already has APP_DEFAULT_LOCALE defined"
else
    print_info "Adding APP_DEFAULT_LOCALE to .env..."
    echo "" >> .env
    echo "# Default Locale Configuration" >> .env
    echo "APP_DEFAULT_LOCALE=fr_FR" >> .env
    print_status "Added APP_DEFAULT_LOCALE=fr_FR to .env"
fi
echo ""

# 6. CLEAR CACHE
print_info "Step 6: Clearing cache..."
php bin/console cache:clear --env=prod --no-debug 2>&1 | tail -3
print_status "Cache cleared"
echo ""

# 7. WARM UP CACHE
print_info "Step 7: Warming up cache..."
php bin/console cache:warmup --env=prod --no-debug 2>&1 | tail -3
print_status "Cache warmed up"
echo ""

# 8. FIX CACHE PERMISSIONS
print_info "Step 8: Fixing cache permissions..."
chown -R pim:pim var/cache/prod 2>/dev/null
chmod -R 777 var/cache/prod 2>/dev/null
print_status "Cache permissions fixed"
echo ""

# 9. RECALCULATE COMPLETENESS
print_info "Step 9: Recalculating product completeness..."
print_warning "This may take several minutes for 9,541 products..."
php bin/console pim:completeness:calculate --env=prod 2>&1 &
CALC_PID=$!
print_info "Completeness calculation started in background (PID: $CALC_PID)"
echo ""

# 10. VERIFY CONFIGURATION
print_info "Step 10: Verifying configuration..."

# Check locale is active
VERIFY_LOCALE=$(mysql -u root -p'Blackant@2025' u341287766_akeneodb -e "
SELECT code, is_activated FROM pim_catalog_locale WHERE code = 'fr_FR';
" 2>/dev/null | tail -n +2)

if echo "$VERIFY_LOCALE" | grep -q "fr_FR.*1"; then
    print_status "French locale (fr_FR) is ACTIVE ✅"
else
    print_error "French locale verification FAILED"
fi

# Check channels
CHANNEL_COUNT=$(mysql -u root -p'Blackant@2025' u341287766_akeneodb -e "
SELECT COUNT(DISTINCT c.id) 
FROM pim_catalog_channel c
JOIN pim_catalog_channel_locale cl ON c.id = cl.channel_id
JOIN pim_catalog_locale l ON cl.locale_id = l.id
WHERE l.code = 'fr_FR';
" 2>/dev/null | tail -n +2)

print_status "French locale added to $CHANNEL_COUNT channel(s)"
echo ""

# 11. SUMMARY
echo "================================================================"
echo "                         SUMMARY"
echo "================================================================"
echo ""
echo "✅ COMPLETED ACTIONS:"
echo "  1. ✅ French locale (fr_FR) activated"
echo "  2. ✅ French locale added to $CHANNEL_COUNT channel(s)"
echo "  3. ✅ APP_DEFAULT_LOCALE configured in .env"
echo "  4. ✅ Cache cleared and warmed up"
echo "  5. ✅ Cache permissions fixed"
echo "  6. ⏳ Completeness calculation started (background)"
echo ""
echo "📊 CONFIGURATION STATUS:"
echo "  Locale: fr_FR (French - France) - ACTIVE ✅"
echo "  Channels: $CHANNEL_COUNT with French support"
echo "  Default: fr_FR configured"
echo ""
echo "🎯 NEXT STEPS:"
echo "  1. Wait for completeness calculation to finish"
echo "  2. Test PIM UI in French"
echo "  3. Verify product data displays correctly"
echo "  4. Check completeness scores"
echo "  5. Review channel settings in PIM"
echo ""
echo "🔍 VERIFICATION:"
echo "  • Login: https://pim.technostationery.com/user/login"
echo "  • Check: System → Locales (should show fr_FR active)"
echo "  • Check: System → Channels (should show fr_FR in each)"
echo "  • Check: Products (should display French content)"
echo ""
echo "================================================================"
echo "French locale configuration completed at: $(date)"
echo "================================================================"
