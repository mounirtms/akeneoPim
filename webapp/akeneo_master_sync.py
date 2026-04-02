#!/usr/bin/env python3
"""
Akeneo PIM Master Sync & Optimization Script
=============================================
Comprehensive script handling:
  Phase 1: Platform fixes (cache, permissions, job queue, measurement)
  Phase 2: Enhanced families with better SEO & locale attributes
  Phase 3: Category restructuring with proper hierarchy
  Phase 4: Product model handling (configurable products)
  Phase 5: Full product import with association management
  Phase 6: SEO & locale optimization (en_US, fr_FR, ar_DZ)
  Phase 7: Comprehensive data audit with tuning recommendations
  Phase 8: Apply all tunings and fixes

Usage:
  python3 akeneo_master_sync.py --fix-platform          # Fix platform issues
  python3 akeneo_master_sync.py --enhance-families       # Better families/attributes
  python3 akeneo_master_sync.py --fix-categories         # Fix category structure
  python3 akeneo_master_sync.py --product-models         # Create product models
  python3 akeneo_master_sync.py --sync-products          # Full product sync
  python3 akeneo_master_sync.py --sync-associations      # Import associations
  python3 akeneo_master_sync.py --optimize-seo           # SEO & locale
  python3 akeneo_master_sync.py --audit                  # Full audit
  python3 akeneo_master_sync.py --apply-fixes            # Apply all fixes
  python3 akeneo_master_sync.py --all                    # Everything
"""

import sys, os, json, re, time, argparse, unicodedata, traceback
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
LOG_FILE = "/home/pim/public_html/var/logs/master_sync.log"
BATCH_SIZE = 100

# ============================================================
# ENHANCED ATTRIBUTE GROUPS (with ar_DZ labels)
# ============================================================
ATTRIBUTE_GROUPS = {
    "identification": {
        "labels": {"en_US": "Identification", "fr_FR": "Identification", "ar_DZ": "التعريف"},
        "sort_order": 1
    },
    "description": {
        "labels": {"en_US": "Description", "fr_FR": "Description", "ar_DZ": "الوصف"},
        "sort_order": 2
    },
    "pricing": {
        "labels": {"en_US": "Pricing", "fr_FR": "Tarification", "ar_DZ": "التسعير"},
        "sort_order": 3
    },
    "dimensions": {
        "labels": {"en_US": "Dimensions & Weight", "fr_FR": "Dimensions et Poids", "ar_DZ": "الأبعاد والوزن"},
        "sort_order": 4
    },
    "technical": {
        "labels": {"en_US": "Technical Specifications", "fr_FR": "Specifications Techniques", "ar_DZ": "المواصفات التقنية"},
        "sort_order": 5
    },
    "seo": {
        "labels": {"en_US": "SEO & Metadata", "fr_FR": "SEO et Metadonnees", "ar_DZ": "تحسين محركات البحث"},
        "sort_order": 6
    },
    "ecommerce": {
        "labels": {"en_US": "E-commerce & Visibility", "fr_FR": "E-commerce et Visibilite", "ar_DZ": "التجارة الإلكترونية"},
        "sort_order": 7
    },
    "marketing": {
        "labels": {"en_US": "Marketing & Branding", "fr_FR": "Marketing et Image de Marque", "ar_DZ": "التسويق والعلامة التجارية"},
        "sort_order": 8
    },
    "media": {
        "labels": {"en_US": "Media & Images", "fr_FR": "Media et Images", "ar_DZ": "الوسائط والصور"},
        "sort_order": 9
    },
}

# ============================================================
# ENHANCED ATTRIBUTE SCHEMA (with ar_DZ labels, better SEO)
# ============================================================
ATTRIBUTE_SCHEMA = {
    # -- Identification --
    "sku":            {"type": "pim_catalog_identifier", "group": "identification", "localizable": False, "scopable": False,
                       "labels": {"en_US": "SKU", "fr_FR": "SKU", "ar_DZ": "رمز المنتج"}},
    "name":           {"type": "pim_catalog_text", "group": "identification", "localizable": True, "scopable": False,
                       "labels": {"en_US": "Product Name", "fr_FR": "Nom du Produit", "ar_DZ": "اسم المنتج"}},
    "techno_ref":     {"type": "pim_catalog_text", "group": "identification", "localizable": False, "scopable": False,
                       "labels": {"en_US": "Techno Reference", "fr_FR": "Reference Techno", "ar_DZ": "المرجع التقني"}},
    "url_key":        {"type": "pim_catalog_text", "group": "seo", "localizable": False, "scopable": False,
                       "labels": {"en_US": "URL Key", "fr_FR": "Cle URL", "ar_DZ": "مفتاح الرابط"}},
    "manufacturer":   {"type": "pim_catalog_simpleselect", "group": "identification", "localizable": False, "scopable": False,
                       "labels": {"en_US": "Manufacturer", "fr_FR": "Fabricant", "ar_DZ": "الشركة المصنعة"}},
    "mgs_brand":      {"type": "pim_catalog_simpleselect", "group": "marketing", "localizable": False, "scopable": False,
                       "labels": {"en_US": "Brand", "fr_FR": "Marque", "ar_DZ": "العلامة التجارية"}},

    # -- Description --
    "description":    {"type": "pim_catalog_textarea", "group": "description", "localizable": True, "scopable": True,
                       "labels": {"en_US": "Description", "fr_FR": "Description", "ar_DZ": "الوصف"}, "wysiwyg": True},
    "short_description": {"type": "pim_catalog_textarea", "group": "description", "localizable": True, "scopable": True,
                       "labels": {"en_US": "Short Description", "fr_FR": "Description Courte", "ar_DZ": "وصف مختصر"}, "wysiwyg": True},

    # -- Pricing --
    "price":          {"type": "pim_catalog_price_collection", "group": "pricing", "localizable": False, "scopable": False,
                       "labels": {"en_US": "Price", "fr_FR": "Prix", "ar_DZ": "السعر"}},
    "special_price":  {"type": "pim_catalog_price_collection", "group": "pricing", "localizable": False, "scopable": False,
                       "labels": {"en_US": "Special Price", "fr_FR": "Prix Special", "ar_DZ": "سعر خاص"}},
    "cost":           {"type": "pim_catalog_price_collection", "group": "pricing", "localizable": False, "scopable": False,
                       "labels": {"en_US": "Cost", "fr_FR": "Cout", "ar_DZ": "التكلفة"}},

    # -- Dimensions --
    "weight":         {"type": "pim_catalog_metric", "group": "dimensions", "localizable": False, "scopable": False,
                       "labels": {"en_US": "Weight", "fr_FR": "Poids", "ar_DZ": "الوزن"},
                       "metric_family": "Weight", "default_metric_unit": "GRAM"},
    "size":           {"type": "pim_catalog_simpleselect", "group": "dimensions", "localizable": False, "scopable": False,
                       "labels": {"en_US": "Size", "fr_FR": "Taille", "ar_DZ": "الحجم"}},
    "dimension":      {"type": "pim_catalog_simpleselect", "group": "dimensions", "localizable": False, "scopable": False,
                       "labels": {"en_US": "Dimension", "fr_FR": "Dimension", "ar_DZ": "البعد"}},
    "diameter":       {"type": "pim_catalog_simpleselect", "group": "dimensions", "localizable": False, "scopable": False,
                       "labels": {"en_US": "Diameter", "fr_FR": "Diametre", "ar_DZ": "القطر"}},
    "thickness":      {"type": "pim_catalog_simpleselect", "group": "dimensions", "localizable": False, "scopable": False,
                       "labels": {"en_US": "Thickness", "fr_FR": "Epaisseur", "ar_DZ": "السمك"}},
    "format":         {"type": "pim_catalog_simpleselect", "group": "dimensions", "localizable": False, "scopable": False,
                       "labels": {"en_US": "Format", "fr_FR": "Format", "ar_DZ": "الصيغة"}},

    # -- Technical --
    "color":          {"type": "pim_catalog_simpleselect", "group": "technical", "localizable": False, "scopable": False,
                       "labels": {"en_US": "Color", "fr_FR": "Couleur", "ar_DZ": "اللون"}},
    "capacity":       {"type": "pim_catalog_simpleselect", "group": "technical", "localizable": False, "scopable": False,
                       "labels": {"en_US": "Capacity", "fr_FR": "Capacite", "ar_DZ": "السعة"}},
    "pattern":        {"type": "pim_catalog_simpleselect", "group": "technical", "localizable": False, "scopable": False,
                       "labels": {"en_US": "Pattern", "fr_FR": "Motif", "ar_DZ": "النمط"}},
    "type_product":   {"type": "pim_catalog_simpleselect", "group": "technical", "localizable": False, "scopable": False,
                       "labels": {"en_US": "Product Type", "fr_FR": "Type de Produit", "ar_DZ": "نوع المنتج"}},

    # -- SEO (enhanced) --
    "meta_title":     {"type": "pim_catalog_text", "group": "seo", "localizable": True, "scopable": False,
                       "labels": {"en_US": "Meta Title", "fr_FR": "Titre Meta", "ar_DZ": "عنوان ميتا"}},
    "meta_description": {"type": "pim_catalog_textarea", "group": "seo", "localizable": True, "scopable": False,
                       "labels": {"en_US": "Meta Description", "fr_FR": "Description Meta", "ar_DZ": "وصف ميتا"}},
    "meta_keyword":   {"type": "pim_catalog_textarea", "group": "seo", "localizable": True, "scopable": False,
                       "labels": {"en_US": "Meta Keywords", "fr_FR": "Mots-cles Meta", "ar_DZ": "كلمات ميتا"}},

    # -- E-commerce --
    "product_status": {"type": "pim_catalog_boolean", "group": "ecommerce", "localizable": False, "scopable": False,
                       "labels": {"en_US": "Enabled", "fr_FR": "Active", "ar_DZ": "مفعّل"}},
    "visibility":     {"type": "pim_catalog_simpleselect", "group": "ecommerce", "localizable": False, "scopable": False,
                       "labels": {"en_US": "Visibility", "fr_FR": "Visibilite", "ar_DZ": "الرؤية"}},
    "a_la_une":       {"type": "pim_catalog_boolean", "group": "ecommerce", "localizable": False, "scopable": False,
                       "labels": {"en_US": "Featured", "fr_FR": "A la Une", "ar_DZ": "مميز"}},
    "best_seller":    {"type": "pim_catalog_boolean", "group": "ecommerce", "localizable": False, "scopable": False,
                       "labels": {"en_US": "Best Seller", "fr_FR": "Meilleure Vente", "ar_DZ": "الأكثر مبيعاً"}},
    "trending":       {"type": "pim_catalog_boolean", "group": "ecommerce", "localizable": False, "scopable": False,
                       "labels": {"en_US": "Trending", "fr_FR": "Tendance", "ar_DZ": "رائج"}},
    "en_promo":       {"type": "pim_catalog_text", "group": "ecommerce", "localizable": False, "scopable": False,
                       "labels": {"en_US": "Promo Label", "fr_FR": "Libelle Promo", "ar_DZ": "تسمية العرض"}},
    "gender_product": {"type": "pim_catalog_simpleselect", "group": "ecommerce", "localizable": False, "scopable": False,
                       "labels": {"en_US": "Gender", "fr_FR": "Genre", "ar_DZ": "الجنس"}},

    # -- Marketing --
    "brand":          {"type": "pim_catalog_text", "group": "marketing", "localizable": False, "scopable": False,
                       "labels": {"en_US": "Brand Text", "fr_FR": "Marque (Texte)", "ar_DZ": "نص العلامة التجارية"}},
    "country_of_manufacture": {"type": "pim_catalog_text", "group": "marketing", "localizable": False, "scopable": False,
                       "labels": {"en_US": "Country of Manufacture", "fr_FR": "Pays de Fabrication", "ar_DZ": "بلد الصنع"}},
}

