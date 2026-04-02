#!/usr/bin/env python3
"""
Akeneo PIM - Catalog Optimization & Full Re-sync Script
========================================================
Phase 8-9: Optimizes attributes, families, attribute groups, then re-syncs
all data from Magento beta with proper mapping.

Usage:
  python3 optimize_and_resync.py --optimize          # Create/update Akeneo schema
  python3 optimize_and_resync.py --sync-options      # Sync select attribute options
  python3 optimize_and_resync.py --sync-categories    # Clean & re-sync categories
  python3 optimize_and_resync.py --sync-products     # Re-sync products with full mapping
  python3 optimize_and_resync.py --all               # Everything in order
  python3 optimize_and_resync.py --audit             # Show audit report only
"""

import sys, os, json, re, time, argparse, unicodedata
import mysql.connector
import requests
from datetime import datetime

# === Configuration ===
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
LOCALE = "en_US"
CURRENCY = "DZD"
LOG_FILE = "/home/pim/public_html/var/logs/optimize_sync.log"

# === Attribute Group Mapping ===
# Maps Akeneo group codes to logical groupings
ATTRIBUTE_GROUPS = {
    "identification": {"en_US": "Identification", "fr_FR": "Identification", "sort_order": 1},
    "description":    {"en_US": "Description", "fr_FR": "Description", "sort_order": 2},
    "pricing":        {"en_US": "Pricing", "fr_FR": "Prix", "sort_order": 3},
    "dimensions":     {"en_US": "Dimensions & Weight", "fr_FR": "Dimensions & Poids", "sort_order": 4},
    "technical":      {"en_US": "Technical Specifications", "fr_FR": "Specifications Techniques", "sort_order": 5},
    "seo":            {"en_US": "SEO & Metadata", "fr_FR": "SEO & Metadonnees", "sort_order": 6},
    "ecommerce":      {"en_US": "E-commerce & Visibility", "fr_FR": "E-commerce & Visibilite", "sort_order": 7},
    "marketing":      {"en_US": "Marketing & Branding", "fr_FR": "Marketing & Marque", "sort_order": 8},
    "media":          {"en_US": "Media & Images", "fr_FR": "Media & Images", "sort_order": 9},
}

