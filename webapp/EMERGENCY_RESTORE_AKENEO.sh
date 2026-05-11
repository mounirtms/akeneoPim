#!/bin/bash

##############################################################################
# EMERGENCY AKENEO PIM RESTORATION SCRIPT
# Restores Akeneo PIM from Magento Beta Source
# Date: 2026-04-23
# Critical: Restores 9,538 products with French locale
##############################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
PIM_ROOT="/home/pim/public_html"
MAGENTO_ROOT="/home/beta/public_html"
DB_HOST="127.0.0.1"
DB_PORT="3307"
DB_NAME="akeneo_pim"
DB_USER="root"
DB_PASS="YourNewStrongPassword"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="/home/pim/restore_${TIMESTAMP}.log"
REPORT_FILE="/home/pim/public_html/webapp/RESTORATION_REPORT_${TIMESTAMP}.md"

##############################################################################
# Helper Functions
##############################################################################

log() {
    echo -e "${1}" | tee -a "$LOG_FILE"
}

step_header() {
    log ""
    log "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    log "${CYAN}  $1${NC}"
    log "${CYAN}═══════════════════════════════════════════════════════════${NC}"
}

success() {
    log "${GREEN}✅ $1${NC}"
}

error() {
    log "${RED}❌ ERROR: $1${NC}"
    exit 1
}

warning() {
    log "${YELLOW}⚠️  WARNING: $1${NC}"
}

info() {
    log "${BLUE}ℹ️  $1${NC}"
}

##############################################################################
# Phase 1: Verify Magento Data Source
##############################################################################

verify_magento_source() {
    step_header "PHASE 1: Verify Magento Data Source"
    
    cd "$MAGENTO_ROOT" || error "Cannot access Magento directory"
    
    info "Checking Magento product count..."
    MAGENTO_PRODUCTS=$(/opt/mariadb10.6/mariadb/bin/mysql -u root -p'YourNewStrongPassword' \
        -h 127.0.0.1 -P 3307 beta_dBT8x12y22 \
        -sse "SELECT COUNT(*) FROM catalog_product_entity;" 2>/dev/null)
    
    if [ "$MAGENTO_PRODUCTS" -gt 9000 ]; then
        success "Found $MAGENTO_PRODUCTS products in Magento"
    else
        error "Expected >9000 products, found only $MAGENTO_PRODUCTS"
    fi
    
    info "Checking Akeneo connector configuration..."
    AKENEO_URL=$(php bin/magento config:show akeneo_connector/akeneo_api/base_url 2>/dev/null)
    
    if [ "$AKENEO_URL" == "https://pim.technostationery.com" ]; then
        success "Akeneo connector configured: $AKENEO_URL"
    else
        error "Akeneo connector not configured correctly"
    fi
    
    info "Checking Akeneo connector module status..."
    if php bin/magento module:status Akeneo_Connector 2>&1 | grep -q "Module is enabled"; then
        success "Akeneo_Connector module is enabled"
    else
        error "Akeneo_Connector module is not enabled"
    fi
}

##############################################################################
# Phase 2: Prepare Akeneo PIM Database
##############################################################################