# ============================================================
# ENHANCED FAMILY DEFINITIONS (with better category-attribute mapping)
# ============================================================
VISIBILITY_MAP = {1: "not_visible_individually", 2: "in_catalog", 3: "in_search", 4: "catalog_and_search"}
VISIBILITY_OPTIONS = [
    {"code": "not_visible_individually", "labels": {"en_US": "Not Visible Individually", "fr_FR": "Non Visible Individuellement", "ar_DZ": "غير مرئي"}},
    {"code": "in_catalog", "labels": {"en_US": "Catalog", "fr_FR": "Catalogue", "ar_DZ": "الكتالوج"}},
    {"code": "in_search", "labels": {"en_US": "Search", "fr_FR": "Recherche", "ar_DZ": "البحث"}},
    {"code": "catalog_and_search", "labels": {"en_US": "Catalog, Search", "fr_FR": "Catalogue et Recherche", "ar_DZ": "الكتالوج والبحث"}},
]

# Enhanced family map with better attribute distribution
BASE_FAMILY_ATTRS = [
    "sku", "name", "description", "short_description", "price", "special_price",
    "weight", "url_key", "product_status", "visibility", "meta_title",
    "meta_description", "meta_keyword", "mgs_brand", "manufacturer",
    "techno_ref", "color", "a_la_une", "best_seller", "trending", "en_promo",
    "brand", "cost", "country_of_manufacture"
]

FAMILY_DEFINITIONS = {
    "stationery": {
        "labels": {"en_US": "General Stationery", "fr_FR": "Fournitures Generales", "ar_DZ": "قرطاسية عامة"},
        "magento_sets": ["Products", "Techno", "Maglux", "SCOLAIRE", "madeInAlgeria"],
        "extra_attrs": ["size", "dimension", "capacity", "format", "pattern", "type_product", "gender_product", "diameter", "thickness"],
        "attribute_requirements": {"ecommerce": ["sku", "name", "price", "meta_title", "meta_description", "url_key"]},
    },
    "writing": {
        "labels": {"en_US": "Writing Instruments", "fr_FR": "Instruments d'Ecriture", "ar_DZ": "أدوات الكتابة"},
        "magento_sets": ["ECRITURE", "CRAYONS"],
        "extra_attrs": ["capacity", "thickness", "pattern", "type_product", "diameter"],
        "attribute_requirements": {"ecommerce": ["sku", "name", "price", "color", "meta_title", "meta_description", "url_key"]},
    },
    "notebooks": {
        "labels": {"en_US": "Notebooks & Cahiers", "fr_FR": "Cahiers et Carnets", "ar_DZ": "دفاتر وكراسات"},
        "magento_sets": ["CAHIER"],
        "extra_attrs": ["format", "dimension", "pattern", "type_product"],
        "attribute_requirements": {"ecommerce": ["sku", "name", "price", "format", "meta_title", "meta_description", "url_key"]},
    },
    "office": {
        "labels": {"en_US": "Office Supplies", "fr_FR": "Fournitures de Bureau", "ar_DZ": "مستلزمات المكتب"},
        "magento_sets": ["BUREAUTIQUE", "CALCULATRICES", "INFORMATIQUE", "TABLEAU"],
        "extra_attrs": ["format", "dimension", "capacity", "type_product"],
        "attribute_requirements": {"ecommerce": ["sku", "name", "price", "meta_title", "meta_description", "url_key"]},
    },
    "bags": {
        "labels": {"en_US": "Bags & Accessories", "fr_FR": "Sacs et Accessoires", "ar_DZ": "حقائب وإكسسوارات"},
        "magento_sets": ["Bags Sac"],
        "extra_attrs": ["size", "dimension", "pattern", "gender_product", "type_product"],
        "attribute_requirements": {"ecommerce": ["sku", "name", "price", "size", "color", "meta_title", "meta_description", "url_key"]},
    },
    "arts": {
        "labels": {"en_US": "Fine Arts Supplies", "fr_FR": "Fournitures Beaux-Arts", "ar_DZ": "مستلزمات الفنون الجميلة"},
        "magento_sets": ["BEAUX ARTS"],
        "extra_attrs": ["capacity", "format", "pattern", "type_product"],
        "attribute_requirements": {"ecommerce": ["sku", "name", "price", "color", "meta_title", "meta_description", "url_key"]},
    },
}

# Build reverse lookup: magento_set -> akeneo_family
SET_TO_FAMILY = {}
for fam_code, fam_def in FAMILY_DEFINITIONS.items():
    for s in fam_def["magento_sets"]:
        SET_TO_FAMILY[s] = fam_code

# Categories to exclude from product assignment
EXCLUDED_CATEGORIES = {"default_category", "root_catalog", "tous_les_produits", "root", "master"}

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

    def get_all(self, ep, params=None):
        """Paginate through all results"""
        items = []
        p = params or {}
        p.setdefault("limit", 100)
        while True:
            r = self.get(ep, p)
            if r.status_code != 200:
                break
            data = r.json()
            items.extend(data.get("_embedded", {}).get("items", []))
            next_link = data.get("_links", {}).get("next", {}).get("href")
            if not next_link:
                break
            # Parse next page URL
            from urllib.parse import urlparse, parse_qs
            parsed = urlparse(next_link)
            qs = parse_qs(parsed.query)
            p = {k: v[0] if len(v) == 1 else v for k, v in qs.items()}
        return items

    def patch(self, ep, data):
        r = requests.patch(f"{self.base}/api/rest/v1/{ep}", headers={**self.h(), "Content-Type": "application/json"}, json=data)
        if r.status_code == 401:
            self.auth()
            r = requests.patch(f"{self.base}/api/rest/v1/{ep}", headers={**self.h(), "Content-Type": "application/json"}, json=data)
        return r

    def post(self, ep, data):
        r = requests.post(f"{self.base}/api/rest/v1/{ep}", headers={**self.h(), "Content-Type": "application/json"}, json=data)
        if r.status_code == 401:
            self.auth()
            r = requests.post(f"{self.base}/api/rest/v1/{ep}", headers={**self.h(), "Content-Type": "application/json"}, json=data)
        return r

    def patch_batch(self, ep, items):
        """Send batch PATCH (JSONL body)"""
        body = "\n".join(json.dumps(item) for item in items)
        headers = {**self.h(), "Content-Type": "application/vnd.akeneo.collection+json"}
        r = requests.patch(f"{self.base}/api/rest/v1/{ep}", headers=headers, data=body)
        if r.status_code == 401:
            self.auth()
            headers = {**self.h(), "Content-Type": "application/vnd.akeneo.collection+json"}
            r = requests.patch(f"{self.base}/api/rest/v1/{ep}", headers=headers, data=body)
        return r


