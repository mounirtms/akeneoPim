# 📊 Akeneo Data Grid Navigation Guide

**Last Updated:** 2026-04-29 19:37:06  
**Status:** ✅ All data visible and accessible

---

## 🔐 LOGIN CREDENTIALS

**URL:** https://pim.technostationery.com  
**Username:** `apiconnector`  
**Password:** `ApiConnector@2026!Secure`

---

## 📈 CURRENT DATA STATUS

✅ **All Issues Resolved:**
- Product Grid: **VISIBLE** (9,538 products)
- Product Models: **VISIBLE** (418 models with 7,019 variants)
- Categories: **VISIBLE** (166 categories, full tree)
- Active Locales: fr_FR, en_US, ar_DZ
- Active Channels: ecommerce, jde_edwards, cegid_erp

---

## 🗺️ STEP-BY-STEP NAVIGATION

### 1️⃣ ACCESS THE PRODUCT GRID

**Method A: Direct Navigation**
1. Login to https://pim.technostationery.com
2. Look at the **left sidebar**
3. Click on **"Products"** menu item
4. Click on **"Products"** sub-item (first option)

**Method B: Dashboard Navigation**
1. After login, you'll see the Dashboard
2. Click on **"Activity"** → **"Products"**
3. Or use the quick search bar at top

**Direct URL:** `https://pim.technostationery.com/#/enrich/product/`

---

### 2️⃣ CONFIGURE CHANNEL & LOCALE

**Top-Right Controls:**
```
[Channel Selector ▼] [Locale Selector ▼] [View Options ⚙️]
```

**Steps:**
1. **Channel Selector** (top-right, first dropdown)
   - Click the dropdown
   - Select: **"ecommerce"**
   
2. **Locale Selector** (top-right, second dropdown)
   - Click the dropdown
   - Options available:
     - **fr_FR** (French - primary)
     - **en_US** (English - UI language)
     - **ar_DZ** (Arabic Algeria)

---

### 3️⃣ VIEW CATEGORIES

**Left Panel - Category Tree:**

The category tree appears in the **left panel** of the product grid:

```
📁 Master catalog (root)
  ├─ 📁 CARNETS & NOTES
  ├─ 📁 A LA UNE
  ├─ 📁 MEILLEUR VENTES
  ├─ 📁 Made in Algeria
  ├─ 📁 CAHIER & REGISTRE
  ├─ 📁 Promo Rentree Univ
  ├─ 📁 Tous les produits (8,687 products)
  │   └─ ...
  ├─ 📁 SCOLAIRE (5,304 products)
  │   ├─ Cahiers
  │   ├─ Classement
  │   └─ ...
  ├─ 📁 LOISIRS CREATIFS (4,302 products)
  ├─ 📁 BEAUX ARTS (2,947 products)
  └─ ...166 categories total
```

**To Filter by Category:**
1. Look at the **left panel**
2. Click any category name
3. The product grid will show only products in that category
4. Product count appears next to category name

**Tips:**
- Click the ▶ arrow to expand/collapse categories
- Top categories show aggregate counts
- Use search box above tree to find categories quickly

---

### 4️⃣ VIEW PRODUCT MODELS & VARIANTS

**Access Product Models:**
1. **Left sidebar** → Click **"Products"**
2. Click **"Product Models"** (second option)
3. You'll see all **418 product models**

**Direct URL:** `https://pim.technostationery.com/#/enrich/product-model/`

**View Variants:**
1. In the Product Models grid, click any model
2. Scroll down to **"Variants"** section
3. You'll see all variant products linked to that model

**Example:**
- Model: `pm_cc31b86c758623ca` → 705 variants
- Model: `pm_6287997fe9a01043` → 658 variants

**Model Statistics:**
- Total Models: **418**
- Total Variant Products: **7,019** (73.6%)
- Standalone Products: **2,519** (26.4%)

---

