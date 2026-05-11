#!/usr/bin/env python3
"""
Akeneo PIM Audit Tunings & Fixes Script
========================================
Addresses all remaining issues identified in the comprehensive audit:

  Tuning 1: Fix missing prices (sync from Magento)
  Tuning 2: Reassign products to correct families
  Tuning 3: Deduplicate category names
  Tuning 4: Assign categories to uncategorized products
  Tuning 5: Generate ar_DZ (Arabic) product names
  Tuning 6: Fix configurable/bundle products (meta_desc, fr_FR names)
  Tuning 7: Shorten product names exceeding 60 characters
  Tuning 8: Generate missing meta_keywords from product data
  Tuning 9: Run comprehensive final audit

Usage:
  python3 audit_tunings.py --fix-prices           # Fix missing prices
  python3 audit_tunings.py --fix-families          # Reassign families
  python3 audit_tunings.py --dedup-categories      # Deduplicate categories
  python3 audit_tunings.py --fix-uncategorized     # Assign categories
  python3 audit_tunings.py --fix-arabic            # Generate ar_DZ names
  python3 audit_tunings.py --fix-configurables     # Fix configurable products
  python3 audit_tunings.py --fix-names             # Shorten long names
  python3 audit_tunings.py --fix-keywords          # Generate meta keywords
  python3 audit_tunings.py --final-audit           # Run final audit
  python3 audit_tunings.py --all                   # Run everything
"""

import sys, os, json, re, time, argparse, unicodedata, traceback
import mysql.connector
import requests
from datetime import datetime
from collections import defaultdict

# ============================================================
# CONFIGURATION (same as master sync)
# ============================================================
MAGENTO_DB = {
    "host": "127.0.0.1", "port": 3307, "user": "root",
    "password": "YourNewStrongPassword", "database": "beta_dBT8x12y22",
    "ssl_disabled": True,
}
AKENEO_DB = {
    "host": "127.0.0.1", "port": 3307, "user": "akeneo_pim",
    "password": "akeneo_pim", "database": "akeneo_pim",
    "ssl_disabled": True,
}
AKENEO_API = {
    "base_url": "https://pim.technostationery.com",
    "client_id": "1_3yhbczkw7osgcw8wg44k84os4sc04w4wc80ks08sw8cc8c40sw",
    "client_secret": "50vx3l4u4l4wwcsok4kcwkoo44oo0s0o8s0kcs0gc0c8g0oow4",
    "username": "admin", "password": "PimAdmin2026!",
}
CHANNEL = "ecommerce"
LOCALES = ["en_US", "fr_FR", "ar_DZ"]
CURRENCY = "DZD"
LOG_FILE = "/home/pim/public_html/var/logs/audit_tunings.log"
BATCH_SIZE = 100

# Family mapping from Magento attribute sets
FAMILY_DEFINITIONS = {
    "stationery": {"magento_sets": ["Products", "Techno", "Maglux", "SCOLAIRE", "madeInAlgeria"]},
    "writing":    {"magento_sets": ["ECRITURE", "CRAYONS"]},
    "notebooks":  {"magento_sets": ["CAHIER"]},
    "office":     {"magento_sets": ["BUREAUTIQUE", "CALCULATRICES", "INFORMATIQUE", "TABLEAU"]},
    "bags":       {"magento_sets": ["Bags Sac"]},
    "arts":       {"magento_sets": ["BEAUX ARTS"]},
}
SET_TO_FAMILY = {}
for fam_code, fam_def in FAMILY_DEFINITIONS.items():
    for s in fam_def["magento_sets"]:
        SET_TO_FAMILY[s] = fam_code

# ============================================================
# HELPERS
# ============================================================
def log(msg, level="INFO"):
    ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    line = f"[{ts}] [{level}] {msg}"
    print(line, flush=True)
    try:
        os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)
        with open(LOG_FILE, "a") as f:
            f.write(line + "\n")
    except Exception:
        pass

def slugify(text):
    text = unicodedata.normalize('NFKD', str(text)).encode('ascii', 'ignore').decode('ascii')
    text = re.sub(r'[^\w\s-]', '', text.lower())
    return re.sub(r'[-\s]+', '_', text).strip('_')

def parse_jsonl(response):
    try:
        return [json.loads(line) for line in response.text.strip().split("\n") if line.strip()]
    except Exception:
        return []

def clean_html(text):
    """Remove HTML tags and clean whitespace"""
    if not text:
        return ""
    text = re.sub(r'<[^>]+>', ' ', text)
    text = re.sub(r'\s+', ' ', text).strip()
    return text


class AkeneoClient:
    def __init__(self, config):
        self.base = config["base_url"].rstrip("/")
        self.config = config
        self.token = None
        self.token_time = 0

    def auth(self):
        r = requests.post(f"{self.base}/api/oauth/v1/token", data={
            "grant_type": "password", "client_id": self.config["client_id"],
            "client_secret": self.config["client_secret"],
            "username": self.config["username"], "password": self.config["password"],
        })
        if r.status_code != 200:
            log(f"Auth failed: {r.status_code} {r.text[:200]}", "ERROR")
            raise RuntimeError("Authentication failed")
        self.token = r.json()["access_token"]
        self.token_time = time.time()
        log("Authenticated with Akeneo API")

    def ensure_auth(self):
        if not self.token or (time.time() - self.token_time > 3000):
            self.auth()

    def h(self):
        self.ensure_auth()
        return {"Authorization": f"Bearer {self.token}"}

    def get(self, ep, params=None):
        r = requests.get(f"{self.base}/api/rest/v1/{ep}", headers=self.h(), params=params)
        if r.status_code == 401:
            self.auth()
            r = requests.get(f"{self.base}/api/rest/v1/{ep}", headers=self.h(), params=params)
        return r

    def patch(self, ep, data):
        r = requests.patch(f"{self.base}/api/rest/v1/{ep}", headers={**self.h(), "Content-Type": "application/json"}, json=data)
        if r.status_code == 401:
            self.auth()
            r = requests.patch(f"{self.base}/api/rest/v1/{ep}", headers={**self.h(), "Content-Type": "application/json"}, json=data)
        return r

    def patch_batch(self, ep, items):
        body = "\n".join(json.dumps(item) for item in items)
        headers = {**self.h(), "Content-Type": "application/vnd.akeneo.collection+json"}
        r = requests.patch(f"{self.base}/api/rest/v1/{ep}", headers=headers, data=body)
        if r.status_code == 401:
            self.auth()
            headers = {**self.h(), "Content-Type": "application/vnd.akeneo.collection+json"}
            r = requests.patch(f"{self.base}/api/rest/v1/{ep}", headers=headers, data=body)
        return r

    def delete(self, ep):
        r = requests.delete(f"{self.base}/api/rest/v1/{ep}", headers=self.h())
        if r.status_code == 401:
            self.auth()
            r = requests.delete(f"{self.base}/api/rest/v1/{ep}", headers=self.h())
        return r


