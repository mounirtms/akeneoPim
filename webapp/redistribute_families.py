#!/usr/bin/env python3
"""
Family Redistribution Script
Moves products from 'default' family to appropriate families based on Magento attribute_set_id
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
print(" FAMILY REDISTRIBUTION - OPTIMIZING CATALOG")
print("=" * 80)
print(f"Started at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
print()

# Connect to databases
print("📡 Connecting to databases...")
magento_conn = pymysql.connect(**MAGENTO_CONFIG)
akeneo_conn = pymysql.connect(**AKENEO_CONFIG)
print("✅ Connected to both databases")
print()

# Phase 1: Get current family distribution in Akeneo
print("=" * 80)
print("PHASE 1: ANALYZING CURRENT FAMILY DISTRIBUTION")
print("=" * 80)

akeneo_cursor = akeneo_conn.cursor()
akeneo_cursor.execute("""
    SELECT 
        f.code as family_code,
        COUNT(p.id) as product_count
    FROM pim_catalog_product p
    LEFT JOIN pim_catalog_family f ON p.family_id = f.id
    GROUP BY f.code
    ORDER BY product_count DESC
""")

print("📊 Current Family Distribution:")
current_distribution = {}
for row in akeneo_cursor.fetchall():
    family = row[0] or 'NULL'
    count = row[1]
    current_distribution[family] = count
    print(f"   {family:20s}: {count:,} products")

print()
default_count = current_distribution.get('default', 0)
print(f"⚠️  Products in 'default' family: {default_count:,} ({default_count * 100 / 9538:.1f}%)")
print()

# Phase 2: Get Akeneo families
print("=" * 80)
print("PHASE 2: LOADING AKENEO FAMILIES")
print("=" * 80)

akeneo_cursor.execute("SELECT id, code FROM pim_catalog_family WHERE code != 'default'")
akeneo_families = {row[1]: row[0] for row in akeneo_cursor.fetchall()}
print(f"✅ Found {len(akeneo_families)} families (excluding 'default')")
print(f"   Available families: {', '.join(sorted(akeneo_families.keys()))}")
print()

# Phase 3: Build attribute set to family mapping
print("=" * 80)
print("PHASE 3: BUILDING ATTRIBUTE SET MAPPING")
print("=" * 80)

magento_cursor = magento_conn.cursor()

# Get Magento attribute sets
magento_cursor.execute("""
    SELECT 
        attribute_set_id,
        attribute_set_name
    FROM eav_attribute_set
    WHERE entity_type_id = 4
""")

attribute_sets = {}
for row in magento_cursor.fetchall():
    set_id = row[0]
    set_name = row[1].lower()
    attribute_sets[set_id] = set_name

print(f"✅ Found {len(attribute_sets)} Magento attribute sets")

# Map attribute sets to Akeneo families
# Strategy: Look for keywords in attribute set names
family_mapping = {}
for set_id, set_name in attribute_sets.items():
    mapped_family = 'products'  # Default fallback
    
    # Check for keyword matches
    if 'bag' in set_name or 'sac' in set_name:
        mapped_family = 'bags'
    elif 'notebook' in set_name or 'cahier' in set_name or 'carnet' in set_name:
        mapped_family = 'notebooks'
    elif 'office' in set_name or 'bureau' in set_name:
        mapped_family = 'office'
    elif 'art' in set_name or 'dessin' in set_name or 'peinture' in set_name:
        mapped_family = 'arts'
    elif 'writing' in set_name or 'pen' in set_name or 'pencil' in set_name or 'stylo' in set_name or 'crayon' in set_name:
        mapped_family = 'writing'
    elif 'paper' in set_name or 'papier' in set_name or 'papeterie' in set_name or 'stationery' in set_name:
        mapped_family = 'stationery'
    
    # Only use if family exists in Akeneo
    if mapped_family in akeneo_families:
        family_mapping[set_id] = mapped_family
    else:
        family_mapping[set_id] = 'products'  # Fallback to 'products'

print(f"✅ Mapped {len(family_mapping)} attribute sets to families")
print()
print("📋 Mapping Preview:")
for set_id, family in sorted(family_mapping.items(), key=lambda x: x[1])[:10]:
    set_name = attribute_sets.get(set_id, 'Unknown')
    print(f"   {set_name[:40]:40s} → {family}")
print()

# Phase 4: Get products in 'default' family and their Magento attribute sets
print("=" * 80)
print("PHASE 4: EXTRACTING PRODUCT DATA")
print("=" * 80)

# Get products in 'default' family
akeneo_cursor.execute("""
    SELECT p.identifier, p.id
    FROM pim_catalog_product p
    JOIN pim_catalog_family f ON p.family_id = f.id
    WHERE f.code = 'default'
