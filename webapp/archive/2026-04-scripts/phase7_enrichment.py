#!/usr/bin/env python3
"""
Akeneo PIM - Phase 7: Content Enrichment
==========================================
Syncs rich content from Magento into Akeneo:

  Phase 7A: Descriptions (en_US from Magento, fr_FR/ar_DZ as copies)
  Phase 7B: Product Images (from Magento media gallery)
  Phase 7C: Brand data (mgs_brand from Magento)
  Phase 7D: Product Model categories (inherit from children)
  Phase 8A: Generate missing descriptions from product names
  Phase 8B: Enrich associations (cross-sell, upsell, related by category)

Usage:
  python3 phase7_enrichment.py --descriptions     # 7A
  python3 phase7_enrichment.py --images           # 7B
  python3 phase7_enrichment.py --brands           # 7C
  python3 phase7_enrichment.py --model-categories # 7D
  python3 phase7_enrichment.py --gen-descriptions # 8A
  python3 phase7_enrichment.py --associations     # 8B
  python3 phase7_enrichment.py --all
"""

import sys, os, json, re, time, argparse, html, traceback
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
MAGENTO_MEDIA_URL = "https://beta.technostationery.com/pub/media/catalog/product"
CHANNEL = "ecommerce"
LOCALES = ["en_US", "fr_FR", "ar_DZ"]
LOG_FILE = "/home/pim/public_html/var/logs/phase7_enrichment.log"
BATCH_SIZE = 100
WEBAPP = "/home/pim/public_html/webapp"


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
            "grant_type": "password", "client_id": self.config["client_id"],
            "client_secret": self.config["client_secret"],
            "username": self.config["username"], "password": self.config["password"],
        })
        if r.status_code != 200:
            raise RuntimeError(f"Auth failed: {r.status_code} {r.text[:200]}")
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

    def patch_batch(self, ep, items):
        body = "\n".join(json.dumps(item) for item in items)
        headers = {**self.h(), "Content-Type": "application/vnd.akeneo.collection+json"}
        r = requests.patch(f"{self.base}/api/rest/v1/{ep}", headers=headers, data=body)
        if r.status_code == 401:
            self.auth()
            headers = {**self.h(), "Content-Type": "application/vnd.akeneo.collection+json"}
            r = requests.patch(f"{self.base}/api/rest/v1/{ep}", headers=headers, data=body)
        return r

    def get_all_products(self):
        search_after = None
        while True:
            params = {"limit": 100, "pagination_type": "search_after"}
            if search_after:
                params["search_after"] = search_after
            r = self.get("products", params)
            if r.status_code != 200:
                break
            items = r.json().get("_embedded", {}).get("items", [])
            if not items:
                break
            yield from items
            search_after = items[-1].get("identifier", "")

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


def clean_html(text):
    """Strip HTML tags and clean up description text."""
    if not text:
        return ""
    text = re.sub(r'<br\s*/?>', '\n', text, flags=re.IGNORECASE)
    text = re.sub(r'</?p[^>]*>', '\n', text, flags=re.IGNORECASE)
    text = re.sub(r'<li[^>]*>', '- ', text, flags=re.IGNORECASE)
    text = re.sub(r'<[^>]+>', '', text)
    text = html.unescape(text)
    text = re.sub(r'\n{3,}', '\n\n', text)
    text = re.sub(r'[ \t]+', ' ', text)
    return text.strip()