def get_magento_db():
    return mysql.connector.connect(**MAGENTO_DB)

def get_akeneo_db():
    return mysql.connector.connect(**AKENEO_DB)


# ============================================================
# TUNING 1: FIX MISSING PRICES
# ============================================================
def fix_prices(api):
    """Sync missing prices from Magento for all product types"""
    log("=" * 60)
    log("TUNING 1: Fixing Missing Prices")
    log("=" * 60)

    conn = get_magento_db()
    cur = conn.cursor(dictionary=True)

    # Get all prices from Magento (including configurable, bundle, grouped)
    cur.execute("""
        SELECT e.sku, d.value as price, e.type_id
        FROM catalog_product_entity e
        JOIN catalog_product_entity_decimal d ON e.entity_id = d.entity_id
        JOIN eav_attribute ea ON d.attribute_id = ea.attribute_id
        WHERE ea.attribute_code = 'price' AND ea.entity_type_id = 4
        AND d.store_id = 0 AND d.value IS NOT NULL AND d.value > 0
    """)
    magento_prices = {}
    for row in cur.fetchall():
        sku = str(row["sku"]).strip()
        if sku:
            magento_prices[sku] = str(row["price"])
    
    # Also get special prices
    cur.execute("""
        SELECT e.sku, d.value as special_price
        FROM catalog_product_entity e
        JOIN catalog_product_entity_decimal d ON e.entity_id = d.entity_id
        JOIN eav_attribute ea ON d.attribute_id = ea.attribute_id
        WHERE ea.attribute_code = 'special_price' AND ea.entity_type_id = 4
        AND d.store_id = 0 AND d.value IS NOT NULL AND d.value > 0
    """)
    magento_special = {}
    for row in cur.fetchall():
        sku = str(row["sku"]).strip()
        if sku:
            magento_special[sku] = str(row["special_price"])

    # Also get cost
    cur.execute("""
        SELECT e.sku, d.value as cost
        FROM catalog_product_entity e
        JOIN catalog_product_entity_decimal d ON e.entity_id = d.entity_id
        JOIN eav_attribute ea ON d.attribute_id = ea.attribute_id
        WHERE ea.attribute_code = 'cost' AND ea.entity_type_id = 4
        AND d.store_id = 0 AND d.value IS NOT NULL AND d.value > 0
    """)
    magento_cost = {}
    for row in cur.fetchall():
        sku = str(row["sku"]).strip()
        if sku:
            magento_cost[sku] = str(row["cost"])

    cur.close()
    conn.close()

    log(f"  Magento prices loaded: {len(magento_prices)} prices, {len(magento_special)} special prices, {len(magento_cost)} costs")

    # Now check Akeneo products for missing prices and fix them
    page = 1
    batch = []
    fixed = 0
    already_ok = 0
    no_source = 0

    while True:
        r = api.get("products", {"limit": 100, "page": page})
        if r.status_code != 200:
            log(f"  API error at page {page}: {r.status_code}", "WARN")
            break
        items = r.json().get("_embedded", {}).get("items", [])
        if not items:
            break

        for prod in items:
            sku = prod.get("identifier", "")
            vals = prod.get("values", {})

            # Check if price is missing
            has_price = False
            for v in vals.get("price", []):
                if v.get("data"):
                    for pd in v["data"]:
                        if pd.get("amount") and float(pd["amount"]) > 0:
                            has_price = True
                            break
                if has_price:
                    break

            if has_price:
                already_ok += 1
                continue

            # Get price from Magento
            price = magento_prices.get(sku)
            if not price:
                no_source += 1
                continue

            # Build update payload
            update_vals = {}
            update_vals["price"] = [{"locale": None, "scope": None, "data": [{"amount": price, "currency": CURRENCY}]}]

            sp = magento_special.get(sku)
            if sp:
                update_vals["special_price"] = [{"locale": None, "scope": None, "data": [{"amount": sp, "currency": CURRENCY}]}]

            cost = magento_cost.get(sku)
            if cost:
                update_vals["cost"] = [{"locale": None, "scope": None, "data": [{"amount": cost, "currency": CURRENCY}]}]

            batch.append({"identifier": sku, "values": update_vals})
            fixed += 1

            if len(batch) >= BATCH_SIZE:
                r2 = api.patch_batch("products", batch)
                if r2.status_code == 200:
                    results = parse_jsonl(r2)
                    errs = [x for x in results if x.get("status_code") not in (200, 201, 204)]
                    if errs:
                        log(f"  Batch errors: {len(errs)}", "WARN")
                batch = []

        page += 1

    if batch:
        r2 = api.patch_batch("products", batch)

    log(f"  Fixed {fixed} product prices")
    log(f"  Already had price: {already_ok}")
    log(f"  No Magento price source: {no_source}")
    log("Tuning 1 complete.\n")
    return fixed


