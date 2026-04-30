#!/usr/bin/env python3
"""
Delta Sync: Magento -> Akeneo
Syncs only products updated since last run.
Run via cron: 0 */4 * * * python3 /home/pim/public_html/webapp/delta_sync.py
"""
import mysql.connector, requests, json, time, os
from datetime import datetime, timedelta

STATE_FILE = "/home/pim/public_html/webapp/.last_sync_timestamp"
API = {"base_url": "https://pim.technostationery.com", "client_id": "1_3yhbczkw7osgcw8wg44k84os4sc04w4wc80ks08sw8cc8c40sw", "client_secret": "50vx3l4u4l4wwcsok4kcwkoo44oo0s0o8s0kcs0gc0c8g0oow4", "username": "admin", "password": "PimAdmin2026!"}
MAGENTO_DB = {"host": "127.0.0.1", "port": 3307, "user": "root", "password": "YourNewStrongPassword", "database": "beta_dBT8x12y22", "ssl_disabled": True}
BATCH_SIZE = 100

def get_last_sync():
    if os.path.exists(STATE_FILE):
        with open(STATE_FILE) as f:
            return f.read().strip()
    return (datetime.now() - timedelta(days=1)).strftime("%Y-%m-%d %H:%M:%S")

def save_sync_time():
    with open(STATE_FILE, "w") as f:
        f.write(datetime.now().strftime("%Y-%m-%d %H:%M:%S"))

def main():
    last = get_last_sync()
    print(f"Delta sync since {last}")

    conn = mysql.connector.connect(**MAGENTO_DB)
    cur = conn.cursor(dictionary=True)
    cur.execute("""
        SELECT sku FROM catalog_product_entity
        WHERE updated_at > %s
        ORDER BY updated_at DESC LIMIT 5000
    """, (last,))
    updated_skus = [row["sku"] for row in cur.fetchall()]
    cur.close()
    conn.close()

    if not updated_skus:
        print("No updates found.")
        save_sync_time()
        return

    print(f"Found {len(updated_skus)} updated products")
    # The master sync script handles the actual data sync
    # This script just identifies what needs syncing
    with open("/home/pim/public_html/webapp/.delta_skus.json", "w") as f:
        json.dump(updated_skus, f)

    save_sync_time()
    print("Delta sync complete.")

if __name__ == "__main__":
    main()