# ============================================================
# PHASE 7A: DESCRIPTIONS FROM MAGENTO
# ============================================================
def sync_descriptions(api):
    log("=" * 70)
    log("PHASE 7A: Syncing Descriptions from Magento")
    log("=" * 70)

    conn = mysql.connector.connect(**MAGENTO_DB)
    cur = conn.cursor(dictionary=True)

    # Get descriptions from Magento
    cur.execute("""
        SELECT e.sku,
               MAX(CASE WHEN a.attribute_code = 'description' THEN t.value END) as description,
               MAX(CASE WHEN a.attribute_code = 'short_description' THEN t.value END) as short_description
        FROM catalog_product_entity e
        JOIN catalog_product_entity_text t ON e.entity_id = t.entity_id AND t.store_id = 0
        JOIN eav_attribute a ON t.attribute_id = a.attribute_id
        WHERE a.attribute_code IN ('description', 'short_description')
          AND t.value IS NOT NULL AND t.value != ''
        GROUP BY e.sku
    """)
    magento_data = {}
    for row in cur.fetchall():
        magento_data[row["sku"]] = {
            "description": clean_html(row.get("description", "")),
            "short_description": clean_html(row.get("short_description", "")),
        }
    cur.close()
    conn.close()

    log(f"  Magento descriptions loaded: {len(magento_data)} products")

    # Build Akeneo index of existing descriptions
    batch = []
    updated = 0
    skipped = 0

    for prod in api.get_all_products():
        sku = prod.get("identifier", "")
        vals = prod.get("values", {})

        if sku not in magento_data:
            continue

        mg = magento_data[sku]
        update_vals = {}

        # Description - set for all locales
        desc = mg.get("description", "")
        if desc and len(desc) > 10:
            existing_en = ""
            for v in vals.get("description", []):
                if v.get("locale") == "en_US" and v.get("data", "").strip():
                    existing_en = v["data"]

            if not existing_en or len(existing_en) < len(desc) // 2:
                update_vals["description"] = []
                for loc in LOCALES:
                    update_vals["description"].append({
                        "locale": loc, "scope": CHANNEL, "data": desc
                    })

        # Short description
        short = mg.get("short_description", "")
        if short and len(short) > 5:
            existing_short = ""
            for v in vals.get("short_description", []):
                if v.get("locale") == "en_US" and v.get("data", "").strip():
                    existing_short = v["data"]

            if not existing_short or len(existing_short) < len(short) // 2:
                update_vals["short_description"] = []
                for loc in LOCALES:
                    update_vals["short_description"].append({
                        "locale": loc, "scope": CHANNEL, "data": short
                    })

        if update_vals:
            batch.append({"identifier": sku, "values": update_vals})
            updated += 1
        else:
            skipped += 1

        if len(batch) >= BATCH_SIZE:
            r = api.patch_batch("products", batch)
            if updated <= 200:
                log(f"    Batch sent: {len(batch)} products")
            batch = []

    if batch:
        api.patch_batch("products", batch)

    log(f"  Updated: {updated}, Skipped (already had): {skipped}")
    log("PHASE 7A COMPLETE.\n")
    return updated