# === Full Attribute Schema ===
# All Magento attributes mapped to Akeneo with proper types/groups
ATTRIBUTE_SCHEMA = {
    # -- Identification --
    "sku":            {"type": "pim_catalog_identifier", "group": "identification", "localizable": False, "scopable": False},
    "name":           {"type": "pim_catalog_text", "group": "identification", "localizable": True,  "scopable": False, "labels": {"en_US": "Product Name", "fr_FR": "Nom du produit"}},
    "techno_ref":     {"type": "pim_catalog_text", "group": "identification", "localizable": False, "scopable": False, "labels": {"en_US": "Techno Reference", "fr_FR": "Reference Techno"}},
    "url_key":        {"type": "pim_catalog_text", "group": "identification", "localizable": False, "scopable": False, "labels": {"en_US": "URL Key", "fr_FR": "Cle URL"}},
    "manufacturer":   {"type": "pim_catalog_simpleselect", "group": "identification", "localizable": False, "scopable": False, "labels": {"en_US": "Manufacturer", "fr_FR": "Fabricant"}},
    "mgs_brand":      {"type": "pim_catalog_simpleselect", "group": "identification", "localizable": False, "scopable": False, "labels": {"en_US": "Brand", "fr_FR": "Marque"}},
    # -- Description --
    "description":    {"type": "pim_catalog_textarea", "group": "description", "localizable": True, "scopable": True, "labels": {"en_US": "Description", "fr_FR": "Description"}, "wysiwyg": True},
    "short_description": {"type": "pim_catalog_textarea", "group": "description", "localizable": True, "scopable": True, "labels": {"en_US": "Short Description", "fr_FR": "Description courte"}, "wysiwyg": True},
    # -- Pricing --
    "price":          {"type": "pim_catalog_price_collection", "group": "pricing", "localizable": False, "scopable": False, "labels": {"en_US": "Price", "fr_FR": "Prix"}},
    "special_price":  {"type": "pim_catalog_price_collection", "group": "pricing", "localizable": False, "scopable": False, "labels": {"en_US": "Special Price", "fr_FR": "Prix special"}},
    "cost":           {"type": "pim_catalog_price_collection", "group": "pricing", "localizable": False, "scopable": False, "labels": {"en_US": "Cost", "fr_FR": "Cout"}},
    # -- Dimensions --
    "weight":         {"type": "pim_catalog_metric", "group": "dimensions", "localizable": False, "scopable": False, "labels": {"en_US": "Weight", "fr_FR": "Poids"}, "metric_family": "Weight", "default_metric_unit": "GRAM"},
    "size":           {"type": "pim_catalog_simpleselect", "group": "dimensions", "localizable": False, "scopable": False, "labels": {"en_US": "Size", "fr_FR": "Taille"}},
    "dimension":      {"type": "pim_catalog_simpleselect", "group": "dimensions", "localizable": False, "scopable": False, "labels": {"en_US": "Dimension", "fr_FR": "Dimension"}},
    "diameter":       {"type": "pim_catalog_simpleselect", "group": "dimensions", "localizable": False, "scopable": False, "labels": {"en_US": "Diameter", "fr_FR": "Diametre"}},
    "thickness":      {"type": "pim_catalog_simpleselect", "group": "dimensions", "localizable": False, "scopable": False, "labels": {"en_US": "Thickness", "fr_FR": "Epaisseur"}},
    "format":         {"type": "pim_catalog_simpleselect", "group": "dimensions", "localizable": False, "scopable": False, "labels": {"en_US": "Format", "fr_FR": "Format"}},
    # -- Technical --
    "color":          {"type": "pim_catalog_simpleselect", "group": "technical", "localizable": False, "scopable": False, "labels": {"en_US": "Color", "fr_FR": "Couleur"}},
    "capacity":       {"type": "pim_catalog_simpleselect", "group": "technical", "localizable": False, "scopable": False, "labels": {"en_US": "Capacity", "fr_FR": "Capacite"}},
    "pattern":        {"type": "pim_catalog_simpleselect", "group": "technical", "localizable": False, "scopable": False, "labels": {"en_US": "Pattern", "fr_FR": "Motif"}},
    "type_product":   {"type": "pim_catalog_simpleselect", "group": "technical", "localizable": False, "scopable": False, "labels": {"en_US": "Product Type", "fr_FR": "Type de produit"}},
    # -- SEO --
    "meta_title":     {"type": "pim_catalog_text", "group": "seo", "localizable": True, "scopable": False, "labels": {"en_US": "Meta Title", "fr_FR": "Meta Titre"}},
    "meta_description": {"type": "pim_catalog_textarea", "group": "seo", "localizable": True, "scopable": False, "labels": {"en_US": "Meta Description", "fr_FR": "Meta Description"}},
    "meta_keyword":   {"type": "pim_catalog_textarea", "group": "seo", "localizable": True, "scopable": False, "labels": {"en_US": "Meta Keywords", "fr_FR": "Mots cles Meta"}},
    # -- E-commerce --
    "product_status": {"type": "pim_catalog_boolean", "group": "ecommerce", "localizable": False, "scopable": False, "labels": {"en_US": "Enabled", "fr_FR": "Active"}},
    "visibility":     {"type": "pim_catalog_simpleselect", "group": "ecommerce", "localizable": False, "scopable": False, "labels": {"en_US": "Visibility", "fr_FR": "Visibilite"}},
    "a_la_une":       {"type": "pim_catalog_boolean", "group": "ecommerce", "localizable": False, "scopable": False, "labels": {"en_US": "Featured", "fr_FR": "A la une"}},
    "best_seller":    {"type": "pim_catalog_boolean", "group": "ecommerce", "localizable": False, "scopable": False, "labels": {"en_US": "Best Seller", "fr_FR": "Meilleure vente"}},
    "trending":       {"type": "pim_catalog_boolean", "group": "ecommerce", "localizable": False, "scopable": False, "labels": {"en_US": "Trending", "fr_FR": "Tendance"}},
    "en_promo":       {"type": "pim_catalog_text", "group": "ecommerce", "localizable": False, "scopable": False, "labels": {"en_US": "Promo Label", "fr_FR": "Libelle promo"}},
    "gender_product": {"type": "pim_catalog_simpleselect", "group": "ecommerce", "localizable": False, "scopable": False, "labels": {"en_US": "Gender", "fr_FR": "Genre"}},
    # -- Marketing --
    "brand":          {"type": "pim_catalog_text", "group": "marketing", "localizable": False, "scopable": False, "labels": {"en_US": "Brand Text", "fr_FR": "Marque (texte)"}},
    "country_of_manufacture": {"type": "pim_catalog_text", "group": "marketing", "localizable": False, "scopable": False, "labels": {"en_US": "Country of Manufacture", "fr_FR": "Pays de fabrication"}},
}

# Families mapping - Magento attribute sets -> Akeneo families
FAMILY_MAP = {
    "stationery":    {"label": {"en_US": "General Stationery", "fr_FR": "Fournitures Generales"}, "sets": ["Products", "Techno", "Maglux", "SCOLAIRE", "madeInAlgeria"]},
    "writing":       {"label": {"en_US": "Writing Instruments", "fr_FR": "Instruments d'ecriture"}, "sets": ["ECRITURE", "CRAYONS"]},
    "notebooks":     {"label": {"en_US": "Notebooks & Cahiers", "fr_FR": "Cahiers"}, "sets": ["CAHIER"]},
    "office":        {"label": {"en_US": "Office Supplies", "fr_FR": "Fournitures de Bureau"}, "sets": ["BUREAUTIQUE", "CALCULATRICES", "INFORMATIQUE", "TABLEAU"]},
    "bags":          {"label": {"en_US": "Bags & Accessories", "fr_FR": "Sacs & Accessoires"}, "sets": ["Bags Sac"]},
    "arts":          {"label": {"en_US": "Fine Arts Supplies", "fr_FR": "Beaux Arts"}, "sets": ["BEAUX ARTS"]},
}

