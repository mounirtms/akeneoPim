#!/usr/bin/env python3
"""
Akeneo PIM Phase 3+ Fixes Script
=================================
Handles all remaining issues from the post-audit phase:

  Fix 1: Shorten remaining 327 product names >60 chars (special char handling)
  Fix 2: Resolve remaining duplicate category name groups
  Fix 3: Assign default prices to priceless products (category/family avg)
  Fix 4: Assign categories to uncategorized products (name-based matching)
  Fix 5: SEO deep optimization (url_key dedup, meta quality scoring)
  Fix 6: Data quality - attribute completeness enforcement
  Fix 7: Attribute cleanup - consolidate high-cardinality options
  Fix 8: Final comprehensive audit with full search_after pagination

Usage:
  python3 phase3_fixes.py --fix-names           # Fix remaining long names
  python3 phase3_fixes.py --dedup-categories     # Re-run dedup with improved logic
  python3 phase3_fixes.py --fix-prices           # Assign default prices
  python3 phase3_fixes.py --fix-categories       # Auto-assign categories
  python3 phase3_fixes.py --seo-optimize         # SEO deep optimization
  python3 phase3_fixes.py --data-quality         # Enforce data quality rules
  python3 phase3_fixes.py --cleanup-options      # Consolidate attribute options
  python3 phase3_fixes.py --audit                # Full comprehensive audit
  python3 phase3_fixes.py --all                  # Run everything
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
LOG_FILE = "/home/pim/public_html/var/logs/phase3_fixes.log"
BATCH_SIZE = 100

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
    return re.sub(r'[-\s]+', '-', text).strip('-')

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

    def patch(self, ep, data):
        r = requests.patch(f"{self.base}/api/rest/v1/{ep}",
                           headers={**self.h(), "Content-Type": "application/json"}, json=data)
        if r.status_code == 401:
            self.auth()
            r = requests.patch(f"{self.base}/api/rest/v1/{ep}",
                               headers={**self.h(), "Content-Type": "application/json"}, json=data)
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
        """Iterator over ALL products using search_after pagination"""
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

    def get_all_categories(self):
        """Get ALL categories"""
        page = 1
        all_cats = []
        while True:
            r = self.get("categories", {"limit": 100, "page": page})
            if r.status_code != 200:
                break
            items = r.json().get("_embedded", {}).get("items", [])
            if not items:
                break
            all_cats.extend(items)
            page += 1
        return all_cats


def get_magento_db():
    return mysql.connector.connect(**MAGENTO_DB)


# ============================================================
# FIX 1: SHORTEN REMAINING LONG PRODUCT NAMES (special chars)
# ============================================================
def fix_long_names(api):
    """Enhanced name shortening that handles special characters like quotes, accents"""
    log("=" * 60)
    log("FIX 1: Shortening Remaining Long Product Names")
    log("=" * 60)

    batch = []
    fixed = 0
    total_long = 0

    for prod in api.get_all_products():
        sku = prod.get("identifier", "")
        vals = prod.get("values", {})

        for v in vals.get("name", []):
            if v.get("locale") == "en_US" and v.get("data"):
                name = v["data"]
                if len(name) <= 60:
                    continue
                total_long += 1

                # Enhanced shortening strategy for French product names with special chars
                shortened = name

                # Step 1: Remove reference codes at end (REF:xxxx, Ref.xxxx)
                shortened = re.sub(r'\s*(REF[.:]\s*\S+\.?\w*)\s*$', '', shortened, flags=re.IGNORECASE)

                # Step 2: Remove ".old" suffixes
                shortened = re.sub(r'\.old\s*$', '', shortened, flags=re.IGNORECASE)

                # Step 3: Remove brand in quotes at end (e.g., "MAPED", "BIC")
                shortened = re.sub(r'\s*"[^"]*"\s*$', '', shortened)

                # Step 4: Remove parenthetical content at end
                shortened = re.sub(r'\s*\([^)]*\)\s*$', '', shortened)

                # Step 5: Remove trailing quantity info
                shortened = re.sub(r'\s*-?\s*\d+\s*(pcs?|pieces?|units?|boite|x)\s*$', '',
                                   shortened, flags=re.IGNORECASE)
                shortened = re.sub(r'\s+DE\s+\d+\s+PCS?\s*$', '', shortened, flags=re.IGNORECASE)

                # Step 6: Remove double spaces and trailing punctuation
                shortened = re.sub(r'\s{2,}', ' ', shortened).strip()
                shortened = shortened.rstrip(' -,;:.')

                # Step 7: If still too long, truncate at word boundary
                if len(shortened) > 60:
                    # Try removing intermediate descriptors
                    parts = shortened.split()
                    if len(parts) > 4:
                        # Keep first 4 meaningful words + last word (often size/ref)
                        shortened = ' '.join(parts[:5])

                if len(shortened) > 60:
                    # Hard truncate at word boundary
                    shortened = shortened[:57]
                    last_space = shortened.rfind(' ')
                    if last_space > 20:
                        shortened = shortened[:last_space]
                    shortened = shortened.rstrip(' -,;:.') + "..."

                if shortened != name and len(shortened) >= 10:
                    update = {"name": []}
                    # Update all locale names if they match the original
                    for nv in vals.get("name", []):
                        if nv.get("data") == name:
                            update["name"].append({
                                "locale": nv.get("locale"),
                                "scope": None,
                                "data": shortened[:255]
                            })

                    if update["name"]:
                        batch.append({"identifier": sku, "values": update})
                        fixed += 1

        if len(batch) >= BATCH_SIZE:
            r = api.patch_batch("products", batch)
            if r.status_code == 200:
                errs = [x for x in parse_jsonl(r) if x.get("status_code") not in (200, 201, 204)]
                if errs:
                    log(f"  Batch errors: {len(errs)} - sample: {json.dumps(errs[0])[:200]}", "WARN")
            batch = []

    if batch:
        api.patch_batch("products", batch)

    log(f"  Found {total_long} products with names > 60 chars")
    log(f"  Shortened {fixed} product names")
    log("Fix 1 complete.\n")
    return fixed


# ============================================================
# FIX 2: RESOLVE REMAINING DUPLICATE CATEGORY NAME GROUPS
# ============================================================
def dedup_categories(api):
    """Improved deduplication: use parent path + code to create unique labels"""
    log("=" * 60)
    log("FIX 2: Resolving Duplicate Category Name Groups")
    log("=" * 60)

    all_categories = api.get_all_categories()
    log(f"  Total categories: {len(all_categories)}")

    # Build parent lookup
    code_to_cat = {c["code"]: c for c in all_categories}

    def get_parent_label(cat):
        """Get parent's en_US label"""
        parent_code = cat.get("parent", "")
        if parent_code and parent_code in code_to_cat:
            parent = code_to_cat[parent_code]
            return parent.get("labels", {}).get("en_US", parent_code)
        return ""

    def get_full_path(cat, depth=3):
        """Build breadcrumb path up to depth levels"""
        parts = []
        current = cat
        for _ in range(depth):
            parent_code = current.get("parent", "")
            if not parent_code or parent_code not in code_to_cat:
                break
            parent = code_to_cat[parent_code]
            plabel = parent.get("labels", {}).get("en_US", parent_code)
            if plabel and plabel.lower() not in {"master", "root", "default category"}:
                parts.insert(0, plabel)
            current = parent
        return " > ".join(parts) if parts else ""

    # Group by lowercased en_US name
    name_groups = defaultdict(list)
    for cat in all_categories:
        name = cat.get("labels", {}).get("en_US", "").strip()
        if name:
            name_groups[name.lower()].append(cat)

    dupes = {n: cats for n, cats in name_groups.items() if len(cats) > 1}
    log(f"  Duplicate name groups: {len(dupes)}")

    if not dupes:
        log("  No duplicates to fix")
        return 0

    fixed = 0
    batch = []

    for name, cats in dupes.items():
        # For each duplicate, disambiguate using parent path
        seen_labels = set()

        for cat in cats:
            current_label = cat.get("labels", {}).get("en_US", "").strip()
            parent_label = get_parent_label(cat)

            # Check if current label already disambiguated (has parenthetical)
            if "(" in current_label and ")" in current_label:
                # Already disambiguated, skip
                if current_label.lower() not in seen_labels:
                    seen_labels.add(current_label.lower())
                    continue

            # Create disambiguated label
            if parent_label and parent_label.lower() != name:
                new_label = f"{current_label} ({parent_label})"
            else:
                # Use full path if parent has same name
                path = get_full_path(cat)
                if path:
                    new_label = f"{current_label} ({path})"
                else:
                    # Fallback: append category code
                    new_label = f"{current_label} [{cat['code'][-8:]}]"

            # Ensure uniqueness
            if new_label.lower() in seen_labels:
                new_label = f"{current_label} [{cat['code'][-12:]}]"

            seen_labels.add(new_label.lower())

            if new_label != current_label:
                update = {"code": cat["code"], "labels": {}}
                for loc in LOCALES:
                    old_label = cat.get("labels", {}).get(loc, current_label)
                    # Apply same disambiguation to all locales
                    suffix = new_label[len(current_label):]  # e.g., " (PARENT)"
                    update["labels"][loc] = (old_label + suffix)[:255]

                batch.append(update)
                fixed += 1

        if len(batch) >= BATCH_SIZE:
            r = api.patch_batch("categories", batch)
            if r.status_code == 200:
                errs = [x for x in parse_jsonl(r) if x.get("status_code") not in (200, 201, 204)]
                if errs:
                    log(f"  Batch errors: {len(errs)}", "WARN")
            batch = []

    if batch:
        api.patch_batch("categories", batch)

    log(f"  Disambiguated {fixed} category labels")
    log("Fix 2 complete.\n")
    return fixed


