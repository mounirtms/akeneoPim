#!/bin/bash

echo "=========================================="
echo "PIM TEST SUITE RUNNER"
echo "=========================================="
echo ""

# Try to use system Chromium/Chrome if available
if command -v chromium-browser &> /dev/null; then
    export PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=$(which chromium-browser)
    echo "✓ Using system Chromium: $PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH"
elif command -v chromium &> /dev/null; then
    export PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=$(which chromium)
    echo "✓ Using system Chromium: $PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH"
elif command -v google-chrome &> /dev/null; then
    export PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=$(which google-chrome)
    echo "✓ Using Google Chrome: $PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH"
else
    echo "⚠️ No system browser found - will try Playwright's bundled browser"
fi

echo ""
echo "Running comprehensive PIM tests..."
echo ""

# Run tests with timeout
timeout 120 node pim_comprehensive_tests.js 2>&1 || {
    EXIT_CODE=$?
    if [ $EXIT_CODE -eq 124 ]; then
        echo ""
        echo "⚠️ Tests timed out after 120 seconds"
    else
        echo ""
        echo "⚠️ Tests exited with code: $EXIT_CODE"
    fi
}

echo ""
echo "=========================================="
echo "Checking test outputs..."
echo "=========================================="

# Check if report was generated
if [ -f pim_test_report.json ]; then
    echo "✅ Test report generated"
    echo ""
    echo "Summary from report:"
    echo "---"
    cat pim_test_report.json | grep -E '"name"|"status"|"passed"|"failed"' | head -30
else
    echo "⚠️ Test report not generated"
fi

echo ""
echo "Screenshots generated:"
ls -lh test_*.png 2>/dev/null || echo "No screenshots found"

echo ""
echo "=========================================="
echo "MANUAL VERIFICATION REQUIRED"
echo "=========================================="
echo ""
echo "Please verify the following manually:"
echo "1. Open: https://pim.technostationery.com/user/login"
echo "2. Check if CSS is loading properly"
echo "3. Try logging in with: admin / admin"
echo "4. Open browser console (F12) and check for errors"
echo ""

