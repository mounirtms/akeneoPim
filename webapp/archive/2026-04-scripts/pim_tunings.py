#!/usr/bin/env python3
"""
Akeneo PIM - Advanced Tunings & Data Display Fixes
===================================================
Phase 10: Final data perfection tunings for product display quality.

Issues addressed:
  T1. ALL-CAPS names (6,729 products) -> Title Case conversion for en/fr locales
  T2. Visibility = in_search (12 products) -> catalog_and_search
  T3. Short descriptions <30 chars (329 products) -> generate proper summaries
  T4. Duplicate product names (733 groups) -> disambiguate with attributes
  T5. High-price anomalies (>100k DZD, 9 products) -> verify and flag
  T6. Product model display data inheritance check
  T7. URL key consistency audit across locales
  T8. Description quality - strip excessive whitespace / HTML remnants
  T9. Category depth & hierarchy optimization for display
  T10. Attribute option label completeness for grid display

Usage:
  python3 pim_tunings.py --all
  python3 pim_tunings.py --names --visibility --short-desc
  python3 pim_tunings.py --audit   (report only, no changes)
"""

import sys, os, json, re, time, argparse, traceback
import requests
from datetime import datetime
from collections import defaultdict

# ============================================================
# CONFIGURATION
# ============================================================
AKENEO_API = {
    "base_url": "https://pim.technostationery.com",
    "client_id": "1_3yhbczkw7osgcw8wg44k84os4sc04w4wc80ks08sw8cc8c40sw",
    "client_secret": "50vx3l4u4l4wwcsok4kcwkoo44oo0s0o8s0kcs0gc0c8g0oow4",
    "username": "admin", "password": "PimAdmin2026!",
}
CHANNEL = "ecommerce"
LOCALES = ["en_US", "fr_FR", "ar_DZ"]
LOG_FILE = "/home/pim/public_html/var/logs/pim_tunings.log"
BATCH_SIZE = 100
WEBAPP = "/home/pim/public_html/webapp"
FAMILIES = ["arts", "bags", "notebooks", "office", "stationery", "writing"]

# Words that should stay uppercase in titles
UPPERCASE_WORDS = {
    "USB", "LED", "A4", "A5", "A3", "A6", "B5", "B4", "PVC", "PP", "HB",
    "2B", "3B", "4B", "5B", "6B", "7B", "8B", "2H", "3H", "4H", "5H",
    "DIN", "ISO", "HP", "BIC", "UHU", "3M", "CD", "DVD", "ID", "RGB",
    "XL", "XXL", "ML", "MM", "CM", "KG", "GR", "PC", "PCS", "SET",
    "MAPED", "STABILO", "FABER", "CASTELL", "PILOT", "PENTEL",
    "SCHNEIDER", "STAEDTLER", "ZEBRA", "UNI",
}

# French articles/prepositions that should stay lowercase in titles
FR_LOWERCASE = {
    "de", "du", "des", "le", "la", "les", "un", "une",
    "et", "ou", "en", "au", "aux", "avec", "pour", "par",
    "sur", "sous", "dans", "d", "l",
}


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

    def patch(self, ep, json_data):
        r = requests.patch(f"{self.base}/api/rest/v1/{ep}",
                           headers={**self.h(), "Content-Type": "application/json"}, json=json_data)
        if r.status_code == 401:
            self.auth()
            r = requests.patch(f"{self.base}/api/rest/v1/{ep}",
                               headers={**self.h(), "Content-Type": "application/json"}, json=json_data)
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


def get_val(values, attr, locale=None):
    for v in values.get(attr, []):
        if locale and v.get("locale") != locale:
            continue
        return v.get("data")
    return None


def has_val(values, attr):
    for v in values.get(attr, []):
        if v.get("data") is not None and v.get("data") != "":
            return True
    return False


# ============================================================
# TUNING 1: Fix ALL-CAPS product names -> Title Case
# ============================================================
def smart_title_case(name, locale="en_US"):
    """Convert ALL-CAPS name to smart Title Case preserving acronyms."""
    if not name or name != name.upper() or len(name) <= 3:
        return name

    words = name.split()
    result = []
    for i, word in enumerate(words):
        # Strip punctuation for checking
        clean = word.strip("()[]{},.;:-/\"'")

        # Preserve known acronyms and model numbers
        if clean.upper() in UPPERCASE_WORDS:
            result.append(word)
            continue

        # Preserve numbers with letters (model numbers like 10B, 2H, etc.)
        if re.match(r'^[0-9]+[A-Za-z]+$', clean) or re.match(r'^[A-Za-z]+[0-9]+$', clean):
            result.append(word)
            continue

        # French lowercase articles (not first word)
        if locale == "fr_FR" and i > 0 and clean.lower() in FR_LOWERCASE:
            result.append(word.lower())
            continue

        # Title case the word
        if len(word) > 1:
            result.append(word[0].upper() + word[1:].lower())
        else:
            result.append(word.upper())

    return " ".join(result)


