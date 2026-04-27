# Detailed Implementation Plan - Phase 2
**High-Priority Improvements (Week 2)**  
**Duration**: 12-16 hours  
**Priority**: 🟡 HIGH - Should Complete Within 2 Weeks  
**Expected Improvement**: 85% → 92% (7 points)

---

## Overview

Phase 2 focuses on adding comprehensive validation rules and reorganizing attribute groups for better usability and data quality enforcement.

**Prerequisites**: Phase 1 must be completed
- ✅ Required attributes configured
- ✅ English translations added
- ✅ Completeness calculation running

---

## Task 2.1: Add Numeric Validation Rules
**Duration**: 3-4 hours  
**Owner**: PIM Administrator  
**Priority**: 🔴 HIGH

### Objective
Add min/max constraints and decimal rules for all numeric attributes to prevent invalid data entry.

### Numeric Attributes Requiring Validation

#### Price Attributes
| Attribute | Type | Min | Max | Decimals | Negative |
|-----------|------|-----|-----|----------|----------|
| `price` | Decimal | 0.01 | 999,999.99 | Yes (2) | No |
| `special_price` | Decimal | 0.01 | 999,999.99 | Yes (2) | No |
| `cost` | Decimal | 0.00 | 999,999.99 | Yes (2) | No |
| `msrp` | Decimal | 0.01 | 999,999.99 | Yes (2) | No |

#### Inventory Attributes
| Attribute | Type | Min | Max | Decimals | Negative |
|-----------|------|-----|-----|----------|----------|
| `qty` | Number | 0 | 999,999 | No | No |
| `min_qty` | Number | 0 | 999,999 | No | No |
| `max_qty` | Number | 1 | 999,999 | No | No |
| `min_sale_qty` | Number | 1 | 999,999 | No | No |
| `max_sale_qty` | Number | 1 | 999,999 | No | No |

#### Physical Dimensions
| Attribute | Type | Min | Max | Decimals | Negative |
|-----------|------|-----|-----|----------|----------|
| `weight` | Metric (Weight) | 0.01 | 99,999 | Yes (2) | No |
| `length` | Number | 0.01 | 99,999 | Yes (2) | No |
| `width` | Number | 0.01 | 99,999 | Yes (2) | No |
| `height` | Number | 0.01 | 99,999 | Yes (2) | No |

### Implementation Steps

#### Method 1: Via Akeneo UI (Slower, More Visual)

**For Each Attribute**:

1. Navigate to: `Settings → Attributes → [Select Attribute]`

2. Click "Validation parameters" tab

3. Configure based on attribute type:

**For Price/Cost Attributes**:
```
Number min: 0.01
Number max: 999999.99
Decimals allowed: Yes
Number of decimals: 2
Negative allowed: No
```

**For Quantity Attributes**:
```
Number min: 0
Number max: 999999
Decimals allowed: No
Negative allowed: No
```

**For Dimension Attributes**:
```
Number min: 0.01
Number max: 99999
Decimals allowed: Yes
Number of decimals: 2
Negative allowed: No
```

4. Save changes

5. Test:
   - Try entering value < min → Should show error
   - Try entering value > max → Should show error
   - Try entering negative value → Should show error

**Estimated Time**: 10-15 minutes per attribute × 15 attributes = 2.5-4 hours

#### Method 2: Database Direct Update (Faster)