# ============================================================
# PHASE 7B: PRODUCT IMAGES FROM MAGENTO
# ============================================================
def sync_images(api):
    log("=" * 70)
    log("PHASE 7B: Syncing Product Images from Magento")
    log("=" * 70)

    conn = mysql.connector.connect(**MAGENTO_DB)
    cur = conn.cursor(dictionary=True)

    # Get image paths from Magento (main image per product)
    cur.execute("""
        SELECT e.sku,
               MAX(CASE WHEN a.attribute_code = 'image' THEN v.value END) as image,
               MAX(CASE WHEN a.attribute_code = 'small_image' THEN v.value END) as small_image,
               MAX(CASE WHEN a.attribute_code = 'thumbnail' THEN v.value END) as thumbnail
        FROM catalog_product_entity e
        JOIN catalog_product_entity_varchar v ON e.entity_id = v.entity_id AND v.store_id = 0
        JOIN eav_attribute a ON v.attribute_id = a.attribute_id
        WHERE a.attribute_code IN ('image', 'small_image', 'thumbnail')
          AND v.value IS NOT NULL AND v.value != '' AND v.value != 'no_selection'
        GROUP BY e.sku
    """)
    magento_images = {}
    for row in cur.fetchall():
        img = row.get("image") or row.get("small_image") or row.get("thumbnail")
        if img:
            magento_images[row["sku"]] = img

    cur.close()
    conn.close()

    log(f"  Magento images loaded: {len(magento_images)} products")

    # Check Akeneo - which products lack images
    # For now, we'll store the Magento image URL in a text attribute
    # since Akeneo image upload via API requires multipart/form-data per product
    # Instead, we'll create a reference list for manual import

    image_manifest = []
    for sku, img_path in magento_images.items():
        full_url = f"{MAGENTO_MEDIA_URL}{img_path}"
        image_manifest.append({
            "sku": sku,
            "magento_path": img_path,
            "url": full_url,
        })

    manifest_file = f"{WEBAPP}/image_import_manifest.json"
    with open(manifest_file, "w") as f:
        json.dump(image_manifest, f, indent=2)

    log(f"  Image manifest saved: {manifest_file} ({len(image_manifest)} entries)")

    # Actually download and upload images via API (first 100 as test)
    uploaded = 0
    errors = 0

    for entry in image_manifest[:500]:
        sku = entry["sku"]
        url = entry["url"]

        try:
            # Download image
            img_r = requests.get(url, timeout=10)
            if img_r.status_code != 200:
                errors += 1
                continue

            # Determine content type
            ct = img_r.headers.get("Content-Type", "image/jpeg")
            ext = "jpg"
            if "png" in ct:
                ext = "png"
            elif "webp" in ct:
                ext = "webp"

            filename = f"{sku}.{ext}"

            # Upload to Akeneo
            api.ensure_auth()
            upload_url = f"{api.base}/api/rest/v1/media-files"
            files = {
                "file": (filename, img_r.content, ct),
            }
            product_data = json.dumps({
                "identifier": sku,
                "attribute": "image",
                "scope": None,
                "locale": None,
            })
            r = requests.post(
                upload_url,
                headers={"Authorization": f"Bearer {api.token}"},
                files=files,
                data={"product": product_data},
            )

            if r.status_code in (201, 204):
                uploaded += 1
            else:
                errors += 1
                if uploaded + errors <= 5:
                    log(f"    Upload error {sku}: {r.status_code} {r.text[:100]}", "WARN")

        except Exception as e:
            errors += 1
            if errors <= 5:
                log(f"    Error {sku}: {e}", "WARN")

        if (uploaded + errors) % 50 == 0:
            log(f"    Progress: {uploaded} uploaded, {errors} errors")

    log(f"  Uploaded: {uploaded}, Errors: {errors}")
    log(f"  Remaining: {len(image_manifest) - 500} (manifest saved for batch import)")
    log("PHASE 7B COMPLETE.\n")
    return uploaded


