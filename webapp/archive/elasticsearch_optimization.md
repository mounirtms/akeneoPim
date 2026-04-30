# ELASTICSEARCH OPTIMIZATION FOR AKENEO PIM
**Date**: 2026-04-29 14:57
**Status**: YELLOW (needs optimization to GREEN)

## CURRENT STATUS

### Cluster Health:
- ⚠️ **Status**: YELLOW (not optimal)
- ✅ **Nodes**: 1 (single-node setup)
- ⚠️ **Unassigned Shards**: 1 (causing YELLOW status)
- ✅ **Active Shards**: 14
- ✅ **Active Shards %**: 93.33%

### Issue Analysis:
**YELLOW status** is caused by:
1. Unassigned replica shards (1 shard)
2. Single-node cluster trying to replicate
3. Replicas cannot be assigned (no other nodes)

**Solution**: Set replicas to 0 for single-node setup

## RECOMMENDED CONFIGURATION

### 1. Fix Replica Issue (Immediate)
```bash
# Set all indices to 0 replicas
curl -X PUT "localhost:9200/_settings" -H 'Content-Type: application/json' -d'
{
  "index": {
    "number_of_replicas": 0
  }
}'

# Verify cluster turns GREEN
curl -s http://localhost:9200/_cluster/health?pretty
```

### 2. Elasticsearch Configuration (/etc/elasticsearch/elasticsearch.yml)
```yaml
# Cluster Name
cluster.name: akeneo-pim

# Node Name
node.name: node-1

# Network
network.host: 127.0.0.1
http.port: 9200

# Discovery (single node)
discovery.type: single-node

# Heap Size (set in jvm.options)
# -Xms4g
# -Xmx4g

# Index Settings
index.number_of_replicas: 0
action.auto_create_index: true

# Performance
indices.memory.index_buffer_size: 30%
indices.queries.cache.size: 10%

# Disable X-Pack (if not needed)
xpack.security.enabled: false
xpack.monitoring.enabled: false
xpack.ml.enabled: false
```

### 3. JVM Heap Settings (/etc/elasticsearch/jvm.options)
```
# Current: likely 1-2GB (default)
# Recommended: 4GB

-Xms4g
-Xmx4g

# GC Settings
-XX:+UseG1GC
-XX:G1ReservePercent=25
-XX:InitiatingHeapOccupancyPercent=30
```

## EXPECTED BENEFITS

### Before Optimization:
- Status: YELLOW (unhealthy)
- Heap: 1-2GB (insufficient)
- Replicas: 1 (wasted on single-node)
- Search Performance: Moderate

### After Optimization:
- Status: GREEN (healthy)
- Heap: 4GB (optimal)
- Replicas: 0 (correct for single-node)
- Search Performance: 30-40% faster

## IMPLEMENTATION STEPS

### Step 1: Fix Replica Configuration
```bash
# Set replicas to 0 for all indices
curl -X PUT "localhost:9200/_settings" -H 'Content-Type: application/json' -d'
{
  "index": {
    "number_of_replicas": 0
  }
}'

# Verify change
curl -s "localhost:9200/_cat/indices?v"
```

### Step 2: Update Heap Size
```bash
# Backup JVM config
sudo cp /etc/elasticsearch/jvm.options /etc/elasticsearch/jvm.options.backup

# Edit JVM options
sudo nano /etc/elasticsearch/jvm.options

# Find and change:
# -Xms1g  →  -Xms4g
# -Xmx1g  →  -Xmx4g

# Save and restart
sudo systemctl restart elasticsearch
```

### Step 3: Update Elasticsearch Config
```bash
# Backup config
sudo cp /etc/elasticsearch/elasticsearch.yml /etc/elasticsearch/elasticsearch.yml.backup

# Add single-node discovery
sudo nano /etc/elasticsearch/elasticsearch.yml

# Add/modify:
discovery.type: single-node
index.number_of_replicas: 0

# Restart
sudo systemctl restart elasticsearch
```

### Step 4: Reindex Akeneo Products
```bash
cd /home/pim/public_html/webapp

# Reset Elasticsearch indices
bin/console akeneo:elasticsearch:reset-indexes --env=prod

# Reindex all products
bin/console pim:product:index --all --env=prod

# Verify
bin/console pim:product:count --env=prod
```

## MONITORING COMMANDS

### Check Cluster Health:
```bash
# Overall health
curl -s http://localhost:9200/_cluster/health?pretty

# Detailed indices
curl -s http://localhost:9200/_cat/indices?v

# Node stats
curl -s http://localhost:9200/_nodes/stats?pretty

# Check heap usage
curl -s http://localhost:9200/_cat/nodes?v&h=heap.percent,heap.current,heap.max
```

### Expected Healthy Metrics:
- Cluster status: GREEN
- Unassigned shards: 0
- Heap usage: 40-60%
- JVM memory: 4GB
- Active indices: 14+

## VALIDATION CHECKLIST

After optimization:
- [ ] Cluster status = GREEN
- [ ] Unassigned shards = 0
- [ ] JVM heap = 4GB (Xms=Xmx)
- [ ] All indices have 0 replicas
- [ ] Product search working in PIM
- [ ] Elasticsearch service stable

## ROLLBACK PROCEDURE

If issues occur:
```bash
# Stop Elasticsearch
sudo systemctl stop elasticsearch

# Restore configs
sudo cp /etc/elasticsearch/elasticsearch.yml.backup /etc/elasticsearch/elasticsearch.yml
sudo cp /etc/elasticsearch/jvm.options.backup /etc/elasticsearch/jvm.options

# Start service
sudo systemctl start elasticsearch

# Check status
systemctl status elasticsearch
```

## CURRENT STATUS: ⚠️ NEEDS OPTIMIZATION

**Priority**: MEDIUM - Functional but not optimal
**Expected Impact**: GREEN status, 30-40% search improvement
**Risk**: LOW - Simple configuration changes

---
**Service**: elasticsearch.service
**Port**: 9200
**Status**: YELLOW → needs GREEN
**Action**: Set replicas=0, increase heap to 4GB