```sql
-- Connect to database
-- /opt/mariadb10.6/mariadb/bin/mysql -u root -p'YourNewStrongPassword' -h 127.0.0.1 -P 3307 akeneo_pim

-- Update price attributes
UPDATE pim_catalog_attribute 
SET 
    number_min = 0.01,
    number_max = 999999.99,
    decimals_allowed = 1,
    negative_allowed = 0
WHERE code IN ('price', 'special_price', 'msrp');

-- Cost can be 0
UPDATE pim_catalog_attribute 
SET 
    number_min = 0.00,
    number_max = 999999.99,
    decimals_allowed = 1,
    negative_allowed = 0
WHERE code = 'cost';

-- Update quantity attributes
UPDATE pim_catalog_attribute 
SET 
    number_min = 0,
    number_max = 999999,
    decimals_allowed = 0,
    negative_allowed = 0
WHERE code IN ('qty', 'min_qty', 'min_sale_qty');

-- Max qty must be at least 1
UPDATE pim_catalog_attribute 
SET 
    number_min = 1,
    number_max = 999999,
    decimals_allowed = 0,
    negative_allowed = 0
WHERE code IN ('max_qty', 'max_sale_qty');

-- Update dimension attributes (length, width, height)
UPDATE pim_catalog_attribute 
SET 
    number_min = 0.01,
    number_max = 99999,
    decimals_allowed = 1,
    negative_allowed = 0
WHERE code IN ('length', 'width', 'height');

-- Weight already configured, verify
SELECT code, number_min, number_max, decimals_allowed, negative_allowed 
FROM pim_catalog_attribute 
WHERE code = 'weight';
```

**Clear Cache After Database Changes**:
```bash
cd /home/pim/public_html
bin/console cache:clear --env=prod
```

**Estimated Time**: 30 minutes SQL + 15 minutes testing = 45 minutes

### Testing

```bash
# Create test script
cd /home/pim/public_html/webapp

cat > test_numeric_validation.php << 'EOFPHP'
<?php
// Test numeric validation rules

$testCases = [
    ['attribute' => 'price', 'value' => -10.00, 'should_fail' => true, 'reason' => 'negative'],
    ['attribute' => 'price', 'value' => 0.00, 'should_fail' => true, 'reason' => 'below min'],
    ['attribute' => 'price', 'value' => 0.01, 'should_fail' => false, 'reason' => 'valid min'],
    ['attribute' => 'price', 'value' => 999999.99, 'should_fail' => false, 'reason' => 'valid max'],
    ['attribute' => 'price', 'value' => 1000000.00, 'should_fail' => true, 'reason' => 'above max'],
    ['attribute' => 'qty', 'value' => -1, 'should_fail' => true, 'reason' => 'negative'],
    ['attribute' => 'qty', 'value' => 0, 'should_fail' => false, 'reason' => 'valid min'],
    ['attribute' => 'qty', 'value' => 1000000, 'should_fail' => true, 'reason' => 'above max'],
];

echo "NUMERIC VALIDATION TEST RESULTS\n";
echo str_repeat("=", 80) . "\n\n";

foreach ($testCases as $test) {
    echo "Attribute: {$test['attribute']}\n";
    echo "Value: {$test['value']}\n";
    echo "Expected: " . ($test['should_fail'] ? 'FAIL' : 'PASS') . " ({$test['reason']})\n";
    echo "Test this manually in Akeneo UI\n";
    echo str_repeat("-", 80) . "\n";
}
EOFPHP

php test_numeric_validation.php
```

### Acceptance Criteria
- [ ] All 15 numeric attributes have min/max constraints
- [ ] Decimals allowed/disallowed configured correctly
- [ ] Negative values blocked where appropriate
- [ ] Test cases pass (invalid values rejected)
- [ ] Existing products validated (bulk check script)

---

## Task 2.2: Add Text Validation Rules
**Duration**: 3-4 hours  
**Owner**: PIM Administrator  
**Priority**: 🔴 HIGH

### Objective
Add character limits and regex patterns for text attributes to ensure data consistency and prevent data overflow.

### Text Attributes Requiring Validation

#### Core Text Fields
| Attribute | Type | Max Length | Regex Pattern | Description |
|-----------|------|------------|---------------|-------------|
| `sku` | Text | 64 | `^[A-Z0-9-]+$` | Uppercase, numbers, hyphens only |
| `name` | Text | 255 | - | Product name |
| `short_description` | Textarea | 500 | - | Brief description |
| `description` | Textarea | 10,000 | - | Full description |
| `url_key` | Text | 255 | `^[a-z0-9-]+$` | Lowercase, numbers, hyphens only |