# ============================================================
# PHASE 7C: BRAND DATA FROM MAGENTO
# ============================================================
def sync_brands(api):
    log("=" * 70)
    log("PHASE 7C: Syncing Brand Data from Magento")
    log("=" * 70)

    conn = mysql.connector.connect(**MAGENTO_DB)
    cur = conn.cursor(dictionary=True)

    # Get brand labels from Magento
    cur.execute("""
        SELECT e.sku, eaov.value as brand_name
        FROM catalog_product_entity e
        JOIN catalog_product_entity_int v ON e.entity_id = v.entity_id AND v.store_id = 0
        JOIN eav_attribute a ON v.attribute_id = a.attribute_id
        JOIN eav_attribute_option_value eaov ON v.value = eaov.option_id AND eaov.store_id = 0
        WHERE a.attribute_code = 'mgs_brand' AND v.value > 0
    """)
    brand_map = {}
    brand_set = set()
    for row in cur.fetchall():
        brand_map[row["sku"]] = row["brand_name"]
        brand_set.add(row["brand_name"])

    cur.close()
    conn.close()

    log(f"  Magento brands loaded: {len(brand_map)} products, {len(brand_set)} unique brands")

    # First, check if 'brand' attribute is simple select or text
    r = api.get("attributes/brand")
    if r.status_code == 200:
        brand_attr = r.json()
        brand_type = brand_attr.get("type", "")
        log(f"  Brand attribute type: {brand_type}")
    else:
        r = api.get("attributes/mgs_brand")
        if r.status_code == 200:
            brand_attr = r.json()
            brand_type = brand_attr.get("type", "")
            log(f"  mgs_brand attribute type: {brand_type}")
        else:
            log("  No brand/mgs_brand attribute found, skipping", "WARN")
            return 0

    attr_code = "mgs_brand" if "mgs_brand" in (brand_attr.get("code", "")) else "brand"

    # If it's a simple select, we need to ensure options exist
    if brand_type == "pim_catalog_simpleselect":
        # Get existing options
        r = api.get(f"attributes/{attr_code}/options", {"limit": 100})
        existing_options = set()
        if r.status_code == 200:
            for opt in r.json().get("_embedded", {}).get("items", []):
                existing_options.add(opt.get("code", ""))

        # Create missing options
        new_options = []
        for brand in brand_set:
            code = re.sub(r'[^a-zA-Z0-9_]', '_', brand.lower()).strip('_')[:100]
            if code and code not in existing_options:
                new_options.append({
                    "code": code,
                    "attribute": attr_code,
                    "sort_order": 0,
                    "labels": {"en_US": brand, "fr_FR": brand, "ar_DZ": brand},
                })
                existing_options.add(code)

        if new_options:
            for i in range(0, len(new_options), BATCH_SIZE):
                chunk = new_options[i:i + BATCH_SIZE]
                body = "\n".join(json.dumps(opt) for opt in chunk)
                headers = {**api.h(), "Content-Type": "application/vnd.akeneo.collection+json"}
                r = requests.patch(
                    f"{api.base}/api/rest/v1/attributes/{attr_code}/options",
                    headers=headers, data=body
                )
            log(f"  Created {len(new_options)} new brand options")

        # Build code map
        brand_to_code = {}
        for brand in brand_set:
            brand_to_code[brand] = re.sub(r'[^a-zA-Z0-9_]', '_', brand.lower()).strip('_')[:100]

        # Update products
        batch = []
        updated = 0
        for prod in api.get_all_products():
            sku = prod.get("identifier", "")
            if sku not in brand_map:
                continue
            vals = prod.get("values", {})
            existing_brand = None
            for v in vals.get(attr_code, []):
                if v.get("data"):
                    existing_brand = v["data"]

            brand_code = brand_to_code.get(brand_map[sku])
            if brand_code and existing_brand != brand_code:
                batch.append({
                    "identifier": sku,
                    "values": {
                        attr_code: [{"locale": None, "scope": None, "data": brand_code}]
                    }
                })
                updated += 1

            if len(batch) >= BATCH_SIZE:
                api.patch_batch("products", batch)
                batch = []

        if batch:
            api.patch_batch("products", batch)

    elif brand_type in ("pim_catalog_text", "pim_catalog_textarea"):
        # Text attribute - just set the string
        batch = []
        updated = 0
        for prod in api.get_all_products():
            sku = prod.get("identifier", "")
            if sku not in brand_map:
                continue
            vals = prod.get("values", {})
            existing = ""
            for v in vals.get(attr_code, []):
                if v.get("data", "").strip():
                    existing = v["data"]

            if not existing:
                batch.append({
                    "identifier": sku,
                    "values": {
                        attr_code: [{"locale": None, "scope": None, "data": brand_map[sku]}]
                    }
                })
                updated += 1

            if len(batch) >= BATCH_SIZE:
                api.patch_batch("products", batch)
                batch = []

        if batch:
            api.patch_batch("products", batch)
    else:
        log(f"  Unsupported brand attribute type: {brand_type}", "WARN")
        return 0

    log(f"  Updated brands: {updated}")
    log("PHASE 7C COMPLETE.\n")
    return updated


