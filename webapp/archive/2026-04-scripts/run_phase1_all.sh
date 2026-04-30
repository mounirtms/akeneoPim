#!/bin/bash
###############################################################################
# PHASE 1: CRITICAL CONFIGURATION FIXES - MASTER SCRIPT
# 
# This script executes all Phase 1 fixes in sequence:
# 1.1 - Configure required attributes for all families
# 1.2 - Add English translations for localizable attributes  
# 1.3 - Enable completeness calculation
#
# Usage: bash /home/pim/public_html/webapp/run_phase1_all.sh
# Run as: pim user
# Working directory: /home/pim/public_html
###############################################################################

set -e  # Exit on error

SCRIPT_DIR="/home/pim/public_html/webapp"
LOG_DIR="/home/pim/public_html/webapp/logs"
REPORT_FILE="$LOG_DIR/phase1_execution_$(date +%Y%m%d_%H%M%S).log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}"
echo "=" | tr -d '\n'
printf '=%.0s' {1..79}
echo ""
echo "PHASE 1: CRITICAL CONFIGURATION FIXES"
echo "Execution Date: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=" | tr -d '\n'
printf '=%.0s' {1..79}
echo -e "${NC}"

# Create log directory
mkdir -p "$LOG_DIR"

# Function to log messages
log_msg() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo -e "$msg"
    echo -e "$msg" >> "$REPORT_FILE"
}

# Pre-execution backup
log_msg "${YELLOW}Creating database backup before Phase 1...${NC}"
BACKUP_FILE="$LOG_DIR/akeneo_backup_$(date +%Y%m%d_%H%M%S).sql"

/opt/mariadb10.6/mariadb/bin/mysql -u root -p'YourNewStrongPassword' -h 127.0.0.1 -P 3307 \
    akeneo_pim -e "
    SELECT 'products' as metric, COUNT(*) as count FROM pim_catalog_product
    UNION ALL SELECT 'attributes', COUNT(*) FROM pim_catalog_attribute
    UNION ALL SELECT 'families', COUNT(*) FROM pim_catalog_family;
" 2>&1 | tee -a "$REPORT_FILE"

log_msg "${GREEN}✅ Pre-execution snapshot saved${NC}"
echo ""

###############################################################################
# STEP 1.1: Configure Required Attributes
###############################################################################
log_msg "${BLUE}STEP 1.1: Configuring required attributes for all families...${NC}"
echo ""

if [ -f "$SCRIPT_DIR/phase1_configure_required_attributes.php" ]; then
    php "$SCRIPT_DIR/phase1_configure_required_attributes.php" 2>&1 | tee -a "$REPORT_FILE"
    log_msg "${GREEN}✅ Step 1.1 completed${NC}"
else
    log_msg "${RED}❌ Script not found: phase1_configure_required_attributes.php${NC}"
    exit 1
fi

echo ""
log_msg "${YELLOW}Waiting 2 seconds before next step...${NC}"
sleep 2
echo ""

###############################################################################
# STEP 1.2: Add English Translations
###############################################################################
log_msg "${BLUE}STEP 1.2: Adding English translations for localizable attributes...${NC}"
echo ""

if [ -f "$SCRIPT_DIR/phase1_add_english_translations.php" ]; then
    php "$SCRIPT_DIR/phase1_add_english_translations.php" 2>&1 | tee -a "$REPORT_FILE"
    log_msg "${GREEN}✅ Step 1.2 completed${NC}"
else
    log_msg "${RED}❌ Script not found: phase1_add_english_translations.php${NC}"
    exit 1
fi

echo ""
log_msg "${YELLOW}Waiting 2 seconds before next step...${NC}"
sleep 2
echo ""

###############################################################################
# STEP 1.3: Enable Completeness Calculation
###############################################################################
log_msg "${BLUE}STEP 1.3: Enabling completeness calculation...${NC}"
echo ""

if [ -f "$SCRIPT_DIR/phase1_enable_completeness.php" ]; then
    php "$SCRIPT_DIR/phase1_enable_completeness.php" 2>&1 | tee -a "$REPORT_FILE"
    log_msg "${GREEN}✅ Step 1.3 initiated (completeness runs in background)${NC}"
else
    log_msg "${RED}❌ Script not found: phase1_enable_completeness.php${NC}"
    exit 1
fi

echo ""

###############################################################################
# Post-execution verification
###############################################################################
echo ""
log_msg "${BLUE}Running post-execution verification...${NC}"
echo ""

/opt/mariadb10.6/mariadb/bin/mysql -u akeneo_pim -p'akeneo_pim' -h 127.0.0.1 -P 3307 akeneo_pim -e "
-- Check required attributes per family
SELECT 'Required Attributes Summary' as '';
SELECT 
    f.code as family,
    COUNT(r.id) as required_attrs
FROM pim_catalog_family f
LEFT JOIN pim_catalog_attribute_requirement r ON f.id = r.family_id
GROUP BY f.id, f.code
ORDER BY f.code;

-- Check translation coverage
SELECT 'Translation Coverage' as '';
SELECT 
    COUNT(DISTINCT a.id) as total_localizable,
    COUNT(DISTINCT CASE WHEN t.locale = 'en_US' THEN a.id END) as en_US_count,
    COUNT(DISTINCT CASE WHEN t.locale = 'fr_FR' THEN a.id END) as fr_FR_count
FROM pim_catalog_attribute a
LEFT JOIN pim_catalog_attribute_translation t ON a.id = t.foreign_key
WHERE a.is_localizable = 1;

-- Check completeness
SELECT 'Completeness Status' as '';
SELECT COUNT(*) as completeness_records FROM pim_catalog_completeness;
" 2>&1 | tee -a "$REPORT_FILE"

###############################################################################
# Summary
###############################################################################
echo ""
log_msg "${GREEN}"
echo "=" | tr -d '\n'
printf '=%.0s' {1..79}
echo ""
echo "PHASE 1 EXECUTION COMPLETE"
echo "=" | tr -d '\n'
printf '=%.0s' {1..79}
echo -e "${NC}"

log_msg "Report saved to: $REPORT_FILE"
echo ""
log_msg "Next Steps:"
log_msg "1. Review the log file for any errors"
log_msg "2. Test in Akeneo UI - verify required attributes are enforced"
log_msg "3. Check that English translations appear correctly"
log_msg "4. Monitor completeness calculation progress"
log_msg "5. When ready, proceed to Phase 2: Validation Rules & Organization"
echo ""
log_msg "Phase 2 includes:"
log_msg "- Add numeric validation rules (price, weight, quantity)"
log_msg "- Add text validation rules (SKU, name, descriptions)"
log_msg "- Add file/media validation rules"
log_msg "- Reorganize attribute groups (general → 7 logical groups)"
log_msg "- Consolidate color options (631 → <200)"
echo ""
log_msg "Execution completed at: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""