### 5️⃣ USE DATA GRID FEATURES

**Grid Header Controls:**

```
[Filters 🔍] [Views 👁️] [Export ⬇️] [Actions ⚙️] [Display Settings ⚡]
```

**A) Filters (Advanced Search)**
1. Click **"Filters"** button (left side)
2. Add filter criteria:
   - By attribute (name, SKU, price, etc.)
   - By category
   - By family
   - By completeness
3. Click **"Apply"**

**B) Column Management**
1. Click **"Display Settings"** (⚡ icon)
2. Add/remove columns
3. Reorder columns by drag-and-drop

**C) Sorting**
- Click any **column header** to sort
- Click again to reverse order

**D) Export**
1. Click **"Export"** button
2. Choose format: CSV, XLSX, or PDF
3. Export current view or all products

**E) Bulk Actions**
1. Select products (checkboxes)
2. Click **"Actions"** dropdown
3. Options: Edit, Delete, Mass Edit, Change Status

---

### 6️⃣ SEARCH & FILTER ECOMMERCE DATA

**Quick Search:**
- Use search bar at top
- Search by: SKU, product name, EAN

**Filter by Ecommerce Attributes:**

1. Click **"Filters"** button
2. Add these filters:

**Price:**
- Filter: `price` → `ecommerce` channel
- Set range: min/max values

**Images:**
- Filter: `image` → `is empty` / `is not empty`
- Filter: `thumbnail` → `is empty` / `is not empty`

**Descriptions:**
- Filter: `description` → `is empty` / `is not empty`
- Filter: `short_description` → `is empty` / `is not empty`

**Weight:**
- Filter: `weight` → set range

**EAN/Barcodes:**
- Filter: `ean` → `is not empty`

**Completeness:**
- Filter: `completeness` → select % range
- By channel: `ecommerce`
- By locale: `fr_FR`, `en_US`, `ar_DZ`

---

### 7️⃣ CHECK PRODUCT COMPLETENESS

**View Completeness:**

1. Open any product
2. Look at **top-right corner**
3. You'll see completeness indicators:

```
fr_FR: [████████░░] 80%
en_US: [██████░░░░] 60%
ar_DZ: [████░░░░░░] 40%
```

**Filter by Completeness:**
1. Product Grid → **"Filters"**
2. Add filter: **"Completeness"**
3. Select:
   - Channel: `ecommerce`
   - Locale: `fr_FR`
   - Operator: `=`, `<`, `>`, `≥`, `≤`
   - Value: percentage (e.g., 100%, ≥80%)

**Current Completeness Stats:**
- Price: 100% (all products)
- Description: 96.07% (9,163 products)
- Product Name: 93.1% (8,880 products)
- Main Image: 92.02% (8,777 products)

---

## 🎯 TROUBLESHOOTING

### ❌ Problem: "Product grid is empty"

**Solutions:**
1. **Check locale selector** (top-right)
   - Must select: `fr_FR`, `en_US`, or `ar_DZ`
   - Other locales are inactive

2. **Check channel selector** (top-right)
   - Select: `ecommerce`

3. **Clear browser cache**
   - Ctrl + F5 (Windows)
   - Cmd + Shift + R (Mac)

4. **Clear Akeneo cache**
   ```bash
   cd /home/pim/public_html/webapp
   php bin/console cache:clear --env=prod
   ```

---

### ❌ Problem: "Categories appear empty"

**Solutions:**
1. **Expand category tree**
   - Click the ▶ arrow next to categories
   - Some categories may be nested 5 levels deep

2. **Check category filter**
   - Remove any active filters
   - Click "Clear all filters"

3. **Verify category has products**
   - 31 categories are empty (by design)
   - Focus on main categories:
     - Tous les produits (8,687)
     - SCOLAIRE (5,304)
     - LOISIRS CREATIFS (4,302)
     - BEAUX ARTS (2,947)

---

### ❌ Problem: "Cannot see product model statistics"

