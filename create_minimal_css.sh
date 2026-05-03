#!/bin/bash
echo "=== Creating Minimal Working CSS ==="
echo "Date: $(date)"
echo ""

# Step 1: Create a minimal CSS that includes login page styles
cat > public/css/pim.css << 'CSS'
/* Akeneo PIM - Minimal CSS for Login Page */

/* Reset and Base Styles */
* { margin: 0; padding: 0; box-sizing: border-box; }

body {
    font-family: "Lato", "Helvetica Neue", Helvetica, Arial, sans-serif;
    font-size: 14px;
    line-height: 1.42857143;
    color: #11324d;
    background-color: #f5f5f5;
}

/* Login Page Styles */
.login-page {
    display: flex;
    align-items: center;
    justify-content: center;
    min-height: 100vh;
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
}

.login-form {
    background: #ffffff;
    padding: 40px;
    border-radius: 8px;
    box-shadow: 0 10px 40px rgba(0,0,0,0.2);
    max-width: 400px;
    width: 100%;
}

.login-form h1 {
    text-align: center;
    margin-bottom: 30px;
    color: #11324d;
    font-size: 24px;
    font-weight: 300;
}

.login-form .form-group {
    margin-bottom: 20px;
}

.login-form label {
    display: block;
    margin-bottom: 5px;
    color: #67768a;
    font-weight: 500;
}

.login-form input[type="text"],
.login-form input[type="password"] {
    width: 100%;
    padding: 12px 15px;
    border: 1px solid #ddd;
    border-radius: 4px;
    font-size: 14px;
    transition: border-color 0.3s;
}

.login-form input[type="text"]:focus,
.login-form input[type="password"]:focus {
    outline: none;
    border-color: #5e63b6;
    box-shadow: 0 0 0 3px rgba(94, 99, 182, 0.1);
}

.login-form button[type="submit"],
.login-form .btn-primary {
    width: 100%;
    padding: 12px;
    background: #5e63b6;
    border: none;
    border-radius: 4px;
    color: #ffffff;
    font-size: 16px;
    font-weight: 500;
    cursor: pointer;
    transition: background-color 0.3s;
}

.login-form button[type="submit"]:hover,
.login-form .btn-primary:hover {
    background: #4a4f93;
}

/* Dashboard Styles - Basic */
.AknHeader {
    background: #11324d;
    color: #ffffff;
    padding: 15px 20px;
    display: flex;
    align-items: center;
    justify-content: space-between;
}

.AknHeader-logo {
    height: 30px;
}

.oro-navigation,
.navigation {
    background: #ffffff;
    border-bottom: 1px solid #e8e8e8;
    padding: 10px 20px;
}

.oro-navigation ul,
.navigation ul {
    list-style: none;
    display: flex;
    gap: 20px;
}

.oro-navigation a,
.navigation a {
    color: #11324d;
    text-decoration: none;
    font-weight: 500;
    transition: color 0.3s;
}

.oro-navigation a:hover,
.navigation a:hover {
    color: #5e63b6;
}

#container {
    padding: 20px;
    max-width: 1400px;
    margin: 0 auto;
}

/* Alerts and Messages */
.alert {
    padding: 15px;
    margin-bottom: 20px;
    border-radius: 4px;
}

.alert-error,
.alert-danger {
    background: #f8d7da;
    color: #721c24;
    border: 1px solid #f5c6cb;
}

.alert-success {
    background: #d4edda;
    color: #155724;
    border: 1px solid #c3e6cb;
}

/* Loading Animation */
.AknLoadingPlaceHolder {
    display: flex;
    align-items: center;
    justify-content: center;
    min-height: 200px;
}

.AknLoadingPlaceHolder:after {
    content: "";
    width: 40px;
    height: 40px;
    border: 4px solid #f3f3f3;
    border-top: 4px solid #5e63b6;
    border-radius: 50%;
    animation: spin 1s linear infinite;
}

@keyframes spin {
    0% { transform: rotate(0deg); }
    100% { transform: rotate(360deg); }
}

/* Utility Classes */
.hidden { display: none; }
.text-center { text-align: center; }
.mt-10 { margin-top: 10px; }
.mb-10 { margin-bottom: 10px; }
CSS

echo "✅ Minimal CSS created"
ls -lh public/css/pim.css
SIZE=$(stat -c%s public/css/pim.css)
echo "Size: $SIZE bytes ($(($SIZE / 1024)) KB)"
echo "CSS Rules: $(grep -o '{' public/css/pim.css | wc -l)"

# Set permissions
chown pim:pim public/css/pim.css
chmod 644 public/css/pim.css

# Clear cache
echo ""
echo "Clearing cache..."
rm -rf var/cache/prod/*
php bin/console cache:clear --env=prod --no-warmup 2>&1 | tail -2

echo ""
echo "=== CSS Ready for Testing ==="