# ============================================================
# FIX 3: ASSIGN DEFAULT PRICES TO PRICELESS PRODUCTS
# ============================================================
def fix_prices(api):
    """For products without any price source, assign the average category price"""
    log("=" * 60)
    log("FIX 3: Assigning Default Prices to Priceless Products")
    log("=" * 60)

    # First, collect price data by category to compute averages
    cat_prices = defaultdict(list)
    no_price_products = []

    for prod in api.get_all_products():
        sku = prod.get("identifier", "")
        vals = prod.get("values", {})
        categories = prod.get("categories", [])

        has_price = False
        price_val = 0
        for v in vals.get("price", []):
            if v.get("data"):
                for pd in v["data"]:
                    if pd.get("amount") and float(pd["amount"]) > 0:
                        has_price = True
                        price_val = float(pd["amount"])

        if has_price and price_val > 0:
            for cat in categories:
                cat_prices[cat].append(price_val)
        elif not has_price:
            no_price_products.append({"sku": sku, "categories": categories, "parent": prod.get("parent")})

    log(f"  Products without price: {len(no_price_products)}")
    log(f"  Categories with price data: {len(cat_prices)}")

    # Compute category averages
    cat_avg = {}
    for cat, prices in cat_prices.items():
        cat_avg[cat] = round(sum(prices) / len(prices), 2)

    # Global average as fallback
    all_prices = [p for prices in cat_prices.values() for p in prices]
    global_avg = round(sum(all_prices) / len(all_prices), 2) if all_prices else 100.00
    log(f"  Global average price: {global_avg} {CURRENCY}")

    # Assign prices
    batch = []
    fixed = 0
    parent_prices = {}  # Cache parent model prices

    for prod_info in no_price_products:
        sku = prod_info["sku"]
        categories = prod_info["categories"]
        parent = prod_info.get("parent")

        # Strategy 1: Use parent product model price if available
        if parent and parent in parent_prices:
            price = parent_prices[parent]
        else:
            price = None

        # Strategy 2: Use category average
        if not price:
            for cat in categories:
                if cat in cat_avg:
                    price = cat_avg[cat]
                    break

        # Strategy 3: Use global average
        if not price:
            price = global_avg

        batch.append({
            "identifier": sku,
            "values": {
                "price": [{"locale": None, "scope": None, "data": [
                    {"amount": str(price), "currency": CURRENCY}
                ]}]
            }
        })
        fixed += 1

        if len(batch) >= BATCH_SIZE:
            r = api.patch_batch("products", batch)
            if r.status_code == 200:
                errs = [x for x in parse_jsonl(r) if x.get("status_code") not in (200, 201, 204)]
                if errs:
                    log(f"  Batch errors: {len(errs)}", "WARN")
            batch = []

    if batch:
        api.patch_batch("products", batch)

    log(f"  Assigned prices to {fixed} products")
    log("Fix 3 complete.\n")
    return fixed


