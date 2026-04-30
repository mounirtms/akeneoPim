#!/usr/bin/env python3.9
"""
Direct Price Import Script - Python Version
Imports prices directly into Akeneo raw_values JSON column
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
print(" DIRECT PRICE IMPORT - PYTHON VERSION")
print("=" * 80)
print(f"Started at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
print()

# Connect to databases
print("📡 Connecting to databases...")
magento_conn = pymysql.connect(**MAGENTO_CONFIG)
akeneo_conn = pymysql.connect(**AKENEO_CONFIG)
print("✅ Connected to both databases")
print()

# Phase 1: Extract prices from Magento
print("=" * 80)
print("PHASE 1: EXTRACTING PRICES FROM MAGENTO")
print("=" * 80)

magento_cursor = magento_conn.cursor()
magento_cursor.execute("""
    SELECT 
        p.sku,
        ea.attribute_code,
        d.value
    FROM catalog_product_entity p
    JOIN catalog_product_entity_decimal d ON p.entity_id = d.entity_id
    JOIN eav_attribute ea ON d.attribute_id = ea.attribute_id
    WHERE ea.entity_type_id = 4
      AND ea.attribute_code IN ('price', 'special_price', 'cost', 'weight', 'msrp')
      AND d.store_id = 0
      AND p.sku IS NOT NULL
      AND p.sku != ''
    ORDER BY p.sku, ea.attribute_code
""")

# Build product data structure
products = {}
for sku, attr_code, value in magento_cursor:
    if sku not in products:
        products[sku] = {}
    products[sku][attr_code] = float(value)

magento_cursor.close()
magento_conn.close()

print(f"✅ Extracted data for {len(products)} products")
print(f"   Total records: {len(products) * 2} (avg)")
print()

# Phase 2: Update Akeneo products
print("=" * 80)
print("PHASE 2: UPDATING AKENEO PRODUCTS")
print("=" * 80)

akeneo_cursor = akeneo_conn.cursor()

# Get current statistics
akeneo_cursor.execute("SELECT COUNT(*) FROM pim_catalog_product WHERE raw_values LIKE '%\"price\"%'")
before_prices = akeneo_cursor.fetchone()[0]
print(f"📊 Before: {before_prices} products with prices")
print()

updated_count = 0
skipped_count = 0
error_count = 0

print("🔄 Processing products...")
for i, (sku, attrs) in enumerate(products.items(), 1):
    try:
        # Get current raw_values
        akeneo_cursor.execute(
            "SELECT raw_values FROM pim_catalog_product WHERE identifier = %s",
            (sku,)
        )
        result = akeneo_cursor.fetchone()
        
        if not result:
            skipped_count += 1
            continue
        
        raw_values = json.loads(result[0]) if result[0] else {}
        
        # Update price
        if 'price' in attrs:
            raw_values['price'] = [{
                "locale": None,
                "scope": None,
                "data": [{"amount": str(attrs['price']), "currency": "DZD"}]
            }]
        
        # Update special_price
        if 'special_price' in attrs:
            raw_values['special_price'] = [{
                "locale": None,
                "scope": None,
                "data": [{"amount": str(attrs['special_price']), "currency": "DZD"}]
            }]
        
        # Update cost
        if 'cost' in attrs:
            raw_values['cost'] = [{
                "locale": None,
                "scope": None,
                "data": [{"amount": str(attrs['cost']), "currency": "DZD"}]
            }]
        
        # Update weight (convert kg to grams)
        if 'weight' in attrs:
            raw_values['weight'] = [{
                "locale": None,
                "scope": None,
                "data": {"amount": str(attrs['weight'] * 1000), "unit": "GRAM"}
            }]
        
        # Update MSRP
        if 'msrp' in attrs:
            raw_values['msrp'] = [{
                "locale": None,
                "scope": None,
                "data": [{"amount": str(attrs['msrp']), "currency": "DZD"}]
            }]
        
        # Save updated values
        akeneo_cursor.execute(
            "UPDATE pim_catalog_product SET raw_values = %s, updated = NOW() WHERE identifier = %s",
            (json.dumps(raw_values), sku)
        )
        updated_count += 1
        
        # Commit every 100 products
        if i % 100 == 0:
            akeneo_conn.commit()
            print(f"   Processed {i} / {len(products)} products... ({updated_count} updated)")
    
    except Exception as e:
        error_count += 1
        if error_count <= 5:
            print(f"⚠️  Error updating {sku}: {str(e)[:100]}")

# Final commit
akeneo_conn.commit()

# Get final statistics
akeneo_cursor.execute("SELECT COUNT(*) FROM pim_catalog_product WHERE raw_values LIKE '%\"price\"%'")
after_prices = akeneo_cursor.fetchone()[0]

akeneo_cursor.execute("SELECT COUNT(*) FROM pim_catalog_product WHERE raw_values LIKE '%\"weight\"%'")
after_weights = akeneo_cursor.fetchone()[0]

akeneo_cursor.execute("SELECT COUNT(*) FROM pim_catalog_product WHERE raw_values LIKE '%\"special_price\"%'")
special_prices = akeneo_cursor.fetchone()[0]

akeneo_cursor.close()
akeneo_conn.close()

print()
print("=" * 80)
print(" IMPORT COMPLETE!")
print("=" * 80)
print()
print("📊 RESULTS:")
print(f"   Updated: {updated_count} products")
print(f"   Skipped: {skipped_count} products (not found in Akeneo)")
print(f"   Errors:  {error_count} products")
print()
print("📈 STATISTICS:")
print(f"   Products with Prices:        {after_prices} / 9,538 ({after_prices * 100 / 9538:.1f}%)")
print(f"   Products with Weights:       {after_weights} / 9,538 ({after_weights * 100 / 9538:.1f}%)")
print(f"   Products with Special Price: {special_prices}")
print(f"   Price Improvement:           +{after_prices - before_prices} products")
print()
print(f"✅ Completed at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
print("=" * 80)
