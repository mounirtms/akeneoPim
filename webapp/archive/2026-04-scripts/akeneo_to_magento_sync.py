#!/usr/bin/env python3
"""
Akeneo PIM → Magento 2 Reverse Sync Script
============================================
Exports product data from Akeneo PIM and pushes changes back to Magento 2.
Designed for bidirectional sync after PIM becomes the source of truth.

Usage:
  python3 /home/pim/public_html/webapp/akeneo_to_magento_sync.py --products [--limit N] [--dry-run]
  python3 /home/pim/public_html/webapp/akeneo_to_magento_sync.py --categories [--dry-run]
  python3 /home/pim/public_html/webapp/akeneo_to_magento_sync.py --all [--dry-run]

Options:
  --dry-run    Show what would be synced without making changes
  --limit N    Limit number of items to sync
  --since H    Only sync items modified in the last H hours (default: 24)
"""

import sys
import os
import json
import re
import time
import argparse
import mysql.connector
import requests
from datetime import datetime, timedelta

# === Configuration ===
MAGENTO_DB = {
    "host": "127.0.0.1",
    "port": 3307,
    "user": "root",
    "password": "YourNewStrongPassword",
    "database": "beta_dBT8x12y22",
    "ssl_disabled": True,
}

AKENEO_API = {
    "base_url": "https://pim.technostationery.com",
    "client_id": "1_3yhbczkw7osgcw8wg44k84os4sc04w4wc80ks08sw8cc8c40sw",
    "client_secret": "50vx3l4u4l4wwcsok4kcwkoo44oo0s0o8s0kcs0gc0c8g0oow4",
    "username": "admin",
    "password": "PimAdmin2026!",
}

PIM_CHANNEL = "ecommerce"
PIM_LOCALE = "en_US"
PIM_CURRENCY = "DZD"

LOG_FILE = "/home/pim/public_html/var/logs/akeneo_to_magento_sync.log"

# === Logging ===
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


# === Akeneo API Client ===
class AkeneoClient:
    def __init__(self, config):
        self.base_url = config["base_url"].rstrip("/")
        self.config = config
        self.token = None
        self.refresh_token = None

    def authenticate(self):
        r = requests.post(
            "%s/api/oauth/v1/token" % self.base_url,
            data={
                "grant_type": "password",
                "client_id": self.config["client_id"],
                "client_secret": self.config["client_secret"],
                "username": self.config["username"],
                "password": self.config["password"],
            },
        )
        if r.status_code != 200:
            log("Auth failed: %d %s" % (r.status_code, r.text[:200]), "ERROR")
            sys.exit(1)
        data = r.json()
        self.token = data["access_token"]
        self.refresh_token = data.get("refresh_token")
        log("Authenticated with Akeneo API")

    def headers(self):
        return {"Authorization": "Bearer %s" % self.token}

    def get_all(self, endpoint, params=None):
        """Paginate through all results from an API endpoint."""
        items = []
        url = "%s/api/rest/v1/%s" % (self.base_url, endpoint)
        if params is None:
            params = {}
        params.setdefault("limit", 100)

        while url:
            r = requests.get(url, headers=self.headers(), params=params)
            if r.status_code == 401:
                self.authenticate()
                r = requests.get(url, headers=self.headers(), params=params)
            if r.status_code != 200:
                log("GET %s => %d" % (url, r.status_code), "ERROR")
                break
            data = r.json()
            embedded = data.get("_embedded", {}).get("items", [])
            items.extend(embedded)
            # Follow next page
            next_link = data.get("_links", {}).get("next", {}).get("href")
            url = next_link
            params = {}  # params are in the next URL already
        return items

    def get_products_updated_since(self, since_dt):
        """Get products updated after a specific datetime."""
        search = json.dumps({
            "updated": [{"operator": ">", "value": since_dt.strftime("%Y-%m-%d %H:%M:%S")}]
        })
        return self.get_all("products", {"search": search})