# Magento special attribute value mappings (not in eav_attribute_option table)
# Visibility: 1=Not Visible, 2=Catalog, 3=Search, 4=Catalog & Search
VISIBILITY_MAP = {
    1: "not_visible_individually",
    2: "in_catalog",
    3: "in_search",
    4: "catalog_and_search",
}
VISIBILITY_OPTIONS = [
    {"code": "not_visible_individually", "labels": {"en_US": "Not Visible Individually", "fr_FR": "Non visible individuellement"}},
    {"code": "in_catalog", "labels": {"en_US": "Catalog", "fr_FR": "Catalogue"}},
    {"code": "in_search", "labels": {"en_US": "Search", "fr_FR": "Recherche"}},
    {"code": "catalog_and_search", "labels": {"en_US": "Catalog, Search", "fr_FR": "Catalogue, Recherche"}},
]

# Manufacturer source model values need special handling too
# These are Magento system attributes using source models, NOT eav_attribute_option
SPECIAL_INT_SELECTS = {"visibility"}  # handled with VISIBILITY_MAP

# Base attributes for ALL families
BASE_FAMILY_ATTRS = [
    "sku", "name", "description", "short_description", "price", "special_price",
    "weight", "url_key", "product_status", "visibility", "meta_title",
    "meta_description", "meta_keyword", "mgs_brand", "manufacturer",
    "techno_ref", "color", "a_la_une", "best_seller", "trending", "en_promo",
    "brand", "cost"
]

# Extra attributes per family
FAMILY_EXTRA_ATTRS = {
    "writing":   ["capacity", "thickness", "pattern", "type_product", "diameter"],
    "notebooks": ["format", "dimension", "pattern", "type_product"],
    "office":    ["format", "dimension", "capacity", "type_product"],
    "bags":      ["size", "dimension", "pattern", "gender_product", "type_product"],
    "arts":      ["capacity", "format", "pattern", "type_product"],
    "stationery":["size", "dimension", "capacity", "format", "pattern", "type_product", "gender_product", "diameter", "thickness"],
}


def log(msg, level="INFO"):
    ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    line = "[%s] [%s] %s" % (ts, level, msg)
    print(line)
    try:
        os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)
        with open(LOG_FILE, "a") as f:
            f.write(line + "\n")
    except Exception:
        pass

def parse_jsonl(response):
    """Parse JSONL (one JSON per line) response from Akeneo batch API."""
    try:
        lines = response.text.strip().split("\n")
        return [json.loads(line) for line in lines if line.strip()]
    except Exception:
        return []

def slugify(text):
    text = unicodedata.normalize('NFKD', str(text)).encode('ascii', 'ignore').decode('ascii')
    text = re.sub(r'[^\w\s-]', '', text.lower())
    return re.sub(r'[-\s]+', '_', text).strip('_')


class AkeneoClient:
    def __init__(self, config):
        self.base = config["base_url"].rstrip("/")
        self.config = config
        self.token = None

    def auth(self):
        r = requests.post("%s/api/oauth/v1/token" % self.base, data={
            "grant_type": "password", "client_id": self.config["client_id"],
            "client_secret": self.config["client_secret"],
            "username": self.config["username"], "password": self.config["password"],
        })
        if r.status_code != 200:
            log("Auth failed: %d" % r.status_code, "ERROR"); sys.exit(1)
        self.token = r.json()["access_token"]
        log("Authenticated with Akeneo API")

    def h(self):
        return {"Authorization": "Bearer %s" % self.token}

    def get(self, ep, params=None):
        r = requests.get("%s/api/rest/v1/%s" % (self.base, ep), headers=self.h(), params=params)
        if r.status_code == 401:
            self.auth()
            r = requests.get("%s/api/rest/v1/%s" % (self.base, ep), headers=self.h(), params=params)
        return r

    def get_all(self, ep, params=None):
        items = []; url = "%s/api/rest/v1/%s" % (self.base, ep)
        if params is None: params = {}
        params.setdefault("limit", 100)
        while url:
            r = requests.get(url, headers=self.h(), params=params)
            if r.status_code == 401:
                self.auth(); r = requests.get(url, headers=self.h(), params=params)
            if r.status_code != 200: break
            d = r.json(); items.extend(d.get("_embedded", {}).get("items", []))
            url = d.get("_links", {}).get("next", {}).get("href"); params = {}
        return items

    def patch(self, ep, data):
        r = requests.patch("%s/api/rest/v1/%s" % (self.base, ep), headers={**self.h(), "Content-Type": "application/json"}, json=data)
        if r.status_code == 401:
            self.auth()
            r = requests.patch("%s/api/rest/v1/%s" % (self.base, ep), headers={**self.h(), "Content-Type": "application/json"}, json=data)
        return r

    def post(self, ep, data):
        r = requests.post("%s/api/rest/v1/%s" % (self.base, ep), headers={**self.h(), "Content-Type": "application/json"}, json=data)
        if r.status_code == 401:
            self.auth()
            r = requests.post("%s/api/rest/v1/%s" % (self.base, ep), headers={**self.h(), "Content-Type": "application/json"}, json=data)
        return r

    def patch_collection(self, ep, items):
        lines = "\n".join(json.dumps(i) for i in items)
        r = requests.patch("%s/api/rest/v1/%s" % (self.base, ep), headers={**self.h(), "Content-Type": "application/vnd.akeneo.collection+json"}, data=lines)
        if r.status_code == 401:
            self.auth()
            r = requests.patch("%s/api/rest/v1/%s" % (self.base, ep), headers={**self.h(), "Content-Type": "application/vnd.akeneo.collection+json"}, data=lines)
        return r