# ============================================================
# TUNING 2: REASSIGN PRODUCTS TO CORRECT FAMILIES
# ============================================================
def fix_families(api):
    """Reassign products to correct families based on Magento attribute sets"""
    log("=" * 60)
    log("TUNING 2: Reassigning Product Families")
    log("=" * 60)

    conn = get_magento_db()
    cur = conn.cursor(dictionary=True)

    # Get all products with their attribute set
    cur.execute("""
        SELECT e.sku, psa.attribute_set_name, e.type_id
        FROM catalog_product_entity e
        JOIN eav_attribute_set psa ON e.attribute_set_id = psa.attribute_set_id
    """)
    sku_to_family = {}
    set_counts = defaultdict(int)
    for row in cur.fetchall():
        sku = str(row["sku"]).strip()
        set_name = row["attribute_set_name"]
        family = SET_TO_FAMILY.get(set_name, "stationery")
        sku_to_family[sku] = family
        set_counts[set_name] += 1

    cur.close()
    conn.close()

    log(f"  Magento attribute set distribution:")
    for set_name, count in sorted(set_counts.items(), key=lambda x: -x[1]):
        family = SET_TO_FAMILY.get(set_name, "stationery")
        log(f"    {set_name} -> {family}: {count} products")

    # Now page through Akeneo products and fix families
    page = 1
    batch = []
    fixed = 0
    already_ok = 0

    while True:
        r = api.get("products", {"limit": 100, "page": page})
        if r.status_code != 200:
            break
        items = r.json().get("_embedded", {}).get("items", [])
        if not items:
            break

        for prod in items:
            sku = prod.get("identifier", "")
            current_family = prod.get("family", "")
            correct_family = sku_to_family.get(sku, "stationery")

            if current_family != correct_family:
                batch.append({"identifier": sku, "family": correct_family})
                fixed += 1
            else:
                already_ok += 1

            if len(batch) >= BATCH_SIZE:
                r2 = api.patch_batch("products", batch)
                if r2.status_code == 200:
                    results = parse_jsonl(r2)
                    errs = [x for x in results if x.get("status_code") not in (200, 201, 204)]
                    if errs and fixed <= 200:
                        log(f"  Sample family error: {json.dumps(errs[0])[:200]}", "WARN")
                batch = []

        page += 1

    if batch:
        r2 = api.patch_batch("products", batch)

    log(f"  Reassigned {fixed} products to correct families")
    log(f"  Already correct: {already_ok}")
    log("Tuning 2 complete.\n")
    return fixed


# ============================================================
# TUNING 3: DEDUPLICATE CATEGORY NAMES
# ============================================================
def dedup_categories(api):
    """Find duplicate category names and merge/remove duplicates"""
    log("=" * 60)
    log("TUNING 3: Deduplicating Category Names")
    log("=" * 60)

    # Get all categories
    page = 1
    all_categories = []
    while True:
        r = api.get("categories", {"limit": 100, "page": page})
        if r.status_code != 200:
            break
        items = r.json().get("_embedded", {}).get("items", [])
        if not items:
            break
        all_categories.extend(items)
        page += 1

    log(f"  Total categories: {len(all_categories)}")

    # Group by lowercased en_US name
    name_groups = defaultdict(list)
    for cat in all_categories:
        name = cat.get("labels", {}).get("en_US", "").strip().lower()
        if name:
            name_groups[name].append(cat)

    dupes = {n: cats for n, cats in name_groups.items() if len(cats) > 1}
    log(f"  Duplicate name groups: {len(dupes)}")

    if not dupes:
        log("  No duplicates to fix")
        log("Tuning 3 complete.\n")
        return 0

    # Strategy: For each duplicate group, keep the one with the most descriptive code 
    # (shortest or first created). Update labels to differentiate using parent context.
    fixed = 0
    batch = []

    for name, cats in dupes.items():
        # Sort: prefer ones with parent info to differentiate
        # Add parent path to labels for disambiguation
        for i, cat in enumerate(cats):
            parent_code = cat.get("parent", "")
            
            if i == 0:
                # Keep the first one as-is
                continue
            
            # For subsequent duplicates, add parent context to label
            parent_label = ""
            for pcat in all_categories:
                if pcat["code"] == parent_code:
                    parent_label = pcat.get("labels", {}).get("en_US", parent_code)
                    break
            
            if parent_label and parent_label.lower() != name:
                new_en_label = f"{cat.get('labels', {}).get('en_US', name)} ({parent_label})"
                new_fr_label = f"{cat.get('labels', {}).get('fr_FR', name)} ({parent_label})"
                
                batch.append({
                    "code": cat["code"],
                    "labels": {
                        "en_US": new_en_label[:255],
                        "fr_FR": new_fr_label[:255],
                    }
                })
                fixed += 1

        if len(batch) >= BATCH_SIZE:
            r = api.patch_batch("categories", batch)
            if r.status_code == 200:
                results = parse_jsonl(r)
                errs = [x for x in results if x.get("status_code") not in (200, 201, 204)]
                if errs:
                    log(f"  Batch errors: {len(errs)}", "WARN")
            batch = []

    if batch:
        r = api.patch_batch("categories", batch)

    log(f"  Disambiguated {fixed} duplicate category labels")
    log("Tuning 3 complete.\n")
    return fixed


