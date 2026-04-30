#!/bin/bash
# Product Enrichment Workflow Configuration
# Purpose: Set up product enrichment rules, workflows, and bulk operations

set -e

WORK_DIR="/home/pim/public_html"
cd "$WORK_DIR"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "================================================================="
echo "     PRODUCT ENRICHMENT WORKFLOW SETUP"
echo "================================================================="
echo ""

# Create enrichment workflows directory
mkdir -p var/enrichment_workflows

echo "📋 Creating enrichment workflow templates..."

# Workflow 1: New Product Enrichment
cat > var/enrichment_workflows/new_product_workflow.yml << 'EOF'
# New Product Enrichment Workflow

workflow_name: "New Product Onboarding"
description: "Standard workflow for new products from creation to publication"

stages:
  1_basic_info:
    name: "Basic Information"
    required_attributes:
      - sku
      - name
      - family
      - categories
    validation:
      - "SKU must be unique"
      - "Name minimum 3 characters"
      - "Must belong to at least one category"
    status: "draft"
    
  2_description:
    name: "Product Description"
    required_attributes:
      - description
      - short_description
    validation:
      - "Description minimum 50 characters"
      - "Short description minimum 20 characters"
    status: "in_enrichment"
    
  3_pricing:
    name: "Pricing & Inventory"
    required_attributes:
      - price
      - cost
      - weight
    validation:
      - "Price must be > 0"
      - "Weight must be specified"
    status: "pricing_complete"
    
  4_media:
    name: "Media & Assets"
    required_attributes:
      - image
    optional:
      - gallery_images
      - video_url
    validation:
      - "At least one product image required"
      - "Image dimensions minimum 800x800"
    status: "media_complete"
    
  5_specifications:
    name: "Technical Specifications"
    required_attributes:
      - brand
      - manufacturer
    optional:
      - dimensions
      - materials
      - specifications
    status: "specifications_complete"
    
  6_seo:
    name: "SEO Optimization"
    required_attributes:
      - meta_title
      - meta_description
    optional:
      - meta_keywords
      - url_key
    validation:
      - "Meta title 50-60 characters"
      - "Meta description 150-160 characters"
    status: "seo_complete"
    
  7_review:
    name: "Quality Review"
    validation:
      - "All required attributes complete"
      - "Images meet quality standards"
      - "Descriptions proofread"
      - "Pricing approved"
    status: "ready_for_review"
    
  8_publish:
    name: "Ready for Publication"
    actions:
      - "Enable product"
      - "Add to e-commerce channel"
      - "Generate product feed"
    status: "published"

automation_rules:
  - trigger: "product_created"
    action: "assign_to_stage_1"
    
  - trigger: "stage_complete"
    action: "move_to_next_stage"
    notification: true
    
  - trigger: "all_stages_complete"
    action: "mark_ready_for_publication"
    notification: "quality_team"
EOF

echo "   ✓ Created new product workflow"

# Workflow 2: Bulk Update Workflow
cat > var/enrichment_workflows/bulk_update_workflow.yml << 'EOF'
# Bulk Product Update Workflow

workflow_name: "Bulk Product Updates"
description: "Workflow for mass product updates and maintenance"

update_types:
  price_update:
    name: "Bulk Price Update"
    attributes: [price, special_price, cost]
    validation:
      - "Price must be numeric"
      - "Special price < regular price"
    backup: true
    approval_required: true
    
  category_reassignment:
    name: "Category Reassignment"
    attributes: [categories]
    validation:
      - "At least one category required"
    backup: true
    approval_required: false
    
  attribute_enrichment:
    name: "Missing Attribute Fill"
    target: "products_missing_attributes"
    validation:
      - "Validate against attribute rules"
    backup: true
    approval_required: false
    
  image_update:
    name: "Bulk Image Update"
    attributes: [image, gallery_images]
    validation:
      - "Image format: jpg, png, webp"
      - "Max size: 10MB"
      - "Min dimensions: 800x800"
    backup: true
    approval_required: true

backup_policy:
  enabled: true
  retention_days: 30
  location: "var/backups/product_updates"
EOF

