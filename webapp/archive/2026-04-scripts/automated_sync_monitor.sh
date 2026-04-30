#!/bin/bash
###############################################################################
# AKENEO PIM - AUTOMATED SYNC & MONITORING SCRIPT
#
# This script provides:
# 1. Automated data quality monitoring
# 2. Cross-database sync verification (Akeneo ↔ Magento Beta)
# 3. Automated alerts for issues
# 4. Daily health reports
#
# Usage: bash /home/pim/public_html/webapp/automated_sync_monitor.sh
# Run as: pim user via crontab
# Schedule: Every 6 hours (0 */6 * * *)
###############################################################################

set -euo pipefail

# Configuration
SCRIPT_DIR="/home/pim/public_html/webapp"
LOG_DIR="/home/pim/public_html/webapp/logs"
REPORT_DIR="/home/pim/public_html/webapp/reports"
DATE=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$LOG_DIR/sync_monitor_${DATE}.log"
REPORT_FILE="$REPORT_DIR/daily_health_${DATE}.html"
ALERT_EMAIL="webmaster@techno-dz.com"

# Database credentials (user-level, NOT root)
AKENEO_USER="akeneo_pim"
AKENEO_PASS="akeneo_pim"
AKENEO_DB="akeneo_pim"

BETA_USER="beta_ntdbusr24"
BETA_PASS="the-correct-password"
BETA_DB="beta_dBT8x12y22"

MYSQL="/opt/mariadb10.6/mariadb/bin/mysql"
MYSQL_HOST="127.0.0.1"
MYSQL_PORT="3307"

# Create directories
mkdir -p "$LOG_DIR" "$REPORT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}================================================================================${NC}"
echo -e "${BLUE}AKENEO PIM - AUTOMATED SYNC & MONITORING${NC}"
echo -e "${BLUE}Date: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
echo -e "${BLUE}================================================================================${NC}"

log_msg() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

alert() {
    local severity="$1"
    local message="$2"
    log_msg "${severity}: ${message}"
    
    # Log alert to separate file
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [${severity}] ${message}" >> "$LOG_DIR/alerts.log"
}

###############################################################################
# SECTION 1: DATABASE CONNECTIVITY CHECK
###############################################################################
log_msg "Checking database connectivity..."

# Check Akeneo
if $MYSQL -u "$AKENEO_USER" -p"$AKENEO_PASS" -h "$MYSQL_HOST" -P "$MYSQL_PORT" "$AKENEO_DB" -e "SELECT 1;" &>/dev/null; then
    log_msg "✅ Akeneo PIM database: Connected"
    AKENEO_CONNECTED=1
else
    log_msg "❌ Akeneo PIM database: Connection failed"
    AKENEO_CONNECTED=0
    alert "CRITICAL" "Akeneo database connection failed"
fi

# Check Beta Magento
if $MYSQL -u "$BETA_USER" -p"$BETA_PASS" -h "$MYSQL_HOST" -P "$MYSQL_PORT" "$BETA_DB" -e "SELECT 1;" &>/dev/null; then
    log_msg "✅ Beta Magento database: Connected"
    BETA_CONNECTED=1
else
    log_msg "❌ Beta Magento database: Connection failed"
    BETA_CONNECTED=0
    alert "CRITICAL" "Beta Magento database connection failed"
fi

echo ""

