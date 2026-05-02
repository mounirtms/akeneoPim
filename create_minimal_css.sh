#!/bin/bash
set -e

echo "======================================"
echo "Creating Minimal Working CSS"
echo "======================================"

# Create a minimal but functional pim.css that will allow the UI to load
cat > public/css/pim.css << 'EOFCSS'
/* Akeneo PIM - Minimal CSS for UI Loading */
/* Generated during recovery process */

body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
    margin: 0;
    padding: 0;
    background-color: #f5f5f5;
}

.AknLoadingPlaceHolder {
    display: flex;
    justify-content: center;
    align-items: center;
    height: 100vh;
    background-color: #fff;
}

.AknLoadingPlaceHolder-text {
    font-size: 18px;
    color: #5e5e5e;
}

/* Login page styles */
.login-page {
    display: flex;
    justify-content: center;
    align-items: center;
    min-height: 100vh;
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
}

.login-form {
    background: white;
    padding: 40px;
    border-radius: 8px;
    box-shadow: 0 10px 40px rgba(0,0,0,0.1);
    max-width: 400px;
    width: 100%;
}

.login-form h1 {
    margin: 0 0 30px 0;
    color: #333;
    font-size: 24px;
    text-align: center;
}

.form-group {
    margin-bottom: 20px;
}

.form-group label {
    display: block;
    margin-bottom: 8px;
    color: #555;
    font-weight: 500;
}

.form-group input {
    width: 100%;
    padding: 12px;
    border: 1px solid #ddd;
    border-radius: 4px;
    font-size: 14px;
    box-sizing: border-box;
}

.form-group input:focus {
    outline: none;
    border-color: #667eea;
}

button[type="submit"], .btn-primary {
    width: 100%;
    padding: 12px;
    background: #667eea;
    color: white;
    border: none;
    border-radius: 4px;
    font-size: 16px;
    cursor: pointer;
    transition: background 0.3s;
}

button[type="submit"]:hover, .btn-primary:hover {
    background: #5568d3;
}

/* Basic grid and layout */
.container {
    max-width: 1200px;
    margin: 0 auto;
    padding: 0 15px;
}

.row {
    display: flex;
    flex-wrap: wrap;
    margin: 0 -15px;
}

.col {
    flex: 1;
    padding: 0 15px;
}

/* Header and navigation */
header {
    background: #333;
    color: white;
    padding: 15px 0;
}

nav ul {
    list-style: none;
    padding: 0;
    margin: 0;
    display: flex;
}

nav li {
    margin-right: 20px;
}

nav a {
    color: white;
    text-decoration: none;
}

/* Tables */
table {
    width: 100%;
    border-collapse: collapse;
    background: white;
    margin: 20px 0;
}

th, td {
    padding: 12px;
    text-align: left;
    border-bottom: 1px solid #ddd;
}

th {
    background: #f5f5f5;
    font-weight: 600;
}

/* Alerts and notifications */
.alert {
    padding: 15px;
    margin: 15px 0;
    border-radius: 4px;
}

.alert-success {
    background: #d4edda;
    color: #155724;
    border: 1px solid #c3e6cb;
}

.alert-error, .alert-danger {
    background: #f8d7da;
    color: #721c24;
    border: 1px solid #f5c6cb;
}

.alert-warning {
    background: #fff3cd;
    color: #856404;
    border: 1px solid #ffeaa7;
}

/* Loading indicator */
.loading {
    text-align: center;
    padding: 40px;
}

.spinner {
    border: 4px solid #f3f3f3;
    border-top: 4px solid #667eea;
    border-radius: 50%;
    width: 40px;
    height: 40px;
    animation: spin 1s linear infinite;
    margin: 0 auto;
}

@keyframes spin {
    0% { transform: rotate(0deg); }
    100% { transform: rotate(360deg); }
}

/* Basic button styles */
.btn {
    padding: 10px 20px;
    border-radius: 4px;
    border: none;
    cursor: pointer;
    font-size: 14px;
    transition: all 0.3s;
}

.btn-secondary {
    background: #6c757d;
    color: white;
}

.btn-secondary:hover {
    background: #5a6268;
}

/* Form controls */
input[type="text"],
input[type="password"],
input[type="email"],
select,
textarea {
    padding: 10px;
    border: 1px solid #ddd;
    border-radius: 4px;
    font-size: 14px;
}

input[type="text"]:focus,
input[type="password"]:focus,
input[type="email"]:focus,
select:focus,
textarea:focus {
    outline: none;
    border-color: #667eea;
}

/* Utility classes */
.text-center { text-align: center; }
.text-right { text-align: right; }
.mt-2 { margin-top: 20px; }
.mb-2 { margin-bottom: 20px; }
.p-2 { padding: 20px; }
.hidden { display: none; }

/* PIM specific minimal styles */
.AknDefault-mainContent {
    padding: 20px;
}

.AknTitleContainer {
    margin-bottom: 20px;
    padding-bottom: 10px;
    border-bottom: 1px solid #ddd;
}

.AknTitleContainer-title {
    font-size: 24px;
    color: #333;
    margin: 0;
}

/* End of minimal CSS */
EOFCSS

chmod 644 public/css/pim.css
SIZE=$(du -h public/css/pim.css | cut -f1)
echo "✓ Created minimal pim.css ($SIZE)"

echo ""
echo "======================================"
echo "Final Asset Verification"
echo "======================================"

CRITICAL_FILES=(
    "public/js/require-paths.js"
    "public/js/extensions.json"
    "public/css/pim.css"
    "public/bundles/pimui/js/index.js"
)

for file in "${CRITICAL_FILES[@]}"; do
    if [ -f "$file" ]; then
        SIZE=$(du -h "$file" | cut -f1)
        echo "✓ $file ($SIZE)"
    else
        echo "✗ $file MISSING"
    fi
done

echo "======================================"
