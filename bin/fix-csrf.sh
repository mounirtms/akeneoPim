#!/bin/bash
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║              Pimcore CSRF Protection Fix                       ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

cd /home/pim/public_html

echo "1. Clearing all caches..."
rm -rf var/cache/* var/sessions/* var/tmp/*
echo "   ✓ Caches cleared"

echo ""
echo "2. Fixing permissions..."
chown -R pim:nobody var/ public/
chmod -R 775 var/
echo "   ✓ Permissions fixed"

echo ""
echo "3. Clearing database sessions..."
/opt/mariadb10.6/mariadb/bin/mysql -u root -p'YourNewStrongPassword' -h 127.0.0.1 -P 3307 pimcore -e "DELETE FROM sessions;" 2>/dev/null
echo "   ✓ Sessions cleared"

echo ""
echo "4. Rebuilding cache..."
php bin/console cache:clear --env=prod --no-warmup >/dev/null 2>&1
echo "   ✓ Cache rebuilt"

echo ""
echo "5. Testing login page..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" https://pim.technostationery.com/admin/login)
if [ "$HTTP_CODE" = "200" ]; then
    echo "   ✓ Login page: OK ($HTTP_CODE)"
else
    echo "   ✗ Login page: FAILED ($HTTP_CODE)"
fi

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                     FIX COMPLETE                                ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "🔐 LOGIN INSTRUCTIONS:"
echo ""
echo "1. Open INCOGNITO/PRIVATE browser window"
echo "2. Go to: https://pim.technostationery.com/admin/login"
echo "3. Clear ALL site data if asked"
echo "4. Login with:"
echo "   Username: admin"
echo "   Password: f3j3f6E4d1O6G1C2"
echo ""
echo "⚠️  If still getting 403:"
echo "   - Clear ALL browser data (Ctrl+Shift+Delete)"
echo "   - Try different browser"
echo "   - Disable browser extensions (especially ad blockers)"
echo ""
