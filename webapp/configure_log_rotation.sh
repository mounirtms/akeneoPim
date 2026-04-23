#!/bin/bash

################################################################################
# Log Rotation Configuration for Akeneo PIM
# Purpose: Control massive log file growth (19MB+ cron log)
# Date: 2026-04-23
################################################################################

echo "=========================================="
echo "Configuring Log Rotation"
echo "=========================================="
echo ""

# Check current log sizes
echo "Current log file sizes:"
du -sh /home/pim/public_html/var/logs/*.log | sort -h | tail -10
echo ""

# Create logrotate config
echo "Creating logrotate configuration..."
sudo tee /etc/logrotate.d/akeneo-pim > /dev/null << 'EOF'
/home/pim/public_html/var/logs/*.log {
    daily
    rotate 7
    compress
    delaycompress
    notifempty
    missingok
    create 0660 pim pim
    sharedscripts
}
EOF

echo "✓ Created /etc/logrotate.d/akeneo-pim"
echo ""

# Manually rotate large logs now
echo "Rotating large log files immediately..."
cd /home/pim/public_html/var/logs

# Rotate cron_messenger.log (19MB)
if [ -f cron_messenger.log ]; then
    SIZE=$(du -m cron_messenger.log | cut -f1)
    if [ "$SIZE" -gt 10 ]; then
        echo "  Rotating cron_messenger.log ($SIZE MB)..."
        gzip -c cron_messenger.log > cron_messenger.log.$(date +%Y%m%d).gz
        > cron_messenger.log
        echo "  ✓ Rotated and compressed"
    fi
fi

# Rotate prod.log if large
if [ -f prod.log ]; then
    SIZE=$(du -m prod.log | cut -f1)
    if [ "$SIZE" -gt 5 ]; then
        echo "  Rotating prod.log ($SIZE MB)..."
        gzip -c prod.log > prod.log.$(date +%Y%m%d).gz
        > prod.log
        echo "  ✓ Rotated and compressed"
    fi
fi

echo ""
echo "New log file sizes:"
du -sh /home/pim/public_html/var/logs/*.log | sort -h | tail -10
echo ""

echo "=========================================="
echo "Log Rotation Complete"
echo "=========================================="
echo ""
echo "Configuration: /etc/logrotate.d/akeneo-pim"
echo "Rotation: Daily"
echo "Retention: 7 days"
echo "Compression: Enabled"
echo ""

exit 0
