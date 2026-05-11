#!/usr/bin/env python3
"""
Category Assignment Script
Assigns 928 products without categories to appropriate categories based on Magento data
"""

import pymysql
import json
import sys
from datetime import datetime

# Configuration
MAGENTO_CONFIG = {
    'host': '127.0.0.1',
    'port': 3307,
    'user': 'root',
    'password': 'YourNewStrongPassword',
    'database': 'beta_dBT8x12y22',
    'charset': 'utf8mb4'
}

AKENEO_CONFIG = {
    'host': '127.0.0.1',
    'port': 3307,
    'user': 'akeneo_pim',
    'password': 'akeneo_pim',
    'database': 'akeneo_pim',
    'charset': 'utf8mb4'
}

print("=" * 80)
print(" CATEGORY ASSIGNMENT - COMPLETING CATALOG")
print("=" * 80)
print(f"Started at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
print()

# Connect to databases
print("📡 Connecting to databases...")
magento_conn = pymysql.connect(**MAGENTO_CONFIG)
akeneo_conn = pymysql.connect(**AKENEO_CONFIG)
print("✅ Connected to both databases")
print()

# Phase 1: Find products without categories in Akeneo
print("=" * 80)
print("PHASE 1: FINDING PRODUCTS WITHOUT CATEGORIES")
print("=" * 80)

akeneo_cursor = akeneo_conn.cursor()
akeneo_cursor.execute("""
    SELECT p.identifier, p.id
    FROM pim_catalog_product p
    LEFT JOIN pim_catalog_category_product cp ON p.id = cp.product_id
    WHERE cp.product_id IS NULL
""")

products_without_cats = {row[0]: row[1] for row in akeneo_cursor.fetchall()}
print(f"✅ Found {len(products_without_cats)} products without categories")
print()

if len(products_without_cats) == 0:
    print("🎉 All products already have categories!")
    akeneo_cursor.close()
    akeneo_conn.close()
    magento_conn.close()
    sys.exit(0)

# Phase 2: Get category mappings from Magento
print("=" * 80)
print("PHASE 2: EXTRACTING CATEGORY MAPPINGS FROM MAGENTO")
print("=" * 80)

magento_cursor = magento_conn.cursor()

# Get Magento category mappings
magento_cursor.execute("""
    SELECT 
        p.sku,
        GROUP_CONCAT(DISTINCT cp.category_id) as category_ids
    FROM catalog_product_entity p
    JOIN catalog_category_product cp ON p.entity_id = cp.product_id
    WHERE p.sku IN (%s)
    GROUP BY p.sku
""" % ','.join(['%s'] * len(products_without_cats)), list(products_without_cats.keys()))

magento_category_mappings = {row[0]: row[1].split(',') if row[1] else [] for row in magento_cursor.fetchall()}
print(f"✅ Extracted category mappings for {len(magento_category_mappings)} products")
print()

# Phase 3: Build category code mapping (Magento ID -> Akeneo code)
print("=" * 80)
print("PHASE 3: BUILDING CATEGORY MAPPING")
print("=" * 80)

# Get all Akeneo categories
akeneo_cursor.execute("SELECT id, code FROM pim_catalog_category")
akeneo_categories = {row[1]: row[0] for row in akeneo_cursor.fetchall()}

# Build mapping from Magento category names to Akeneo codes
magento_cursor.execute("""
    SELECT 
        ce.entity_id,
        v.value as name
    FROM catalog_category_entity ce
    JOIN catalog_category_entity_varchar v ON ce.entity_id = v.entity_id
    JOIN eav_attribute a ON v.attribute_id = a.attribute_id
    WHERE a.attribute_code = 'name' 
      AND a.entity_type_id = 3
      AND v.store_id = 0
""")

magento_cat_names = {str(row[0]): row[1] for row in magento_cursor.fetchall()}

# Create mapping: Magento category ID -> Akeneo category ID
def slugify(text):
    import re
    text = text.lower()
    text = re.sub(r'[àáâãäå]', 'a', text)
    text = re.sub(r'[èéêë]', 'e', text)
    text = re.sub(r'[ìíîï]', 'i', text)
    text = re.sub(r'[òóôõö]', 'o', text)
    text = re.sub(r'[ùúûü]', 'u', text)
    text = re.sub(r'[^a-z0-9\s-]', '', text)
    text = re.sub(r'[\s_]+', '_', text)
    return text.strip('_')[:90]

magento_to_akeneo = {}
for mag_id, mag_name in magento_cat_names.items():
    # Try to find matching Akeneo category by code
    code_variants = [
        slugify(mag_name),
        f"cat_{mag_id}",
        slugify(mag_name)[:50]
    ]
    
    for code in code_variants:
        if code in akeneo_categories:
            magento_to_akeneo[mag_id] = akeneo_categories[code]
            break

print(f"✅ Mapped {len(magento_to_akeneo)} Magento categories to Akeneo")
print()

# Phase 4: Assign categories to products
print("=" * 80)
print("PHASE 4: ASSIGNING CATEGORIES TO PRODUCTS")
print("=" * 80)

assigned_count = 0
no_mapping_count = 0
error_count = 0

for sku, product_id in products_without_cats.items():
    try:
        if sku not in magento_category_mappings:
            no_mapping_count += 1
            continue
        
        magento_cat_ids = magento_category_mappings[sku]
        akeneo_cat_ids = []
        
        for mag_cat_id in magento_cat_ids:
            if mag_cat_id in magento_to_akeneo:
                akeneo_cat_ids.append(magento_to_akeneo[mag_cat_id])
        
        if not akeneo_cat_ids:
            no_mapping_count += 1
            continue
        
        # Insert category links
        for cat_id in akeneo_cat_ids:
            try:
                akeneo_cursor.execute("""
                    INSERT IGNORE INTO pim_catalog_category_product (product_id, category_id)
                    VALUES (%s, %s)
                """, (product_id, cat_id))
            except Exception as e:
                pass
        
        assigned_count += 1
        
        if assigned_count % 100 == 0:
            akeneo_conn.commit()
            print(f"   Processed {assigned_count} products...")
    
    except Exception as e:
        error_count += 1
        if error_count <= 5:
            print(f"⚠️  Error assigning categories for {sku}: {str(e)[:100]}")

# Final commit
akeneo_conn.commit()

# Get final statistics
akeneo_cursor.execute("""
    SELECT COUNT(DISTINCT product_id) 
    FROM pim_catalog_category_product
""")
products_with_cats = akeneo_cursor.fetchone()[0]

akeneo_cursor.execute("SELECT COUNT(*) FROM pim_catalog_category_product")
total_links = akeneo_cursor.fetchone()[0]

akeneo_cursor.close()
akeneo_conn.close()
magento_cursor.close()
magento_conn.close()

print()
print("=" * 80)
print(" CATEGORY ASSIGNMENT COMPLETE!")
print("=" * 80)
print()
print("📊 RESULTS:")
print(f"   Categories Assigned:   {assigned_count} products")
print(f"   No Mapping Found:      {no_mapping_count} products")
print(f"   Errors:                {error_count} products")
print()
print("📈 FINAL STATISTICS:")
print(f"   Products in Categories:  {products_with_cats} / 9,538 ({products_with_cats * 100 / 9538:.1f}%)")
print(f"   Total Category Links:    {total_links}")
print(f"   Improvement:             +{assigned_count} products with categories")
print()
print(f"✅ Completed at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
print("=" * 80)