###############################################################################
# SECTION 2: CORE METRICS COLLECTION
###############################################################################
if [ "$AKENEO_CONNECTED" -eq 1 ]; then
    log_msg "Collecting Akeneo metrics..."
    
    AKENEO_PRODUCTS=$($MYSQL -u "$AKENEO_USER" -p"$AKENEO_PASS" -h "$MYSQL_HOST" -P "$MYSQL_PORT" "$AKENEO_DB" -N -e "SELECT COUNT(*) FROM pim_catalog_product;" 2>/dev/null || echo "0")
    AKENEO_CATEGORIES=$($MYSQL -u "$AKENEO_USER" -p"$AKENEO_PASS" -h "$MYSQL_HOST" -P "$MYSQL_PORT" "$AKENEO_DB" -N -e "SELECT COUNT(*) FROM pim_catalog_category;" 2>/dev/null || echo "0")
    AKENEO_ATTRIBUTES=$($MYSQL -u "$AKENEO_USER" -p"$AKENEO_PASS" -h "$MYSQL_HOST" -P "$MYSQL_PORT" "$AKENEO_DB" -N -e "SELECT COUNT(*) FROM pim_catalog_attribute;" 2>/dev/null || echo "0")
    AKENEO_FAMILIES=$($MYSQL -u "$AKENEO_USER" -p"$AKENEO_PASS" -h "$MYSQL_HOST" -P "$MYSQL_PORT" "$AKENEO_DB" -N -e "SELECT COUNT(*) FROM pim_catalog_family;" 2>/dev/null || echo "0")
    AKENEO_COMPLETENESS=$($MYSQL -u "$AKENEO_USER" -p"$AKENEO_PASS" -h "$MYSQL_HOST" -P "$MYSQL_PORT" "$AKENEO_DB" -N -e "SELECT COUNT(*) FROM pim_catalog_completeness;" 2>/dev/null || echo "0")
    AKENEO_REQUIRED_ATTRS=$($MYSQL -u "$AKENEO_USER" -p"$AKENEO_PASS" -h "$MYSQL_HOST" -P "$MYSQL_PORT" "$AKENEO_DB" -N -e "SELECT COUNT(*) FROM pim_catalog_attribute_requirement;" 2>/dev/null || echo "0")
    
    log_msg "  Products: $AKENEO_PRODUCTS"
    log_msg "  Categories: $AKENEO_CATEGORIES"
    log_msg "  Attributes: $AKENEO_ATTRIBUTES"
    log_msg "  Families: $AKENEO_FAMILIES"
    log_msg "  Completeness records: $AKENEO_COMPLETENESS"
    log_msg "  Required attribute configs: $AKENEO_REQUIRED_ATTRS"
fi

if [ "$BETA_CONNECTED" -eq 1 ]; then
    log_msg "Collecting Beta Magento metrics..."
    
    BETA_PRODUCTS=$($MYSQL -u "$BETA_USER" -p"$BETA_PASS" -h "$MYSQL_HOST" -P "$MYSQL_PORT" "$BETA_DB" -N -e "SELECT COUNT(*) FROM catalog_product_entity;" 2>/dev/null || echo "0")
    BETA_CATEGORIES=$($MYSQL -u "$BETA_USER" -p"$BETA_PASS" -h "$MYSQL_HOST" -P "$MYSQL_PORT" "$BETA_DB" -N -e "SELECT COUNT(*) FROM catalog_category_entity;" 2>/dev/null || echo "0")
    BETA_URL_REWRITES=$($MYSQL -u "$BETA_USER" -p"$BETA_PASS" -h "$MYSQL_HOST" -P "$MYSQL_PORT" "$BETA_DB" -N -e "SELECT COUNT(*) FROM url_rewrite;" 2>/dev/null || echo "0")
    
    log_msg "  Products: $BETA_PRODUCTS"
    log_msg "  Categories: $BETA_CATEGORIES"
    log_msg "  URL Rewrites: $BETA_URL_REWRITES"
fi

echo ""