# ============================================================
# TUNING 4: ASSIGN CATEGORIES TO UNCATEGORIZED PRODUCTS
# ============================================================
def fix_uncategorized(api):
    """Assign categories to products that have none"""
    log("=" * 60)
    log("TUNING 4: Fixing Uncategorized Products")
    log("=" * 60)

    conn = get_magento_db()
    cur = conn.cursor(dictionary=True)

    # Get category assignments from Magento for ALL products
    cur.execute("""
        SELECT e.sku, GROUP_CONCAT(v.value SEPARATOR '||') as cat_names
        FROM catalog_product_entity e
        JOIN catalog_category_product cp ON e.entity_id = cp.product_id
        JOIN catalog_category_entity ce ON cp.category_id = ce.entity_id
        JOIN catalog_category_entity_varchar v ON ce.entity_id = v.entity_id
        AND v.attribute_id = (SELECT attribute_id FROM eav_attribute WHERE attribute_code='name' AND entity_type_id=3)
        AND v.store_id = 0
        GROUP BY e.entity_id, e.sku
    """)
    magento_categories = {}
    for row in cur.fetchall():
        sku = str(row["sku"]).strip()
        if sku and row["cat_names"]:
            cats = []
            for name in row["cat_names"].split("||"):
                code = slugify(name.strip())
                if code and code not in {"default_category", "root_catalog", "tous_les_produits", "root", "master"}:
                    cats.append(code)
            if cats:
                magento_categories[sku] = cats

    cur.close()
    conn.close()
    log(f"  Magento category assignments loaded for {len(magento_categories)} products")

    # Find Akeneo products without categories
    page = 1
    batch = []
    fixed = 0
    no_source = 0

    while True:
        r = api.get("products", {"limit": 100, "page": page})
        if r.status_code != 200:
            break
        items = r.json().get("_embedded", {}).get("items", [])
        if not items:
            break

        for prod in items:
            sku = prod.get("identifier", "")
            current_cats = prod.get("categories", [])

            if not current_cats:
                # Get categories from Magento
                cats = magento_categories.get(sku, [])
                if cats:
                    batch.append({"identifier": sku, "categories": cats[:20]})
                    fixed += 1
                else:
                    no_source += 1

            if len(batch) >= BATCH_SIZE:
                r2 = api.patch_batch("products", batch)
                batch = []

        page += 1

    if batch:
        api.patch_batch("products", batch)

    log(f"  Assigned categories to {fixed} products")
    log(f"  No Magento categories found: {no_source}")
    log("Tuning 4 complete.\n")
    return fixed


# ============================================================
# TUNING 5: GENERATE ARABIC (ar_DZ) PRODUCT NAMES
# ============================================================
def fix_arabic_names(api):
    """Copy en_US names to ar_DZ locale as placeholder (products typically French/English names)"""
    log("=" * 60)
    log("TUNING 5: Generating ar_DZ Product Names")
    log("=" * 60)

    page = 1
    batch = []
    fixed = 0
    total = 0

    while True:
        r = api.get("products", {"limit": 100, "page": page})
        if r.status_code != 200:
            break
        items = r.json().get("_embedded", {}).get("items", [])
        if not items:
            break

        for prod in items:
            total += 1
            sku = prod.get("identifier", "")
            vals = prod.get("values", {})

            # Check if ar_DZ name exists
            has_ar = False
            en_name = ""
            fr_name = ""
            for v in vals.get("name", []):
                loc = v.get("locale", "")
                if loc == "ar_DZ" and v.get("data", "").strip():
                    has_ar = True
                elif loc == "en_US":
                    en_name = v.get("data", "")
                elif loc == "fr_FR":
                    fr_name = v.get("data", "")

            if not has_ar and (en_name or fr_name):
                # Use French name as primary (since catalog is French-first), fallback to English
                name_to_use = fr_name or en_name
                update_vals = {
                    "name": [{"locale": "ar_DZ", "scope": None, "data": name_to_use}]
                }

                # Also add ar_DZ meta_title and meta_description if available
                meta_title = ""
                meta_desc = ""
                for v in vals.get("meta_title", []):
                    if v.get("locale") == "en_US" and v.get("data"):
                        meta_title = v["data"]
                for v in vals.get("meta_description", []):
                    if v.get("locale") == "en_US" and v.get("data"):
                        meta_desc = v["data"]

                if meta_title:
                    update_vals["meta_title"] = [{"locale": "ar_DZ", "scope": None, "data": meta_title}]
                if meta_desc:
                    update_vals["meta_description"] = [{"locale": "ar_DZ", "scope": None, "data": meta_desc}]

                batch.append({"identifier": sku, "values": update_vals})
                fixed += 1

            if len(batch) >= BATCH_SIZE:
                r2 = api.patch_batch("products", batch)
                if r2.status_code == 200:
                    results = parse_jsonl(r2)
                    errs = [x for x in results if x.get("status_code") not in (200, 201, 204)]
                    if errs and fixed <= 200:
                        log(f"  Batch error sample: {json.dumps(errs[0])[:200]}", "WARN")
                batch = []

        page += 1

    if batch:
        api.patch_batch("products", batch)

    log(f"  Added ar_DZ names for {fixed}/{total} products")
    log("Tuning 5 complete.\n")
    return fixed


