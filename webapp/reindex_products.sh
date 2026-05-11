#!/bin/bash
# Akeneo PIM - Product Reindex Script
# This script reindexes all products and product models from MySQL to Elasticsearch
# Usage: ./reindex_products.sh

set -e

WORK_DIR="/home/pim/public_html"
cd "$WORK_DIR"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "================================================================="
echo "        AKENEO PIM - PRODUCT REINDEX UTILITY"
echo "================================================================="
echo ""

# Check if Elasticsearch is running
echo "🔍 1. Checking Elasticsearch status..."
ES_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9200/_cluster/health 2>/dev/null || echo "000")
if [ "$ES_STATUS" != "200" ]; then
    echo -e "${RED}❌ Elasticsearch is not responding (HTTP $ES_STATUS)${NC}"
    echo "   Please ensure Elasticsearch is running on localhost:9200"
    exit 1
fi
echo -e "${GREEN}✅ Elasticsearch is healthy${NC}"
echo ""

# Check database connection
echo "🗄️  2. Checking database connection..."
if php bin/console doctrine:query:sql "SELECT 1" --env=prod > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Database connection is healthy${NC}"
else
    echo -e "${RED}❌ Database connection failed${NC}"
    exit 1
fi
echo ""

# Get product counts
echo "📊 3. Getting current counts..."
MYSQL_COUNT=$(php bin/console doctrine:query:sql "SELECT COUNT(*) as count FROM pim_catalog_product" --env=prod 2>/dev/null | grep -oP '"count"=>\s*int\(\K[0-9]+' || echo "0")
MYSQL_MODEL_COUNT=$(php bin/console doctrine:query:sql "SELECT COUNT(*) as count FROM pim_catalog_product_model" --env=prod 2>/dev/null | grep -oP '"count"=>\s*int\(\K[0-9]+' || echo "0")
ES_COUNT=$(curl -s http://localhost:9200/akeneo_pim_product_and_product_model/_count 2>/dev/null | grep -oP '"count":\K[0-9]+' || echo "0")

echo "   MySQL Products:        $MYSQL_COUNT"
echo "   MySQL Product Models:  $MYSQL_MODEL_COUNT"
echo "   Elasticsearch Total:   $ES_COUNT"
echo ""

# Confirm reindex
if [ "$ES_COUNT" -gt 0 ]; then
    echo -e "${YELLOW}⚠️  WARNING: Elasticsearch index already contains $ES_COUNT items${NC}"
    echo "   This will reset and rebuild the entire index"
    read -p "   Do you want to continue? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo "   Reindex cancelled"
        exit 0
    fi
fi

# Reset Elasticsearch indexes
echo ""
echo "🔄 4. Resetting Elasticsearch indexes..."
php -d allow_url_fopen=1 bin/console akeneo:elasticsearch:reset-indexes --index=product_and_product_model --env=prod --no-interaction 2>&1
echo -e "${GREEN}✅ Indexes reset successfully${NC}"
echo ""

# Reindex products
echo "📦 5. Reindexing products..."
echo "   This may take several minutes for large catalogs..."
START_TIME=$(date +%s)
php -d allow_url_fopen=1 -d memory_limit=1G bin/console pim:product:index --all --env=prod 2>&1
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
echo -e "${GREEN}✅ Products indexed in ${DURATION}s${NC}"
echo ""

# Reindex product models
echo "📦 6. Reindexing product models..."
START_TIME=$(date +%s)
php -d allow_url_fopen=1 -d memory_limit=1G bin/console pim:product-model:index --all --env=prod 2>&1
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
echo -e "${GREEN}✅ Product models indexed in ${DURATION}s${NC}"
echo ""

# Verify results
echo "✓ 7. Verifying reindex..."
sleep 2
NEW_ES_COUNT=$(curl -s http://localhost:9200/akeneo_pim_product_and_product_model/_count 2>/dev/null | grep -oP '"count":\K[0-9]+' || echo "0")

echo "   MySQL Total:           $((MYSQL_COUNT + MYSQL_MODEL_COUNT))"
echo "   Elasticsearch Total:   $NEW_ES_COUNT"

if [ "$NEW_ES_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✅ Reindex completed successfully!${NC}"
    
    # Calculate difference
    EXPECTED=$((MYSQL_COUNT + MYSQL_MODEL_COUNT))
    DIFF=$((EXPECTED - NEW_ES_COUNT))
    
    if [ "$DIFF" -ne 0 ]; then
        echo -e "${YELLOW}⚠️  Note: Difference of $DIFF items between MySQL and Elasticsearch${NC}"
        echo "   This is normal if some products are incomplete or have validation errors"
    fi
else
    echo -e "${RED}❌ Reindex may have failed - Elasticsearch count is 0${NC}"
    echo "   Check logs: tail -100 var/logs/prod.log"
    exit 1
fi

echo ""
echo "================================================================="
echo "                    REINDEX COMPLETE"
echo "================================================================="
echo ""
echo "Next steps:"
echo "  1. Clear Symfony cache: php bin/console cache:clear --env=prod"
echo "  2. Test product search in PIM UI"
echo "  3. Verify product listings and filters"
echo ""
echo "If products still don't appear:"
echo "  - Check browser cache (Ctrl+Shift+R to hard refresh)"
echo "  - Check var/logs/prod.log for errors"
echo "  - Verify user permissions in PIM"
echo ""