def optimize_schema(ak):
    """Phase 8: Create/update attribute groups, attributes, families."""
    log("=" * 60)
    log("PHASE 8: OPTIMIZING AKENEO SCHEMA")
    log("=" * 60)

    # 1. Update attribute groups with labels
    log("--- Updating attribute groups ---")
    existing_groups = {g["code"]: g for g in ak.get_all("attribute-groups")}
    for code, info in ATTRIBUTE_GROUPS.items():
        payload = {"code": code, "labels": {"en_US": info["en_US"], "fr_FR": info["fr_FR"]}, "sort_order": info["sort_order"]}
        r = ak.patch("attribute-groups/%s" % code, payload)
        if r.status_code in (201, 204):
            log("  Updated group: %s" % code)
        elif r.status_code == 404:
            r2 = ak.post("attribute-groups", payload)
            log("  Created group: %s (%d)" % (code, r2.status_code))
        else:
            log("  Group %s: %d" % (code, r.status_code), "WARN")

    # 1b. Create visibility options
    log("--- Creating visibility options ---")
    for opt in VISIBILITY_OPTIONS:
        payload = {"code": opt["code"], "attribute": "visibility", "labels": opt["labels"]}
        r = ak.patch("attributes/visibility/options/%s" % opt["code"], payload)
        if r.status_code in (201, 204):
            log("  Visibility option: %s" % opt["code"])
        elif r.status_code == 404:
            r2 = ak.post("attributes/visibility/options", payload)
            log("  Created visibility option: %s (%d)" % (opt["code"], r2.status_code))

    # 2. Create/update attributes
    log("--- Updating attributes ---")
    existing_attrs = {a["code"]: a for a in ak.get_all("attributes")}
    created = 0; updated = 0
    for code, schema in ATTRIBUTE_SCHEMA.items():
        payload = {"code": code, "type": schema["type"], "group": schema["group"],
                   "localizable": schema.get("localizable", False),
                   "scopable": schema.get("scopable", False)}
        if "labels" in schema:
            payload["labels"] = schema["labels"]
        if schema["type"] == "pim_catalog_metric":
            payload["metric_family"] = schema.get("metric_family", "Weight")
            payload["default_metric_unit"] = schema.get("default_metric_unit", "GRAM")
            payload["negative_allowed"] = False
            payload["decimals_allowed"] = True
        if schema["type"] == "pim_catalog_textarea" and schema.get("wysiwyg"):
            payload["wysiwyg_enabled"] = True
        if schema.get("unique"):
            payload["unique"] = True

        if code in existing_attrs:
            # Only update labels and group for existing attrs (can't change type)
            upd = {"labels": schema.get("labels", {}), "group": schema["group"]}
            r = ak.patch("attributes/%s" % code, upd)
            if r.status_code in (204, 200): updated += 1
        else:
            r = ak.post("attributes", payload)
            if r.status_code in (201,):
                created += 1; log("  Created attribute: %s (%s)" % (code, schema["type"]))
            else:
                log("  Failed to create %s: %d %s" % (code, r.status_code, r.text[:200]), "WARN")
    log("  Attributes: %d created, %d updated" % (created, updated))

    # 3. Create/update families
    log("--- Updating families ---")
    existing_families = {f["code"]: f for f in ak.get_all("families")}
    for fam_code, fam_info in FAMILY_MAP.items():
        attrs = list(BASE_FAMILY_ATTRS) + FAMILY_EXTRA_ATTRS.get(fam_code, [])
        # Filter to only existing attributes
        valid_attrs = [a for a in attrs if a in ATTRIBUTE_SCHEMA or a in existing_attrs]
        # Remove duplicates
        valid_attrs = list(dict.fromkeys(valid_attrs))

        payload = {
            "code": fam_code,
            "labels": fam_info["label"],
            "attributes": valid_attrs,
            "attribute_as_label": "name",
            "attribute_requirements": {
                CHANNEL: ["sku", "name"]
            }
        }
        r = ak.patch("families/%s" % fam_code, payload)
        if r.status_code in (201, 204):
            log("  Updated family: %s (%d attrs)" % (fam_code, len(valid_attrs)))
        elif r.status_code == 404 or r.status_code == 422:
            r2 = ak.post("families", payload)
            if r2.status_code in (201,):
                log("  Created family: %s (%d attrs)" % (fam_code, len(valid_attrs)))
            else:
                log("  Failed family %s: %d %s" % (fam_code, r2.status_code, r2.text[:300]), "WARN")
        else:
            log("  Family %s: %d %s" % (fam_code, r.status_code, r.text[:200]), "WARN")

    log("Schema optimization complete")


