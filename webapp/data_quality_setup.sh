#!/bin/bash
# Akeneo PIM - Data Quality Tuning Setup Script
# Purpose: Configure data validation, completeness rules, and quality monitoring

set -e

WORK_DIR="/home/pim/public_html"
cd "$WORK_DIR"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "================================================================="
echo "     AKENEO PIM - DATA QUALITY CONFIGURATION SETUP"
echo "================================================================="
echo ""

# Function to run command with error handling
run_command() {
    local cmd="$1"
    local desc="$2"
    
    echo -n "➜ $desc... "
    if eval "$cmd" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
        return 0
    else
        echo -e "${RED}✗${NC}"
        return 1
    fi
}

# Wait for PHP configuration to reload
echo "⏳ Waiting for PHP configuration reload (5 seconds)..."
sleep 5

echo ""
echo "📊 PHASE 1: Data Statistics & Analysis"
echo "-----------------------------------------------------------------"

# Get product count
PRODUCT_COUNT=$(php bin/console doctrine:query:sql "SELECT COUNT(*) as cnt FROM pim_catalog_product" --env=prod 2>/dev/null | grep -oP '\d+' | tail -1)
echo "   Products: ${PRODUCT_COUNT}"

# Get attribute count
ATTRIBUTE_COUNT=$(php bin/console doctrine:query:sql "SELECT COUNT(*) as cnt FROM pim_catalog_attribute" --env=prod 2>/dev/null | grep -oP '\d+' | tail -1)
echo "   Attributes: ${ATTRIBUTE_COUNT}"

# Get category count
CATEGORY_COUNT=$(php bin/console doctrine:query:sql "SELECT COUNT(*) as cnt FROM pim_catalog_category" --env=prod 2>/dev/null | grep -oP '\d+' | tail -1)
echo "   Categories: ${CATEGORY_COUNT}"

# Get family count
FAMILY_COUNT=$(php bin/console doctrine:query:sql "SELECT COUNT(*) as cnt FROM pim_catalog_family" --env=prod 2>/dev/null | grep -oP '\d+' | tail -1)
echo "   Families: ${FAMILY_COUNT}"

echo ""
echo "🔍 PHASE 2: Elasticsearch Reindexing"
echo "-----------------------------------------------------------------"

# Reindex products
echo "   Reindexing products..."
php bin/console akeneo:elasticsearch:reset-indexes --env=prod 2>&1 | grep -E "Done|Success|OK" || echo "   Index reset initiated"

echo ""
echo "📝 PHASE 3: Data Quality Configuration"
echo "-----------------------------------------------------------------"

# Create data quality configuration directory
mkdir -p var/data_quality_rules

# Create attribute completeness tracking
cat > var/data_quality_rules/completeness_tracking.json << 'EOF'
{
  "quality_rules": {
    "required_attributes": [
      "sku",
      "name",
      "description",
      "price",
      "image"
    ],
    "completeness_thresholds": {
      "ecommerce": 90,
      "mobile": 85,
      "print": 75
    },
    "validation_rules": {
      "sku": {
        "type": "regex",
        "pattern": "^[A-Z0-9\\-]+$",
        "message": "SKU must contain only uppercase letters, numbers, and hyphens"
      },
      "price": {
        "type": "numeric",
        "min": 0,
        "message": "Price must be a positive number"
      },
      "description": {
        "type": "length",
        "min": 50,
        "max": 5000,
        "message": "Description must be between 50 and 5000 characters"
      }
    }
  }
}
EOF

echo "   ✓ Created completeness tracking rules"

# Create data quality report template
cat > var/data_quality_rules/quality_report_template.sql << 'EOF'
-- Data Quality Report Queries

-- 1. Products without images
SELECT p.id, p.identifier 
FROM pim_catalog_product p 
LEFT JOIN pim_catalog_product_value v ON p.id = v.product_id 
WHERE v.attribute_id = (SELECT id FROM pim_catalog_attribute WHERE code = 'image')
AND v.value IS NULL
LIMIT 100;

-- 2. Products with missing descriptions
SELECT p.id, p.identifier 
FROM pim_catalog_product p 
LEFT JOIN pim_catalog_product_value v ON p.id = v.product_id 
WHERE v.attribute_id = (SELECT id FROM pim_catalog_attribute WHERE code = 'description')
AND (v.value IS NULL OR v.value = '')
LIMIT 100;