def get_magento_db():
    return mysql.connector.connect(**MAGENTO_DB)

def get_akeneo_db():
    return mysql.connector.connect(**AKENEO_DB)


# ============================================================
# PHASE 1: FIX PLATFORM ISSUES
# ============================================================
def fix_platform(api):
    """Fix known platform issues: weight metric, job params, locales, channels"""
    log("=" * 60)
    log("PHASE 1: Fixing Platform Issues")
    log("=" * 60)

    # Fix weight metric family via DB
    log("Fixing weight attribute metric family...")
    try:
        conn = get_akeneo_db()
        cur = conn.cursor()
        cur.execute("""
            UPDATE pim_catalog_attribute 
            SET properties = 'a:2:{s:13:"metric_family";s:6:"Weight";s:19:"default_metric_unit";s:4:"GRAM";}'
            WHERE code = 'weight' AND attribute_type = 'pim_catalog_metric'
            AND (properties = 'a:0:{}' OR properties IS NULL OR properties NOT LIKE '%metric_family%')
        """)
        if cur.rowcount > 0:
            log(f"  Fixed weight attribute metric properties ({cur.rowcount} row)")
        else:
            log("  Weight attribute metric already configured")
        conn.commit()
        cur.close()
        conn.close()
    except Exception as e:
        log(f"  DB fix skipped: {e}", "WARN")

    # Ensure locales exist
    log("Checking locales...")
    for locale in LOCALES:
        r = api.get(f"locales/{locale}")
        if r.status_code == 200:
            data = r.json()
            if data.get("enabled"):
                log(f"  Locale {locale}: active")
            else:
                log(f"  Locale {locale}: exists but not enabled")
        else:
            log(f"  Locale {locale}: not found (status {r.status_code})")

    # Ensure channel exists and has locales
    log("Checking ecommerce channel...")
    r = api.get(f"channels/{CHANNEL}")
    if r.status_code == 200:
        ch = r.json()
        current_locales = ch.get("locales", [])
        current_currencies = ch.get("currencies", [])
        log(f"  Channel {CHANNEL}: locales={current_locales}, currencies={current_currencies}")

        # Add missing locales to channel
        needed_locales = [l for l in LOCALES if l in current_locales or True]  # Only add if locale is active
        if set(current_locales) != set(LOCALES):
            active_locales = []
            for l in LOCALES:
                lr = api.get(f"locales/{l}")
                if lr.status_code == 200 and lr.json().get("enabled"):
                    active_locales.append(l)
            if active_locales and set(active_locales) != set(current_locales):
                r2 = api.patch(f"channels/{CHANNEL}", {"locales": active_locales})
                log(f"  Updated channel locales: {active_locales} (status {r2.status_code})")
    else:
        log(f"  Channel {CHANNEL} not found", "ERROR")

    # Ensure visibility options exist
    log("Checking visibility attribute options...")
    r = api.get("attributes/visibility/options", {"limit": 100})
    if r.status_code == 200:
        existing = {o["code"] for o in r.json().get("_embedded", {}).get("items", [])}
        for opt in VISIBILITY_OPTIONS:
            if opt["code"] not in existing:
                r2 = api.post("attributes/visibility/options", opt)
                log(f"  Created visibility option: {opt['code']} ({r2.status_code})")
            else:
                # Update labels
                r2 = api.patch(f"attributes/visibility/options/{opt['code']}", {"labels": opt["labels"]})
                log(f"  Updated visibility option labels: {opt['code']}")
    log("Phase 1 complete.\n")


# ============================================================
# PHASE 2: ENHANCE FAMILIES WITH BETTER ATTRIBUTES
# ============================================================
def enhance_families(api):
    """Create/update attribute groups, attributes, and families with SEO+locale support"""
    log("=" * 60)
    log("PHASE 2: Enhancing Families & Attributes")
    log("=" * 60)

    # Update attribute groups (with ar_DZ)
    log("Updating attribute groups...")
    for code, grp in ATTRIBUTE_GROUPS.items():
        payload = {"code": code, "labels": grp["labels"], "sort_order": grp["sort_order"]}
        r = api.patch(f"attribute-groups/{code}", payload)
        if r.status_code in (201, 204):
            log(f"  Group {code}: OK")
        else:
            log(f"  Group {code}: {r.status_code}")

    # Update attributes (with ar_DZ labels)
    log("Updating attributes...")
    created = updated = 0
    for code, schema in ATTRIBUTE_SCHEMA.items():
        if code == "sku":
            # Just update labels for identifier
            r = api.patch(f"attributes/{code}", {"labels": schema.get("labels", {})})
            if r.status_code in (200, 204):
                updated += 1
            continue

        payload = {
            "code": code,
            "type": schema["type"],
            "group": schema["group"],
            "localizable": schema.get("localizable", False),
            "scopable": schema.get("scopable", False),
            "labels": schema.get("labels", {}),
        }
        if schema["type"] == "pim_catalog_metric":
            payload["metric_family"] = schema.get("metric_family", "Weight")
            payload["default_metric_unit"] = schema.get("default_metric_unit", "GRAM")
            payload["negative_allowed"] = False
            payload["decimals_allowed"] = True

        r = api.patch(f"attributes/{code}", payload)
        if r.status_code == 201:
            created += 1
        elif r.status_code in (200, 204):
            updated += 1
        else:
            log(f"  Attr {code}: {r.status_code} {r.text[:100]}", "WARN")

    log(f"  Attributes: {created} created, {updated} updated")

    # Update families
    log("Updating families...")
    for fam_code, fam_def in FAMILY_DEFINITIONS.items():
        all_attrs = list(BASE_FAMILY_ATTRS) + fam_def.get("extra_attrs", [])
        # Remove duplicates preserving order
        seen = set()
        unique_attrs = []
        for a in all_attrs:
            if a not in seen:
                seen.add(a)
                unique_attrs.append(a)

        payload = {
            "code": fam_code,
            "labels": fam_def["labels"],
            "attributes": unique_attrs,
            "attribute_as_label": "name",
            "attribute_as_image": None,
        }

        # Add attribute requirements
        if "attribute_requirements" in fam_def:
            payload["attribute_requirements"] = fam_def["attribute_requirements"]

        r = api.patch(f"families/{fam_code}", payload)
        if r.status_code in (200, 201, 204):
            log(f"  Family {fam_code}: OK ({len(unique_attrs)} attrs)")
        else:
            log(f"  Family {fam_code}: {r.status_code} {r.text[:200]}", "WARN")

    log("Phase 2 complete.\n")