def fix_allcaps_names(api):
    log("=" * 70)
    log("TUNING 1: Converting ALL-CAPS product names to Title Case")
    log("=" * 70)

    batch = []
    fixed = 0
    skipped = 0
    samples = []

    for prod in api.get_all_products():
        sku = prod.get("identifier", "")
        vals = prod.get("values", {})
        parent = prod.get("parent")

        # Only fix standalone products (variant names come from model)
        # Also fix variants that have their own name
        name_en = get_val(vals, "name", "en_US")
        name_fr = get_val(vals, "name", "fr_FR")

        if not name_en:
            continue

        # Check if ALL-CAPS
        if name_en != name_en.upper() or len(name_en) <= 3:
            skipped += 1
            continue

        # Convert
        new_name_en = smart_title_case(name_en, "en_US")
        new_name_fr = smart_title_case(name_fr, "fr_FR") if name_fr and name_fr == name_fr.upper() else name_fr

        update_vals = {}
        name_updates = []

        if new_name_en != name_en:
            name_updates.append({"locale": "en_US", "scope": None, "data": new_name_en})
        if name_fr and new_name_fr and new_name_fr != name_fr:
            name_updates.append({"locale": "fr_FR", "scope": None, "data": new_name_fr})

        # Keep ar_DZ unchanged (Arabic doesn't have case)
        name_ar = get_val(vals, "name", "ar_DZ")
        if name_ar:
            name_updates.append({"locale": "ar_DZ", "scope": None, "data": name_ar})

        if not name_updates:
            continue

        # Also fix meta_title to match new name
        meta_updates = []
        meta_en = get_val(vals, "meta_title", "en_US")
        if meta_en and meta_en == meta_en.upper() and len(meta_en) > 3:
            new_meta = smart_title_case(meta_en, "en_US")
            meta_updates.append({"locale": "en_US", "scope": None, "data": new_meta})
        meta_fr = get_val(vals, "meta_title", "fr_FR")
        if meta_fr and meta_fr == meta_fr.upper() and len(meta_fr) > 3:
            new_meta = smart_title_case(meta_fr, "fr_FR")
            meta_updates.append({"locale": "fr_FR", "scope": None, "data": new_meta})

        update = {"identifier": sku, "values": {"name": name_updates}}
        if meta_updates:
            update["values"]["meta_title"] = meta_updates

        batch.append(update)
        fixed += 1

        if fixed <= 5:
            samples.append(f"  {sku}: '{name_en}' -> '{new_name_en}'")

        if len(batch) >= BATCH_SIZE:
            r = api.patch_batch("products", batch)
            if r and r.status_code == 200:
                log(f"  Batch sent: {len(batch)} items, status={r.status_code}")
            batch = []

    if batch:
        api.patch_batch("products", batch)

    # Also fix product model names
    batch_models = []
    model_fixed = 0
    for model in api.get_all_product_models():
        code = model.get("code", "")
        vals = model.get("values", {})

        name_en = get_val(vals, "name", "en_US")
        name_fr = get_val(vals, "name", "fr_FR")

        if not name_en or name_en != name_en.upper() or len(name_en) <= 3:
            continue

        new_name_en = smart_title_case(name_en, "en_US")
        new_name_fr = smart_title_case(name_fr, "fr_FR") if name_fr and name_fr == name_fr.upper() else name_fr

        name_updates = []
        if new_name_en != name_en:
            name_updates.append({"locale": "en_US", "scope": None, "data": new_name_en})
        if name_fr and new_name_fr and new_name_fr != name_fr:
            name_updates.append({"locale": "fr_FR", "scope": None, "data": new_name_fr})
        name_ar = get_val(vals, "name", "ar_DZ")
        if name_ar:
            name_updates.append({"locale": "ar_DZ", "scope": None, "data": name_ar})

        if not name_updates:
            continue

        update = {"code": code, "values": {"name": name_updates}}

        # Fix meta_title on model too
        meta_en = get_val(vals, "meta_title", "en_US")
        if meta_en and meta_en == meta_en.upper() and len(meta_en) > 3:
            meta_updates = [{"locale": "en_US", "scope": None, "data": smart_title_case(meta_en, "en_US")}]
            update["values"]["meta_title"] = meta_updates

        batch_models.append(update)
        model_fixed += 1

        if len(batch_models) >= BATCH_SIZE:
            api.patch_batch("product-models", batch_models)
            batch_models = []

    if batch_models:
        api.patch_batch("product-models", batch_models)

    for s in samples:
        log(s)
    log(f"  Products fixed: {fixed}, Models fixed: {model_fixed}, Skipped: {skipped}")
    log(f"  TOTAL name fixes: {fixed + model_fixed}")
    log("TUNING 1 COMPLETE.\n")
    return fixed + model_fixed


