# 🖥️ Akeneo PIM - Visual Data Grid Guide

**Last Updated:** 2026-04-29  
**URL:** https://pim.technostationery.com  
**Status:** ✅ All data visible

---

## 📍 WHERE TO FIND THE DATA GRID

### LOGIN SCREEN → DASHBOARD → PRODUCT GRID

```
┌─────────────────────────────────────────────────────────────┐
│ 🔐 LOGIN PAGE                                               │
│ https://pim.technostationery.com                           │
│                                                             │
│  Username: [apiconnector            ]                      │
│  Password: [ApiConnector@2026!Secure]                      │
│                                                             │
│  [ Login ] button                                          │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 📊 DASHBOARD (after login)                                  │
│                                                             │
│  Left Sidebar:                                             │
│  ┌──────────────────┐                                      │
│  │ 🏠 Dashboard     │                                      │
│  │ 📦 Products   ← CLICK HERE                              │
│  │   └ Products  ← THEN CLICK HERE                         │
│  │   └ Product Models                                      │
│  │ 📁 Assets        │                                      │
│  │ 🏷️  Catalogs     │                                      │
│  │ ⚙️  Settings     │                                      │
│  └──────────────────┘                                      │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 📋 PRODUCT GRID - THIS IS WHAT YOU'RE LOOKING FOR          │
│                                                             │
│  [Channel: ecommerce ▼] [Locale: fr_FR ▼] [⚙️ Settings]   │
│                                                             │
│  Category Tree (Left)  │  Product List (Center/Right)     │
│  ┌──────────────────┐  │  ┌──────────────────────────┐   │
│  │ 📁 Master        │  │  │ SKU  │ Name  │ Price ... │   │
│  │  ├ SCOLAIRE     │  │  │ 1001 │ Cahier│ 150 DZD  │   │
│  │  ├ BEAUX ARTS   │  │  │ 1002 │ Stylo │ 50 DZD   │   │
│  │  └ LOISIRS      │  │  │ ...  │ ...   │ ...      │   │
│  └──────────────────┘  │  └──────────────────────────┘   │
│                                                             │
│  🎯 You'll see 9,538 products here                         │
└─────────────────────────────────────────────────────────────┘

---

## 🎯 WHAT EACH SCREEN ELEMENT DOES

### Top Bar Controls (Product Grid)

```
┌───────────────────────────────────────────────────────────────┐
│ [Channel ▼]  [Locale ▼]  | [🔍 Search] | [View] [Export] [⚙️]│
└───────────────────────────────────────────────────────────────┘

1. Channel Selector: Choose "ecommerce" (or jde_edwards, cegid_erp)
2. Locale Selector: Choose fr_FR, en_US, or ar_DZ
3. Search Bar: Search by SKU, name, or any attribute
4. View Options: Grid view or list view
5. Export Button: Download products as CSV/XLSX
6. Settings: Column configuration
```

### Left Panel - Category Tree

```
┌─────────────────────────┐
│ 🔍 Search categories    │
├─────────────────────────┤
│ ▼ 📁 Master (root)      │
│   ├─ ▶ CARNETS & NOTES  │
│   ├─ ▶ A LA UNE         │
│   ├─ ▼ SCOLAIRE (5,304) │ ← Click to expand/collapse
│   │   ├─ Cahiers        │
│   │   └─ Classement     │
│   ├─ ▼ LOISIRS (4,302)  │
│   └─ ▼ BEAUX ARTS       │
└─────────────────────────┘

• Click ▶ to expand categories
• Click ▼ to collapse categories
• Numbers show product count
• Click category name to filter products
```

### Center Panel - Product Grid

```
┌─────────────────────────────────────────────────────────────┐
│ [Filters 🔍] [100 per page ▼] [Page 1 of 96 ◀ ▶]          │
├────────┬─────────────┬──────────┬──────────┬───────────────┤
│ ☐ SKU  │ Image       │ Name     │ Price    │ Completeness │
├────────┼─────────────┼──────────┼──────────┼───────────────┤
│ ☐ 1001 │ [📷 thumb] │ Cahier A4│ 150 DZD  │ █████░ 80%   │
│ ☐ 1002 │ [📷 thumb] │ Stylo    │ 50 DZD   │ ████░░ 60%   │
│ ☐ 1003 │ [📷 thumb] │ Crayon   │ 30 DZD   │ ██████ 100%  │
└────────┴─────────────┴──────────┴──────────┴───────────────┘

