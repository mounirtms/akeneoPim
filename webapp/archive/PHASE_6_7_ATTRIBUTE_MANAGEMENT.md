# Phase 6 & 7: Attribute Group Reorganization & Documentation

**Date**: 2026-04-27  
**Status**: Analysis Complete - Ready for Implementation  
**Priority**: Medium (UX Improvement)

---

## Executive Summary

Current analysis reveals that **100 attributes** are grouped under the "general" attribute group, making product editing cumbersome and unorganized. This phase provides a reorganization strategy and documentation framework to improve user experience.

---

## Current State Analysis

### Attribute Group Distribution

| Group | Attribute Count | Status |
|-------|----------------|--------|
| **general** | **100** | ⚠️ Too many - needs reorganization |
| technical | 11 | ✅ Reasonable |
| other | 1 | ✅ OK |
| marketing | 0 | ⚠️ Empty - can be populated |

**Total Attributes**: 112

**Issue**: 89% of attributes (100/112) are in the "general" group, making it difficult for users to find and organize product data efficiently.

---

## Recommended Reorganization Strategy

### Proposed Attribute Groups

#### 1. Product Information (keep existing "general" - but reduce)
**Target**: 15-20 core attributes  
**Purpose**: Essential product identifiers and basic info  
**Examples**:
- SKU / Product Code
- Name / Title
- Brand
- Status
- Creation/Update dates

#### 2. Technical Specifications (existing - expand)
**Current**: 11 attributes  
**Target**: 20-25 attributes  
**Purpose**: Technical details, dimensions, specifications  
**Move here**:
- Dimensions (length, width, height)
- Weight
- Material
- Technical specifications
- Capacity/Size specifications
- Model numbers

#### 3. Marketing (existing - populate)
**Current**: 0 attributes  
**Target**: 15-20 attributes  
**Purpose**: Marketing and promotional content  
**Move here**:
- Descriptions (short, long)
- Meta title/description (SEO)
- Keywords
- Features/Benefits
- Promotional text
- Marketing categories

#### 4. Media & Assets (create new)
**Target**: 10-15 attributes  
**Purpose**: Images, videos, documents  
**Move here**:
- Product images (main, additional)
- Videos
- Datasheets
- Manuals
- Certificates
- 3D models

#### 5. Pricing & Commercial (create new)
**Target**: 10-15 attributes  
**Purpose**: Pricing, margins, commercial info  
**Move here**:
- Base price
- Sale price
- Cost price
- Margin
- Tax information
- Currency
- Price lists

#### 6. Logistics & Inventory (create new)
**Target**: 10-15 attributes  
**Purpose**: Shipping, warehouse, stock info  
**Move here**:
- Stock level
- Warehouse location
- Shipping dimensions
- Package weight
- Minimum order quantity
- Lead time
- Supplier info

---

## Implementation Plan

### Phase 6A: Create New Attribute Groups (15 minutes)

1. **Navigate to Akeneo UI**:
   - Settings → Attribute Groups → Create

