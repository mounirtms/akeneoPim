#!/bin/bash

# PHASE 5: COMPLETE SYSTEM AUDIT & NEXT STEPS
# Purpose: Verify all systems, identify remaining issues, plan next phases
# Date: 2026-05-06

REPORT_FILE="/home/pim/public_html/PHASE5_AUDIT_REPORT_$(date +%Y%m%d_%H%M%S).md"

echo "=== PHASE 5: COMPLETE SYSTEM AUDIT ===" | tee "$REPORT_FILE"
echo "Date: $(date)" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

# 1. SYSTEM INFRASTRUCTURE
echo "## 1. SYSTEM INFRASTRUCTURE" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

echo "### PHP Version Check" | tee -a "$REPORT_FILE"
php -v | head -1 | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

echo "### PHP Extensions" | tee -a "$REPORT_FILE"
php -m | grep -E "(curl|gd|intl|mbstring|mysql|xml|zip|apcu|opcache)" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

echo "### Symfony Console" | tee -a "$REPORT_FILE"
php bin/console --version 2>&1 | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

# 2. DATABASE STATUS
echo "## 2. DATABASE STATUS" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

echo "### Connection Test" | tee -a "$REPORT_FILE"
mysql -h 127.0.0.1 -P 3307 -u akeneo_pim -pakeneo_pim --skip-ssl akeneo_pim -e "SELECT VERSION();" 2>&1 | grep -v Deprecated | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

echo "### Data Counts" | tee -a "$REPORT_FILE"
mysql -h 127.0.0.1 -P 3307 -u akeneo_pim -pakeneo_pim --skip-ssl akeneo_pim << 'SQL' 2>&1 | grep -v Deprecated | tee -a "$REPORT_FILE"
SELECT 'Products' as Entity, COUNT(*) as Count FROM pim_catalog_product
UNION ALL
SELECT 'Users', COUNT(*) FROM oro_user
UNION ALL
SELECT 'Families', COUNT(*) FROM pim_catalog_family
UNION ALL
SELECT 'Categories', COUNT(*) FROM pim_catalog_category
UNION ALL
SELECT 'Channels', COUNT(*) FROM pim_catalog_channel
UNION ALL
SELECT 'Locales', COUNT(*) FROM pim_catalog_locale
UNION ALL
SELECT 'Attributes', COUNT(*) FROM pim_catalog_attribute;
SQL
echo "" | tee -a "$REPORT_FILE"

# 3. ELASTICSEARCH STATUS
echo "## 3. ELASTICSEARCH STATUS" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

echo "### Cluster Health" | tee -a "$REPORT_FILE"
curl -s "http://localhost:9200/_cluster/health?pretty" 2>&1 | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

echo "### Index Status" | tee -a "$REPORT_FILE"
curl -s "http://localhost:9200/_cat/indices/akeneo*?v" 2>&1 | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

# 4. FILE SYSTEM CHECKS
echo "## 4. FILE SYSTEM STATUS" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

echo "### Critical Directories" | tee -a "$REPORT_FILE"
for dir in var/cache var/logs var/sessions public/media public/bundles vendor; do
    if [ -d "$dir" ]; then
        echo "✓ $dir: $(du -sh $dir | cut -f1)" | tee -a "$REPORT_FILE"
    else
        echo "✗ $dir: MISSING" | tee -a "$REPORT_FILE"
    fi
done
echo "" | tee -a "$REPORT_FILE"

echo "### Frontend Assets" | tee -a "$REPORT_FILE"
for asset in public/css/pim.css public/dist/main.min.js public/bundles/pimui/manifest.json; do
    if [ -f "$asset" ]; then
        echo "✓ $asset: $(du -sh $asset | cut -f1)" | tee -a "$REPORT_FILE"
    else
        echo "✗ $asset: MISSING" | tee -a "$REPORT_FILE"
    fi
done
echo "" | tee -a "$REPORT_FILE"

echo "### Permissions Check" | tee -a "$REPORT_FILE"
for dir in var/cache var/logs var/sessions public/media; do
    if [ -w "$dir" ]; then
        echo "✓ $dir: Writable" | tee -a "$REPORT_FILE"
    else
        echo "✗ $dir: NOT writable" | tee -a "$REPORT_FILE"
    fi
