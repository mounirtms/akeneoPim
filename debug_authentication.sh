#!/bin/bash

echo "=== DEEP AUTHENTICATION DEBUGGING ==="
echo ""

echo "### 1. Check Admin User in Database ###"
php bin/console doctrine:query:sql "
SELECT id, username, email, enabled, password 
FROM oro_user 
WHERE username = 'admin' LIMIT 1
" --env=prod 2>&1 | grep -A 10 "array"

echo ""
echo "### 2. Test Password Hash ###"
echo "Testing if 'admin' password matches hash..."
php -r "
\$hash = '$2y$10$Y7a/ZG6470c00yXMZXCQWOqrJGQ8h.Kq3n6nYFzN5vqhV5L6mJ5zy';
\$password = 'admin';
if (password_verify(\$password, \$hash)) {
    echo 'Password verification: SUCCESS' . PHP_EOL;
} else {
    echo 'Password verification: FAILED' . PHP_EOL;
}
"

echo ""
echo "### 3. Check Security Configuration ###"
if [ -f "config/packages/security.yaml" ]; then
    echo "Security configuration exists"
    grep -A10 "encoders:\|password_hasher:" config/packages/security.yaml | head -15
else
    echo "Security configuration NOT FOUND"
fi

echo ""
echo "### 4. Check Recent Security Logs ###"
if [ -f "var/logs/prod.log" ]; then
    echo "Recent authentication attempts:"
    tail -200 var/logs/prod.log | grep -i "security\|authentication\|firewall" | tail -10
else
    echo "No log file found"
fi

echo ""
echo "### 5. Test Direct Login via Curl ###"
echo "Attempting login via curl..."
curl -X POST http://localhost:8000/index.php/user/login-check \
  -d "_username=admin&_password=admin" \
  -c /tmp/cookies.txt \
  -L -s -o /tmp/login_response.html \
  -w "HTTP Status: %{http_code}\nRedirect URL: %{redirect_url}\n"

echo ""
echo "Response preview:"
head -50 /tmp/login_response.html | grep -i "error\|invalid\|incorrect\|title" || echo "No error messages found in response"

echo ""
echo "=== Debug Complete ==="
