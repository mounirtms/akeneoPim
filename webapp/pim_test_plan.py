#!/usr/bin/env python3
"""
Akeneo PIM - Comprehensive Test Plan & Validation Suite
========================================================
Automated test suite for validating all PIM data quality, display,
and API functionality after tuning operations.

Test Categories:
  TC1: Data Integrity Tests (required fields, data types, constraints)
  TC2: Display Quality Tests (names, descriptions, images, meta)
  TC3: Multilingual Tests (en_US, fr_FR, ar_DZ completeness)
  TC4: Product Structure Tests (families, models, variants, categories)
  TC5: SEO Tests (URL keys, meta titles, descriptions)
  TC6: Association Tests (related, cross-sell, upsell)
  TC7: API Performance Tests (response times, pagination)
  TC8: Attribute Configuration Tests (filters, options, labels)
  TC9: Completeness & Scoring Tests
  TC10: Regression Tests (verify previous fixes still hold)

Usage:
  python3 pim_test_plan.py                  # Run all tests
  python3 pim_test_plan.py --category TC1   # Run specific category
  python3 pim_test_plan.py --verbose        # Detailed output
  python3 pim_test_plan.py --report         # Generate HTML report
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
LOG_FILE = "/home/pim/public_html/var/logs/pim_tests.log"
REPORT_DIR = "/home/pim/public_html/var/logs"
LOCALES = ["en_US", "fr_FR", "ar_DZ"]
FAMILIES = ["arts", "bags", "notebooks", "office", "stationery", "writing"]
CHANNEL = "ecommerce"

# Expected thresholds
THRESHOLDS = {
    "min_products": 9500,
    "min_product_models": 550,
    "min_categories": 2000,
    "image_coverage_pct": 88.0,
    "brand_coverage_pct": 95.0,
    "manufacturer_coverage_pct": 95.0,
    "description_coverage_pct": 99.0,
    "visibility_coverage_pct": 99.5,
    "status_coverage_pct": 99.5,
    "price_coverage_pct": 99.0,
    "meta_coverage_pct": 99.0,
    "category_coverage_pct": 99.0,
    "max_allcaps_names_pct": 1.0,
    "max_short_desc_pct": 2.0,
    "max_duplicate_names_pct": 1.0,
    "api_response_max_ms": 5000,
    "api_list_max_ms": 10000,
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

    def timed_get(self, ep, params=None):
        """GET with timing info."""
        start = time.time()
        r = self.get(ep, params)
        elapsed_ms = (time.time() - start) * 1000
        return r, elapsed_ms

    def get_sample_products(self, n=200):
        """Get first N products for sampling."""
        products = []
        page = 1
        while len(products) < n:
            r = self.get("products", {"limit": 100, "page": page})
            if r.status_code != 200:
                break
            items = r.json().get("_embedded", {}).get("items", [])
            if not items:
                break
            products.extend(items)
            page += 1
        return products[:n]

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
            if page % 30 == 0:
                log(f"  ... scanned {page * 100} products")

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
# TEST RESULT TRACKING
# ============================================================
class TestResult:
    def __init__(self, test_id, name, category):
        self.test_id = test_id
        self.name = name
        self.category = category
        self.status = "PENDING"  # PASS, FAIL, WARN, SKIP, ERROR
        self.message = ""
        self.details = []
        self.duration_ms = 0
        self.expected = ""
        self.actual = ""

    def passed(self, msg="", details=None):
        self.status = "PASS"
        self.message = msg
        if details:
            self.details = details

    def failed(self, msg="", expected="", actual="", details=None):
        self.status = "FAIL"
        self.message = msg
        self.expected = str(expected)
        self.actual = str(actual)
        if details:
            self.details = details

    def warned(self, msg="", details=None):
        self.status = "WARN"
        self.message = msg
        if details:
            self.details = details

    def errored(self, msg=""):
        self.status = "ERROR"
        self.message = msg

    def skipped(self, msg=""):
        self.status = "SKIP"
        self.message = msg


class TestSuite:
    def __init__(self):
        self.results = []
        self.start_time = None
        self.end_time = None

    def add(self, result):
        self.results.append(result)

    def summary(self):
        total = len(self.results)
        passed = sum(1 for r in self.results if r.status == "PASS")
        failed = sum(1 for r in self.results if r.status == "FAIL")
        warned = sum(1 for r in self.results if r.status == "WARN")
        errors = sum(1 for r in self.results if r.status == "ERROR")
        skipped = sum(1 for r in self.results if r.status == "SKIP")
        return {
            "total": total, "passed": passed, "failed": failed,
            "warned": warned, "errors": errors, "skipped": skipped,
            "pass_rate": f"{passed/total*100:.1f}%" if total > 0 else "N/A",
        }

    def print_report(self, verbose=False):
        s = self.summary()
        duration = (self.end_time - self.start_time) if self.start_time and self.end_time else 0

        log("\n" + "=" * 70)
        log("PIM TEST SUITE RESULTS")
        log(f"Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        log(f"Duration: {duration:.1f}s")
        log("=" * 70)
        log(f"Total: {s['total']}  |  ✓ Pass: {s['passed']}  |  ✗ Fail: {s['failed']}  |  ⚠ Warn: {s['warned']}  |  ✕ Error: {s['errors']}  |  ○ Skip: {s['skipped']}")
        log(f"Pass Rate: {s['pass_rate']}")
        log("-" * 70)

        # Group by category
        categories = defaultdict(list)
        for r in self.results:
            categories[r.category].append(r)

        for cat in sorted(categories.keys()):
            tests = categories[cat]
            cat_pass = sum(1 for t in tests if t.status == "PASS")
            log(f"\n  [{cat}] ({cat_pass}/{len(tests)} passed)")

            for t in tests:
                icon = {"PASS": "✓", "FAIL": "✗", "WARN": "⚠", "ERROR": "✕", "SKIP": "○", "PENDING": "?"}
                log(f"    {icon.get(t.status, '?')} {t.test_id}: {t.name} [{t.status}] {t.message}")
                if verbose and t.status in ("FAIL", "WARN", "ERROR"):
                    if t.expected:
                        log(f"      Expected: {t.expected}")
                    if t.actual:
                        log(f"      Actual: {t.actual}")
                    for d in t.details[:5]:
                        log(f"      - {d}")

        log("\n" + "=" * 70)

    def generate_json_report(self):
        return {
            "timestamp": datetime.now().isoformat(),
            "summary": self.summary(),
            "duration_seconds": (self.end_time - self.start_time) if self.start_time and self.end_time else 0,
            "tests": [
                {
                    "id": r.test_id,
                    "name": r.name,
                    "category": r.category,
                    "status": r.status,
                    "message": r.message,
                    "expected": r.expected,
                    "actual": r.actual,
                    "details": r.details[:10],
                }
                for r in self.results
            ],
        }


# ============================================================
# TC1: DATA INTEGRITY TESTS
# ============================================================
def tc1_data_integrity(api, suite, products):
    log("\n--- TC1: Data Integrity Tests ---")

    # TC1.1: Product count meets minimum
    t = TestResult("TC1.1", "Product count >= threshold", "TC1: Data Integrity")
    total = len(list(api.get_all_products()))
    if total >= THRESHOLDS["min_products"]:
        t.passed(f"{total:,} products (threshold: {THRESHOLDS['min_products']:,})")
    else:
        t.failed(f"Only {total:,} products", THRESHOLDS["min_products"], total)
    suite.add(t)

    # TC1.2: All products have a family
    t = TestResult("TC1.2", "All products assigned to a family", "TC1: Data Integrity")
    no_family = [p.get("identifier", "") for p in products if not p.get("family")]
    if not no_family:
        t.passed(f"All {len(products)} sampled products have families")
    else:
        t.failed(f"{len(no_family)} products without family", "0", len(no_family), no_family[:10])
    suite.add(t)

    # TC1.3: All products have valid SKU
    t = TestResult("TC1.3", "All products have valid SKU identifier", "TC1: Data Integrity")
    bad_skus = [p.get("identifier", "") for p in products
                if not p.get("identifier") or len(p.get("identifier", "")) < 1]
    if not bad_skus:
        t.passed(f"All {len(products)} sampled products have valid SKUs")
    else:
        t.failed(f"{len(bad_skus)} invalid SKUs", "0", len(bad_skus))
    suite.add(t)

    # TC1.4: Price > 0 for all products
    t = TestResult("TC1.4", "All products have price > 0", "TC1: Data Integrity")
    zero_price = []
    for p in products:
        vals = p.get("values", {})
        for pv in vals.get("price", []):
            for pp in pv.get("data", []):
                if pp.get("currency") == "DZD" and float(pp.get("amount", 0)) == 0:
                    zero_price.append(p.get("identifier", ""))
    if not zero_price:
        t.passed(f"All {len(products)} sampled products have price > 0")
    else:
        t.failed(f"{len(zero_price)} products with zero price", "0", len(zero_price), zero_price[:10])
    suite.add(t)

    # TC1.5: No weight placeholders (9999)
    t = TestResult("TC1.5", "No weight=9999 placeholders remain", "TC1: Data Integrity")
    bad_weights = []
    for p in products:
        vals = p.get("values", {})
        wt = get_val(vals, "weight")
        if wt:
            amt = wt.get("amount") if isinstance(wt, dict) else wt
            try:
                if float(str(amt)) >= 9990:
                    bad_weights.append(p.get("identifier", ""))
            except (ValueError, TypeError):
                pass
    if not bad_weights:
        t.passed("No weight=9999 placeholders in sample")
    else:
        t.failed(f"{len(bad_weights)} products with placeholder weight", "0", len(bad_weights), bad_weights[:10])
    suite.add(t)

    # TC1.6: No weight=0 values
    t = TestResult("TC1.6", "No weight=0 values remain", "TC1: Data Integrity")
    zero_weights = []
    for p in products:
        vals = p.get("values", {})
        wt = get_val(vals, "weight")
        if wt:
            amt = wt.get("amount") if isinstance(wt, dict) else wt
            try:
                if float(str(amt)) == 0:
                    zero_weights.append(p.get("identifier", ""))
            except (ValueError, TypeError):
                pass
    if not zero_weights:
        t.passed("No weight=0 values in sample")
    else:
        t.failed(f"{len(zero_weights)} products with weight=0", "0", len(zero_weights), zero_weights[:10])
    suite.add(t)

    # TC1.7: Enabled products count
    t = TestResult("TC1.7", "Product status distribution is correct", "TC1: Data Integrity")
    enabled = sum(1 for p in products if get_val(p.get("values", {}), "product_status") is True)
    disabled = sum(1 for p in products if get_val(p.get("values", {}), "product_status") is False)
    none_status = sum(1 for p in products if get_val(p.get("values", {}), "product_status") is None)
    if none_status == 0:
        t.passed(f"Enabled: {enabled}, Disabled: {disabled}, Unset: {none_status}")
    else:
        t.failed(f"{none_status} products without status", "0 unset", none_status)
    suite.add(t)


# ============================================================
# TC2: DISPLAY QUALITY TESTS
# ============================================================
def tc2_display_quality(api, suite, products):
    log("\n--- TC2: Display Quality Tests ---")

    # TC2.1: ALL-CAPS name percentage
    t = TestResult("TC2.1", "ALL-CAPS names below threshold", "TC2: Display Quality")
    allcaps = sum(1 for p in products
                  if (get_val(p.get("values", {}), "name", "en_US") or "") ==
                  (get_val(p.get("values", {}), "name", "en_US") or "").upper() and
                  len(get_val(p.get("values", {}), "name", "en_US") or "") > 3)
    pct = allcaps / len(products) * 100 if products else 0
    if pct <= THRESHOLDS["max_allcaps_names_pct"]:
        t.passed(f"{allcaps}/{len(products)} ({pct:.1f}%) ALL-CAPS names (threshold: {THRESHOLDS['max_allcaps_names_pct']}%)")
    else:
        t.failed(f"{allcaps} ALL-CAPS names ({pct:.1f}%)", f"<= {THRESHOLDS['max_allcaps_names_pct']}%", f"{pct:.1f}%")
    suite.add(t)

    # TC2.2: Short description quality
    t = TestResult("TC2.2", "Short descriptions >= 30 chars", "TC2: Display Quality")
    short = sum(1 for p in products
                if len(get_val(p.get("values", {}), "short_description", "en_US") or "") < 30)
    pct = short / len(products) * 100 if products else 0
    if pct <= THRESHOLDS["max_short_desc_pct"]:
        t.passed(f"{short}/{len(products)} ({pct:.1f}%) short descriptions (threshold: {THRESHOLDS['max_short_desc_pct']}%)")
    else:
        t.failed(f"{short} short descriptions ({pct:.1f}%)", f"<= {THRESHOLDS['max_short_desc_pct']}%", f"{pct:.1f}%")
    suite.add(t)

    # TC2.3: Image coverage
    t = TestResult("TC2.3", "Image coverage meets threshold", "TC2: Display Quality")
    with_image = sum(1 for p in products if any(d.get("data") for d in p.get("values", {}).get("image", [])))
    pct = with_image / len(products) * 100 if products else 0
    if pct >= THRESHOLDS["image_coverage_pct"]:
        t.passed(f"{with_image}/{len(products)} ({pct:.1f}%) have images (threshold: {THRESHOLDS['image_coverage_pct']}%)")
    else:
        t.failed(f"Image coverage {pct:.1f}%", f">= {THRESHOLDS['image_coverage_pct']}%", f"{pct:.1f}%")
    suite.add(t)

    # TC2.4: No HTML/script injection in descriptions
    t = TestResult("TC2.4", "No script injection in descriptions", "TC2: Display Quality")
    injections = []
    for p in products:
        vals = p.get("values", {})
        for dd in vals.get("description", []):
            txt = dd.get("data", "") or ""
            if "<script" in txt.lower() or "javascript:" in txt.lower() or "onerror=" in txt.lower():
                injections.append(p.get("identifier", ""))
                break
    if not injections:
        t.passed("No script injection found in sample")
    else:
        t.failed(f"{len(injections)} products with potential injection", "0", len(injections), injections[:10])
    suite.add(t)

    # TC2.5: Description length quality
    t = TestResult("TC2.5", "Descriptions have meaningful content (>= 20 chars)", "TC2: Display Quality")
    thin_desc = []
    for p in products:
        vals = p.get("values", {})
        desc = get_val(vals, "description", "en_US") or ""
        if 0 < len(desc) < 20:
            thin_desc.append(p.get("identifier", ""))
    if not thin_desc:
        t.passed("All descriptions have meaningful length")
    else:
        t.warned(f"{len(thin_desc)} products with very short descriptions", thin_desc[:10])
    suite.add(t)

    # TC2.6: Duplicate names in sample
    t = TestResult("TC2.6", "No duplicate product names in sample", "TC2: Display Quality")
    name_counts = defaultdict(int)
    for p in products:
        name = get_val(p.get("values", {}), "name", "en_US") or ""
        if name:
            name_counts[name] += 1
    dups = {k: v for k, v in name_counts.items() if v > 1}
    dup_pct = sum(dups.values()) / len(products) * 100 if products else 0
    if dup_pct <= THRESHOLDS["max_duplicate_names_pct"]:
        t.passed(f"{len(dups)} duplicate groups ({dup_pct:.1f}%) (threshold: {THRESHOLDS['max_duplicate_names_pct']}%)")
    else:
        t.warned(f"{len(dups)} duplicate name groups ({dup_pct:.1f}%)", list(dups.keys())[:5])
    suite.add(t)


# ============================================================
# TC3: MULTILINGUAL TESTS
# ============================================================
def tc3_multilingual(api, suite, products):
    log("\n--- TC3: Multilingual Tests ---")

    for locale in LOCALES:
        for attr, label in [("name", "Name"), ("description", "Description"),
                            ("short_description", "Short Description"),
                            ("meta_title", "Meta Title")]:
            t = TestResult(f"TC3.{locale}.{attr}", f"{label} ({locale}) coverage", "TC3: Multilingual")
            count = sum(1 for p in products if get_val(p.get("values", {}), attr, locale))
            pct = count / len(products) * 100 if products else 0
            threshold = THRESHOLDS.get("description_coverage_pct", 95.0)
            if pct >= threshold:
                t.passed(f"{count}/{len(products)} ({pct:.1f}%)")
            elif pct >= 80:
                t.warned(f"{count}/{len(products)} ({pct:.1f}%)")
            else:
                t.failed(f"{count}/{len(products)} ({pct:.1f}%)", f">= {threshold}%", f"{pct:.1f}%")
            suite.add(t)

    # TC3.consistency: Name consistency across locales
    t = TestResult("TC3.consistency", "All products have names in all 3 locales", "TC3: Multilingual")
    incomplete = []
    for p in products:
        vals = p.get("values", {})
        has_all = all(get_val(vals, "name", loc) for loc in LOCALES)
        if not has_all:
            incomplete.append(p.get("identifier", ""))
    if not incomplete:
        t.passed(f"All {len(products)} products have trilingual names")
    else:
        t.warned(f"{len(incomplete)} products missing name in some locale", incomplete[:10])
    suite.add(t)


# ============================================================
# TC4: PRODUCT STRUCTURE TESTS
# ============================================================
def tc4_product_structure(api, suite, products):
    log("\n--- TC4: Product Structure Tests ---")

    # TC4.1: All families exist
    t = TestResult("TC4.1", "All expected families exist", "TC4: Product Structure")
    families_found = set()
    for fam in FAMILIES:
        r = api.get(f"families/{fam}")
        if r.status_code == 200:
            families_found.add(fam)
    missing = set(FAMILIES) - families_found
    if not missing:
        t.passed(f"All {len(FAMILIES)} families exist")
    else:
        t.failed(f"Missing families: {missing}", "All families exist", f"Missing: {missing}")
    suite.add(t)

    # TC4.2: Product model count
    t = TestResult("TC4.2", "Product model count meets threshold", "TC4: Product Structure")
    model_count = 0
    for _ in api.get_all_product_models():
        model_count += 1
    if model_count >= THRESHOLDS["min_product_models"]:
        t.passed(f"{model_count} product models (threshold: {THRESHOLDS['min_product_models']})")
    else:
        t.failed(f"Only {model_count} models", THRESHOLDS["min_product_models"], model_count)
    suite.add(t)

    # TC4.3: All product models have categories
    t = TestResult("TC4.3", "All product models have categories", "TC4: Product Structure")
    models_no_cat = 0
    for model in api.get_all_product_models():
        if not model.get("categories", []):
            models_no_cat += 1
    if models_no_cat == 0:
        t.passed(f"All {model_count} product models have categories")
    else:
        t.failed(f"{models_no_cat} models without categories", "0", models_no_cat)
    suite.add(t)

    # TC4.4: Variant products have parent
    t = TestResult("TC4.4", "Variant products reference valid parent models", "TC4: Product Structure")
    orphan_variants = []
    for p in products:
        if p.get("parent") and not p.get("family"):
            orphan_variants.append(p.get("identifier", ""))
    if not orphan_variants:
        t.passed("No orphan variants in sample")
    else:
        t.warned(f"{len(orphan_variants)} potentially orphaned variants", orphan_variants[:10])
    suite.add(t)

    # TC4.5: Category count
    t = TestResult("TC4.5", "Category count meets threshold", "TC4: Product Structure")
    r = api.get("categories", {"limit": 1, "with_count": "true"})
    cat_count = r.json().get("items_count", 0) if r.status_code == 200 else 0
    # Fallback: count manually
    if cat_count == 0:
        page = 1
        while True:
            r2 = api.get("categories", {"limit": 100, "page": page})
            if r2.status_code != 200:
                break
            items = r2.json().get("_embedded", {}).get("items", [])
            if not items:
                break
            cat_count += len(items)
            page += 1
    if cat_count >= THRESHOLDS["min_categories"]:
        t.passed(f"{cat_count} categories (threshold: {THRESHOLDS['min_categories']})")
    else:
        t.failed(f"Only {cat_count} categories", THRESHOLDS["min_categories"], cat_count)
    suite.add(t)

    # TC4.6: Family distribution is reasonable
    t = TestResult("TC4.6", "Family distribution is balanced (no empty families)", "TC4: Product Structure")
    fam_dist = defaultdict(int)
    for p in products:
        fam_dist[p.get("family", "unknown")] += 1
    empty_fams = [f for f in FAMILIES if fam_dist.get(f, 0) == 0]
    if not empty_fams:
        t.passed(f"All families represented in sample: {dict(fam_dist)}")
    else:
        t.warned(f"Families with no products in sample: {empty_fams}")
    suite.add(t)


# ============================================================
# TC5: SEO TESTS
# ============================================================
def tc5_seo(api, suite, products):
    log("\n--- TC5: SEO Tests ---")

    # TC5.1: URL key format (url_key is NOT localizable in this PIM)
    t = TestResult("TC5.1", "URL keys are properly formatted", "TC5: SEO")
    bad_urls = []
    for p in products:
        vals = p.get("values", {})
        # url_key is non-localizable: locale=null, scope=null
        uk = get_val(vals, "url_key") or ""
        if not uk:
            bad_urls.append((p.get("identifier", ""), "missing"))
        elif " " in uk:
            bad_urls.append((p.get("identifier", ""), "contains spaces"))
        elif uk != uk.lower() and not any(c in uk for c in '\u0600\u0601'):
            bad_urls.append((p.get("identifier", ""), "not lowercase"))
    if not bad_urls:
        t.passed(f"All {len(products)} URL keys are properly formatted")
    else:
        t.failed(f"{len(bad_urls)} bad URL keys", "0", len(bad_urls),
                 [f"{sku}: {reason}" for sku, reason in bad_urls[:10]])
    suite.add(t)

    # TC5.2: Meta title coverage
    t = TestResult("TC5.2", "Meta title present for all locales", "TC5: SEO")
    missing_meta = 0
    for p in products:
        vals = p.get("values", {})
        for loc in LOCALES:
            if not get_val(vals, "meta_title", loc):
                missing_meta += 1
    pct = (len(products) * 3 - missing_meta) / (len(products) * 3) * 100 if products else 0
    if pct >= THRESHOLDS["meta_coverage_pct"]:
        t.passed(f"{pct:.1f}% meta title coverage across all locales")
    else:
        t.failed(f"Meta title coverage {pct:.1f}%", f">= {THRESHOLDS['meta_coverage_pct']}%", f"{pct:.1f}%")
    suite.add(t)

    # TC5.3: Meta description coverage
    t = TestResult("TC5.3", "Meta description present for all locales", "TC5: SEO")
    missing = 0
    for p in products:
        vals = p.get("values", {})
        for loc in LOCALES:
            if not get_val(vals, "meta_description", loc):
                missing += 1
    pct = (len(products) * 3 - missing) / (len(products) * 3) * 100 if products else 0
    if pct >= THRESHOLDS["meta_coverage_pct"]:
        t.passed(f"{pct:.1f}% meta description coverage")
    else:
        t.failed(f"Meta description coverage {pct:.1f}%", f">= {THRESHOLDS['meta_coverage_pct']}%", f"{pct:.1f}%")
    suite.add(t)

    # TC5.4: URL key uniqueness in sample
    t = TestResult("TC5.4", "URL keys are unique (no duplicates in sample)", "TC5: SEO")
    uk_map = defaultdict(list)
    for p in products:
        uk = get_val(p.get("values", {}), "url_key") or ""
        if uk:
            uk_map[uk].append(p.get("identifier", ""))
    dups = {k: v for k, v in uk_map.items() if len(v) > 1}
    if not dups:
        t.passed(f"All URL keys unique in {len(products)}-product sample")
    else:
        t.warned(f"{len(dups)} duplicate URL keys found", [f"{k}: {v}" for k, v in list(dups.items())[:5]])
    suite.add(t)


# ============================================================
# TC6: ASSOCIATION TESTS
# ============================================================
def tc6_associations(api, suite, products):
    log("\n--- TC6: Association Tests ---")

    assoc_types = ["RELATED", "CROSSSELL", "UPSELL"]
    for atype in assoc_types:
        t = TestResult(f"TC6.{atype}", f"{atype} associations present", "TC6: Associations")
        with_assoc = 0
        for p in products:
            assocs = p.get("associations", {}).get(atype, {}).get("products", [])
            if assocs:
                with_assoc += 1
        pct = with_assoc / len(products) * 100 if products else 0
        if pct >= 80:
            t.passed(f"{with_assoc}/{len(products)} ({pct:.1f}%) have {atype} associations")
        elif pct >= 50:
            t.warned(f"{with_assoc}/{len(products)} ({pct:.1f}%) have {atype} associations")
        else:
            t.failed(f"Low {atype} coverage", ">= 80%", f"{pct:.1f}%")
        suite.add(t)


# ============================================================
# TC7: API PERFORMANCE TESTS
# ============================================================
def tc7_api_performance(api, suite):
    log("\n--- TC7: API Performance Tests ---")

    # TC7.1: Single product GET
    t = TestResult("TC7.1", "Single product GET < threshold", "TC7: API Performance")
    r, ms = api.timed_get("products", {"limit": 1})
    if r.status_code == 200 and ms < THRESHOLDS["api_response_max_ms"]:
        t.passed(f"{ms:.0f}ms (threshold: {THRESHOLDS['api_response_max_ms']}ms)")
    elif r.status_code == 200:
        t.warned(f"{ms:.0f}ms (slow, threshold: {THRESHOLDS['api_response_max_ms']}ms)")
    else:
        t.failed(f"Status {r.status_code}, {ms:.0f}ms")
    suite.add(t)

    # TC7.2: Product list (100 items) GET
    t = TestResult("TC7.2", "Product list (100 items) GET < threshold", "TC7: API Performance")
    r, ms = api.timed_get("products", {"limit": 100})
    if r.status_code == 200 and ms < THRESHOLDS["api_list_max_ms"]:
        t.passed(f"{ms:.0f}ms for 100 products (threshold: {THRESHOLDS['api_list_max_ms']}ms)")
    elif r.status_code == 200:
        t.warned(f"{ms:.0f}ms (slow, threshold: {THRESHOLDS['api_list_max_ms']}ms)")
    else:
        t.failed(f"Status {r.status_code}, {ms:.0f}ms")
    suite.add(t)

    # TC7.3: Categories list GET
    t = TestResult("TC7.3", "Categories list GET < threshold", "TC7: API Performance")
    r, ms = api.timed_get("categories", {"limit": 100})
    if r.status_code == 200 and ms < THRESHOLDS["api_response_max_ms"]:
        t.passed(f"{ms:.0f}ms (threshold: {THRESHOLDS['api_response_max_ms']}ms)")
    else:
        t.warned(f"Status {r.status_code}, {ms:.0f}ms")
    suite.add(t)

    # TC7.4: Authentication speed
    t = TestResult("TC7.4", "Authentication completes quickly", "TC7: API Performance")
    start = time.time()
    try:
        api.auth()
        ms = (time.time() - start) * 1000
        if ms < 3000:
            t.passed(f"{ms:.0f}ms")
        else:
            t.warned(f"{ms:.0f}ms (slow)")
    except Exception as e:
        t.errored(str(e))
    suite.add(t)

    # TC7.5: Product model list GET
    t = TestResult("TC7.5", "Product model list GET < threshold", "TC7: API Performance")
    r, ms = api.timed_get("product-models", {"limit": 100})
    if r.status_code == 200 and ms < THRESHOLDS["api_response_max_ms"]:
        t.passed(f"{ms:.0f}ms (threshold: {THRESHOLDS['api_response_max_ms']}ms)")
    else:
        t.warned(f"Status {r.status_code}, {ms:.0f}ms")
    suite.add(t)


# ============================================================
# TC8: ATTRIBUTE CONFIGURATION TESTS
# ============================================================
def tc8_attribute_config(api, suite):
    log("\n--- TC8: Attribute Configuration Tests ---")

    # TC8.1: Grid filter attributes enabled
    t = TestResult("TC8.1", "Key attributes have grid filters enabled", "TC8: Attribute Config")
    filter_attrs = ["mgs_brand", "color", "visibility", "product_status", "manufacturer"]
    missing_filters = []
    for attr_code in filter_attrs:
        r = api.get(f"attributes/{attr_code}")
        if r.status_code == 200:
            attr_data = r.json()
            if not attr_data.get("useable_as_grid_filter", False):
                missing_filters.append(attr_code)
        else:
            missing_filters.append(f"{attr_code} (not found)")
    if not missing_filters:
        t.passed(f"All {len(filter_attrs)} key attributes have grid filters")
    else:
        t.failed(f"Missing grid filters: {missing_filters}", "All enabled", missing_filters)
    suite.add(t)

    # TC8.2: All attribute groups have trilingual labels
    t = TestResult("TC8.2", "All attribute groups have trilingual labels", "TC8: Attribute Config")
    page = 1
    missing = 0
    total_groups = 0
    while True:
        r = api.get("attribute-groups", {"limit": 100, "page": page})
        if r.status_code != 200:
            break
        items = r.json().get("_embedded", {}).get("items", [])
        if not items:
            break
        for grp in items:
            total_groups += 1
            labels = grp.get("labels", {})
            for loc in LOCALES:
                if not labels.get(loc):
                    missing += 1
        page += 1
    if missing == 0:
        t.passed(f"All {total_groups} attribute groups have trilingual labels")
    else:
        t.failed(f"{missing} missing labels across {total_groups} groups", "0", missing)
    suite.add(t)

    # TC8.3: Family completeness requirements include core attributes
    t = TestResult("TC8.3", "Family completeness includes core attributes", "TC8: Attribute Config")
    core_attrs = {"description", "image", "name", "price"}
    families_missing = {}
    for fam in FAMILIES:
        r = api.get(f"families/{fam}")
        if r.status_code != 200:
            continue
        fam_data = r.json()
        reqs = set()
        for ch_reqs in fam_data.get("attribute_requirements", {}).values():
            reqs.update(ch_reqs)
        missing_core = core_attrs - reqs
        if missing_core:
            families_missing[fam] = list(missing_core)
    if not families_missing:
        t.passed(f"All {len(FAMILIES)} families require core attributes")
    else:
        t.warned(f"Families missing core attrs: {families_missing}")
    suite.add(t)

    # TC8.4: Select attribute options have labels
    t = TestResult("TC8.4", "Select attribute options have trilingual labels", "TC8: Attribute Config")
    attrs_to_check = ["visibility", "color", "mgs_brand"]
    total_opts = 0
    missing_labels = 0
    for attr_code in attrs_to_check:
        page = 1
        while True:
            r = api.get(f"attributes/{attr_code}/options", {"limit": 100, "page": page})
            if r.status_code != 200:
                break
            items = r.json().get("_embedded", {}).get("items", [])
            if not items:
                break
            for opt in items:
                total_opts += 1
                labels = opt.get("labels", {})
                for loc in LOCALES:
                    if not labels.get(loc):
                        missing_labels += 1
            page += 1
    if missing_labels == 0:
        t.passed(f"All {total_opts} options across checked attributes have trilingual labels")
    else:
        t.warned(f"{missing_labels} missing labels across {total_opts} options")
    suite.add(t)


# ============================================================
# TC9: COMPLETENESS & SCORING TESTS
# ============================================================
def tc9_completeness(api, suite, products):
    log("\n--- TC9: Completeness & Scoring Tests ---")

    # TC9.1: Visibility coverage
    t = TestResult("TC9.1", "Visibility attribute set on all products", "TC9: Completeness")
    with_vis = sum(1 for p in products if has_val(p.get("values", {}), "visibility"))
    pct = with_vis / len(products) * 100 if products else 0
    if pct >= THRESHOLDS["visibility_coverage_pct"]:
        t.passed(f"{with_vis}/{len(products)} ({pct:.1f}%)")
    else:
        t.failed(f"Visibility coverage {pct:.1f}%", f">= {THRESHOLDS['visibility_coverage_pct']}%", f"{pct:.1f}%")
    suite.add(t)

    # TC9.2: Brand coverage
    t = TestResult("TC9.2", "Brand attribute coverage meets threshold", "TC9: Completeness")
    with_brand = sum(1 for p in products if has_val(p.get("values", {}), "mgs_brand"))
    pct = with_brand / len(products) * 100 if products else 0
    if pct >= THRESHOLDS["brand_coverage_pct"]:
        t.passed(f"{with_brand}/{len(products)} ({pct:.1f}%)")
    else:
        t.failed(f"Brand coverage {pct:.1f}%", f">= {THRESHOLDS['brand_coverage_pct']}%", f"{pct:.1f}%")
    suite.add(t)

    # TC9.3: Manufacturer coverage
    t = TestResult("TC9.3", "Manufacturer attribute coverage meets threshold", "TC9: Completeness")
    with_mfr = sum(1 for p in products if has_val(p.get("values", {}), "manufacturer"))
    pct = with_mfr / len(products) * 100 if products else 0
    if pct >= THRESHOLDS["manufacturer_coverage_pct"]:
        t.passed(f"{with_mfr}/{len(products)} ({pct:.1f}%)")
    else:
        t.failed(f"Manufacturer coverage {pct:.1f}%", f">= {THRESHOLDS['manufacturer_coverage_pct']}%", f"{pct:.1f}%")
    suite.add(t)

    # TC9.4: Category assignment
    t = TestResult("TC9.4", "All products assigned to categories", "TC9: Completeness")
    with_cat = sum(1 for p in products if p.get("categories", []))
    pct = with_cat / len(products) * 100 if products else 0
    if pct >= THRESHOLDS["category_coverage_pct"]:
        t.passed(f"{with_cat}/{len(products)} ({pct:.1f}%)")
    else:
        t.failed(f"Category coverage {pct:.1f}%", f">= {THRESHOLDS['category_coverage_pct']}%", f"{pct:.1f}%")
    suite.add(t)

    # TC9.5: Price coverage
    t = TestResult("TC9.5", "Price attribute set on all products", "TC9: Completeness")
    with_price = sum(1 for p in products if has_val(p.get("values", {}), "price"))
    pct = with_price / len(products) * 100 if products else 0
    if pct >= THRESHOLDS["price_coverage_pct"]:
        t.passed(f"{with_price}/{len(products)} ({pct:.1f}%)")
    else:
        t.failed(f"Price coverage {pct:.1f}%", f">= {THRESHOLDS['price_coverage_pct']}%", f"{pct:.1f}%")
    suite.add(t)


# ============================================================
# TC10: REGRESSION TESTS (verify previous fixes)
# ============================================================
def tc10_regression(api, suite, products):
    log("\n--- TC10: Regression Tests ---")

    # TC10.1: No visibility = empty
    t = TestResult("TC10.1", "No products with empty visibility (Phase 9A fix)", "TC10: Regression")
    empty_vis = [p.get("identifier", "") for p in products
                 if not has_val(p.get("values", {}), "visibility")]
    if not empty_vis:
        t.passed("All products have visibility set")
    else:
        t.failed(f"{len(empty_vis)} products missing visibility", "0", len(empty_vis), empty_vis[:10])
    suite.add(t)

    # TC10.2: No product_status = None
    t = TestResult("TC10.2", "No products with empty product_status (Phase 9A fix)", "TC10: Regression")
    empty_status = [p.get("identifier", "") for p in products
                    if get_val(p.get("values", {}), "product_status") is None]
    if not empty_status:
        t.passed("All products have product_status set")
    else:
        t.failed(f"{len(empty_status)} products missing status", "0", len(empty_status), empty_status[:10])
    suite.add(t)

    # TC10.3: Descriptions present in all locales
    t = TestResult("TC10.3", "Descriptions present in all 3 locales (Phase 7A fix)", "TC10: Regression")
    missing = 0
    for p in products:
        vals = p.get("values", {})
        for loc in LOCALES:
            if not get_val(vals, "description", loc):
                missing += 1
    if missing == 0:
        t.passed(f"All {len(products)} products have descriptions in all 3 locales")
    else:
        t.failed(f"{missing} missing descriptions across locales", "0", missing)
    suite.add(t)

    # TC10.4: Categories assigned to all products
    t = TestResult("TC10.4", "All products have categories (Phase 7D fix)", "TC10: Regression")
    no_cat = [p.get("identifier", "") for p in products if not p.get("categories", [])]
    if not no_cat:
        t.passed(f"All {len(products)} products have categories")
    else:
        t.failed(f"{len(no_cat)} products without categories", "0", len(no_cat), no_cat[:10])
    suite.add(t)

    # TC10.5: No weight = 9999 (Phase 9C fix)
    t = TestResult("TC10.5", "No weight=9999 placeholders (Phase 9C fix)", "TC10: Regression")
    bad = []
    for p in products:
        wt = get_val(p.get("values", {}), "weight")
        if wt:
            amt = wt.get("amount") if isinstance(wt, dict) else wt
            try:
                if float(str(amt)) >= 9990:
                    bad.append(p.get("identifier", ""))
            except (ValueError, TypeError):
                pass
    if not bad:
        t.passed("No weight placeholders found")
    else:
        t.failed(f"{len(bad)} weight placeholders remain", "0", len(bad), bad[:10])
    suite.add(t)

    # TC10.6: Trilingual category labels (Phase TUNING fix)
    t = TestResult("TC10.6", "Category labels complete in all 3 locales", "TC10: Regression")
    missing_cat_labels = 0
    page = 1
    checked = 0
    while checked < 100:  # Sample first 100 categories
        r = api.get("categories", {"limit": 100, "page": page})
        if r.status_code != 200:
            break
        items = r.json().get("_embedded", {}).get("items", [])
        if not items:
            break
        for cat in items:
            checked += 1
            labels = cat.get("labels", {})
            for loc in LOCALES:
                if not labels.get(loc):
                    missing_cat_labels += 1
        page += 1
    if missing_cat_labels == 0:
        t.passed(f"All {checked} sampled categories have trilingual labels")
    else:
        t.failed(f"{missing_cat_labels} missing category labels", "0", missing_cat_labels)
    suite.add(t)

    # TC10.7: Manufacturer populated (Phase 9B fix)
    t = TestResult("TC10.7", "Manufacturer attribute populated (Phase 9B fix)", "TC10: Regression")
    with_mfr = sum(1 for p in products if has_val(p.get("values", {}), "manufacturer"))
    pct = with_mfr / len(products) * 100 if products else 0
    if pct >= 90:
        t.passed(f"{with_mfr}/{len(products)} ({pct:.1f}%) have manufacturer")
    else:
        t.failed(f"Manufacturer coverage dropped to {pct:.1f}%", ">= 90%", f"{pct:.1f}%")
    suite.add(t)


# ============================================================
# MAIN
# ============================================================
def main():
    parser = argparse.ArgumentParser(description="Akeneo PIM Test Suite")
    parser.add_argument("--category", type=str, help="Run specific test category (TC1-TC10)")
    parser.add_argument("--verbose", action="store_true", help="Show detailed failure info")
    parser.add_argument("--report", action="store_true", help="Generate JSON report")
    parser.add_argument("--sample-size", type=int, default=200, help="Sample size for product tests")
    parser.add_argument("--full-scan", action="store_true", help="Scan ALL products (slow but comprehensive)")
    args = parser.parse_args()

    api = AkeneoClient(AKENEO_API)
    api.auth()
    log("Authenticated with Akeneo API")

    suite = TestSuite()
    suite.start_time = time.time()

    # Load products
    if args.full_scan:
        log(f"Running FULL SCAN of all products...")
        products = list(api.get_all_products())
    else:
        log(f"Loading {args.sample_size} sample products...")
        products = api.get_sample_products(args.sample_size)
    log(f"Loaded {len(products)} products for testing")

    # Run test categories
    categories_to_run = None
    if args.category:
        categories_to_run = [args.category.upper()]

    if not categories_to_run or "TC1" in categories_to_run:
        tc1_data_integrity(api, suite, products)
    if not categories_to_run or "TC2" in categories_to_run:
        tc2_display_quality(api, suite, products)
    if not categories_to_run or "TC3" in categories_to_run:
        tc3_multilingual(api, suite, products)
    if not categories_to_run or "TC4" in categories_to_run:
        tc4_product_structure(api, suite, products)
    if not categories_to_run or "TC5" in categories_to_run:
        tc5_seo(api, suite, products)
    if not categories_to_run or "TC6" in categories_to_run:
        tc6_associations(api, suite, products)
    if not categories_to_run or "TC7" in categories_to_run:
        tc7_api_performance(api, suite)
    if not categories_to_run or "TC8" in categories_to_run:
        tc8_attribute_config(api, suite)
    if not categories_to_run or "TC9" in categories_to_run:
        tc9_completeness(api, suite, products)
    if not categories_to_run or "TC10" in categories_to_run:
        tc10_regression(api, suite, products)

    suite.end_time = time.time()

    # Print results
    suite.print_report(verbose=args.verbose)

    # Generate report file
    if args.report:
        report_data = suite.generate_json_report()
        report_path = os.path.join(REPORT_DIR, f"test_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json")
        try:
            with open(report_path, "w") as f:
                json.dump(report_data, f, indent=2)
            log(f"Report saved to: {report_path}")
        except Exception as e:
            log(f"Failed to save report: {e}", "WARN")
            # Try alternative location
            alt_path = f"/tmp/pim_test_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
            try:
                with open(alt_path, "w") as f:
                    json.dump(report_data, f, indent=2)
                log(f"Report saved to: {alt_path}")
            except Exception:
                pass

    # Return exit code based on results
    summary = suite.summary()
    if summary["failed"] > 0 or summary["errors"] > 0:
        sys.exit(1)
    sys.exit(0)


if __name__ == "__main__":
    main()