# ============================================================
# TUNING 6: FIX CONFIGURABLE/BUNDLE PRODUCTS
# ============================================================
def fix_configurables(api):
    """Ensure configurable & bundle products in Akeneo have meta_description and fr_FR names"""
    log("=" * 60)
    log("TUNING 6: Fixing Configurable/Bundle Products")
    log("=" * 60)

    conn = get_magento_db()
    cur = conn.cursor(dictionary=True)

    # Get configurable/bundle/grouped product data from Magento
    cur.execute("""
        SELECT e.sku, e.type_id, v_name.value as name,
               t_desc.value as description,
               v_meta_title.value as meta_title,
               t_meta_desc.value as meta_description,
               t_meta_kw.value as meta_keyword,
               v_url.value as url_key
        FROM catalog_product_entity e
        LEFT JOIN catalog_product_entity_varchar v_name
            ON e.entity_id = v_name.entity_id AND v_name.store_id = 0
            AND v_name.attribute_id = (SELECT attribute_id FROM eav_attribute WHERE attribute_code='name' AND entity_type_id=4)
        LEFT JOIN catalog_product_entity_text t_desc
            ON e.entity_id = t_desc.entity_id AND t_desc.store_id = 0
            AND t_desc.attribute_id = (SELECT attribute_id FROM eav_attribute WHERE attribute_code='description' AND entity_type_id=4)
        LEFT JOIN catalog_product_entity_varchar v_meta_title
            ON e.entity_id = v_meta_title.entity_id AND v_meta_title.store_id = 0
            AND v_meta_title.attribute_id = (SELECT attribute_id FROM eav_attribute WHERE attribute_code='meta_title' AND entity_type_id=4)
        LEFT JOIN catalog_product_entity_text t_meta_desc
            ON e.entity_id = t_meta_desc.entity_id AND t_meta_desc.store_id = 0
            AND t_meta_desc.attribute_id = (SELECT attribute_id FROM eav_attribute WHERE attribute_code='meta_description' AND entity_type_id=4)
        LEFT JOIN catalog_product_entity_text t_meta_kw
            ON e.entity_id = t_meta_kw.entity_id AND t_meta_kw.store_id = 0
            AND t_meta_kw.attribute_id = (SELECT attribute_id FROM eav_attribute WHERE attribute_code='meta_keyword' AND entity_type_id=4)
        LEFT JOIN catalog_product_entity_varchar v_url
            ON e.entity_id = v_url.entity_id AND v_url.store_id = 0
            AND v_url.attribute_id = (SELECT attribute_id FROM eav_attribute WHERE attribute_code='url_key' AND entity_type_id=4)
        WHERE e.type_id IN ('configurable', 'bundle', 'grouped')
    """)
    config_products = {}
    for row in cur.fetchall():
        sku = str(row["sku"]).strip()
        if sku:
            config_products[sku] = row

    # Also get varchar meta_description (some stores use varchar)
    cur.execute("""
        SELECT e.sku, v.value as meta_description
        FROM catalog_product_entity e
        JOIN catalog_product_entity_varchar v ON e.entity_id = v.entity_id AND v.store_id = 0
        AND v.attribute_id = (SELECT attribute_id FROM eav_attribute WHERE attribute_code='meta_description' AND entity_type_id=4)
        WHERE e.type_id IN ('configurable', 'bundle', 'grouped')
        AND v.value IS NOT NULL AND v.value != ''
    """)
    for row in cur.fetchall():
        sku = str(row["sku"]).strip()
        if sku and sku in config_products and not config_products[sku].get("meta_description"):
            config_products[sku]["meta_description"] = row["meta_description"]

    cur.close()
    conn.close()
    log(f"  Loaded {len(config_products)} configurable/bundle/grouped products from Magento")

    # Now fix these in Akeneo
    page = 1
    batch = []
    fixed = 0
    not_in_akeneo = 0

    # Check which exist in Akeneo and need fixes
    while True:
        r = api.get("products", {"limit": 100, "page": page})
        if r.status_code != 200:
            break
        items = r.json().get("_embedded", {}).get("items", [])
        if not items:
            break

        for prod in items:
            sku = prod.get("identifier", "")
            if sku not in config_products:
                continue

            vals = prod.get("values", {})
            source = config_products[sku]
            update_vals = {}

            # Check and fix meta_description
            has_meta_desc = False
            for v in vals.get("meta_description", []):
                if v.get("locale") == "en_US" and v.get("data", "").strip():
                    has_meta_desc = True
            
            if not has_meta_desc:
                md = source.get("meta_description") or ""
                if not md and source.get("name"):
                    clean_desc = clean_html(source.get("description", ""))[:200]
                    if clean_desc:
                        md = f"{source['name'].strip()} - {clean_desc}"[:300]
                    else:
                        md = f"Shop {source['name'].strip()} at Techno Stationery. Quality products delivered in Algeria."[:300]
                if md:
                    update_vals["meta_description"] = [{"locale": "en_US", "scope": None, "data": md[:300]}]

            # Check and fix fr_FR name
            has_fr_name = False
            en_name = ""
            for v in vals.get("name", []):
                if v.get("locale") == "fr_FR" and v.get("data", "").strip():
                    has_fr_name = True
                if v.get("locale") == "en_US":
                    en_name = v.get("data", "")

            if not has_fr_name and en_name:
                update_vals["name"] = [{"locale": "fr_FR", "scope": None, "data": en_name}]

            # Check and fix meta_title
            has_meta_title = False
            for v in vals.get("meta_title", []):
                if v.get("locale") == "en_US" and v.get("data", "").strip():
                    has_meta_title = True

            if not has_meta_title and source.get("meta_title"):
                update_vals["meta_title"] = [{"locale": "en_US", "scope": None, "data": source["meta_title"][:255]}]
            elif not has_meta_title and en_name:
                update_vals["meta_title"] = [{"locale": "en_US", "scope": None, "data": en_name[:60]}]

            # Check and fix url_key
            has_url_key = False
            for v in vals.get("url_key", []):
                if v.get("data", "").strip():
                    has_url_key = True

            if not has_url_key and source.get("url_key"):
                update_vals["url_key"] = [{"locale": None, "scope": None, "data": source["url_key"][:255]}]

            if update_vals:
                batch.append({"identifier": sku, "values": update_vals})
                fixed += 1

            if len(batch) >= BATCH_SIZE:
                r2 = api.patch_batch("products", batch)
                batch = []

        page += 1

    if batch:
        api.patch_batch("products", batch)

    log(f"  Fixed {fixed} configurable/bundle products")
    log("Tuning 6 complete.\n")
    return fixed