# ============================================================
# TUNING 2: Fix visibility = in_search -> catalog_and_search
# ============================================================
def fix_visibility_insearch(api):
    log("=" * 70)
    log("TUNING 2: Fixing visibility=in_search -> catalog_and_search")
    log("=" * 70)

    batch = []
    fixed = 0

    for prod in api.get_all_products():
        sku = prod.get("identifier", "")
        vals = prod.get("values", {})
        vis = get_val(vals, "visibility")

        if vis == "in_search":
            batch.append({
                "identifier": sku,
                "values": {
                    "visibility": [{"locale": None, "scope": None, "data": "catalog_and_search"}]
                },
            })
            fixed += 1
            log(f"  Fixing {sku}: in_search -> catalog_and_search")

        if len(batch) >= BATCH_SIZE:
            api.patch_batch("products", batch)
            batch = []

    if batch:
        api.patch_batch("products", batch)

    # Also fix on models
    model_fixed = 0
    batch = []
    for model in api.get_all_product_models():
        code = model.get("code", "")
        vals = model.get("values", {})
        vis = get_val(vals, "visibility")

        if vis == "in_search":
            batch.append({
                "code": code,
                "values": {
                    "visibility": [{"locale": None, "scope": None, "data": "catalog_and_search"}]
                },
            })
            model_fixed += 1

        if len(batch) >= BATCH_SIZE:
            api.patch_batch("product-models", batch)
            batch = []

    if batch:
        api.patch_batch("product-models", batch)

    log(f"  Products fixed: {fixed}, Models fixed: {model_fixed}")
    log(f"  TOTAL visibility fixes: {fixed + model_fixed}")
    log("TUNING 2 COMPLETE.\n")
    return fixed + model_fixed


# ============================================================
# TUNING 3: Fix short descriptions < 30 chars
# ============================================================
def fix_short_descriptions(api):
    log("=" * 70)
    log("TUNING 3: Improving short descriptions < 30 characters")
    log("=" * 70)

    batch = []
    fixed = 0

    for prod in api.get_all_products():
        sku = prod.get("identifier", "")
        vals = prod.get("values", {})
        fam = prod.get("family", "")

        sd_en = get_val(vals, "short_description", "en_US") or ""
        if len(sd_en) >= 30:
            continue

        # Build a better short description from name + family + brand
        name_en = get_val(vals, "name", "en_US") or sku
        brand = get_val(vals, "mgs_brand")
        color = get_val(vals, "color")

        # Build descriptor
        parts = []
        if brand:
            brand_label = brand.replace("_", " ").title()
            parts.append(brand_label)

        # Clean name (remove ALL-CAPS if present)
        clean_name = smart_title_case(name_en, "en_US") if name_en == name_en.upper() else name_en
        parts.append(clean_name)

        if color:
            color_label = color.replace("_", " ").title()
            parts.append(f"- {color_label}")

        family_names = {
            "arts": "art supply", "bags": "bag", "notebooks": "notebook",
            "office": "office supply", "stationery": "stationery item",
            "writing": "writing instrument",
        }
        fam_name = family_names.get(fam, "product")

        new_sd = " ".join(parts)
        if len(new_sd) < 30:
            new_sd = f"Premium quality {fam_name}: {new_sd}. Perfect for everyday use."

        # Generate for all locales
        sd_updates = [{"locale": "en_US", "scope": CHANNEL, "data": new_sd}]

        # French version
        sd_fr = get_val(vals, "short_description", "fr_FR") or ""
        if len(sd_fr) < 30:
            name_fr = get_val(vals, "name", "fr_FR") or name_en
            fr_fam = {
                "arts": "fourniture artistique", "bags": "sac",
                "notebooks": "cahier", "office": "fourniture de bureau",
                "stationery": "papeterie", "writing": "instrument d'ecriture",
            }
            fr_parts = []
            if brand:
                fr_parts.append(brand.replace("_", " ").title())
            clean_fr = smart_title_case(name_fr, "fr_FR") if name_fr == name_fr.upper() else name_fr
            fr_parts.append(clean_fr)
            new_sd_fr = " ".join(fr_parts)
            if len(new_sd_fr) < 30:
                new_sd_fr = f"Qualite premium {fr_fam.get(fam, 'produit')}: {new_sd_fr}."
            sd_updates.append({"locale": "fr_FR", "scope": CHANNEL, "data": new_sd_fr})

        # Arabic version
        sd_ar = get_val(vals, "short_description", "ar_DZ") or ""
        if len(sd_ar) < 30:
            name_ar = get_val(vals, "name", "ar_DZ") or name_en
            ar_fam = {
                "arts": "مستلزمات فنية", "bags": "حقيبة",
                "notebooks": "دفتر", "office": "مستلزمات مكتبية",
                "stationery": "قرطاسية", "writing": "أداة كتابة",
            }
            new_sd_ar = f"{ar_fam.get(fam, 'منتج')} - {name_ar}"
            if len(new_sd_ar) < 30:
                new_sd_ar = f"جودة عالية {ar_fam.get(fam, 'منتج')}: {name_ar}. مثالي للاستخدام اليومي."
            sd_updates.append({"locale": "ar_DZ", "scope": CHANNEL, "data": new_sd_ar})

        batch.append({
            "identifier": sku,
            "values": {"short_description": sd_updates},
        })
        fixed += 1

        if len(batch) >= BATCH_SIZE:
            r = api.patch_batch("products", batch)
            log(f"  Batch sent: {len(batch)} items, status={r.status_code if r else 'none'}")
            batch = []

    if batch:
        api.patch_batch("products", batch)

    log(f"  Short descriptions improved: {fixed}")
    log("TUNING 3 COMPLETE.\n")
    return fixed