2. **Create groups** (if they don't exist):
   ```
   Code: media_assets
   Label: Media & Assets
   Sort Order: 30
   
   Code: pricing_commercial
   Label: Pricing & Commercial
   Sort Order: 40
   
   Code: logistics_inventory
   Label: Logistics & Inventory
   Sort Order: 50
   ```

3. **Update existing groups**:
   ```
   general → Sort Order: 10
   marketing → Sort Order: 20
   technical → Sort Order: 25
   ```

### Phase 6B: Reorganize Attributes (1-2 hours)

**Method 1: Via Akeneo UI** (Recommended for safety)

1. **Export current attribute list**:
   ```bash
   cd /home/pim/public_html
   php bin/console pim:product:query-help --env=prod
   ```

2. **Use bulk attribute editor**:
   - Settings → Attributes
   - Select attributes by type/name pattern
   - Bulk Actions → Change attribute group
   - Repeat for each category

**Method 2: Via API** (Faster, requires caution)

Use Akeneo API to batch update attribute groups:
```bash
curl -X PATCH https://pim.technostationery.com/api/rest/v1/attributes/{code} \
  -H "Authorization: Bearer {token}" \
  -d '{"group": "media_assets"}'
```

**Method 3: Via Database** (Advanced, backup required!)

```sql
-- BACKUP FIRST!
-- Update attributes matching pattern
UPDATE pim_catalog_attribute 
SET group_id = (SELECT id FROM pim_catalog_attribute_group WHERE code = 'media_assets')
WHERE code LIKE '%image%' OR code LIKE '%picture%' OR code LIKE '%photo%';
```

---

## Phase 7: Attribute Documentation Dictionary

### Purpose
Create comprehensive documentation for all 112 attributes to:
- Help users understand each attribute's purpose
- Provide data entry guidelines
- Document validation rules
- List dependencies and relationships

### Documentation Template

For each attribute, document:

```markdown
## Attribute: {attribute_code}

**Label**: {Localized label}  
**Type**: {text|number|select|image|etc}  
**Group**: {Attribute group}  
**Required**: {Yes|No}  
**Scopable**: {Yes|No} (Channel-specific)  
**Localizable**: {Yes|No} (Language-specific)  

### Purpose
{What this attribute represents}

### Usage Guidelines
{How to fill this attribute}

### Validation Rules
- {Rule 1}
- {Rule 2}

### Examples
- Good: {example}
- Bad: {example}

### Related Attributes
- {attribute_1}
- {attribute_2}

### Notes
{Any special considerations}
```

### Implementation

**Step 1**: Export attribute list with details
```bash
cd /home/pim/public_html
php bin/console doctrine:query:sql "
  SELECT 
    a.code,
    a.attribute_type,
    g.code as group_code,
    t.label,
    a.is_required,
    a.is_scopable,
    a.is_localizable
  FROM pim_catalog_attribute a
  LEFT JOIN pim_catalog_attribute_group g ON a.group_id = g.id
  LEFT JOIN pim_catalog_attribute_translation t ON a.id = t.foreign_key AND t.locale = 'en_US'
  ORDER BY g.code, a.code
" --env=prod > attributes_export.txt
```

**Step 2**: Create documentation file
```bash
cd /home/pim/public_html/webapp
touch ATTRIBUTE_DICTIONARY.md
```

**Step 3**: Populate with attribute definitions

Sample structure:
```markdown
# Akeneo Attribute Dictionary

## Product Information Group

### sku
- **Type**: Text
- **Required**: Yes
- **Purpose**: Unique product identifier
...

## Technical Specifications Group
...

## Marketing Group
...
```

---

## Benefits of Reorganization

### For Product Managers
- ✅ Easier to find relevant attributes
- ✅ Logical grouping reduces cognitive load
- ✅ Faster product data entry
- ✅ Clearer data structure

### For Data Entry Team
- ✅ Clear sections to fill
- ✅ Less scrolling in product edit form
- ✅ Better understanding of attribute purpose
- ✅ Reduced errors

### For System Administrators
- ✅ Better organized system
- ✅ Easier maintenance
- ✅ Clear documentation
- ✅ Onboarding new users faster

---

## Estimated Impact

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| Attributes in "general" | 100 | ~15 | 85% reduction |
| Product edit form sections | 4 | 6-7 | Better organization |
| Time to find attribute | 30-60s | 10-20s | 50-67% faster |
| User satisfaction | Low | High | Significant |

---

## Rollback Plan

If reorganization causes issues:

1. **Backup database before changes**:
   ```bash
   mysqldump -u user -p database > backup_before_reorg.sql
   ```

2. **Document original group_id for each attribute**

3. **Restore if needed**:
   ```sql
   UPDATE pim_catalog_attribute 
   SET group_id = {original_id} 
   WHERE code = '{attribute_code}';
   ```

4. **Clear cache**:
   ```bash
   php bin/console cache:clear --env=prod
   ```

---

## Maintenance Schedule

### Quarterly Review (Every 3 months)
- Review new attributes
- Ensure proper group assignment
- Update documentation
- Gather user feedback

### Annual Audit (Yearly)
- Comprehensive review of all 112+ attributes
- Identify unused attributes
- Clean up obsolete data
- Update grouping strategy if needed

---

## Quick Start Guide

### For Immediate Implementation

1. **Backup database** (5 min)
2. **Create new attribute groups** (15 min)
3. **Reorganize top 50 attributes** (1 hour)
   - Focus on most-used attributes first
4. **Test product editing** (15 min)
5. **Get user feedback** (ongoing)
6. **Reorganize remaining attributes** (1 hour)
7. **Create basic documentation** (1 hour)

**Total Time**: ~3.5 hours  
**Impact**: Significant UX improvement

---

## Success Criteria

✅ No more than 20 attributes in any single group  
✅ All groups have logical, related attributes  
✅ Product edit form is easier to navigate  
✅ Documentation exists for all attributes  
✅ User feedback is positive  
✅ No data loss or corruption  

---

## Sample SQL Queries for Reorganization

### Get attributes by name pattern
```sql
SELECT code, attribute_type 
FROM pim_catalog_attribute 
WHERE code LIKE '%image%' OR code LIKE '%media%';
```

### Move attributes to new group
```sql
-- Get group IDs first
SELECT id, code FROM pim_catalog_attribute_group;

-- Update attributes (example)
UPDATE pim_catalog_attribute 
SET group_id = 5  -- ID of media_assets group
WHERE code IN ('product_image', 'gallery_images', 'video_url');
```

### Verify reorganization
```sql
SELECT 
  g.code as group_name,
  COUNT(a.id) as attribute_count
FROM pim_catalog_attribute_group g
LEFT JOIN pim_catalog_attribute a ON g.id = a.group_id
GROUP BY g.id, g.code
ORDER BY attribute_count DESC;
```

---

## Status & Next Steps

**Current Status**: ✅ Analysis Complete

**Phase 6 Status**: ⏳ Ready for Implementation  
**Phase 7 Status**: ⏳ Ready for Documentation

**Recommended Timeline**:
- Week 1: Create new groups and reorganize critical attributes
- Week 2: Complete reorganization and initial documentation
- Week 3: User testing and feedback
- Week 4: Finalize documentation and training

**Priority**: Medium (improves UX but not critical for functionality)

---

**Generated**: 2026-04-27 16:58:00  
**Repository**: https://github.com/mounirtms/akeneoPim.git  
**Branch**: oldbranch