• Click checkbox to select products
• Click row to open product details
• Click column header to sort
• Click "Filters" to add search criteria
```

---

## 🔍 HOW TO FILTER ECOMMERCE DATA

### Filter by Price

```
1. Click "Filters" button (top-left)
2. Click "+ Add a filter"
3. Select "price"
4. Choose channel: "ecommerce"
5. Set range: Min [____] Max [____]
6. Click "Apply"
```

### Filter by Images

```
1. Click "Filters" button
2. Click "+ Add a filter"
3. Select "image" (or "thumbnail")
4. Choose operator:
   • "is empty" (products without images)
   • "is not empty" (products with images)
5. Click "Apply"

Result: Shows only products matching image criteria
```

### Filter by Category

```
Method 1: Use Category Tree (Left Panel)
• Simply click any category name

Method 2: Use Filters
1. Click "Filters" button
2. Click "+ Add a filter"
3. Select "categories"
4. Choose category from dropdown
5. Option: "Include subcategories" ✓
6. Click "Apply"
```

### Filter by Completeness

```
1. Click "Filters" button
2. Click "+ Add a filter"
3. Select "completeness"
4. Choose:
   • Channel: "ecommerce"
   • Locale: "fr_FR" (or en_US, ar_DZ)
   • Operator: = / < / > / ≥ / ≤
   • Value: 100% (or any percentage)
5. Click "Apply"

Example filters:
• "= 100%" → Only complete products
• "< 100%" → Incomplete products
• "≥ 80%" → At least 80% complete
```

---

## 📊 VIEWING PRODUCT MODEL STATISTICS

### Access Product Models

```
┌─────────────────────────────────────────────────────────────┐
│ Left Sidebar                                                │
│                                                             │
│ 📦 Products                                                 │
│   ├─ Products (9,538 total)    ← Individual products       │
│   └─ Product Models (418 total) ← CLICK HERE               │
└─────────────────────────────────────────────────────────────┘
```

### Product Model Grid

```
┌─────────────────────────────────────────────────────────────┐
│ PRODUCT MODELS                                              │
├─────────────────┬───────────────┬────────────┬──────────────┤
│ Code            │ Family Variant│ # Variants │ Status       │
├─────────────────┼───────────────┼────────────┼──────────────┤
│ pm_cc31b86c...  │ products_type │ 705 ←      │ Enabled      │
│ pm_6287997f...  │ products_type │ 658        │ Enabled      │
│ pm_a06e32d0...  │ products_type │ 341        │ Enabled      │
└─────────────────┴───────────────┴────────────┴──────────────┘

• "# Variants" column shows variant count per model
• Click any row to see variant details
```

### Inside a Product Model

```
When you click a product model, you'll see:

┌─────────────────────────────────────────────────────────────┐
│ Product Model: pm_cc31b86c758623ca                          │
│ Family Variant: products_by_type                            │
├─────────────────────────────────────────────────────────────┤
│ Variants (705 total)                     [Export] [+ Add]   │
├─────────────────────────────────────────────────────────────┤
│ SKU          │ Type    │ Color │ Size │ Completeness       │
├──────────────┼─────────┼───────┼──────┼────────────────────┤
│ 1140619022-1 │ Notebook│ Blue  │ A4   │ ████████░░ 85%    │
│ 1140619022-2 │ Notebook│ Red   │ A4   │ ████████░░ 85%    │
│ 1140619022-3 │ Notebook│ Green │ A5   │ ███████░░░ 75%    │
│ ...          │ ...     │ ...   │ ...  │ ...               │
└──────────────┴─────────┴───────┴──────┴────────────────────┘

This shows all 705 variant products under this model
```

---

## ❓ WHY CATEGORIES MIGHT APPEAR EMPTY

### Reason 1: Category Tree Not Expanded

```
❌ WRONG:
┌──────────────────┐
│ ▶ SCOLAIRE       │  ← Collapsed, looks empty
└──────────────────┘

✅ CORRECT:
┌──────────────────┐
│ ▼ SCOLAIRE (5,304)│ ← Expanded, shows count
│   ├─ Cahiers     │
│   └─ Classement  │
└──────────────────┘
```

### Reason 2: Wrong Locale Selected

```
❌ WRONG: Locale selector shows "de_DE" (inactive)
   → Categories have no German labels
   → Tree appears empty