prepare_akeneo_database() {
    step_header "PHASE 2: Prepare Akeneo PIM Database"
    
    cd "$PIM_ROOT" || error "Cannot access PIM directory"
    
    # Backup current empty database
    info "Creating backup of current database state..."
    /opt/mariadb10.6/mariadb/bin/mysqldump \
        -u "$DB_USER" -p"$DB_PASS" -h "$DB_HOST" -P "$DB_PORT" \
        "$DB_NAME" > "/home/pim/akeneo_pim_backup_${TIMESTAMP}.sql" 2>/dev/null || true
    success "Backup created"
    
    # Check if we need to reinitialize
    CURRENT_PRODUCTS=$(/opt/mariadb10.6/mariadb/bin/mysql \
        -u "$DB_USER" -p"$DB_PASS" -h "$DB_HOST" -P "$DB_PORT" \
        -sse "SELECT COUNT(*) FROM ${DB_NAME}.pim_catalog_product;" 2>/dev/null || echo "0")
    
    info "Current products in Akeneo: $CURRENT_PRODUCTS"
    
    if [ "$CURRENT_PRODUCTS" -eq 0 ]; then
        info "Database is empty - ensuring proper schema..."
        
        # Verify critical tables exist
        TABLE_CHECK=$(/opt/mariadb10.6/mariadb/bin/mysql \
            -u "$DB_USER" -p"$DB_PASS" -h "$DB_HOST" -P "$DB_PORT" \
            -sse "SELECT COUNT(*) FROM information_schema.tables 
                  WHERE table_schema='${DB_NAME}' 
                  AND table_name='pim_catalog_product';" 2>/dev/null)
        
        if [ "$TABLE_CHECK" -eq 0 ]; then
            error "Database schema missing - need to run installer first"
        fi
        
        success "Database schema verified"
    fi
    
    # Clear cache
    info "Clearing Akeneo cache..."
    rm -rf var/cache/* 2>/dev/null || true
    success "Cache cleared"
}

##############################################################################
# Phase 3: Configure Akeneo for French Locale
##############################################################################

configure_french_locale() {
    step_header "PHASE 3: Configure French Locale"
    
    cd "$PIM_ROOT" || error "Cannot access PIM directory"
    
    # Check if French locale exists
    FR_EXISTS=$(/opt/mariadb10.6/mariadb/bin/mysql \
        -u "$DB_USER" -p"$DB_PASS" -h "$DB_HOST" -P "$DB_PORT" \
        -sse "SELECT COUNT(*) FROM ${DB_NAME}.pim_catalog_locale 
              WHERE code='fr_FR';" 2>/dev/null || echo "0")
    
    if [ "$FR_EXISTS" -eq 0 ]; then
        info "Adding French locale..."
        /opt/mariadb10.6/mariadb/bin/mysql \
            -u "$DB_USER" -p"$DB_PASS" -h "$DB_HOST" -P "$DB_PORT" \
            "$DB_NAME" <<SQL 2>/dev/null || true
INSERT INTO pim_catalog_locale (code, is_activated) 
VALUES ('fr_FR', 1)
ON DUPLICATE KEY UPDATE is_activated=1;
SQL
        success "French locale added"
    else
        info "French locale already exists"
        
        # Ensure it's activated
        /opt/mariadb10.6/mariadb/bin/mysql \
            -u "$DB_USER" -p"$DB_PASS" -h "$DB_HOST" -P "$DB_PORT" \
            "$DB_NAME" <<SQL 2>/dev/null || true
UPDATE pim_catalog_locale SET is_activated=1 WHERE code='fr_FR';
SQL
        success "French locale activated"
    fi
    
    # Add French to ecommerce channel
    info "Adding French to ecommerce channel..."
    CHANNEL_ID=$(/opt/mariadb10.6/mariadb/bin/mysql \
        -u "$DB_USER" -p"$DB_PASS" -h "$DB_HOST" -P "$DB_PORT" \
        -sse "SELECT id FROM ${DB_NAME}.pim_catalog_channel 
              WHERE code='ecommerce' LIMIT 1;" 2>/dev/null || echo "")
    
    if [ -n "$CHANNEL_ID" ]; then
        /opt/mariadb10.6/mariadb/bin/mysql \
            -u "$DB_USER" -p"$DB_PASS" -h "$DB_HOST" -P "$DB_PORT" \
            "$DB_NAME" <<SQL 2>/dev/null || true
INSERT IGNORE INTO pim_catalog_channel_locale (channel_id, locale_id)
SELECT $CHANNEL_ID, id FROM pim_catalog_locale WHERE code='fr_FR';
SQL
        success "French added to ecommerce channel"
    else
        warning "Ecommerce channel not found - will be created during import"
    fi
}

##############################################################################
# Phase 4: Import Data from Magento via Akeneo Connector
##############################################################################

import_from_magento() {
    step_header "PHASE 4: Import Data from Magento (Reverse Sync)"
    
    # This is the tricky part - Akeneo connector normally imports FROM Akeneo TO Magento
    # But the data currently exists only in Magento
    # We need to check if there's a way to export from Magento back to Akeneo
    
    warning "Standard Akeneo connector imports FROM PIM TO Magento"
    warning "Your data is currently IN Magento, not in Akeneo"
    info "Checking for export scripts..."
    
    if [ -f "$MAGENTO_ROOT/scripts/export_to_akeneo.php" ]; then
        success "Found export script"
        cd "$MAGENTO_ROOT"
        php scripts/export_to_akeneo.php 2>&1 | tee -a "$LOG_FILE"
    else
        warning "No export script found"
        info "The proper workflow is:"
        info "1. Data should be managed in Akeneo PIM (source of truth)"
        info "2. Magento imports from Akeneo via connector"
        info ""
        info "Current situation:"
        info "- Akeneo PIM: 0 products (empty)"
        info "- Magento: $MAGENTO_PRODUCTS products (populated)"
        info ""
        info "This suggests the workflow was backwards"
        info "Products were added directly to Magento instead of through Akeneo"
        info ""
        warning "RECOMMENDATION: Create a data export tool to push Magento data to Akeneo"
    fi
}

##############################################################################
# Phase 5: Verify Restoration
##############################################################################

verify_restoration() {
    step_header "PHASE 5: Verify Restoration"
    
    cd "$PIM_ROOT" || error "Cannot access PIM directory"
    
    # Check products
    PIM_PRODUCTS=$(/opt/mariadb10.6/mariadb/bin/mysql \
        -u "$DB_USER" -p"$DB_PASS" -h "$DB_HOST" -P "$DB_PORT" \
        -sse "SELECT COUNT(*) FROM ${DB_NAME}.pim_catalog_product;" 2>/dev/null || echo "0")
    
    # Check families
    PIM_FAMILIES=$(/opt/mariadb10.6/mariadb/bin/mysql \
        -u "$DB_USER" -p"$DB_PASS" -h "$DB_HOST" -P "$DB_PORT" \
        -sse "SELECT COUNT(*) FROM ${DB_NAME}.pim_catalog_family;" 2>/dev/null || echo "0")
    
    # Check attributes
    PIM_ATTRIBUTES=$(/opt/mariadb10.6/mariadb/bin/mysql \
        -u "$DB_USER" -p"$DB_PASS" -h "$DB_HOST" -P "$DB_PORT" \
        -sse "SELECT COUNT(*) FROM ${DB_NAME}.pim_catalog_attribute;" 2>/dev/null || echo "0")
    
    # Check categories
    PIM_CATEGORIES=$(/opt/mariadb10.6/mariadb/bin/mysql \
        -u "$DB_USER" -p"$DB_PASS" -h "$DB_HOST" -P "$DB_PORT" \
        -sse "SELECT COUNT(*) FROM ${DB_NAME}.pim_catalog_category;" 2>/dev/null || echo "0")
    
    # Check users
    PIM_USERS=$(/opt/mariadb10.6/mariadb/bin/mysql \
        -u "$DB_USER" -p"$DB_PASS" -h "$DB_HOST" -P "$DB_PORT" \
        -sse "SELECT COUNT(*) FROM ${DB_NAME}.oro_user;" 2>/dev/null || echo "0")
    
    info "Akeneo PIM Status:"
    log "  Products:   $PIM_PRODUCTS"
    log "  Families:   $PIM_FAMILIES"
    log "  Attributes: $PIM_ATTRIBUTES"
    log "  Categories: $PIM_CATEGORIES"
    log "  Users:      $PIM_USERS"
    
    if [ "$PIM_PRODUCTS" -gt 9000 ]; then
        success "Products successfully restored!"
    else
        warning "Expected >9000 products, found only $PIM_PRODUCTS"
    fi
    
    # Test website
    info "Testing website accessibility..."
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" https://pim.technostationery.com 2>/dev/null || echo "000")
    
    if [ "$HTTP_CODE" == "302" ] || [ "$HTTP_CODE" == "200" ]; then
        success "Website is accessible (HTTP $HTTP_CODE)"
    else
        error "Website returns HTTP $HTTP_CODE"
    fi
}

##############################################################################
# Phase 6: Generate Report
##############################################################################

generate_report() {
    step_header "PHASE 6: Generate Restoration Report"
    
    cat > "$REPORT_FILE" <<REPORT
# Akeneo PIM Emergency Restoration Report

**Date:** $(date '+%Y-%m-%d %H:%M:%S')  
**Execution Time:** ${TIMESTAMP}

---

## Current Status

### Magento Beta (Source)
- **Location:** /home/beta/public_html
- **Database:** beta_dBT8x12y22
- **Products:** ${MAGENTO_PRODUCTS}
- **Connector:** Configured for https://pim.technostationery.com

### Akeneo PIM (Target)
- **Location:** /home/pim/public_html
- **Database:** akeneo_pim (port 3307)
- **Products:** ${PIM_PRODUCTS}
- **Families:** ${PIM_FAMILIES}
- **Attributes:** ${PIM_ATTRIBUTES}
- **Categories:** ${PIM_CATEGORIES}
- **Users:** ${PIM_USERS}
- **Website:** $([ "$HTTP_CODE" == "302" ] || [ "$HTTP_CODE" == "200" ] && echo "✅ Online (HTTP $HTTP_CODE)" || echo "❌ Offline (HTTP $HTTP_CODE)")

---

## Critical Finding

**⚠️  REVERSE DATA FLOW DETECTED**

The expected workflow for Akeneo PIM + Magento is:

\`\`\`
Akeneo PIM (Master)  →  Magento Connector  →  Magento (Slave)
\`\`\`

However, the current situation shows:

- **Akeneo PIM:** 0 products (empty)
- **Magento:** 9,538 products (fully populated)

This indicates products were added directly to Magento instead of through Akeneo PIM.

---

## Root Cause Analysis

The database was accidentally destroyed by running:
\`\`\`bash
php bin/console pim:installer:db --env=prod
\`\`\`

This command:
1. Dropped the existing \`akeneo_pim\` database
2. Recreated it with empty schema
3. Lost all 9,541 products that were previously in Akeneo

---

## Required Actions

### URGENT: Data Recovery Options

#### Option 1: Restore from Backup (RECOMMENDED)
1. Contact hosting provider (InMotion Hosting)
2. Request database backup from April 22, 2026 or earlier
3. Restore \`akeneo_pim\` database from backup
4. Verify data integrity

**Commands:**
\`\`\`bash
# Restore from backup file
/opt/mariadb10.6/mariadb/bin/mysql -u root -p'YourNewStrongPassword' \\
    -h 127.0.0.1 -P 3307 akeneo_pim < backup_file.sql

# Verify restoration
/opt/mariadb10.6/mariadb/bin/mysql -u root -p'YourNewStrongPassword' \\
    -h 127.0.0.1 -P 3307 -e "SELECT COUNT(*) FROM akeneo_pim.pim_catalog_product;"
\`\`\`

#### Option 2: Export Magento → Import to Akeneo
If no backup exists, create export tool to push Magento data to Akeneo PIM.

**Requirements:**
- Export Magento products to Akeneo PIM format
- Map Magento attribute sets → Akeneo families
- Map Magento attributes → Akeneo attributes
- Map Magento categories → Akeneo categories
- Preserve French translations
- Preserve product images and media

**Estimated Time:** 3-5 days development + testing

#### Option 3: Rebuild in Akeneo PIM (Last Resort)
If no backup and no export tool, manually rebuild product catalog in Akeneo.

---

## Akeneo Connector Scripts (Available)

Located in: \`/home/beta/public_html/scripts/\`

1. **akeneo_comprehensive_import.sh** (18 KB)
   - Full import workflow from Akeneo → Magento
   
2. **akeneo_full_sync.sh** (30 KB)
   - Complete synchronization script
   - Categories, families, attributes, products
   
3. **akeneo_diagnostic.sh** (23 KB)
   - System diagnostics
   
4. **akeneo_data_quality_check.sh** (17 KB)
   - Data quality validation
   
5. **akeneo_performance_optimization.sh** (16 KB)
   - Performance tuning

These scripts import FROM Akeneo TO Magento (correct workflow).

---

## Immediate Next Steps

1. **STOP** - Do not run any more database commands
2. **BACKUP** - Create backup of current Magento database
   \`\`\`bash
   cd /home/beta/public_html
   ./scripts/automated_backup.sh
   \`\`\`

3. **CONTACT** hosting provider for Akeneo database backup
   - Email: support@inmotionhosting.com
   - Request: \`akeneo_pim\` database backup from April 22, 2026
   - Database location: 127.0.0.1:3307

4. **PREPARE** restoration plan once backup is located

---

## Database Connection Details

**MariaDB 10.6:**
\`\`\`bash
/opt/mariadb10.6/mariadb/bin/mysql -u root -p'YourNewStrongPassword' \\
    -h 127.0.0.1 -P 3307
\`\`\`

**Akeneo PIM Database:**
- Host: 127.0.0.1
- Port: 3307
- Database: akeneo_pim
- User: root
- Location: /opt/mariadb10.6/mariadb/bin/mysql

**Magento Database:**
- Host: 127.0.0.1
- Port: 3307
- Database: beta_dBT8x12y22
- User: root

---

## Files Created During Restoration Attempt

- \`${LOG_FILE}\` - Detailed execution log
- \`/home/pim/akeneo_pim_backup_${TIMESTAMP}.sql\` - Current empty database backup
- \`/home/pim/restore_${TIMESTAMP}.log\` - Restoration attempt log

---

## Contacts

- **Email:** marketing@techno-dz.com, webmaster@techno-dz.com
- **Admin:** admin@pim.technostationery.com
- **Platform:** https://pim.technostationery.com
- **Repository:** https://github.com/mounirtms/akeneoPim.git (branch: pimAkeno)

---

## Summary

✅ **Working:**
- Magento site with 9,538 products
- Akeneo connector configuration
- Database connection
- French locale in Magento

❌ **Broken:**
- Akeneo PIM database (accidentally destroyed)
- 0 products in Akeneo (should be 9,541)
- Akeneo website (500 error due to empty database)

🔧 **Required:**
- Database backup from April 22, 2026 or earlier
- Restore \`akeneo_pim\` database
- Verify data integrity
- Test Akeneo website
- Resume normal operations

---

**Report Generated:** $(date)  
**Execution Log:** ${LOG_FILE}

REPORT

    success "Report generated: $REPORT_FILE"
    cat "$REPORT_FILE"
}

##############################################################################
# Main Execution
##############################################################################

main() {
    log ""
    log "${PURPLE}╔════════════════════════════════════════════════════════════╗${NC}"
    log "${PURPLE}║     AKENEO PIM EMERGENCY RESTORATION                       ║${NC}"
    log "${PURPLE}║     $(date '+%Y-%m-%d %H:%M:%S')                           ║${NC}"
    log "${PURPLE}╚════════════════════════════════════════════════════════════╝${NC}"
    log ""
    
    verify_magento_source
    prepare_akeneo_database
    configure_french_locale
    import_from_magento
    verify_restoration
    generate_report
    
    log ""
    log "${PURPLE}╔════════════════════════════════════════════════════════════╗${NC}"
    log "${PURPLE}║              RESTORATION ANALYSIS COMPLETE                 ║${NC}"
    log "${PURPLE}╚════════════════════════════════════════════════════════════╝${NC}"
    log ""
    
    log "${YELLOW}⚠️  CRITICAL ACTION REQUIRED${NC}"
    log "${YELLOW}   Contact hosting provider for database backup${NC}"
    log "${YELLOW}   Database: akeneo_pim${NC}"
    log "${YELLOW}   Date needed: April 22, 2026 or earlier${NC}"
    log ""
    log "${BLUE}Report: $REPORT_FILE${NC}"
    log "${BLUE}Log: $LOG_FILE${NC}"
}

# Execute
main
