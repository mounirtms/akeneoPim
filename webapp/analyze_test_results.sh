#!/bin/bash

echo "=========================================="
echo "COMPREHENSIVE TEST RESULTS ANALYSIS"
echo "=========================================="
echo ""

echo "📊 Test Execution Summary"
echo "---"
if [ -f test_summary.json ]; then
    echo "Summary Report:"
    cat test_summary.json | jq -r '
        "Timestamp: \(.timestamp)",
        "",
        "Overall Results:",
        "  Total Tests: \(.summary.total)",
        "  ✅ Passed: \(.summary.passed)",
        "  ❌ Failed: \(.summary.failed)",
        "  ⏭️  Skipped: \(.summary.skipped)",
        "",
        "Test Suites:"
    '
    
    cat test_summary.json | jq -r '.testSuites[] | 
        "  \(.name):",
        (.tests[] | "    • \(.name || "Test"): \(.status) (\(.duration // 0)ms)")
    '
    
    echo ""
    echo "Performance Metrics:"
    cat test_summary.json | jq -r '.performance.navigation | 
        "  • DOM Content Loaded: \(.domContentLoaded)ms",
        "  • Load Complete: \(.loadComplete)ms",
        "  • Total Time: \(.totalTime)ms",
        "  • TTFB: \(.ttfb)ms"
    '
    
    echo ""
    echo "Resource Loading:"
    cat test_summary.json | jq -r '.performance.resources | 
        "  • Total Resources: \(.total)",
        "  • CSS Files: \(.css)",
        "  • JS Files: \(.js)",
        "  • Images: \(.images)",
        "  • Fonts: \(.fonts)"
    '
else
    echo "❌ test_summary.json not found"
fi

echo ""
echo "📸 Screenshots Generated"
echo "---"
ls -lh screenshot_*.png 2>/dev/null | awk '{print "  • " $9 " (" $5 ")"}'

echo ""
echo "📝 Error Analysis"
echo "---"
if [ -f test_summary.json ]; then
    echo "Top Errors:"
    cat test_summary.json | jq -r '.errors[] | "  • \(.message)"' | head -10
else
    echo "No error summary available"
fi

echo ""
echo "🔍 Key Findings from Logs"
echo "---"
if [ -f test_execution.log ]; then
    echo "Login Results:"
    grep -E "Login successful|Login failed|Testing login" test_execution.log | sed 's/^/  /'
    
    echo ""
    echo "JavaScript Errors:"
    grep "ERROR\]" test_execution.log | grep -i "error:" | head -5 | sed 's/^/  /'
    
    echo ""
    echo "Network Issues:"
    grep "Request Failed" test_execution.log | wc -l | xargs -I {} echo "  • {} failed requests"
    
    echo ""
    echo "Console Logs Count:"
    grep "\[CONSOLE\]" test_execution.log | wc -l | xargs -I {} echo "  • {} console messages"
fi

echo ""
echo "📋 Detailed Report Files"
echo "---"
echo "  • comprehensive_pim_test_report.json - Full test results with all logs"
echo "  • test_summary.json - Executive summary"
echo "  • test_execution.log - Complete test execution output"
echo "  • mounir_auth.json - Authenticated session storage for Mounir"

echo ""
echo "🎯 Next Steps Recommendations"
echo "---"
if [ -f test_summary.json ]; then
    FAILED=$(cat test_summary.json | jq -r '.summary.failed')
    if [ "$FAILED" -gt 0 ]; then
        echo "  1. Review failed tests in comprehensive_pim_test_report.json"
        echo "  2. Check error screenshots: screenshot_*_after_login.png"
        echo "  3. Investigate authentication issues if login tests failed"
    else
        echo "  ✅ All tests passed! System is working correctly."
        echo "  1. Review performance metrics for optimization opportunities"
        echo "  2. Address CSP warnings for external scripts"
        echo "  3. Consider implementing additional UI tests"
    fi
else
    echo "  • Review test_execution.log for test status"
fi

echo ""
echo "=========================================="
echo "ANALYSIS COMPLETE"
echo "=========================================="