# === Magento DB Writer ===
class MagentoWriter:
    def __init__(self, config):
        self.config = config
        self.conn = None

    def connect(self):
        self.conn = mysql.connector.connect(**self.config)
        log("Connected to Magento DB: %s" % self.config["database"])

    def close(self):
        if self.conn:
            self.conn.close()

    def get_product_entity_id(self, sku):
        """Get Magento product entity_id by SKU."""
        cursor = self.conn.cursor(dictionary=True)
        cursor.execute(
            "SELECT entity_id FROM catalog_product_entity WHERE sku = %s LIMIT 1",
            (sku,)
        )
        row = cursor.fetchone()
        cursor.close()
        return row["entity_id"] if row else None

    def update_product_attribute(self, entity_id, attribute_code, value, store_id=0):
        """Update a product EAV attribute value in Magento."""
        cursor = self.conn.cursor(dictionary=True)

        # Get attribute_id and backend_type
        cursor.execute(
            """SELECT attribute_id, backend_type FROM eav_attribute
               WHERE attribute_code = %s AND entity_type_id = (
                   SELECT entity_type_id FROM eav_entity_type WHERE entity_type_code = 'catalog_product'
               ) LIMIT 1""",
            (attribute_code,)
        )
        attr = cursor.fetchone()
        if not attr:
            cursor.close()
            return False

        table = "catalog_product_entity_%s" % attr["backend_type"]
        if attr["backend_type"] == "static":
            cursor.execute(
                "UPDATE catalog_product_entity SET %s = %%s WHERE entity_id = %%s" % attribute_code,
                (value, entity_id)
            )
        else:
            # UPSERT into EAV value table
            cursor.execute(
                """INSERT INTO %s (attribute_id, store_id, entity_id, value)
                   VALUES (%%s, %%s, %%s, %%s)
                   ON DUPLICATE KEY UPDATE value = %%s""" % table,
                (attr["attribute_id"], store_id, entity_id, value, value)
            )
        cursor.close()
        return True

    def update_product_price(self, entity_id, price, currency="DZD", store_id=0):
        """Update product price in Magento."""
        cursor = self.conn.cursor(dictionary=True)
        cursor.execute(
            """SELECT attribute_id FROM eav_attribute
               WHERE attribute_code = 'price' AND entity_type_id = (
                   SELECT entity_type_id FROM eav_entity_type WHERE entity_type_code = 'catalog_product'
               ) LIMIT 1"""
        )
        attr = cursor.fetchone()
        if attr:
            cursor.execute(
                """INSERT INTO catalog_product_entity_decimal (attribute_id, store_id, entity_id, value)
                   VALUES (%s, %s, %s, %s)
                   ON DUPLICATE KEY UPDATE value = %s""",
                (attr["attribute_id"], store_id, entity_id, price, price)
            )
        cursor.close()

    def commit(self):
        if self.conn:
            self.conn.commit()


# === Sync Logic ===
def get_pim_value(product, attr_code, locale=None, scope=None):
    """Extract an attribute value from Akeneo product JSON."""
    values = product.get("values", {}).get(attr_code, [])
    for v in values:
        if (v.get("locale") == locale or v.get("locale") is None) and \
           (v.get("scope") == scope or v.get("scope") is None):
            return v.get("data")
    return None


def sync_products(akeneo, magento, since_hours=24, limit=None, dry_run=False):
    """Sync updated products from Akeneo back to Magento."""
    log("=== Syncing products (Akeneo -> Magento) ===")

    if since_hours:
        since_dt = datetime.now() - timedelta(hours=since_hours)
        log("Fetching products updated since %s" % since_dt.strftime("%Y-%m-%d %H:%M:%S"))
        products = akeneo.get_products_updated_since(since_dt)
    else:
        products = akeneo.get_all("products")

    if limit:
        products = products[:limit]

    log("Found %d products to sync" % len(products))

    stats = {"updated": 0, "skipped": 0, "errors": 0, "not_found": 0}

    for prod in products:
        sku = prod.get("identifier", "")
        if not sku:
            stats["skipped"] += 1
            continue

        try:
            entity_id = magento.get_product_entity_id(sku)
            if not entity_id:
                stats["not_found"] += 1
                log("  SKU '%s' not found in Magento - skipping" % sku, "WARN")
                continue

            if dry_run:
                name = get_pim_value(prod, "name", locale=PIM_LOCALE)
                desc = get_pim_value(prod, "description", locale=PIM_LOCALE, scope=PIM_CHANNEL)
                price_data = get_pim_value(prod, "price")
                price = None
                if price_data:
                    for p in price_data:
                        if p.get("currency") == PIM_CURRENCY:
                            price = p.get("amount")
                log("  [DRY-RUN] Would update SKU '%s' (entity_id=%s): name=%s, price=%s" %
                    (sku, entity_id, name, price))
                stats["updated"] += 1
                continue

            # Update name
            name = get_pim_value(prod, "name", locale=PIM_LOCALE)
            if name:
                magento.update_product_attribute(entity_id, "name", name)

            # Update description
            desc = get_pim_value(prod, "description", locale=PIM_LOCALE, scope=PIM_CHANNEL)
            if desc:
                magento.update_product_attribute(entity_id, "description", desc)

            # Update short description
            short_desc = get_pim_value(prod, "short_description", locale=PIM_LOCALE, scope=PIM_CHANNEL)
            if short_desc:
                magento.update_product_attribute(entity_id, "short_description", short_desc)

            # Update price
            price_data = get_pim_value(prod, "price")
            if price_data:
                for p in price_data:
                    if p.get("currency") == PIM_CURRENCY and p.get("amount"):
                        magento.update_product_price(entity_id, p["amount"])

            # Update weight
            weight_data = get_pim_value(prod, "weight")
            if weight_data and weight_data.get("amount"):
                magento.update_product_attribute(entity_id, "weight", weight_data["amount"])

            # Update status
            status = get_pim_value(prod, "product_status")
            if status is not None:
                magento.update_product_attribute(entity_id, "status", 1 if status else 2)

            # Update meta title
            meta_title = get_pim_value(prod, "meta_title", locale=PIM_LOCALE)
            if meta_title:
                magento.update_product_attribute(entity_id, "meta_title", meta_title)

            # Update meta description
            meta_desc = get_pim_value(prod, "meta_description", locale=PIM_LOCALE)
            if meta_desc:
                magento.update_product_attribute(entity_id, "meta_description", meta_desc)

            # Update URL key
            url_key = get_pim_value(prod, "url_key")
            if url_key:
                magento.update_product_attribute(entity_id, "url_key", url_key)

            magento.commit()
            stats["updated"] += 1

        except Exception as e:
            log("  Error syncing SKU '%s': %s" % (sku, str(e)), "ERROR")
            stats["errors"] += 1

    log("Product sync complete: updated=%d, not_found=%d, skipped=%d, errors=%d" %
        (stats["updated"], stats["not_found"], stats["skipped"], stats["errors"]))
    return stats


