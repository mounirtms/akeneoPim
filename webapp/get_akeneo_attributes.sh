#!/bin/bash

# Get Akeneo Attributes Script
CLIENT_ID="3_4jr9m44ntl44ggg4cgkcsccgwscsgo44s4wg0ccc48w8gc0kkk"
CLIENT_SECRET="2myx2ccqwsowcko0k04woocgo4w0wk08gk8gkkgc0cwww88o44"
USERNAME="admin"
PASSWORD="Admin1234!"
BASE_URL="https://pim.technostationery.com"

echo "=== Akeneo Attribute Extraction ==="
echo ""

# Get access token
echo "Getting access token..."
TOKEN_RESPONSE=$(curl -s -X POST "${BASE_URL}/api/oauth/v1/token" \
  -d "grant_type=password" \
  -d "client_id=${CLIENT_ID}" \
  -d "client_secret=${CLIENT_SECRET}" \
  -d "username=${USERNAME}" \
  -d "password=${PASSWORD}")

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token')

if [ -z "$ACCESS_TOKEN" ] || [ "$ACCESS_TOKEN" == "null" ]; then
  echo "❌ Failed to get access token"
  echo "$TOKEN_RESPONSE"
  exit 1
fi

echo "✓ Access token obtained"
echo ""

# Get families
echo "Fetching families..."
curl -s -X GET "${BASE_URL}/api/rest/v1/families" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" | jq '.' > families.json
echo "✓ Families saved to families.json"

# Get attributes
echo "Fetching attributes..."
curl -s -X GET "${BASE_URL}/api/rest/v1/attributes?limit=100" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" | jq '.' > attributes.json
echo "✓ Attributes saved to attributes.json"

# Get categories
echo "Fetching categories..."
curl -s -X GET "${BASE_URL}/api/rest/v1/categories" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" | jq '.' > categories.json
echo "✓ Categories saved to categories.json"

# Get channels
echo "Fetching channels..."
curl -s -X GET "${BASE_URL}/api/rest/v1/channels" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" | jq '.' > channels.json
echo "✓ Channels saved to channels.json"

# Get locales
echo "Fetching locales..."
curl -s -X GET "${BASE_URL}/api/rest/v1/locales" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" | jq '.' > locales.json
echo "✓ Locales saved to locales.json"

# Get sample products
echo "Fetching sample products (10)..."
curl -s -X GET "${BASE_URL}/api/rest/v1/products?limit=10" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" | jq '.' > sample_products.json
echo "✓ Sample products saved to sample_products.json"

echo ""
echo "=== Extraction Complete ==="
echo ""
echo "Files created:"
ls -lh families.json attributes.json categories.json channels.json locales.json sample_products.json
