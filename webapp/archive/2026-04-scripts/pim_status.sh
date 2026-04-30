#!/usr/bin/env bash
# =============================================================================
# Techno Stationery PIM - System Status & Quick Reference
# =============================================================================
# Run: bash /home/pim/public_html/webapp/pim_status.sh
# =============================================================================

PIM="/home/pim/public_html"
WEBAPP="$PIM/webapp"

echo "============================================================"
echo " Techno Stationery - Akeneo PIM Status"
echo " $(date '+%Y-%m-%d %H:%M:%S')"
echo "============================================================"
echo ""

# DB counts
echo "--- Data Summary ---"
mysql -h 127.0.0.1 -P 3307 -u root -p'YourNewStrongPassword' --ssl=false -sN akeneo_pim 2>/dev/null << 'SQL'
SELECT CONCAT('  Products:     ', COUNT(*)) FROM pim_catalog_product
UNION ALL SELECT CONCAT('  Categories:   ', COUNT(*)) FROM pim_catalog_category
UNION ALL SELECT CONCAT('  Families:     ', COUNT(*)) FROM pim_catalog_family
UNION ALL SELECT CONCAT('  Attributes:   ', COUNT(*)) FROM pim_catalog_attribute
UNION ALL SELECT CONCAT('  Channels:     ', COUNT(*)) FROM pim_catalog_channel
UNION ALL SELECT CONCAT('  Import Jobs:  ', COUNT(*)) FROM akeneo_batch_job_instance WHERE type='import'
UNION ALL SELECT CONCAT('  Export Jobs:  ', COUNT(*)) FROM akeneo_batch_job_instance WHERE type='export';
SQL

echo ""
echo "--- Services ---"
# PHP-FPM
if pgrep -f php-fpm > /dev/null 2>&1; then echo "  PHP-FPM:       RUNNING"; else echo "  PHP-FPM:       STOPPED"; fi
# Elasticsearch
ES=$(curl -sS localhost:9200/_cluster/health 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('status','unknown'))" 2>/dev/null || echo "unreachable")
echo "  Elasticsearch: $ES"
# MySQL
if mysql -h 127.0.0.1 -P 3307 -u root -p'YourNewStrongPassword' --ssl=false -e "SELECT 1" >/dev/null 2>&1; then
    echo "  MySQL:         RUNNING (port 3307)"
else
    echo "  MySQL:         STOPPED"
fi
# Web
HTTP=$(curl -sS -o /dev/null -w "%{http_code}" https://pim.technostationery.com/user/login 2>/dev/null)
echo "  Web (HTTPS):   $HTTP"

echo ""
echo "--- API Test ---"
TOKEN=$(curl -sS -X POST https://pim.technostationery.com/api/oauth/v1/token \
  -d "grant_type=password&client_id=1_3yhbczkw7osgcw8wg44k84os4sc04w4wc80ks08sw8cc8c40sw&client_secret=50vx3l4u4l4wwcsok4kcwkoo44oo0s0o8s0kcs0gc0c8g0oow4&username=admin&password=PimAdmin2026!" \
  2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token','FAIL'))" 2>/dev/null)
if [ "$TOKEN" != "FAIL" ] && [ -n "$TOKEN" ]; then
    echo "  API Auth:      OK"
else
    echo "  API Auth:      FAILED"
fi

echo ""
echo "============================================================"
