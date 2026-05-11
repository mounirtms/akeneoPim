#!/bin/bash
################################################################################
# PHASE 11: Comprehensive Localhost Testing
# Date: 2026-05-06
# Purpose: Test all layers (Apache:8080, Varnish:80, PHP-FPM) before Cloudflare
################################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 PHASE 11: LOCALHOST COMPREHENSIVE TEST"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Started: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo ""

TESTS_PASSED=0
TESTS_FAILED=0
WARNINGS=0

# Test function
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_pattern="$3"
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Test: $test_name"
    echo "Command: $test_command"
    
    result=$(eval "$test_command" 2>&1)
    
    if echo "$result" | grep -qi "$expected_pattern"; then
        echo "✅ PASSED"
        ((TESTS_PASSED++))
    else
        echo "❌ FAILED"
        echo "Expected pattern: $expected_pattern"
        echo "Got: ${result:0:500}"
        ((TESTS_FAILED++))
    fi
    echo ""
}

# Layer 1: Direct Apache on port 8080
echo "═══════════════════════════════════════════════════════════════════════"
echo "📊 LAYER 1: Direct Apache Testing (Port 8080)"
echo "═══════════════════════════════════════════════════════════════════════"

run_test "Apache Root Response" \
    "curl -sI http://localhost:8080/ | head -1" \
    "HTTP"

run_test "Apache Root Content" \
    "curl -sL http://localhost:8080/ | head -20" \
    "login\|Location:\|DOCTYPE"

run_test "Apache Login Page" \
    "curl -sI http://localhost:8080/user/login | head -1" \
    "200"

run_test "Apache Static Asset" \
    "curl -sI http://localhost:8080/bundles/pimui/images/logo.svg | head -1" \
    "200"

# Check .htaccess execution
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 .htaccess Execution Check"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Test if mod_rewrite is working
test_rewrite=$(curl -sL http://localhost:8080/nonexistent-path 2>&1)
if echo "$test_rewrite" | grep -qi "login\|symfony"; then
    echo "✅ mod_rewrite is working (404 handled by Symfony)"
    ((TESTS_PASSED++))
else
    echo "⚠️  mod_rewrite may not be working"
    ((WARNINGS++))
fi

# Layer 2: Varnish on port 80
echo ""
echo "═══════════════════════════════════════════════════════════════════════"
echo "📊 LAYER 2: Varnish Testing (Port 80)"
echo "═══════════════════════════════════════════════════════════════════════"

run_test "Varnish Root Response" \
    "curl -sI http://localhost/ | head -1" \
    "HTTP"

run_test "Varnish Cache Header" \
    "curl -sI http://localhost/ | grep -i 'x-varnish\|age\|cache'" \
    "varnish\|age\|cache"

run_test "Varnish Login Page" \
    "curl -sI http://localhost/user/login | head -1" \
    "200"

# Layer 3: PHP-FPM and Application
echo ""
echo "═══════════════════════════════════════════════════════════════════════"
echo "📊 LAYER 3: PHP-FPM & Application Testing"
echo "═══════════════════════════════════════════════════════════════════════"

# Test direct PHP execution
cat > /tmp/test_php.php << 'PHPEOF'
<?php
echo "PHP_VERSION: " . PHP_VERSION . "\n";
echo "SAPI: " . php_sapi_name() . "\n";
echo "CWD: " . getcwd() . "\n";
PHPEOF

php_test=$(php /tmp/test_php.php 2>&1)
if echo "$php_test" | grep -q "8\.[23]"; then
    echo "✅ PHP Version: $(echo "$php_test" | grep PHP_VERSION)"
    ((TESTS_PASSED++))
else
    echo "❌ PHP test failed"
    ((TESTS_FAILED++))
fi

# Test Symfony routing
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 Symfony Application Test"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

app_test=$(php bin/console cache:pool:list 2>&1 | head -5)
if echo "$app_test" | grep -qi "cache\|pool"; then
    echo "✅ Symfony console working"
    ((TESTS_PASSED++))
else
    echo "⚠️  Symfony console warning: $app_test"
    ((WARNINGS++))
fi

# Configuration Audit
echo ""
echo "═══════════════════════════════════════════════════════════════════════"
echo "📊 Configuration Audit"
echo "═══════════════════════════════════════════════════════════════════════"

echo "▶ Apache VirtualHost Configuration"
grep -A 30 "pim.technostationery.com" /etc/apache2/conf/httpd.conf 2>/dev/null | grep -E "ServerName|DocumentRoot|DirectoryIndex|AllowOverride" | head -10

echo ""
echo "▶ Root .htaccess (first 30 lines)"
head -30 /home/pim/public_html/.htaccess 2>/dev/null

echo ""
echo "▶ Public .htaccess DirectoryIndex"
grep -i "DirectoryIndex" /home/pim/public_html/public/.htaccess 2>/dev/null || echo "⚠️  No DirectoryIndex found"

echo ""
echo "▶ Varnish Backend Configuration"
grep -E "backend|\.host|\.port" /etc/varnish/default.vcl 2>/dev/null | head -10

# Performance metrics
echo ""
echo "═══════════════════════════════════════════════════════════════════════"
echo "📊 Performance Metrics"
echo "═══════════════════════════════════════════════════════════════════════"

echo "▶ Apache Response Time (10 requests)"
for i in {1..10}; do
    time_ms=$(curl -o /dev/null -s -w '%{time_total}\n' http://localhost:8080/)
    echo "  Request $i: ${time_ms}s"
done | tail -1

echo ""
echo "▶ Varnish Response Time (10 requests)"
for i in {1..10}; do
    time_ms=$(curl -o /dev/null -s -w '%{time_total}\n' http://localhost/)
    echo "  Request $i: ${time_ms}s"
done | tail -1

# Network and Process Status
echo ""
echo "═══════════════════════════════════════════════════════════════════════"
echo "📊 Network & Process Status"
echo "═══════════════════════════════════════════════════════════════════════"

echo "▶ Listening Ports"
ss -tlnp 2>/dev/null | grep -E ":80|:8080|:443|:6082" || netstat -tlnp 2>/dev/null | grep -E ":80|:8080|:443|:6082"

echo ""
echo "▶ Apache Processes"
ps aux | grep -E "[h]ttpd|[a]pache" | wc -l
echo "  (showing top 3)"
ps aux | grep -E "[h]ttpd|[a]pache" | head -3

echo ""
echo "▶ Varnish Processes"
ps aux | grep -E "[v]arnishd" | head -2

echo ""
echo "▶ PHP-FPM Processes (ea-php83)"
ps aux | grep -E "[p]hp-fpm.*ea-php83" | wc -l
echo "  (showing master)"
ps aux | grep -E "[p]hp-fpm.*ea-php83.*master" | head -1

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 TEST SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Tests Passed:  $TESTS_PASSED"
echo "❌ Tests Failed:  $TESTS_FAILED"
echo "⚠️  Warnings:     $WARNINGS"

total_tests=$((TESTS_PASSED + TESTS_FAILED))
if [ $total_tests -gt 0 ]; then
    success_rate=$((TESTS_PASSED * 100 / total_tests))
    echo "📈 Success Rate:  ${success_rate}%"
fi

echo ""
echo "Completed: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $TESTS_FAILED -gt 0 ]; then
    exit 1
fi

exit 0