# ============================================================
# PHASE 3: FIX CATEGORIES
# ============================================================
def fix_categories(api):
    """Restructure categories - fix missing, clean up, proper hierarchy"""
    log("=" * 60)
    log("PHASE 3: Fixing Category Structure")
    log("=" * 60)

    conn = get_magento_db()
    cur = conn.cursor(dictionary=True)

    # Get all Magento categories with hierarchy
    cur.execute("""
        SELECT e.entity_id, e.parent_id, e.path, e.level, e.position,
               v_name.value as name, v_active.value as is_active,
               v_url.value as url_key
        FROM catalog_category_entity e
        LEFT JOIN catalog_category_entity_varchar v_name 
            ON e.entity_id = v_name.entity_id AND v_name.attribute_id = (
                SELECT attribute_id FROM eav_attribute WHERE attribute_code='name' AND entity_type_id=3
            ) AND v_name.store_id = 0
        LEFT JOIN catalog_category_entity_int v_active 
            ON e.entity_id = v_active.entity_id AND v_active.attribute_id = (
                SELECT attribute_id FROM eav_attribute WHERE attribute_code='is_active' AND entity_type_id=3
            ) AND v_active.store_id = 0
        LEFT JOIN catalog_category_entity_varchar v_url 
            ON e.entity_id = v_url.entity_id AND v_url.attribute_id = (
                SELECT attribute_id FROM eav_attribute WHERE attribute_code='url_key' AND entity_type_id=3
            ) AND v_url.store_id = 0
        WHERE e.level >= 1
        ORDER BY e.level, e.position
    """)
    categories = cur.fetchall()

    # Build lookup
    cat_by_id = {c["entity_id"]: c for c in categories}
    log(f"  Found {len(categories)} Magento categories")

    # Get existing Akeneo categories
    existing_cats = {}
    page = 1
    while True:
        r = api.get("categories", {"limit": 100, "page": page})
        if r.status_code != 200:
            break
        items = r.json().get("_embedded", {}).get("items", [])
        if not items:
            break
        for c in items:
            existing_cats[c["code"]] = c
        page += 1
    log(f"  Existing Akeneo categories: {len(existing_cats)}")

    # Ensure master root exists
    if "master" not in existing_cats:
        r = api.patch("categories/master", {"code": "master", "labels": {"en_US": "Master Catalog", "fr_FR": "Catalogue Principal", "ar_DZ": "الكتالوج الرئيسي"}})
        log(f"  Created master root: {r.status_code}")

    # Process categories
    batch = []
    cat_code_map = {}  # magento entity_id -> akeneo code
    created = updated = 0

    for cat in categories:
        name = cat["name"] or ""
        if not name.strip():
            continue

        code = slugify(name)
        if not code or code in EXCLUDED_CATEGORIES:
            continue

        # Make unique if needed
        orig_code = code
        suffix = 1
        while code in cat_code_map.values() and cat_code_map.get(cat["entity_id"]) != code:
            code = f"{orig_code}_{suffix}"
            suffix += 1

        cat_code_map[cat["entity_id"]] = code

        # Determine parent
        parent = "master"
        if cat["parent_id"] and cat["parent_id"] in cat_code_map:
            parent = cat_code_map[cat["parent_id"]]

        payload = {
            "code": code,
            "parent": parent,
            "labels": {
                "en_US": name.strip(),
                "fr_FR": name.strip(),
            }
        }

        batch.append(payload)
        if len(batch) >= BATCH_SIZE:
            r = api.patch_batch("categories", batch)
            if r.status_code == 200:
                results = parse_jsonl(r)
                c = sum(1 for x in results if x.get("status_code") == 201)
                u = sum(1 for x in results if x.get("status_code") == 204)
                created += c
                updated += u
            batch = []

    # Final batch
    if batch:
        r = api.patch_batch("categories", batch)
        if r.status_code == 200:
            results = parse_jsonl(r)
            c = sum(1 for x in results if x.get("status_code") == 201)
            u = sum(1 for x in results if x.get("status_code") == 204)
            created += c
            updated += u

    cur.close()
    conn.close()
    log(f"  Categories: {created} created, {updated} updated")
    log("Phase 3 complete.\n")
    return cat_code_map


# ============================================================
# PHASE 4: PRODUCT MODELS (Configurable Products)
# ============================================================
def create_product_models(api):
    """Create product models for Magento configurable products - optimized batch approach"""
    log("=" * 60)
    log("PHASE 4: Product Model Handling")
    log("=" * 60)

    conn = get_magento_db()
    cur = conn.cursor(dictionary=True)

    # Get axis combinations per configurable
    cur.execute("""
        SELECT sa.product_id as parent_id,
               GROUP_CONCAT(ea.attribute_code ORDER BY ea.attribute_code) as axes_str,
               parent.sku as parent_sku,
               psa.attribute_set_name,
               v_name.value as name
        FROM catalog_product_super_attribute sa
        JOIN eav_attribute ea ON sa.attribute_id = ea.attribute_id
        JOIN catalog_product_entity parent ON sa.product_id = parent.entity_id
        JOIN eav_attribute_set psa ON parent.attribute_set_id = psa.attribute_set_id
        LEFT JOIN catalog_product_entity_varchar v_name 
            ON parent.entity_id = v_name.entity_id 
            AND v_name.attribute_id = (SELECT attribute_id FROM eav_attribute WHERE attribute_code='name' AND entity_type_id=4)
            AND v_name.store_id = 0
        WHERE parent.type_id = 'configurable'
        GROUP BY sa.product_id
        ORDER BY parent.entity_id
    """)
    parents = cur.fetchall()
    log(f"  Found {len(parents)} configurable products")

    if not parents:
        cur.close(); conn.close()
        log("  No configurable products to process"); log("Phase 4 complete.\n"); return

    # Valid axes from our schema
    valid_axes = {c for c, s in ATTRIBUTE_SCHEMA.items() if s["type"] == "pim_catalog_simpleselect"}
    # Map Magento axis names to Akeneo (handle 'type' -> 'type_product')
    AXIS_REMAP = {"type": "type_product"}

    # Group by (family, axes_combo) to create one family variant per combo
    combo_groups = defaultdict(list)  # (family, axes_tuple) -> [parent_data]
    for p in parents:
        family = SET_TO_FAMILY.get(p["attribute_set_name"], "stationery")
        raw_axes = [a.strip() for a in p["axes_str"].split(",")]
        axes = [AXIS_REMAP.get(a, a) for a in raw_axes if AXIS_REMAP.get(a, a) in valid_axes]
        if not axes:
            continue
        key = (family, tuple(sorted(axes)))
        combo_groups[key].append(p)

    log(f"  Unique (family, axes) combos: {len(combo_groups)}")

    # Create family variants per combo
    variant_map = {}  # (family, axes_tuple) -> variant_code
    for (family, axes_tuple), group in combo_groups.items():
        axes_list = list(axes_tuple)
        variant_code = f"{family}_{'_'.join(axes_list[:3])}"[:40]

        payload = {
            "code": variant_code,
            "labels": {
                "en_US": f"{FAMILY_DEFINITIONS.get(family, {}).get('labels', {}).get('en_US', family)} by {', '.join(axes_list)}",
                "fr_FR": f"{FAMILY_DEFINITIONS.get(family, {}).get('labels', {}).get('fr_FR', family)} par {', '.join(axes_list)}",
            },
            "variant_attribute_sets": [{
                "level": 1,
                "axes": axes_list[:5],
                "attributes": axes_list[:5],
            }]
        }

        r = api.patch(f"families/{family}/variants/{variant_code}", payload)
        if r.status_code in (200, 201, 204):
            variant_map[(family, axes_tuple)] = variant_code
            log(f"  Variant {variant_code}: OK (axes: {axes_list}, {len(group)} products)")
        elif r.status_code == 422:
            # Try listing existing variants for this family
            r2 = api.get(f"families/{family}/variants", {"limit": 100})
            if r2.status_code == 200:
                existing = r2.json().get("_embedded", {}).get("items", [])
                # Find one with matching axes
                for ev in existing:
                    ev_axes = set()
                    for vas in ev.get("variant_attribute_sets", []):
                        ev_axes.update(vas.get("axes", []))
                    if ev_axes == set(axes_list):
                        variant_map[(family, axes_tuple)] = ev["code"]
                        log(f"  Using existing variant {ev['code']} for axes {axes_list}")
                        break
                else:
                    log(f"  Variant {variant_code}: 422 - {r.text[:150]}", "WARN")
        else:
            log(f"  Variant {variant_code}: {r.status_code}", "WARN")

    log(f"  Created {len(variant_map)} family variants")

    # Create product models (batch approach for speed)
    log("  Creating product models...")
    models_created = models_updated = models_errors = 0
    batch = []

    for (family, axes_tuple), group in combo_groups.items():
        variant_code = variant_map.get((family, axes_tuple))
        if not variant_code:
            continue

        for p in group:
            sku = str(p["parent_sku"]).strip()
            if not sku or sku == "/":
                continue
            model_code = slugify(sku) or f"model_{p['parent_id']}"
            name = (p["name"] or sku)[:200]

            batch.append({
                "code": model_code,
                "family_variant": variant_code,
                "values": {"name": [{"locale": "en_US", "scope": None, "data": name}]},
            })

            if len(batch) >= BATCH_SIZE:
                r = api.patch_batch("product-models", batch)
                if r.status_code == 200:
                    results = parse_jsonl(r)
                    models_created += sum(1 for x in results if x.get("status_code") == 201)
                    models_updated += sum(1 for x in results if x.get("status_code") == 204)
                    errs = [x for x in results if x.get("status_code") not in (201, 204)]
                    models_errors += len(errs)
                    if errs and models_errors <= 5:
                        log(f"  Sample error: {json.dumps(errs[0])[:200]}", "WARN")
                else:
                    models_errors += len(batch)
                    if models_errors <= 5:
                        log(f"  Batch failed: {r.status_code} {r.text[:200]}", "WARN")
                batch = []

    if batch:
        r = api.patch_batch("product-models", batch)
        if r.status_code == 200:
            results = parse_jsonl(r)
            models_created += sum(1 for x in results if x.get("status_code") == 201)
            models_updated += sum(1 for x in results if x.get("status_code") == 204)
            models_errors += sum(1 for x in results if x.get("status_code") not in (201, 204))

    log(f"  Product models: {models_created} created, {models_updated} updated, {models_errors} errors")

    # Now assign children to models via batch
    log("  Assigning child products to models...")
    cur.execute("""
        SELECT parent.sku as parent_sku, child.sku as child_sku
        FROM catalog_product_super_link sl
        JOIN catalog_product_entity parent ON sl.parent_id = parent.entity_id
        JOIN catalog_product_entity child ON sl.product_id = child.entity_id
    """)
    links = cur.fetchall()
    cur.close(); conn.close()

    batch = []
    children_assigned = children_errors = 0
    for link in links:
        parent_code = slugify(str(link["parent_sku"]).strip())
        child_sku = str(link["child_sku"]).strip()
        if parent_code and child_sku:
            batch.append({"identifier": child_sku, "parent": parent_code})

        if len(batch) >= BATCH_SIZE:
            r = api.patch_batch("products", batch)
            if r.status_code == 200:
                results = parse_jsonl(r)
                children_assigned += sum(1 for x in results if x.get("status_code") in (200, 201, 204))
                children_errors += sum(1 for x in results if x.get("status_code") not in (200, 201, 204))
            else:
                children_errors += len(batch)
            batch = []

    if batch:
        r = api.patch_batch("products", batch)
        if r.status_code == 200:
            results = parse_jsonl(r)
            children_assigned += sum(1 for x in results if x.get("status_code") in (200, 201, 204))
            children_errors += sum(1 for x in results if x.get("status_code") not in (200, 201, 204))

    log(f"  Children: {children_assigned} assigned, {children_errors} errors")
    log("Phase 4 complete.\n")


