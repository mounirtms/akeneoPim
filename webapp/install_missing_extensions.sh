#!/bin/bash
set -e

LOG_FILE="logs/extension_install_$(date +%Y%m%d_%H%M%S).log"
mkdir -p logs

echo "=== Installing Missing PHP Extensions ===" | tee -a "$LOG_FILE"
echo "Date: $(date)" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Check current PHP version and path
echo "1. Checking PHP configuration..." | tee -a "$LOG_FILE"
php -v | head -3 | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Check if APCu is available via yum
echo "2. Checking APCu package availability..." | tee -a "$LOG_FILE"
if yum list available 2>/dev/null | grep -q "ea-php82-php-pecl-apcu"; then
    echo "✓ APCu package found via yum" | tee -a "$LOG_FILE"
    echo "Installing ea-php82-php-pecl-apcu..." | tee -a "$LOG_FILE"
    yum install -y ea-php82-php-pecl-apcu 2>&1 | tee -a "$LOG_FILE"
else
    echo "⚠ APCu not found in yum, trying PECL..." | tee -a "$LOG_FILE"
    
    # Try PECL installation
    echo "Attempting PECL installation..." | tee -a "$LOG_FILE"
    pecl channel-update pecl.php.net 2>&1 | tee -a "$LOG_FILE"
    pecl install -f apcu 2>&1 | tee -a "$LOG_FILE" || {
        echo "⚠ PECL installation requires root/sudo access" | tee -a "$LOG_FILE"
    }
fi

echo "" | tee -a "$LOG_FILE"

# Verify extensions after installation
echo "3. Verifying installed extensions..." | tee -a "$LOG_FILE"
echo "Redis: $(php -m | grep -i redis || echo 'NOT FOUND')" | tee -a "$LOG_FILE"
echo "APCu: $(php -m | grep -i apcu || echo 'NOT FOUND')" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# If extensions are still missing, install predis as fallback
echo "4. Installing predis/predis as Redis client..." | tee -a "$LOG_FILE"
cd /home/pim/public_html
COMPOSER_ALLOW_SUPERUSER=1 composer require predis/predis --ignore-platform-req=ext-apcu --no-interaction 2>&1 | tee -a "$LOG_FILE"

echo "" | tee -a "$LOG_FILE"
echo "5. Verifying predis installation..." | tee -a "$LOG_FILE"
COMPOSER_ALLOW_SUPERUSER=1 composer show predis/predis 2>&1 | tee -a "$LOG_FILE" || echo "Predis not found" | tee -a "$LOG_FILE"

echo "" | tee -a "$LOG_FILE"
echo "=== Installation Complete ===" | tee -a "$LOG_FILE"
echo "Log saved to: $LOG_FILE"