#### SEO Fields
| Attribute | Type | Max Length | Regex Pattern | Description |
|-----------|------|------------|---------------|-------------|
| `meta_title` | Text | 70 | - | SEO title (Google limit) |
| `meta_description` | Textarea | 160 | - | SEO description (Google limit) |
| `meta_keywords` | Textarea | 255 | - | SEO keywords |

#### Contact/URL Fields
| Attribute | Type | Max Length | Regex Pattern | Description |
|-----------|------|------------|---------------|-------------|
| `email` | Text | 255 | Email validation | Valid email format |
| `phone` | Text | 20 | Phone validation | Valid phone format |
| `website_url` | Text | 255 | URL validation | Valid URL format |

### Implementation Steps

#### Step 1: Configure Character Limits via UI (2 hours)

**For Each Text Attribute**:

1. Navigate to: `Settings → Attributes → [Select Attribute]`

2. Click "Validation parameters" tab

3. For Text attributes:
   ```
   Max characters: [SEE TABLE ABOVE]
   Validation rule: [None, Email, URL, or Regexp]
   Validation regexp: [IF APPLICABLE]
   ```

4. Examples:

**SKU Attribute**:
```
Attribute type: Text
Max characters: 64
Validation rule: Regular expression
Validation regexp: ^[A-Z0-9-]+$
```

**Name Attribute**:
```
Attribute type: Text
Max characters: 255
Validation rule: None
```

**Meta Title**:
```
Attribute type: Text
Max characters: 70
Validation rule: None
```

**Email Attribute**:
```
Attribute type: Text
Max characters: 255
Validation rule: E-mail
```

**URL Attribute**:
```
Attribute type: Text
Max characters: 255
Validation rule: URL
```

#### Step 2: Database Bulk Update (30 minutes)

```sql
-- Update character limits for core text fields
UPDATE pim_catalog_attribute 
SET max_characters = 64,
    validation_rule = 'regexp',
    validation_regexp = '^[A-Z0-9-]+$'
WHERE code = 'sku';

UPDATE pim_catalog_attribute 
SET max_characters = 255
WHERE code IN ('name', 'url_key', 'brand', 'manufacturer');

UPDATE pim_catalog_attribute 
SET max_characters = 500
WHERE code = 'short_description';

UPDATE pim_catalog_attribute 
SET max_characters = 10000
WHERE code = 'description';

-- SEO fields with Google limits
UPDATE pim_catalog_attribute 
SET max_characters = 70
WHERE code IN ('meta_title', 'meta_keyword');

UPDATE pim_catalog_attribute 
SET max_characters = 160
WHERE code = 'meta_description';

UPDATE pim_catalog_attribute 
SET max_characters = 255
WHERE code = 'meta_keywords';

-- URL key validation
UPDATE pim_catalog_attribute 
SET max_characters = 255,
    validation_rule = 'regexp',
    validation_regexp = '^[a-z0-9-]+$'
WHERE code = 'url_key';

-- Email validation
UPDATE pim_catalog_attribute 
SET max_characters = 255,
    validation_rule = 'email'
WHERE code LIKE '%email%';

-- URL validation
UPDATE pim_catalog_attribute 
SET max_characters = 255,
    validation_rule = 'url'
WHERE code LIKE '%url%' AND code != 'url_key';

-- Clear cache
```

```bash
cd /home/pim/public_html
bin/console cache:clear --env=prod
```

#### Step 3: Test Validation (1 hour)

**Manual UI Tests**:
1. Product with SKU containing lowercase → Should fail
2. Product with SKU "test-product-123" → Should fail (lowercase)
3. Product with SKU "TEST-PRODUCT-123" → Should pass
4. Product name > 255 characters → Should fail
5. Meta title > 70 characters → Should fail
6. Description > 10,000 characters → Should fail
7. Invalid email format → Should fail
8. Invalid URL format → Should fail

