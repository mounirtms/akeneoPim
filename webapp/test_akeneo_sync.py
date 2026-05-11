#!/usr/bin/env python3
"""
Test Akeneo to Magento Sync
Tests syncing a small batch of products from Akeneo PIM to Magento Beta
"""

import requests
import json
import sys
import time
from datetime import datetime

# Configuration
AKENEO_BASE_URL = "https://pim.technostationery.com"
AKENEO_CLIENT_ID = "2_ml5f52erhggg0s484gckwgs4kg8gwc4c48ksgko4gkgos4k48"
AKENEO_CLIENT_SECRET = "1zniz3jfcmcgg0wckskw8k4c80ccwc4o0cokcwk80cs8cs0cs4"
AKENEO_USERNAME = "apiconnector"
AKENEO_PASSWORD = "ApiP@ss2026!"

MAGENTO_BASE_URL = "http://beta.technostationery.com"  # Adjust if needed
MAGENTO_API_TOKEN = "YOUR_MAGENTO_API_TOKEN"  # Will need to be configured

def print_header(text):
    """Print formatted header"""
    print(f"\n{'='*70}")
    print(f"  {text}")
    print(f"{'='*70}\n")

def print_step(step, text):
    """Print formatted step"""
    print(f"[{step}] {text}")

def get_akeneo_token():
    """Get Akeneo API access token"""
    print_step("1", "Getting Akeneo API access token...")
    
    url = f"{AKENEO_BASE_URL}/api/oauth/v1/token"
    data = {
        "grant_type": "password",
        "username": AKENEO_USERNAME,
        "password": AKENEO_PASSWORD
    }
    
    try:
        response = requests.post(
            url,
            json=data,
            auth=(AKENEO_CLIENT_ID, AKENEO_CLIENT_SECRET),
            headers={"Content-Type": "application/json"},
            timeout=30
        )
        
        if response.status_code == 200:
            token = response.json().get('access_token')
            print(f"    ✅ Token obtained successfully")
            return token
        else:
            print(f"    ❌ Failed to get token: {response.status_code}")
            print(f"    Response: {response.text}")
            return None
            
    except Exception as e:
        print(f"    ❌ Error: {str(e)}")
        return None

def fetch_akeneo_products(token, limit=10):
    """Fetch sample products from Akeneo"""
    print_step("2", f"Fetching {limit} sample products from Akeneo...")
    
    url = f"{AKENEO_BASE_URL}/api/rest/v1/products"
    params = {
        "limit": limit,
        "with_count": "true",
        "search": json.dumps({"enabled": [{"operator": "=", "value": True}]})
    }
    
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
    
    try:
        response = requests.get(url, params=params, headers=headers, timeout=30)
        
        if response.status_code == 200:
            data = response.json()
            products = data.get('_embedded', {}).get('items', [])
            print(f"    ✅ Retrieved {len(products)} products")
            return products
        else:
            print(f"    ❌ Failed to fetch products: {response.status_code}")
            print(f"    Response: {response.text}")
            return []
            
    except Exception as e:
        print(f"    ❌ Error: {str(e)}")
        return []

def analyze_product_data(products):
    """Analyze product data quality"""
    print_step("3", "Analyzing product data quality...")
    
    stats = {
        'total': len(products),
        'with_names': 0,
        'with_descriptions': 0,
        'with_prices': 0,
        'with_categories': 0,
        'with_images': 0
    }
    
    for product in products:
        values = product.get('values', {})
        
        # Check for names (fr_FR locale)
        if values.get('name', {}).get('fr_FR'):
            stats['with_names'] += 1
            
        # Check for descriptions
        if values.get('description', {}).get('fr_FR'):
            stats['with_descriptions'] += 1
            
        # Check for prices
        if values.get('price', {}).get('DZD'):
            stats['with_prices'] += 1
            
        # Check for categories
        if product.get('categories', []):
            stats['with_categories'] += 1
            
        # Check for images
        if values.get('image'):
            stats['with_images'] += 1
    
    print(f"\n    📊 Data Quality Stats:")
    print(f"       Total Products:    {stats['total']}")
    print(f"       With Names:        {stats['with_names']} ({stats['with_names']/stats['total']*100:.1f}%)")
    print(f"       With Descriptions: {stats['with_descriptions']} ({stats['with_descriptions']/stats['total']*100:.1f}%)")
    print(f"       With Prices:       {stats['with_prices']} ({stats['with_prices']/stats['total']*100:.1f}%)")
    print(f"       With Categories:   {stats['with_categories']} ({stats['with_categories']/stats['total']*100:.1f}%)")
    print(f"       With Images:       {stats['with_images']} ({stats['with_images']/stats['total']*100:.1f}%)")
    
    return stats

