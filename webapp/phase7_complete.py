#!/usr/bin/env python3
"""
Akeneo PIM - Phase 7-9: Complete Enrichment & Tuning
=====================================================
Comprehensive script to sync all missing data from Magento and fix PIM issues.

Tasks:
  --setup-image        Create image attribute, add to families
  --fix-category-labels Fix missing ar_DZ labels on categories
  --descriptions       7A: Sync descriptions from Magento (all locales)
  --images             7B: Download & upload product images from Magento
  --brands             7C: Sync brand/mgs_brand data from Magento
  --model-categories   7D: Assign categories to product models from children
  --gen-descriptions   8A: Generate descriptions for products still missing them
  --associations       8B: Build cross-sell/upsell/related associations
  --weight             Sync weight data from Magento
  --audit              Final data quality audit
  --all                Run everything

Usage:
  python3 phase7_complete.py --all
  python3 phase7_complete.py --descriptions --images --brands
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
MAGENTO_MEDIA_BASE = "https://beta.technostationery.com/pub/media/catalog/product"
MAGENTO_MEDIA_DIR = "/home/beta/public_html/pub/media/catalog/product"
CHANNEL = "ecommerce"
LOCALES = ["en_US", "fr_FR", "ar_DZ"]
LOG_FILE = "/home/pim/public_html/var/logs/phase7_complete.log"
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

    def post(self, ep, json_data=None, **kwargs):
        r = requests.post(f"{self.base}/api/rest/v1/{ep}", headers=self.h(), json=json_data, **kwargs)
        if r.status_code == 401:
            self.auth()
            r = requests.post(f"{self.base}/api/rest/v1/{ep}", headers=self.h(), json=json_data, **kwargs)
        return r

    def patch(self, ep, json_data):
        r = requests.patch(f"{self.base}/api/rest/v1/{ep}", headers=self.h(), json=json_data)
        if r.status_code == 401:
            self.auth()
            r = requests.patch(f"{self.base}/api/rest/v1/{ep}", headers=self.h(), json=json_data)
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

    def get_all_categories(self):
        page = 1
        while True:
            r = self.get("categories", {"limit": 100, "page": page})
            if r.status_code != 200:
                break
            items = r.json().get("_embedded", {}).get("items", [])
            if not items:
                break
            yield from items
            page += 1


# ============================================================
# SETUP: Create image attribute & add to families
# ============================================================
def setup_image_attribute(api):
    log("=" * 70)
    log("SETUP: Creating image attribute and adding to all families")
    log("=" * 70)

    # Check if image attribute already exists
    r = api.get("attributes/image")
    if r.status_code == 200:
        log("  Image attribute already exists")
    else:
        # Create image attribute
        attr_data = {
            "code": "image",
            "type": "pim_catalog_image",
            "group": "media",
            "unique": False,
            "useable_as_grid_filter": False,
            "allowed_extensions": ["jpg", "jpeg", "png", "gif"],
            "max_file_size": "10",
            "labels": {
                "en_US": "Main Image",
                "fr_FR": "Image principale",
                "ar_DZ": "الصورة الرئيسية",
            },
            "localizable": False,
            "scopable": False,
        }
        r = requests.post(
            f"{api.base}/api/rest/v1/attributes",
            headers={**api.h(), "Content-Type": "application/json"},
            json=attr_data,
        )
        if r.status_code in (201, 204):
            log("  Created 'image' attribute (pim_catalog_image)")
        else:
            log(f"  Failed to create image attribute: {r.status_code} {r.text[:200]}", "ERROR")
            return 0

    # Also create additional_images for gallery
    r = api.get("attributes/additional_images")
    if r.status_code != 200:
        attr_data = {
            "code": "additional_images",
            "type": "pim_catalog_image",
            "group": "media",
            "unique": False,
            "useable_as_grid_filter": False,
            "allowed_extensions": ["jpg", "jpeg", "png", "gif"],
            "max_file_size": "10",
            "labels": {
                "en_US": "Additional Image",
                "fr_FR": "Image supplémentaire",
                "ar_DZ": "صورة إضافية",
            },
            "localizable": False,
            "scopable": True,
        }
        r = requests.post(
            f"{api.base}/api/rest/v1/attributes",
            headers={**api.h(), "Content-Type": "application/json"},
            json=attr_data,
        )
        if r.status_code in (201, 204):
            log("  Created 'additional_images' attribute")
        else:
            log(f"  additional_images creation: {r.status_code} {r.text[:200]}", "WARN")

    # Add image attribute to all families
    added = 0
    for fam_code in FAMILIES:
        r = api.get(f"families/{fam_code}")
        if r.status_code != 200:
            continue
        fam = r.json()
        attrs = fam.get("attributes", [])
        need_update = False

        if "image" not in attrs:
            attrs.append("image")
            need_update = True
        if "additional_images" not in attrs:
            attrs.append("additional_images")
            need_update = True

        if need_update:
            r = api.patch(f"families/{fam_code}", {"attributes": attrs})
            if r.status_code in (200, 201, 204):
                log(f"  Added image attributes to family '{fam_code}'")
                added += 1
            else:
                log(f"  Failed to update family '{fam_code}': {r.status_code} {r.text[:200]}", "WARN")
        else:
            log(f"  Family '{fam_code}' already has image attributes")

    # Set 'image' as the attribute used for product image in families
    for fam_code in FAMILIES:
        r = api.get(f"families/{fam_code}")
        if r.status_code == 200:
            fam = r.json()
            if fam.get("attribute_as_image") != "image":
                r = api.patch(f"families/{fam_code}", {"attribute_as_image": "image"})
                if r.status_code in (200, 201, 204):
                    log(f"  Set 'image' as thumbnail attribute for '{fam_code}'")

    log(f"  Setup complete. Families updated: {added}")
    log("SETUP: IMAGE ATTRIBUTE COMPLETE.\n")
    return added


# ============================================================
# FIX: Category labels (ar_DZ missing)
# ============================================================
def fix_category_labels(api):
    log("=" * 70)
    log("FIX: Fixing missing category labels (ar_DZ)")
    log("=" * 70)

    batch = []
    fixed = 0

    for cat in api.get_all_categories():
        code = cat.get("code", "")
        labels = cat.get("labels", {})

        en_label = labels.get("en_US", "").strip()
        fr_label = labels.get("fr_FR", "").strip()
        ar_label = labels.get("ar_DZ", "").strip()

        updates = {}
        # Use en_US or fr_FR as fallback for missing labels
        base_label = en_label or fr_label or code.replace("_", " ").title()

        if not en_label:
            updates["en_US"] = base_label
        if not fr_label:
            updates["fr_FR"] = base_label
        if not ar_label:
            updates["ar_DZ"] = base_label

        if updates:
            new_labels = {**labels, **updates}
            batch.append({"code": code, "labels": new_labels})
            fixed += 1

        if len(batch) >= BATCH_SIZE:
            api.patch_batch("categories", batch)
            log(f"    Batch: updated {len(batch)} categories")
            batch = []

    if batch:
        api.patch_batch("categories", batch)

    log(f"  Fixed {fixed} categories with missing labels")
    log("FIX: CATEGORY LABELS COMPLETE.\n")
    return fixed


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

    batch = []
    updated = 0
    skipped = 0
    batch_num = 0

    for prod in api.get_all_products():
        sku = prod.get("identifier", "")
        vals = prod.get("values", {})

        if sku not in magento_data:
            continue

        mg = magento_data[sku]
        update_vals = {}

        # Description - check each locale
        desc = mg.get("description", "")
        if desc and len(desc) > 10:
            desc_updates = []
            for loc in LOCALES:
                existing = ""
                for v in vals.get("description", []):
                    if v.get("locale") == loc and v.get("scope") == CHANNEL and v.get("data", "").strip():
                        existing = v["data"]
                if not existing or len(existing) < 20:
                    desc_updates.append({"locale": loc, "scope": CHANNEL, "data": desc})

            if desc_updates:
                # Preserve any existing good descriptions
                for v in vals.get("description", []):
                    if v.get("data", "").strip() and len(v["data"]) >= 20:
                        # Don't overwrite good data
                        desc_updates = [u for u in desc_updates if u["locale"] != v["locale"]]
                        if v not in desc_updates:
                            desc_updates.append(v)
                if desc_updates:
                    update_vals["description"] = desc_updates

        # Short description - check each locale
        short = mg.get("short_description", "")
        if short and len(short) > 5:
            short_updates = []
            for loc in LOCALES:
                existing = ""
                for v in vals.get("short_description", []):
                    if v.get("locale") == loc and v.get("scope") == CHANNEL and v.get("data", "").strip():
                        existing = v["data"]
                if not existing or len(existing) < 10:
                    short_updates.append({"locale": loc, "scope": CHANNEL, "data": short})

            if short_updates:
                for v in vals.get("short_description", []):
                    if v.get("data", "").strip() and len(v["data"]) >= 10:
                        short_updates = [u for u in short_updates if u["locale"] != v["locale"]]
                        if v not in short_updates:
                            short_updates.append(v)
                if short_updates:
                    update_vals["short_description"] = short_updates

        if update_vals:
            batch.append({"identifier": sku, "values": update_vals})
            updated += 1
        else:
            skipped += 1

        if len(batch) >= BATCH_SIZE:
            r = api.patch_batch("products", batch)
            batch_num += 1
            if batch_num % 10 == 0:
                log(f"    Batch {batch_num}: {updated} updated so far")
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

    # Get ALL image paths from Magento gallery (ordered by position)
    cur.execute("""
        SELECT e.sku, g.value as path, gv.position, gv.label
        FROM catalog_product_entity e
        JOIN catalog_product_entity_media_gallery_value_to_entity gte
            ON e.entity_id = gte.entity_id
        JOIN catalog_product_entity_media_gallery g
            ON gte.value_id = g.value_id
        LEFT JOIN catalog_product_entity_media_gallery_value gv
            ON g.value_id = gv.value_id AND gv.store_id = 0
        WHERE g.media_type = 'image' AND g.disabled = 0
        ORDER BY e.sku, COALESCE(gv.position, 999)
    """)
    magento_images = defaultdict(list)
    for row in cur.fetchall():
        magento_images[row["sku"]].append({
            "path": row["path"],
            "position": row.get("position", 999),
            "label": row.get("label", ""),
        })

    cur.close()
    conn.close()

    log(f"  Magento images loaded: {len(magento_images)} products, "
        f"{sum(len(v) for v in magento_images.values())} total images")

    # Save manifest for reference
    manifest = []
    for sku, imgs in magento_images.items():
        for img in imgs:
            manifest.append({
                "sku": sku,
                "path": img["path"],
                "url": f"{MAGENTO_MEDIA_BASE}{img['path']}",
                "position": img["position"],
            })
    with open(f"{WEBAPP}/image_import_manifest.json", "w") as f:
        json.dump(manifest, f, indent=2)
    log(f"  Manifest saved: {len(manifest)} entries")

    # Check which products already have images in Akeneo
    products_with_images = set()
    for prod in api.get_all_products():
        sku = prod.get("identifier", "")
        vals = prod.get("values", {})
        if vals.get("image"):
            for v in vals["image"]:
                if v.get("data"):
                    products_with_images.add(sku)
                    break
    log(f"  Products already with images in PIM: {len(products_with_images)}")

    # Upload images - main image per product
    uploaded = 0
    errors = 0
    skip_has = 0
    skus_to_upload = [sku for sku in magento_images if sku not in products_with_images]
    total_to_upload = len(skus_to_upload)
    log(f"  Products needing images: {total_to_upload}")

    for idx, sku in enumerate(skus_to_upload):
        imgs = magento_images[sku]
        if not imgs:
            continue

        main_img = imgs[0]  # First image by position
        img_path = main_img["path"]

        try:
            # Try local file first (faster)
            local_path = f"{MAGENTO_MEDIA_DIR}{img_path}"
            if os.path.exists(local_path):
                with open(local_path, "rb") as f:
                    img_content = f.read()
            else:
                # Download from URL
                url = f"{MAGENTO_MEDIA_BASE}{img_path}"
                img_r = requests.get(url, timeout=15)
                if img_r.status_code != 200:
                    errors += 1
                    continue
                img_content = img_r.content

            # Determine extension
            ext = img_path.rsplit(".", 1)[-1].lower() if "." in img_path else "jpg"
            if ext not in ("jpg", "jpeg", "png", "gif", "webp"):
                ext = "jpg"
            ct_map = {"jpg": "image/jpeg", "jpeg": "image/jpeg", "png": "image/png",
                       "gif": "image/gif", "webp": "image/webp"}
            ct = ct_map.get(ext, "image/jpeg")

            # Sanitize filename
            safe_sku = re.sub(r'[^a-zA-Z0-9_\-]', '_', sku)
            filename = f"{safe_sku}.{ext}"

            # Upload to Akeneo media files
            api.ensure_auth()
            upload_url = f"{api.base}/api/rest/v1/media-files"
            product_data = json.dumps({
                "identifier": sku,
                "attribute": "image",
                "scope": None,
                "locale": None,
            })
            r = requests.post(
                upload_url,
                headers={"Authorization": f"Bearer {api.token}"},
                files={"file": (filename, img_content, ct)},
                data={"product": product_data},
            )

            if r.status_code in (201, 204):
                uploaded += 1
            else:
                errors += 1
                if errors <= 10:
                    log(f"    Upload error {sku}: {r.status_code} {r.text[:150]}", "WARN")

        except Exception as e:
            errors += 1
            if errors <= 10:
                log(f"    Error {sku}: {e}", "WARN")

        if (uploaded + errors) % 200 == 0 and (uploaded + errors) > 0:
            log(f"    Progress: {uploaded}/{total_to_upload} uploaded, {errors} errors "
                f"({(uploaded+errors)*100//total_to_upload}%)")

        # Re-auth every 500 images to avoid token expiry
        if (uploaded + errors) % 500 == 0:
            try:
                api.auth()
            except Exception:
                pass

    log(f"  Uploaded: {uploaded}, Errors: {errors}, Already had: {len(products_with_images)}")
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

    # Check mgs_brand attribute type
    r = api.get("attributes/mgs_brand")
    if r.status_code != 200:
        log("  mgs_brand attribute not found in PIM, skipping", "WARN")
        return 0

    brand_attr = r.json()
    brand_type = brand_attr.get("type", "")
    attr_code = "mgs_brand"
    log(f"  mgs_brand attribute type: {brand_type}")

    if brand_type == "pim_catalog_simpleselect":
        # Get existing options
        existing_options = set()
        page = 1
        while True:
            r = api.get(f"attributes/{attr_code}/options", {"limit": 100, "page": page})
            if r.status_code != 200:
                break
            items = r.json().get("_embedded", {}).get("items", [])
            if not items:
                break
            for opt in items:
                existing_options.add(opt.get("code", ""))
            page += 1

        log(f"  Existing brand options: {len(existing_options)}")

        # Create missing options
        brand_to_code = {}
        new_options = []
        for brand in brand_set:
            code = re.sub(r'[^a-zA-Z0-9_]', '_', brand.lower()).strip('_')[:100]
            if not code:
                code = "brand_" + str(abs(hash(brand)) % 10000)
            brand_to_code[brand] = code
            if code not in existing_options:
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
                requests.patch(
                    f"{api.base}/api/rest/v1/attributes/{attr_code}/options",
                    headers=headers, data=body,
                )
            log(f"  Created {len(new_options)} new brand options")

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
                    },
                })
                updated += 1

            if len(batch) >= BATCH_SIZE:
                api.patch_batch("products", batch)
                batch = []

        if batch:
            api.patch_batch("products", batch)

        # Also set brand text attribute from mgs_brand
        r_brand = api.get("attributes/brand")
        if r_brand.status_code == 200:
            brand_text_type = r_brand.json().get("type", "")
            if brand_text_type in ("pim_catalog_text", "pim_catalog_textarea"):
                batch = []
                for prod in api.get_all_products():
                    sku = prod.get("identifier", "")
                    if sku not in brand_map:
                        continue
                    vals = prod.get("values", {})
                    existing = ""
                    for v in vals.get("brand", []):
                        if v.get("data", "").strip():
                            existing = v["data"]
                    if not existing:
                        batch.append({
                            "identifier": sku,
                            "values": {
                                "brand": [{"locale": None, "scope": None, "data": brand_map[sku]}]
                            },
                        })
                    if len(batch) >= BATCH_SIZE:
                        api.patch_batch("products", batch)
                        batch = []
                if batch:
                    api.patch_batch("products", batch)
                log(f"  Also updated text 'brand' attribute")

    elif brand_type in ("pim_catalog_text", "pim_catalog_textarea"):
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
                    },
                })
                updated += 1
            if len(batch) >= BATCH_SIZE:
                api.patch_batch("products", batch)
                batch = []
        if batch:
            api.patch_batch("products", batch)

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

    # Also check sub-models that have a parent (2-level hierarchy)
    sub_model_parents = {}
    for model in api.get_all_product_models():
        code = model.get("code", "")
        parent = model.get("parent")
        if parent:
            sub_model_parents[code] = parent

    # Propagate sub-model categories up to root models
    for sub_code, root_code in sub_model_parents.items():
        if sub_code in parent_cats:
            for cat, count in parent_cats[sub_code].items():
                parent_cats[root_code][cat] += count

    # Get all product models and fix those missing categories
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
            cat_counts = parent_cats[code]
            top_cats = sorted(cat_counts.keys(), key=lambda c: -cat_counts[c])[:5]
            batch.append({"code": code, "categories": top_cats})
            updated += 1
        else:
            skipped += 1

        if len(batch) >= BATCH_SIZE:
            body = "\n".join(json.dumps(item) for item in batch)
            headers = {**api.h(), "Content-Type": "application/vnd.akeneo.collection+json"}
            requests.patch(f"{api.base}/api/rest/v1/product-models", headers=headers, data=body)
            log(f"    Batch: updated {len(batch)} models")
            batch = []

    if batch:
        body = "\n".join(json.dumps(item) for item in batch)
        headers = {**api.h(), "Content-Type": "application/vnd.akeneo.collection+json"}
        requests.patch(f"{api.base}/api/rest/v1/product-models", headers=headers, data=body)

    log(f"  Updated: {updated}, Skipped (already had or no children): {skipped}")
    log("PHASE 7D COMPLETE.\n")
    return updated


# ============================================================
# SYNC WEIGHT FROM MAGENTO
# ============================================================
def sync_weight(api):
    log("=" * 70)
    log("SYNC: Weight data from Magento")
    log("=" * 70)

    conn = mysql.connector.connect(**MAGENTO_DB)
    cur = conn.cursor(dictionary=True)

    cur.execute("""
        SELECT e.sku, d.value as weight
        FROM catalog_product_entity e
        JOIN catalog_product_entity_decimal d ON e.entity_id = d.entity_id AND d.store_id = 0
        JOIN eav_attribute a ON d.attribute_id = a.attribute_id
        WHERE a.attribute_code = 'weight' AND d.value IS NOT NULL AND d.value > 0
    """)
    weight_map = {}
    for row in cur.fetchall():
        w = float(row["weight"])
        # Magento weight is typically in kg; convert to grams for PIM
        # But check if values seem already in grams (>100)
        if w > 0:
            weight_map[row["sku"]] = w

    cur.close()
    conn.close()

    log(f"  Magento weights loaded: {len(weight_map)} products")

    # Check current weight unit in PIM
    r = api.get("attributes/weight")
    if r.status_code == 200:
        weight_attr = r.json()
        metric_family = weight_attr.get("metric_family", "")
        default_unit = weight_attr.get("default_metric_unit", "GRAM")
        log(f"  Weight attribute: metric_family={metric_family}, default_unit={default_unit}")
    else:
        log("  Weight attribute not found in PIM", "WARN")
        return 0

    batch = []
    updated = 0

    for prod in api.get_all_products():
        sku = prod.get("identifier", "")
        if sku not in weight_map:
            continue
        vals = prod.get("values", {})

        # Check existing weight
        has_good_weight = False
        for v in vals.get("weight", []):
            d = v.get("data", {})
            if d and d.get("amount") and float(d["amount"]) > 0 and float(d["amount"]) < 9999:
                has_good_weight = True
                break

        if has_good_weight:
            continue

        mg_weight = weight_map[sku]
        # Convert: if weight is < 100, assume kg, convert to grams
        # If weight is >= 100, assume it's already grams
        if mg_weight < 100:
            weight_grams = mg_weight * 1000
        else:
            weight_grams = mg_weight

        # Clamp unreasonable values
        if weight_grams > 50000:
            weight_grams = 0
            continue

        batch.append({
            "identifier": sku,
            "values": {
                "weight": [{"locale": None, "scope": None, "data": {
                    "amount": str(round(weight_grams, 2)),
                    "unit": default_unit,
                }}]
            },
        })
        updated += 1

        if len(batch) >= BATCH_SIZE:
            api.patch_batch("products", batch)
            batch = []

    if batch:
        api.patch_batch("products", batch)

    log(f"  Updated weights: {updated}")
    log("SYNC WEIGHT COMPLETE.\n")
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

        # Check all locales for description
        missing_desc_locales = []
        missing_short_locales = []

        for loc in LOCALES:
            has_desc = any(
                v.get("locale") == loc and v.get("scope") == CHANNEL and v.get("data", "").strip()
                for v in vals.get("description", [])
            )
            has_short = any(
                v.get("locale") == loc and v.get("scope") == CHANNEL and v.get("data", "").strip()
                for v in vals.get("short_description", [])
            )
            if not has_desc:
                missing_desc_locales.append(loc)
            if not has_short:
                missing_short_locales.append(loc)

        if not missing_desc_locales and not missing_short_locales:
            continue

        # Get the product name
        name = ""
        for v in vals.get("name", []):
            if v.get("locale") == "en_US" and v.get("data"):
                name = v["data"]
                break
        if not name:
            for v in vals.get("name", []):
                if v.get("data"):
                    name = v["data"]
                    break

        if not name:
            continue

        # Gather attribute info for richer descriptions
        parts = [name]
        for attr in ["brand", "mgs_brand", "color", "capacity", "dimension", "format", "size"]:
            for v in vals.get(attr, []):
                val = v.get("data", "")
                if val and isinstance(val, str) and val not in ("None", "none"):
                    parts.append(val.replace("_", " ").title())

        family = prod.get("family", "")
        cats = prod.get("categories", [])

        # Build description
        desc = f"{name}."
        if len(parts) > 1:
            desc += " " + " | ".join(parts[1:]) + "."
        if family:
            desc += f" Category: {family.replace('_', ' ').title()}."
        desc += " Available at Techno Stationery Algeria."

        short = name
        if len(short) > 150:
            short = short[:147] + "..."

        update_vals = {}

        if missing_desc_locales:
            # Build desc updates only for missing locales, preserve existing
            desc_entries = []
            for v in vals.get("description", []):
                if v.get("data", "").strip():
                    desc_entries.append(v)
            for loc in missing_desc_locales:
                desc_entries.append({"locale": loc, "scope": CHANNEL, "data": desc})
            update_vals["description"] = desc_entries

        if missing_short_locales:
            short_entries = []
            for v in vals.get("short_description", []):
                if v.get("data", "").strip():
                    short_entries.append(v)
            for loc in missing_short_locales:
                short_entries.append({"locale": loc, "scope": CHANNEL, "data": short})
            update_vals["short_description"] = short_entries

        if update_vals:
            batch.append({"identifier": sku, "values": update_vals})
            updated += 1

        if len(batch) >= BATCH_SIZE:
            api.patch_batch("products", batch)
            if updated % 500 == 0:
                log(f"    Progress: {updated} generated")
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

    batch = []
    updated = 0

    for prod in api.get_all_products():
        sku = prod.get("identifier", "")
        cats = product_cats.get(sku, [])
        fam = product_families.get(sku, "")

        assoc = prod.get("associations", {})
        has_related = bool(assoc.get("RELATED", {}).get("products"))
        has_crosssell = bool(assoc.get("CROSSSELL", {}).get("products"))
        has_upsell = bool(assoc.get("UPSELL", {}).get("products"))

        if has_related and has_crosssell and has_upsell:
            continue

        related = set()
        crosssell = set()
        upsell = set()

        for c in cats[:3]:
            siblings = cat_products.get(c, [])
            for s in siblings:
                if s == sku:
                    continue
                if product_families.get(s) == fam:
                    if len(related) < 5:
                        related.add(s)
                    elif len(upsell) < 3:
                        upsell.add(s)
                else:
                    if len(crosssell) < 5:
                        crosssell.add(s)

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
            if updated % 500 == 0:
                log(f"    Progress: {updated} products")
            batch = []

    if batch:
        api.patch_batch("products", batch)

    log(f"  Products with new associations: {updated}")
    log("PHASE 8B COMPLETE.\n")
    return updated


# ============================================================
# FINAL AUDIT
# ============================================================
def run_audit(api):
    log("=" * 70)
    log("AUDIT: Comprehensive Data Quality Check")
    log("=" * 70)

    stats = {
        "total": 0,
        "desc_en": 0, "desc_fr": 0, "desc_ar": 0,
        "short_en": 0, "short_fr": 0, "short_ar": 0,
        "has_image": 0,
        "has_brand": 0,
        "has_weight": 0,
        "has_categories": 0,
        "has_price": 0,
        "has_name_en": 0, "has_name_fr": 0, "has_name_ar": 0,
        "has_meta_title": 0, "has_meta_desc": 0,
        "has_url_key": 0,
        "has_related": 0, "has_crosssell": 0, "has_upsell": 0,
    }

    for prod in api.get_all_products():
        stats["total"] += 1
        vals = prod.get("values", {})
        cats = prod.get("categories", [])
        assoc = prod.get("associations", {})

        if cats:
            stats["has_categories"] += 1

        # Names
        for loc, key in [("en_US", "has_name_en"), ("fr_FR", "has_name_fr"), ("ar_DZ", "has_name_ar")]:
            if any(v.get("locale") == loc and v.get("data", "").strip() for v in vals.get("name", [])):
                stats[key] += 1

        # Descriptions
        for loc, key in [("en_US", "desc_en"), ("fr_FR", "desc_fr"), ("ar_DZ", "desc_ar")]:
            if any(v.get("locale") == loc and v.get("data", "").strip() for v in vals.get("description", [])):
                stats[key] += 1

        # Short descriptions
        for loc, key in [("en_US", "short_en"), ("fr_FR", "short_fr"), ("ar_DZ", "short_ar")]:
            if any(v.get("locale") == loc and v.get("data", "").strip() for v in vals.get("short_description", [])):
                stats[key] += 1

        # Image
        if any(v.get("data") for v in vals.get("image", [])):
            stats["has_image"] += 1

        # Brand
        if any(v.get("data") for v in vals.get("mgs_brand", [])):
            stats["has_brand"] += 1

        # Weight
        for v in vals.get("weight", []):
            d = v.get("data", {})
            if d and d.get("amount") and float(d.get("amount", 0)) > 0:
                stats["has_weight"] += 1
                break

        # Price
        for v in vals.get("price", []):
            amounts = v.get("data", [])
            if amounts and any(float(a.get("amount", 0)) > 0 for a in amounts):
                stats["has_price"] += 1
                break

        # Meta
        if any(v.get("data", "").strip() for v in vals.get("meta_title", [])):
            stats["has_meta_title"] += 1
        if any(v.get("data", "").strip() for v in vals.get("meta_description", [])):
            stats["has_meta_desc"] += 1
        if any(v.get("data", "").strip() for v in vals.get("url_key", [])):
            stats["has_url_key"] += 1

        # Associations
        if assoc.get("RELATED", {}).get("products"):
            stats["has_related"] += 1
        if assoc.get("CROSSSELL", {}).get("products"):
            stats["has_crosssell"] += 1
        if assoc.get("UPSELL", {}).get("products"):
            stats["has_upsell"] += 1

    # Product models
    model_stats = {"total": 0, "with_categories": 0}
    for m in api.get_all_product_models():
        model_stats["total"] += 1
        if m.get("categories"):
            model_stats["with_categories"] += 1

    # Category stats
    cat_stats = {"total": 0, "has_en": 0, "has_fr": 0, "has_ar": 0}
    for c in api.get_all_categories():
        cat_stats["total"] += 1
        labels = c.get("labels", {})
        if labels.get("en_US", "").strip():
            cat_stats["has_en"] += 1
        if labels.get("fr_FR", "").strip():
            cat_stats["has_fr"] += 1
        if labels.get("ar_DZ", "").strip():
            cat_stats["has_ar"] += 1

    total = stats["total"]
    report = []
    report.append("=" * 70)
    report.append(f"AKENEO PIM DATA QUALITY AUDIT - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    report.append("=" * 70)
    report.append(f"Total products: {total}")
    report.append(f"Product models: {model_stats['total']} (with categories: {model_stats['with_categories']})")
    report.append(f"Categories: {cat_stats['total']} (en_US: {cat_stats['has_en']}, "
                  f"fr_FR: {cat_stats['has_fr']}, ar_DZ: {cat_stats['has_ar']})")
    report.append("")
    report.append("PRODUCT DATA COVERAGE:")
    report.append(f"  Names (en_US):        {stats['has_name_en']:>6}/{total} ({stats['has_name_en']*100//total}%)")
    report.append(f"  Names (fr_FR):        {stats['has_name_fr']:>6}/{total} ({stats['has_name_fr']*100//total}%)")
    report.append(f"  Names (ar_DZ):        {stats['has_name_ar']:>6}/{total} ({stats['has_name_ar']*100//total}%)")
    report.append(f"  Description (en_US):  {stats['desc_en']:>6}/{total} ({stats['desc_en']*100//total}%)")
    report.append(f"  Description (fr_FR):  {stats['desc_fr']:>6}/{total} ({stats['desc_fr']*100//total}%)")
    report.append(f"  Description (ar_DZ):  {stats['desc_ar']:>6}/{total} ({stats['desc_ar']*100//total}%)")
    report.append(f"  Short desc (en_US):   {stats['short_en']:>6}/{total} ({stats['short_en']*100//total}%)")
    report.append(f"  Short desc (fr_FR):   {stats['short_fr']:>6}/{total} ({stats['short_fr']*100//total}%)")
    report.append(f"  Short desc (ar_DZ):   {stats['short_ar']:>6}/{total} ({stats['short_ar']*100//total}%)")
    report.append(f"  Images:               {stats['has_image']:>6}/{total} ({stats['has_image']*100//total}%)")
    report.append(f"  Brand:                {stats['has_brand']:>6}/{total} ({stats['has_brand']*100//total}%)")
    report.append(f"  Weight:               {stats['has_weight']:>6}/{total} ({stats['has_weight']*100//total}%)")
    report.append(f"  Categories:           {stats['has_categories']:>6}/{total} ({stats['has_categories']*100//total}%)")
    report.append(f"  Price > 0:            {stats['has_price']:>6}/{total} ({stats['has_price']*100//total}%)")
    report.append(f"  Meta title:           {stats['has_meta_title']:>6}/{total} ({stats['has_meta_title']*100//total}%)")
    report.append(f"  Meta description:     {stats['has_meta_desc']:>6}/{total} ({stats['has_meta_desc']*100//total}%)")
    report.append(f"  URL key:              {stats['has_url_key']:>6}/{total} ({stats['has_url_key']*100//total}%)")
    report.append(f"  Related products:     {stats['has_related']:>6}/{total} ({stats['has_related']*100//total}%)")
    report.append(f"  Cross-sell:           {stats['has_crosssell']:>6}/{total} ({stats['has_crosssell']*100//total}%)")
    report.append(f"  Upsell:               {stats['has_upsell']:>6}/{total} ({stats['has_upsell']*100//total}%)")
    report.append("=" * 70)

    report_text = "\n".join(report)
    print(report_text)

    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    report_file = f"{WEBAPP}/PHASE7_AUDIT_{ts}.txt"
    with open(report_file, "w") as f:
        f.write(report_text)

    log(f"  Audit report saved: {report_file}")
    return stats


# ============================================================
# MAIN
# ============================================================
def main():
    parser = argparse.ArgumentParser(description="Akeneo PIM Phase 7-9: Complete Enrichment")
    parser.add_argument("--setup-image", action="store_true", help="Create image attribute, add to families")
    parser.add_argument("--fix-category-labels", action="store_true", help="Fix missing ar_DZ category labels")
    parser.add_argument("--descriptions", action="store_true", help="7A: Sync descriptions from Magento")
    parser.add_argument("--images", action="store_true", help="7B: Sync product images from Magento")
    parser.add_argument("--brands", action="store_true", help="7C: Sync brand data")
    parser.add_argument("--model-categories", action="store_true", help="7D: Fix product model categories")
    parser.add_argument("--weight", action="store_true", help="Sync weight data from Magento")
    parser.add_argument("--gen-descriptions", action="store_true", help="8A: Generate missing descriptions")
    parser.add_argument("--associations", action="store_true", help="8B: Enrich associations")
    parser.add_argument("--audit", action="store_true", help="Run data quality audit")
    parser.add_argument("--all", action="store_true", help="Run everything")
    args = parser.parse_args()

    if not any(vars(args).values()):
        parser.print_help()
        sys.exit(1)

    api = AkeneoClient(AKENEO_API)
    api.auth()

    log("=" * 70)
    log("AKENEO PIM PHASE 7-9 ENRICHMENT STARTED")
    log(f"Timestamp: {datetime.now().isoformat()}")
    log("=" * 70)

    results = {}
    try:
        if args.setup_image or args.all:
            results["setup_image"] = setup_image_attribute(api)
        if args.fix_category_labels or args.all:
            results["fix_category_labels"] = fix_category_labels(api)
        if args.descriptions or args.all:
            results["7A_descriptions"] = sync_descriptions(api)
        if args.brands or args.all:
            results["7C_brands"] = sync_brands(api)
        if args.weight or args.all:
            results["weight"] = sync_weight(api)
        if args.model_categories or args.all:
            results["7D_model_categories"] = fix_model_categories(api)
        if args.gen_descriptions or args.all:
            results["8A_gen_descriptions"] = generate_descriptions(api)
        if args.associations or args.all:
            results["8B_associations"] = enrich_associations(api)
        if args.images or args.all:
            results["7B_images"] = sync_images(api)
        if args.audit or args.all:
            results["audit"] = run_audit(api)
    except Exception as e:
        log(f"FATAL ERROR: {e}", "ERROR")
        traceback.print_exc()
        sys.exit(1)

    log("=" * 70)
    log("SUMMARY:")
    for k, v in results.items():
        if isinstance(v, dict):
            log(f"  {k}: (audit report generated)")
        else:
            log(f"  {k}: {v}")
    log("=" * 70)
    log("PHASE 7-9 ENRICHMENT COMPLETE")


if __name__ == "__main__":
    main()