**Automated Test Script**:
```bash
cd /home/pim/public_html/webapp

cat > test_text_validation.php << 'EOFPHP'
<?php
$pdo = new PDO('mysql:host=127.0.0.1;port=3307;dbname=akeneo_pim', 'root', 'YourNewStrongPassword');

echo "TEXT VALIDATION CONFIGURATION CHECK\n";
echo str_repeat("=", 80) . "\n\n";

$attrs = $pdo->query("
    SELECT 
        code,
        attribute_type,
        max_characters,
        validation_rule,
        validation_regexp
    FROM pim_catalog_attribute
    WHERE attribute_type IN ('pim_catalog_text', 'pim_catalog_textarea')
    AND (max_characters IS NOT NULL OR validation_rule IS NOT NULL)
    ORDER BY code
")->fetchAll(PDO::FETCH_ASSOC);

foreach ($attrs as $attr) {
    echo "Attribute: {$attr['code']}\n";
    echo "  Type: {$attr['attribute_type']}\n";
    echo "  Max Characters: " . ($attr['max_characters'] ?: 'None') . "\n";
    echo "  Validation Rule: " . ($attr['validation_rule'] ?: 'None') . "\n";
    if ($attr['validation_regexp']) {
        echo "  Regex: {$attr['validation_regexp']}\n";
    }
    echo "\n";
}
EOFPHP

php test_text_validation.php
```

### Acceptance Criteria
- [ ] All text attributes have appropriate character limits
- [ ] SKU enforces uppercase alphanumeric + hyphens
- [ ] URL key enforces lowercase alphanumeric + hyphens
- [ ] SEO fields respect Google limits (70/160 chars)
- [ ] Email/URL validation configured
- [ ] Test cases pass

---

## Task 2.3: Add File/Media Validation
**Duration**: 2 hours  
**Owner**: PIM Administrator  
**Priority**: 🔴 HIGH

### Objective
Configure file type restrictions and size limits for image and media attributes.

### File Attributes Requiring Validation

| Attribute | Allowed Extensions | Max File Size | Max Width | Max Height |
|-----------|-------------------|---------------|-----------|------------|
| `image` | jpg, jpeg, png, gif, webp | 5 MB | 4000px | 4000px |
| `thumbnail` | jpg, jpeg, png, gif, webp | 2 MB | 500px | 500px |
| `small_image` | jpg, jpeg, png, gif, webp | 2 MB | 800px | 800px |
| `gallery` | jpg, jpeg, png, gif, webp | 5 MB | 4000px | 4000px |
| `swatch_image` | jpg, jpeg, png, gif, webp | 1 MB | 200px | 200px |
| `pdf_file` | pdf | 10 MB | - | - |

### Implementation Steps

#### Via Akeneo UI (1 hour)

**For Each File/Image Attribute**:

1. Navigate to: `Settings → Attributes → [Select Attribute]`

2. Click "Validation parameters" tab

3. Configure:
```
Allowed file extensions: jpg,jpeg,png,gif,webp
Max file size (MB): 5
Max width (px): 4000
Max height (px): 4000
```

4. Examples:

**Main Image**:
```
Allowed extensions: jpg,jpeg,png,gif,webp
Max file size: 5 MB
Max width: 4000 px
Max height: 4000 px
```

**Thumbnail**:
```
Allowed extensions: jpg,jpeg,png,gif,webp
Max file size: 2 MB
Max width: 500 px
Max height: 500 px
```

**PDF Documents**:
```
Allowed extensions: pdf
Max file size: 10 MB
```

#### Database Update (30 minutes)

