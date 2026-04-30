# Detailed Implementation Plan
**Akeneo PIM Data Quality Improvement Project**  
**Start Date**: 2026-04-28 (recommended)  
**Total Duration**: 3-4 weeks  
**Total Effort**: 34-48 hours  
**Current Grade**: B+ (87%)  
**Target Grade**: A (95%)

---

## Table of Contents

1. [Phase 1: Critical Fixes (Week 1)](#phase-1-critical-fixes-week-1)
2. [Phase 2: High-Priority Improvements (Week 2)](#phase-2-high-priority-improvements-week-2)
3. [Phase 3: Optimizations (Week 3-4)](#phase-3-optimizations-week-3-4)
4. [Phase 4: Ongoing Maintenance](#phase-4-ongoing-maintenance)
5. [Resource Requirements](#resource-requirements)
6. [Risk Assessment](#risk-assessment)
7. [Success Criteria](#success-criteria)

---

## Phase 1: Critical Fixes (Week 1)

**Duration**: 11-16 hours  
**Priority**: 🔴 CRITICAL - Must Complete Before Production Launch  
**Expected Improvement**: 75% → 85% (10 points)

---

### Task 1.1: Configure Required Attributes
**Duration**: 6-8 hours  
**Owner**: PIM Administrator  
**Priority**: 🔴 CRITICAL

#### Objective
Enforce minimum data quality standards by configuring required attributes across all 18 families.

#### Prerequisites
- [ ] Akeneo PIM admin access
- [ ] List of all 18 families confirmed
- [ ] Stakeholder approval on required fields

#### Implementation Steps

##### Step 1: Define Core Required Attributes (30 minutes)
**Required for ALL Families**:
```
1. sku (identifier) - already required by default
2. name - Product name
3. description - Full product description
4. price - Base price
5. image - Main product image
6. tax_class_id - Tax classification
7. visibility - Product visibility setting
8. status - Enabled/disabled status
```

##### Step 2: Define Category-Specific Required Attributes (1 hour)

**Family: scolaire (School Supplies)**
```
Required: sku, name, description, price, image, tax_class_id, visibility, status
Optional Required:
- age_range (e.g., 3-5 years, 6-8 years)
- grade_level (e.g., kindergarten, elementary)
- education_category (e.g., arts, math, reading)
```

**Family: informatique (IT Products)**
```
Required: sku, name, description, price, image, tax_class_id, visibility, status
Optional Required:
- warranty (warranty period)
- brand (manufacturer brand)
- model (product model number)
- specifications (technical specs)
```

**Family: beaux_arts (Fine Arts)**
```
Required: sku, name, description, price, image, tax_class_id, visibility, status
Optional Required:
- color (primary color)
- size (dimensions or standard size)
- material (composition/materials)
- art_category (painting, sculpture, etc.)
```

**Family: papeterie (Stationery)**
```
Required: sku, name, description, price, image, tax_class_id, visibility, status
Optional Required:
- paper_weight (grams per square meter)
- sheet_count (number of sheets)
- paper_size (A4, A5, etc.)
```

**Remaining Families**: Apply core 8 required attributes
- bureautique, tableau, default, calculatrices, maglux
- fournitures_bureau, crayons, cahier, bags_sac, techno
- products, madeinalgeria, ecriture, classement

##### Step 3: Configure Requirements in Akeneo (4-5 hours)

**For Each Family**:

1. Navigate to Akeneo PIM UI:
   ```
   Settings → Families → [Select Family]
   ```

2. Click "Attributes" tab

3. For each core required attribute:
   - Find the attribute in the list
   - Click the "Required" checkbox next to "ecommerce" channel
   - Save changes

4. Repeat for category-specific attributes (if applicable)

5. Verify configuration:
   - Try creating a new product in this family
   - Attempt to save without required fields
   - Should receive validation error

**Command-Line Alternative** (Faster for bulk updates):

Create CSV file `required_attributes.csv`:
```csv
family_code,attribute_code,channel_code,required
scolaire,name,ecommerce,1
scolaire,description,ecommerce,1
scolaire,price,ecommerce,1
scolaire,image,ecommerce,1
scolaire,tax_class_id,ecommerce,1
scolaire,visibility,ecommerce,1
scolaire,status,ecommerce,1
scolaire,age_range,ecommerce,1
scolaire,grade_level,ecommerce,1
... (repeat for all families)
```

Import via command line:
```bash
cd /home/pim/public_html
bin/console akeneo:import:family-attributes required_attributes.csv
```

##### Step 4: Test Configuration (30 minutes)

1. **Test Product Creation**:
   - Create new product in each family
   - Try saving without required fields
   - Verify validation errors appear

2. **Test Existing Products**:
   - Open existing product
   - Check if it shows completeness warnings
   - Verify required fields are marked with asterisk (*)

3. **Test API Behavior**:
   ```bash
   curl -X POST https://pim.technostationery.com/api/rest/v1/products \
     -H "Authorization: Bearer YOUR_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{
       "identifier": "test-sku-001",
       "family": "scolaire"
     }'
   # Should return validation error for missing required fields
   ```

##### Step 5: Run Completeness Calculation (1 hour)

```bash
# SSH into server
cd /home/pim/public_html

# Run completeness calculation (may take 30-60 minutes for 9,538 products)
bin/console pim:completeness:calculate --verbose

# Verify results
bin/console pim:completeness:export > completeness_report.csv

# Check summary statistics
cat completeness_report.csv | awk -F',' '{sum+=$5; count++} END {print "Average Completeness:", sum/count "%"}'
```

#### Acceptance Criteria
- [ ] All 18 families have 8 core required attributes configured
- [ ] 4 category-specific families have additional required attributes
- [ ] Validation errors appear when required fields are missing
- [ ] Completeness calculation runs successfully
- [ ] Average completeness score visible in Akeneo UI

#### Rollback Plan
If issues occur:
```bash
# Backup database before changes
mysqldump -u root -p'YourNewStrongPassword' -h 127.0.0.1 -P 3307 akeneo_pim > akeneo_backup_phase1.sql

# To restore if needed
mysql -u root -p'YourNewStrongPassword' -h 127.0.0.1 -P 3307 akeneo_pim < akeneo_backup_phase1.sql
```

---

### Task 1.2: Add English Translations
**Duration**: 4-6 hours  
**Owner**: Content Manager / PIM Administrator  
**Priority**: 🔴 CRITICAL

#### Objective
Add en_US translations for all localizable attributes to enable English UI and international support.

#### Prerequisites
- [ ] Akeneo PIM admin access
- [ ] List of 20+ attributes missing translations
- [ ] English terminology standards approved

#### Attributes Requiring English Translation

**Core Attributes** (Priority 1):
```
1. name → "Product Name"
2. description → "Product Description"
3. short_description → "Short Description"
4. meta_title → "Meta Title (SEO)"
5. meta_description → "Meta Description (SEO)"
6. meta_keywords → "Meta Keywords (SEO)"
7. meta_keyword → "Meta Keyword (SEO)"
8. image_label → "Image Label"
9. gallery → "Image Gallery"
10. media_gallery → "Media Gallery"
```

**Extended Attributes** (Priority 2):
```
11. amasty_preorder_cart_label → "Pre-order Cart Label"
12. amasty_preorder_note → "Pre-order Note"
13. amtoolkit_canonical → "Canonical URL"
14. category_ids → "Category IDs"
15. custom_layout_update → "Custom Layout Update"
16. en_promo → "On Promotion"
17. has_options → "Has Options"
18. links_title → "Links Title"
19. mwishlist_sku → "Wishlist SKU"
20. quickorder_sku → "Quick Order SKU"
21. required_options → "Required Options"
```

#### Implementation Steps

##### Method 1: Manual UI Entry (Slower but Safer)

**For Each Attribute** (repeat 20+ times):

1. Navigate to:
   ```
   Settings → Attributes → [Select Attribute]
   ```

2. Click "Labels" tab

3. Click "Add a label"

4. Select "en_US" from locale dropdown

5. Enter English label (see table above)

6. Add help text if needed:
   ```
   Example for "name":
   Label: "Product Name"
   Help text: "The name of the product as it will appear in the catalog"
   ```

7. Save changes

**Estimated Time**: 15-20 minutes per attribute = 5-7 hours for 20+ attributes

##### Method 2: Bulk CSV Import (Faster)

**Step 1**: Create CSV file `attribute_translations_en.csv`:
```csv
code,locale,label,description
name,en_US,Product Name,The name of the product as displayed in catalog
description,en_US,Product Description,Full description of the product features and benefits
short_description,en_US,Short Description,Brief summary of the product
meta_title,en_US,Meta Title (SEO),SEO meta title for search engines
meta_description,en_US,Meta Description (SEO),SEO meta description for search results
meta_keywords,en_US,Meta Keywords (SEO),SEO keywords for search optimization
meta_keyword,en_US,Meta Keyword (SEO),Individual SEO keyword
image_label,en_US,Image Label,Alt text label for main product image
gallery,en_US,Image Gallery,Collection of product images
media_gallery,en_US,Media Gallery,All product media files
amasty_preorder_cart_label,en_US,Pre-order Cart Label,Label shown in cart for pre-order items
amasty_preorder_note,en_US,Pre-order Note,Note about pre-order availability
amtoolkit_canonical,en_US,Canonical URL,Canonical URL for SEO purposes
category_ids,en_US,Category IDs,Internal category identifiers
custom_layout_update,en_US,Custom Layout Update,Custom XML layout updates
en_promo,en_US,On Promotion,Indicates if product is on special promotion
has_options,en_US,Has Options,Product has customizable options
links_title,en_US,Links Title,Title for related product links
mwishlist_sku,en_US,Wishlist SKU,SKU for wishlist functionality
quickorder_sku,en_US,Quick Order SKU,SKU for quick order form
required_options,en_US,Required Options,Product requires option selection
```

**Step 2**: Import via Akeneo UI:
```
Settings → Imports → Create New Import Profile
Name: "Attribute English Translations"
Job: "Attribute translation import in CSV"
Upload: attribute_translations_en.csv
Execute Import
```

**Step 3**: Verify import:
```
Settings → Attributes → [Check Random Attributes]
Verify en_US labels appear
```

**Estimated Time**: 1 hour to create CSV + 30 minutes to import and verify

##### Method 3: Command Line (Fastest for Technical Users)

```bash
cd /home/pim/public_html

# Create import file (use Method 2 CSV above)
nano attribute_translations_en.csv

# Import using console command
bin/console pim:import:translations attribute_translations_en.csv --locale=en_US

# Verify import
bin/console pim:attribute:list --locale=en_US | grep -E "name|description|meta"
```

#### Testing Steps

1. **Switch UI to English**:
   - User Settings → Interface Language → English
   - Navigate to Products → Create Product
   - Verify all attribute labels appear in English

2. **Test Product Edit Screen**:
   - Open existing product
   - Check that all attributes show English labels
   - No attribute codes (e.g., "meta_description") should be visible

3. **Test API Response**:
   ```bash
   curl https://pim.technostationery.com/api/rest/v1/attributes/name \
     -H "Authorization: Bearer YOUR_TOKEN" | jq '.labels'
   # Should show: {"en_US": "Product Name", "fr_FR": "Nom du produit"}
   ```

#### Acceptance Criteria
- [ ] All 20+ localizable attributes have en_US labels
- [ ] English UI shows translated labels (no attribute codes)
- [ ] Help text added for key attributes
- [ ] API returns en_US translations
- [ ] Both en_US and fr_FR translations coexist

---

### Task 1.3: Enable Completeness Calculation
**Duration**: 1-2 hours  
**Owner**: DevOps / System Administrator  
**Priority**: 🔴 CRITICAL

#### Objective
Enable automatic completeness tracking to monitor product data quality.

#### Prerequisites
- [ ] SSH access to server
- [ ] Cron access
- [ ] Required attributes configured (Task 1.1)

#### Implementation Steps

##### Step 1: Manual Completeness Calculation (30 minutes)

```bash
# SSH into server
ssh user@pim.technostationery.com

# Navigate to Akeneo root
cd /home/pim/public_html

# Run initial completeness calculation
# This will take 30-60 minutes for 9,538 products
bin/console pim:completeness:calculate --verbose

# Monitor progress
tail -f var/logs/prod.log | grep completeness
```

**Expected Output**:
```
Calculating completeness for ecommerce channel...
Processed 1000 / 9538 products...
Processed 2000 / 9538 products...
...
Completeness calculation completed in 42 minutes.
```

##### Step 2: Verify Completeness Data (15 minutes)

**Database Check**:
```bash
/opt/mariadb10.6/mariadb/bin/mysql -u root -p'YourNewStrongPassword' -h 127.0.0.1 -P 3307 akeneo_pim -e "
SELECT 
    COUNT(*) as total_records,
    AVG(((required_count - missing_count) / required_count) * 100) as avg_completeness,
    MIN(((required_count - missing_count) / required_count) * 100) as min_completeness,
    MAX(((required_count - missing_count) / required_count) * 100) as max_completeness
FROM pim_catalog_completeness
WHERE required_count > 0;
"
```

**UI Check**:
1. Navigate to Products in Akeneo
2. Check product list - should show completeness percentage
3. Open individual product - should show completeness per channel/locale

##### Step 3: Set Up Automated Cron Job (30 minutes)

```bash
# Edit crontab
crontab -e

# Add completeness calculation job (runs every 30 minutes)
*/30 * * * * cd /home/pim/public_html && bin/console pim:completeness:calculate >> var/logs/completeness_cron.log 2>&1

# Or run once per hour during business hours (8 AM - 8 PM)
0 8-20 * * * cd /home/pim/public_html && bin/console pim:completeness:calculate >> var/logs/completeness_cron.log 2>&1

# Or run once daily at 2 AM (lighter load)
0 2 * * * cd /home/pim/public_html && bin/console pim:completeness:calculate >> var/logs/completeness_cron.log 2>&1

# Save and exit (:wq in vi/vim)
```

**Verify Cron Setup**:
```bash
# List current cron jobs
crontab -l | grep completeness

# Check if cron service is running
systemctl status cron
# or
service cron status

# Monitor first automated run
tail -f /home/pim/public_html/var/logs/completeness_cron.log
```

##### Step 4: Configure Completeness Rules (15 minutes)

**Channel-Specific Requirements**:

1. Navigate to:
   ```
   Settings → Channels → ecommerce
   ```

2. Verify "Completeness" tab settings:
   - Locales: en_US, fr_FR (both should be checked)
   - Category tree: Select appropriate tree
   - Currencies: EUR, DZD (if applicable)

3. Repeat for other channels (jde_edwards, cegid_erp) if needed

##### Step 5: Create Completeness Monitoring Script (30 minutes)

```bash
cd /home/pim/public_html/webapp

cat > completeness_monitor.php << 'EOFPHP'
<?php
/**
 * Completeness Monitoring Script
 * Run: php completeness_monitor.php
 */

$pdo = new PDO('mysql:host=127.0.0.1;port=3307;dbname=akeneo_pim', 'root', 'YourNewStrongPassword');

$stats = $pdo->query("
    SELECT 
        l.code as locale,
        ch.code as channel,
        COUNT(DISTINCT c.product_id) as products,
        AVG(((c.required_count - c.missing_count) / c.required_count) * 100) as avg_completeness,
        SUM(CASE WHEN c.missing_count = 0 THEN 1 ELSE 0 END) as complete_products,
        SUM(CASE WHEN c.missing_count > 0 THEN 1 ELSE 0 END) as incomplete_products
    FROM pim_catalog_completeness c
    JOIN pim_catalog_locale l ON c.locale_id = l.id
    JOIN pim_catalog_channel ch ON c.channel_id = ch.id
    WHERE c.required_count > 0
    GROUP BY l.code, ch.code
    ORDER BY ch.code, l.code
")->fetchAll(PDO::FETCH_ASSOC);

echo "COMPLETENESS REPORT - " . date('Y-m-d H:i:s') . "\n";
echo str_repeat("=", 80) . "\n\n";

foreach ($stats as $stat) {
    echo "Channel: {$stat['channel']} | Locale: {$stat['locale']}\n";
    echo "  Products: {$stat['products']}\n";
    echo "  Average Completeness: " . round($stat['avg_completeness'], 2) . "%\n";
    echo "  Complete: {$stat['complete_products']} | Incomplete: {$stat['incomplete_products']}\n";
    echo "\n";
}
EOFPHP

# Make executable
chmod +x completeness_monitor.php

# Run it
php completeness_monitor.php
```

#### Acceptance Criteria
- [ ] Initial completeness calculation completed successfully
- [ ] Completeness data visible in database
- [ ] Products show completeness percentage in UI
- [ ] Cron job configured and running
- [ ] Monitoring script created and tested

---

### Task 1.4: Verify and Rerun Audit
**Duration**: 1 hour  
**Owner**: PIM Administrator  
**Priority**: 🔴 CRITICAL

#### Objective
Verify all Phase 1 changes are working and measure improvement.

#### Implementation Steps

##### Step 1: Run Completeness Monitor (5 minutes)
```bash
cd /home/pim/public_html/webapp
php completeness_monitor.php
```

**Expected Output** (should now show >0%):
```
COMPLETENESS REPORT - 2026-04-28 10:00:00
================================================================================

Channel: ecommerce | Locale: en_US
  Products: 9538
  Average Completeness: 78.5%
  Complete: 7201 | Incomplete: 2337

Channel: ecommerce | Locale: fr_FR
  Products: 9538
  Average Completeness: 82.3%
  Complete: 7645 | Incomplete: 1893
```

##### Step 2: Rerun Attribute Audit (5 minutes)
```bash
cd /home/pim/public_html
php webapp/comprehensive_attribute_field_audit.php
```

**Check for Improvements**:
- Product Completeness: Should now show >0% (was 0%)
- Overall Score: Should increase from 75% to ~80-85%

##### Step 3: Rerun Cross-Database Audit (5 minutes)
```bash
php webapp/cross_database_integrity_audit.php
```

**Verify**:
- All previous scores maintained (99.6% sync health)
- No regressions introduced

##### Step 4: Test Product Creation (15 minutes)

**Test 1: Create Product with Missing Required Fields**
1. Navigate to Products → Create
2. Select family: "scolaire"
3. Enter only SKU
4. Try to save → Should show validation error listing missing required fields

**Test 2: Create Complete Product**
1. Create new product with all required fields
2. Save successfully
3. Check completeness: should show 100% for ecommerce/en_US

**Test 3: Edit Existing Product**
1. Open existing product with <100% completeness
2. Identify missing required fields (marked with red exclamation)
3. Complete missing fields
4. Save and verify completeness increases

##### Step 5: Test English UI (10 minutes)

1. Change UI language to English
2. Navigate to Products → Create Product
3. Verify all attribute labels appear in English (not codes)
4. Check that:
   - "name" shows as "Product Name"
   - "description" shows as "Product Description"
   - "meta_title" shows as "Meta Title (SEO)"

##### Step 6: Generate Phase 1 Completion Report (20 minutes)

```bash
cd /home/pim/public_html/webapp

cat > phase1_completion_report.md << 'EOFREPORT'
# Phase 1 Completion Report
**Date**: [INSERT_DATE]
**Duration**: [INSERT_HOURS] hours

## Tasks Completed
- [x] Task 1.1: Required attributes configured for 18 families
- [x] Task 1.2: English translations added for 20+ attributes
- [x] Task 1.3: Completeness calculation enabled and automated
- [x] Task 1.4: Verification and audit rerun completed

## Metrics Before Phase 1
- Attribute Configuration Quality: 75% (Grade C)
- Product Completeness: 0%
- Required Attributes: 0 across all families
- English Translations: 0 localizable attributes

## Metrics After Phase 1
- Attribute Configuration Quality: [INSERT_SCORE]% (Grade [INSERT_GRADE])
- Product Completeness: [INSERT_SCORE]%
- Required Attributes: 8 core + category-specific per family
- English Translations: 20+ localizable attributes

## Completeness Statistics
[INSERT completeness_monitor.php OUTPUT]

## Issues Encountered
[LIST ANY ISSUES]

## Next Steps
- Begin Phase 2: High-Priority Improvements (Week 2)
- Expected improvement: 85% → 92%
EOFREPORT

# Fill in the report manually or with script data
nano phase1_completion_report.md
```

#### Acceptance Criteria
- [ ] Completeness now shows >0% (target: 70-85%)
- [ ] Attribute quality score increased by 10+ points
- [ ] Required fields validation working in UI
- [ ] English translations visible in UI
- [ ] No regressions in cross-database sync (maintain 99.6%)
- [ ] Phase 1 completion report generated

#### Expected Results
| Metric | Before Phase 1 | After Phase 1 | Target |
|--------|----------------|---------------|--------|
| Overall Score | 75% | 80-85% | 85% |
| Completeness | 0% | 70-85% | 80%+ |
| Required Attrs | 0 | 8+ per family | 8+ |
| Translations | 0 | 20+ | 20+ |

---

## Phase 1 Summary

**Total Duration**: 11-16 hours  
**Status**: Ready to Execute  
**Risk Level**: LOW (configuration changes, no data migration)

### Deliverables
1. ✅ Required attributes configured for all 18 families
2. ✅ English translations for 20+ localizable attributes
3. ✅ Automated completeness calculation (cron job)
4. ✅ Completeness monitoring script
5. ✅ Phase 1 completion report
6. ✅ Updated audit scores

### Next Phase
Proceed to **Phase 2: High-Priority Improvements** (12-16 hours) to add validation rules and reorganize attribute groups.

---

*Continue to Phase 2 detailed planning...*