def sync_options(ak):
    """Sync select attribute options from Magento to Akeneo."""
    log("=" * 60)
    log("SYNCING ATTRIBUTE OPTIONS (Magento -> Akeneo)")
    log("=" * 60)

    conn = mysql.connector.connect(**MAGENTO_DB)
    cursor = conn.cursor(dictionary=True)

    select_attrs = [k for k, v in ATTRIBUTE_SCHEMA.items() if v["type"] == "pim_catalog_simpleselect"]
    total_created = 0

    for attr_code in select_attrs:
        cursor.execute("""
            SELECT DISTINCT ov.value AS label, o.sort_order
            FROM eav_attribute_option o
            JOIN eav_attribute_option_value ov ON o.option_id = ov.option_id AND ov.store_id = 0
            JOIN eav_attribute a ON o.attribute_id = a.attribute_id
            WHERE a.attribute_code = %s AND a.entity_type_id = 4
              AND ov.value IS NOT NULL AND ov.value != ''
            ORDER BY o.sort_order, ov.value
        """, (attr_code,))
        options = cursor.fetchall()
        if not options:
            continue

        # Get existing options
        existing = set()
        r = ak.get("attributes/%s/options" % attr_code, {"limit": 100})
        if r.status_code == 200:
            for page_item in r.json().get("_embedded", {}).get("items", []):
                existing.add(page_item["code"])

        batch = []
        for opt in options:
            code = slugify(opt["label"])[:100]
            if not code or code in existing:
                continue
            batch.append({
                "code": code,
                "attribute": attr_code,
                "sort_order": opt.get("sort_order", 0),
                "labels": {"en_US": opt["label"]}
            })
            existing.add(code)

        if batch:
            # Send in batches of 100
            for i in range(0, len(batch), 100):
                chunk = batch[i:i+100]
                r = ak.patch_collection("attributes/%s/options" % attr_code, chunk)
                if r.status_code == 200:
                    # Response is JSONL (one JSON per line)
                    try:
                        results = [json.loads(line) for line in r.text.strip().split("\n") if line.strip()]
                    except Exception:
                        results = []
                    ok = sum(1 for x in results if x.get("status_code") in (201, 204))
                    total_created += ok
            log("  %s: %d options synced (%d new)" % (attr_code, len(batch), len(batch)))

    cursor.close(); conn.close()
    log("Options sync complete: %d total created" % total_created)


def sync_categories(ak):
    """Clean sync categories with proper tree structure."""
    log("=" * 60)
    log("SYNCING CATEGORIES (Magento -> Akeneo)")
    log("=" * 60)

    conn = mysql.connector.connect(**MAGENTO_DB)
    cursor = conn.cursor(dictionary=True)

    # Get all categories with names
    cursor.execute("""
        SELECT e.entity_id, e.parent_id, e.path, e.level, e.position,
               v.value AS name
        FROM catalog_category_entity e
        LEFT JOIN catalog_category_entity_varchar v ON e.entity_id = v.entity_id
            AND v.attribute_id = (SELECT attribute_id FROM eav_attribute WHERE attribute_code='name' AND entity_type_id=3)
            AND v.store_id = 0
        WHERE e.level >= 2
        ORDER BY e.level, e.position
    """)
    categories = cursor.fetchall()

    # Build parent mapping (entity_id -> akeneo code)
    id_to_code = {}
    # Get Akeneo master tree root
    existing = {c["code"]: c for c in ak.get_all("categories")}

    created = 0; updated = 0
    batch = []

    for cat in categories:
        name = cat["name"] or "Category_%d" % cat["entity_id"]
        code = slugify(name)[:100]
        if not code:
            code = "cat_%d" % cat["entity_id"]

        # Ensure uniqueness
        base_code = code
        counter = 1
        while code in existing and existing[code].get("_entity_id") != cat["entity_id"]:
            code = "%s_%d" % (base_code, counter)
            counter += 1

        id_to_code[cat["entity_id"]] = code

        # Determine parent
        parent = "master"
        if cat["parent_id"] and cat["parent_id"] in id_to_code:
            parent = id_to_code[cat["parent_id"]]

        payload = {
            "code": code,
            "parent": parent,
            "labels": {"en_US": name}
        }
        batch.append(payload)
        existing[code] = {"_entity_id": cat["entity_id"]}

        if len(batch) >= 100:
            r = ak.patch_collection("categories", batch)
            if r.status_code == 200:
                results = parse_jsonl(r)
                c = sum(1 for x in results if x.get("status_code") == 201)
                u = sum(1 for x in results if x.get("status_code") == 204)
                created += c; updated += u
            batch = []

    if batch:
        r = ak.patch_collection("categories", batch)
        if r.status_code == 200:
            results = parse_jsonl(r)
            c = sum(1 for x in results if x.get("status_code") == 201)
            u = sum(1 for x in results if x.get("status_code") == 204)
            created += c; updated += u

    cursor.close(); conn.close()
    log("Categories: %d created, %d updated (total %d)" % (created, updated, len(categories)))


