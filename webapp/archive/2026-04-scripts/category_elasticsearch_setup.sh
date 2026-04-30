#!/bin/bash
# Category Structure Optimization & Elasticsearch Tuning
# Purpose: Optimize category hierarchy and search indexing

set -e

WORK_DIR="/home/pim/public_html"
cd "$WORK_DIR"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "================================================================="
echo "   CATEGORY OPTIMIZATION & ELASTICSEARCH TUNING"
echo "================================================================="
echo ""

# Create optimization directories
mkdir -p var/category_optimization
mkdir -p var/elasticsearch_config

echo -e "${BLUE}📊 PHASE 1: Category Structure Analysis${NC}"
echo "-----------------------------------------------------------------"

# Analyze category structure
TOTAL_CATS=$(php bin/console doctrine:query:sql "SELECT COUNT(*) FROM pim_catalog_category" --env=prod 2>/dev/null | grep -oP '\d+' | tail -1)
echo "   Total Categories: ${TOTAL_CATS}"

# Root categories
ROOT_CATS=$(php bin/console doctrine:query:sql "SELECT COUNT(*) FROM pim_catalog_category WHERE parent_id IS NULL" --env=prod 2>/dev/null | grep -oP '\d+' | tail -1)
echo "   Root Categories: ${ROOT_CATS}"

# Create category analysis report
cat > var/category_optimization/category_analysis.sql << 'EOF'
-- Category Structure Analysis Queries

-- 1. Category depth analysis
SELECT 
    c.code,
    c.lft,
    c.rgt,
    (c.rgt - c.lft - 1) / 2 as descendants_count
FROM pim_catalog_category c
WHERE c.parent_id IS NULL
ORDER BY descendants_count DESC;

-- 2. Empty categories (no products)
SELECT c.code, c.id
FROM pim_catalog_category c
LEFT JOIN pim_catalog_category_product cp ON c.id = cp.category_id
WHERE cp.product_id IS NULL
LIMIT 100;

-- 3. Categories with most products
SELECT 
    c.code,
    COUNT(cp.product_id) as product_count
FROM pim_catalog_category c
LEFT JOIN pim_catalog_category_product cp ON c.id = cp.category_id
GROUP BY c.id, c.code
ORDER BY product_count DESC
LIMIT 20;

-- 4. Category tree depth
SELECT 
    MAX(level) as max_depth,
    AVG(level) as avg_depth
FROM (
    SELECT 
        c1.id,
        COUNT(c2.id) as level
    FROM pim_catalog_category c1
    LEFT JOIN pim_catalog_category c2 ON c1.lft BETWEEN c2.lft AND c2.rgt
    GROUP BY c1.id
) as depths;
EOF

echo "   ✓ Created category analysis SQL"

# Category optimization recommendations
cat > var/category_optimization/optimization_rules.yml << 'EOF'
# Category Optimization Rules

structure_guidelines:
  max_depth: 4
  description: "Maximum 4 levels deep (Root > L1 > L2 > L3)"
  reason: "Deeper hierarchies confuse users and hurt SEO"
  
  min_products_per_category: 3
  description: "Each category should have at least 3 products"
  reason: "Avoid empty or sparse categories"
  
  max_products_per_category: 500
  description: "Split categories with more than 500 products"
  reason: "Improves browsing performance and user experience"
  
  sibling_count: 12
  description: "Maximum 12 subcategories per parent"
  reason: "Prevents overwhelming navigation menus"

naming_conventions:
  format: "Clear, descriptive, unique"
  examples:
    good:
      - "Office Supplies > Writing Instruments > Pens > Ballpoint Pens"
      - "Arts & Crafts > Painting > Brushes"
    bad:
      - "Products > Category1 > Sub1"
      - "Items > Misc > Other"
      
  rules:
    - "Use proper capitalization"
    - "Avoid special characters"
    - "Keep names under 50 characters"
    - "Use singular or plural consistently"
    - "Include relevant keywords for SEO"

