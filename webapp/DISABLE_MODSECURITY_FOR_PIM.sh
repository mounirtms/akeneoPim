#!/bin/bash

echo "=========================================="
echo "DISABLE MODSECURITY FOR PIM DOMAIN"
echo "Date: $(date)"
echo "=========================================="
echo ""

echo "=== STEP 1: Check ModSecurity Status ==="
httpd -M 2>&1 | grep -i security

echo ""
echo "=== STEP 2: Create ModSecurity Exception ==="

# Method 1: Create .modsecurity.conf in root
cat > /home/pim/public_html/.modsecurity.conf << 'EOF'
<IfModule mod_security2.c>
  SecRuleEngine Off
</IfModule>
EOF

chmod 644 /home/pim/public_html/.modsecurity.conf
chown pim:pim /home/pim/public_html/.modsecurity.conf

echo "✅ Created .modsecurity.conf to disable ModSecurity"

# Method 2: Update .htaccess
echo ""
echo "Adding ModSecurity disable directive to .htaccess..."

if ! grep -q "SecRuleEngine Off" /home/pim/public_html/.htaccess; then
    cat >> /home/pim/public_html/.htaccess << 'EOF'

# Disable ModSecurity (Phase 11 Fix)
<IfModule mod_security2.c>
  SecRuleEngine Off
</IfModule>
EOF
    echo "✅ Added ModSecurity disable to root .htaccess"
else
    echo "⚠️  ModSecurity disable already present in .htaccess"
fi

# Method 3: Create custom ModSecurity config
echo ""
echo "Creating custom ModSecurity whitelist rules..."

mkdir -p /usr/local/apache/conf/modsec
cat > /usr/local/apache/conf/modsec/pim_whitelist.conf << 'EOF'
# ModSecurity Whitelist for pim.technostationery.com
<IfModule mod_security2.c>
  <VirtualHost *:80>
    ServerName pim.technostationery.com
    ServerAlias www.pim.technostationery.com
    
    SecRuleEngine Off
  </VirtualHost>
  
  <VirtualHost *:443>
    ServerName pim.technostationery.com
    ServerAlias www.pim.technostationery.com
    
    SecRuleEngine Off
  </VirtualHost>
</IfModule>
EOF

echo "✅ Created custom ModSecurity whitelist config"

echo ""
echo "=== STEP 3: Restart Apache ==="
/scripts/restartsrv_httpd --graceful
sleep 3

echo ""
echo "=== STEP 4: Test External IP Access ==="
echo "Testing direct IP with Host header:"
curl -I -H "Host: pim.technostationery.com" http://205.134.249.177/ 2>&1 | head -15

echo ""
echo "=== STEP 5: Test via Cloudflare ==="
echo "Purging Cloudflare cache..."
curl -s -X POST "https://api.cloudflare.com/client/v4/zones/4919ad3406fcabba381edbd543814a68/purge_cache" \
  -H "X-Auth-Email: amine.bo@techno-dz.com" \
  -H "X-Auth-Key: 35d8fd4b1a5d27eabbce73c6753978fc350bc" \
  -H "Content-Type: application/json" \
  -d '{"purge_everything":true}' | python3 -m json.tool | grep success

echo ""
echo "Waiting 10 seconds..."
sleep 10

echo ""
echo "Testing https://pim.technostationery.com/:"
curl -I https://pim.technostationery.com/ 2>&1 | head -20

echo ""
echo "=========================================="
echo "MODSECURITY DISABLE SUMMARY"
echo "=========================================="
echo ""
echo "Actions Taken:"
echo "  1. Created /home/pim/public_html/.modsecurity.conf"
echo "  2. Added SecRuleEngine Off to .htaccess"
echo "  3. Created custom whitelist config"
echo "  4. Restarted Apache"
echo "  5. Purged Cloudflare cache"
echo ""
echo "If still showing 403, you may need root/WHM access to:"
echo "  - Edit /usr/local/apache/conf/modsec/modsec2.user.conf"
echo "  - Or disable ModSecurity globally in WHM"
echo ""
echo "=========================================="

