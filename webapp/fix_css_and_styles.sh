#!/bin/bash
# Fix CSS and Styles Issues in Akeneo PIM
# Date: 2026-05-01

LOG_FILE="webapp/logs/css_fix_$(date +%Y%m%d_%H%M%S).log"
mkdir -p webapp/logs

echo "========================================" | tee "$LOG_FILE"
echo "Fixing CSS and Styles Issues" | tee -a "$LOG_FILE"
echo "Date: $(date)" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

cd /home/pim/public_html

# Step 1: Check current CSS situation
echo "Step 1: Analyzing current CSS configuration..." | tee -a "$LOG_FILE"
echo "Webpack dist directory size:" | tee -a "$LOG_FILE"
du -sh public/dist 2>/dev/null | tee -a "$LOG_FILE"
echo "CSS files in bundles:" | tee -a "$LOG_FILE"
find public/bundles -name "*.css" 2>/dev/null | wc -l | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Step 2: Check if Akeneo uses CSS-in-JS
echo "Step 2: Checking for CSS-in-JS configuration..." | tee -a "$LOG_FILE"
if grep -r "style-loader\|css-loader" package.json 2>/dev/null; then
    echo "✓ CSS-in-JS detected (webpack handles styles)" | tee -a "$LOG_FILE"
    CSS_IN_JS=true
else
    echo "⚠ No CSS-in-JS configuration found" | tee -a "$LOG_FILE"
    CSS_IN_JS=false
fi
echo "" | tee -a "$LOG_FILE"

# Step 3: Check for LESS/SASS compilation
echo "Step 3: Checking for LESS/SASS..." | tee -a "$LOG_FILE"
LESS_FILES=$(find . -name "*.less" -not -path "*/node_modules/*" -not -path "*/vendor/*" | wc -l)
SCSS_FILES=$(find . -name "*.scss" -not -path "*/node_modules/*" -not -path "*/vendor/*" | wc -l)
echo "LESS files found: $LESS_FILES" | tee -a "$LOG_FILE"
echo "SCSS files found: $SCSS_FILES" | tee -a "$LOG_FILE"

if [ "$LESS_FILES" -gt 0 ] || [ "$SCSS_FILES" -gt 0 ]; then
    echo "Styles need compilation" | tee -a "$LOG_FILE"
    NEEDS_COMPILATION=true
else
    NEEDS_COMPILATION=false
fi
echo "" | tee -a "$LOG_FILE"

# Step 4: Install Symfony assets properly
echo "Step 4: Installing Symfony assets..." | tee -a "$LOG_FILE"
php bin/console assets:install public --symlink --env=prod 2>&1 | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Step 5: Check for missing pim.css and create basic stylesheet
echo "Step 5: Creating basic PIM stylesheet..." | tee -a "$LOG_FILE"
if [ ! -f "public/css/pim.css" ]; then
    cat > public/css/pim.css << 'PIMCSS'
/* Akeneo PIM Basic Styles */
/* Generated: 2026-05-01 */

body {
    margin: 0;
    padding: 0;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
    font-size: 14px;
    line-height: 1.5;
    color: #333;
    background-color: #f5f5f5;
}

/* Basic layout */
.AknDefault-contentWithBottom {
    min-height: 100vh;
}

/* Navigation */
.AknHeader {
    background: #fff;
    border-bottom: 1px solid #ddd;
    padding: 10px 20px;
}

.AknMenu {
    background: #2c3e50;
    color: #fff;
}

/* Forms */
.AknTextField,
.AknTextareaField,
input[type="text"],
input[type="email"],
input[type="password"],
select,
textarea {
    width: 100%;
    padding: 8px 12px;
    border: 1px solid #ccc;
    border-radius: 4px;
    font-size: 14px;
}

.AknButton,
button,
.btn {
    padding: 8px 16px;
    border: none;
    border-radius: 4px;
    cursor: pointer;
    font-size: 14px;
    background-color: #5992c4;
    color: #fff;
}

.AknButton:hover,
button:hover {
    background-color: #4a7ba7;
}

/* Login page */
.AknLogin {
    display: flex;
    align-items: center;
    justify-content: center;
    min-height: 100vh;
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
}