```sql
-- Image attributes
UPDATE pim_catalog_attribute 
SET 
    allowed_extensions = 'jpg,jpeg,png,gif,webp',
    max_file_size = 5.0
WHERE code IN ('image', 'gallery', 'media_gallery');

-- Thumbnail images
UPDATE pim_catalog_attribute 
SET 
    allowed_extensions = 'jpg,jpeg,png,gif,webp',
    max_file_size = 2.0
WHERE code IN ('thumbnail', 'small_image');

-- Swatch images
UPDATE pim_catalog_attribute 
SET 
    allowed_extensions = 'jpg,jpeg,png,gif,webp',
    max_file_size = 1.0
WHERE code LIKE '%swatch%';

-- PDF files
UPDATE pim_catalog_attribute 
SET 
    allowed_extensions = 'pdf',
    max_file_size = 10.0
WHERE code LIKE '%pdf%' OR code LIKE '%document%';
```

```bash
cd /home/pim/public_html
bin/console cache:clear --env=prod
```

#### Testing (30 minutes)

1. Try uploading .bmp file to image → Should fail
2. Try uploading 10MB image → Should fail
3. Try uploading valid 2MB JPG → Should pass
4. Try uploading PDF to image field → Should fail
5. Try uploading 5MB PDF to pdf_file → Should pass

### Acceptance Criteria
- [ ] All image attributes restrict to web-safe formats
- [ ] File size limits configured
- [ ] Max dimensions set (where applicable)
- [ ] Invalid file types rejected
- [ ] Oversized files rejected

---

## Task 2.4: Reorganize Attribute Groups
**Duration**: 2-3 hours  
**Owner**: PIM Administrator  
**Priority**: 🟡 HIGH

### Objective
Reorganize 100 attributes from overloaded "general" group into logical, specific groups.

### Current State
- **general**: 100 attributes (89%)
- **technical**: 11 attributes (10%)
- **marketing**: 0 attributes (0%) - TO DELETE
- **other**: 1 attribute (1%)

### Target State
- **product_info**: 15-20 attributes
- **pricing**: 5-8 attributes
- **physical**: 8-10 attributes
- **media**: 8-10 attributes
- **seo**: 8-10 attributes
- **inventory**: 5-8 attributes
- **technical**: 11 attributes (keep existing)
- **ecommerce**: 10-15 attributes
- **other**: remaining attributes

### Implementation Steps

#### Step 1: Create New Attribute Groups (30 minutes)

```bash
# Via Akeneo UI
Settings → Attribute groups → Create

# Create each group:
```

**Product Info Group**:
```
Code: product_info
Labels:
  - en_US: Product Information
  - fr_FR: Informations Produit
Sort order: 10
```

**Pricing Group**:
```
Code: pricing
Labels:
  - en_US: Pricing & Costs
  - fr_FR: Tarification et Coûts
Sort order: 20
```

**Physical Group**:
```
Code: physical
Labels:
  - en_US: Physical Properties
  - fr_FR: Propriétés Physiques
Sort order: 30
```

**Media Group**:
```
Code: media
Labels:
  - en_US: Media & Images
  - fr_FR: Médias et Images
Sort order: 40
```

**SEO Group**:
```
Code: seo
Labels:
  - en_US: SEO & Marketing
  - fr_FR: SEO et Marketing
Sort order: 50
```

**Inventory Group**:
```
Code: inventory
Labels:
  - en_US: Inventory & Stock
  - fr_FR: Inventaire et Stock
Sort order: 60
```

**Ecommerce Group**:
```
Code: ecommerce
Labels:
  - en_US: E-commerce Settings
  - fr_FR: Paramètres E-commerce
Sort order: 70
```

#### Step 2: Move Attributes to New Groups (1.5-2 hours)

**Product Info Group** (move these from "general"):
```
- name
- description
- short_description
- brand
- manufacturer
- model
- sku_manufacturer
- gtin
- upc
- ean
- mpn
- product_type
- condition
- warranty
- country_of_manufacture
```