seo_optimization:
  url_key:
    - "Use lowercase"
    - "Replace spaces with hyphens"
    - "Remove special characters"
    - "Keep short and descriptive"
    example: "office-supplies/writing-instruments/pens"
    
  meta_title:
    length: "50-60 characters"
    format: "{Category Name} | {Brand Name}"
    example: "Ballpoint Pens | Techno Stationery"
    
  meta_description:
    length: "150-160 characters"
    format: "Browse our {category} collection. {Key features}. {Call to action}."
    example: "Browse our ballpoint pens collection. Wide selection, affordable prices. Shop now!"

maintenance_tasks:
  weekly:
    - "Identify empty categories"
    - "Check for orphaned products"
    - "Review new category requests"
    
  monthly:
    - "Analyze category performance"
    - "Review and merge similar categories"
    - "Update category descriptions and SEO"
    - "Rebalance overloaded categories"
    
  quarterly:
    - "Full category structure audit"
    - "Reorganize based on sales data"
    - "Update navigation menus"
    - "Review and update URL structure"
EOF

echo "   ✓ Created optimization rules"

echo ""
echo -e "${BLUE}🔍 PHASE 2: Elasticsearch Configuration${NC}"
echo "-----------------------------------------------------------------"

# Elasticsearch index settings
cat > var/elasticsearch_config/index_settings.json << 'EOF'
{
  "settings": {
    "number_of_shards": 3,
    "number_of_replicas": 1,
    "refresh_interval": "30s",
    "max_result_window": 10000,
    
    "analysis": {
      "analyzer": {
        "product_analyzer": {
          "type": "custom",
          "tokenizer": "standard",
          "filter": [
            "lowercase",
            "asciifolding",
            "stop",
            "product_synonym"
          ]
        },
        "sku_analyzer": {
          "type": "custom",
          "tokenizer": "keyword",
          "filter": ["lowercase"]
        },
        "autocomplete_analyzer": {
          "type": "custom",
          "tokenizer": "standard",
          "filter": [
            "lowercase",
            "autocomplete_filter"
          ]
        }
      },
      "filter": {
        "autocomplete_filter": {
          "type": "edge_ngram",
          "min_gram": 2,
          "max_gram": 20
        },
        "product_synonym": {
          "type": "synonym",
          "synonyms": [
            "pen, ballpoint, biro",
            "notebook, notepad, journal",
            "marker, highlighter",
            "pencil, lead pencil",
            "eraser, rubber"
          ]
        }
      }
    }
  },
  
  "mappings": {
    "properties": {
      "identifier": {
        "type": "text",
        "fields": {
          "keyword": {"type": "keyword"},
          "analyzed": {"type": "text", "analyzer": "sku_analyzer"}
        }
      },
      "name": {
        "type": "text",
        "analyzer": "product_analyzer",
        "fields": {
          "autocomplete": {"type": "text", "analyzer": "autocomplete_analyzer"},
          "keyword": {"type": "keyword"}
        }
      },
      "description": {
        "type": "text",
        "analyzer": "product_analyzer"
      },
      "categories": {
        "type": "keyword"
      },
      "price": {
        "type": "scaled_float",
        "scaling_factor": 100
      },
      "is_enabled": {
        "type": "boolean"
      },
      "created": {
        "type": "date"
      },
      "updated": {
        "type": "date"
      }
    }
  }
}
EOF

echo "   ✓ Created Elasticsearch index settings"

# Search optimization configuration
cat > var/elasticsearch_config/search_optimization.yml << 'EOF'
# Elasticsearch Search Optimization

query_optimization:
  boost_factors:
    name: 3.0
    description: 1.0
    sku: 2.0
    categories: 1.5
    brand: 2.0
    
  fuzzy_search:
    enabled: true
    fuzziness: "AUTO"
    max_expansions: 50
    prefix_length: 2
    
  autocomplete:
    min_chars: 2
    max_results: 10
    boost_recent: true
    
  facets:
    - name: "categories"
      type: "terms"
      size: 20
    - name: "brand"
      type: "terms"
      size: 15
    - name: "price"
      type: "range"
      ranges:
        - {to: 10}
        - {from: 10, to: 50}
        - {from: 50, to: 100}
        - {from: 100}
    - name: "is_enabled"
      type: "terms"