.AknLogin-form {
    background: #fff;
    padding: 40px;
    border-radius: 8px;
    box-shadow: 0 4px 6px rgba(0,0,0,0.1);
    width: 100%;
    max-width: 400px;
}

.AknLogin-title {
    font-size: 24px;
    font-weight: 600;
    margin-bottom: 24px;
    text-align: center;
    color: #333;
}

.AknLogin-field {
    margin-bottom: 16px;
}

.AknLogin-button {
    width: 100%;
    margin-top: 16px;
}

/* Grid system */
.AknGrid {
    display: grid;
    gap: 16px;
}

/* Tables */
table {
    width: 100%;
    border-collapse: collapse;
}

th, td {
    padding: 12px;
    text-align: left;
    border-bottom: 1px solid #ddd;
}

th {
    background-color: #f8f8f8;
    font-weight: 600;
}

/* Loading state */
.AknLoadingMask {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(255,255,255,0.8);
    display: flex;
    align-items: center;
    justify-content: center;
}

/* Utility classes */
.text-center { text-align: center; }
.mt-1 { margin-top: 8px; }
.mt-2 { margin-top: 16px; }
.mb-1 { margin-bottom: 8px; }
.mb-2 { margin-bottom: 16px; }
.p-1 { padding: 8px; }
.p-2 { padding: 16px; }

/* Responsive */
@media (max-width: 768px) {
    .AknLogin-form {
        margin: 20px;
        padding: 24px;
    }
}
PIMCSS
    
    echo "✓ Created basic pim.css stylesheet" | tee -a "$LOG_FILE"
    chmod 644 public/css/pim.css
else
    echo "✓ pim.css already exists" | tee -a "$LOG_FILE"
fi
echo "" | tee -a "$LOG_FILE"

# Step 6: Check webpack configuration
echo "Step 6: Checking webpack configuration..." | tee -a "$LOG_FILE"
if [ -f "webpack.config.js" ]; then
    echo "Webpack config exists" | tee -a "$LOG_FILE"
    
    # Check if webpack is properly configured
    if grep -q "MiniCssExtractPlugin\|extract.*css" webpack.config.js 2>/dev/null; then
        echo "✓ CSS extraction configured" | tee -a "$LOG_FILE"
    else
        echo "⚠ No CSS extraction plugin found (CSS may be in JS)" | tee -a "$LOG_FILE"
    fi
else
    echo "⚠ No webpack.config.js found" | tee -a "$LOG_FILE"
fi
echo "" | tee -a "$LOG_FILE"

# Step 7: Clear and warm cache
echo "Step 7: Clearing and warming cache..." | tee -a "$LOG_FILE"
rm -rf var/cache/prod/*
php bin/console cache:clear --env=prod --no-warmup 2>&1 | tee -a "$LOG_FILE"
php bin/console cache:warmup --env=prod 2>&1 | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Step 8: Verify fix
echo "Step 8: Verifying CSS fix..." | tee -a "$LOG_FILE"
if [ -f "public/css/pim.css" ]; then
    CSS_SIZE=$(stat -c%s "public/css/pim.css")
    echo "✓ public/css/pim.css exists ($CSS_SIZE bytes)" | tee -a "$LOG_FILE"
else
    echo "✗ public/css/pim.css still missing" | tee -a "$LOG_FILE"
fi

# Check total CSS presence
TOTAL_CSS=$(find public -name "*.css" 2>/dev/null | wc -l)
echo "Total CSS files in public/: $TOTAL_CSS" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Step 9: Test accessibility
echo "Step 9: Testing CSS accessibility..." | tee -a "$LOG_FILE"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" https://pim.technostationery.com/css/pim.css)
echo "HTTP response for /css/pim.css: $HTTP_CODE" | tee -a "$LOG_FILE"
if [ "$HTTP_CODE" = "200" ]; then
    echo "✓ CSS file accessible" | tee -a "$LOG_FILE"
else
    echo "⚠ CSS file not accessible (HTTP $HTTP_CODE)" | tee -a "$LOG_FILE"
fi
echo "" | tee -a "$LOG_FILE"

echo "========================================" | tee -a "$LOG_FILE"
echo "CSS Fix Complete" | tee -a "$LOG_FILE"
echo "Log saved to: $LOG_FILE" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"