✅ CORRECT: Locale selector shows "fr_FR", "en_US", or "ar_DZ"
   → Categories have labels
   → Tree shows properly
```

### Reason 3: Some Categories ARE Empty

```
These 31 categories have 0 products (by design):

• cat_2770, cat_919, cat_920, cat_2762, cat_2768
• cat_2769, cat_2771, cat_2772, cat_2773, cat_2774
• ... (and 21 more)

This is normal! Not all categories need products.
Main categories have thousands:
• Tous les produits: 8,687 products
• SCOLAIRE: 5,304 products
• LOISIRS CREATIFS: 4,302 products
```

---

## 📈 CURRENT DATA STATISTICS

### Overall Catalog Health

```
✅ Products: 9,538 total
   ├─ With product models: 7,019 (73.6%)
   └─ Standalone: 2,519 (26.4%)

✅ Product Models: 418 total
   └─ Average variants per model: ~17

✅ Categories: 166 total
   ├─ Empty: 31 (18.7%)
   └─ With products: 135 (81.3%)

✅ Data Quality:
   ├─ Products with categories: 100% (9,538)
   ├─ Products with price: 100% (9,538)
   ├─ Products with description: 96.07% (9,163)
   ├─ Products with name: 93.1% (8,880)
   └─ Products with images ready: 98.54% (9,399)

✅ Active Locales: 3
   └─ fr_FR, en_US, ar_DZ

✅ Active Channels: 3
   └─ ecommerce, jde_edwards, cegid_erp
```

### Top 10 Product Models by Variants

```
1. pm_cc31b86c758623ca → 705 variants
2. pm_6287997fe9a01043 → 658 variants
3. pm_a06e32d006424f45 → 341 variants
4. pm_e789597ad58901f3 → 286 variants
5. pm_0c39eb267a16260b → 225 variants
6. pm_f7523757ac88ef6c → 208 variants
7. pm_2c73a3eac555ca3d → 189 variants
8. pm_12ca259280f42d77 → 167 variants
9. pm_d85900ac0edce8d9 → 156 variants
10. pm_988f3fd5b1625770 → 145 variants
```

### Top 5 Categories by Products

```
1. Tous les produits → 8,687 products (91.1%)
2. SCOLAIRE → 5,304 products (55.6%)
3. LOISIRS CREATIFS → 4,302 products (45.1%)
4. BEAUX ARTS → 2,947 products (30.9%)
5. Promo Rentree Univ → 2,228 products (23.4%)
```

---

## ✅ FINAL VERIFICATION

### Checklist: Can You See Everything?

```
Login and verify you can see:

□ Product grid shows products (not empty)
□ Can see 9,538 products total
□ Category tree shows 166 categories
□ Can expand/collapse categories
□ Product model page shows 418 models
□ Can click model and see variants
□ Can filter by price
□ Can filter by images
□ Can filter by category
□ Can filter by completeness
□ Can switch channels (ecommerce, etc.)
□ Can switch locales (fr_FR, en_US, ar_DZ)

If all checked ✅ → Data grid is working perfectly!
```

---

## 🆘 STILL HAVING ISSUES?

### Quick Fixes

**1. Clear Browser Cache:**
- Chrome/Firefox: Ctrl + Shift + Delete
- Safari: Cmd + Option + E

**2. Clear Akeneo Cache:**
```bash
cd /home/pim/public_html/webapp
php bin/console cache:clear --env=prod
```

**3. Check Database:**
```bash
cd /home/pim/public_html/webapp
php CHECK_AKENEO_DATA_INSIGHTS.php
```

**4. Re-run Fix Script:**
```bash
cd /home/pim/public_html/webapp
php FIX_DATA_INSIGHTS.php
```

---

## 📞 ACCESS INFORMATION

**Akeneo PIM:**
- URL: https://pim.technostationery.com
- User: `apiconnector`
- Pass: `ApiConnector@2026!Secure`

**Direct URLs:**
- Product Grid: `https://pim.technostationery.com/#/enrich/product/`
- Product Models: `https://pim.technostationery.com/#/enrich/product-model/`
- Dashboard: `https://pim.technostationery.com/#/`

**Support Files:**
- Scripts: `/home/pim/public_html/webapp/`
- Logs: `/home/pim/public_html/webapp/*.log`
- Images: `/home/pim/public_html/public/media/product_images/`

---

**Last Updated:** 2026-04-29 19:40  
**Status:** ✅ All systems operational  
**Next Steps:** Import images & SEO metadata