performance_tuning:
  cache:
    query_cache: true
    request_cache: true
    field_data_cache_size: "20%"
    
  routing:
    enabled: true
    field: "family"
    
  refresh_interval: "30s"
  max_concurrent_shard_requests: 5
  
  bulk_indexing:
    batch_size: 500
    concurrent_requests: 2
    flush_interval: "5s"

monitoring:
  slow_query_threshold: "1s"
  log_slow_queries: true
  track_total_hits: 10000
  
health_checks:
  - metric: "cluster_health"
    threshold: "yellow"
  - metric: "node_stats"
    check_disk: true
    disk_threshold: "85%"
  - metric: "index_stats"
    check_size: true
  - metric: "search_performance"
    avg_query_time: "500ms"
EOF

echo "   ✓ Created search optimization config"

# Elasticsearch management scripts
cat > var/elasticsearch_config/es_manager.sh << 'EOFES'
#!/bin/bash
# Elasticsearch Management Helper

ES_HOST="localhost:9200"

case "$1" in
  health)
    echo "Elasticsearch Cluster Health:"
    curl -s "http://$ES_HOST/_cluster/health?pretty"
    ;;
    
  indices)
    echo "Elasticsearch Indices:"
    curl -s "http://$ES_HOST/_cat/indices?v"
    ;;
    
  stats)
    echo "Index Statistics:"
    curl -s "http://$ES_HOST/_cat/indices?v&s=store.size:desc"
    ;;
    
  reindex)
    echo "Reindexing Akeneo products..."
    cd /home/pim/public_html
    php bin/console akeneo:elasticsearch:reset-indexes --env=prod
    ;;
    
  optimize)
    echo "Optimizing indices..."
    curl -XPOST "http://$ES_HOST/_forcemerge?max_num_segments=1"
    ;;
    
  clear-cache)
    echo "Clearing Elasticsearch cache..."
    curl -XPOST "http://$ES_HOST/_cache/clear"
    ;;
    
  *)
    echo "Elasticsearch Manager"
    echo "Usage: $0 {health|indices|stats|reindex|optimize|clear-cache}"
    echo ""
    echo "Commands:"
    echo "  health      - Check cluster health"
    echo "  indices     - List all indices"
    echo "  stats       - Index statistics"
    echo "  reindex     - Reindex Akeneo products"
    echo "  optimize    - Optimize indices (merge segments)"
    echo "  clear-cache - Clear ES cache"
    ;;
esac
EOFES

chmod +x var/elasticsearch_config/es_manager.sh
echo "   ✓ Created Elasticsearch manager script"

# Daily optimization script
cat > var/elasticsearch_config/daily_optimization.sh << 'EOFOPT'
#!/bin/bash
# Daily Elasticsearch and Category Optimization

WORK_DIR="/home/pim/public_html"
cd "$WORK_DIR"

LOG_FILE="var/elasticsearch_config/optimization_$(date +%Y%m%d).log"

{
  echo "======================================"
  echo "Daily Optimization: $(date)"
  echo "======================================"
  echo ""
  
  # Check Elasticsearch health
  echo "1. Elasticsearch Health Check"
  curl -s http://localhost:9200/_cluster/health | grep -o '"status":"[^"]*"'
  
  # Clear old logs
  echo ""
  echo "2. Clearing old Elasticsearch logs (>7 days)"
  find var/logs -name "*elasticsearch*" -mtime +7 -delete 2>/dev/null || echo "   No old logs found"
  
  # Optimize indices (weekly, on Monday)
  if [ $(date +%u) -eq 1 ]; then
    echo ""
    echo "3. Weekly: Optimizing Elasticsearch indices"
    curl -s -XPOST "http://localhost:9200/_forcemerge?max_num_segments=1" | head -1
  fi
  
  # Analyze table statistics
  echo ""
  echo "4. Analyzing database tables"
  php bin/console doctrine:query:sql "ANALYZE TABLE pim_catalog_product, pim_catalog_category, pim_catalog_attribute" --env=prod >/dev/null 2>&1
  echo "   Database tables analyzed"
  
  echo ""
  echo "Optimization complete at $(date)"
  
} | tee "$LOG_FILE"
EOFOPT