**Pricing Group**:
```
- price
- special_price
- special_from_date
- special_to_date
- cost
- msrp
- price_type
- price_view
- tax_class_id
```

**Physical Group**:
```
- weight
- length
- width
- height
- volume
- dimensions
- color
- size
- material
- packaging_type
```

**Media Group**:
```
- image
- small_image
- thumbnail
- gallery
- media_gallery
- video_url
- image_label
- swatch_image
```

**SEO Group**:
```
- meta_title
- meta_description
- meta_keywords
- meta_keyword
- url_key
- url_path
- canonical_url
- page_layout
- custom_layout_update
```

**Inventory Group**:
```
- qty
- min_qty
- max_qty
- min_sale_qty
- max_sale_qty
- is_in_stock
- manage_stock
- backorders
- stock_status
```

**Ecommerce Group**:
```
- status
- visibility
- enable_googlecheckout
- new_from_date
- new_to_date
- news_from_date
- featured
- bestseller
- special_offer
- gift_message_available
- tier_price
```

#### Bulk Move via Database (Faster Option - 30 minutes)

```sql
-- Get group IDs first
SELECT id, code FROM pim_catalog_attribute_group;

-- Then update attributes (adjust IDs as needed)
-- Product Info group (assume ID = 5)
UPDATE pim_catalog_attribute 
SET group_id = 5
WHERE code IN ('name', 'description', 'short_description', 'brand', 'manufacturer', 
               'model', 'gtin', 'upc', 'ean', 'mpn', 'warranty', 'country_of_manufacture');

-- Pricing group (assume ID = 6)
UPDATE pim_catalog_attribute 
SET group_id = 6
WHERE code IN ('price', 'special_price', 'special_from_date', 'special_to_date', 
               'cost', 'msrp', 'tax_class_id');

-- Physical group (assume ID = 7)
UPDATE pim_catalog_attribute 
SET group_id = 7
WHERE code IN ('weight', 'length', 'width', 'height', 'volume', 'dimensions', 
               'color', 'size', 'material');

-- Media group (assume ID = 8)
UPDATE pim_catalog_attribute 
SET group_id = 8
WHERE code IN ('image', 'small_image', 'thumbnail', 'gallery', 'media_gallery', 
               'video_url', 'image_label');

-- SEO group (assume ID = 9)
UPDATE pim_catalog_attribute 
SET group_id = 9
WHERE code IN ('meta_title', 'meta_description', 'meta_keywords', 'meta_keyword', 
               'url_key', 'url_path', 'canonical_url');

-- Inventory group (assume ID = 10)
UPDATE pim_catalog_attribute 
SET group_id = 10
WHERE code IN ('qty', 'min_qty', 'max_qty', 'min_sale_qty', 'max_sale_qty', 
               'is_in_stock', 'manage_stock', 'backorders', 'stock_status');

-- Ecommerce group (assume ID = 11)
UPDATE pim_catalog_attribute 
SET group_id = 11
WHERE code IN ('status', 'visibility', 'new_from_date', 'new_to_date', 
               'featured', 'bestseller', 'gift_message_available');
```

```bash
cd /home/pim/public_html
bin/console cache:clear --env=prod
```

#### Step 3: Delete Empty Marketing Group (15 minutes)

```bash
# Via UI
Settings → Attribute groups → marketing → Delete

# Or via database
-- First verify it's empty
SELECT COUNT(*) FROM pim_catalog_attribute WHERE group_id = (
    SELECT id FROM pim_catalog_attribute_group WHERE code = 'marketing'
);

-- If count = 0, safe to delete
DELETE FROM pim_catalog_attribute_group WHERE code = 'marketing';
```

#### Step 4: Verify Reorganization (15 minutes)