# ============================================================
# PHASE 5: FULL PRODUCT SYNC
# ============================================================
def sync_products(api, limit=None):
    """Full product sync from Magento to Akeneo with proper mapping"""
    log("=" * 60)
    log("PHASE 5: Full Product Sync")
    log("=" * 60)

    conn = get_magento_db()
    cur = conn.cursor(dictionary=True)

    # Get products
    limit_sql = f"LIMIT {limit}" if limit else ""
    cur.execute(f"""
        SELECT e.entity_id, e.sku, e.type_id, e.attribute_set_id,
               psa.attribute_set_name
        FROM catalog_product_entity e
        JOIN eav_attribute_set psa ON e.attribute_set_id = psa.attribute_set_id
        WHERE e.type_id IN ('simple', 'virtual')
        ORDER BY e.entity_id
        {limit_sql}
    """)
    products = cur.fetchall()
    log(f"  Found {len(products)} products to sync")

    # Pre-load attribute values
    # Get text attributes
    text_attrs = {}
    cur.execute("""
        SELECT ea.attribute_code, ev.entity_id, ev.value, ev.store_id
        FROM catalog_product_entity_varchar ev
        JOIN eav_attribute ea ON ev.attribute_id = ea.attribute_id
        WHERE ea.entity_type_id = 4 AND ev.store_id = 0
        AND ea.attribute_code IN ('name','url_key','techno_ref','brand','country_of_manufacture','en_promo')
    """)
    for row in cur.fetchall():
        text_attrs.setdefault(row["entity_id"], {})[row["attribute_code"]] = row["value"]

    # Get text area attributes
    cur.execute("""
        SELECT ea.attribute_code, ev.entity_id, ev.value, ev.store_id
        FROM catalog_product_entity_text ev
        JOIN eav_attribute ea ON ev.attribute_id = ea.attribute_id
        WHERE ea.entity_type_id = 4 AND ev.store_id = 0
        AND ea.attribute_code IN ('description','short_description','meta_title','meta_description','meta_keyword')
    """)
    for row in cur.fetchall():
        text_attrs.setdefault(row["entity_id"], {})[row["attribute_code"]] = row["value"]

    # Also get varchar meta_ fields
    cur.execute("""
        SELECT ea.attribute_code, ev.entity_id, ev.value, ev.store_id
        FROM catalog_product_entity_varchar ev
        JOIN eav_attribute ea ON ev.attribute_id = ea.attribute_id
        WHERE ea.entity_type_id = 4 AND ev.store_id = 0
        AND ea.attribute_code IN ('meta_title','meta_description','meta_keyword')
    """)
    for row in cur.fetchall():
        # Don't overwrite text values with empty varchar
        if row["value"] and row["value"].strip():
            text_attrs.setdefault(row["entity_id"], {})[row["attribute_code"]] = row["value"]

    # Get decimal attributes (price, weight, etc)
    decimal_attrs = {}
    cur.execute("""
        SELECT ea.attribute_code, ev.entity_id, ev.value
        FROM catalog_product_entity_decimal ev
        JOIN eav_attribute ea ON ev.attribute_id = ea.attribute_id
        WHERE ea.entity_type_id = 4 AND ev.store_id = 0
        AND ea.attribute_code IN ('price','special_price','cost','weight')
    """)
    for row in cur.fetchall():
        decimal_attrs.setdefault(row["entity_id"], {})[row["attribute_code"]] = row["value"]

    # Get int attributes (status, visibility, booleans)
    int_attrs = {}
    cur.execute("""
        SELECT ea.attribute_code, ev.entity_id, ev.value
        FROM catalog_product_entity_int ev
        JOIN eav_attribute ea ON ev.attribute_id = ea.attribute_id
        WHERE ea.entity_type_id = 4 AND ev.store_id = 0
        AND ea.attribute_code IN ('status','visibility','a_la_une','best_seller','trending')
    """)
    for row in cur.fetchall():
        int_attrs.setdefault(row["entity_id"], {})[row["attribute_code"]] = row["value"]

    # Get select attribute labels
    select_labels = {}
    cur.execute("""
        SELECT ea.attribute_code, ev.entity_id, ev.value as option_id,
               COALESCE(ov.value, CAST(ev.value AS CHAR)) as label
        FROM catalog_product_entity_int ev
        JOIN eav_attribute ea ON ev.attribute_id = ea.attribute_id
        LEFT JOIN eav_attribute_option_value ov ON ev.value = ov.option_id AND ov.store_id = 0
        WHERE ea.entity_type_id = 4 AND ev.store_id = 0
        AND ea.attribute_code IN ('color','manufacturer','mgs_brand','capacity','pattern','size','dimension','diameter','thickness','format','gender_product','type_product')
        AND ev.value IS NOT NULL AND ev.value > 0
    """)
    for row in cur.fetchall():
        label = row["label"]
        if label:
            select_labels.setdefault(row["entity_id"], {})[row["attribute_code"]] = slugify(label)

    # Get category assignments
    cat_assignments = defaultdict(list)
    cur.execute("""
        SELECT cp.product_id, ce.entity_id as cat_id,
               v.value as cat_name
        FROM catalog_category_product cp
        JOIN catalog_category_entity ce ON cp.category_id = ce.entity_id
        LEFT JOIN catalog_category_entity_varchar v ON ce.entity_id = v.entity_id 
            AND v.attribute_id = (SELECT attribute_id FROM eav_attribute WHERE attribute_code='name' AND entity_type_id=3)
            AND v.store_id = 0
    """)
    for row in cur.fetchall():
        if row["cat_name"]:
            cat_code = slugify(row["cat_name"])
            if cat_code and cat_code not in EXCLUDED_CATEGORIES:
                cat_assignments[row["product_id"]].append(cat_code)

    cur.close()
    conn.close()

    # Build and send products
    stats = {"created": 0, "updated": 0, "errors": 0, "skipped": 0}
    batch = []

    for prod in products:
        eid = prod["entity_id"]
        sku = str(prod["sku"]).strip()
        if not sku or len(sku) > 255:
            stats["skipped"] += 1
            continue

        # Determine family
        family = SET_TO_FAMILY.get(prod["attribute_set_name"], "stationery")

        # Build values
        vals = {}
        txt = text_attrs.get(eid, {})
        dec = decimal_attrs.get(eid, {})
        ints = int_attrs.get(eid, {})
        sels = select_labels.get(eid, {})

        # Text attributes
        for attr in ["name", "meta_title"]:
            v = txt.get(attr)
            if v and v.strip():
                vals[attr] = [{"locale": "en_US", "scope": None, "data": v.strip()[:255]}]

        for attr in ["description", "short_description"]:
            v = txt.get(attr)
            if v and v.strip():
                vals[attr] = [{"locale": "en_US", "scope": CHANNEL, "data": v.strip()}]

        for attr in ["meta_description", "meta_keyword"]:
            v = txt.get(attr)
            if v and v.strip():
                vals[attr] = [{"locale": "en_US", "scope": None, "data": v.strip()}]

        for attr in ["techno_ref", "url_key", "brand", "country_of_manufacture", "en_promo"]:
            v = txt.get(attr)
            if v and v.strip():
                vals[attr] = [{"locale": None, "scope": None, "data": v.strip()[:255]}]

        # Prices
        for attr in ["price", "special_price", "cost"]:
            v = dec.get(attr)
            if v is not None:
                vals[attr] = [{"locale": None, "scope": None, "data": [{"amount": str(v), "currency": CURRENCY}]}]

        # Weight
        w = dec.get("weight")
        if w is not None:
            vals["weight"] = [{"locale": None, "scope": None, "data": {"amount": str(w), "unit": "GRAM"}}]

        # Booleans
        status = ints.get("status")
        vals["product_status"] = [{"locale": None, "scope": None, "data": status == 1 if status is not None else True}]

        for attr in ["a_la_une", "best_seller", "trending"]:
            v = ints.get(attr)
            if v is not None:
                vals[attr] = [{"locale": None, "scope": None, "data": bool(v)}]

        # Visibility (special mapping)
        vis = ints.get("visibility")
        if vis and vis in VISIBILITY_MAP:
            vals["visibility"] = [{"locale": None, "scope": None, "data": VISIBILITY_MAP[vis]}]

        # Select attributes
        for attr in ["color", "manufacturer", "mgs_brand", "capacity", "pattern", "size", "dimension",
                      "diameter", "thickness", "format", "gender_product", "type_product"]:
            v = sels.get(attr)
            if v:
                vals[attr] = [{"locale": None, "scope": None, "data": v}]

        # Categories
        cats = cat_assignments.get(eid, [])

        item = {
            "identifier": sku,
            "family": family,
            "categories": cats[:20],
            "values": vals,
        }
        batch.append(item)

        if len(batch) >= BATCH_SIZE:
            r = api.patch_batch("products", batch)
            if r.status_code == 200:
                results = parse_jsonl(r)
                c = sum(1 for x in results if x.get("status_code") == 201)
                u = sum(1 for x in results if x.get("status_code") == 204)
                e = sum(1 for x in results if x.get("status_code") not in (201, 204))
                stats["created"] += c
                stats["updated"] += u
                stats["errors"] += e
                if e > 0 and stats["errors"] <= 5:
                    errs = [x for x in results if x.get("status_code") not in (201, 204)][:3]
                    for err in errs:
                        log(f"  Error: {err.get('identifier', '?')}: {json.dumps(err.get('message', err.get('errors', '')))[:200]}", "WARN")
            else:
                stats["errors"] += len(batch)
                log(f"  Batch failed: {r.status_code}", "ERROR")
            batch = []

    # Final batch
    if batch:
        r = api.patch_batch("products", batch)
        if r.status_code == 200:
            results = parse_jsonl(r)
            c = sum(1 for x in results if x.get("status_code") == 201)
            u = sum(1 for x in results if x.get("status_code") == 204)
            e = sum(1 for x in results if x.get("status_code") not in (201, 204))
            stats["created"] += c
            stats["updated"] += u
            stats["errors"] += e
        else:
            stats["errors"] += len(batch)

    log(f"  Product sync: {stats['created']} created, {stats['updated']} updated, {stats['errors']} errors, {stats['skipped']} skipped")
    log("Phase 5 complete.\n")
    return stats


