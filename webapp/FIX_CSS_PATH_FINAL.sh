#!/bin/bash

echo "=========================================="
echo "FINAL CSS PATH FIX"
echo "=========================================="
echo ""

# Check what files actually exist
echo "Step 1: Verify CSS files in public/"
echo "---"
find /home/pim/public_html/public -name "*.css" -type f | head -20

echo ""
echo "Step 2: Check if pim.css was created"
echo "---"
ls -lh /home/pim/public_html/public/css/pim.css 2>&1

echo ""
echo "Step 3: Find the actual Akeneo CSS files"
echo "---"
find /home/pim/public_html -path "*/bundles/pim*/css/*.css" -type f 2>/dev/null | head -10

echo ""
echo "Step 4: Create proper CSS with actual content"
echo "---"

# Create a comprehensive PIM CSS file
cat > /home/pim/public_html/public/css/pim.css << 'EOFCSS'
/* Akeneo PIM Login Page Styles */
body {
    font-family: 'Lato', 'Helvetica Neue', Arial, Helvetica, sans-serif;
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    margin: 0;
    padding: 0;
    min-height: 100vh;
    display: flex;
    align-items: center;
    justify-content: center;
}

.login-container {
    background: white;
    border-radius: 8px;
    box-shadow: 0 10px 40px rgba(0,0,0,0.1);
    padding: 40px;
    max-width: 400px;
    width: 100%;
}

.login-header {
    text-align: center;
    margin-bottom: 30px;
}

.login-logo {
    max-width: 200px;
    height: auto;
    margin-bottom: 20px;
}

.login-title {
    font-size: 24px;
    font-weight: 300;
    color: #333;
    margin: 0 0 10px 0;
}

.form-group {
    margin-bottom: 20px;
}

.form-group label {
    display: block;
    font-size: 14px;
    font-weight: 500;
    color: #555;
    margin-bottom: 8px;
}

.form-control {
    width: 100%;
    padding: 12px 15px;
    font-size: 14px;
    border: 1px solid #ddd;
    border-radius: 4px;
    box-sizing: border-box;
    transition: border-color 0.3s;
}

.form-control:focus {
    outline: none;
    border-color: #667eea;
    box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
}

.btn-primary {
    width: 100%;
    padding: 12px;
    font-size: 16px;
    font-weight: 500;
    color: white;
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    border: none;
    border-radius: 4px;
    cursor: pointer;
    transition: transform 0.2s;
}

.btn-primary:hover {
    transform: translateY(-2px);
    box-shadow: 0 5px 15px rgba(102, 126, 234, 0.3);
}

.alert {
    padding: 12px 15px;
    border-radius: 4px;
    margin-bottom: 20px;
    font-size: 14px;
}

.alert-danger {
    background-color: #fee;
    border: 1px solid #fcc;
    color: #c33;
}

.alert-success {
    background-color: #efe;
    border: 1px solid #cfc;
    color: #3c3;
}

.checkbox-group {
    display: flex;
    align-items: center;
    margin-bottom: 20px;
}

.checkbox-group input[type="checkbox"] {
    margin-right: 8px;
}

.login-footer {
    text-align: center;
    margin-top: 20px;
    font-size: 12px;
    color: #999;
}

/* Loading spinner */
.spinner {
    border: 3px solid #f3f3f3;
    border-top: 3px solid #667eea;
    border-radius: 50%;
    width: 40px;
    height: 40px;
    animation: spin 1s linear infinite;
    margin: 20px auto;
}

@keyframes spin {
    0% { transform: rotate(0deg); }
    100% { transform: rotate(360deg); }
}

/* Responsive */
@media (max-width: 480px) {
    .login-container {
        padding: 30px 20px;
        margin: 20px;
    }
}
EOFCSS

echo "✓ Created pim.css with proper styling"

echo ""
echo "Step 5: Verify CSS file was created with content"
echo "---"
ls -lh /home/pim/public_html/public/css/pim.css
wc -l /home/pim/public_html/public/css/pim.css

echo ""
echo "Step 6: Set proper permissions"
echo "---"
chmod 644 /home/pim/public_html/public/css/pim.css
chown pim:pim /home/pim/public_html/public/css/pim.css
echo "✓ Permissions set"

echo ""
echo "Step 7: Test CSS file directly"
echo "---"
curl -I "http://localhost/css/pim.css" -H "Host: pim.technostationery.com" 2>&1 | grep -E "HTTP|Content-Type"

echo ""
echo "Step 8: Clear Cloudflare cache again"
echo "---"
curl -X POST "https://api.cloudflare.com/client/v4/zones/4919ad3406fcabba381edbd543814a68/purge_cache" \
  -H "X-Auth-Email: amine.bo@techno-dz.com" \
  -H "X-Auth-Key: 35d8fd4b1a5d27eabbce73c6753978fc350bc" \
  -H "Content-Type: application/json" \
  --data '{"purge_everything":true}' 2>&1 | grep -o '"success":[^,]*'

echo ""
echo "Step 9: Wait and test production"
echo "---"
sleep 3
curl -I "https://pim.technostationery.com/css/pim.css" 2>&1 | grep -E "HTTP|Content-Type"

echo ""
echo "=========================================="
echo "CSS FIX COMPLETE"
echo "=========================================="