# ============================================================
# FIX 4: AUTO-ASSIGN CATEGORIES TO UNCATEGORIZED PRODUCTS
# ============================================================
def fix_categories(api):
    """Use product name keyword matching to assign the best category"""
    log("=" * 60)
    log("FIX 4: Auto-Assigning Categories to Uncategorized Products")
    log("=" * 60)

    # Get all categories and build keyword index
    all_categories = api.get_all_categories()
    cat_keywords = {}
    for cat in all_categories:
        code = cat["code"]
        label = cat.get("labels", {}).get("en_US", "").lower()
        fr_label = cat.get("labels", {}).get("fr_FR", "").lower()
        if cat.get("parent") is None:
            continue  # Skip root
        keywords = set()
        for word in re.split(r'[\s_\-/]+', label + " " + fr_label):
            if len(word) > 2:
                keywords.add(word)
        cat_keywords[code] = keywords

    log(f"  Category keyword index: {len(cat_keywords)} categories")

    # Find uncategorized products
    uncategorized = []
    for prod in api.get_all_products():
        if not prod.get("categories"):
            sku = prod.get("identifier", "")
            vals = prod.get("values", {})
            en_name = ""
            for v in vals.get("name", []):
                if v.get("locale") == "en_US":
                    en_name = v.get("data", "")
            uncategorized.append({"sku": sku, "name": en_name, "parent": prod.get("parent")})

    log(f"  Uncategorized products: {len(uncategorized)}")

    if not uncategorized:
        log("  No uncategorized products")
        return 0

    # Match products to categories using name keywords
    batch = []
    fixed = 0

    # Build parent->categories lookup from existing products
    parent_cats = defaultdict(set)
    for prod in api.get_all_products():
        parent = prod.get("parent")
        cats = prod.get("categories", [])
        if parent and cats:
            parent_cats[parent].update(cats)

    for prod_info in uncategorized:
        sku = prod_info["sku"]
        name = prod_info["name"].lower()
        parent = prod_info.get("parent")
        name_words = set(re.split(r'[\s_\-/\'"]+', name))
        name_words = {w for w in name_words if len(w) > 2}

        # Strategy 1: Inherit from parent product model siblings
        if parent and parent in parent_cats:
            assigned_cats = list(parent_cats[parent])[:10]
            if assigned_cats:
                batch.append({"identifier": sku, "categories": assigned_cats})
                fixed += 1
                continue

        # Strategy 2: Keyword matching
        best_match = None
        best_score = 0
        for code, keywords in cat_keywords.items():
            score = len(name_words & keywords)
            if score > best_score:
                best_score = score
                best_match = code

        if best_match and best_score >= 2:
            batch.append({"identifier": sku, "categories": [best_match]})
            fixed += 1
        elif best_match and best_score >= 1:
            # Partial match - still assign
            batch.append({"identifier": sku, "categories": [best_match]})
            fixed += 1

        if len(batch) >= BATCH_SIZE:
            r = api.patch_batch("products", batch)
            batch = []

    if batch:
        api.patch_batch("products", batch)

    log(f"  Assigned categories to {fixed} products")
    log("Fix 4 complete.\n")
    return fixed


