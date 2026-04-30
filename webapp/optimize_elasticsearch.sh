#!/bin/bash
# Elasticsearch Optimization Script for Akeneo PIM
# Date: 2026-04-30
# Purpose: Optimize Elasticsearch performance for product search

LOG_FILE="/home/pim/public_html/webapp/logs/elasticsearch_optimization.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

echo "[$DATE] Starting Elasticsearch Optimization..." | tee -a "$LOG_FILE"

# 1. Check Elasticsearch health
echo "Checking Elasticsearch health..." | tee -a "$LOG_FILE"
ES_HEALTH=$(curl -s "localhost:9200/_cluster/health" | grep -o '"status":"[^"]*' | cut -d'"' -f4)
echo "Current status: $ES_HEALTH" | tee -a "$LOG_FILE"

# 2. Optimize index settings for all Akeneo indices
echo "Optimizing index settings..." | tee -a "$LOG_FILE"
curl -s -X PUT "localhost:9200/akeneo_pim_*/_settings" -H 'Content-Type: application/json' -d'{
  "index": {
    "number_of_replicas": 0,
    "refresh_interval": "30s",
    "max_result_window": 50000,
    "codec": "best_compression"
  }
}' >> "$LOG_FILE" 2>&1

curl -s -X PUT "localhost:9200/beta_techno_*/_settings" -H 'Content-Type: application/json' -d'{
  "index": {
    "number_of_replicas": 0,
    "refresh_interval": "30s",
    "max_result_window": 50000,
    "codec": "best_compression"
  }
}' >> "$LOG_FILE" 2>&1

curl -s -X PUT "localhost:9200/techno_stationery_*/_settings" -H 'Content-Type: application/json' -d'{
  "index": {
    "number_of_replicas": 0,
    "refresh_interval": "30s",
    "max_result_window": 50000,
    "codec": "best_compression"
  }
}' >> "$LOG_FILE" 2>&1

# 3. Clear caches
echo "Clearing Elasticsearch caches..." | tee -a "$LOG_FILE"
curl -s -X POST "localhost:9200/_cache/clear" >> "$LOG_FILE" 2>&1

# 4. Force merge to optimize segments (only for indices with data)
echo "Force merging product indices..." | tee -a "$LOG_FILE"
curl -s -X POST "localhost:9200/akeneo_pim_product_and_product_model*/_forcemerge?max_num_segments=1" >> "$LOG_FILE" 2>&1 &
curl -s -X POST "localhost:9200/beta_techno_stationery_*/_forcemerge?max_num_segments=1" >> "$LOG_FILE" 2>&1 &

# Wait for force merge to complete
sleep 10

# 5. Check final index stats
echo "Final index statistics:" | tee -a "$LOG_FILE"
curl -s "http://localhost:9200/_cat/indices?v&h=index,docs.count,store.size,health" | grep -E "(akeneo|beta_techno|techno_stationery)" | tee -a "$LOG_FILE"

# 6. Check cluster stats
echo "Cluster statistics:" | tee -a "$LOG_FILE"
curl -s "localhost:9200/_cluster/stats?pretty" | grep -E "(indices|nodes|jvm|mem)" | tee -a "$LOG_FILE"

echo "[$DATE] Elasticsearch optimization complete!" | tee -a "$LOG_FILE"
echo "---" >> "$LOG_FILE"
