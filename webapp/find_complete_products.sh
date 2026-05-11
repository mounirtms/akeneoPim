#!/bin/bash

# Get OAuth token
TOKEN_RESPONSE=$(curl -s -X POST "https://pim.technostationery.com/api/oauth/v1/token" \
  -H "Content-Type: application/json" \
  -d '{
    "grant_type": "password",
    "client_id": "3_4jr9m44ntl44ggg4cgkcsccgwscsgo44s4wg0ccc48w8gc0kkk",
    "client_secret": "2myx2ccqwsowcko0k04woocgo4w0wk08gk8gkkgc0cwww88o44",
    "username": "admin",
    "password": "Admin1234!"
  }')

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)

echo "Searching for products with complete data..."
echo ""

# Fetch larger sample to find products with more data
curl -s -X GET "https://pim.technostationery.com/api/rest/v1/products?limit=50" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" > products_50.json

python3 << 'PYEOF'
import json

with open('products_50.json', 'r') as f:
    data = json.load(f)

products = data.get('_embedded', {}).get('items', [])

print(f"Analyzing {len(products)} products...\n")

# Find products with different attribute counts
attr_distribution = {}
products_by_attr_count = {}

for product in products:
    values = product.get('values', {})
    attr_count = len(values)
    
    if attr_count not in attr_distribution:
        attr_distribution[attr_count] = 0
        products_by_attr_count[attr_count] = []
    
    attr_distribution[attr_count] += 1
    if len(products_by_attr_count[attr_count]) < 3:  # Keep first 3 examples
        products_by_attr_count[attr_count].append({
            'identifier': product.get('identifier'),
            'attributes': list(values.keys())
        })

print("Attribute distribution:")
for count in sorted(attr_distribution.keys(), reverse=True):
    print(f"  {count} attributes: {attr_distribution[count]} products")
    if count > 0:
        print(f"    Examples: {[p['identifier'] for p in products_by_attr_count[count]]}")
        if products_by_attr_count[count]:
            print(f"    Attrs: {products_by_attr_count[count][0]['attributes'][:10]}")
    print()

# Check for name and price attributes
products_with_name = []
products_with_price = []

for product in products:
    values = product.get('values', {})
    
    if 'name' in values:
        products_with_name.append(product.get('identifier'))
    
    if 'price' in values:
        products_with_price.append(product.get('identifier'))

print(f"\n📊 Summary:")
print(f"  Products with 'name' attribute: {len(products_with_name)}")
if products_with_name:
    print(f"    Examples: {products_with_name[:5]}")

print(f"  Products with 'price' attribute: {len(products_with_price)}")
if products_with_price:
    print(f"    Examples: {products_with_price[:5]}")

# Find product with most attributes
if products:
    richest_product = max(products, key=lambda p: len(p.get('values', {})))
    print(f"\n🏆 Product with most attributes:")
    print(f"  Identifier: {richest_product.get('identifier')}")
    print(f"  Attributes: {len(richest_product.get('values', {}))}")
    print(f"  Keys: {list(richest_product.get('values', {}).keys())}")
PYEOF