# ============================================================
# FIX 5: SEO DEEP OPTIMIZATION
# ============================================================
def seo_optimize(api):
    """URL key deduplication, meta quality improvement, SEO scoring"""
    log("=" * 60)
    log("FIX 5: SEO Deep Optimization")
    log("=" * 60)

    # Collect all url_keys and check for duplicates
    url_keys = defaultdict(list)
    products_data = {}

    for prod in api.get_all_products():
        sku = prod.get("identifier", "")
        vals = prod.get("values", {})

        url_key = ""
        for v in vals.get("url_key", []):
            if v.get("data"):
                url_key = v["data"]

        if url_key:
            url_keys[url_key].append(sku)

        # Also collect for meta quality check
        meta_title = ""
        meta_desc = ""
        en_name = ""
        for v in vals.get("meta_title", []):
            if v.get("locale") == "en_US" and v.get("data"):
                meta_title = v["data"]
        for v in vals.get("meta_description", []):
            if v.get("locale") == "en_US" and v.get("data"):
                meta_desc = v["data"]
        for v in vals.get("name", []):
            if v.get("locale") == "en_US" and v.get("data"):
                en_name = v["data"]

        products_data[sku] = {
            "url_key": url_key,
            "meta_title": meta_title,
            "meta_desc": meta_desc,
            "name": en_name,
        }

    # Find duplicate url_keys
    dupes = {k: skus for k, skus in url_keys.items() if len(skus) > 1}
    log(f"  Duplicate URL key groups: {len(dupes)}")

    batch = []
    fixed_urlkeys = 0

    for url_key, skus in dupes.items():
        # Keep the first, modify the rest
        for i, sku in enumerate(skus[1:], 1):
            new_key = f"{url_key}-{i}"
            # Ensure new key is also unique
            while new_key in url_keys:
                new_key = f"{url_key}-{i}-{sku[-4:]}"
            batch.append({
                "identifier": sku,
                "values": {
                    "url_key": [{"locale": None, "scope": None, "data": new_key}]
                }
            })
            fixed_urlkeys += 1

    if batch:
        r = api.patch_batch("products", batch)
        if r.status_code == 200:
            errs = [x for x in parse_jsonl(r) if x.get("status_code") not in (200, 201, 204)]
            if errs:
                log(f"  URL key batch errors: {len(errs)}", "WARN")
    log(f"  Fixed {fixed_urlkeys} duplicate URL keys")

    # Meta quality improvement: ensure meta_title is <=60 chars
    batch = []
    fixed_meta = 0

    for sku, data in products_data.items():
        mt = data["meta_title"]
        md = data["meta_desc"]
        name = data["name"]
        update = {}

        # Fix meta_title > 60 chars
        if mt and len(mt) > 60:
            new_mt = mt[:57].rsplit(' ', 1)[0]
            if len(new_mt) < 15:
                new_mt = mt[:57]
            new_mt = new_mt.rstrip(' -,;:.') + "..."
            update["meta_title"] = [{"locale": "en_US", "scope": None, "data": new_mt}]

        # Fix meta_description too short (<50 chars) or too long (>300 chars)
        if md and len(md) < 50 and name:
            new_md = f"{name} - Qualite professionnelle chez Techno Stationery. " \
                     f"Livraison en Algerie. {md}"
            update["meta_description"] = [{"locale": "en_US", "scope": None, "data": new_md[:300]}]
        elif md and len(md) > 300:
            new_md = md[:297].rsplit(' ', 1)[0] + "..."
            update["meta_description"] = [{"locale": "en_US", "scope": None, "data": new_md}]

        if update:
            batch.append({"identifier": sku, "values": update})
            fixed_meta += 1

        if len(batch) >= BATCH_SIZE:
            api.patch_batch("products", batch)
            batch = []

    if batch:
        api.patch_batch("products", batch)

    log(f"  Improved meta quality for {fixed_meta} products")
    log("Fix 5 complete.\n")
    return fixed_urlkeys + fixed_meta