# ============================================================
# PHASE 5B: IMPORT ASSOCIATIONS
# ============================================================
def sync_associations(api):
    """Import product associations from Magento (related, upsell, crosssell)"""
    log("=" * 60)
    log("PHASE 5B: Importing Product Associations")
    log("=" * 60)

    conn = get_magento_db()
    cur = conn.cursor(dictionary=True)

    # Ensure association types exist in Akeneo
    assoc_types = {
        "RELATED": {"labels": {"en_US": "Related Products", "fr_FR": "Produits Associes", "ar_DZ": "منتجات مرتبطة"}},
        "UPSELL": {"labels": {"en_US": "Up-sell Products", "fr_FR": "Produits Complementaires", "ar_DZ": "منتجات بديلة أفضل"}},
        "CROSSSELL": {"labels": {"en_US": "Cross-sell Products", "fr_FR": "Ventes Croisees", "ar_DZ": "منتجات تكميلية"}},
    }

    for code, data in assoc_types.items():
        payload = {"code": code, "labels": data["labels"], "is_quantified": False}
        r = api.patch(f"association-types/{code}", payload)
        if r.status_code in (200, 201, 204):
            log(f"  Association type {code}: OK")
        else:
            log(f"  Association type {code}: {r.status_code} {r.text[:100]}", "WARN")

    # Get Magento associations: related products
    cur.execute("""
        SELECT pl.product_id, pe1.sku as source_sku, pl.linked_product_id, pe2.sku as target_sku, pl.link_type_id
        FROM catalog_product_link pl
        JOIN catalog_product_entity pe1 ON pl.product_id = pe1.entity_id
        JOIN catalog_product_entity pe2 ON pl.linked_product_id = pe2.entity_id
        WHERE pl.link_type_id IN (1, 4, 5)
        ORDER BY pl.product_id
    """)
    # link_type_id: 1=related, 4=upsell, 5=crosssell
    links = cur.fetchall()

    cur.close()
    conn.close()

    log(f"  Found {len(links)} product associations in Magento")

    if not links:
        log("  No associations to import")
        log("Phase 5B complete.\n")
        return

    # Group by source product
    LINK_TYPE_MAP = {1: "RELATED", 4: "UPSELL", 5: "CROSSSELL"}
    product_assocs = defaultdict(lambda: defaultdict(list))

    for link in links:
        src_sku = str(link["source_sku"]).strip()
        tgt_sku = str(link["target_sku"]).strip()
        assoc_type = LINK_TYPE_MAP.get(link["link_type_id"])
        if src_sku and tgt_sku and assoc_type:
            if tgt_sku not in product_assocs[src_sku][assoc_type]:
                product_assocs[src_sku][assoc_type].append(tgt_sku)

    log(f"  Products with associations: {len(product_assocs)}")

    # Send in batches
    stats = {"updated": 0, "errors": 0}
    batch = []

    for sku, assocs in product_assocs.items():
        item = {
            "identifier": sku,
            "associations": {}
        }
        for assoc_type, targets in assocs.items():
            item["associations"][assoc_type] = {"products": targets[:50]}

        batch.append(item)

        if len(batch) >= BATCH_SIZE:
            r = api.patch_batch("products", batch)
            if r.status_code == 200:
                results = parse_jsonl(r)
                u = sum(1 for x in results if x.get("status_code") in (200, 201, 204))
                e = sum(1 for x in results if x.get("status_code") not in (200, 201, 204))
                stats["updated"] += u
                stats["errors"] += e
            else:
                stats["errors"] += len(batch)
            batch = []

    if batch:
        r = api.patch_batch("products", batch)
        if r.status_code == 200:
            results = parse_jsonl(r)
            u = sum(1 for x in results if x.get("status_code") in (200, 201, 204))
            e = sum(1 for x in results if x.get("status_code") not in (200, 201, 204))
            stats["updated"] += u
            stats["errors"] += e
        else:
            stats["errors"] += len(batch)

    log(f"  Associations: {stats['updated']} products updated, {stats['errors']} errors")
    log("Phase 5B complete.\n")


# ============================================================
# PHASE 6: SEO & LOCALE OPTIMIZATION
# ============================================================
def optimize_seo(api, limit=None):
    """Generate missing meta descriptions, optimize meta titles, add locale data"""
    log("=" * 60)
    log("PHASE 6: SEO & Locale Optimization")
    log("=" * 60)

    # Get products needing SEO optimization
    page = 1
    products_to_fix = []
    total_checked = 0

    while True:
        r = api.get("products", {"limit": 100, "page": page})
        if r.status_code != 200:
            break
        items = r.json().get("_embedded", {}).get("items", [])
        if not items:
            break

        for prod in items:
            total_checked += 1
            sku = prod.get("identifier", "")
            vals = prod.get("values", {})

            # Extract current values
            name_val = ""
            desc_val = ""
            meta_title_val = ""
            meta_desc_val = ""

            for v in vals.get("name", []):
                if v.get("locale") == "en_US":
                    name_val = v.get("data", "")
            for v in vals.get("description", []):
                if v.get("locale") == "en_US":
                    desc_val = v.get("data", "")
            for v in vals.get("meta_title", []):
                if v.get("locale") == "en_US":
                    meta_title_val = v.get("data", "")
            for v in vals.get("meta_description", []):
                if v.get("locale") == "en_US":
                    meta_desc_val = v.get("data", "")

            needs_fix = {}

            # Generate meta_description if missing
            if not meta_desc_val and name_val:
                # Clean HTML from description
                clean_desc = re.sub(r'<[^>]+>', '', desc_val or "").strip()[:200]
                if clean_desc:
                    meta_desc = f"{name_val.strip()} - {clean_desc}"[:300]
                else:
                    meta_desc = f"Buy {name_val.strip()} online at Techno Stationery. Quality office and school supplies."[:300]
                needs_fix["meta_description"] = meta_desc

            # Optimize meta_title if too long (>60 chars)
            if meta_title_val and len(meta_title_val) > 60:
                # Truncate intelligently
                short_title = meta_title_val[:57].rsplit(' ', 1)[0] + "..."
                needs_fix["meta_title_fix"] = short_title

            # Generate fr_FR locale content if missing
            fr_name = ""
            for v in vals.get("name", []):
                if v.get("locale") == "fr_FR":
                    fr_name = v.get("data", "")

            if not fr_name and name_val:
                needs_fix["fr_name"] = name_val  # Copy en_US to fr_FR as fallback

            if needs_fix:
                products_to_fix.append({"sku": sku, "fixes": needs_fix, "name": name_val})

        page += 1
        if limit and total_checked >= limit:
            break

    log(f"  Checked {total_checked} products, {len(products_to_fix)} need SEO fixes")

    # Apply fixes
    stats = {"meta_desc_generated": 0, "meta_title_fixed": 0, "locale_copied": 0, "errors": 0}
    batch = []

    for prod in products_to_fix:
        vals = {}

        if "meta_description" in prod["fixes"]:
            vals["meta_description"] = [{"locale": "en_US", "scope": None, "data": prod["fixes"]["meta_description"]}]
            stats["meta_desc_generated"] += 1

        if "meta_title_fix" in prod["fixes"]:
            vals["meta_title"] = [{"locale": "en_US", "scope": None, "data": prod["fixes"]["meta_title_fix"]}]
            stats["meta_title_fixed"] += 1

        if "fr_name" in prod["fixes"]:
            vals["name"] = [{"locale": "fr_FR", "scope": None, "data": prod["fixes"]["fr_name"]}]
            stats["locale_copied"] += 1

        if vals:
            batch.append({"identifier": prod["sku"], "values": vals})

        if len(batch) >= BATCH_SIZE:
            r = api.patch_batch("products", batch)
            if r.status_code == 200:
                results = parse_jsonl(r)
                errs = sum(1 for x in results if x.get("status_code") not in (200, 201, 204))
                stats["errors"] += errs
            else:
                stats["errors"] += len(batch)
            batch = []

    if batch:
        r = api.patch_batch("products", batch)
        if r.status_code == 200:
            results = parse_jsonl(r)
            errs = sum(1 for x in results if x.get("status_code") not in (200, 201, 204))
            stats["errors"] += errs
        else:
            stats["errors"] += len(batch)

    log(f"  SEO: {stats['meta_desc_generated']} meta descriptions generated")
    log(f"  SEO: {stats['meta_title_fixed']} meta titles optimized")
    log(f"  Locale: {stats['locale_copied']} fr_FR names copied")
    log(f"  Errors: {stats['errors']}")
    log("Phase 6 complete.\n")


