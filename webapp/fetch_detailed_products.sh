#!/bin/bash

# Get OAuth token
echo "Getting OAuth token..."
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

if [ -z "$ACCESS_TOKEN" ]; then
  echo "Failed to get access token"
  exit 1
fi

echo "✅ Token obtained"
echo ""

# Fetch products with attributes parameter
echo "Fetching detailed products with all attributes..."
curl -s -X GET "https://pim.technostationery.com/api/rest/v1/products?limit=5&with_attribute_options=true" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" > detailed_products.json

echo "✅ Saved to detailed_products.json"
echo ""

# Check what we got
echo "Sample product structure:"
cat detailed_products.json | python3 -m json.tool | head -80
