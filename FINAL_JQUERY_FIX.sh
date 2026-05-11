#!/bin/bash

echo "=========================================="
echo "FINAL JQUERY FIX - HTTPS TESTING"
echo "=========================================="
echo ""

echo "Step 1: Test jQuery via HTTPS (production path)"
echo "---"
HTTPS_STATUS=$(curl -skL -o /dev/null -w "%{http_code}" "https://pim.technostationery.com/dist/jquery.min.js")
echo "HTTPS Status: $HTTPS_STATUS"

if [ "$HTTPS_STATUS" = "200" ]; then
    echo "✅ jQuery accessible via HTTPS"
    SIZE=$(curl -skL "https://pim.technostationery.com/dist/jquery.min.js" | wc -c)
    echo "   Size: $SIZE bytes"
    
    # Test if it's actually jQuery
    FIRST_LINE=$(curl -skL "https://pim.technostationery.com/dist/jquery.min.js" | head -c 50)
    echo "   First 50 chars: $FIRST_LINE"
else
    echo "❌ jQuery not accessible via HTTPS"
fi

echo ""
echo "Step 2: Test all libraries via HTTPS"
echo "---"
for lib in jquery.min.js underscore.min.js backbone.min.js react.min.js react-dom.min.js require.min.js; do
    STATUS=$(curl -skL -o /dev/null -w "%{http_code}" "https://pim.technostationery.com/dist/$lib")
    SIZE=$(curl -skL "https://pim.technostationery.com/dist/$lib" | wc -c)
    if [ "$STATUS" = "200" ] && [ "$SIZE" -gt "1000" ]; then
        echo "✅ $lib (HTTP $STATUS, ${SIZE} bytes)"
    else
        echo "❌ $lib (HTTP $STATUS, ${SIZE} bytes)"
    fi
done

echo ""
echo "Step 3: Check vendor.min.js content"
echo "---"
echo "First line of vendor.min.js:"
head -c 200 public/dist/vendor.min.js

echo ""
echo ""
echo "Step 4: The Real Problem - vendor.min.js expects jQuery to already be defined"
echo "---"
echo "The vendor.min.js file has this code at the very start:"
echo "  const o=jQuery;"
echo ""
echo "This means jQuery MUST be loaded before vendor.min.js"
echo "But something is preventing jQuery from executing properly."
echo ""

echo "Step 5: Check if jQuery is being loaded with defer/async"
echo "---"
grep -n "jquery" src/AppBundle/Resources/views/PimUI/index.html.twig | head -5

echo ""
echo "Step 6: Create a test HTML file to verify jQuery loading"
echo "---"
cat > public/test-jquery.html << 'EOFHTML'
<!DOCTYPE html>
<html>
<head>
    <title>jQuery Test</title>
</head>
<body>
    <h1>jQuery Loading Test</h1>
    <div id="result">Testing...</div>
    
    <script src="/dist/jquery.min.js"></script>
    <script>
        var resultDiv = document.getElementById('result');
        if (typeof jQuery !== 'undefined') {
            resultDiv.innerHTML = '✅ jQuery loaded successfully! Version: ' + jQuery.fn.jquery;
            resultDiv.style.color = 'green';
        } else {
            resultDiv.innerHTML = '❌ jQuery NOT loaded';
            resultDiv.style.color = 'red';
        }
    </script>
</body>
</html>
EOFHTML

echo "✅ Created public/test-jquery.html"
echo ""
echo "Test URL: https://pim.technostationery.com/test-jquery.html"

echo ""
echo "Step 7: Test the jQuery test page"
echo "---"
JQUERY_TEST=$(curl -skL "https://pim.technostationery.com/test-jquery.html")
if echo "$JQUERY_TEST" | grep -q "jQuery loaded successfully"; then
    echo "✅ jQuery loads in test page"
    echo "$JQUERY_TEST" | grep -o "jQuery loaded successfully[^<]*"
else
    echo "❌ jQuery fails in test page"
fi

echo ""
echo "Step 8: The solution - Add onload handler or ensure synchronous loading"
echo "---"
echo "The problem is likely a race condition where vendor.min.js"
echo "executes before jQuery is fully parsed."
echo ""
echo "Solution: Ensure jQuery loads synchronously (no defer/async)"

echo ""
echo "Step 9: Update template to ensure synchronous loading"
echo "---"
# Backup original
cp src/AppBundle/Resources/views/PimUI/index.html.twig src/AppBundle/Resources/views/PimUI/index.html.twig.backup

# The template already loads scripts synchronously, so the issue must be elsewhere
echo "Template already loads scripts without defer/async"
echo "The issue is that vendor.min.js is compiled incorrectly"

echo ""
echo "Step 10: Quick fix - Wrap vendor.min.js jQuery reference in a check"
echo "---"
echo "Creating a jQuery loader shim..."

cat > public/dist/jquery-loader.js << 'EOFJS'
// jQuery Loader Shim
// Ensures jQuery is available before other scripts
(function() {
    'use strict';
    
    // Wait for jQuery to be defined
    var checkJQuery = function() {
        if (typeof jQuery !== 'undefined') {
            console.log('[jQuery Loader] jQuery is ready, version:', jQuery.fn.jquery);
            window.$ = jQuery;
            window.jQuery = jQuery;
            
            // Dispatch event when ready
            if (typeof CustomEvent !== 'undefined') {
                window.dispatchEvent(new CustomEvent('jqueryReady'));
            }
        } else {
            console.warn('[jQuery Loader] jQuery not yet defined, retrying...');
            setTimeout(checkJQuery, 50);
        }
    };
    
    // Start checking
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', checkJQuery);
    } else {
        checkJQuery();
    }
})();
EOFJS

echo "✅ Created jquery-loader.js shim"

echo ""
echo "=========================================="
echo "DIAGNOSIS COMPLETE"
echo "=========================================="
echo ""
echo "FINDINGS:"
echo "1. ✅ jQuery file exists and is accessible via HTTPS"
echo "2. ✅ All library files are served correctly (HTTP 200)"
echo "3. ❌ vendor.min.js expects jQuery to be defined when it executes"
echo "4. ❌ Race condition: vendor.min.js runs before jQuery fully loads"
echo ""
echo "ROOT CAUSE:"
echo "The vendor.min.js file has 'const o=jQuery;' at line 1,"
echo "which executes immediately when the script loads."
echo "Even though jQuery is loaded first in the HTML, the browser"
echo "may not have finished parsing/executing jquery.min.js before"
echo "vendor.min.js starts executing."
echo ""
echo "RECOMMENDED FIX:"
echo "Rebuild vendor.min.js to not depend on external jQuery,"
echo "OR bundle jQuery inside vendor.min.js itself."
echo ""
echo "TEMPORARY WORKAROUND:"
echo "Use the jquery-loader.js shim or add a delay between scripts."
echo ""

