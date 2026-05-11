#!/usr/bin/env python3
"""
Beta Catalog Full Audit Script
================================
Comprehensive audit of the Magento beta catalog covering:
1. Attributes - types, usage, optimization opportunities
2. Attribute Sets (Families) - structure, overlap, consolidation
3. Categories - hierarchy, empty nodes, SEO coverage
4. SEO - meta field fill rates, quality analysis
5. Data Quality - missing values, duplicates, consistency
"""

import sys, os, json, re
import mysql.connector
import requests
from datetime import datetime
from collections import defaultdict

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

REPORT = []

def section(title):
    REPORT.append("\n" + "=" * 70)
    REPORT.append("  %s" % title)
    REPORT.append("=" * 70)

def line(text=""):
    REPORT.append(text)

def get_akeneo_token():
    r = requests.post(AKENEO_API["base_url"] + "/api/oauth/v1/token", data={
        "grant_type": "password", "client_id": AKENEO_API["client_id"],
        "client_secret": AKENEO_API["client_secret"],
        "username": AKENEO_API["username"], "password": AKENEO_API["password"],
    })
    return r.json().get("access_token") if r.status_code == 200 else None

def main():
    conn = mysql.connector.connect(**MAGENTO_DB)
    cur = conn.cursor(dictionary=True)

    REPORT.append("=" * 70)
    REPORT.append("  BETA CATALOG FULL AUDIT REPORT")
    REPORT.append("  Generated: %s" % datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
    REPORT.append("  Database: %s" % MAGENTO_DB["database"])
    REPORT.append("=" * 70)

    # ================================================================
    # 1. OVERVIEW
    # ================================================================
    section("1. CATALOG OVERVIEW")

    cur.execute("SELECT COUNT(*) AS c FROM catalog_product_entity")
    total_products = cur.fetchone()["c"]
    cur.execute("SELECT COUNT(*) AS c FROM catalog_product_entity WHERE type_id='simple'")
    simple = cur.fetchone()["c"]
    cur.execute("SELECT COUNT(*) AS c FROM catalog_product_entity WHERE type_id='configurable'")
    configurable = cur.fetchone()["c"]
    cur.execute("SELECT COUNT(*) AS c FROM catalog_product_entity WHERE type_id NOT IN ('simple','configurable')")
    other_types = cur.fetchone()["c"]
    cur.execute("SELECT COUNT(*) AS c FROM catalog_category_entity WHERE level >= 2")
    total_cats = cur.fetchone()["c"]
    cur.execute("SELECT COUNT(DISTINCT attribute_set_id) AS c FROM eav_attribute_set WHERE entity_type_id=4")
    total_sets = cur.fetchone()["c"]

    line("  Total Products:    %d" % total_products)
    line("    - Simple:        %d" % simple)
    line("    - Configurable:  %d" % configurable)
    line("    - Other:         %d" % other_types)
    line("  Total Categories:  %d" % total_cats)
    line("  Attribute Sets:    %d" % total_sets)

    # ================================================================
    # 2. ATTRIBUTE AUDIT
    # ================================================================
    section("2. ATTRIBUTE AUDIT")

    cur.execute("""
        SELECT a.attribute_code, a.frontend_input, a.backend_type,
               a.is_required, a.is_user_defined,
               COALESCE(
                 (SELECT COUNT(DISTINCT v.entity_id) FROM catalog_product_entity_varchar v
                  WHERE v.attribute_id = a.attribute_id AND v.value IS NOT NULL AND v.value != ''),
                 0
               ) AS varchar_usage,
               COALESCE(
                 (SELECT COUNT(DISTINCT v.entity_id) FROM catalog_product_entity_int v
                  WHERE v.attribute_id = a.attribute_id AND v.value IS NOT NULL),
                 0
               ) AS int_usage,
               COALESCE(
                 (SELECT COUNT(DISTINCT v.entity_id) FROM catalog_product_entity_decimal v
                  WHERE v.attribute_id = a.attribute_id AND v.value IS NOT NULL),
                 0
               ) AS decimal_usage,
               COALESCE(
                 (SELECT COUNT(DISTINCT v.entity_id) FROM catalog_product_entity_text v
                  WHERE v.attribute_id = a.attribute_id AND v.value IS NOT NULL AND v.value != ''),
                 0
               ) AS text_usage
        FROM eav_attribute a
        WHERE a.entity_type_id = 4
          AND a.attribute_code NOT IN ('entity_id','attribute_set_id','type_id','created_at','updated_at',
                                        'has_options','required_options','created_in','updated_in')
        ORDER BY a.attribute_code
    """)
    attrs = cur.fetchall()

    line("\n  %-25s %-12s %-8s %-10s %-6s" % ("Attribute", "Input Type", "Backend", "Fill Rate", "Used"))
    line("  " + "-" * 65)

    unused_attrs = []
    low_usage_attrs = []
    select_attrs = []
    text_attrs = []

    for a in attrs:
        code = a["attribute_code"]
        usage = max(a["varchar_usage"], a["int_usage"], a["decimal_usage"], a["text_usage"])
        pct = (usage / total_products * 100) if total_products > 0 else 0
        fill = "%d/%d (%.0f%%)" % (usage, total_products, pct)

        if usage == 0:
            unused_attrs.append(code)
            marker = "UNUSED"
        elif pct < 10:
            low_usage_attrs.append((code, pct))
            marker = "LOW"
        else:
            marker = "OK"

        fi = (a["frontend_input"] or "n/a")[:12]
        bt = (a["backend_type"] or "n/a")[:8]
        line("  %-25s %-12s %-8s %-10s %-6s" % (code[:25], fi, bt, fill, marker))

        if a["frontend_input"] == "select":
            select_attrs.append(code)
        if a["frontend_input"] == "textarea":
            text_attrs.append(code)

    line("\n  SUMMARY:")
    line("  Total Attributes: %d" % len(attrs))
    line("  Unused (0 values): %d" % len(unused_attrs))
    if unused_attrs:
        line("    -> %s" % ", ".join(unused_attrs[:20]))
    line("  Low Usage (<10%%): %d" % len(low_usage_attrs))
    if low_usage_attrs:
        for code, pct in low_usage_attrs[:10]:
            line("    -> %s (%.1f%%)" % (code, pct))
    line("  Select Attributes: %d" % len(select_attrs))
    line("  Text/Textarea Attributes: %d" % len(text_attrs))

    # ================================================================
    # 3. ATTRIBUTE SETS AUDIT
    # ================================================================
    section("3. ATTRIBUTE SETS (FAMILIES) AUDIT")

    cur.execute("""
        SELECT s.attribute_set_id, s.attribute_set_name,
               COUNT(DISTINCT ea.attribute_id) AS attr_count,
               (SELECT COUNT(*) FROM catalog_product_entity p WHERE p.attribute_set_id = s.attribute_set_id) AS product_count
        FROM eav_attribute_set s
        LEFT JOIN eav_entity_attribute ea ON s.attribute_set_id = ea.attribute_set_id
        WHERE s.entity_type_id = 4
        GROUP BY s.attribute_set_id, s.attribute_set_name
        ORDER BY product_count DESC
    """)
    attr_sets = cur.fetchall()

    line("\n  %-20s %-8s %-10s %-40s" % ("Attribute Set", "Attrs", "Products", "Status"))
    line("  " + "-" * 80)

    empty_sets = []
    for s in attr_sets:
        status = ""
        if s["product_count"] == 0:
            empty_sets.append(s["attribute_set_name"])
            status = "EMPTY - can remove"
        elif s["product_count"] < 10:
            status = "LOW usage - consider merge"
        line("  %-20s %-8d %-10d %-40s" % (s["attribute_set_name"][:20], s["attr_count"], s["product_count"], status))

    line("\n  Empty Sets (no products): %d" % len(empty_sets))
    if empty_sets:
        line("    -> %s" % ", ".join(empty_sets))

    # Attribute overlap between sets
    line("\n  ATTRIBUTE OVERLAP ANALYSIS:")
    cur.execute("""
        SELECT s1.attribute_set_name AS set1, s2.attribute_set_name AS set2,
               COUNT(*) AS shared_attrs
        FROM eav_entity_attribute ea1
        JOIN eav_entity_attribute ea2 ON ea1.attribute_id = ea2.attribute_id AND ea1.attribute_set_id < ea2.attribute_set_id
        JOIN eav_attribute_set s1 ON ea1.attribute_set_id = s1.attribute_set_id
        JOIN eav_attribute_set s2 ON ea2.attribute_set_id = s2.attribute_set_id
        WHERE s1.entity_type_id = 4 AND s2.entity_type_id = 4
        GROUP BY s1.attribute_set_name, s2.attribute_set_name
        HAVING shared_attrs > 20
        ORDER BY shared_attrs DESC
        LIMIT 15
    """)
    overlaps = cur.fetchall()
    for o in overlaps:
        line("  %-15s <-> %-15s: %d shared attributes" % (o["set1"][:15], o["set2"][:15], o["shared_attrs"]))

    # ================================================================
    # 4. CATEGORIES AUDIT
    # ================================================================
    section("4. CATEGORIES AUDIT")

    cur.execute("""
        SELECT e.entity_id, e.parent_id, e.level, e.path,
               v.value AS name,
               (SELECT COUNT(*) FROM catalog_category_product cp WHERE cp.category_id = e.entity_id) AS product_count
        FROM catalog_category_entity e
        LEFT JOIN catalog_category_entity_varchar v ON e.entity_id = v.entity_id
            AND v.attribute_id = (SELECT attribute_id FROM eav_attribute WHERE attribute_code='name' AND entity_type_id=3)
            AND v.store_id = 0
        WHERE e.level >= 1
        ORDER BY e.level, e.position
    """)
    categories = cur.fetchall()

    level_counts = defaultdict(int)
    empty_cats = []
    oversized_cats = []
    duplicate_names = defaultdict(list)

    for c in categories:
        level_counts[c["level"]] += 1
        if c["level"] >= 2:
            if c["product_count"] == 0:
                empty_cats.append(c)
            if c["product_count"] > 500:
                oversized_cats.append(c)
            if c["name"]:
                duplicate_names[c["name"].strip().lower()].append(c)

    line("\n  CATEGORY DEPTH DISTRIBUTION:")
    for lvl in sorted(level_counts.keys()):
        line("    Level %d: %d categories" % (lvl, level_counts[lvl]))

    line("\n  Total Categories (level 2+): %d" % sum(v for k, v in level_counts.items() if k >= 2))
    line("  Empty Categories (no products): %d" % len(empty_cats))
    if empty_cats:
        line("  Top 15 empty categories:")
        for c in empty_cats[:15]:
            line("    -> [L%d] %s (id=%d)" % (c["level"], c["name"] or "unnamed", c["entity_id"]))

    line("\n  Oversized Categories (>500 products): %d" % len(oversized_cats))
    for c in oversized_cats:
        line("    -> %s: %d products" % (c["name"][:40], c["product_count"]))

    # Duplicate category names
    dupes = {k: v for k, v in duplicate_names.items() if len(v) > 1}
    line("\n  Duplicate Category Names: %d" % len(dupes))
    for name, cats in sorted(dupes.items(), key=lambda x: -len(x[1]))[:15]:
        line("    -> '%s' x%d (levels: %s)" % (name[:40], len(cats), ",".join(str(c["level"]) for c in cats)))

    # ================================================================
    # 5. SEO AUDIT
    # ================================================================
    section("5. SEO & METADATA AUDIT")

    seo_fields = [
        ("meta_title", "varchar", "Critical - page title tag"),
        ("meta_description", "varchar", "Critical - search snippet"),
        ("meta_keyword", "text", "Low priority - deprecated by Google"),
        ("url_key", "varchar", "Critical - URL slug"),
        ("description", "text", "Important - product detail page"),
        ("short_description", "text", "Important - catalog listing"),
        ("name", "varchar", "Critical - product identification"),
    ]

    line("\n  %-20s %-12s %-14s %-30s" % ("Field", "Fill Count", "Fill Rate", "Priority"))
    line("  " + "-" * 80)

    seo_issues = []
    for field, backend, priority in seo_fields:
        table = "catalog_product_entity_%s" % backend
        cur.execute("""
            SELECT COUNT(DISTINCT v.entity_id) AS filled
            FROM %s v
            JOIN eav_attribute a ON v.attribute_id = a.attribute_id
            WHERE a.attribute_code = '%s' AND a.entity_type_id = 4
              AND v.value IS NOT NULL AND v.value != ''
        """ % (table, field))
        filled = cur.fetchone()["filled"]
        pct = (filled / total_products * 100) if total_products > 0 else 0
        status = "OK" if pct >= 80 else ("LOW" if pct >= 40 else "CRITICAL")
        line("  %-20s %-12d %5.1f%%  %-6s %-30s" % (field, filled, pct, status, priority))

        if pct < 80 and "Critical" in priority:
            seo_issues.append((field, pct))

    # SEO quality checks
    line("\n  SEO QUALITY CHECKS:")

    # Meta title length
    cur.execute("""
        SELECT
          SUM(CASE WHEN LENGTH(v.value) < 30 THEN 1 ELSE 0 END) AS too_short,
          SUM(CASE WHEN LENGTH(v.value) BETWEEN 30 AND 60 THEN 1 ELSE 0 END) AS optimal,
          SUM(CASE WHEN LENGTH(v.value) > 60 THEN 1 ELSE 0 END) AS too_long,
          COUNT(*) AS total
        FROM catalog_product_entity_varchar v
        JOIN eav_attribute a ON v.attribute_id = a.attribute_id
        WHERE a.attribute_code = 'meta_title' AND a.entity_type_id = 4
          AND v.value IS NOT NULL AND v.value != '' AND v.store_id = 0
    """)
    mt = cur.fetchone()
    if mt and mt["total"]:
        line("  Meta Title Length Distribution:")
        line("    Too Short (<30): %d (%.0f%%)" % (mt["too_short"], mt["too_short"]/mt["total"]*100))
        line("    Optimal (30-60): %d (%.0f%%)" % (mt["optimal"], mt["optimal"]/mt["total"]*100))
        line("    Too Long (>60):  %d (%.0f%%)" % (mt["too_long"], mt["too_long"]/mt["total"]*100))

    # Meta description length
    cur.execute("""
        SELECT
          SUM(CASE WHEN LENGTH(v.value) < 70 THEN 1 ELSE 0 END) AS too_short,
          SUM(CASE WHEN LENGTH(v.value) BETWEEN 70 AND 160 THEN 1 ELSE 0 END) AS optimal,
          SUM(CASE WHEN LENGTH(v.value) > 160 THEN 1 ELSE 0 END) AS too_long,
          COUNT(*) AS total
        FROM catalog_product_entity_varchar v
        JOIN eav_attribute a ON v.attribute_id = a.attribute_id
        WHERE a.attribute_code = 'meta_description' AND a.entity_type_id = 4
          AND v.value IS NOT NULL AND v.value != '' AND v.store_id = 0
    """)
    md = cur.fetchone()
    if md and md["total"]:
        line("  Meta Description Length Distribution:")
        line("    Too Short (<70):   %d (%.0f%%)" % (md["too_short"], md["too_short"]/md["total"]*100))
        line("    Optimal (70-160):  %d (%.0f%%)" % (md["optimal"], md["optimal"]/md["total"]*100))
        line("    Too Long (>160):   %d (%.0f%%)" % (md["too_long"], md["too_long"]/md["total"]*100))

    # Duplicate meta titles
    cur.execute("""
        SELECT COUNT(*) AS dupes FROM (
            SELECT v.value, COUNT(DISTINCT v.entity_id) AS cnt
            FROM catalog_product_entity_varchar v
            JOIN eav_attribute a ON v.attribute_id = a.attribute_id
            WHERE a.attribute_code = 'meta_title' AND a.entity_type_id = 4
              AND v.value IS NOT NULL AND v.value != '' AND v.store_id = 0
            GROUP BY v.value HAVING cnt > 1
        ) t
    """)
    dupe_titles = cur.fetchone()["dupes"]
    line("  Duplicate Meta Titles: %d groups" % dupe_titles)

    # Duplicate URL keys
    cur.execute("""
        SELECT COUNT(*) AS dupes FROM (
            SELECT v.value, COUNT(DISTINCT v.entity_id) AS cnt
            FROM catalog_product_entity_varchar v
            JOIN eav_attribute a ON v.attribute_id = a.attribute_id
            WHERE a.attribute_code = 'url_key' AND a.entity_type_id = 4
              AND v.value IS NOT NULL AND v.value != '' AND v.store_id = 0
            GROUP BY v.value HAVING cnt > 1
        ) t
    """)
    dupe_urls = cur.fetchone()["dupes"]
    line("  Duplicate URL Keys: %d groups" % dupe_urls)

    # ================================================================
    # 6. SELECT ATTRIBUTE OPTIONS AUDIT
    # ================================================================
    section("6. SELECT ATTRIBUTE OPTIONS AUDIT")

    cur.execute("""
        SELECT a.attribute_code,
               COUNT(DISTINCT o.option_id) AS option_count
        FROM eav_attribute a
        JOIN eav_attribute_option o ON a.attribute_id = o.attribute_id
        WHERE a.entity_type_id = 4 AND a.frontend_input = 'select'
        GROUP BY a.attribute_code
        ORDER BY option_count DESC
    """)
    select_options = cur.fetchall()

    line("\n  %-20s %-12s %-40s" % ("Attribute", "Options", "Status"))
    line("  " + "-" * 75)
    for s in select_options:
        status = ""
        if s["option_count"] > 200:
            status = "HIGH - consider cleanup/consolidation"
        elif s["option_count"] > 50:
            status = "moderate"
        line("  %-20s %-12d %-40s" % (s["attribute_code"][:20], s["option_count"], status))

    # Check for unused options
    line("\n  UNUSED OPTION CHECK (top attrs):")
    for attr in ["color", "pattern", "dimension", "capacity"]:
        cur.execute("""
            SELECT COUNT(*) AS unused FROM (
                SELECT o.option_id
                FROM eav_attribute_option o
                JOIN eav_attribute a ON o.attribute_id = a.attribute_id
                WHERE a.attribute_code = '%s' AND a.entity_type_id = 4
                AND o.option_id NOT IN (
                    SELECT DISTINCT v.value FROM catalog_product_entity_int v
                    WHERE v.attribute_id = a.attribute_id AND v.value IS NOT NULL
                )
            ) t
        """ % attr)
        row = cur.fetchone()
        if row:
            line("    %s: %d unused options" % (attr, row["unused"]))

    # ================================================================
    # 7. DATA QUALITY AUDIT
    # ================================================================
    section("7. DATA QUALITY AUDIT")

    # Products without names
    cur.execute("""
        SELECT COUNT(*) AS c FROM catalog_product_entity p
        WHERE NOT EXISTS (
            SELECT 1 FROM catalog_product_entity_varchar v
            JOIN eav_attribute a ON v.attribute_id = a.attribute_id
            WHERE a.attribute_code = 'name' AND a.entity_type_id = 4
              AND v.entity_id = p.entity_id AND v.value IS NOT NULL AND v.value != ''
        )
    """)
    no_name = cur.fetchone()["c"]
    line("  Products without name: %d" % no_name)

    # Products without price
    cur.execute("""
        SELECT COUNT(*) AS c FROM catalog_product_entity p
        WHERE NOT EXISTS (
            SELECT 1 FROM catalog_product_entity_decimal v
            JOIN eav_attribute a ON v.attribute_id = a.attribute_id
            WHERE a.attribute_code = 'price' AND a.entity_type_id = 4
              AND v.entity_id = p.entity_id AND v.value IS NOT NULL
        )
    """)
    no_price = cur.fetchone()["c"]
    line("  Products without price: %d" % no_price)

    # Products without categories
    cur.execute("""
        SELECT COUNT(*) AS c FROM catalog_product_entity p
        WHERE NOT EXISTS (
            SELECT 1 FROM catalog_category_product cp WHERE cp.product_id = p.entity_id
        )
    """)
    no_cat = cur.fetchone()["c"]
    line("  Products without categories: %d" % no_cat)

    # Disabled products
    cur.execute("""
        SELECT COUNT(*) AS c FROM catalog_product_entity_int v
        JOIN eav_attribute a ON v.attribute_id = a.attribute_id
        WHERE a.attribute_code = 'status' AND a.entity_type_id = 4
          AND v.store_id = 0 AND v.value = 2
    """)
    disabled = cur.fetchone()["c"]
    line("  Disabled products: %d (%.0f%%)" % (disabled, disabled/total_products*100 if total_products else 0))

    # Visibility analysis
    cur.execute("""
        SELECT v.value, COUNT(*) AS cnt
        FROM catalog_product_entity_int v
        JOIN eav_attribute a ON v.attribute_id = a.attribute_id
        WHERE a.attribute_code = 'visibility' AND a.entity_type_id = 4 AND v.store_id = 0
        GROUP BY v.value ORDER BY v.value
    """)
    vis = cur.fetchall()
    vis_labels = {1: "Not Visible", 2: "Catalog", 3: "Search", 4: "Catalog & Search"}
    line("\n  Visibility Distribution:")
    for v in vis:
        label = vis_labels.get(v["value"], "Unknown(%d)" % v["value"])
        line("    %s: %d" % (label, v["cnt"]))

    # ================================================================
    # 8. AKENEO COMPARISON
    # ================================================================
    section("8. AKENEO PIM COMPARISON")

    token = get_akeneo_token()
    if token:
        headers = {"Authorization": "Bearer " + token}
        base = AKENEO_API["base_url"]

        # Products count
        r = requests.get(base + "/api/rest/v1/products?limit=1", headers=headers)
        ak_prods = 0
        if r.status_code == 200:
            # Akeneo doesn't give total count easily, use items_count if available
            ak_prods = r.json().get("items_count", len(r.json().get("_embedded", {}).get("items", [])))

        # Families
        r = requests.get(base + "/api/rest/v1/families?limit=100", headers=headers)
        ak_fams = r.json().get("_embedded", {}).get("items", []) if r.status_code == 200 else []

        # Attributes
        r = requests.get(base + "/api/rest/v1/attributes?limit=100", headers=headers)
        ak_attrs = r.json().get("_embedded", {}).get("items", []) if r.status_code == 200 else []

        # Categories
        r = requests.get(base + "/api/rest/v1/categories?limit=1", headers=headers)
        ak_cats_count = r.json().get("items_count", 0) if r.status_code == 200 else 0

        line("\n  %-25s %-15s %-15s %-10s" % ("", "Magento Beta", "Akeneo PIM", "Gap"))
        line("  " + "-" * 70)
        line("  %-25s %-15d %-15d %-10s" % ("Products", total_products, ak_prods, "%+d" % (ak_prods - total_products)))
        line("  %-25s %-15d %-15d %-10s" % ("Categories", total_cats, ak_cats_count, "%+d" % (ak_cats_count - total_cats)))
        line("  %-25s %-15d %-15d %-10s" % ("Attr Sets / Families", total_sets, len(ak_fams), "%+d" % (len(ak_fams) - total_sets)))
        line("  %-25s %-15d %-15d %-10s" % ("Attributes (user-defined)", len(attrs), len(ak_attrs), "%+d" % (len(ak_attrs) - len(attrs))))

        line("\n  Akeneo Families:")
        for f in ak_fams:
            label = f.get("labels", {}).get("en_US", f["code"])
            attrs_count = len(f.get("attributes", []))
            line("    -> %s: %d attributes" % (label, attrs_count))

        line("\n  Akeneo Attribute Groups:")
        r = requests.get(base + "/api/rest/v1/attribute-groups?limit=100", headers=headers)
        if r.status_code == 200:
            groups = r.json().get("_embedded", {}).get("items", [])
            for g in groups:
                label = g.get("labels", {}).get("en_US", g["code"])
                attrs_in = len(g.get("attributes", []))
                line("    -> %s: %d attributes" % (label, attrs_in))

    # ================================================================
    # 9. OPTIMIZATION RECOMMENDATIONS
    # ================================================================
    section("9. OPTIMIZATION RECOMMENDATIONS")

    line("\n  PRIORITY 1 - IMMEDIATE FIXES:")
    if seo_issues:
        for field, pct in seo_issues:
            line("  [SEO] Fill '%s' for all products (currently %.0f%%)" % (field, pct))
    if no_name > 0:
        line("  [DATA] Fix %d products without names" % no_name)
    if no_price > 0:
        line("  [DATA] Fix %d products without prices" % no_price)
    if dupe_urls > 0:
        line("  [SEO] Fix %d duplicate URL keys" % dupe_urls)

    line("\n  PRIORITY 2 - ATTRIBUTE OPTIMIZATION:")
    if unused_attrs:
        line("  [ATTRS] Remove %d unused attributes:" % len(unused_attrs))
        line("    -> %s" % ", ".join(unused_attrs[:10]))
    if empty_sets:
        line("  [SETS] Remove %d empty attribute sets:" % len(empty_sets))
        line("    -> %s" % ", ".join(empty_sets))

    line("\n  PRIORITY 3 - CATEGORY OPTIMIZATION:")
    line("  [CATS] Clean up %d empty categories" % len(empty_cats))
    line("  [CATS] Consolidate %d duplicate category name groups" % len(dupes))

    line("\n  PRIORITY 4 - SEO OPTIMIZATION (via Akeneo):")
    line("  [SEO] Auto-generate meta_title from product name + brand")
    line("  [SEO] Auto-generate meta_description from short_description")
    line("  [SEO] Ensure all URL keys are unique and SEO-friendly")
    line("  [SEO] Set up Akeneo rules for enforcing SEO field completion")

    line("\n  PRIORITY 5 - LATER PHASE AKENEO ENHANCEMENTS:")
    line("  [PIM] Configure data quality rules for completeness scoring")
    line("  [PIM] Set up product models for configurable products")
    line("  [PIM] Implement multi-locale support (en_US, fr_FR, ar_DZ)")
    line("  [PIM] Configure channel-specific attribute requirements")
    line("  [PIM] Enable Data Quality Insights for automated scoring")
    line("  [PIM] Set up import/export profiles for automated sync")

    # ================================================================
    # FINISH
    # ================================================================
    cur.close()
    conn.close()

    report_text = "\n".join(REPORT)
    print(report_text)

    # Save report
    report_path = "/home/pim/public_html/webapp/AUDIT_REPORT_%s.txt" % datetime.now().strftime("%Y%m%d_%H%M%S")
    with open(report_path, "w") as f:
        f.write(report_text)
    print("\n[Report saved to %s]" % report_path)

    return report_text


if __name__ == "__main__":
    main()
