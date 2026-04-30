#!/bin/bash
# Quick System Health Check for Akeneo PIM
# Date: 2026-04-30

echo "========================================="
echo "   Akeneo PIM System Health Check"
echo "   $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================="
echo ""

# 1. Elasticsearch Status
echo "📊 Elasticsearch:"
ES_HEALTH=$(curl -s "localhost:9200/_cluster/health" 2>/dev/null | grep -o '"status":"[^"]*' | cut -d'"' -f4)
if [ "$ES_HEALTH" == "green" ] || [ "$ES_HEALTH" == "yellow" ]; then
    echo "   ✅ Status: $ES_HEALTH"
else
    echo "   ❌ Status: $ES_HEALTH (or not responding)"
fi

# 2. Product Count in Elasticsearch
PRODUCT_COUNT=$(curl -s "localhost:9200/beta_techno_stationery_product_1_v7/_count" 2>/dev/null | grep -o '"count":[0-9]*' | cut -d':' -f2)
if [ ! -z "$PRODUCT_COUNT" ]; then
    echo "   ✅ Indexed Products: $PRODUCT_COUNT"
else
    echo "   ⚠️  Could not retrieve product count"
fi

echo ""

# 3. Database Connection
echo "🗄️  Database (MySQL):"
DB_STATUS=$(php -r "try { new PDO('mysql:host=127.0.0.1;port=3307;dbname=akeneo_pim', 'akeneo_pim', 'akeneo_pim'); echo 'Connected'; } catch(Exception \$e) { echo 'Failed: ' . \$e->getMessage(); }" 2>/dev/null)
if [[ "$DB_STATUS" == "Connected" ]]; then
    echo "   ✅ $DB_STATUS"
else
    echo "   ❌ $DB_STATUS"
fi

# Get product counts from database
DB_PRODUCTS=$(php -r "
\$conn = new PDO('mysql:host=127.0.0.1;port=3307;dbname=akeneo_pim', 'akeneo_pim', 'akeneo_pim');
\$stmt = \$conn->query('SELECT COUNT(*) as count FROM pim_catalog_product WHERE is_enabled = 1');
echo \$stmt->fetch(PDO::FETCH_ASSOC)['count'];
" 2>/dev/null)
echo "   ✅ Products in DB: $DB_PRODUCTS"

DB_MODELS=$(php -r "
\$conn = new PDO('mysql:host=127.0.0.1;port=3307;dbname=akeneo_pim', 'akeneo_pim', 'akeneo_pim');
\$stmt = \$conn->query('SELECT COUNT(*) as count FROM pim_catalog_product_model');
echo \$stmt->fetch(PDO::FETCH_ASSOC)['count'];
" 2>/dev/null)
echo "   ✅ Product Models: $DB_MODELS"

echo ""

# 4. Image Files
echo "🖼️  Product Images:"
IMAGE_COUNT=$(find /home/pim/public_html/public/media/product_images -type f 2>/dev/null | wc -l)
if [ $IMAGE_COUNT -gt 0 ]; then
    echo "   ✅ Image Files: $IMAGE_COUNT"
    IMAGE_SIZE=$(du -sh /home/pim/public_html/public/media/product_images 2>/dev/null | cut -f1)
    echo "   ✅ Total Size: $IMAGE_SIZE"
else
    echo "   ⚠️  No images found"
fi

echo ""

# 5. Disk Usage
echo "💾 Disk Space:"
DISK_USAGE=$(df -h /home/pim/public_html | awk 'NR==2 {print $5}')
DISK_AVAILABLE=$(df -h /home/pim/public_html | awk 'NR==2 {print $4}')
echo "   📊 Usage: $DISK_USAGE (Available: $DISK_AVAILABLE)"

echo ""

# 6. Akeneo PIM Web Interface
echo "🌐 Akeneo PIM Web:"
PIM_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "https://pim.technostationery.com" 2>/dev/null)
if [ "$PIM_STATUS" == "200" ] || [ "$PIM_STATUS" == "302" ]; then
    echo "   ✅ HTTP Status: $PIM_STATUS"
else
    echo "   ⚠️  HTTP Status: $PIM_STATUS"
fi

echo ""

# 7. Magento Frontend
echo "🛒 Magento Frontend:"
MAGENTO_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "https://beta.technostationery.com" 2>/dev/null)
if [ "$MAGENTO_STATUS" == "200" ]; then
    echo "   ✅ HTTP Status: $MAGENTO_STATUS"
else
    echo "   ⚠️  HTTP Status: $MAGENTO_STATUS"
fi

echo ""

# 8. System Resources
echo "⚙️  System Resources:"
CPU_LOAD=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}')
echo "   📊 CPU Load: $CPU_LOAD"

MEMORY_USAGE=$(free -h | awk 'NR==2 {print $3 "/" $2}')
echo "   📊 Memory: $MEMORY_USAGE"

echo ""
echo "========================================="
echo "   Health Check Complete"
echo "========================================="
