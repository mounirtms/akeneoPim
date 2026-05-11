#!/bin/bash
# Akeneo PIM <-> Magento Automated Sync
# Runs nightly at 2 AM via cron
# crontab entry: 0 2 * * * /home/pim/public_html/webapp/sync_cron.sh >> /home/pim/public_html/var/logs/cron_sync.log 2>&1

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG="/home/pim/public_html/var/logs/cron_sync_$TIMESTAMP.log"

echo "[$TIMESTAMP] Starting nightly sync..." >> "$LOG"

# Step 1: Reindex Elasticsearch
cd /home/pim/public_html
php bin/console pim:product:index --all --env=prod >> "$LOG" 2>&1
php bin/console pim:product-model:index --all --env=prod >> "$LOG" 2>&1

# Step 2: Publish export job to queue
php bin/console akeneo:batch:publish-job-to-queue csv_product_export --env=prod >> "$LOG" 2>&1

# Step 3: Process the export job (consume from import_export_job queue)
php bin/console messenger:consume import_export_job --limit=5 --time-limit=120 --env=prod >> "$LOG" 2>&1

# Step 4: Clean stuck job executions
php bin/console akeneo:batch:clean-job-executions --env=prod >> "$LOG" 2>&1

echo "[$TIMESTAMP] Sync complete." >> "$LOG"

# Cleanup old logs (keep 30 days)
find /home/pim/public_html/var/logs/ -name "cron_sync_*.log" -mtime +30 -delete 2>/dev/null
