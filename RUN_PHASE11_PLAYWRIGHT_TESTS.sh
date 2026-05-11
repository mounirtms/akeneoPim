#!/bin/bash
################################################################################
# Phase 11: Run Playwright Comprehensive Tests
# This script installs Playwright if needed and runs comprehensive browser tests
################################################################################

set -e  # Exit on error

SCRIPT_DIR="/home/pim/public_html"
TEST_SCRIPT="PHASE11_PLAYWRIGHT_COMPREHENSIVE_TEST.js"
REPORT_FILE="PHASE11_PLAYWRIGHT_TEST_REPORT.json"
LOG_FILE="PHASE11_PLAYWRIGHT_TEST.log"

echo "========================================"
echo "Phase 11: Playwright Test Runner"
echo "========================================"
echo "Start Time: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo ""

cd "$SCRIPT_DIR"

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "❌ ERROR: Node.js is not installed"
    echo "   Install with: curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash - && sudo apt-get install -y nodejs"
    exit 1
fi

echo "✅ Node.js version: $(node --version)"
echo "✅ npm version: $(npm --version)"
echo ""

# Check if Playwright is installed
if ! npm list playwright 2>/dev/null | grep -q playwright; then
    echo "📦 Installing Playwright..."
    npm install playwright
    
    echo "📦 Installing Playwright browsers..."
    npx playwright install chromium
fi

echo "✅ Playwright installed"
echo ""

# Run the tests
echo "🚀 Running Playwright tests..."
echo "   Target: https://pim.technostationery.com"
echo "   Test script: $TEST_SCRIPT"
echo ""

# Run tests and capture output
if node "$TEST_SCRIPT" 2>&1 | tee "$LOG_FILE"; then
    TEST_EXIT_CODE=0
    echo ""
    echo "✅ Tests completed successfully"
else
    TEST_EXIT_CODE=$?
    echo ""
    echo "⚠️  Tests completed with failures (exit code: $TEST_EXIT_CODE)"
fi

echo ""
echo "========================================"
echo "Test Results Summary"
echo "========================================"

# Check if report file exists
if [ -f "$REPORT_FILE" ]; then
    echo "✅ Report generated: $REPORT_FILE"
    echo ""
    
    # Extract summary using node
    node -e "
    const fs = require('fs');
    const report = JSON.parse(fs.readFileSync('$REPORT_FILE', 'utf8'));
    console.log('Tests Run: ' + report.tests.length);
    console.log('✅ Passed: ' + report.summary.passed);
    console.log('❌ Failed: ' + report.summary.failed);
    console.log('⚠️  Warnings: ' + report.summary.warnings);
    console.log('');
    console.log('Test Details:');
    report.tests.forEach(test => {
      const icon = test.status === 'PASS' ? '✅' : test.status === 'FAIL' ? '❌' : '⚠️';
      console.log(icon + ' ' + test.name + (test.details ? ' - ' + test.details : ''));
    });
    " 2>/dev/null || echo "⚠️  Could not parse JSON report"
    
    echo ""
else
    echo "❌ Report file not found"
fi

echo "========================================"
echo "Logs saved to: $LOG_FILE"
echo "End Time: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "========================================"

exit $TEST_EXIT_CODE