# ============================================================
# PHASE 7: COMPREHENSIVE AUDIT
# ============================================================
def comprehensive_audit(api):
    """Full data quality audit with detailed findings and recommendations"""
    log("=" * 60)
    log("PHASE 7: Comprehensive Data Audit")
    log("=" * 60)

    report = []
    report.append("=" * 70)
    report.append("AKENEO PIM - COMPREHENSIVE DATA AUDIT REPORT")
    report.append(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    report.append("=" * 70)

    # 1. Families audit
    report.append("\n## 1. FAMILIES")
    r = api.get("families", {"limit": 100})
    families = r.json().get("_embedded", {}).get("items", []) if r.status_code == 200 else []
    report.append(f"   Total families: {len(families)}")
    for fam in families:
        attrs = fam.get("attributes", [])
        reqs = fam.get("attribute_requirements", {})
        labels = fam.get("labels", {})
        has_fr = bool(labels.get("fr_FR"))
        has_ar = bool(labels.get("ar_DZ"))
        report.append(f"   - {fam['code']}: {len(attrs)} attrs, fr_FR={'yes' if has_fr else 'NO'}, ar_DZ={'yes' if has_ar else 'NO'}")
        if reqs:
            for ch, ch_reqs in reqs.items():
                report.append(f"     Requirements ({ch}): {len(ch_reqs)} required attrs")

    # 2. Attributes audit
    report.append("\n## 2. ATTRIBUTES")
    r = api.get("attributes", {"limit": 100})
    attributes = r.json().get("_embedded", {}).get("items", []) if r.status_code == 200 else []
    report.append(f"   Total attributes: {len(attributes)}")

    attrs_without_fr = []
    attrs_without_ar = []
    attrs_by_group = defaultdict(list)
    for attr in attributes:
        labels = attr.get("labels", {})
        if not labels.get("fr_FR"):
            attrs_without_fr.append(attr["code"])
        if not labels.get("ar_DZ"):
            attrs_without_ar.append(attr["code"])
        attrs_by_group[attr.get("group", "other")].append(attr["code"])

    report.append(f"   Without fr_FR label: {len(attrs_without_fr)}")
    if attrs_without_fr:
        report.append(f"     {', '.join(attrs_without_fr[:10])}")
    report.append(f"   Without ar_DZ label: {len(attrs_without_ar)}")
    if attrs_without_ar:
        report.append(f"     {', '.join(attrs_without_ar[:10])}")
    report.append(f"   By group:")
    for grp, grp_attrs in sorted(attrs_by_group.items()):
        report.append(f"     {grp}: {len(grp_attrs)} attrs")

    # 3. Categories audit
    report.append("\n## 3. CATEGORIES")
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

    report.append(f"   Total categories: {len(all_categories)}")
    root_cats = [c for c in all_categories if c.get("parent") is None]
    report.append(f"   Root categories: {len(root_cats)}")

    cats_without_fr = [c["code"] for c in all_categories if not c.get("labels", {}).get("fr_FR")]
    report.append(f"   Without fr_FR label: {len(cats_without_fr)}")

    # Check for duplicate category names
    cat_names = defaultdict(list)
    for c in all_categories:
        name = c.get("labels", {}).get("en_US", "")
        if name:
            cat_names[name.lower()].append(c["code"])
    dupes = {n: codes for n, codes in cat_names.items() if len(codes) > 1}
    report.append(f"   Duplicate name groups: {len(dupes)}")

    # 4. Products audit
    report.append("\n## 4. PRODUCTS")
    page = 1
    total_products = 0
    seo_stats = {"meta_title": 0, "meta_description": 0, "meta_keyword": 0, "url_key": 0, "name": 0}
    family_counts = defaultdict(int)
    products_no_price = 0
    products_no_category = 0
    products_no_name = 0
    locale_stats = {"en_US_name": 0, "fr_FR_name": 0, "ar_DZ_name": 0}
    title_length_issues = 0

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

            # Check SEO fields
            for field in ["meta_title", "meta_description", "meta_keyword", "url_key"]:
                for v in vals.get(field, []):
                    if v.get("data"):
                        seo_stats[field] += 1
                        break

            # Check name across locales
            has_name = False
            for v in vals.get("name", []):
                if v.get("data"):
                    has_name = True
                    loc = v.get("locale", "")
                    if loc == "en_US":
                        locale_stats["en_US_name"] += 1
                        # Check title length
                        if len(v["data"]) > 60:
                            title_length_issues += 1
                    elif loc == "fr_FR":
                        locale_stats["fr_FR_name"] += 1
                    elif loc == "ar_DZ":
                        locale_stats["ar_DZ_name"] += 1

            if not has_name:
                products_no_name += 1

            # Check price
            has_price = False
            for v in vals.get("price", []):
                if v.get("data"):
                    has_price = True
                    break
            if not has_price:
                products_no_price += 1

            # Check categories
            if not prod.get("categories"):
                products_no_category += 1

        page += 1

    report.append(f"   Total products: {total_products}")
    report.append(f"   By family:")
    for fam, count in sorted(family_counts.items(), key=lambda x: -x[1]):
        report.append(f"     {fam}: {count}")

    report.append(f"\n   Data quality:")
    report.append(f"     Missing name: {products_no_name}")
    report.append(f"     Missing price: {products_no_price}")
    report.append(f"     Missing categories: {products_no_category}")
    report.append(f"     Name too long (>60 chars): {title_length_issues}")

    report.append(f"\n   SEO coverage:")
    for field, count in seo_stats.items():
        pct = (count / total_products * 100) if total_products > 0 else 0
        report.append(f"     {field}: {count}/{total_products} ({pct:.1f}%)")

    report.append(f"\n   Locale coverage (name field):")
    for loc, count in locale_stats.items():
        pct = (count / total_products * 100) if total_products > 0 else 0
        report.append(f"     {loc}: {count}/{total_products} ({pct:.1f}%)")

    # 5. Associations audit
    report.append("\n## 5. ASSOCIATIONS")
    r = api.get("association-types", {"limit": 100})
    if r.status_code == 200:
        assoc_types = r.json().get("_embedded", {}).get("items", [])
        report.append(f"   Association types: {len(assoc_types)}")
        for at in assoc_types:
            report.append(f"     {at['code']}: {at.get('labels', {}).get('en_US', 'no label')}")

    # 6. Product models audit
    report.append("\n## 6. PRODUCT MODELS")
    r = api.get("product-models", {"limit": 100})
    if r.status_code == 200:
        models = r.json().get("_embedded", {}).get("items", [])
        report.append(f"   Total product models: {len(models)}")
    else:
        report.append(f"   Product models endpoint: {r.status_code}")

    # 7. Family variants
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

    # 8. Recommendations
    report.append("\n## 8. RECOMMENDATIONS")
    report.append("   Priority 1 (Critical):")
    if products_no_price > 0:
        report.append(f"     - Fix {products_no_price} products missing price")
    if products_no_name > 0:
        report.append(f"     - Fix {products_no_name} products missing name")
    if seo_stats["meta_description"] < total_products:
        missing = total_products - seo_stats["meta_description"]
        report.append(f"     - Generate {missing} missing meta descriptions")

    report.append("   Priority 2 (Important):")
    if locale_stats["fr_FR_name"] < total_products:
        missing = total_products - locale_stats["fr_FR_name"]
        report.append(f"     - Add fr_FR names for {missing} products")
    if locale_stats["ar_DZ_name"] < total_products:
        missing = total_products - locale_stats["ar_DZ_name"]
        report.append(f"     - Add ar_DZ names for {missing} products")
    if title_length_issues > 0:
        report.append(f"     - Optimize {title_length_issues} product names exceeding 60 chars")
    if len(dupes) > 0:
        report.append(f"     - Resolve {len(dupes)} duplicate category name groups")

    report.append("   Priority 3 (Maintenance):")
    if attrs_without_fr:
        report.append(f"     - Add fr_FR labels to {len(attrs_without_fr)} attributes")
    if attrs_without_ar:
        report.append(f"     - Add ar_DZ labels to {len(attrs_without_ar)} attributes")
    if products_no_category > 0:
        report.append(f"     - Assign categories to {products_no_category} products")

    # Save report
    report_text = "\n".join(report)
    report_file = f"/home/pim/public_html/webapp/AUDIT_REPORT_{datetime.now().strftime('%Y%m%d_%H%M%S')}.txt"
    with open(report_file, "w") as f:
        f.write(report_text)

    print(report_text)
    log(f"  Audit report saved to {report_file}")
    log("Phase 7 complete.\n")
    return report_text


# ============================================================
# PHASE 8: APPLY ALL TUNINGS AND FIXES
# ============================================================
def apply_fixes(api):
    """Apply all identified tunings and fixes"""
    log("=" * 60)
    log("PHASE 8: Applying Tunings & Fixes")
    log("=" * 60)

    stats = {"fixed": 0, "errors": 0}

    # Fix 1: Generate meta descriptions for products missing them
    log("Fix 1: Generating missing meta descriptions...")
    page = 1
    batch = []
    meta_fixed = 0

    while True:
        r = api.get("products", {"limit": 100, "page": page})
        if r.status_code != 200:
            break
        items = r.json().get("_embedded", {}).get("items", [])
        if not items:
            break

        for prod in items:
            vals = prod.get("values", {})
            sku = prod.get("identifier", "")

            # Check if meta_description is missing
            has_meta_desc = False
            for v in vals.get("meta_description", []):
                if v.get("locale") == "en_US" and v.get("data", "").strip():
                    has_meta_desc = True
                    break

            if not has_meta_desc:
                # Get name and description to generate meta
                name = ""
                desc = ""
                for v in vals.get("name", []):
                    if v.get("locale") == "en_US":
                        name = v.get("data", "")
                for v in vals.get("description", []):
                    if v.get("locale") == "en_US":
                        desc = re.sub(r'<[^>]+>', '', v.get("data", "")).strip()

                if name:
                    if desc:
                        meta_desc = f"{name.strip()} - {desc[:200]}"[:300]
                    else:
                        meta_desc = f"Shop {name.strip()} at Techno Stationery. Quality school and office supplies delivered across Algeria."[:300]

                    batch.append({
                        "identifier": sku,
                        "values": {
                            "meta_description": [{"locale": "en_US", "scope": None, "data": meta_desc}]
                        }
                    })
                    meta_fixed += 1

            if len(batch) >= BATCH_SIZE:
                r2 = api.patch_batch("products", batch)
                if r2.status_code == 200:
                    results = parse_jsonl(r2)
                    errs = sum(1 for x in results if x.get("status_code") not in (200, 201, 204))
                    stats["errors"] += errs
                batch = []

        page += 1

    if batch:
        r2 = api.patch_batch("products", batch)
        if r2.status_code == 200:
            results = parse_jsonl(r2)
            errs = sum(1 for x in results if x.get("status_code") not in (200, 201, 204))
            stats["errors"] += errs

    stats["fixed"] += meta_fixed
    log(f"  Generated {meta_fixed} missing meta descriptions")

    # Fix 2: Copy en_US name to fr_FR for products missing French name
    log("Fix 2: Copying names to fr_FR locale...")
    page = 1
    batch = []
    fr_fixed = 0

    while True:
        r = api.get("products", {"limit": 100, "page": page})
        if r.status_code != 200:
            break
        items = r.json().get("_embedded", {}).get("items", [])
        if not items:
            break

        for prod in items:
            vals = prod.get("values", {})
            sku = prod.get("identifier", "")

            en_name = ""
            fr_name = ""
            for v in vals.get("name", []):
                if v.get("locale") == "en_US":
                    en_name = v.get("data", "")
                elif v.get("locale") == "fr_FR":
                    fr_name = v.get("data", "")

            if en_name and not fr_name:
                batch.append({
                    "identifier": sku,
                    "values": {
                        "name": [{"locale": "fr_FR", "scope": None, "data": en_name}]
                    }
                })
                fr_fixed += 1

            if len(batch) >= BATCH_SIZE:
                r2 = api.patch_batch("products", batch)
                if r2.status_code == 200:
                    results = parse_jsonl(r2)
                    errs = sum(1 for x in results if x.get("status_code") not in (200, 201, 204))
                    stats["errors"] += errs
                batch = []

        page += 1

    if batch:
        r2 = api.patch_batch("products", batch)
        if r2.status_code == 200:
            results = parse_jsonl(r2)
            errs = sum(1 for x in results if x.get("status_code") not in (200, 201, 204))
            stats["errors"] += errs

    stats["fixed"] += fr_fixed
    log(f"  Copied {fr_fixed} names to fr_FR")

    # Fix 3: Update attribute labels with ar_DZ locale
    log("Fix 3: Updating attribute labels for ar_DZ locale...")
    ar_fixed = 0
    for code, schema in ATTRIBUTE_SCHEMA.items():
        labels = schema.get("labels", {})
        if labels.get("ar_DZ"):
            r = api.patch(f"attributes/{code}", {"labels": labels})
            if r.status_code in (200, 204):
                ar_fixed += 1

    stats["fixed"] += ar_fixed
    log(f"  Updated {ar_fixed} attributes with ar_DZ labels")

    # Fix 4: Update category labels for fr_FR
    log("Fix 4: Updating category labels...")
    page = 1
    cat_fixed = 0
    batch = []

    while True:
        r = api.get("categories", {"limit": 100, "page": page})
        if r.status_code != 200:
            break
        items = r.json().get("_embedded", {}).get("items", [])
        if not items:
            break

        for cat in items:
            labels = cat.get("labels", {})
            en_label = labels.get("en_US", "")
            if en_label and not labels.get("fr_FR"):
                batch.append({
                    "code": cat["code"],
                    "labels": {"fr_FR": en_label}
                })
                cat_fixed += 1

            if len(batch) >= BATCH_SIZE:
                r2 = api.patch_batch("categories", batch)
                batch = []

        page += 1

    if batch:
        api.patch_batch("categories", batch)

    stats["fixed"] += cat_fixed
    log(f"  Fixed {cat_fixed} category labels")

    log(f"\n  Total fixes applied: {stats['fixed']}")
    log(f"  Total errors: {stats['errors']}")
    log("Phase 8 complete.\n")


# ============================================================
# MAIN
# ============================================================
def main():
    parser = argparse.ArgumentParser(description="Akeneo PIM Master Sync & Optimization")
    parser.add_argument("--fix-platform", action="store_true", help="Fix platform issues")
    parser.add_argument("--enhance-families", action="store_true", help="Enhance families & attributes")
    parser.add_argument("--fix-categories", action="store_true", help="Fix category structure")
    parser.add_argument("--product-models", action="store_true", help="Create product models")
    parser.add_argument("--sync-products", action="store_true", help="Full product sync")
    parser.add_argument("--sync-associations", action="store_true", help="Import associations")
    parser.add_argument("--optimize-seo", action="store_true", help="SEO & locale optimization")
    parser.add_argument("--audit", action="store_true", help="Full audit")
    parser.add_argument("--apply-fixes", action="store_true", help="Apply all tunings & fixes")
    parser.add_argument("--all", action="store_true", help="Run everything")
    parser.add_argument("--limit", type=int, default=None, help="Limit products to process")
    args = parser.parse_args()

    if not any(vars(args).values()):
        parser.print_help()
        sys.exit(1)

    api = AkeneoClient(AKENEO_API)
    api.auth()

    log("=" * 60)
    log("AKENEO PIM MASTER SYNC STARTED")
    log("=" * 60)

    try:
        if args.fix_platform or args.all:
            fix_platform(api)

        if args.enhance_families or args.all:
            enhance_families(api)

        if args.fix_categories or args.all:
            fix_categories(api)

        if args.product_models or args.all:
            create_product_models(api)

        if args.sync_products or args.all:
            sync_products(api, args.limit)

        if args.sync_associations or args.all:
            sync_associations(api)

        if args.optimize_seo or args.all:
            optimize_seo(api, args.limit)

        if args.apply_fixes or args.all:
            apply_fixes(api)

        if args.audit or args.all:
            comprehensive_audit(api)

    except Exception as e:
        log(f"FATAL ERROR: {e}", "ERROR")
        traceback.print_exc()
        sys.exit(1)

    log("=" * 60)
    log("ALL PHASES COMPLETE")
    log("=" * 60)


if __name__ == "__main__":
    main()
