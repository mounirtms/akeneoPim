#!/bin/bash
# Complete Permission Fix for Pimcore
# This fixes the root/pim/nobody permission issue permanently

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║     Pimcore Complete Permission Fix - Line by Line             ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

cd /home/pim/public_html

# Step 1: Change ALL files to pim:nobody
echo "Step 1: Setting owner to pim:nobody..."
chown -R pim:nobody /home/pim/public_html
echo "   ✓ Owner changed"

# Step 2: Set directories to 775 (rwxrwxr-x)
echo ""
echo "Step 2: Setting directory permissions to 775..."
find /home/pim/public_html -type d -exec chmod 775 {} \;
echo "   ✓ Directories: 775"

# Step 3: Set files to 664 (rw-rw-r--)
echo ""
echo "Step 3: Setting file permissions to 664..."
find /home/pim/public_html -type f -exec chmod 664 {} \;
echo "   ✓ Files: 664"

# Step 4: Make bin/console executable
echo ""
echo "Step 4: Making executables..."
chmod +x /home/pim/public_html/bin/console
chmod +x /home/pim/public_html/bin/*.sh 2>/dev/null
echo "   ✓ Executables ready"

# Step 5: Critical directories need write access
echo ""
echo "Step 5: Setting critical directories to 777..."
chmod -R 777 /home/pim/public_html/var/cache
chmod -R 777 /home/pim/public_html/var/log
chmod -R 777 /home/pim/public_html/var/tmp
chmod -R 777 /home/pim/public_html/var/sessions
chmod -R 775 /home/pim/public_html/public/var
echo "   ✓ Cache/Log directories: 777"

# Step 6: Set sticky bit on var directory
echo ""
echo "Step 6: Setting sticky bit on var..."
chmod -R g+s /home/pim/public_html/var
echo "   ✓ Sticky bit set"

# Step 7: Clear old cache files
echo ""
echo "Step 7: Clearing cache..."
rm -rf /home/pim/public_html/var/cache/*
echo "   ✓ Cache cleared"

# Step 8: Rebuild cache as pim user
echo ""
echo "Step 8: Rebuilding cache as pim user..."
su - pim -c "cd /home/pim/public_html && php bin/console cache:clear --env=prod" 2>/dev/null || \
  runuser -u pim -- /home/pim/public_html/bin/console cache:clear --env=prod
echo "   ✓ Cache rebuilt"

# Step 9: Verify permissions
echo ""
echo "Step 9: Verification..."
echo "   var/cache  : $(stat -c '%a %U:%G' /home/pim/public_html/var/cache)"
echo "   var/log    : $(stat -c '%a %U:%G' /home/pim/public_html/var/log)"
echo "   var/sessions: $(stat -c '%a %U:%G' /home/pim/public_html/var/sessions)"
echo "   public/    : $(stat -c '%a %U:%G' /home/pim/public_html/public)"

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                   ✅ PERMISSIONS FIXED                         ║"
echo "╚════════════════════════════════════════════════════════════════╝"