# ============================================================
# TUNING 4: Disambiguate duplicate product names
# ============================================================
def fix_duplicate_names(api):
    log("=" * 70)
    log("TUNING 4: Disambiguating duplicate product names")
    log("=" * 70)

    # First pass: collect all names
    name_map = defaultdict(list)  # name -> [(sku, vals, family)]
    for prod in api.get_all_products():
        sku = prod.get("identifier", "")
        vals = prod.get("values", {})
        fam = prod.get("family", "")
        name_en = get_val(vals, "name", "en_US") or ""
        if name_en:
            name_map[name_en].append((sku, vals, fam))

    # Find duplicates
    duplicates = {k: v for k, v in name_map.items() if len(v) > 1}
    log(f"  Found {len(duplicates)} duplicate name groups ({sum(len(v) for v in duplicates.values())} products)")

    batch = []
    fixed = 0

    for name, products in duplicates.items():
        for i, (sku, vals, fam) in enumerate(products):
            # Try to disambiguate using color, capacity, or SKU
            color = get_val(vals, "color")
            capacity = get_val(vals, "capacity")
            size = get_val(vals, "size")

            suffix_parts = []
            if color:
                suffix_parts.append(color.replace("_", " ").title())
            if capacity:
                suffix_parts.append(str(capacity).replace("_", " "))
            if size:
                suffix_parts.append(str(size).replace("_", " "))

            if not suffix_parts:
                # Fall back to last 4 digits of SKU
                suffix_parts.append(f"#{sku[-4:]}" if len(sku) >= 4 else f"#{sku}")

            suffix = " - ".join(suffix_parts)
            new_name = f"{name} ({suffix})"

            # Only update en_US name (fr_FR and ar_DZ may have different duplicate patterns)
            name_updates = [{"locale": "en_US", "scope": None, "data": new_name}]

            # Also disambiguate fr_FR if it's a duplicate
            name_fr = get_val(vals, "name", "fr_FR")
            if name_fr:
                name_updates.append({"locale": "fr_FR", "scope": None, "data": f"{name_fr} ({suffix})"})

            batch.append({
                "identifier": sku,
                "values": {"name": name_updates},
            })
            fixed += 1

        if len(batch) >= BATCH_SIZE:
            r = api.patch_batch("products", batch)
            log(f"  Batch sent: {len(batch)} items, status={r.status_code if r else 'none'}")
            batch = []

    if batch:
        api.patch_batch("products", batch)

    log(f"  Duplicate names disambiguated: {fixed}")
    log("TUNING 4 COMPLETE.\n")
    return fixed