# ============================================================
# FIX 6: DATA QUALITY & COMPLETENESS ENFORCEMENT
# ============================================================
def data_quality(api):
    """Set attribute requirements for the ecommerce channel on all families"""
    log("=" * 60)
    log("FIX 6: Data Quality & Completeness Enforcement")
    log("=" * 60)

    # Get all families
    r = api.get("families", {"limit": 100})
    families = r.json().get("_embedded", {}).get("items", []) if r.status_code == 200 else []

    # Define required attributes for ecommerce channel
    ecommerce_required = ["sku", "name", "price", "meta_title", "meta_description", "url_key"]

    fixed = 0
    for fam in families:
        current_reqs = fam.get("attribute_requirements", {}).get(CHANNEL, [])
        new_reqs = list(set(current_reqs + ecommerce_required))

        if set(new_reqs) != set(current_reqs):
            r = api.patch(f"families/{fam['code']}", {
                "attribute_requirements": {CHANNEL: new_reqs}
            })
            if r.status_code in (200, 201, 204):
                log(f"  Updated {fam['code']}: {len(current_reqs)} -> {len(new_reqs)} required attrs")
                fixed += 1
            else:
                log(f"  Failed to update {fam['code']}: {r.status_code} {r.text[:200]}", "WARN")

    log(f"  Updated {fixed} family attribute requirements")
    log("Fix 6 complete.\n")
    return fixed


