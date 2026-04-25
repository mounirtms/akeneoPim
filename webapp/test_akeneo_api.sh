#!/bin/bash

# Akeneo API Test Script
CLIENT_ID="3_4jr9m44ntl44ggg4cgkcsccgwscsgo44s4wg0ccc48w8gc0kkks"
CLIENT_SECRET="2myx2ccqwsowcko0k04woocgo4w0wk08gk8gkkgc0cwww88o44"
USERNAME="admin"
PASSWORD="Admin1234!"
BASE_URL="https://pim.technostationery.com"

echo "=== Akeneo REST API Test ==="
echo ""
echo "Step 1: Get Access Token..."
TOKEN_RESPONSE=$(curl -s -X POST "${BASE_URL}/api/oauth/v1/token" \
  -d "grant_type=password" \
  -d "client_id=${CLIENT_ID}" \
  -d "client_secret=${CLIENT_SECRET}" \
  -d "username=${USERNAME}" \
  -d "password=${PASSWORD}")

echo "$TOKEN_RESPONSE" | jq '.' 2>/dev/null || echo "$TOKEN_RESPONSE"

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token' 2>/dev/null)

if [ -z "$ACCESS_TOKEN" ] || [ "$ACCESS_TOKEN" == "null" ]; then
  echo "❌ Failed to get access token"
  exit 1
fi

echo ""
echo "✅ Access Token obtained: ${ACCESS_TOKEN:0:50}..."
echo ""
echo "Step 2: Test Products API (first 5 products)..."
curl -s -X GET "${BASE_URL}/api/rest/v1/products?limit=5" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" | jq '._embedded.items[].identifier' 2>/dev/null || echo "Response received"

echo ""
echo "Step 3: Get Product Count..."
TOTAL_PRODUCTS=$(curl -s -X GET "${BASE_URL}/api/rest/v1/products?limit=1" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" | jq '.items_count' 2>/dev/null)

echo "✅ Total Products Available: ${TOTAL_PRODUCTS:-'Unable to determine'}"
echo ""
echo "=== API Test Complete ==="