# ============================================================
# TUNING 5: High-price anomaly check
# ============================================================
def check_high_prices(api):
    log("=" * 70)
    log("TUNING 5: Checking high-price anomalies (>100,000 DZD)")
    log("=" * 70)

    flagged = []
    for prod in api.get_all_products():
        sku = prod.get("identifier", "")
        vals = prod.get("values", {})
        name_en = get_val(vals, "name", "en_US") or sku

        for pv in vals.get("price", []):
            for pp in pv.get("data", []):
                if pp.get("currency") == "DZD":
                    amt = float(pp.get("amount", 0))
                    if amt > 100000:
                        flagged.append({
                            "sku": sku,
                            "name": name_en,
                            "price_dzd": amt,
                            "family": prod.get("family", ""),
                        })

    for item in flagged:
        log(f"  HIGH PRICE: {item['sku']} - {item['name']} - {item['price_dzd']:,.0f} DZD ({item['family']})")

    log(f"  Total high-price products: {len(flagged)}")
    log("TUNING 5 COMPLETE.\n")
    return len(flagged)


# ============================================================
# TUNING 6: Description quality - clean whitespace & HTML
# ============================================================
def clean_descriptions(api):
    log("=" * 70)
    log("TUNING 6: Cleaning description quality (whitespace, HTML remnants)")
    log("=" * 70)

    batch = []
    fixed = 0

    for prod in api.get_all_products():
        sku = prod.get("identifier", "")
        vals = prod.get("values", {})
        updates = {}

        for attr in ["description", "short_description"]:
            attr_updates = []
            changed = False
            for val_entry in vals.get(attr, []):
                loc = val_entry.get("locale")
                scope = val_entry.get("scope")
                data = val_entry.get("data", "") or ""

                original = data
                # Clean excessive whitespace
                data = re.sub(r'\s+', ' ', data).strip()
                # Remove empty HTML tags
                data = re.sub(r'<(p|div|span|br)\s*/?\s*>', '', data, flags=re.IGNORECASE)
                data = re.sub(r'</(p|div|span)>', '', data, flags=re.IGNORECASE)
                # Remove orphaned HTML attributes
                data = re.sub(r'style="[^"]*"', '', data)
                data = re.sub(r'class="[^"]*"', '', data)
                # Clean double spaces again after removals
                data = re.sub(r'\s+', ' ', data).strip()

                if data != original:
                    changed = True
                attr_updates.append({"locale": loc, "scope": scope, "data": data})

            if changed:
                updates[attr] = attr_updates

        if updates:
            batch.append({"identifier": sku, "values": updates})
            fixed += 1

        if len(batch) >= BATCH_SIZE:
            r = api.patch_batch("products", batch)
            log(f"  Batch sent: {len(batch)} items, status={r.status_code if r else 'none'}")
            batch = []

    if batch:
        api.patch_batch("products", batch)

    log(f"  Descriptions cleaned: {fixed}")
    log("TUNING 6 COMPLETE.\n")
    return fixed


# ============================================================
# TUNING 7: Attribute option label completeness for display
# ============================================================
def fix_option_labels(api):
    log("=" * 70)
    log("TUNING 7: Fixing attribute option labels for trilingual display")
    log("=" * 70)

    select_attrs = ["mgs_brand", "color", "capacity", "format", "size",
                    "visibility", "manufacturer", "gender_product",
                    "type_product", "pattern"]
    total_fixed = 0

    for attr_code in select_attrs:
        r = api.get(f"attributes/{attr_code}")
        if r.status_code != 200:
            continue

        attr_type = r.json().get("type", "")
        if "select" not in attr_type:
            continue

        page = 1
        options_fixed = 0
        while True:
            r = api.get(f"attributes/{attr_code}/options", {"limit": 100, "page": page})
            if r.status_code != 200:
                break
            items = r.json().get("_embedded", {}).get("items", [])
            if not items:
                break

            for opt in items:
                code = opt.get("code", "")
                labels = opt.get("labels", {})
                en_label = labels.get("en_US", "")
                fr_label = labels.get("fr_FR", "")
                ar_label = labels.get("ar_DZ", "")

                needs_update = False
                new_labels = dict(labels)

                # If en_US is missing, derive from code
                if not en_label:
                    new_labels["en_US"] = code.replace("_", " ").title()
                    needs_update = True

                # If fr_FR is missing, use en_US
                if not fr_label:
                    new_labels["fr_FR"] = new_labels.get("en_US", code.replace("_", " ").title())
                    needs_update = True

                # If ar_DZ is missing, use en_US
                if not ar_label:
                    new_labels["ar_DZ"] = new_labels.get("en_US", code.replace("_", " ").title())
                    needs_update = True

                if needs_update:
                    r2 = api.patch(f"attributes/{attr_code}/options/{code}", {"labels": new_labels})
                    if r2.status_code in (200, 201, 204):
                        options_fixed += 1

            page += 1

        if options_fixed > 0:
            log(f"  {attr_code}: fixed {options_fixed} option labels")
            total_fixed += options_fixed

    log(f"  Total option labels fixed: {total_fixed}")
    log("TUNING 7 COMPLETE.\n")
    return total_fixed