# ============================================================
# PHASE 7D: PRODUCT MODEL CATEGORIES
# ============================================================
def fix_model_categories(api):
    log("=" * 70)
    log("PHASE 7D: Assigning Categories to Product Models")
    log("=" * 70)

    # Build map: parent_code -> list of child categories
    parent_cats = defaultdict(lambda: defaultdict(int))

    for prod in api.get_all_products():
        parent = prod.get("parent")
        cats = prod.get("categories", [])
        if parent and cats:
            for c in cats:
                parent_cats[parent][c] += 1

    log(f"  Parent models with child categories: {len(parent_cats)}")

    # Get all product models
    batch = []
    updated = 0
    skipped = 0

    for model in api.get_all_product_models():
        code = model.get("code", "")
        existing_cats = model.get("categories", [])

        if existing_cats:
            skipped += 1
            continue

        if code in parent_cats:
            # Get top 5 most common categories from children
            cat_counts = parent_cats[code]
            top_cats = sorted(cat_counts.keys(), key=lambda c: -cat_counts[c])[:5]
            batch.append({"code": code, "categories": top_cats})
            updated += 1
        else:
            skipped += 1

        if len(batch) >= BATCH_SIZE:
            body = "\n".join(json.dumps(item) for item in batch)
            headers = {**api.h(), "Content-Type": "application/vnd.akeneo.collection+json"}
            r = requests.patch(f"{api.base}/api/rest/v1/product-models", headers=headers, data=body)
            batch = []

    if batch:
        body = "\n".join(json.dumps(item) for item in batch)
        headers = {**api.h(), "Content-Type": "application/vnd.akeneo.collection+json"}
        requests.patch(f"{api.base}/api/rest/v1/product-models", headers=headers, data=body)

    log(f"  Updated: {updated}, Skipped: {skipped}")
    log("PHASE 7D COMPLETE.\n")
    return updated


# ============================================================
# PHASE 8A: GENERATE MISSING DESCRIPTIONS
# ============================================================
def generate_descriptions(api):
    log("=" * 70)
    log("PHASE 8A: Generating Descriptions for Products Without")
    log("=" * 70)

    batch = []
    updated = 0

    for prod in api.get_all_products():
        sku = prod.get("identifier", "")
        vals = prod.get("values", {})

        # Check if already has en_US description
        has_desc = any(
            v.get("locale") == "en_US" and v.get("data", "").strip()
            for v in vals.get("description", [])
        )

        if has_desc:
            continue

        # Generate from name + attributes
        name = ""
        for v in vals.get("name", []):
            if v.get("locale") == "en_US" and v.get("data"):
                name = v["data"]
                break

        if not name:
            continue

        # Gather attribute values
        parts = [name]
        for attr in ["brand", "mgs_brand", "color", "capacity", "dimension", "format"]:
            for v in vals.get(attr, []):
                val = v.get("data", "")
                if val and isinstance(val, str):
                    parts.append(val.replace("_", " ").title())

        # Build description
        desc = f"{name}. "
        if len(parts) > 1:
            desc += "Features: " + ", ".join(parts[1:]) + ". "
        desc += "Available at Techno Stationery."

        # Short description
        short = name
        if len(short) > 150:
            short = short[:147] + "..."

        update_vals = {
            "description": [
                {"locale": loc, "scope": CHANNEL, "data": desc}
                for loc in LOCALES
            ],
        }
        # Only set short_description if missing
        has_short = any(
            v.get("locale") == "en_US" and v.get("data", "").strip()
            for v in vals.get("short_description", [])
        )
        if not has_short:
            update_vals["short_description"] = [
                {"locale": loc, "scope": CHANNEL, "data": short}
                for loc in LOCALES
            ]

        batch.append({"identifier": sku, "values": update_vals})
        updated += 1

        if len(batch) >= BATCH_SIZE:
            api.patch_batch("products", batch)
            batch = []

    if batch:
        api.patch_batch("products", batch)

    log(f"  Generated descriptions: {updated}")
    log("PHASE 8A COMPLETE.\n")
    return updated