""")

default_products = {row[0]: row[1] for row in akeneo_cursor.fetchall()}
print(f"✅ Found {len(default_products)} products in 'default' family")

# Get Magento attribute_set_id for these products
magento_cursor.execute("""
    SELECT sku, attribute_set_id
    FROM catalog_product_entity
    WHERE sku IN (%s)
""" % ','.join(['%s'] * len(default_products)), list(default_products.keys()))

product_attribute_sets = {row[0]: row[1] for row in magento_cursor.fetchall()}
print(f"✅ Matched {len(product_attribute_sets)} products with Magento data")
print()

# Phase 5: Redistribute products to appropriate families
print("=" * 80)
print("PHASE 5: REDISTRIBUTING PRODUCTS")
print("=" * 80)

redistributed = {}
no_mapping = 0
errors = 0

for sku, product_id in default_products.items():
    try:
        if sku not in product_attribute_sets:
            no_mapping += 1
            continue
        
        attribute_set_id = product_attribute_sets[sku]
        
        if attribute_set_id not in family_mapping:
            no_mapping += 1
            continue
        
        target_family = family_mapping[attribute_set_id]
        
        if target_family not in akeneo_families:
            no_mapping += 1
            continue
        
        target_family_id = akeneo_families[target_family]
        
        # Update product family
        akeneo_cursor.execute("""
            UPDATE pim_catalog_product
            SET family_id = %s, updated = NOW()
            WHERE id = %s
        """, (target_family_id, product_id))
        
        if target_family not in redistributed:
            redistributed[target_family] = 0
        redistributed[target_family] += 1
        
        if sum(redistributed.values()) % 100 == 0:
            akeneo_conn.commit()
            print(f"   Processed {sum(redistributed.values())} products...")
    
    except Exception as e:
        errors += 1
        if errors <= 5:
            print(f"⚠️  Error redistributing {sku}: {str(e)[:100]}")

# Final commit
akeneo_conn.commit()

# Get new family distribution
akeneo_cursor.execute("""
    SELECT 
        f.code as family_code,
        COUNT(p.id) as product_count
    FROM pim_catalog_product p
    LEFT JOIN pim_catalog_family f ON p.family_id = f.id
    GROUP BY f.code
    ORDER BY product_count DESC
""")

print()
print("=" * 80)
print(" FAMILY REDISTRIBUTION COMPLETE!")
print("=" * 80)
print()
print("📊 REDISTRIBUTION RESULTS:")
for family, count in sorted(redistributed.items(), key=lambda x: x[1], reverse=True):
    print(f"   {family:20s}: +{count:,} products")
print()
print(f"   Total Redistributed:   {sum(redistributed.values()):,} products")
print(f"   No Mapping Found:      {no_mapping:,} products")
print(f"   Errors:                {errors} products")
print()
print("📈 NEW FAMILY DISTRIBUTION:")
for row in akeneo_cursor.fetchall():
    family = row[0] or 'NULL'
    count = row[1]
    change = count - current_distribution.get(family, 0)
    change_str = f"(+{change})" if change > 0 else f"({change})" if change < 0 else ""
    print(f"   {family:20s}: {count:,} products {change_str}")

akeneo_cursor.close()
akeneo_conn.close()
magento_cursor.close()
magento_conn.close()

print()
print(f"✅ Completed at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
print("=" * 80)
