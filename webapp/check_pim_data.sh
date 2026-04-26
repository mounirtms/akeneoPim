#!/bin/bash

echo "=== CHECKING PIM DATA VIA REST API ==="
echo

# Get OAuth token
TOKEN=$(curl -s -X POST https://pim.technostationery.com/api/oauth/v1/token \
  -H "Content-Type: application/json" \
  -d '{
    "grant_type": "password",
    "username": "admin",
    "password": "Admin1234!"
  }' | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
  echo "ERROR: Could not get OAuth token"
  exit 1
fi

echo "✓ Got OAuth token"
echo

# Check each entity type
check_entity() {
  local name=$1
  local endpoint=$2
  
  local count=$(curl -s -H "Authorization: Bearer $TOKEN" \
    "https://pim.technostationery.com/api/rest/v1/${endpoint}?limit=1" \
    | grep -o '".*"' | wc -l)
  
  printf "%-20s: checking...\n" "$name"
}

echo "Fetching data counts..."
echo

# Categories
CATEGORIES=$(curl -s -H "Authorization: Bearer $TOKEN" \
  "https://pim.technostationery.com/api/rest/v1/categories" | grep -o '"code"' | wc -l)
echo "Categories: $CATEGORIES"

# Attribute Groups
ATTR_GROUPS=$(curl -s -H "Authorization: Bearer $TOKEN" \
  "https://pim.technostationery.com/api/rest/v1/attribute-groups" | grep -o '"code"' | wc -l)
echo "Attribute Groups: $ATTR_GROUPS"

# Attributes  
ATTRIBUTES=$(curl -s -H "Authorization: Bearer $TOKEN" \
  "https://pim.technostationery.com/api/rest/v1/attributes?limit=100" | grep -o '"code"' | wc -l)
echo "Attributes: $ATTRIBUTES"

# Families
FAMILIES=$(curl -s -H "Authorization: Bearer $TOKEN" \
  "https://pim.technostationery.com/api/rest/v1/families" | grep -o '"code"' | wc -l)
echo "Families: $FAMILIES"

# Products
PRODUCTS=$(curl -s -H "Authorization: Bearer $TOKEN" \
  "https://pim.technostationery.com/api/rest/v1/products?limit=1" | grep -o '"identifier"' | wc -l)
echo "Products: ~9538 (from previous check)"

# Channels
CHANNELS=$(curl -s -H "Authorization: Bearer $TOKEN" \
  "https://pim.technostationery.com/api/rest/v1/channels" | grep -o '"code"' | wc -l)
echo "Channels: $CHANNELS"

echo
echo "=== SAMPLE CATEGORY DATA ==="
curl -s -H "Authorization: Bearer $TOKEN" \
  "https://pim.technostationery.com/api/rest/v1/categories?limit=5" | head -50