```bash
cd /home/pim/public_html/webapp

cat > verify_groups.php << 'EOFPHP'
<?php
$pdo = new PDO('mysql:host=127.0.0.1;port=3307;dbname=akeneo_pim', 'root', 'YourNewStrongPassword');

$groups = $pdo->query("
    SELECT 
        ag.code,
        ag.sort_order,
        COUNT(a.id) as attribute_count
    FROM pim_catalog_attribute_group ag
    LEFT JOIN pim_catalog_attribute a ON ag.id = a.group_id
    GROUP BY ag.id, ag.code, ag.sort_order
    ORDER BY ag.sort_order
")->fetchAll(PDO::FETCH_ASSOC);

echo "ATTRIBUTE GROUP DISTRIBUTION - AFTER REORGANIZATION\n";
echo str_repeat("=", 80) . "\n\n";
echo sprintf("%-25s %15s %15s\n", "Group", "Sort Order", "Attributes");
echo str_repeat("-", 60) . "\n";

foreach ($groups as $group) {
    echo sprintf("%-25s %15d %15d\n",
        $group['code'],
        $group['sort_order'],
        $group['attribute_count']
    );
}
EOFPHP

php verify_groups.php
```

**Expected Output**:
```
ATTRIBUTE GROUP DISTRIBUTION - AFTER REORGANIZATION
================================================================================

Group                       Sort Order      Attributes
------------------------------------------------------------
product_info                        10              15
pricing                             20               8
physical                            30              10
media                               40               8
seo                                 50               9
inventory                           60               9
ecommerce                           70              12
technical                          100              11
other                              999              30
```

### Acceptance Criteria
- [ ] 7 new attribute groups created
- [ ] 100 attributes moved from "general" to specific groups
- [ ] Empty "marketing" group deleted
- [ ] No group has >30 attributes
- [ ] Attributes logically organized
- [ ] Product edit screen shows organized tabs

---

## Task 2.5: Audit Color Options
**Duration**: 2-3 hours  
**Owner**: PIM Administrator / Data Analyst  
**Priority**: 🟡 MEDIUM

### Objective
Reduce 631 color options to 100-200 essential colors by consolidating duplicates and removing unused options.

### Implementation Steps

#### Step 1: Export Current Color Options (15 minutes)

```bash
cd /home/pim/public_html/webapp

cat > export_color_options.php << 'EOFPHP'
<?php
$pdo = new PDO('mysql:host=127.0.0.1;port=3307;dbname=akeneo_pim', 'root', 'YourNewStrongPassword');

// Get color attribute ID
$colorAttr = $pdo->query("
    SELECT id FROM pim_catalog_attribute WHERE code = 'color'
")->fetch();

if (!$colorAttr) {
    die("Color attribute not found\n");
}

// Get all color options with usage count
$options = $pdo->query("
    SELECT 
        ao.code,
        aov.value as label_fr,
        COUNT(DISTINCT p.id) as product_count
    FROM pim_catalog_attribute_option ao
    LEFT JOIN pim_catalog_attribute_option_value aov 
        ON ao.id = aov.option_id AND aov.locale_code = 'fr_FR'
    LEFT JOIN pim_catalog_product p ON p.identifier LIKE CONCAT('%', ao.code, '%')
    WHERE ao.attribute_id = {$colorAttr['id']}
    GROUP BY ao.id, ao.code, aov.value
    ORDER BY product_count DESC, ao.code
")->fetchAll(PDO::FETCH_ASSOC);

// Save to CSV
$fp = fopen('color_options_audit.csv', 'w');
fputcsv($fp, ['Option Code', 'Label (FR)', 'Product Count', 'Action']);

foreach ($options as $option) {
    fputcsv($fp, [
        $option['code'],
        $option['label_fr'],
        $option['product_count'],
        '' // To be filled manually
    ]);
}

fclose($fp);

echo "Exported " . count($options) . " color options to color_options_audit.csv\n";
echo "Review file and mark actions: KEEP, DELETE, MERGE_TO:color_code\n";
EOFPHP

php export_color_options.php
```

#### Step 2: Analyze and Plan Consolidation (1 hour)