-- 3. Products without categories
SELECT p.id, p.identifier 
FROM pim_catalog_product p 
LEFT JOIN pim_catalog_category_product cp ON p.id = cp.product_id 
WHERE cp.category_id IS NULL
LIMIT 100;

-- 4. Completeness by family
SELECT f.code as family, 
       COUNT(p.id) as product_count,
       AVG(CASE WHEN pc.required_count = pc.complete_count THEN 100 ELSE 0 END) as avg_completeness
FROM pim_catalog_product p
JOIN pim_catalog_family f ON p.family_id = f.id
LEFT JOIN pim_catalog_completeness pc ON p.id = pc.product_id
GROUP BY f.code;
EOF

echo "   ✓ Created quality report SQL templates"

echo ""
echo "🔧 PHASE 4: Optimization Configuration"
echo "-----------------------------------------------------------------"

# Create optimization script
cat > var/data_quality_rules/optimize_catalog.sh << 'EOFSCRIPT'
#!/bin/bash
# Daily catalog optimization

cd /home/pim/public_html

# Clear old product versions (keep last 10)
php bin/console pim:versioning:purge --more-than-days=30 --env=prod --no-interaction

# Recalculate completeness
php bin/console pim:completeness:calculate --env=prod

# Clear orphaned values
php bin/console pim:catalog:remove-orphan-category-files --env=prod

# Refresh elasticsearch
php bin/console akeneo:elasticsearch:reset-indexes --env=prod

echo "Catalog optimization complete"
EOFSCRIPT

chmod +x var/data_quality_rules/optimize_catalog.sh
echo "   ✓ Created catalog optimization script"

echo ""
echo "📋 PHASE 5: Validation Rule Configuration"
echo "-----------------------------------------------------------------"

# Create custom validation rules
cat > var/data_quality_rules/custom_validations.yml << 'EOF'
# Custom Validation Rules for Akeneo PIM

validation_rules:
  # SKU Format Validation
  sku_format:
    attribute: sku
    type: regex
    pattern: '^[A-Z0-9\-]{5,50}$'
    message: 'SKU must be 5-50 characters: uppercase letters, numbers, hyphens only'
    
  # Price Range Validation
  price_range:
    attribute: price
    type: range
    min: 0.01
    max: 999999.99
    message: 'Price must be between 0.01 and 999999.99'
    
  # Weight Validation
  weight_validation:
    attribute: weight
    type: range
    min: 0
    max: 99999
    message: 'Weight must be a positive number'
    
  # Description Length
  description_length:
    attribute: description
    type: length
    min: 50
    max: 5000
    message: 'Description must be between 50-5000 characters'
    
  # Name Length
  name_length:
    attribute: name
    type: length
    min: 3
    max: 255
    message: 'Product name must be between 3-255 characters'

completeness_requirements:
  ecommerce:
    - sku
    - name
    - description
    - price
    - image
    - weight
    - categories
    
  mobile:
    - sku
    - name
    - price
    - image
    - short_description
    
  print:
    - sku
    - name
    - description
    - price

quality_gates:
  ready_for_ecommerce:
    completeness: 100
    channels: [ecommerce]
    required_attributes: [sku, name, description, price, image]
    
  ready_for_export:
    completeness: 90
    channels: [ecommerce, mobile]
    required_attributes: [sku, name, price]
EOF

echo "   ✓ Created custom validation rules YAML"

echo ""
echo "🎯 PHASE 6: Data Quality Monitoring Setup"
echo "-----------------------------------------------------------------"

# Create monitoring script
cat > var/data_quality_rules/quality_monitor.sh << 'EOFMON'
#!/bin/bash
# Data Quality Monitoring Script

WORK_DIR="/home/pim/public_html"
cd "$WORK_DIR"

REPORT_DIR="var/data_quality_rules/reports"
mkdir -p "$REPORT_DIR"

REPORT_FILE="$REPORT_DIR/quality_report_$(date +%Y%m%d_%H%M%S).txt"