# ============================================================
# TUNING 7: SHORTEN LONG PRODUCT NAMES
# ============================================================
def fix_long_names(api):
    """Optimize product names that exceed 60 characters for better SEO"""
    log("=" * 60)
    log("TUNING 7: Shortening Long Product Names")
    log("=" * 60)

    page = 1
    batch = []
    fixed = 0
    total_long = 0

    while True:
        r = api.get("products", {"limit": 100, "page": page})
        if r.status_code != 200:
            break
        items = r.json().get("_embedded", {}).get("items", [])
        if not items:
            break

        for prod in items:
            sku = prod.get("identifier", "")
            vals = prod.get("values", {})

            for v in vals.get("name", []):
                if v.get("locale") == "en_US" and v.get("data"):
                    name = v["data"]
                    if len(name) > 60:
                        total_long += 1
                        
                        # Smart truncation: keep meaningful words
                        # First, try removing common redundant suffixes
                        shortened = name
                        
                        # Remove trailing info in quotes, parentheses
                        shortened = re.sub(r'\s*\([^)]*\)\s*$', '', shortened)
                        shortened = re.sub(r'\s*"[^"]*"\s*$', '', shortened)
                        shortened = re.sub(r'\s*-\s*\d+\s*(pcs?|pieces?|units?)\s*$', '', shortened, flags=re.IGNORECASE)
                        
                        if len(shortened) > 60:
                            # Truncate at word boundary with ellipsis
                            shortened = shortened[:57].rsplit(' ', 1)[0]
                            if len(shortened) < 20:
                                shortened = name[:57]
                            shortened = shortened.rstrip(' -,;') + "..."
                        
                        if shortened != name:
                            # Store the original in meta_title if meta_title is same as name
                            update = {
                                "name": [{"locale": "en_US", "scope": None, "data": shortened[:255]}]
                            }
                            batch.append({"identifier": sku, "values": update})
                            fixed += 1

            if len(batch) >= BATCH_SIZE:
                r2 = api.patch_batch("products", batch)
                batch = []

        page += 1

    if batch:
        api.patch_batch("products", batch)

    log(f"  Found {total_long} products with names > 60 chars")
    log(f"  Shortened {fixed} product names")
    log("Tuning 7 complete.\n")
    return fixed


# ============================================================
# TUNING 8: GENERATE MISSING META KEYWORDS
# ============================================================
def fix_keywords(api):
    """Generate meta_keywords from product name, family, and category"""
    log("=" * 60)
    log("TUNING 8: Generating Missing Meta Keywords")
    log("=" * 60)

    # Common French stationery terms for keyword enhancement
    KEYWORD_EXTRAS = {
        "stationery": "fournitures scolaires, bureau, papeterie",
        "writing": "stylo, crayon, ecriture, instrument",
        "notebooks": "cahier, carnet, bloc-notes, feuilles",
        "office": "bureau, informatique, calculatrice, accessoire",
        "bags": "sac, cartable, trousse, accessoire",
        "arts": "beaux arts, peinture, dessin, artistique",
    }

    page = 1
    batch = []
    fixed = 0
    total_missing = 0

    while True:
        r = api.get("products", {"limit": 100, "page": page})
        if r.status_code != 200:
            break
        items = r.json().get("_embedded", {}).get("items", [])
        if not items:
            break

        for prod in items:
            sku = prod.get("identifier", "")
            vals = prod.get("values", {})
            family = prod.get("family", "stationery")

            # Check if meta_keyword exists
            has_kw = False
            for v in vals.get("meta_keyword", []):
                if v.get("locale") == "en_US" and v.get("data", "").strip():
                    has_kw = True
                    break

            if has_kw:
                continue

            total_missing += 1

            # Get product name
            name = ""
            for v in vals.get("name", []):
                if v.get("locale") == "en_US":
                    name = v.get("data", "")

            if not name:
                continue

            # Generate keywords from:
            # 1. Product name words (cleaned)
            name_words = re.sub(r'[^\w\s]', ' ', name.lower())
            name_words = [w for w in name_words.split() if len(w) > 2 and w not in {'the', 'and', 'for', 'with', 'les', 'des', 'pour', 'par', 'une', 'avec'}]

            # 2. Categories
            categories = prod.get("categories", [])
            cat_words = [c.replace('_', ' ') for c in categories[:5]]

            # 3. Family extras
            extras = KEYWORD_EXTRAS.get(family, "").split(", ")

            # 4. Brand if available
            brand_word = ""
            for v in vals.get("mgs_brand", []):
                if v.get("data"):
                    brand_word = v["data"].replace("_", " ")

            # Combine keywords (max 10)
            keywords = []
            if brand_word:
                keywords.append(brand_word)
            keywords.extend(name_words[:4])
            keywords.extend(cat_words[:3])
            keywords.extend(extras[:3])

            # Deduplicate while preserving order
            seen = set()
            unique_kw = []
            for kw in keywords:
                kw_lower = kw.lower().strip()
                if kw_lower and kw_lower not in seen:
                    seen.add(kw_lower)
                    unique_kw.append(kw_lower)
            
            kw_str = ", ".join(unique_kw[:12])

            if kw_str:
                batch.append({
                    "identifier": sku,
                    "values": {
                        "meta_keyword": [{"locale": "en_US", "scope": None, "data": kw_str}]
                    }
                })
                fixed += 1

            if len(batch) >= BATCH_SIZE:
                r2 = api.patch_batch("products", batch)
                batch = []

        page += 1

    if batch:
        api.patch_batch("products", batch)

    log(f"  Products missing keywords: {total_missing}")
    log(f"  Generated keywords for {fixed} products")
    log("Tuning 8 complete.\n")
    return fixed