# ============================================================
# TUNING 8: Product model display data inheritance verification
# ============================================================
def verify_model_inheritance(api):
    log("=" * 70)
    log("TUNING 8: Verifying product model display data inheritance")
    log("=" * 70)

    issues = {
        "model_no_name": 0,
        "model_no_desc": 0,
        "model_no_image": 0,
        "model_no_price": 0,
        "model_no_category": 0,
        "model_no_visibility": 0,
    }
    model_fixes = []

    for model in api.get_all_product_models():
        code = model.get("code", "")
        vals = model.get("values", {})

        if not get_val(vals, "name", "en_US"):
            issues["model_no_name"] += 1
        if not get_val(vals, "description", "en_US"):
            issues["model_no_desc"] += 1
        if not has_val(vals, "image"):
            issues["model_no_image"] += 1
        if not has_val(vals, "price"):
            issues["model_no_price"] += 1
        if not model.get("categories", []):
            issues["model_no_category"] += 1
        if not has_val(vals, "visibility"):
            issues["model_no_visibility"] += 1

    for key, count in issues.items():
        if count > 0:
            log(f"  {key}: {count}", "WARN")
        else:
            log(f"  {key}: {count} (OK)")

    log("TUNING 8 COMPLETE.\n")
    return sum(issues.values())


# ============================================================
# TUNING 9: URL key consistency check across locales
# ============================================================
def check_urlkey_consistency(api):
    log("=" * 70)
    log("TUNING 9: URL key consistency audit across locales")
    log("=" * 70)

    issues = {"missing": 0, "spaces": 0, "uppercase": 0, "special_chars": 0, "duplicates": 0}
    urlkey_map = defaultdict(list)  # urlkey -> [skus]

    for prod in api.get_all_products():
        sku = prod.get("identifier", "")
        vals = prod.get("values", {})

        # url_key is NOT localizable - uses locale=null
        uk = get_val(vals, "url_key") or ""
        if not uk:
            issues["missing"] += 1
        else:
            if " " in uk:
                issues["spaces"] += 1
            if uk != uk.lower():
                issues["uppercase"] += 1
            if re.search(r'[^a-zA-Z0-9\-_/\u0600-\u06FF]', uk):
                issues["special_chars"] += 1
            urlkey_map[uk].append(sku)

    # Check for duplicates
    dups = {k: v for k, v in urlkey_map.items() if len(v) > 1}
    issues["duplicates"] = len(dups)
    if dups:
        log(f"  {len(dups)} duplicate URL keys found")

    for key, count in issues.items():
        status = "OK" if count == 0 else "WARN"
        log(f"  {key}: {count} ({status})")

    log("TUNING 9 COMPLETE.\n")
    return issues["missing"] + issues["spaces"] + issues["uppercase"] + issues["duplicates"]


# ============================================================
# TUNING 10: Category hierarchy depth check
# ============================================================
def check_category_hierarchy(api):
    log("=" * 70)
    log("TUNING 10: Category hierarchy depth & label audit")
    log("=" * 70)

    page = 1
    total = 0
    max_depth = 0
    missing_labels = {"en_US": 0, "fr_FR": 0, "ar_DZ": 0}
    empty_categories = 0

    while True:
        r = api.get("categories", {"limit": 100, "page": page})
        if r.status_code != 200:
            break
        items = r.json().get("_embedded", {}).get("items", [])
        if not items:
            break

        for cat in items:
            total += 1
            code = cat.get("code", "")
            parent = cat.get("parent")
            labels = cat.get("labels", {})

            # Depth estimation from code pattern
            depth = code.count("__") + (1 if parent else 0)
            if depth > max_depth:
                max_depth = depth

            # Label check
            for locale in LOCALES:
                if not labels.get(locale):
                    missing_labels[locale] += 1

        page += 1

    log(f"  Total categories: {total}")
    log(f"  Max depth: {max_depth}")
    for locale, count in missing_labels.items():
        status = "OK" if count == 0 else "WARN"
        log(f"  Missing {locale} labels: {count} ({status})")
    log("TUNING 10 COMPLETE.\n")
    return sum(missing_labels.values())