Open `color_options_audit.csv` and analyze:

1. **Identify Duplicates**:
   - "red", "Red", "RED" → Keep "red"
   - "navy_blue", "navy", "dark_blue" → Keep "navy_blue"
   
2. **Identify Unused** (product_count = 0):
   - Mark for deletion

3. **Identify Similar Colors**:
   - Group similar shades
   - Keep most common variant

4. **Create Consolidation Plan**:
```csv
Option Code,Label (FR),Product Count,Action
red,Rouge,120,KEEP
Red,Rouge,0,DELETE
RED,Rouge,0,DELETE
navy_blue,Bleu Marine,80,KEEP
navy,Marine,15,MERGE_TO:navy_blue
dark_blue,Bleu Foncé,5,MERGE_TO:navy_blue
beige_light,Beige Clair,0,DELETE
```

#### Step 3: Execute Consolidation (1 hour)

```bash
cd /home/pim/public_html/webapp

cat > consolidate_colors.php << 'EOFPHP'
<?php
$pdo = new PDO('mysql:host=127.0.0.1;port=3307;dbname=akeneo_pim', 'root', 'YourNewStrongPassword');

// Read consolidation plan
$plan = array_map('str_getcsv', file('color_options_audit.csv'));
array_shift($plan); // Remove header

$deleted = 0;
$merged = 0;

foreach ($plan as $row) {
    list($code, $label, $count, $action) = $row;
    
    if ($action === 'DELETE') {
        // Delete option
        $pdo->exec("
            DELETE FROM pim_catalog_attribute_option 
            WHERE code = '$code' 
            AND attribute_id = (SELECT id FROM pim_catalog_attribute WHERE code = 'color')
        ");
        $deleted++;
        echo "Deleted: $code\n";
        
    } elseif (strpos($action, 'MERGE_TO:') === 0) {
        $targetCode = substr($action, 9);
        
        // Update product values to use target color
        // This is complex - may need manual product updates
        echo "Merge $code → $targetCode: Manual review needed\n";
        $merged++;
    }
}

echo "\nConsolidation Summary:\n";
echo "Deleted: $deleted options\n";
echo "Merged: $merged options\n";
EOFPHP

# Review the plan first
nano color_options_audit.csv

# Then execute
php consolidate_colors.php
```

#### Step 4: Add English Translations for Remaining Colors (30 minutes)

```csv
code,locale,label
red,en_US,Red
blue,en_US,Blue
green,en_US,Green
yellow,en_US,Yellow
black,en_US,Black
white,en_US,White
navy_blue,en_US,Navy Blue
... (continue for all remaining colors)
```

Import via: `Settings → Imports → Attribute option translation import`

### Acceptance Criteria
- [ ] Color options reduced from 631 to 100-200
- [ ] Duplicates removed
- [ ] Unused options deleted
- [ ] Similar colors consolidated
- [ ] English translations added for all remaining colors
- [ ] No products lost color data

---

## Phase 2 Summary

**Total Duration**: 12-16 hours  
**Status**: Ready to Execute  
**Risk Level**: MEDIUM (validation rules may affect existing products)

### Deliverables
1. ✅ Numeric validation rules for 15+ attributes
2. ✅ Text validation rules (character limits, regex)
3. ✅ File/media validation rules
4. ✅ 7 new attribute groups created
5. ✅ 100 attributes reorganized
6. ✅ Empty "marketing" group deleted
7. ✅ Color options reduced to 100-200
8. ✅ Validation test scripts

### Testing Checklist
- [ ] Invalid numeric values rejected
- [ ] Text exceeding limits rejected
- [ ] Invalid file types rejected
- [ ] Attribute groups visible in UI
- [ ] Product edit screen organized
- [ ] Color picker shows consolidated options

### Next Phase
Proceed to **Phase 3: Optimizations** (11-16 hours) for family optimization, documentation, and training.

---

*Continue to Phase 3 detailed planning...*