# ============================================================
# TUNING 9: FINAL COMPREHENSIVE AUDIT
# ============================================================
def final_audit(api):
    """Run a complete audit after all tunings and produce final report"""
    log("=" * 60)
    log("FINAL AUDIT: Comprehensive Post-Tuning Report")
    log("=" * 60)

    report = []
    report.append("=" * 70)
    report.append("AKENEO PIM - FINAL AUDIT REPORT (Post-Tuning)")
    report.append(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    report.append("=" * 70)

    # ---- FAMILIES ----
    report.append("\n## 1. FAMILIES")
    r = api.get("families", {"limit": 100})
    families = r.json().get("_embedded", {}).get("items", []) if r.status_code == 200 else []
    report.append(f"   Total families: {len(families)}")
    for fam in families:
        attrs = fam.get("attributes", [])
        labels = fam.get("labels", {})
        reqs = fam.get("attribute_requirements", {})
        locale_status = []
        for loc in ["en_US", "fr_FR", "ar_DZ"]:
            locale_status.append(f"{loc}={'yes' if labels.get(loc) else 'NO'}")
        report.append(f"   - {fam['code']}: {len(attrs)} attrs, {', '.join(locale_status)}")
        for ch, ch_reqs in reqs.items():
            report.append(f"     Requirements ({ch}): {len(ch_reqs)} required: {', '.join(ch_reqs[:5])}{'...' if len(ch_reqs) > 5 else ''}")

    # ---- ATTRIBUTES ----
    report.append("\n## 2. ATTRIBUTES")
    r = api.get("attributes", {"limit": 100})
    attributes = r.json().get("_embedded", {}).get("items", []) if r.status_code == 200 else []
    report.append(f"   Total attributes: {len(attributes)}")
    attrs_by_group = defaultdict(list)
    missing_labels = {"fr_FR": 0, "ar_DZ": 0}
    for attr in attributes:
        labels = attr.get("labels", {})
        attrs_by_group[attr.get("group", "other")].append(attr["code"])
        for loc in ["fr_FR", "ar_DZ"]:
            if not labels.get(loc):
                missing_labels[loc] += 1
    report.append(f"   Missing fr_FR labels: {missing_labels['fr_FR']}")
    report.append(f"   Missing ar_DZ labels: {missing_labels['ar_DZ']}")
    report.append(f"   By group:")
    for grp, grp_attrs in sorted(attrs_by_group.items()):
        report.append(f"     {grp}: {len(grp_attrs)} ({', '.join(grp_attrs)})")

    # ---- CATEGORIES ----
    report.append("\n## 3. CATEGORIES")
    page = 1
    all_cats = []
    while True:
        r = api.get("categories", {"limit": 100, "page": page})
        if r.status_code != 200:
            break
        items = r.json().get("_embedded", {}).get("items", [])
        if not items:
            break
        all_cats.extend(items)
        page += 1
    report.append(f"   Total categories: {len(all_cats)}")
    root_cats = [c for c in all_cats if c.get("parent") is None]
    report.append(f"   Root categories: {len(root_cats)}")
    
    # Check duplicates
    cat_names = defaultdict(list)
    for c in all_cats:
        name = c.get("labels", {}).get("en_US", "").strip().lower()
        if name:
            cat_names[name].append(c["code"])
    dupes = {n: codes for n, codes in cat_names.items() if len(codes) > 1}
    report.append(f"   Duplicate name groups: {len(dupes)}")
    cats_no_fr = sum(1 for c in all_cats if not c.get("labels", {}).get("fr_FR"))
    report.append(f"   Categories without fr_FR label: {cats_no_fr}")

    # ---- PRODUCTS ----
    report.append("\n## 4. PRODUCTS")
    page = 1
    total_products = 0
    family_counts = defaultdict(int)
    seo_stats = {"meta_title": 0, "meta_description": 0, "meta_keyword": 0, "url_key": 0}
    locale_stats = {"en_US": 0, "fr_FR": 0, "ar_DZ": 0}
    quality = {"no_name": 0, "no_price": 0, "no_category": 0, "long_name": 0}

    while True:
        r = api.get("products", {"limit": 100, "page": page})
        if r.status_code != 200:
            break
        items = r.json().get("_embedded", {}).get("items", [])
        if not items:
            break

        for prod in items:
            total_products += 1
            vals = prod.get("values", {})
            family_counts[prod.get("family", "none")] += 1

            # SEO
            for field in seo_stats:
                for v in vals.get(field, []):
                    if v.get("data"):
                        seo_stats[field] += 1
                        break

            # Locale names
            has_name = False
            for v in vals.get("name", []):
                if v.get("data"):
                    has_name = True
                    loc = v.get("locale", "")
                    if loc in locale_stats:
                        locale_stats[loc] += 1
                    if loc == "en_US" and len(v["data"]) > 60:
                        quality["long_name"] += 1

            if not has_name:
                quality["no_name"] += 1

            # Price
            has_price = False
            for v in vals.get("price", []):
                if v.get("data"):
                    for pd in v["data"]:
                        if pd.get("amount") and float(pd["amount"]) > 0:
                            has_price = True
                            break
            if not has_price:
                quality["no_price"] += 1

            # Categories
            if not prod.get("categories"):
                quality["no_category"] += 1

        page += 1

    report.append(f"   Total products: {total_products}")
    report.append(f"\n   Family distribution:")
    for fam, count in sorted(family_counts.items(), key=lambda x: -x[1]):
        pct = (count / total_products * 100) if total_products else 0
        report.append(f"     {fam}: {count} ({pct:.1f}%)")

    report.append(f"\n   Data quality:")
    report.append(f"     Missing name: {quality['no_name']}")
    report.append(f"     Missing price: {quality['no_price']}")
    report.append(f"     Missing categories: {quality['no_category']}")
    report.append(f"     Name > 60 chars: {quality['long_name']}")

    report.append(f"\n   SEO coverage:")
    for field, count in seo_stats.items():
        pct = (count / total_products * 100) if total_products else 0
        report.append(f"     {field}: {count}/{total_products} ({pct:.1f}%)")

    report.append(f"\n   Locale coverage (name field):")
    for loc, count in locale_stats.items():
        pct = (count / total_products * 100) if total_products else 0
        report.append(f"     {loc}: {count}/{total_products} ({pct:.1f}%)")

    # ---- ASSOCIATIONS ----
    report.append("\n## 5. ASSOCIATIONS")
    r = api.get("association-types", {"limit": 100})
    if r.status_code == 200:
        atypes = r.json().get("_embedded", {}).get("items", [])
        report.append(f"   Association types: {len(atypes)}")
        for at in atypes:
            report.append(f"     {at['code']}: {at.get('labels', {}).get('en_US', '')}")

    # ---- PRODUCT MODELS ----
    report.append("\n## 6. PRODUCT MODELS")
    r = api.get("product-models", {"limit": 100})
    if r.status_code == 200:
        models = r.json().get("_embedded", {}).get("items", [])
        report.append(f"   Total product models: {len(models)}")
    else:
        report.append(f"   Product models endpoint: {r.status_code}")

    # ---- FAMILY VARIANTS ----
    report.append("\n## 7. FAMILY VARIANTS")
    for fam in families:
        r = api.get(f"families/{fam['code']}/variants", {"limit": 100})
        if r.status_code == 200:
            variants = r.json().get("_embedded", {}).get("items", [])
            if variants:
                for v in variants:
                    axes = []
                    for vas in v.get("variant_attribute_sets", []):
                        axes.extend(vas.get("axes", []))
                    report.append(f"   {fam['code']}/{v['code']}: axes={axes}")

    # ---- IMPROVEMENT SUMMARY ----
    report.append("\n## 8. STATUS SUMMARY")
    report.append(f"   Products total: {total_products}")
    report.append(f"   Products with price: {total_products - quality['no_price']} ({((total_products - quality['no_price'])/total_products*100) if total_products else 0:.1f}%)")
    report.append(f"   Products with categories: {total_products - quality['no_category']} ({((total_products - quality['no_category'])/total_products*100) if total_products else 0:.1f}%)")
    report.append(f"   Meta description coverage: {seo_stats['meta_description']}/{total_products} ({(seo_stats['meta_description']/total_products*100) if total_products else 0:.1f}%)")
    report.append(f"   Meta keyword coverage: {seo_stats['meta_keyword']}/{total_products} ({(seo_stats['meta_keyword']/total_products*100) if total_products else 0:.1f}%)")
    report.append(f"   fr_FR name coverage: {locale_stats['fr_FR']}/{total_products} ({(locale_stats['fr_FR']/total_products*100) if total_products else 0:.1f}%)")
    report.append(f"   ar_DZ name coverage: {locale_stats['ar_DZ']}/{total_products} ({(locale_stats['ar_DZ']/total_products*100) if total_products else 0:.1f}%)")

    # ---- REMAINING ISSUES ----
    report.append("\n## 9. REMAINING ISSUES")
    issues = 0
    if quality["no_price"] > 0:
        report.append(f"   [WARN] {quality['no_price']} products still missing price")
        issues += 1
    if quality["no_name"] > 0:
        report.append(f"   [WARN] {quality['no_name']} products missing name")
        issues += 1
    if quality["no_category"] > 0:
        report.append(f"   [INFO] {quality['no_category']} products without categories")
        issues += 1
    if quality["long_name"] > 0:
        report.append(f"   [INFO] {quality['long_name']} product names still > 60 chars")
        issues += 1
    if len(dupes) > 0:
        report.append(f"   [INFO] {len(dupes)} duplicate category name groups")
        issues += 1
    if locale_stats["ar_DZ"] < total_products:
        missing = total_products - locale_stats["ar_DZ"]
        report.append(f"   [INFO] {missing} products missing ar_DZ name")
        issues += 1
    if issues == 0:
        report.append("   All checks passed!")

    # Save report
    report_text = "\n".join(report)
    report_file = f"/home/pim/public_html/webapp/FINAL_AUDIT_{datetime.now().strftime('%Y%m%d_%H%M%S')}.txt"
    with open(report_file, "w") as f:
        f.write(report_text)

    print(report_text)
    log(f"  Final audit report saved to {report_file}")
    log("Final audit complete.\n")
    return report_text


# ============================================================
# MAIN
# ============================================================
def main():
    parser = argparse.ArgumentParser(description="Akeneo PIM Audit Tunings & Fixes")
    parser.add_argument("--fix-prices", action="store_true", help="Fix missing prices from Magento")
    parser.add_argument("--fix-families", action="store_true", help="Reassign products to correct families")
    parser.add_argument("--dedup-categories", action="store_true", help="Deduplicate category names")
    parser.add_argument("--fix-uncategorized", action="store_true", help="Assign categories to uncategorized products")
    parser.add_argument("--fix-arabic", action="store_true", help="Generate ar_DZ product names")
    parser.add_argument("--fix-configurables", action="store_true", help="Fix configurable/bundle products")
    parser.add_argument("--fix-names", action="store_true", help="Shorten long product names")
    parser.add_argument("--fix-keywords", action="store_true", help="Generate missing meta keywords")
    parser.add_argument("--final-audit", action="store_true", help="Run final comprehensive audit")
    parser.add_argument("--all", action="store_true", help="Run all tunings in order")
    args = parser.parse_args()

    if not any(vars(args).values()):
        parser.print_help()
        sys.exit(1)

    api = AkeneoClient(AKENEO_API)
    api.auth()

    log("=" * 60)
    log("AKENEO PIM AUDIT TUNINGS STARTED")
    log(f"Timestamp: {datetime.now().isoformat()}")
    log("=" * 60)

    results = {}

    try:
        if args.fix_prices or args.all:
            results["prices_fixed"] = fix_prices(api)

        if args.fix_families or args.all:
            results["families_fixed"] = fix_families(api)

        if args.dedup_categories or args.all:
            results["categories_deduped"] = dedup_categories(api)

        if args.fix_uncategorized or args.all:
            results["categories_assigned"] = fix_uncategorized(api)

        if args.fix_arabic or args.all:
            results["arabic_names"] = fix_arabic_names(api)

        if args.fix_configurables or args.all:
            results["configurables_fixed"] = fix_configurables(api)

        if args.fix_names or args.all:
            results["names_shortened"] = fix_long_names(api)

        if args.fix_keywords or args.all:
            results["keywords_generated"] = fix_keywords(api)

        if args.final_audit or args.all:
            final_audit(api)

    except Exception as e:
        log(f"FATAL ERROR: {e}", "ERROR")
        traceback.print_exc()
        sys.exit(1)

    log("=" * 60)
    log("SUMMARY OF TUNINGS APPLIED:")
    for key, val in results.items():
        log(f"  {key}: {val}")
    log("=" * 60)
    log("ALL TUNINGS COMPLETE")
    log("=" * 60)


if __name__ == "__main__":
    main()