chmod +x var/elasticsearch_config/daily_optimization.sh
echo "   ✓ Created daily optimization script"

echo ""
echo -e "${BLUE}📋 PHASE 3: Performance Monitoring${NC}"
echo "-----------------------------------------------------------------"

# Performance monitoring script
cat > var/elasticsearch_config/performance_monitor.sh << 'EOFPERF'
#!/bin/bash
# Performance Monitoring Script

WORK_DIR="/home/pim/public_html"
cd "$WORK_DIR"

REPORT_FILE="var/elasticsearch_config/performance_$(date +%Y%m%d_%H%M).txt"

{
  echo "======================================"
  echo "  PERFORMANCE REPORT"
  echo "  Generated: $(date)"
  echo "======================================"
  echo ""
  
  echo "ELASTICSEARCH STATUS:"
  ES_STATUS=$(curl -s http://localhost:9200/_cluster/health | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
  echo "  Cluster Status: $ES_STATUS"
  
  echo ""
  echo "INDEX SIZES:"
  curl -s "http://localhost:9200/_cat/indices?v&h=index,docs.count,store.size" | head -10
  
  echo ""
  echo "DATABASE STATISTICS:"
  
  PRODUCTS=$(php bin/console doctrine:query:sql "SELECT COUNT(*) FROM pim_catalog_product" --env=prod 2>/dev/null | grep -oP '\d+' | tail -1)
  echo "  Products: $PRODUCTS"
  
  CATEGORIES=$(php bin/console doctrine:query:sql "SELECT COUNT(*) FROM pim_catalog_category" --env=prod 2>/dev/null | grep -oP '\d+' | tail -1)
  echo "  Categories: $CATEGORIES"
  
  ATTRIBUTES=$(php bin/console doctrine:query:sql "SELECT COUNT(*) FROM pim_catalog_attribute" --env=prod 2>/dev/null | grep -oP '\d+' | tail -1)
  echo "  Attributes: $ATTRIBUTES"
  
  echo ""
  echo "DISK USAGE:"
  df -h /home/pim | tail -1
  
  echo ""
  echo "MEMORY USAGE:"
  free -h | grep -E "Mem|Swap"
  
  echo ""
  echo "======================================"
  
} | tee "$REPORT_FILE"

echo ""
echo "Report saved to: $REPORT_FILE"
EOFPERF

chmod +x var/elasticsearch_config/performance_monitor.sh
echo "   ✓ Created performance monitor"

echo ""
echo "================================================================="
echo "              OPTIMIZATION SETUP COMPLETE"
echo "================================================================="
echo ""
echo -e "${GREEN}📁 Files Created:${NC}"
echo "   Category Optimization:"
echo "     • var/category_optimization/category_analysis.sql"
echo "     • var/category_optimization/optimization_rules.yml"
echo ""
echo "   Elasticsearch Configuration:"
echo "     • var/elasticsearch_config/index_settings.json"
echo "     • var/elasticsearch_config/search_optimization.yml"
echo "     • var/elasticsearch_config/es_manager.sh"
echo "     • var/elasticsearch_config/daily_optimization.sh"
echo "     • var/elasticsearch_config/performance_monitor.sh"
echo ""
echo -e "${GREEN}🚀 Quick Commands:${NC}"
echo "   # Check ES health"
echo "   ./var/elasticsearch_config/es_manager.sh health"
echo ""
echo "   # Performance report"
echo "   ./var/elasticsearch_config/performance_monitor.sh"
echo ""
echo "   # Daily optimization"
echo "   ./var/elasticsearch_config/daily_optimization.sh"
echo ""
echo "================================================================="