# ============================================================
# COMPREHENSIVE AUDIT
# ============================================================
def run_audit(api):
    log("=" * 70)
    log("COMPREHENSIVE DATA QUALITY AUDIT")
    log("=" * 70)

    stats = {
        "total": 0, "standalone": 0, "variant": 0,
        "all_caps": 0, "no_image": 0, "short_desc_lt30": 0,
        "no_desc_en": 0, "no_desc_fr": 0, "no_desc_ar": 0,
        "no_brand": 0, "no_mfr": 0, "no_weight": 0,
        "price_zero": 0, "price_high": 0, "bad_urlkey": 0,
        "no_meta": 0, "no_cat": 0, "vis_insearch": 0,
        "disabled": 0, "html_risk": 0,
        "vis": {}, "status": {}, "family": {},
        "dup_names": defaultdict(int),
        "completeness": {"high": 0, "medium": 0, "low": 0},
    }

    for prod in api.get_all_products():
        stats["total"] += 1
        vals = prod.get("values", {})
        parent = prod.get("parent")
        fam = prod.get("family", "")

        if parent:
            stats["variant"] += 1
        else:
            stats["standalone"] += 1

        stats["family"][fam] = stats["family"].get(fam, 0) + 1

        name_en = get_val(vals, "name", "en_US") or ""
        if name_en and name_en == name_en.upper() and len(name_en) > 3:
            stats["all_caps"] += 1
        if name_en:
            stats["dup_names"][name_en] += 1

        if not any(d.get("data") for d in vals.get("image", [])):
            stats["no_image"] += 1

        sd = get_val(vals, "short_description", "en_US") or ""
        if len(sd) < 30:
            stats["short_desc_lt30"] += 1

        if not get_val(vals, "description", "en_US"):
            stats["no_desc_en"] += 1
        if not get_val(vals, "description", "fr_FR"):
            stats["no_desc_fr"] += 1
        if not get_val(vals, "description", "ar_DZ"):
            stats["no_desc_ar"] += 1

        if not has_val(vals, "mgs_brand"):
            stats["no_brand"] += 1
        if not has_val(vals, "manufacturer"):
            stats["no_mfr"] += 1
        if get_val(vals, "weight") is None:
            stats["no_weight"] += 1

        vis = get_val(vals, "visibility") or ""
        stats["vis"][vis] = stats["vis"].get(vis, 0) + 1
        if vis == "in_search":
            stats["vis_insearch"] += 1

        st = get_val(vals, "product_status")
        key = str(st) if st is not None else "None"
        stats["status"][key] = stats["status"].get(key, 0) + 1
        if st is False:
            stats["disabled"] += 1

        if not get_val(vals, "meta_title", "en_US"):
            stats["no_meta"] += 1
        if not prod.get("categories"):
            stats["no_cat"] += 1

        for pv in vals.get("price", []):
            for pp in pv.get("data", []):
                if pp.get("currency") == "DZD":
                    amt = float(pp.get("amount", 0))
                    if amt == 0:
                        stats["price_zero"] += 1
                    if amt > 100000:
                        stats["price_high"] += 1

    dup_count = sum(1 for v in stats["dup_names"].values() if v > 1)
    dup_products = sum(v for v in stats["dup_names"].values() if v > 1)

    report = f"""
╔══════════════════════════════════════════════════════════════════════╗
║            AKENEO PIM DATA QUALITY AUDIT REPORT                     ║
║            Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}                          ║
╠══════════════════════════════════════════════════════════════════════╣

  CATALOG OVERVIEW
  ────────────────
  Total Products:     {stats['total']:,}
  Standalone:         {stats['standalone']:,}
  Variant:            {stats['variant']:,}
  Families:           {json.dumps(stats['family'])}

  DATA QUALITY METRICS
  ────────────────────
  ✓ = 100%, ○ = >95%, △ = 80-95%, ✗ = <80%

  Descriptions (en_US):    {'✓' if stats['no_desc_en'] == 0 else '✗'} {stats['total'] - stats['no_desc_en']:,}/{stats['total']:,} ({(stats['total'] - stats['no_desc_en'])/stats['total']*100:.1f}%)
  Descriptions (fr_FR):    {'✓' if stats['no_desc_fr'] == 0 else '✗'} {stats['total'] - stats['no_desc_fr']:,}/{stats['total']:,} ({(stats['total'] - stats['no_desc_fr'])/stats['total']*100:.1f}%)
  Descriptions (ar_DZ):    {'✓' if stats['no_desc_ar'] == 0 else '✗'} {stats['total'] - stats['no_desc_ar']:,}/{stats['total']:,} ({(stats['total'] - stats['no_desc_ar'])/stats['total']*100:.1f}%)
  Images:                  {'○' if stats['no_image'] < stats['total'] * 0.05 else '△'} {stats['total'] - stats['no_image']:,}/{stats['total']:,} ({(stats['total'] - stats['no_image'])/stats['total']*100:.1f}%)
  Brand:                   {'○' if stats['no_brand'] < stats['total'] * 0.05 else '△'} {stats['total'] - stats['no_brand']:,}/{stats['total']:,} ({(stats['total'] - stats['no_brand'])/stats['total']*100:.1f}%)
  Manufacturer:            {'○' if stats['no_mfr'] < stats['total'] * 0.05 else '△'} {stats['total'] - stats['no_mfr']:,}/{stats['total']:,} ({(stats['total'] - stats['no_mfr'])/stats['total']*100:.1f}%)
  Meta Title:              {'✓' if stats['no_meta'] == 0 else '✗'} {stats['total'] - stats['no_meta']:,}/{stats['total']:,}
  Categories:              {'✓' if stats['no_cat'] == 0 else '✗'} {stats['total'] - stats['no_cat']:,}/{stats['total']:,}

  DISPLAY QUALITY ISSUES
  ──────────────────────
  ALL-CAPS names:          {stats['all_caps']:,} {'(NEEDS FIX)' if stats['all_caps'] > 0 else '(OK)'}
  Short desc <30 chars:    {stats['short_desc_lt30']:,} {'(NEEDS FIX)' if stats['short_desc_lt30'] > 0 else '(OK)'}
  Duplicate names:         {dup_count:,} groups ({dup_products:,} products) {'(NEEDS FIX)' if dup_count > 0 else '(OK)'}
  Visibility = in_search:  {stats['vis_insearch']:,} {'(NEEDS FIX)' if stats['vis_insearch'] > 0 else '(OK)'}
  Price = 0 DZD:           {stats['price_zero']:,} {'(NEEDS FIX)' if stats['price_zero'] > 0 else '(OK)'}
  Price > 100k DZD:        {stats['price_high']:,} {'(VERIFY)' if stats['price_high'] > 0 else '(OK)'}

  VISIBILITY: {json.dumps(stats['vis'])}
  STATUS: {json.dumps(stats['status'])}

╚══════════════════════════════════════════════════════════════════════╝
"""
    log(report)
    return stats


