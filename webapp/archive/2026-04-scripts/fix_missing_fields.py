#!/usr/bin/env python3
"""
Fix Missing Fields - Phase 2
Import missing names, descriptions, and weights from Magento to Akeneo
"""

import pymysql
import json
import sys
from datetime import datetime
from typing import Dict, List, Optional

# Configuration
AKENEO_DB_CONFIG = {
    'host': '127.0.0.1',
    'port': 3307,
    'user': 'akeneo_pim',
    'password': 'akeneo_pim',
    'database': 'akeneo_pim',
    'charset': 'utf8mb4'
}

MAGENTO_DB_CONFIG = {
    'host': '127.0.0.1',
    'port': 3307,
    'user': 'root',
    'password': 'YourNewStrongPassword',
    'database': 'beta_dBT8x12y22',
    'charset': 'utf8mb4'
}

BATCH_SIZE = 100
LOG_FILE = f'/home/pim/public_html/webapp/fix_missing_fields_{datetime.now().strftime("%Y%m%d_%H%M%S")}.log'

class FieldFixer:
    def __init__(self):
        self.akeneo_conn = None
        self.magento_conn = None
        self.log_messages = []
        self.stats = {
            'names_added': 0,
            'descriptions_added': 0,
            'weights_added': 0,
            'errors': 0
        }
    
    def log(self, message: str, level: str = 'INFO'):
        """Log message to console and file"""
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        log_entry = f"[{timestamp}] [{level}] {message}"
        print(log_entry)
        self.log_messages.append(log_entry)
    
    def save_log(self):
        """Save log to file"""
        with open(LOG_FILE, 'w', encoding='utf-8') as f:
            f.write('\n'.join(self.log_messages))
        self.log(f"Log saved to: {LOG_FILE}")
    
    def connect_databases(self):
        """Connect to both Akeneo and Magento databases"""
        try:
            self.log("Connecting to Akeneo database...")
            self.akeneo_conn = pymysql.connect(**AKENEO_DB_CONFIG)
            self.log("✅ Connected to Akeneo")
            
            self.log("Connecting to Magento database...")
            self.magento_conn = pymysql.connect(**MAGENTO_DB_CONFIG)
            self.log("✅ Connected to Magento")
            
            return True
        except Exception as e:
            self.log(f"❌ Database connection error: {e}", 'ERROR')
            return False
    
    def get_products_missing_names(self) -> List[Dict]:
        """Get products without names from Akeneo"""
        cursor = self.akeneo_conn.cursor(pymysql.cursors.DictCursor)
        cursor.execute("""
            SELECT id, identifier, raw_values 
            FROM pim_catalog_product 
            WHERE raw_values NOT LIKE '%"name"%'
        """)
        products = cursor.fetchall()
        cursor.close()
        self.log(f"Found {len(products)} products without names")
        return products
    
    def get_products_missing_descriptions(self) -> List[Dict]:
        """Get products without descriptions from Akeneo"""
        cursor = self.akeneo_conn.cursor(pymysql.cursors.DictCursor)
        cursor.execute("""
            SELECT id, identifier, raw_values 
            FROM pim_catalog_product 
            WHERE raw_values NOT LIKE '%"description"%'
        """)
        products = cursor.fetchall()
        cursor.close()
        self.log(f"Found {len(products)} products without descriptions")
        return products
    
    def get_products_missing_weights(self) -> List[Dict]:
        """Get products without weights from Akeneo"""
        cursor = self.akeneo_conn.cursor(pymysql.cursors.DictCursor)
        cursor.execute("""
            SELECT id, identifier, raw_values 
            FROM pim_catalog_product 
            WHERE raw_values NOT LIKE '%"weight"%'
        """)
        products = cursor.fetchall()
        cursor.close()
        self.log(f"Found {len(products)} products without weights")
        return products
    
    def get_magento_product_data(self, skus: List[str]) -> Dict:
        """Get product names, descriptions, and weights from Magento"""
        if not skus:
            return {}
        
        cursor = self.magento_conn.cursor(pymysql.cursors.DictCursor)
        
        # Get attribute IDs
        cursor.execute("""
            SELECT attribute_id, attribute_code 
            FROM eav_attribute 
            WHERE attribute_code IN ('name', 'description', 'short_description', 'weight')
            AND entity_type_id = (SELECT entity_type_id FROM eav_entity_type WHERE entity_type_code = 'catalog_product')
        """)
        attributes = {row['attribute_code']: row['attribute_id'] for row in cursor.fetchall()}
        
        sku_list = ','.join([f"'{sku}'" for sku in skus])
        
        # Get product entity IDs
        cursor.execute(f"""
            SELECT entity_id, sku 
            FROM catalog_product_entity 
            WHERE sku IN ({sku_list})
        """)
        entities = {row['sku']: row['entity_id'] for row in cursor.fetchall()}
        
        result = {}
        
        for sku, entity_id in entities.items():
            result[sku] = {'name': None, 'description': None, 'weight': None}
            
            # Get name (varchar)
            if 'name' in attributes:
                cursor.execute(f"""
                    SELECT value 
                    FROM catalog_product_entity_varchar 
                    WHERE entity_id = {entity_id} 
                    AND attribute_id = {attributes['name']}
                    AND store_id = 0
                    LIMIT 1
                """)
                row = cursor.fetchone()
                if row and row['value']:
                    result[sku]['name'] = row['value']
            
            # Get description (text) - prefer description over short_description
            if 'description' in attributes:
                cursor.execute(f"""
                    SELECT value 
                    FROM catalog_product_entity_text 
                    WHERE entity_id = {entity_id} 
                    AND attribute_id = {attributes['description']}
                    AND store_id = 0
                    LIMIT 1
                """)
                row = cursor.fetchone()
                if row and row['value']:
                    result[sku]['description'] = row['value']
            
            # Fallback to short_description if no description
            if not result[sku]['description'] and 'short_description' in attributes:
                cursor.execute(f"""
                    SELECT value 
                    FROM catalog_product_entity_text 
                    WHERE entity_id = {entity_id} 
                    AND attribute_id = {attributes['short_description']}
                    AND store_id = 0
                    LIMIT 1
                """)
                row = cursor.fetchone()
                if row and row['value']:
                    result[sku]['description'] = row['value']
            
            # Get weight (decimal)
            if 'weight' in attributes:
                cursor.execute(f"""
                    SELECT value 
                    FROM catalog_product_entity_decimal 
                    WHERE entity_id = {entity_id} 
                    AND attribute_id = {attributes['weight']}
                    LIMIT 1
                """)
                row = cursor.fetchone()
                if row and row['value']:
                    # Convert to grams (Akeneo uses grams)
                    weight_kg = float(row['value'])
                    result[sku]['weight'] = weight_kg * 1000  # kg to grams
        
        cursor.close()
        return result
    
    def update_product_field(self, product_id: int, sku: str, raw_values: str, 
                           field_name: str, field_value: str, field_type: str = 'text'):
        """Update a single field in product's raw_values JSON"""
        try:
            # Parse existing raw_values
            if not raw_values or raw_values == '[]':
                values = []
            else:
                values = json.loads(raw_values)
            
            # Find or create the field entry
            field_found = False
            for item in values:
                if field_name in item:
                    field_found = True
                    # Update existing field
                    if field_type == 'text':
                        item[field_name] = [{
                            "locale": "fr_FR",
                            "scope": None,
                            "data": field_value
                        }]
                    elif field_type == 'decimal':
                        item[field_name] = [{
                            "locale": None,
                            "scope": None,
                            "data": str(field_value)
                        }]
                    break
            
            # Add field if not found
            if not field_found:
                if field_type == 'text':
                    values.append({
                        field_name: [{
                            "locale": "fr_FR",
                            "scope": None,
                            "data": field_value
                        }]
                    })
                elif field_type == 'decimal':
                    values.append({
                        field_name: [{
                            "locale": None,
                            "scope": None,
                            "data": str(field_value)
                        }]
                    })
            
            # Update database
            new_raw_values = json.dumps(values, ensure_ascii=False)
            cursor = self.akeneo_conn.cursor()
            cursor.execute("""
                UPDATE pim_catalog_product 
                SET raw_values = %s, updated = NOW() 
                WHERE id = %s
            """, (new_raw_values, product_id))
            cursor.close()
            
            return True
            
        except Exception as e:
            self.log(f"❌ Error updating {field_name} for SKU {sku}: {e}", 'ERROR')
            self.stats['errors'] += 1
            return False
    
    def fix_missing_names(self):
        """Import missing names from Magento"""
        self.log("\n" + "="*70)
        self.log("PHASE 2A: FIXING MISSING NAMES")
        self.log("="*70)
        
        products = self.get_products_missing_names()
        if not products:
            self.log("✅ All products have names")
            return
        
        total = len(products)
        processed = 0
        
        # Process in batches
        for i in range(0, total, BATCH_SIZE):
            batch = products[i:i+BATCH_SIZE]
            skus = [p['identifier'] for p in batch]
            
            self.log(f"\nProcessing batch {i//BATCH_SIZE + 1} ({len(batch)} products)...")
            magento_data = self.get_magento_product_data(skus)
            
            for product in batch:
                sku = product['identifier']
                if sku in magento_data and magento_data[sku]['name']:
                    name = magento_data[sku]['name']
                    if self.update_product_field(product['id'], sku, product['raw_values'], 
                                                'name', name, 'text'):
                        self.stats['names_added'] += 1
                        processed += 1
                else:
                    self.log(f"⚠️  No name found in Magento for SKU: {sku}", 'WARN')
            
            self.akeneo_conn.commit()
            self.log(f"Progress: {processed}/{total} names added")
        
        self.log(f"\n✅ Phase 2A Complete: {self.stats['names_added']} names added")
    
    def fix_missing_descriptions(self):
        """Import missing descriptions from Magento"""
        self.log("\n" + "="*70)
        self.log("PHASE 2B: FIXING MISSING DESCRIPTIONS")
        self.log("="*70)
        
        products = self.get_products_missing_descriptions()
        if not products:
            self.log("✅ All products have descriptions")
            return
        
        total = len(products)
        processed = 0
        
        # Process in batches
        for i in range(0, total, BATCH_SIZE):
            batch = products[i:i+BATCH_SIZE]
            skus = [p['identifier'] for p in batch]
            
            self.log(f"\nProcessing batch {i//BATCH_SIZE + 1} ({len(batch)} products)...")
            magento_data = self.get_magento_product_data(skus)
            
            for product in batch:
                sku = product['identifier']
                if sku in magento_data and magento_data[sku]['description']:
                    description = magento_data[sku]['description']
                    if self.update_product_field(product['id'], sku, product['raw_values'], 
                                                'description', description, 'text'):
                        self.stats['descriptions_added'] += 1
                        processed += 1
                else:
                    self.log(f"⚠️  No description found in Magento for SKU: {sku}", 'WARN')
            
            self.akeneo_conn.commit()
            self.log(f"Progress: {processed}/{total} descriptions added")
        
        self.log(f"\n✅ Phase 2B Complete: {self.stats['descriptions_added']} descriptions added")
    
    def fix_missing_weights(self):
        """Import missing weights from Magento"""
        self.log("\n" + "="*70)
        self.log("PHASE 2C: FIXING MISSING WEIGHTS")
        self.log("="*70)
        
        products = self.get_products_missing_weights()
        if not products:
            self.log("✅ All products have weights")
            return
        
        total = len(products)
        processed = 0
        
        # Process in batches
        for i in range(0, total, BATCH_SIZE):
            batch = products[i:i+BATCH_SIZE]
            skus = [p['identifier'] for p in batch]
            
            self.log(f"\nProcessing batch {i//BATCH_SIZE + 1} ({len(batch)} products)...")
            magento_data = self.get_magento_product_data(skus)
            
            for product in batch:
                sku = product['identifier']
                if sku in magento_data and magento_data[sku]['weight']:
                    weight = magento_data[sku]['weight']
                    if self.update_product_field(product['id'], sku, product['raw_values'], 
                                                'weight', weight, 'decimal'):
                        self.stats['weights_added'] += 1
                        processed += 1
                else:
                    self.log(f"⚠️  No weight found in Magento for SKU: {sku}", 'WARN')
            
            self.akeneo_conn.commit()
            self.log(f"Progress: {processed}/{total} weights added")
        
        self.log(f"\n✅ Phase 2C Complete: {self.stats['weights_added']} weights added")
    
    def generate_final_report(self):
        """Generate final statistics report"""
        self.log("\n" + "="*70)
        self.log("FINAL REPORT - PHASE 2: FIX MISSING FIELDS")
        self.log("="*70)
        self.log(f"\n📊 STATISTICS:")
        self.log(f"  • Names Added:        {self.stats['names_added']}")
        self.log(f"  • Descriptions Added: {self.stats['descriptions_added']}")
        self.log(f"  • Weights Added:      {self.stats['weights_added']}")
        self.log(f"  • Errors:             {self.stats['errors']}")
        self.log(f"\n✅ Phase 2 Complete!")
        self.log(f"   Log file: {LOG_FILE}")
    
    def run(self):
        """Main execution"""
        self.log("="*70)
        self.log("FIX MISSING FIELDS - PHASE 2")
        self.log("="*70)
        self.log(f"Started at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        
        if not self.connect_databases():
            return False
        
        try:
            self.fix_missing_names()
            self.fix_missing_descriptions()
            self.fix_missing_weights()
            self.generate_final_report()
            
            return True
            
        except Exception as e:
            self.log(f"\n❌ Fatal error: {e}", 'ERROR')
            import traceback
            self.log(traceback.format_exc(), 'ERROR')
            return False
            
        finally:
            if self.akeneo_conn:
                self.akeneo_conn.close()
            if self.magento_conn:
                self.magento_conn.close()
            self.save_log()

if __name__ == '__main__':
    fixer = FieldFixer()
    success = fixer.run()
    sys.exit(0 if success else 1)