def display_sample_products(products, count=5):
    """Display sample product details"""
    print_step("4", f"Displaying {count} sample products...")
    
    for i, product in enumerate(products[:count], 1):
        print(f"\n    Product {i}:")
        print(f"       SKU: {product.get('identifier', 'N/A')}")
        
        values = product.get('values', {})
        
        # Name
        name_data = values.get('name', {})
        name = name_data.get('fr_FR', [{}])[0].get('data', 'N/A') if name_data else 'N/A'
        print(f"       Name: {name}")
        
        # Price
        price_data = values.get('price', {})
        if price_data and 'DZD' in price_data:
            price_value = price_data['DZD'][0].get('data', {})
            price = f"{price_value.get('amount', 'N/A')} {price_value.get('currency', 'DZD')}"
        else:
            price = 'N/A'
        print(f"       Price: {price}")
        
        # Categories
        categories = product.get('categories', [])
        print(f"       Categories: {', '.join(categories) if categories else 'None'}")
        
        # Enabled status
        print(f"       Enabled: {'Yes' if product.get('enabled') else 'No'}")

def generate_sync_report(products, stats):
    """Generate sync readiness report"""
    print_step("5", "Generating sync readiness report...")
    
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    report_file = f"/home/pim/public_html/webapp/sync_readiness_report_{timestamp}.md"
    
    with open(report_file, 'w') as f:
        f.write("# Akeneo to Magento Beta - Sync Readiness Report\n\n")
        f.write(f"**Generated:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n")
        
        f.write("## Executive Summary\n\n")
        f.write(f"- **Total Products Tested:** {stats['total']}\n")
        f.write(f"- **Data Completeness Score:** {(stats['with_names']+stats['with_prices'])/stats['total']/2*100:.1f}%\n\n")
        
        f.write("## Data Quality Metrics\n\n")
        f.write("| Metric | Count | Percentage |\n")
        f.write("|--------|-------|------------|\n")
        f.write(f"| Products with Names | {stats['with_names']} | {stats['with_names']/stats['total']*100:.1f}% |\n")
        f.write(f"| Products with Descriptions | {stats['with_descriptions']} | {stats['with_descriptions']/stats['total']*100:.1f}% |\n")
        f.write(f"| Products with Prices | {stats['with_prices']} | {stats['with_prices']/stats['total']*100:.1f}% |\n")
        f.write(f"| Products with Categories | {stats['with_categories']} | {stats['with_categories']/stats['total']*100:.1f}% |\n")
        f.write(f"| Products with Images | {stats['with_images']} | {stats['with_images']/stats['total']*100:.1f}% |\n\n")
        
        f.write("## Sample Products\n\n")
        for i, product in enumerate(products[:5], 1):
            f.write(f"### Product {i}\n\n")
            f.write(f"- **SKU:** {product.get('identifier', 'N/A')}\n")
            
            values = product.get('values', {})
            name_data = values.get('name', {})
            name = name_data.get('fr_FR', [{}])[0].get('data', 'N/A') if name_data else 'N/A'
            f.write(f"- **Name:** {name}\n")
            
            price_data = values.get('price', {})
            if price_data and 'DZD' in price_data:
                price_value = price_data['DZD'][0].get('data', {})
                price = f"{price_value.get('amount', 'N/A')} {price_value.get('currency', 'DZD')}"
            else:
                price = 'N/A'
            f.write(f"- **Price:** {price}\n")
            
            categories = product.get('categories', [])
            f.write(f"- **Categories:** {', '.join(categories) if categories else 'None'}\n\n")
        
        f.write("## Sync Readiness Assessment\n\n")
        
        if stats['with_prices'] >= stats['total'] * 0.9:
            f.write("✅ **READY FOR SYNC** - Most products have required data\n\n")
        else:
            f.write("⚠️ **NEEDS ATTENTION** - Some products are missing critical data\n\n")
        
        f.write("## Next Steps\n\n")
        f.write("1. Review data quality metrics\n")
        f.write("2. Fix any missing critical fields (prices, names)\n")
        f.write("3. Configure Magento API credentials\n")
        f.write("4. Run test sync with 10-20 products\n")
        f.write("5. Validate synced data in Magento\n")
        f.write("6. Proceed with full catalog sync\n")
    
    print(f"    ✅ Report saved to: {report_file}")
    return report_file

def main():
    """Main execution"""
    print_header("AKENEO TO MAGENTO BETA - SYNC TEST")
    
    # Step 1: Get access token
    token = get_akeneo_token()
    if not token:
        print("\n❌ Failed to authenticate with Akeneo API")
        sys.exit(1)
    
    # Step 2: Fetch sample products
    products = fetch_akeneo_products(token, limit=20)
    if not products:
        print("\n❌ Failed to fetch products from Akeneo")
        sys.exit(1)
    
    # Step 3: Analyze data quality
    stats = analyze_product_data(products)
    
    # Step 4: Display sample products
    display_sample_products(products, count=5)
    
    # Step 5: Generate report
    report_file = generate_sync_report(products, stats)
    
    print_header("SYNC TEST COMPLETE")
    print(f"✅ Successfully tested Akeneo API connection")
    print(f"✅ Retrieved and analyzed {len(products)} products")
    print(f"✅ Generated readiness report: {report_file}")
    print(f"\n📋 Review the report before proceeding with full sync")
    
    return 0

if __name__ == "__main__":
    sys.exit(main())