def sync_products(ak, limit=None):
    """Full re-sync products with optimized attribute mapping and family assignment."""
    log("=" * 60)
    log("SYNCING PRODUCTS (Magento -> Akeneo) with optimized schema")
    log("=" * 60)

    conn = mysql.connector.connect(**MAGENTO_DB)
    cursor = conn.cursor(dictionary=True)

    # Build attribute set -> family mapping
    set_to_family = {}
    for fam_code, fam_info in FAMILY_MAP.items():
        for set_name in fam_info["sets"]:
            set_to_family[set_name] = fam_code

    # Get attribute set names
    cursor.execute("""
        SELECT attribute_set_id, attribute_set_name FROM eav_attribute_set
        WHERE entity_type_id = 4
    """)
    set_names = {r["attribute_set_id"]: r["attribute_set_name"] for r in cursor.fetchall()}

    # Get all products with key attributes
    limit_clause = "LIMIT %d" % limit if limit else ""
    cursor.execute("""
        SELECT p.entity_id, p.sku, p.attribute_set_id, p.type_id
        FROM catalog_product_entity p
        WHERE p.sku IS NOT NULL AND p.sku != ''
        ORDER BY p.entity_id
        %s
    """ % limit_clause)
    products = cursor.fetchall()
    log("Found %d products to sync" % len(products))

    # Helper to get EAV value
    def get_val(entity_id, attr_code, backend_type="varchar", store_id=0):
        table = "catalog_product_entity_%s" % backend_type
        cursor.execute("""
            SELECT v.value FROM %s v
            JOIN eav_attribute a ON v.attribute_id = a.attribute_id
            WHERE a.attribute_code = %%s AND a.entity_type_id = 4
              AND v.entity_id = %%s AND v.store_id = %%s
        """ % table, (attr_code, entity_id, store_id))
        row = cursor.fetchone()
        return row["value"] if row else None

    def get_select_label(entity_id, attr_code):
        cursor.execute("""
            SELECT ov.value AS label
            FROM catalog_product_entity_int v
            JOIN eav_attribute a ON v.attribute_id = a.attribute_id
            JOIN eav_attribute_option_value ov ON v.value = ov.option_id AND ov.store_id = 0
            WHERE a.attribute_code = %s AND a.entity_type_id = 4
              AND v.entity_id = %s AND v.store_id = 0
        """, (attr_code, entity_id))
        row = cursor.fetchone()
        return slugify(row["label"])[:100] if row and row["label"] else None

    # Get category mapping
    cursor.execute("""
        SELECT cp.product_id, GROUP_CONCAT(
            (SELECT v.value FROM catalog_category_entity_varchar v
             JOIN eav_attribute a ON v.attribute_id = a.attribute_id
             WHERE a.attribute_code = 'name' AND a.entity_type_id = 3
               AND v.entity_id = cp.category_id AND v.store_id = 0)
        ) AS cat_names
        FROM catalog_category_product cp
        GROUP BY cp.product_id
    """)
    prod_cats = {}
    for row in cursor.fetchall():
        if row["cat_names"]:
            prod_cats[row["product_id"]] = [slugify(c)[:100] for c in row["cat_names"].split(",") if c.strip()]

    stats = {"created": 0, "updated": 0, "errors": 0, "skipped": 0}
    batch = []
    batch_num = 0

    for prod in products:
        sku = str(prod["sku"]).strip()
        if not sku:
            stats["skipped"] += 1; continue

        # Determine family
        set_name = set_names.get(prod["attribute_set_id"], "Products")
        family = set_to_family.get(set_name, "stationery")

        eid = prod["entity_id"]

        # Build values
        values = {}

        # Text attributes (varchar backend)
        name = get_val(eid, "name")
        if name:
            values["name"] = [{"locale": LOCALE, "scope": None, "data": name}]

        techno_ref = get_val(eid, "techno_ref")
        if techno_ref:
            values["techno_ref"] = [{"locale": None, "scope": None, "data": techno_ref}]

        url_key = get_val(eid, "url_key")
        if url_key:
            values["url_key"] = [{"locale": None, "scope": None, "data": url_key}]

        en_promo = get_val(eid, "en_promo")
        if en_promo:
            values["en_promo"] = [{"locale": None, "scope": None, "data": en_promo}]

        brand = get_val(eid, "brand") if get_val(eid, "brand") else None

        # Textarea (text backend)
        desc = get_val(eid, "description", "text")
        if desc:
            values["description"] = [{"locale": LOCALE, "scope": CHANNEL, "data": desc}]

        short_desc = get_val(eid, "short_description", "text")
        if short_desc:
            values["short_description"] = [{"locale": LOCALE, "scope": CHANNEL, "data": short_desc}]

        # SEO fields (varchar)
        meta_title = get_val(eid, "meta_title")
        if meta_title:
            values["meta_title"] = [{"locale": LOCALE, "scope": None, "data": meta_title}]

        meta_desc = get_val(eid, "meta_description")
        if meta_desc:
            values["meta_description"] = [{"locale": LOCALE, "scope": None, "data": meta_desc}]

        # meta_keyword is text backend
        meta_kw = get_val(eid, "meta_keyword", "text")
        if meta_kw:
            values["meta_keyword"] = [{"locale": LOCALE, "scope": None, "data": meta_kw}]

        # Price (decimal backend)
        price = get_val(eid, "price", "decimal")
        if price is not None:
            values["price"] = [{"locale": None, "scope": None, "data": [{"amount": str(price), "currency": CURRENCY}]}]

        special = get_val(eid, "special_price", "decimal")
        if special is not None:
            values["special_price"] = [{"locale": None, "scope": None, "data": [{"amount": str(special), "currency": CURRENCY}]}]

        cost_val = get_val(eid, "cost", "decimal")
        if cost_val is not None:
            values["cost"] = [{"locale": None, "scope": None, "data": [{"amount": str(cost_val), "currency": CURRENCY}]}]

        # Weight
        weight = get_val(eid, "weight", "decimal")
        if weight is not None:
            values["weight"] = [{"locale": None, "scope": None, "data": {"amount": str(weight), "unit": "GRAM"}}]

        # Boolean (int backend)
        for bool_attr in ["product_status", "a_la_une", "best_seller", "trending"]:
            bval = get_val(eid, bool_attr if bool_attr != "product_status" else "status", "int")
            if bval is not None:
                if bool_attr == "product_status":
                    values["product_status"] = [{"locale": None, "scope": None, "data": bval == 1}]
                else:
                    values[bool_attr] = [{"locale": None, "scope": None, "data": bval == 1}]

        # Visibility (special: uses Magento source model, not eav_attribute_option)
        vis_val = get_val(eid, "visibility", "int")
        if vis_val is not None:
            vis_code = VISIBILITY_MAP.get(int(vis_val), "catalog_and_search")
            values["visibility"] = [{"locale": None, "scope": None, "data": vis_code}]

        # Select attributes (standard EAV option-based)
        for sel_attr in ["color", "manufacturer", "mgs_brand", "capacity", "pattern",
                         "size", "dimension", "diameter", "thickness", "format",
                         "gender_product", "type_product"]:
            sel_val = get_select_label(eid, sel_attr if sel_attr != "type_product" else "type")
            if sel_val:
                values[sel_attr] = [{"locale": None, "scope": None, "data": sel_val}]

        # Categories (filter out 'default_category' and other non-existent codes)
        categories = [c for c in prod_cats.get(eid, []) if c and c not in ('default_category', 'root_catalog', 'tous_les_produits')]

        item = {
            "identifier": sku,
            "family": family,
            "categories": categories,
            "values": values,
        }
        batch.append(item)

        if len(batch) >= 100:
            batch_num += 1
            c = u = e = 0
            r = ak.patch_collection("products", batch)
            if r.status_code == 200:
                results = parse_jsonl(r)
                c = sum(1 for x in results if x.get("status_code") == 201)
                u = sum(1 for x in results if x.get("status_code") == 204)
                e = sum(1 for x in results if x.get("status_code") not in (201, 204))
                stats["created"] += c; stats["updated"] += u; stats["errors"] += e
                if e > 0:
                    for x in results[:5]:
                        if x.get("status_code") not in (201, 204):
                            log("  Error: %s" % json.dumps(x)[:500], "WARN")
            else:
                log("  Batch %d failed: %d" % (batch_num, r.status_code), "ERROR")
                stats["errors"] += len(batch)
            log("  Batch %d: +%d created, ~%d updated, %d errors" % (batch_num, c, u, e))
            batch = []

    # Final batch
    if batch:
        batch_num += 1
        c = u = e = 0
        r = ak.patch_collection("products", batch)
        if r.status_code == 200:
            results = parse_jsonl(r)
            c = sum(1 for x in results if x.get("status_code") == 201)
            u = sum(1 for x in results if x.get("status_code") == 204)
            e = sum(1 for x in results if x.get("status_code") not in (201, 204))
            stats["created"] += c; stats["updated"] += u; stats["errors"] += e
            if e > 0:
                for x in results[:5]:
                    if x.get("status_code") not in (201, 204):
                        log("  Error: %s" % json.dumps(x)[:500], "WARN")
        else:
            log("  Batch %d (final) failed: %d" % (batch_num, r.status_code), "ERROR")
            stats["errors"] += len(batch)
        log("  Batch %d (final): +%d created, ~%d updated, %d errors" % (batch_num, c, u, e))

    cursor.close(); conn.close()
    log("Product sync complete: created=%d, updated=%d, errors=%d, skipped=%d" %
        (stats["created"], stats["updated"], stats["errors"], stats["skipped"]))
    return stats