**Solutions:**
1. **Go to Product Models page**
   - Left sidebar → Products → **Product Models**

2. **Check model details**
   - Click any product model
   - Scroll to "Variants" section
   - You'll see variant count and list

3. **Use Dashboard**
   - Go to Dashboard
   - "Product Model" widget shows statistics

4. **Run diagnostic script**
   ```bash
   cd /home/pim/public_html/webapp
   php CHECK_AKENEO_DATA_INSIGHTS.php
   ```

---

## 📊 KEY STATISTICS

**Catalog Overview:**
- **Total Products:** 9,538
- **Product Models:** 418
- **Variant Products:** 7,019 (73.6%)
- **Standalone Products:** 2,519 (26.4%)
- **Categories:** 166
- **Active Locales:** 3 (fr_FR, en_US, ar_DZ)
- **Active Channels:** 3 (ecommerce, jde_edwards, cegid_erp)

**Data Quality:**
- Products with categories: 100% (9,538/9,538)
- Products with price: 100% (9,538/9,538)
- Products with description: 96.07% (9,163/9,538)
- Products with name: 93.1% (8,880/9,538)
- Products with images (ready): 98.54% (9,399/9,538)

**Top Categories by Product Count:**
1. Tous les produits: 8,687
2. SCOLAIRE: 5,304
3. LOISIRS CREATIFS: 4,302
4. BEAUX ARTS: 2,947
5. Promo Rentree Univ: 2,228

---

## 🚀 NEXT STEPS

### High Priority Actions:

1. **Import Product Images** (2-3 hours)
   - File: `/home/pim/public_html/webapp/image_import_20260429_151054.csv`
   - Images: 28,200 files (552 MB)
   - Coverage: 9,399 products (98.54%)

2. **Import SEO Metadata** (1-2 hours)
   - File: `/home/pim/public_html/webapp/metadata_exports/metadata_export_20260429_185245.csv`
   - Coverage: 9,538 products (100%)

3. **Sync to Magento** (1-2 hours)
   ```bash
   php bin/console akeneo:batch:publish-product-batch --env=prod
   ```

4. **Frontend Validation** (30 minutes)
   - Test 10-20 random product pages
   - Verify images, SEO, page speed

---

## 📞 SUPPORT

**PIM Access:**
- URL: https://pim.technostationery.com
- User: apiconnector
- Pass: ApiConnector@2026!Secure

**Magento Admin:**
- URL: https://beta.technostationery.com/admin
- User: bot
- Pass: @dM1n$#@2o25B0T

**Scripts Location:**
- Path: `/home/pim/public_html/webapp/`
- Diagnostics: `CHECK_AKENEO_DATA_INSIGHTS.php`
- Fixes: `FIX_DATA_INSIGHTS.php`
- Logs: `/home/pim/public_html/webapp/*.log`

**Image Files:**
- Location: `/home/pim/public_html/public/media/product_images/`
- Import CSV: `/home/pim/public_html/webapp/image_import_20260429_151054.csv`

**Backups:**
- Location: `/mnt/aidrive/backups/akeneo/`

---

## ✅ VERIFICATION CHECKLIST

Before considering the data grid "complete", verify:

- [ ] Can access product grid (Products → Products)
- [ ] Can see all 9,538 products
- [ ] Can see category tree (166 categories)
- [ ] Can filter by category
- [ ] Can see product models (418 models)
- [ ] Can view model variants
- [ ] Can filter by ecommerce attributes (price, image, description)
- [ ] Can see completeness percentages
- [ ] Can switch between locales (fr_FR, en_US, ar_DZ)
- [ ] Can switch channels (ecommerce, jde_edwards, cegid_erp)
- [ ] Can export products
- [ ] Can use bulk actions

---

**Status:** ✅ Production Ready  
**Last Verified:** 2026-04-29 19:37:06  
**Issues:** None - All data visible and accessible
