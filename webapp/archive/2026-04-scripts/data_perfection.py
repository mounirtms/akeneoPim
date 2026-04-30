#!/usr/bin/env python3
"""
Akeneo PIM - Data Perfection & Display Fixes
=============================================
Comprehensive script to fix all remaining data quality and display issues.

Issues addressed:
  1. Weight placeholders (9999g) and zeros -> null or real Magento values
  2. Missing visibility on 2,047 variant products + 3 standalone + 556 models
  3. Missing product_status on same products -> sync from Magento
  4. Manufacturer attribute -> sync from mgs_brand / Magento brand data
  5. Too-short descriptions (<50 chars) -> generate better ones
  6. Missing brands on ~204 products -> fill from Magento
  7. Disabled products -> verify against Magento and correct
  8. Family completeness requirements -> add image, description, short_description
  9. Grid filter attributes -> enable filtering on key attributes
 10. Visibility option cleanup -> normalize duplicate options

Usage:
  python3 data_perfection.py --all
  python3 data_perfection.py --weight --visibility --manufacturer
  python3 data_perfection.py --audit   (just report, no changes)
"""

import sys, os, json, re, time, argparse, traceback
import mysql.connector
import requests
from datetime import datetime
from collections import defaultdict

# ============================================================
# CONFIGURATION
# ============================================================
MAGENTO_DB = {
    "host": "127.0.0.1", "port": 3307, "user": "root",
    "password": "YourNewStrongPassword", "database": "beta_dBT8x12y22",
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
LOG_FILE = "/home/pim/public_html/var/logs/data_perfection.log"
BATCH_SIZE = 100
WEBAPP = "/home/pim/public_html/webapp"
FAMILIES = ["arts", "bags", "notebooks", "office", "stationery", "writing"]


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


class AkeneoClient:
    def __init__(self, config):
        self.base = config["base_url"].rstrip("/")
        self.config = config
        self.token = None
        self.token_time = 0

    def auth(self):
        r = requests.post(f"{self.base}/api/oauth/v1/token", data={
            "grant_type": "password",
            "client_id": self.config["client_id"],
            "client_secret": self.config["client_secret"],
            "username": self.config["username"],
            "password": self.config["password"],
        })
        if r.status_code != 200:
            raise RuntimeError(f"Auth failed: {r.status_code} {r.text[:300]}")
        self.token = r.json()["access_token"]
        self.token_time = time.time()

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

    def patch(self, ep, json_data):
        r = requests.patch(f"{self.base}/api/rest/v1/{ep}", headers={**self.h(), "Content-Type": "application/json"}, json=json_data)
        if r.status_code == 401:
            self.auth()
            r = requests.patch(f"{self.base}/api/rest/v1/{ep}", headers={**self.h(), "Content-Type": "application/json"}, json=json_data)
        return r

    def patch_batch(self, ep, items):
        if not items:
            return None
        body = "\n".join(json.dumps(item) for item in items)
        headers = {**self.h(), "Content-Type": "application/vnd.akeneo.collection+json"}
        r = requests.patch(f"{self.base}/api/rest/v1/{ep}", headers=headers, data=body)
        if r.status_code == 401:
            self.auth()
            headers = {**self.h(), "Content-Type": "application/vnd.akeneo.collection+json"}
            r = requests.patch(f"{self.base}/api/rest/v1/{ep}", headers=headers, data=body)
        return r

    def get_all_products(self):
        """Page through all products using standard pagination."""
        page = 1
        while True:
            r = self.get("products", {"limit": 100, "page": page})
            if r.status_code != 200:
                break
            items = r.json().get("_embedded", {}).get("items", [])
            if not items:
                break
            yield from items
            page += 1
            if page % 20 == 0:
                log(f"  ... loaded {page * 100} products")

    def get_all_product_models(self):
        page = 1
        while True:
            r = self.get("product-models", {"limit": 100, "page": page})
            if r.status_code != 200:
                break
            items = r.json().get("_embedded", {}).get("items", [])
            if not items:
                break
            yield from items
            page += 1


# ============================================================
# HELPERS
# ============================================================
def get_magento_conn():
    return mysql.connector.connect(**MAGENTO_DB)


def get_val(values, attr, locale=None):
    """Extract value from Akeneo values dict."""
    for v in values.get(attr, []):
        if locale and v.get("locale") != locale:
            continue
        return v.get("data")
    return None


def has_val(values, attr):
    """Check if attribute has a non-empty value."""
    for v in values.get(attr, []):
        if v.get("data") is not None and v.get("data") != "":
            return True
    return False


# ============================================================
# FIX 1: Weight 9999 placeholder values and zeros
# ============================================================
def fix_weight_placeholders(api):
    log("=" * 70)
    log("FIX 1: Cleaning weight=9999 placeholder and weight=0 values")
    log("=" * 70)

    # Get real weights from Magento
    conn = get_magento_conn()
    cur = conn.cursor(dictionary=True)
    cur.execute("""
        SELECT e.sku, d.value as weight
        FROM catalog_product_entity e
        JOIN catalog_product_entity_decimal d ON e.entity_id = d.entity_id AND d.store_id = 0
        JOIN eav_attribute a ON d.attribute_id = a.attribute_id
        WHERE a.attribute_code = 'weight' AND d.value IS NOT NULL AND d.value > 0 AND d.value < 500
    """)
    real_weights = {}
    for row in cur.fetchall():
        w = float(row["weight"])
        if 0 < w < 500:
            # Magento stores in kg; convert to grams if small
            real_weights[row["sku"]] = round(w * 1000, 2) if w < 50 else round(w, 2)
    cur.close()
    conn.close()
    log(f"  Magento real weights loaded: {len(real_weights)}")

    # Scan products
    batch = []
    fixed = 0
    nulled = 0

    for prod in api.get_all_products():
        sku = prod.get("identifier", "")
        vals = prod.get("values", {})
        parent = prod.get("parent")

        w_data = get_val(vals, "weight")
        if not w_data:
            continue

        amt = w_data.get("amount") if isinstance(w_data, dict) else w_data
        try:
            famt = float(str(amt))
        except (ValueError, TypeError):
            continue

        if famt >= 9990 or famt == 0:
            if sku in real_weights:
                batch.append({
                    "identifier": sku,
                    "values": {
                        "weight": [{"locale": None, "scope": None, "data": {
                            "amount": str(real_weights[sku]),
                            "unit": "GRAM",
                        }}]
                    },
                })
                fixed += 1
            else:
                batch.append({
                    "identifier": sku,
                    "values": {
                        "weight": [{"locale": None, "scope": None, "data": None}]
                    },
                })
                nulled += 1

        if len(batch) >= BATCH_SIZE:
            r = api.patch_batch("products", batch)
            log(f"  Batch sent: {len(batch)} items, status={r.status_code if r else 'none'}")
            batch = []

    if batch:
        api.patch_batch("products", batch)

    log(f"  Products - Fixed with real weight: {fixed}, Nulled (no source): {nulled}")

    # Also fix on product models
    batch = []
    model_fixed = 0
    for model in api.get_all_product_models():
        code = model.get("code", "")
        vals = model.get("values", {})

        w_data = get_val(vals, "weight")
        if not w_data:
            continue

        amt = w_data.get("amount") if isinstance(w_data, dict) else w_data
        try:
            famt = float(str(amt))
        except (ValueError, TypeError):
            continue

        if famt >= 9990 or famt == 0:
            batch.append({
                "code": code,
                "values": {
                    "weight": [{"locale": None, "scope": None, "data": None}]
                },
            })
            model_fixed += 1

        if len(batch) >= BATCH_SIZE:
            api.patch_batch("product-models", batch)
            batch = []

    if batch:
        api.patch_batch("product-models", batch)

    total = fixed + nulled + model_fixed
    log(f"  Models fixed: {model_fixed}")
    log(f"  TOTAL weight fixes: {total}")
    log("FIX 1 COMPLETE.\n")
    return total


# ============================================================
# FIX 2: Missing visibility on products + product models
# ============================================================
def fix_visibility(api):
    log("=" * 70)
    log("FIX 2: Setting visibility on all products + models missing it")
    log("=" * 70)

    # Get Magento visibility map
    conn = get_magento_conn()
    cur = conn.cursor(dictionary=True)
    cur.execute("""
        SELECT e.sku, v.value as visibility
        FROM catalog_product_entity e
        JOIN catalog_product_entity_int v ON e.entity_id = v.entity_id AND v.store_id = 0
        JOIN eav_attribute a ON v.attribute_id = a.attribute_id
        WHERE a.attribute_code = 'visibility'
    """)
    mg_visibility = {}
    vis_map = {1: "not_visible_individually", 2: "in_catalog", 3: "in_search", 4: "catalog_and_search"}
    for row in cur.fetchall():
        val = int(row["visibility"])
        mg_visibility[row["sku"]] = vis_map.get(val, "catalog_and_search")
    cur.close()
    conn.close()
    log(f"  Magento visibility data: {len(mg_visibility)}")

    # ---- Fix product models first ----
    log("  Phase A: Fixing product models...")
    batch = []
    model_fixed = 0
    # Build child-to-parent map for deriving model visibility
    child_vis_by_parent = defaultdict(list)
    for prod in api.get_all_products():
        sku = prod.get("identifier", "")
        parent = prod.get("parent")
        if parent and sku in mg_visibility:
            child_vis_by_parent[parent].append(mg_visibility[sku])

    for model in api.get_all_product_models():
        code = model.get("code", "")
        vals = model.get("values", {})

        if has_val(vals, "visibility"):
            continue

        # Derive from children: if any child is catalog_and_search, use that
        child_vis_list = child_vis_by_parent.get(code, [])
        if "catalog_and_search" in child_vis_list:
            vis = "catalog_and_search"
        elif "in_catalog" in child_vis_list:
            vis = "catalog_and_search"
        elif child_vis_list:
            vis = child_vis_list[0]
        else:
            vis = "catalog_and_search"

        batch.append({
            "code": code,
            "values": {
                "visibility": [{"locale": None, "scope": None, "data": vis}]
            },
        })
        model_fixed += 1

        if len(batch) >= BATCH_SIZE:
            api.patch_batch("product-models", batch)
            batch = []

    if batch:
        api.patch_batch("product-models", batch)
    log(f"  Models fixed: {model_fixed}")

    # ---- Fix standalone products ----
    log("  Phase B: Fixing standalone products...")
    batch = []
    prod_fixed = 0
    for prod in api.get_all_products():
        sku = prod.get("identifier", "")
        vals = prod.get("values", {})
        parent = prod.get("parent")

        if has_val(vals, "visibility"):
            continue

        # Only fix standalone products here (variants inherit from model)
        # But we can also try setting on variants directly
        if parent:
            vis = mg_visibility.get(sku, "not_visible_individually")
        else:
            vis = mg_visibility.get(sku, "catalog_and_search")

        batch.append({
            "identifier": sku,
            "values": {
                "visibility": [{"locale": None, "scope": None, "data": vis}]
            },
        })
        prod_fixed += 1

        if len(batch) >= BATCH_SIZE:
            r = api.patch_batch("products", batch)
            batch = []

    if batch:
        api.patch_batch("products", batch)

    total = model_fixed + prod_fixed
    log(f"  Products fixed: {prod_fixed}")
    log(f"  TOTAL visibility fixes: {total}")
    log("FIX 2 COMPLETE.\n")
    return total


# ============================================================
# FIX 3: Missing product_status on products + models
# ============================================================
def fix_product_status(api):
    log("=" * 70)
    log("FIX 3: Setting product_status on all products + models missing it")
    log("=" * 70)

    # Get Magento status
    conn = get_magento_conn()
    cur = conn.cursor(dictionary=True)
    cur.execute("""
        SELECT e.sku, v.value as status
        FROM catalog_product_entity e
        JOIN catalog_product_entity_int v ON e.entity_id = v.entity_id AND v.store_id = 0
        JOIN eav_attribute a ON v.attribute_id = a.attribute_id
        WHERE a.attribute_code = 'status'
    """)
    mg_status = {}
    for row in cur.fetchall():
        mg_status[row["sku"]] = int(row["status"])  # 1=enabled, 2=disabled
    cur.close()
    conn.close()
    log(f"  Magento status data: {len(mg_status)}")

    # Fix product models first
    log("  Phase A: Fixing product models...")
    batch = []
    model_fixed = 0
    child_status_by_parent = defaultdict(list)
    for prod in api.get_all_products():
        sku = prod.get("identifier", "")
        parent = prod.get("parent")
        if parent and sku in mg_status:
            child_status_by_parent[parent].append(mg_status[sku])

    for model in api.get_all_product_models():
        code = model.get("code", "")
        vals = model.get("values", {})

        if has_val(vals, "product_status"):
            continue

        # If any child is enabled in Magento, model is enabled
        child_statuses = child_status_by_parent.get(code, [])
        enabled = any(s == 1 for s in child_statuses) if child_statuses else True

        batch.append({
            "code": code,
            "values": {
                "product_status": [{"locale": None, "scope": None, "data": enabled}]
            },
        })
        model_fixed += 1

        if len(batch) >= BATCH_SIZE:
            api.patch_batch("product-models", batch)
            batch = []

    if batch:
        api.patch_batch("product-models", batch)
    log(f"  Models fixed: {model_fixed}")

    # Fix standalone products
    log("  Phase B: Fixing standalone + variant products...")
    batch = []
    prod_fixed = 0
    for prod in api.get_all_products():
        sku = prod.get("identifier", "")
        vals = prod.get("values", {})

        if has_val(vals, "product_status"):
            continue

        mg_st = mg_status.get(sku, 1)
        enabled = (mg_st == 1)

        batch.append({
            "identifier": sku,
            "values": {
                "product_status": [{"locale": None, "scope": None, "data": enabled}]
            },
        })
        prod_fixed += 1

        if len(batch) >= BATCH_SIZE:
            api.patch_batch("products", batch)
            batch = []

    if batch:
        api.patch_batch("products", batch)

    total = model_fixed + prod_fixed
    log(f"  Products fixed: {prod_fixed}")
    log(f"  TOTAL product_status fixes: {total}")
    log("FIX 3 COMPLETE.\n")
    return total


# ============================================================
# FIX 4: Manufacturer from brand data
# ============================================================
def fix_manufacturer(api):
    log("=" * 70)
    log("FIX 4: Setting manufacturer from Magento brand data")
    log("=" * 70)

    # Check manufacturer attribute exists and is simpleselect
    r = api.get("attributes/manufacturer")
    if r.status_code != 200:
        log("  Manufacturer attribute not found - skipping", "WARN")
        return 0
    mfr_attr = r.json()
    mfr_type = mfr_attr.get("type", "")
    log(f"  Manufacturer type: {mfr_type}")

    if mfr_type != "pim_catalog_simpleselect":
        log("  Manufacturer is not simpleselect, skipping", "WARN")
        return 0

    # Get existing options
    existing_opts = set()
    page = 1
    while True:
        r = api.get("attributes/manufacturer/options", {"limit": 100, "page": page})
        if r.status_code != 200:
            break
        items = r.json().get("_embedded", {}).get("items", [])
        if not items:
            break
        for opt in items:
            existing_opts.add(opt.get("code", ""))
        page += 1
    log(f"  Existing manufacturer options: {len(existing_opts)}")

    # Get brand data from Magento
    conn = get_magento_conn()
    cur = conn.cursor(dictionary=True)
    cur.execute("""
        SELECT e.sku, eaov.value as brand_name
        FROM catalog_product_entity e
        JOIN catalog_product_entity_int v ON e.entity_id = v.entity_id AND v.store_id = 0
        JOIN eav_attribute a ON v.attribute_id = a.attribute_id
        JOIN eav_attribute_option_value eaov ON v.value = eaov.option_id AND eaov.store_id = 0
        WHERE a.attribute_code = 'mgs_brand' AND v.value > 0
    """)
    brand_names = {}
    for row in cur.fetchall():
        if row["brand_name"]:
            brand_names[row["sku"]] = row["brand_name"].strip()
    cur.close()
    conn.close()
    log(f"  Magento brand data: {len(brand_names)} products")

    # Create manufacturer options from unique brands
    unique_brands = set(brand_names.values())
    brand_to_code = {}
    new_options = []
    for brand in unique_brands:
        code = re.sub(r'[^a-zA-Z0-9_]', '_', brand.lower()).strip('_')[:100]
        if not code:
            continue
        brand_to_code[brand] = code
        if code not in existing_opts:
            new_options.append({
                "code": code,
                "attribute": "manufacturer",
                "sort_order": 0,
                "labels": {"en_US": brand, "fr_FR": brand, "ar_DZ": brand},
            })
            existing_opts.add(code)

    if new_options:
        for i in range(0, len(new_options), BATCH_SIZE):
            chunk = new_options[i:i + BATCH_SIZE]
            api.patch_batch("attributes/manufacturer/options", chunk)
        log(f"  Created {len(new_options)} new manufacturer options")
    else:
        log("  No new manufacturer options needed")

    # Update standalone products
    batch = []
    fixed = 0
    for prod in api.get_all_products():
        sku = prod.get("identifier", "")
        vals = prod.get("values", {})
        parent = prod.get("parent")

        if parent:
            continue  # Will be handled via models
        if has_val(vals, "manufacturer"):
            continue

        brand = brand_names.get(sku)
        if brand and brand in brand_to_code:
            batch.append({
                "identifier": sku,
                "values": {
                    "manufacturer": [{"locale": None, "scope": None, "data": brand_to_code[brand]}]
                },
            })
            fixed += 1

        if len(batch) >= BATCH_SIZE:
            api.patch_batch("products", batch)
            batch = []

    if batch:
        api.patch_batch("products", batch)
    log(f"  Standalone products updated: {fixed}")

    # Update product models
    child_brands = {}
    for prod in api.get_all_products():
        parent = prod.get("parent")
        sku = prod.get("identifier", "")
        if parent and sku in brand_names and parent not in child_brands:
            child_brands[parent] = brand_names[sku]

    batch = []
    model_fixed = 0
    for model in api.get_all_product_models():
        code = model.get("code", "")
        vals = model.get("values", {})

        if has_val(vals, "manufacturer"):
            continue

        brand = child_brands.get(code)
        if brand and brand in brand_to_code:
            batch.append({
                "code": code,
                "values": {
                    "manufacturer": [{"locale": None, "scope": None, "data": brand_to_code[brand]}]
                },
            })
            model_fixed += 1

        if len(batch) >= BATCH_SIZE:
            api.patch_batch("product-models", batch)
            batch = []

    if batch:
        api.patch_batch("product-models", batch)

    total = fixed + model_fixed
    log(f"  Models updated: {model_fixed}")
    log(f"  TOTAL manufacturer fixes: {total}")
    log("FIX 4 COMPLETE.\n")
    return total


# ============================================================
# FIX 5: Short/thin descriptions
# ============================================================
def fix_short_descriptions(api):
    log("=" * 70)
    log("FIX 5: Improving too-short descriptions (< 50 chars)")
    log("=" * 70)

    batch = []
    fixed = 0
    batch_models = []
    model_fixed = 0

    for prod in api.get_all_products():
        sku = prod.get("identifier", "")
        vals = prod.get("values", {})
        fam = prod.get("family", "")
        parent = prod.get("parent")

        desc_en = get_val(vals, "description", "en_US")
        if desc_en and len(str(desc_en)) >= 50:
            continue

        name_en = get_val(vals, "name", "en_US") or sku
        brand_v = get_val(vals, "mgs_brand") or get_val(vals, "brand") or ""
        color_v = get_val(vals, "color") or ""
        capacity_v = get_val(vals, "capacity") or ""

        parts = [name_en]
        if brand_v and isinstance(brand_v, str):
            parts.append(f"Brand: {brand_v.replace('_', ' ').title()}")
        if color_v and isinstance(color_v, str):
            parts.append(f"Color: {color_v.replace('_', ' ').title()}")
        if capacity_v and isinstance(capacity_v, str):
            parts.append(f"Capacity: {capacity_v.replace('_', ' ').title()}")
        if fam:
            parts.append(f"Category: {fam.replace('_', ' ').title()}")

        new_desc = f"{name_en}. " + " | ".join(parts[1:])
        new_desc += ". Professional quality supplies from Techno Stationery Algeria."

        update_vals = {
            "description": [
                {"locale": loc, "scope": CHANNEL, "data": new_desc}
                for loc in LOCALES
            ],
        }

        if parent:
            continue  # Descriptions are model-level for variants
        batch.append({"identifier": sku, "values": update_vals})
        fixed += 1

        if len(batch) >= BATCH_SIZE:
            api.patch_batch("products", batch)
            batch = []

    if batch:
        api.patch_batch("products", batch)

    # Also fix on product models
    for model in api.get_all_product_models():
        code = model.get("code", "")
        vals = model.get("values", {})

        desc_en = get_val(vals, "description", "en_US")
        if desc_en and len(str(desc_en)) >= 50:
            continue

        name_en = get_val(vals, "name", "en_US") or code
        fam = model.get("family", "")
        brand_v = get_val(vals, "mgs_brand") or get_val(vals, "brand") or ""

        new_desc = f"{name_en}."
        if brand_v:
            new_desc += f" Brand: {str(brand_v).replace('_', ' ').title()}."
        if fam:
            new_desc += f" Category: {fam.replace('_', ' ').title()}."
        new_desc += " Professional quality supplies from Techno Stationery Algeria."

        batch_models.append({
            "code": code,
            "values": {
                "description": [
                    {"locale": loc, "scope": CHANNEL, "data": new_desc}
                    for loc in LOCALES
                ],
            },
        })
        model_fixed += 1

        if len(batch_models) >= BATCH_SIZE:
            api.patch_batch("product-models", batch_models)
            batch_models = []

    if batch_models:
        api.patch_batch("product-models", batch_models)

    total = fixed + model_fixed
    log(f"  Products improved: {fixed}, Models improved: {model_fixed}")
    log(f"  TOTAL description fixes: {total}")
    log("FIX 5 COMPLETE.\n")
    return total


# ============================================================
# FIX 6: Missing brand on ~204 products
# ============================================================
def fix_missing_brands(api):
    log("=" * 70)
    log("FIX 6: Filling missing brand (mgs_brand) from Magento")
    log("=" * 70)

    conn = get_magento_conn()
    cur = conn.cursor(dictionary=True)
    cur.execute("""
        SELECT e.sku, eaov.value as brand_name
        FROM catalog_product_entity e
        JOIN catalog_product_entity_int v ON e.entity_id = v.entity_id AND v.store_id = 0
        JOIN eav_attribute a ON v.attribute_id = a.attribute_id
        JOIN eav_attribute_option_value eaov ON v.value = eaov.option_id AND eaov.store_id = 0
        WHERE a.attribute_code = 'mgs_brand' AND v.value > 0
    """)
    mg_brands = {}
    for row in cur.fetchall():
        if row["brand_name"]:
            mg_brands[row["sku"]] = row["brand_name"].strip()
    cur.close()
    conn.close()
    log(f"  Magento brand data: {len(mg_brands)} products")

    # Get existing mgs_brand options
    r = api.get("attributes/mgs_brand")
    if r.status_code != 200:
        log("  mgs_brand attribute not found", "WARN")
        return 0
    mgs_type = r.json().get("type")
    log(f"  mgs_brand type: {mgs_type}")

    if mgs_type == "pim_catalog_simpleselect":
        existing_opts = set()
        page = 1
        while True:
            r = api.get("attributes/mgs_brand/options", {"limit": 100, "page": page})
            if r.status_code != 200:
                break
            items = r.json().get("_embedded", {}).get("items", [])
            if not items:
                break
            for opt in items:
                existing_opts.add(opt.get("code", ""))
            page += 1

        brand_to_code = {}
        for brand in set(mg_brands.values()):
            code = re.sub(r'[^a-zA-Z0-9_]', '_', brand.lower()).strip('_')[:100]
            if code:
                brand_to_code[brand] = code
    else:
        brand_to_code = {b: b for b in set(mg_brands.values())}

    batch = []
    fixed = 0
    for prod in api.get_all_products():
        sku = prod.get("identifier", "")
        vals = prod.get("values", {})

        if has_val(vals, "mgs_brand"):
            continue

        brand = mg_brands.get(sku)
        if brand and brand in brand_to_code:
            batch.append({
                "identifier": sku,
                "values": {
                    "mgs_brand": [{"locale": None, "scope": None, "data": brand_to_code[brand]}]
                },
            })
            fixed += 1

        if len(batch) >= BATCH_SIZE:
            api.patch_batch("products", batch)
            batch = []

    if batch:
        api.patch_batch("products", batch)

    log(f"  Brands fixed: {fixed}")
    log("FIX 6 COMPLETE.\n")
    return fixed


# ============================================================
# FIX 7: Disabled products check
# ============================================================
def fix_disabled_products(api):
    log("=" * 70)
    log("FIX 7: Verifying disabled products against Magento source")
    log("=" * 70)

    conn = get_magento_conn()
    cur = conn.cursor(dictionary=True)
    cur.execute("""
        SELECT e.sku, v.value as status
        FROM catalog_product_entity e
        JOIN catalog_product_entity_int v ON e.entity_id = v.entity_id AND v.store_id = 0
        JOIN eav_attribute a ON v.attribute_id = a.attribute_id
        WHERE a.attribute_code = 'status'
    """)
    mg_status = {}
    for row in cur.fetchall():
        mg_status[row["sku"]] = int(row["status"])
    cur.close()
    conn.close()

    batch = []
    enabled_count = 0
    kept_disabled = 0

    for prod in api.get_all_products():
        sku = prod.get("identifier", "")
        vals = prod.get("values", {})

        ps = get_val(vals, "product_status")
        if ps is None or ps is True:
            continue

        # product_status is False = disabled in PIM
        mg_st = mg_status.get(sku, 1)
        if mg_st == 1:
            batch.append({
                "identifier": sku,
                "values": {
                    "product_status": [{"locale": None, "scope": None, "data": True}]
                },
            })
            enabled_count += 1
        else:
            kept_disabled += 1

        if len(batch) >= BATCH_SIZE:
            api.patch_batch("products", batch)
            batch = []

    if batch:
        api.patch_batch("products", batch)

    log(f"  Re-enabled: {enabled_count}, Kept disabled: {kept_disabled}")
    log("FIX 7 COMPLETE.\n")
    return enabled_count


# ============================================================
# FIX 8: Family completeness requirements
# ============================================================
def fix_completeness(api):
    log("=" * 70)
    log("FIX 8: Updating family completeness requirements for ecommerce")
    log("=" * 70)

    base_required = [
        "sku", "name", "description", "short_description",
        "price", "meta_title", "meta_description", "url_key", "image",
    ]

    updated = 0
    for fam_code in FAMILIES:
        r = api.get(f"families/{fam_code}")
        if r.status_code != 200:
            continue
        fam = r.json()
        current_req = fam.get("attribute_requirements", {}).get("ecommerce", [])
        fam_attrs = fam.get("attributes", [])

        new_req = list(set(current_req))
        for attr in base_required:
            if attr in fam_attrs and attr not in new_req:
                new_req.append(attr)

        if sorted(new_req) != sorted(current_req):
            r2 = api.patch(f"families/{fam_code}", {
                "attribute_requirements": {"ecommerce": new_req}
            })
            if r2.status_code in (200, 201, 204):
                added = set(new_req) - set(current_req)
                log(f"  Updated {fam_code}: added {added}")
                updated += 1
            else:
                log(f"  Failed {fam_code}: {r2.status_code} {r2.text[:150]}", "WARN")

    log(f"  Families updated: {updated}")
    log("FIX 8 COMPLETE.\n")
    return updated


# ============================================================
# FIX 9: Enable grid filter on key attributes
# ============================================================
def fix_grid_filters(api):
    log("=" * 70)
    log("FIX 9: Enabling grid filters on key attributes")
    log("=" * 70)

    filterable_attrs = [
        "mgs_brand", "brand", "color", "capacity", "format", "size",
        "visibility", "product_status", "best_seller", "trending",
        "manufacturer", "gender_product", "type_product", "pattern",
        "en_promo", "a_la_une",
    ]

    updated = 0
    for attr_code in filterable_attrs:
        r = api.get(f"attributes/{attr_code}")
        if r.status_code != 200:
            continue
        attr = r.json()
        if not attr.get("useable_as_grid_filter"):
            r2 = api.patch(f"attributes/{attr_code}", {"useable_as_grid_filter": True})
            if r2.status_code in (200, 201, 204):
                updated += 1
                log(f"  Enabled grid filter: {attr_code}")

    log(f"  Attributes updated: {updated}")
    log("FIX 9 COMPLETE.\n")
    return updated


# ============================================================
# FIX 10: Clean up duplicate visibility options
# ============================================================
def fix_visibility_options(api):
    log("=" * 70)
    log("FIX 10: Normalizing visibility options (remove duplicates)")
    log("=" * 70)

    # Current options have duplicates:
    # catalog + in_catalog, search + in_search, catalog_search + catalog_and_search
    # Normalize: keep the descriptive ones, migrate products from old to new

    # Get all options
    r = api.get("attributes/visibility/options", {"limit": 100})
    if r.status_code != 200:
        log("  Could not get visibility options", "WARN")
        return 0

    opts = r.json().get("_embedded", {}).get("items", [])
    opt_codes = [o["code"] for o in opts]
    log(f"  Current visibility options: {opt_codes}")

    # Migration map: old -> new
    migration_map = {
        "catalog": "in_catalog",
        "search": "in_search",
        "catalog_search": "catalog_and_search",
        "not_visible": "not_visible_individually",
    }

    # Scan products and migrate
    batch = []
    migrated = 0
    for prod in api.get_all_products():
        sku = prod.get("identifier", "")
        vals = prod.get("values", {})
        vis = get_val(vals, "visibility")
        if vis and vis in migration_map:
            batch.append({
                "identifier": sku,
                "values": {
                    "visibility": [{"locale": None, "scope": None, "data": migration_map[vis]}]
                },
            })
            migrated += 1

        if len(batch) >= BATCH_SIZE:
            api.patch_batch("products", batch)
            batch = []

    if batch:
        api.patch_batch("products", batch)

    # Also on models
    batch = []
    model_migrated = 0
    for model in api.get_all_product_models():
        code = model.get("code", "")
        vals = model.get("values", {})
        vis = get_val(vals, "visibility")
        if vis and vis in migration_map:
            batch.append({
                "code": code,
                "values": {
                    "visibility": [{"locale": None, "scope": None, "data": migration_map[vis]}]
                },
            })
            model_migrated += 1

        if len(batch) >= BATCH_SIZE:
            api.patch_batch("product-models", batch)
            batch = []

    if batch:
        api.patch_batch("product-models", batch)

    total = migrated + model_migrated
    log(f"  Products migrated: {migrated}, Models migrated: {model_migrated}")
    log(f"  TOTAL visibility option migrations: {total}")
    log("FIX 10 COMPLETE.\n")
    return total


# ============================================================
# AUDIT: Generate comprehensive quality report
# ============================================================
def run_audit(api):
    log("=" * 70)
    log("AUDIT: Comprehensive Data Quality Report")
    log("=" * 70)

    stats = defaultdict(int)
    issues = defaultdict(list)
    total = 0

    for prod in api.get_all_products():
        total += 1
        sku = prod.get("identifier", "")
        vals = prod.get("values", {})
        parent = prod.get("parent")

        # Image
        if has_val(vals, "image"):
            stats["has_image"] += 1
        else:
            issues["no_image"].append(sku)

        # Descriptions all locales
        for loc in LOCALES:
            if get_val(vals, "description", loc):
                stats[f"desc_{loc}"] += 1

        # Short descriptions
        for loc in LOCALES:
            if get_val(vals, "short_description", loc):
                stats[f"short_desc_{loc}"] += 1

        # Brand
        if has_val(vals, "mgs_brand"):
            stats["has_brand"] += 1

        # Weight
        w = get_val(vals, "weight")
        if w:
            stats["has_weight"] += 1
            amt = w.get("amount") if isinstance(w, dict) else w
            try:
                f = float(str(amt))
                if f >= 9990: stats["weight_placeholder"] += 1
                if f == 0: stats["weight_zero"] += 1
            except:
                pass

        # Visibility
        if has_val(vals, "visibility"):
            stats["has_visibility"] += 1

        # Product status
        if has_val(vals, "product_status"):
            stats["has_product_status"] += 1
            if get_val(vals, "product_status") is False:
                stats["disabled"] += 1

        # Manufacturer
        if has_val(vals, "manufacturer"):
            stats["has_manufacturer"] += 1

        # Categories
        if prod.get("categories"):
            stats["has_categories"] += 1

        # Color
        if has_val(vals, "color"):
            stats["has_color"] += 1

        # Meta
        if has_val(vals, "meta_title"):
            stats["has_meta_title"] += 1
        if has_val(vals, "meta_description"):
            stats["has_meta_desc"] += 1
        if has_val(vals, "url_key"):
            stats["has_url_key"] += 1

        # Associations
        assoc = prod.get("associations", {})
        has_assoc = False
        for atype in ["RELATED", "CROSSSELL", "UPSELL", "X_SELL"]:
            prods = assoc.get(atype, {}).get("products", [])
            if prods:
                has_assoc = True
                break
        if has_assoc:
            stats["has_associations"] += 1

    # Product models
    model_total = 0
    models_with_cats = 0
    models_with_vis = 0
    for model in api.get_all_product_models():
        model_total += 1
        if model.get("categories"):
            models_with_cats += 1
        if has_val(model.get("values", {}), "visibility"):
            models_with_vis += 1

    pct = lambda n: f"{round(n / total * 100, 1)}%" if total > 0 else "0%"

    report = f"""
{'='*70}
AKENEO PIM - DATA QUALITY AUDIT REPORT
{'='*70}
Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
Total Products: {total}
Product Models: {model_total} ({models_with_cats} with categories, {models_with_vis} with visibility)

DATA COVERAGE:
  Images:              {stats['has_image']}/{total} ({pct(stats['has_image'])})
  Description en_US:   {stats['desc_en_US']}/{total} ({pct(stats['desc_en_US'])})
  Description fr_FR:   {stats['desc_fr_FR']}/{total} ({pct(stats['desc_fr_FR'])})
  Description ar_DZ:   {stats['desc_ar_DZ']}/{total} ({pct(stats['desc_ar_DZ'])})
  Short desc en_US:    {stats['short_desc_en_US']}/{total} ({pct(stats['short_desc_en_US'])})
  Short desc fr_FR:    {stats['short_desc_fr_FR']}/{total} ({pct(stats['short_desc_fr_FR'])})
  Short desc ar_DZ:    {stats['short_desc_ar_DZ']}/{total} ({pct(stats['short_desc_ar_DZ'])})
  Brand (mgs_brand):   {stats['has_brand']}/{total} ({pct(stats['has_brand'])})
  Manufacturer:        {stats['has_manufacturer']}/{total} ({pct(stats['has_manufacturer'])})
  Weight:              {stats['has_weight']}/{total} ({pct(stats['has_weight'])})
    - Placeholder 9999:{stats['weight_placeholder']}
    - Zero values:     {stats['weight_zero']}
  Visibility:          {stats['has_visibility']}/{total} ({pct(stats['has_visibility'])})
  Product status:      {stats['has_product_status']}/{total} ({pct(stats['has_product_status'])})
    - Disabled:        {stats['disabled']}
  Categories:          {stats['has_categories']}/{total} ({pct(stats['has_categories'])})
  Color:               {stats['has_color']}/{total} ({pct(stats['has_color'])})
  Meta title:          {stats['has_meta_title']}/{total} ({pct(stats['has_meta_title'])})
  Meta description:    {stats['has_meta_desc']}/{total} ({pct(stats['has_meta_desc'])})
  URL key:             {stats['has_url_key']}/{total} ({pct(stats['has_url_key'])})
  Associations:        {stats['has_associations']}/{total} ({pct(stats['has_associations'])})

MISSING IMAGES (first 20): {issues['no_image'][:20]}
{'='*70}
"""
    log(report)

    # Save report
    report_path = os.path.join(WEBAPP, f"AUDIT_REPORT_{datetime.now().strftime('%Y%m%d_%H%M%S')}.txt")
    with open(report_path, "w") as f:
        f.write(report)
    log(f"Report saved to: {report_path}")

    return total


# ============================================================
# MAIN
# ============================================================
def main():
    parser = argparse.ArgumentParser(description="Akeneo PIM Data Perfection")
    parser.add_argument("--weight", action="store_true", help="Fix weight placeholders (9999, 0)")
    parser.add_argument("--visibility", action="store_true", help="Fix missing visibility")
    parser.add_argument("--product-status", action="store_true", help="Fix missing product_status")
    parser.add_argument("--manufacturer", action="store_true", help="Sync manufacturer from brand")
    parser.add_argument("--descriptions", action="store_true", help="Improve short descriptions")
    parser.add_argument("--brands", action="store_true", help="Fix missing brands")
    parser.add_argument("--disabled", action="store_true", help="Fix disabled products")
    parser.add_argument("--completeness", action="store_true", help="Fix family completeness reqs")
    parser.add_argument("--grid-filters", action="store_true", help="Enable grid filters")
    parser.add_argument("--vis-options", action="store_true", help="Normalize visibility options")
    parser.add_argument("--audit", action="store_true", help="Run audit only (no changes)")
    parser.add_argument("--all", action="store_true", help="Run ALL fixes")
    args = parser.parse_args()

    if not any(vars(args).values()):
        parser.print_help()
        sys.exit(1)

    api = AkeneoClient(AKENEO_API)
    api.auth()
    log("Authenticated with Akeneo API")

    log("=" * 70)
    log("DATA PERFECTION STARTED")
    log(f"Timestamp: {datetime.now().isoformat()}")
    log("=" * 70)

    if args.audit:
        run_audit(api)
        return

    results = {}
    try:
        if args.weight or args.all:
            results["weight_fixes"] = fix_weight_placeholders(api)
        if args.visibility or args.all:
            results["visibility_fixes"] = fix_visibility(api)
        if args.product_status or args.all:
            results["product_status_fixes"] = fix_product_status(api)
        if args.manufacturer or args.all:
            results["manufacturer_fixes"] = fix_manufacturer(api)
        if args.descriptions or args.all:
            results["description_fixes"] = fix_short_descriptions(api)
        if args.brands or args.all:
            results["brand_fixes"] = fix_missing_brands(api)
        if args.disabled or args.all:
            results["disabled_fixes"] = fix_disabled_products(api)
        if args.completeness or args.all:
            results["completeness_fixes"] = fix_completeness(api)
        if args.grid_filters or args.all:
            results["grid_filter_fixes"] = fix_grid_filters(api)
        if args.vis_options or args.all:
            results["vis_option_fixes"] = fix_visibility_options(api)
    except Exception as e:
        log(f"FATAL ERROR: {e}", "ERROR")
        traceback.print_exc()
        sys.exit(1)

    log("=" * 70)
    log("SUMMARY:")
    for k, v in results.items():
        log(f"  {k}: {v}")
    log("=" * 70)
    log("DATA PERFECTION COMPLETE")


if __name__ == "__main__":
    main()