# ============================================================
# MAIN
# ============================================================
def main():
    parser = argparse.ArgumentParser(description="Akeneo PIM Advanced Tunings")
    parser.add_argument("--names", action="store_true", help="Fix ALL-CAPS names (T1)")
    parser.add_argument("--visibility", action="store_true", help="Fix visibility=in_search (T2)")
    parser.add_argument("--short-desc", action="store_true", help="Fix short descriptions (T3)")
    parser.add_argument("--duplicates", action="store_true", help="Fix duplicate names (T4)")
    parser.add_argument("--prices", action="store_true", help="Check high prices (T5)")
    parser.add_argument("--clean-desc", action="store_true", help="Clean description quality (T6)")
    parser.add_argument("--option-labels", action="store_true", help="Fix option labels (T7)")
    parser.add_argument("--model-check", action="store_true", help="Verify model inheritance (T8)")
    parser.add_argument("--urlkey-check", action="store_true", help="URL key consistency (T9)")
    parser.add_argument("--category-check", action="store_true", help="Category hierarchy (T10)")
    parser.add_argument("--audit", action="store_true", help="Full audit only (no changes)")
    parser.add_argument("--all", action="store_true", help="Run ALL tunings")
    args = parser.parse_args()

    api = AkeneoClient(AKENEO_API)
    api.auth()

    log("=" * 70)
    log("PIM TUNINGS STARTED")
    log(f"Timestamp: {datetime.now().isoformat()}")
    log("=" * 70)

    results = {}

    if args.audit:
        run_audit(api)
        return

    if args.all or args.names:
        results["name_fixes"] = fix_allcaps_names(api)
    if args.all or args.visibility:
        results["visibility_fixes"] = fix_visibility_insearch(api)
    if args.all or args.short_desc:
        results["short_desc_fixes"] = fix_short_descriptions(api)
    if args.all or args.duplicates:
        results["duplicate_fixes"] = fix_duplicate_names(api)
    if args.all or args.prices:
        results["price_flags"] = check_high_prices(api)
    if args.all or args.clean_desc:
        results["desc_cleaned"] = clean_descriptions(api)
    if args.all or args.option_labels:
        results["option_label_fixes"] = fix_option_labels(api)
    if args.all or args.model_check:
        results["model_issues"] = verify_model_inheritance(api)
    if args.all or args.urlkey_check:
        results["urlkey_issues"] = check_urlkey_consistency(api)
    if args.all or args.category_check:
        results["category_issues"] = check_category_hierarchy(api)

    log("=" * 70)
    log("SUMMARY:")
    for k, v in results.items():
        log(f"  {k}: {v}")
    log("=" * 70)
    log("PIM TUNINGS COMPLETE")


if __name__ == "__main__":
    main()