def audit_report(ak):
    """Print audit report comparing Magento and Akeneo."""
    log("=" * 60)
    log("AUDIT REPORT")
    log("=" * 60)

    conn = mysql.connector.connect(**MAGENTO_DB)
    cursor = conn.cursor(dictionary=True)

    cursor.execute("SELECT COUNT(*) AS c FROM catalog_product_entity")
    mag_prods = cursor.fetchone()["c"]
    cursor.execute("SELECT COUNT(*) AS c FROM catalog_category_entity WHERE level >= 2")
    mag_cats = cursor.fetchone()["c"]

    ak_prods = len(ak.get_all("products"))
    ak_cats = len(ak.get_all("categories"))
    ak_fams = len(ak.get_all("families"))
    ak_attrs = len(ak.get_all("attributes"))

    print("\n" + "=" * 50)
    print("  Magento Beta         | Akeneo PIM")
    print("=" * 50)
    print("  Products: %-10d | Products: %d" % (mag_prods, ak_prods))
    print("  Categories: %-8d | Categories: %d" % (mag_cats, ak_cats))
    print("  Attr Sets: 14        | Families: %d" % ak_fams)
    print("  Attrs: ~80           | Attributes: %d" % ak_attrs)
    print("=" * 50)

    # SEO fill rates
    for field, table, backend in [
        ("meta_title", "catalog_product_entity_varchar", "varchar"),
        ("meta_description", "catalog_product_entity_varchar", "varchar"),
        ("meta_keyword", "catalog_product_entity_text", "text"),
        ("description", "catalog_product_entity_text", "text"),
    ]:
        cursor.execute("""
            SELECT COUNT(*) AS c FROM %s
            WHERE attribute_id = (SELECT attribute_id FROM eav_attribute WHERE attribute_code='%s' AND entity_type_id=4)
              AND value IS NOT NULL AND value != ''
        """ % (table, field))
        filled = cursor.fetchone()["c"]
        pct = (filled / mag_prods * 100) if mag_prods > 0 else 0
        print("  SEO %-18s: %d/%d (%.0f%%)" % (field, filled, mag_prods, pct))

    cursor.close(); conn.close()
    print("=" * 50 + "\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Akeneo catalog optimization & re-sync")
    parser.add_argument("--optimize", action="store_true", help="Optimize schema (groups, attrs, families)")
    parser.add_argument("--sync-options", action="store_true", help="Sync select attribute options")
    parser.add_argument("--sync-categories", action="store_true", help="Re-sync categories")
    parser.add_argument("--sync-products", action="store_true", help="Re-sync products with full mapping")
    parser.add_argument("--all", action="store_true", help="Run everything")
    parser.add_argument("--audit", action="store_true", help="Show audit report")
    parser.add_argument("--limit", type=int, default=None)
    args = parser.parse_args()

    if not any([args.optimize, args.sync_options, args.sync_categories, args.sync_products, args.all, args.audit]):
        parser.print_help(); sys.exit(1)

    ak = AkeneoClient(AKENEO_API)
    ak.auth()

    if args.audit or args.all:
        audit_report(ak)

    if args.optimize or args.all:
        optimize_schema(ak)

    if args.sync_options or args.all:
        sync_options(ak)

    if args.sync_categories or args.all:
        sync_categories(ak)

    if args.sync_products or args.all:
        sync_products(ak, limit=args.limit)

    if args.audit or args.all:
        log("\n--- POST-SYNC AUDIT ---")
        audit_report(ak)

    log("=== All operations complete ===")