def sync_categories(akeneo, magento, limit=None, dry_run=False):
    """Sync categories from Akeneo back to Magento (names only)."""
    log("=== Syncing categories (Akeneo -> Magento) ===")
    categories = akeneo.get_all("categories")

    if limit:
        categories = categories[:limit]

    log("Found %d categories in Akeneo" % len(categories))

    stats = {"updated": 0, "skipped": 0, "errors": 0}

    cursor = magento.conn.cursor(dictionary=True)

    for cat in categories:
        code = cat.get("code", "")
        labels = cat.get("labels", {})
        name_en = labels.get(PIM_LOCALE, "")

        if not name_en or code in ("master",):
            stats["skipped"] += 1
            continue

        if dry_run:
            log("  [DRY-RUN] Would update category '%s' name to '%s'" % (code, name_en))
            stats["updated"] += 1
            continue

        try:
            # Find the Magento category by matching URL key or name
            cursor.execute(
                """SELECT e.entity_id FROM catalog_category_entity e
                   JOIN catalog_category_entity_varchar v ON e.entity_id = v.entity_id
                   JOIN eav_attribute a ON v.attribute_id = a.attribute_id
                   WHERE a.attribute_code = 'url_key' AND v.value = %s LIMIT 1""",
                (code,)
            )
            row = cursor.fetchone()
            if row:
                # Update category name
                cursor.execute(
                    """UPDATE catalog_category_entity_varchar v
                       JOIN eav_attribute a ON v.attribute_id = a.attribute_id
                       SET v.value = %s
                       WHERE v.entity_id = %s AND a.attribute_code = 'name' AND v.store_id = 0""",
                    (name_en, row["entity_id"])
                )
                stats["updated"] += 1
            else:
                stats["skipped"] += 1
        except Exception as e:
            log("  Error syncing category '%s': %s" % (code, str(e)), "ERROR")
            stats["errors"] += 1

    magento.commit()
    cursor.close()

    log("Category sync complete: updated=%d, skipped=%d, errors=%d" %
        (stats["updated"], stats["skipped"], stats["errors"]))
    return stats


# === Main ===
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Akeneo PIM to Magento 2 reverse sync")
    parser.add_argument("--products", action="store_true", help="Sync products")
    parser.add_argument("--categories", action="store_true", help="Sync categories")
    parser.add_argument("--all", action="store_true", help="Sync everything")
    parser.add_argument("--limit", type=int, default=None, help="Limit items to sync")
    parser.add_argument("--since", type=int, default=24, help="Hours lookback for updates (default: 24)")
    parser.add_argument("--dry-run", action="store_true", help="Show what would be synced")
    args = parser.parse_args()

    if not any([args.products, args.categories, args.all]):
        parser.print_help()
        sys.exit(1)

    log("=== Akeneo -> Magento reverse sync started ===")
    if args.dry_run:
        log("*** DRY RUN MODE - no changes will be made ***")

    # Initialize clients
    akeneo = AkeneoClient(AKENEO_API)
    akeneo.authenticate()

    magento = MagentoWriter(MAGENTO_DB)
    magento.connect()

    try:
        if args.all or args.categories:
            sync_categories(akeneo, magento, limit=args.limit, dry_run=args.dry_run)

        if args.all or args.products:
            sync_products(akeneo, magento, since_hours=args.since, limit=args.limit, dry_run=args.dry_run)
    finally:
        magento.close()

    log("=== Reverse sync finished ===")