echo "   ✓ Created bulk update workflow"

# Workflow 3: Product Quality Gates
cat > var/enrichment_workflows/quality_gates.yml << 'EOF'
# Product Quality Gates

quality_gates:
  minimum_viable_product:
    name: "Minimum Viable Product (MVP)"
    description: "Minimum requirements for product to be visible"
    required_completeness: 50
    required_attributes:
      - sku
      - name
      - price
      - image
    actions:
      - "Can be saved as draft"
      - "Not visible on storefront"
      
  ecommerce_ready:
    name: "E-commerce Ready"
    description: "Ready for online sales"
    required_completeness: 90
    required_attributes:
      - sku
      - name
      - description
      - short_description
      - price
      - image
      - weight
      - categories
      - brand
    validation:
      - "SEO fields complete"
      - "At least one category"
      - "Image quality check passed"
    actions:
      - "Enable product"
      - "Add to e-commerce channel"
      - "Include in sitemap"
      
  marketplace_ready:
    name: "Marketplace Ready"
    description: "Ready for marketplace export (Amazon, eBay, etc.)"
    required_completeness: 95
    required_attributes:
      - sku
      - name
      - description
      - price
      - cost
      - image
      - gallery_images (min 3)
      - weight
      - dimensions
      - brand
      - manufacturer
      - categories
      - gtin
    validation:
      - "All marketplace-specific attributes filled"
      - "Images meet marketplace standards"
      - "Descriptions meet character limits"
    actions:
      - "Enable for marketplace export"
      - "Generate marketplace feeds"
      
  premium_quality:
    name: "Premium Quality"
    description: "Highest quality standard for featured products"
    required_completeness: 100
    required_attributes: "all"
    validation:
      - "Professional product photography"
      - "Detailed specifications"
      - "Customer reviews present"
      - "Related products configured"
    actions:
      - "Feature on homepage"
      - "Include in premium catalog"
      - "Enable for all channels"

gate_progression:
  - from: "draft"
    to: "minimum_viable_product"
    auto: false
    
  - from: "minimum_viable_product"
    to: "ecommerce_ready"
    auto: true
    condition: "completeness >= 90"
    
  - from: "ecommerce_ready"
    to: "marketplace_ready"
    auto: false
    review_required: true
    
  - from: "marketplace_ready"
    to: "premium_quality"
    auto: false
    review_required: true
    approval: "product_manager"
EOF

echo "   ✓ Created quality gates configuration"

# Create enrichment helper scripts
cat > var/enrichment_workflows/enrichment_helper.sh << 'EOFHELPER'
#!/bin/bash
# Product Enrichment Helper Commands

WORK_DIR="/home/pim/public_html"
cd "$WORK_DIR"

case "$1" in
  incomplete)
    echo "Finding products with incomplete data..."
    php bin/console pim:completeness:calculate --env=prod
    echo "Completeness recalculated. Check PIM interface for incomplete products."
    ;;
    
  missing-images)
    echo "Products missing images:"
    php bin/console doctrine:query:sql "SELECT COUNT(*) FROM pim_catalog_product p WHERE NOT EXISTS (SELECT 1 FROM pim_catalog_product_value v JOIN pim_catalog_attribute a ON v.attribute_id = a.id WHERE v.product_id = p.id AND a.code = 'image')" --env=prod
    ;;
    
  disabled)
    echo "Count of disabled products:"
    php bin/console doctrine:query:sql "SELECT COUNT(*) FROM pim_catalog_product WHERE is_enabled = 0" --env=prod
    ;;
    
  no-category)
    echo "Products without categories:"
    php bin/console doctrine:query:sql "SELECT COUNT(DISTINCT p.id) FROM pim_catalog_product p LEFT JOIN pim_catalog_category_product cp ON p.id = cp.product_id WHERE cp.category_id IS NULL" --env=prod
    ;;
    
  family-stats)
    echo "Products per family:"
    php bin/console doctrine:query:sql "SELECT f.code, COUNT(p.id) as product_count FROM pim_catalog_family f LEFT JOIN pim_catalog_product p ON f.id = p.family_id GROUP BY f.code ORDER BY product_count DESC" --env=prod
    ;;
    
  *)
    echo "Product Enrichment Helper"
    echo "Usage: $0 {incomplete|missing-images|disabled|no-category|family-stats}"
    echo ""
    echo "Commands:"
    echo "  incomplete     - Find products with incomplete data"
    echo "  missing-images - Count products without images"
    echo "  disabled       - Count disabled products"
    echo "  no-category    - Find products without categories"
    echo "  family-stats   - Show products per family"
    ;;