done
echo "" | tee -a "$REPORT_FILE"

# 5. WEB INTERFACE
echo "## 5. WEB INTERFACE STATUS" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

echo "### Login Page" | tee -a "$REPORT_FILE"
LOGIN_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}|%{time_total}" https://pim.technostationery.com/user/login)
LOGIN_CODE=$(echo $LOGIN_RESPONSE | cut -d'|' -f1)
LOGIN_TIME=$(echo $LOGIN_RESPONSE | cut -d'|' -f2)
echo "Status: $LOGIN_CODE | Response Time: ${LOGIN_TIME}s" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

# 6. AKENEO CLI FUNCTIONALITY
echo "## 6. AKENEO CLI FUNCTIONALITY" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

echo "### Available Commands" | tee -a "$REPORT_FILE"
php bin/console list pim 2>&1 | grep -c "pim:" | xargs -I {} echo "Total PIM commands: {}" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

echo "### Critical Commands Test" | tee -a "$REPORT_FILE"
echo "Testing: pim:installer:check-requirements" | tee -a "$REPORT_FILE"
php bin/console pim:installer:check-requirements --env=prod 2>&1 | head -20 | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

# 7. LOG ANALYSIS
echo "## 7. LOG ANALYSIS" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

if [ -f "var/logs/prod.log" ]; then
    echo "### Recent Critical/Error Entries" | tee -a "$REPORT_FILE"
    CRITICAL_COUNT=$(grep -c "CRITICAL" var/logs/prod.log 2>/dev/null || echo "0")
    ERROR_COUNT=$(grep -c "ERROR" var/logs/prod.log 2>/dev/null || echo "0")
    echo "CRITICAL entries: $CRITICAL_COUNT" | tee -a "$REPORT_FILE"
    echo "ERROR entries: $ERROR_COUNT" | tee -a "$REPORT_FILE"
    echo "" | tee -a "$REPORT_FILE"
    
    if [ $CRITICAL_COUNT -gt 0 ]; then
        echo "Last 5 CRITICAL entries:" | tee -a "$REPORT_FILE"
        grep "CRITICAL" var/logs/prod.log | tail -5 | tee -a "$REPORT_FILE"
        echo "" | tee -a "$REPORT_FILE"
    fi
fi

# 8. CACHE STATUS
echo "## 8. CACHE STATUS" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

echo "### Cache Files Count" | tee -a "$REPORT_FILE"
CACHE_COUNT=$(find var/cache/prod -type f 2>/dev/null | wc -l)
echo "Production cache files: $CACHE_COUNT" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

echo "### OPcache Status" | tee -a "$REPORT_FILE"
php -i | grep -E "(opcache.enable|opcache.memory)" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

# 9. CONFIGURATION FILES
echo "## 9. CONFIGURATION FILES" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

for config in .env .env.local config/packages/security.yml config/packages/framework.yml; do
    if [ -f "$config" ]; then
        echo "✓ $config: EXISTS" | tee -a "$REPORT_FILE"
    else
        echo "✗ $config: MISSING" | tee -a "$REPORT_FILE"
    fi
done
echo "" | tee -a "$REPORT_FILE"

# 10. ELASTICSEARCH INDEXING TEST
echo "## 10. ELASTICSEARCH INDEXING TEST" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

echo "### Product Model Index Status" | tee -a "$REPORT_FILE"
curl -s "http://localhost:9200/akeneo_pim_product_model/_count" 2>&1 | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

echo "### Product Index Status" | tee -a "$REPORT_FILE"
curl -s "http://localhost:9200/akeneo_pim_product_and_product_model/_count" 2>&1 | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

# 11. DISK USAGE
echo "## 11. DISK USAGE" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"
df -h /home/pim/public_html | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

# 12. SUMMARY & RECOMMENDATIONS
echo "## 12. SUMMARY & RECOMMENDATIONS" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

echo "### System Health Score" | tee -a "$REPORT_FILE"
HEALTH_SCORE=0
MAX_SCORE=12

