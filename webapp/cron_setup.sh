#!/bin/bash
#
# Cron Jobs Setup for Akeneo PIM
# Automated monitoring, backups, and maintenance
#
# Date: 2026-04-30
# Repository: https://github.com/mounirtms/akeneoPim.git

cat << 'EOF'
# Akeneo PIM Automated Tasks
# Generated: 2026-04-30

# Health monitoring - every 30 minutes
*/30 * * * * cd /home/pim/public_html/webapp && php telegram_bot.php health >> /home/pim/public_html/var/logs/telegram_health.log 2>&1

# Database backup - daily at 2 AM
0 2 * * * cd /home/pim/public_html/webapp && ./akeneo_service_manager.sh backup-db >> /home/pim/public_html/var/logs/backup.log 2>&1

# Full system backup - weekly on Sunday at 3 AM
0 3 * * 0 cd /home/pim/public_html/webapp && ./akeneo_service_manager.sh backup-full >> /home/pim/public_html/var/logs/backup.log 2>&1

# Cache cleanup - daily at 4 AM
0 4 * * * cd /home/pim/public_html && php bin/console cache:clear --env=prod >> /home/pim/public_html/var/logs/cache_cleanup.log 2>&1

# Check disk space - every hour
0 * * * * DISK_USAGE=$(df -h /home/pim/public_html | tail -1 | awk '{print $5}' | sed 's/%//'); if [ $DISK_USAGE -gt 80 ]; then cd /home/pim/public_html/webapp && php telegram_bot.php alert "Disk Space Warning" "Disk usage is at ${DISK_USAGE}%" "warning"; fi

# Check memory usage - every hour
0 * * * * MEM_USAGE=$(free | grep Mem | awk '{print int($3/$2 * 100)}'); if [ $MEM_USAGE -gt 90 ]; then cd /home/pim/public_html/webapp && php telegram_bot.php alert "Memory Warning" "Memory usage is at ${MEM_USAGE}%" "warning"; fi

# Elasticsearch health check - every 2 hours
0 */2 * * * ES_STATUS=$(curl -s http://localhost:9200/_cluster/health | grep -o '"status":"[^"]*"' | cut -d'"' -f4); if [ "$ES_STATUS" = "red" ]; then cd /home/pim/public_html/webapp && php telegram_bot.php alert "Elasticsearch Alert" "Elasticsearch status is RED" "critical"; fi

# Clean old logs - weekly on Monday at 1 AM
0 1 * * 1 find /home/pim/public_html/var/logs -name "*.log" -mtime +30 -delete

# Clean old backups - keep last 14 days
0 5 * * * find /home/pim/public_html/backups -name "*.tar.gz" -mtime +14 -delete
0 5 * * * find /home/pim/public_html/backups -name "*.sql.gz" -mtime +14 -delete

EOF

echo ""
echo "To install these cron jobs, run:"
echo "  crontab -e"
echo ""
echo "Then paste the above content into your crontab."
echo ""
echo "Or install automatically (requires crontab access):"
echo "  cat webapp/cron_setup.sh | grep -v '^#' | grep -v '^$' | crontab -"