esac
EOFHELPER

chmod +x var/enrichment_workflows/enrichment_helper.sh
echo "   ✓ Created enrichment helper script"

# Create enrichment checklist
cat > var/enrichment_workflows/enrichment_checklist.md << 'EOF'
# Product Enrichment Checklist

## Stage 1: Basic Information
- [ ] SKU assigned (unique identifier)
- [ ] Product name (clear, descriptive)
- [ ] Product family assigned
- [ ] At least one category assigned
- [ ] Product status: Draft

## Stage 2: Descriptions
- [ ] Full description (minimum 50 characters)
- [ ] Short description (minimum 20 characters)
- [ ] Key features listed
- [ ] Product benefits described

## Stage 3: Pricing & Inventory
- [ ] Regular price set
- [ ] Cost price recorded (for margin calculation)
- [ ] Special/Sale price (if applicable)
- [ ] Weight specified
- [ ] SKU mapped to inventory system

## Stage 4: Media & Assets
- [ ] Main product image (minimum 800x800px)
- [ ] Additional gallery images (recommended: 3-5)
- [ ] Images optimized (< 10MB per image)
- [ ] Video URL (if applicable)
- [ ] 360° view (if applicable)

## Stage 5: Technical Specifications
- [ ] Brand assigned
- [ ] Manufacturer specified
- [ ] Dimensions (L x W x H)
- [ ] Materials listed
- [ ] Technical specifications completed
- [ ] Care instructions (if applicable)

## Stage 6: SEO Optimization
- [ ] Meta title (50-60 characters)
- [ ] Meta description (150-160 characters)
- [ ] URL key (SEO-friendly)
- [ ] Meta keywords (optional)
- [ ] Alt text for images

## Stage 7: Quality Review
- [ ] All required attributes complete
- [ ] Spelling and grammar checked
- [ ] Images meet quality standards
- [ ] Pricing verified and approved
- [ ] Completeness score >= 90%

## Stage 8: Publication
- [ ] Product enabled
- [ ] Added to appropriate channels
- [ ] Included in product feeds
- [ ] Published to storefront
- [ ] Monitoring enabled

## Quality Gates

### MVP (Minimum Viable Product)
- Completeness: >= 50%
- Can be saved, not visible

### E-commerce Ready
- Completeness: >= 90%
- Can be published to storefront

### Marketplace Ready
- Completeness: >= 95%
- Ready for Amazon, eBay, etc.

### Premium Quality
- Completeness: 100%
- Featured product status
EOF

echo "   ✓ Created enrichment checklist"

echo ""
echo "================================================================="
echo "                 ENRICHMENT SETUP COMPLETE"
echo "================================================================="
echo ""
echo "📁 Files Created:"
echo "   • var/enrichment_workflows/new_product_workflow.yml"
echo "   • var/enrichment_workflows/bulk_update_workflow.yml"
echo "   • var/enrichment_workflows/quality_gates.yml"
echo "   • var/enrichment_workflows/enrichment_helper.sh"
echo "   • var/enrichment_workflows/enrichment_checklist.md"
echo ""
echo "🚀 Quick Commands:"
echo "   # Check incomplete products"
echo "   ./var/enrichment_workflows/enrichment_helper.sh incomplete"
echo ""
echo "   # Products missing images"
echo "   ./var/enrichment_workflows/enrichment_helper.sh missing-images"
echo ""
echo "   # Family statistics"
echo "   ./var/enrichment_workflows/enrichment_helper.sh family-stats"
echo ""
echo "📖 View enrichment checklist:"
echo "   cat var/enrichment_workflows/enrichment_checklist.md"
echo ""
echo "================================================================="