# ============================================================
# FIX 7: ATTRIBUTE CLEANUP - CONSOLIDATE OPTIONS
# ============================================================
def cleanup_options(api):
    """Consolidate high-cardinality attribute options (color, pattern)"""
    log("=" * 60)
    log("FIX 7: Attribute Option Consolidation")
    log("=" * 60)

    target_attrs = ["color", "pattern"]
    total_consolidated = 0

    for attr_code in target_attrs:
        # Get all options for this attribute
        page = 1
        all_options = []
        while True:
            r = api.get(f"attributes/{attr_code}/options", {"limit": 100, "page": page})
            if r.status_code != 200:
                log(f"  Cannot read options for {attr_code}: {r.status_code}", "WARN")
                break
            items = r.json().get("_embedded", {}).get("items", [])
            if not items:
                break
            all_options.extend(items)
            page += 1

        log(f"  {attr_code}: {len(all_options)} options")

        # Group by normalized label to find duplicates
        label_groups = defaultdict(list)
        for opt in all_options:
            label = opt.get("labels", {}).get("en_US", opt["code"]).strip()
            normalized = label.lower().replace("_", " ").replace("-", " ").strip()
            # Remove common suffixes like "vif", "fonce", "clair" for grouping
            label_groups[normalized].append(opt)

        # Count actual duplicates
        dupes = {n: opts for n, opts in label_groups.items() if len(opts) > 1}
        log(f"  {attr_code}: {len(dupes)} duplicate option groups")

        # For now, just log the most impactful duplicates
        if dupes:
            sorted_dupes = sorted(dupes.items(), key=lambda x: -len(x[1]))
            for name, opts in sorted_dupes[:10]:
                codes = [o["code"] for o in opts]
                log(f"    '{name}': {len(opts)} options -> {codes[:5]}")
            total_consolidated += len(dupes)

    log(f"  Identified {total_consolidated} option groups for consolidation")
    log("  Note: Option merging requires product-level reassignment (deferred)")
    log("Fix 7 complete.\n")
    return total_consolidated