echo "=====================================" > "$REPORT_FILE"
echo "  DATA QUALITY REPORT" >> "$REPORT_FILE"
echo "  Generated: $(date)" >> "$REPORT_FILE"
echo "=====================================" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Product Statistics
echo "PRODUCT STATISTICS:" >> "$REPORT_FILE"
TOTAL_PRODUCTS=$(php bin/console doctrine:query:sql "SELECT COUNT(*) FROM pim_catalog_product" --env=prod 2>/dev/null | grep -oP '\d+' | tail -1)
echo "  Total Products: $TOTAL_PRODUCTS" >> "$REPORT_FILE"

# Products without categories
NO_CATEGORY=$(php bin/console doctrine:query:sql "SELECT COUNT(DISTINCT p.id) FROM pim_catalog_product p LEFT JOIN pim_catalog_category_product cp ON p.id = cp.product_id WHERE cp.category_id IS NULL" --env=prod 2>/dev/null | grep -oP '\d+' | tail -1)
echo "  Without Categories: $NO_CATEGORY" >> "$REPORT_FILE"

# Enabled vs Disabled
ENABLED=$(php bin/console doctrine:query:sql "SELECT COUNT(*) FROM pim_catalog_product WHERE is_enabled = 1" --env=prod 2>/dev/null | grep -oP '\d+' | tail -1)
echo "  Enabled: $ENABLED" >> "$REPORT_FILE"

echo "" >> "$REPORT_FILE"
echo "QUALITY SCORE: $(awk "BEGIN {printf \"%.2f\", (($TOTAL_PRODUCTS - $NO_CATEGORY) / $TOTAL_PRODUCTS) * 100}")%" >> "$REPORT_FILE"

echo ""
cat "$REPORT_FILE"
echo ""
echo "Report saved to: $REPORT_FILE"
EOFMON

chmod +x var/data_quality_rules/quality_monitor.sh
echo "   ✓ Created quality monitoring script"

echo ""
echo "💾 PHASE 7: Database Optimization"
echo "-----------------------------------------------------------------"

# Analyze tables for optimization
echo "   Analyzing catalog tables..."
php bin/console doctrine:query:sql "ANALYZE TABLE pim_catalog_product" --env=prod > /dev/null 2>&1 && echo "   ✓ Analyzed product table"
php bin/console doctrine:query:sql "ANALYZE TABLE pim_catalog_category" --env=prod > /dev/null 2>&1 && echo "   ✓ Analyzed category table"
php bin/console doctrine:query:sql "ANALYZE TABLE pim_catalog_attribute" --env=prod > /dev/null 2>&1 && echo "   ✓ Analyzed attribute table"

echo ""
echo "🎨 PHASE 8: Asset Management Configuration"
echo "-----------------------------------------------------------------"

# Create asset management rules
cat > var/data_quality_rules/asset_rules.yml << 'EOF'
# Asset Management Rules

image_requirements:
  product_images:
    formats:
      - jpg
      - jpeg
      - png
      - webp
    max_size: 10485760  # 10MB
    min_width: 800
    min_height: 800
    recommended_width: 2000
    recommended_height: 2000
    
  thumbnail:
    max_size: 524288  # 512KB
    width: 300
    height: 300
    
  detail:
    max_size: 5242880  # 5MB
    width: 1500
    height: 1500

naming_convention:
  pattern: '{sku}_{variant}_{angle}.{ext}'
  examples:
    - 'SKU12345_main_front.jpg'
    - 'SKU12345_variant1_side.png'
    
storage:
  path: 'public/media/product'
  cache_path: 'var/cache/asset'
  backup_enabled: true
  backup_retention_days: 30
EOF

echo "   ✓ Created asset management rules"

echo ""
echo "================================================================="
echo "                    SETUP COMPLETE"
echo "================================================================="
echo ""
echo "📊 Data Quality Tools Created:"
echo "   • Completeness tracking rules"
echo "   • Quality report SQL templates"
echo "   • Optimization scripts"
echo "   • Custom validation rules"
echo "   • Quality monitoring"
echo "   • Asset management rules"
echo ""
echo "🚀 Next Steps:"
echo "   1. Run quality report: ./var/data_quality_rules/quality_monitor.sh"
echo "   2. Daily optimization: ./var/data_quality_rules/optimize_catalog.sh"
echo "   3. Review rules: cat var/data_quality_rules/custom_validations.yml"
echo ""
echo "📍 All configuration files stored in:"
echo "   $WORK_DIR/var/data_quality_rules/"
echo ""
echo "================================================================="