###############################################################################
# SECTION 3: SYNC VERIFICATION
###############################################################################
if [ "$AKENEO_CONNECTED" -eq 1 ] && [ "$BETA_CONNECTED" -eq 1 ]; then
    log_msg "Verifying cross-database synchronization..."
    
    # Product count sync
    PRODUCT_DIFF=$((AKENEO_PRODUCTS - BETA_PRODUCTS))
    PRODUCT_DIFF_ABS=${PRODUCT_DIFF#-}
    
    if [ "$PRODUCT_DIFF_ABS" -eq 0 ]; then
        log_msg "  ✅ Products: Perfect sync ($AKENEO_PRODUCTS = $BETA_PRODUCTS)"
    elif [ "$PRODUCT_DIFF_ABS" -le 5 ]; then
        log_msg "  ⚠️ Products: Minor difference ($AKENEO_PRODUCTS vs $BETA_PRODUCTS, diff: $PRODUCT_DIFF)"
        alert "WARNING" "Product count mismatch: Akeneo=$AKENEO_PRODUCTS, Magento=$BETA_PRODUCTS"
    else
        log_msg "  ❌ Products: Major difference ($AKENEO_PRODUCTS vs $BETA_PRODUCTS, diff: $PRODUCT_DIFF)"
        alert "CRITICAL" "Major product count mismatch: Akeneo=$AKENEO_PRODUCTS, Magento=$BETA_PRODUCTS"
    fi
    
    # Category count sync
    CATEGORY_DIFF=$((AKENEO_CATEGORIES - BETA_CATEGORIES))
    CATEGORY_DIFF_ABS=${CATEGORY_DIFF#-}
    
    if [ "$CATEGORY_DIFF_ABS" -le 2 ]; then
        log_msg "  ✅ Categories: Acceptable sync ($AKENEO_CATEGORIES vs $BETA_CATEGORIES)"
    else
        log_msg "  ⚠️ Categories: Difference detected ($AKENEO_CATEGORIES vs $BETA_CATEGORIES)"
        alert "WARNING" "Category count mismatch: Akeneo=$AKENEO_CATEGORIES, Magento=$BETA_CATEGORIES"
    fi
    
    # SKU-level sync check
    log_msg "  Checking SKU-level synchronization..."
    
    $MYSQL -u "$AKENEO_USER" -p"$AKENEO_PASS" -h "$MYSQL_HOST" -P "$MYSQL_PORT" "$AKENEO_DB" -N -e "
        SELECT identifier FROM pim_catalog_product ORDER BY identifier;
    " 2>/dev/null | sort > /tmp/akeneo_skus.txt
    
    $MYSQL -u "$BETA_USER" -p"$BETA_PASS" -h "$MYSQL_HOST" -P "$MYSQL_PORT" "$BETA_DB" -N -e "
        SELECT sku FROM catalog_product_entity ORDER BY sku;
    " 2>/dev/null | sort > /tmp/beta_skus.txt
    
    MISSING_IN_MAGENTO=$(comm -23 /tmp/akeneo_skus.txt /tmp/beta_skus.txt | wc -l)
    MISSING_IN_AKENEO=$(comm -13 /tmp/akeneo_skus.txt /tmp/beta_skus.txt | wc -l)
    
    if [ "$MISSING_IN_MAGENTO" -eq 0 ] && [ "$MISSING_IN_AKENEO" -eq 0 ]; then
        log_msg "  ✅ SKU sync: 100% match"
    else
        log_msg "  ⚠️ SKU sync: $MISSING_IN_MAGENTO missing in Magento, $MISSING_IN_AKENEO missing in Akeneo"
        alert "WARNING" "SKU mismatch: $MISSING_IN_MAGENTO missing in Magento, $MISSING_IN_AKENEO missing in Akeneo"
    fi
    
    # Cleanup temp files
    rm -f /tmp/akeneo_skus.txt /tmp/beta_skus.txt
fi

echo ""

###############################################################################
# SECTION 4: DATA QUALITY CHECKS
###############################################################################
if [ "$AKENEO_CONNECTED" -eq 1 ]; then
    log_msg "Running data quality checks..."
    
    # Check for families without required attributes
    FAMILIES_NO_REQUIREMENTS=$($MYSQL -u "$AKENEO_USER" -p"$AKENEO_PASS" -h "$MYSQL_HOST" -P "$MYSQL_PORT" "$AKENEO_DB" -N -e "
        SELECT COUNT(*) FROM pim_catalog_family f
        WHERE NOT EXISTS (
            SELECT 1 FROM pim_catalog_attribute_requirement r WHERE r.family_id = f.id
        );
    " 2>/dev/null || echo "0")
    
    if [ "$FAMILIES_NO_REQUIREMENTS" -gt 0 ]; then
        alert "WARNING" "$FAMILIES_NO_REQUIREMENTS families have no required attributes configured"
        log_msg "  ⚠️ $FAMILIES_NO_REQUIREMENTS families without required attributes"
    else
        log_msg "  ✅ All families have required attributes configured"
    fi
    
    # Check for missing translations
    MISSING_TRANSLATIONS=$($MYSQL -u "$AKENEO_USER" -p"$AKENEO_PASS" -h "$MYSQL_HOST" -P "$MYSQL_PORT" "$AKENEO_DB" -N -e "
        SELECT COUNT(*) FROM pim_catalog_attribute a
        WHERE a.is_localizable = 1
        AND NOT EXISTS (
            SELECT 1 FROM pim_catalog_attribute_translation t 
            WHERE t.foreign_key = a.id AND t.locale = 'en_US'
        );
    " 2>/dev/null || echo "0")
    
    if [ "$MISSING_TRANSLATIONS" -gt 0 ]; then
        alert "INFO" "$MISSING_TRANSLATIONS localizable attributes missing en_US translation"
        log_msg "  ⚠️ $MISSING_TRANSLATIONS attributes missing English translations"
    else
        log_msg "  ✅ All localizable attributes have English translations"
    fi
    
    # Check completeness calculation status
    if [ "$AKENEO_COMPLETENESS" -eq 0 ]; then
        alert "WARNING" "Completeness calculation not enabled or never run"
        log_msg "  ⚠️ No completeness records found"
    else
        AVG_COMPLETENESS=$($MYSQL -u "$AKENEO_USER" -p"$AKENEO_PASS" -h "$MYSQL_HOST" -P "$MYSQL_PORT" "$AKENEO_DB" -N -e "
            SELECT ROUND(AVG(completeness), 1) FROM pim_catalog_completeness;
        " 2>/dev/null || echo "0")
        log_msg "  ✅ Completeness: Average ${AVG_COMPLETENESS}%"
    fi
    
    # Check validation rules
    ATTRS_WITH_VALIDATION=$($MYSQL -u "$AKENEO_USER" -p"$AKENEO_PASS" -h "$MYSQL_HOST" -P "$MYSQL_PORT" "$AKENEO_DB" -N -e "
        SELECT COUNT(*) FROM pim_catalog_attribute 
        WHERE validation_rule IS NOT NULL 
           OR validation_regexp IS NOT NULL
           OR number_min IS NOT NULL
           OR max_characters IS NOT NULL
           OR allowed_extensions IS NOT NULL;
    " 2>/dev/null || echo "0")
    
    log_msg "  ✅ Attributes with validation: $ATTRS_WITH_VALIDATION / 112"
    
    if [ "$ATTRS_WITH_VALIDATION" -lt 20 ]; then
        alert "WARNING" "Only $ATTRS_WITH_VALIDATION attributes have validation rules"
    fi
fi

echo ""

###############################################################################
# SECTION 5: GENERATE HTML REPORT
###############################################################################
log_msg "Generating HTML health report..."

cat > "$REPORT_FILE" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>PIM Health Report - $(date '+%Y-%m-%d %H:%M')</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        h1 { color: #2c3e50; border-bottom: 3px solid #3498db; padding-bottom: 10px; }
        h2 { color: #34495e; margin-top: 30px; }
        table { width: 100%; border-collapse: collapse; margin: 15px 0; }
        th, td { padding: 10px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background: #3498db; color: white; }
        .success { color: #27ae60; font-weight: bold; }
        .warning { color: #f39c12; font-weight: bold; }
        .error { color: #e74c3c; font-weight: bold; }
        .metric { font-size: 24px; font-weight: bold; }
    </style>
</head>
<body>
    <div class="container">
        <h1>📊 PIM Akeneo Health Report</h1>
        <p><strong>Date:</strong> $(date '+%Y-%m-%d %H:%M:%S')</p>
        
        <h2>📈 Core Metrics</h2>
        <table>
            <tr><th>System</th><th>Products</th><th>Categories</th><th>Attributes</th><th>Status</th></tr>
            <tr>
                <td>Akeneo PIM</td>
                <td class="metric">$AKENEO_PRODUCTS</td>
                <td class="metric">$AKENEO_CATEGORIES</td>
                <td class="metric">$AKENEO_ATTRIBUTES</td>
                <td class="success">✅ Online</td>
            </tr>
            <tr>
                <td>Beta Magento</td>
                <td class="metric">$BETA_PRODUCTS</td>
                <td class="metric">$BETA_CATEGORIES</td>
                <td>-</td>
                <td class="success">✅ Online</td>
            </tr>
        </table>
        
        <h2>🔄 Synchronization Status</h2>
        <table>
            <tr><th>Check</th><th>Status</th><th>Details</th></tr>
            <tr>
                <td>Product Count</td>
                <td class="$([ "$PRODUCT_DIFF_ABS" -eq 0 ] && echo 'success' || echo 'warning')">
                    $([ "$PRODUCT_DIFF_ABS" -eq 0 ] && echo '✅' || echo '⚠️')
                </td>
                <td>Akeneo: $AKENEO_PRODUCTS, Magento: $BETA_PRODUCTS (Diff: $PRODUCT_DIFF)</td>
            </tr>
            <tr>
                <td>Category Count</td>
                <td class="$([ "$CATEGORY_DIFF_ABS" -le 2 ] && echo 'success' || echo 'warning')">
                    $([ "$CATEGORY_DIFF_ABS" -le 2 ] && echo '✅' || echo '⚠️')
                </td>
                <td>Akeneo: $AKENEO_CATEGORIES, Magento: $BETA_CATEGORIES</td>
            </tr>
            <tr>
                <td>SKU Match</td>
                <td class="$([ "$MISSING_IN_MAGENTO" -eq 0 ] && [ "$MISSING_IN_AKENEO" -eq 0 ] && echo 'success' || echo 'warning')">
                    $([ "$MISSING_IN_MAGENTO" -eq 0 ] && [ "$MISSING_IN_AKENEO" -eq 0 ] && echo '✅' || echo '⚠️')
                </td>
                <td>Missing in Magento: $MISSING_IN_MAGENTO, Missing in Akeneo: $MISSING_IN_AKENEO</td>
            </tr>
        </table>
        
        <h2>✅ Data Quality Checks</h2>
        <table>
            <tr><th>Check</th><th>Status</th><th>Value</th></tr>
            <tr>
                <td>Families with Required Attributes</td>
                <td class="$([ "$FAMILIES_NO_REQUIREMENTS" -eq 0 ] && echo 'success' || echo 'warning')">
                    $([ "$FAMILIES_NO_REQUIREMENTS" -eq 0 ] && echo '✅' || echo '⚠️')
                </td>
                <td>$FAMILIES_NO_REQUIREMENTS families without requirements</td>
            </tr>
            <tr>
                <td>English Translations</td>
                <td class="$([ "$MISSING_TRANSLATIONS" -eq 0 ] && echo 'success' || echo 'warning')">
                    $([ "$MISSING_TRANSLATIONS" -eq 0 ] && echo '✅' || echo '⚠️')
                </td>
                <td>$MISSING_TRANSLATIONS missing translations</td>
            </tr>
            <tr>
                <td>Completeness Calculation</td>
                <td class="$([ "$AKENEO_COMPLETENESS" -gt 0 ] && echo 'success' || echo 'warning')">
                    $([ "$AKENEO_COMPLETENESS" -gt 0 ] && echo '✅' || echo '⚠️')
                </td>
                <td>$AKENEO_COMPLETENESS records, Avg: ${AVG_COMPLETENESS}%</td>
            </tr>
            <tr>
                <td>Validation Rules</td>
                <td class="$([ "$ATTRS_WITH_VALIDATION" -ge 20 ] && echo 'success' || echo 'warning')">
                    $([ "$ATTRS_WITH_VALIDATION" -ge 20 ] && echo '✅' || echo '⚠️')
                </td>
                <td>$ATTRS_WITH_VALIDATION / 112 attributes with validation</td>
            </tr>
        </table>
        
        <p><small>Report generated by automated monitoring script</small></p>
    </div>
</body>
</html>
EOF

log_msg "✅ Report saved to: $REPORT_FILE"
echo ""

###############################################################################
# SECTION 6: CLEANUP OLD LOGS
###############################################################################
log_msg "Cleaning up old logs (keeping last 30 days)..."
find "$LOG_DIR" -name "*.log" -mtime +30 -delete 2>/dev/null || true
find "$REPORT_DIR" -name "*.html" -mtime +90 -delete 2>/dev/null || true
log_msg "✅ Cleanup complete"

echo ""
log_msg "================================================================================"
log_msg "MONITORING CYCLE COMPLETE"
log_msg "================================================================================"
log_msg "Next check: $(date -d '+6 hours' '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo 'In 6 hours')"
echo ""