# ============================================================
# FIX 8: COMPREHENSIVE AUDIT WITH FULL PAGINATION
# ============================================================
def full_audit(api):
    """Final comprehensive audit using search_after pagination for accuracy"""
    log("=" * 60)
    log("COMPREHENSIVE AUDIT (search_after pagination)")
    log("=" * 60)

    report = []
    report.append("=" * 70)
    report.append("AKENEO PIM - COMPREHENSIVE AUDIT REPORT")
    report.append(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    report.append(f"Instance: {AKENEO_API['base_url']}")
    report.append("=" * 70)

    # ---- FAMILIES ----
    report.append("\n## 1. FAMILIES")
    r = api.get("families", {"limit": 100})
    families = r.json().get("_embedded", {}).get("items", []) if r.status_code == 200 else []
    report.append(f"   Total: {len(families)}")
    for fam in families:
        attrs = fam.get("attributes", [])
        labels = fam.get("labels", {})
        reqs = fam.get("attribute_requirements", {}).get(CHANNEL, [])
        report.append(f"   - {fam['code']}: {len(attrs)} attrs, "
                      f"en_US={'OK' if labels.get('en_US') else 'NO'}, "
                      f"fr_FR={'OK' if labels.get('fr_FR') else 'NO'}, "
                      f"ar_DZ={'OK' if labels.get('ar_DZ') else 'NO'}, "
                      f"required({CHANNEL})={len(reqs)}: {','.join(sorted(reqs))}")

    # ---- ATTRIBUTES ----
    report.append("\n## 2. ATTRIBUTES")
    r = api.get("attributes", {"limit": 100})
    attributes = r.json().get("_embedded", {}).get("items", []) if r.status_code == 200 else []
    report.append(f"   Total: {len(attributes)}")
    groups = defaultdict(list)
    for a in attributes:
        groups[a.get("group", "other")].append(a["code"])
    for g, attrs in sorted(groups.items()):
        report.append(f"   {g}: {len(attrs)} ({', '.join(sorted(attrs))})")

    # ---- CATEGORIES ----
    report.append("\n## 3. CATEGORIES")
    all_cats = api.get_all_categories()
    report.append(f"   Total: {len(all_cats)}")
    roots = [c for c in all_cats if c.get("parent") is None]
    report.append(f"   Root: {len(roots)}")

    # Duplicate check
    cat_names = defaultdict(list)
    for c in all_cats:
        name = c.get("labels", {}).get("en_US", "").strip().lower()
        if name:
            cat_names[name].append(c["code"])
    dupes = {n: codes for n, codes in cat_names.items() if len(codes) > 1}
    report.append(f"   Duplicate name groups: {len(dupes)}")
    empty_cats = sum(1 for c in all_cats if not c.get("labels", {}).get("fr_FR"))
    report.append(f"   Missing fr_FR label: {empty_cats}")

    # ---- PRODUCTS (full scan) ----
    report.append("\n## 4. PRODUCTS")
    total = 0
    family_counts = defaultdict(int)
    stats = {
        "no_name": 0, "no_price": 0, "no_category": 0, "long_name": 0,
        "missing_en": 0, "missing_fr": 0, "missing_ar": 0,
        "missing_meta_title": 0, "missing_meta_desc": 0,
        "missing_meta_kw": 0, "missing_url_key": 0,
    }

    for prod in api.get_all_products():
        total += 1
        vals = prod.get("values", {})
        family_counts[prod.get("family", "none")] += 1

        # Name checks
        en_name = fr_name = ar_name = ""
        for v in vals.get("name", []):
            loc = v.get("locale", "")
            data = v.get("data", "").strip()
            if loc == "en_US" and data: en_name = data
            elif loc == "fr_FR" and data: fr_name = data
            elif loc == "ar_DZ" and data: ar_name = data

        if not en_name: stats["missing_en"] += 1
        if not fr_name: stats["missing_fr"] += 1
        if not ar_name: stats["missing_ar"] += 1
        if not en_name and not fr_name: stats["no_name"] += 1
        if en_name and len(en_name) > 60: stats["long_name"] += 1

        # Price
        has_price = False
        for v in vals.get("price", []):
            if v.get("data"):
                for pd in v["data"]:
                    if pd.get("amount") and float(pd["amount"]) > 0:
                        has_price = True
        if not has_price: stats["no_price"] += 1

        # Categories
        if not prod.get("categories"): stats["no_category"] += 1

        # SEO
        has_field = lambda f: any(v.get("data", "").strip() for v in vals.get(f, []))
        if not has_field("meta_title"): stats["missing_meta_title"] += 1
        if not has_field("meta_description"): stats["missing_meta_desc"] += 1
        if not has_field("meta_keyword"): stats["missing_meta_kw"] += 1
        if not has_field("url_key"): stats["missing_url_key"] += 1

    report.append(f"   Total: {total}")
    report.append(f"\n   Family distribution:")
    for fam, count in sorted(family_counts.items(), key=lambda x: -x[1]):
        report.append(f"     {fam}: {count} ({count / total * 100:.1f}%)")

    report.append(f"\n   Names:")
    report.append(f"     en_US: {total - stats['missing_en']}/{total} ({(total - stats['missing_en']) / total * 100:.1f}%)")
    report.append(f"     fr_FR: {total - stats['missing_fr']}/{total} ({(total - stats['missing_fr']) / total * 100:.1f}%)")
    report.append(f"     ar_DZ: {total - stats['missing_ar']}/{total} ({(total - stats['missing_ar']) / total * 100:.1f}%)")
    report.append(f"     > 60 chars: {stats['long_name']}")

    report.append(f"\n   SEO:")
    for field, key in [("meta_title", "missing_meta_title"), ("meta_description", "missing_meta_desc"),
                       ("meta_keyword", "missing_meta_kw"), ("url_key", "missing_url_key")]:
        count = total - stats[key]
        report.append(f"     {field}: {count}/{total} ({count / total * 100:.1f}%)")

    report.append(f"\n   Data quality:")
    report.append(f"     Missing price: {stats['no_price']}")
    report.append(f"     Missing categories: {stats['no_category']}")
    report.append(f"     Missing name: {stats['no_name']}")

    # ---- PRODUCT MODELS ----
    report.append("\n## 5. PRODUCT MODELS")
    page = 1
    total_models = 0
    while True:
        r = api.get("product-models", {"limit": 100, "page": page})
        if r.status_code != 200:
            break
        items = r.json().get("_embedded", {}).get("items", [])
        if not items:
            break
        total_models += len(items)
        page += 1
    report.append(f"   Total: {total_models}")

    # ---- ASSOCIATIONS ----
    report.append("\n## 6. ASSOCIATIONS")
    r = api.get("association-types", {"limit": 100})
    if r.status_code == 200:
        atypes = r.json().get("_embedded", {}).get("items", [])
        report.append(f"   Types: {len(atypes)} -> {', '.join(t['code'] for t in atypes)}")

    # ---- FAMILY VARIANTS ----
    report.append("\n## 7. FAMILY VARIANTS")
    for fam in families:
        r = api.get(f"families/{fam['code']}/variants", {"limit": 100})
        if r.status_code == 200:
            variants = r.json().get("_embedded", {}).get("items", [])
            for v in variants:
                axes = []
                for vas in v.get("variant_attribute_sets", []):
                    axes.extend(vas.get("axes", []))
                report.append(f"   {fam['code']}/{v['code']}: axes={axes}")

    # ---- CHANNEL ----
    report.append("\n## 8. CHANNEL")
    r = api.get("channels/ecommerce")
    if r.status_code == 200:
        ch = r.json()
        report.append(f"   Channel: {ch.get('code')}")
        report.append(f"   Locales: {ch.get('locales', [])}")
        report.append(f"   Currencies: {ch.get('currencies', [])}")

    # ---- SCORECARD ----
    report.append("\n## 9. SCORECARD")
    checks = [
        ("en_US names", total - stats["missing_en"], total),
        ("fr_FR names", total - stats["missing_fr"], total),
        ("ar_DZ names", total - stats["missing_ar"], total),
        ("meta_title", total - stats["missing_meta_title"], total),
        ("meta_description", total - stats["missing_meta_desc"], total),
        ("meta_keyword", total - stats["missing_meta_kw"], total),
        ("url_key", total - stats["missing_url_key"], total),
        ("price (>0)", total - stats["no_price"], total),
        ("categories", total - stats["no_category"], total),
    ]
    for name, count, tot in checks:
        pct = count / tot * 100 if tot else 0
        status = "PASS" if pct >= 99.5 else ("WARN" if pct >= 90 else "FAIL")
        report.append(f"   [{status}] {name}: {count}/{tot} ({pct:.1f}%)")

    # Save report
    report_text = "\n".join(report)
    report_file = f"/home/pim/public_html/webapp/PHASE3_AUDIT_{datetime.now().strftime('%Y%m%d_%H%M%S')}.txt"
    with open(report_file, "w") as f:
        f.write(report_text)

    print(report_text)
    log(f"  Report saved to {report_file}")
    log("Audit complete.\n")
    return report_text


# ============================================================
# MAIN
# ============================================================
def main():
    parser = argparse.ArgumentParser(description="Akeneo PIM Phase 3+ Fixes")
    parser.add_argument("--fix-names", action="store_true", help="Fix remaining long product names")
    parser.add_argument("--dedup-categories", action="store_true", help="Re-run category deduplication")
    parser.add_argument("--fix-prices", action="store_true", help="Assign default prices")
    parser.add_argument("--fix-categories", action="store_true", help="Auto-assign categories")
    parser.add_argument("--seo-optimize", action="store_true", help="SEO deep optimization")
    parser.add_argument("--data-quality", action="store_true", help="Enforce data quality rules")
    parser.add_argument("--cleanup-options", action="store_true", help="Consolidate attribute options")
    parser.add_argument("--audit", action="store_true", help="Full comprehensive audit")
    parser.add_argument("--all", action="store_true", help="Run all fixes in order")
    args = parser.parse_args()

    if not any(vars(args).values()):
        parser.print_help()
        sys.exit(1)

    api = AkeneoClient(AKENEO_API)
    api.auth()

    log("=" * 60)
    log("AKENEO PIM PHASE 3+ FIXES STARTED")
    log(f"Timestamp: {datetime.now().isoformat()}")
    log("=" * 60)

    results = {}

    try:
        if args.fix_names or args.all:
            results["names_shortened"] = fix_long_names(api)

        if args.dedup_categories or args.all:
            results["categories_deduped"] = dedup_categories(api)

        if args.fix_prices or args.all:
            results["prices_assigned"] = fix_prices(api)

        if args.fix_categories or args.all:
            results["categories_assigned"] = fix_categories(api)

        if args.seo_optimize or args.all:
            results["seo_improvements"] = seo_optimize(api)

        if args.data_quality or args.all:
            results["families_updated"] = data_quality(api)

        if args.cleanup_options or args.all:
            results["options_identified"] = cleanup_options(api)

        if args.audit or args.all:
            full_audit(api)

    except Exception as e:
        log(f"FATAL ERROR: {e}", "ERROR")
        traceback.print_exc()
        sys.exit(1)

    log("=" * 60)
    log("SUMMARY:")
    for key, val in results.items():
        log(f"  {key}: {val}")
    log("=" * 60)
    log("ALL PHASE 3+ FIXES COMPLETE")


if __name__ == "__main__":
    main()
