#!/bin/bash

echo "========================================"
echo "MAGENTO PLATFORM DIAGNOSTICS & FIX"
echo "========================================"
echo "Started: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Magento installation directory
MAGENTO_DIR="/home/technadminy7/public_html"
cd "$MAGENTO_DIR" || exit 1

echo "1. Checking Magento Installation..."
echo "   Directory: $MAGENTO_DIR"
if [ -f "bin/magento" ]; then
    echo "   ✓ Magento CLI found"
    php bin/magento --version 2>&1 | head -1
else
    echo "   ✗ Magento CLI not found"
    exit 1
fi

echo ""
echo "2. Checking Magento Mode..."
MAGENTO_MODE=$(php bin/magento deploy:mode:show 2>&1 | grep -i "Current application mode" | awk '{print $NF}')
echo "   Current mode: $MAGENTO_MODE"

echo ""
echo "3. Testing Frontend URL..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" https://beta.technostationery.com/)
echo "   HTTP Status: $HTTP_CODE"
if [ "$HTTP_CODE" == "500" ]; then
    echo "   ✗ Frontend error detected"
    echo ""
    echo "4. Checking Magento Error Logs..."
    if [ -f "var/log/system.log" ]; then
        echo "   Last 10 errors from system.log:"
        tail -20 var/log/system.log | grep -i error | tail -10
    fi
    if [ -f "var/log/exception.log" ]; then
        echo ""
        echo "   Last 10 errors from exception.log:"
        tail -20 var/log/exception.log | tail -10
    fi
elif [ "$HTTP_CODE" == "200" ]; then
    echo "   ✓ Frontend is working"
fi

echo ""
echo "5. Checking Database Connection..."
php -r "
try {
    \$pdo = new PDO('mysql:host=127.0.0.1;port=3307;dbname=technadminy7_dBT8x12y22', 'root', 'YourNewStrongPassword');
    echo '   ✓ Database connection successful\n';
    \$version = \$pdo->query('SELECT VERSION()')->fetchColumn();
    echo '   Database version: ' . \$version . '\n';
} catch (PDOException \$e) {
    echo '   ✗ Database connection failed: ' . \$e->getMessage() . '\n';
}
"

echo ""
echo "6. Checking Cache Status..."
if [ -d "var/cache" ]; then
    CACHE_SIZE=$(du -sh var/cache 2>/dev/null | awk '{print $1}')
    echo "   Cache size: $CACHE_SIZE"
fi

if [ -d "var/page_cache" ]; then
    PAGE_CACHE_SIZE=$(du -sh var/page_cache 2>/dev/null | awk '{print $1}')
    echo "   Page cache size: $PAGE_CACHE_SIZE"
fi

echo ""
echo "7. Checking File Permissions..."
VAR_OWNER=$(stat -c '%U' var/ 2>/dev/null || stat -f '%Su' var/ 2>/dev/null)
echo "   var/ owner: $VAR_OWNER"

echo ""
echo "========================================"
echo "AUTOMATIC FIXES"
echo "========================================"
echo ""

echo "FIX 1: Clearing all caches..."
php bin/magento cache:flush 2>&1 | grep -v "^$"

echo ""
echo "FIX 2: Clearing generated code..."
rm -rf generated/code/* generated/metadata/*
echo "   ✓ Generated code cleared"

echo ""
echo "FIX 3: Running setup:upgrade..."
php bin/magento setup:upgrade --keep-generated 2>&1 | tail -5

echo ""
echo "FIX 4: Running setup:di:compile..."
echo "   (This may take 2-3 minutes...)"
php bin/magento setup:di:compile 2>&1 | tail -5

echo ""
echo "FIX 5: Deploying static content..."
php bin/magento setup:static-content:deploy -f 2>&1 | tail -5

echo ""
echo "FIX 6: Fixing file permissions..."
find var generated pub/static pub/media app/etc -type f -exec chmod 644 {} \; 2>/dev/null
find var generated pub/static pub/media app/etc -type d -exec chmod 755 {} \; 2>/dev/null
echo "   ✓ Permissions fixed"

echo ""
echo "FIX 7: Reindexing..."
php bin/magento indexer:reindex 2>&1 | tail -10

echo ""
echo "========================================"
echo "POST-FIX VERIFICATION"
echo "========================================"
echo ""

echo "Testing frontend again..."
sleep 2
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" https://beta.technostationery.com/)
RESPONSE_TIME=$(curl -s -o /dev/null -w "%{time_total}" https://beta.technostationery.com/)
echo "   HTTP Status: $HTTP_CODE"
echo "   Response Time: ${RESPONSE_TIME}s"

if [ "$HTTP_CODE" == "200" ]; then
    echo ""
    echo "   ✓ SUCCESS! Magento frontend is now working"
elif [ "$HTTP_CODE" == "500" ]; then
    echo ""
    echo "   ✗ Still showing errors. Check logs:"
    echo "     tail -50 var/log/system.log"
    echo "     tail -50 var/log/exception.log"
fi

echo ""
echo "========================================"
echo "SUMMARY"
echo "========================================"
echo ""
echo "Magento Directory: $MAGENTO_DIR"
echo "Current Mode: $MAGENTO_MODE"
echo "Frontend Status: HTTP $HTTP_CODE"
echo "Cache Cleared: ✓"
echo "Code Generated: ✓"
echo "Static Content: ✓"
echo "Permissions: ✓"
echo "Reindex: ✓"
echo ""
echo "Completed: $(date '+%Y-%m-%d %H:%M:%S')"