# Calculate health score
[ -f "public/css/pim.css" ] && ((HEALTH_SCORE++))
[ $LOGIN_CODE -eq 200 ] && ((HEALTH_SCORE++))
[ $CACHE_COUNT -gt 1000 ] && ((HEALTH_SCORE++))
[ -d "vendor" ] && ((HEALTH_SCORE++))
[ -w "var/cache" ] && ((HEALTH_SCORE++))
[ -w "var/logs" ] && ((HEALTH_SCORE++))
[ $CRITICAL_COUNT -lt 10 ] && ((HEALTH_SCORE++))
[ $ERROR_COUNT -lt 20 ] && ((HEALTH_SCORE++))

mysql -h 127.0.0.1 -P 3307 -u akeneo_pim -pakeneo_pim --skip-ssl akeneo_pim -e "SELECT COUNT(*) FROM pim_catalog_product;" 2>&1 | grep -q "9538" && ((HEALTH_SCORE++))

curl -s "http://localhost:9200/_cluster/health" | grep -q "yellow\|green" && ((HEALTH_SCORE++))

[ $(php bin/console list pim 2>&1 | grep -c "pim:") -gt 10 ] && ((HEALTH_SCORE++))

[ -f ".env" ] && ((HEALTH_SCORE++))

HEALTH_PERCENTAGE=$((HEALTH_SCORE * 100 / MAX_SCORE))
echo "Health Score: $HEALTH_SCORE/$MAX_SCORE ($HEALTH_PERCENTAGE%)" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

# Status determination
if [ $HEALTH_PERCENTAGE -ge 90 ]; then
    echo "**STATUS: ✅ EXCELLENT - System fully operational**" | tee -a "$REPORT_FILE"
elif [ $HEALTH_PERCENTAGE -ge 75 ]; then
    echo "**STATUS: ✓ GOOD - Minor issues to address**" | tee -a "$REPORT_FILE"
elif [ $HEALTH_PERCENTAGE -ge 60 ]; then
    echo "**STATUS: ⚠️ WARNING - Significant issues present**" | tee -a "$REPORT_FILE"
else
    echo "**STATUS: ❌ CRITICAL - Major issues require immediate attention**" | tee -a "$REPORT_FILE"
fi
echo "" | tee -a "$REPORT_FILE"

echo "### Next Steps Recommendations" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

# Dynamic recommendations based on findings
RECOMMENDATIONS=()

if [ $CRITICAL_COUNT -gt 10 ]; then
    RECOMMENDATIONS+=("1. **HIGH PRIORITY**: Investigate and resolve $CRITICAL_COUNT critical log entries")
fi

curl -s "http://localhost:9200/akeneo_pim_product_and_product_model/_count" | grep -q '"count":0' && \
    RECOMMENDATIONS+=("2. **HIGH PRIORITY**: Elasticsearch product index is empty - fix data type issues and re-index")

if [ $CACHE_COUNT -lt 1000 ]; then
    RECOMMENDATIONS+=("3. **MEDIUM PRIORITY**: Cache appears incomplete - run cache:warmup")
fi

mysql -h 127.0.0.1 -P 3307 -u akeneo_pim -pakeneo_pim --skip-ssl akeneo_pim -e "SELECT COUNT(*) FROM pim_catalog_channel WHERE CAST(code AS CHAR) REGEXP '^[0-9]+$';" 2>&1 | grep -v Deprecated | grep -q -v "0" && \
    RECOMMENDATIONS+=("4. **MEDIUM PRIORITY**: Fix channel code data type issues in database")

[ ! -f ".htaccess" ] || ! grep -q "php_value" .htaccess && \
    RECOMMENDATIONS+=("5. **LOW PRIORITY**: Standardize PHP version across CLI/FPM via .htaccess")

RECOMMENDATIONS+=("6. **DEFERRED**: Multi-site cache testing (Varnish/Cloudflare) - per user request")

if [ ${#RECOMMENDATIONS[@]} -eq 0 ]; then
    echo "✅ No critical issues identified - system ready for production" | tee -a "$REPORT_FILE"
else
    for rec in "${RECOMMENDATIONS[@]}"; do
        echo "$rec" | tee -a "$REPORT_FILE"
    done
fi

echo "" | tee -a "$REPORT_FILE"
echo "=== AUDIT COMPLETE ===" | tee -a "$REPORT_FILE"
echo "Report saved to: $REPORT_FILE" | tee -a "$REPORT_FILE"