# ============================================================
# PHASE 8B: PRODUCT ASSOCIATIONS
# ============================================================
def enrich_associations(api):
    log("=" * 70)
    log("PHASE 8B: Enriching Product Associations by Category")
    log("=" * 70)

    # Build category -> product index
    cat_products = defaultdict(list)
    product_cats = {}
    product_families = {}

    for prod in api.get_all_products():
        sku = prod.get("identifier", "")
        cats = prod.get("categories", [])
        fam = prod.get("family", "")
        product_cats[sku] = cats
        product_families[sku] = fam
        for c in cats:
            cat_products[c].append(sku)

    log(f"  Products indexed: {len(product_cats)}")
    log(f"  Categories with products: {len(cat_products)}")

    # For each product, find related/cross-sell/upsell from same categories
    batch = []
    updated = 0

    for prod in api.get_all_products():
        sku = prod.get("identifier", "")
        cats = product_cats.get(sku, [])
        fam = product_families.get(sku, "")

        # Check if already has associations
        assoc = prod.get("associations", {})
        has_related = bool(assoc.get("RELATED", {}).get("products"))
        has_crosssell = bool(assoc.get("CROSSSELL", {}).get("products"))
        has_upsell = bool(assoc.get("UPSELL", {}).get("products"))

        if has_related and has_crosssell and has_upsell:
            continue

        # Find related products (same category, same family)
        related = set()
        crosssell = set()
        upsell = set()

        for c in cats[:3]:  # Top 3 categories
            siblings = cat_products.get(c, [])
            for s in siblings:
                if s == sku:
                    continue
                if product_families.get(s) == fam:
                    related.add(s)
                else:
                    crosssell.add(s)

                if len(related) >= 5 and len(crosssell) >= 5:
                    break

        # Upsell: same family, different categories
        for c in cats[:2]:
            siblings = cat_products.get(c, [])
            for s in siblings:
                if s != sku and product_families.get(s) == fam and s not in related:
                    upsell.add(s)
                if len(upsell) >= 3:
                    break

        new_assoc = {}
        if not has_related and related:
            new_assoc["RELATED"] = {"products": list(related)[:5]}
        if not has_crosssell and crosssell:
            new_assoc["CROSSSELL"] = {"products": list(crosssell)[:5]}
        if not has_upsell and upsell:
            new_assoc["UPSELL"] = {"products": list(upsell)[:3]}

        if new_assoc:
            batch.append({"identifier": sku, "associations": new_assoc})
            updated += 1

        if len(batch) >= BATCH_SIZE:
            api.patch_batch("products", batch)
            batch = []

    if batch:
        api.patch_batch("products", batch)

    log(f"  Products with new associations: {updated}")
    log("PHASE 8B COMPLETE.\n")
    return updated


# ============================================================
# MAIN
# ============================================================
def main():
    parser = argparse.ArgumentParser(description="Akeneo PIM Phase 7+: Content Enrichment")
    parser.add_argument("--descriptions", action="store_true", help="7A: Sync descriptions from Magento")
    parser.add_argument("--images", action="store_true", help="7B: Sync product images")
    parser.add_argument("--brands", action="store_true", help="7C: Sync brand data")
    parser.add_argument("--model-categories", action="store_true", help="7D: Fix product model categories")
    parser.add_argument("--gen-descriptions", action="store_true", help="8A: Generate missing descriptions")
    parser.add_argument("--associations", action="store_true", help="8B: Enrich associations")
    parser.add_argument("--all", action="store_true", help="Run all phases")
    args = parser.parse_args()

    if not any(vars(args).values()):
        parser.print_help()
        sys.exit(1)

    api = AkeneoClient(AKENEO_API)
    api.auth()

    log("=" * 70)
    log("AKENEO PIM PHASE 7+ ENRICHMENT STARTED")
    log(f"Timestamp: {datetime.now().isoformat()}")
    log("=" * 70)

    results = {}
    try:
        if args.descriptions or args.all:
            results["7A_descriptions"] = sync_descriptions(api)
        if args.images or args.all:
            results["7B_images"] = sync_images(api)
        if args.brands or args.all:
            results["7C_brands"] = sync_brands(api)
        if args.model_categories or args.all:
            results["7D_model_categories"] = fix_model_categories(api)
        if args.gen_descriptions or args.all:
            results["8A_gen_descriptions"] = generate_descriptions(api)
        if args.associations or args.all:
            results["8B_associations"] = enrich_associations(api)
    except Exception as e:
        log(f"FATAL ERROR: {e}", "ERROR")
        traceback.print_exc()
        sys.exit(1)

    log("=" * 70)
    log("SUMMARY:")
    for k, v in results.items():
        log(f"  {k}: {v}")
    log("=" * 70)
    log("PHASE 7+ ENRICHMENT COMPLETE")


if __name__ == "__main__":
    main()
