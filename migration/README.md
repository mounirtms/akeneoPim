# Migration Toolkit

This directory contains tools to import Magento data into Pimcore, with a focus on reliability, idempotency, and performance.

## Prerequisites
- Ensure Pimcore filesystem permissions are correct. From project root:
  - bash scripts/fix-permissions-smart.sh
- Optional but recommended: disable versioning during bulk imports (scripts handle this automatically).
- Configure Magento media base path (for image import):
  - export MAGENTO_MEDIA_BASE=/mnt/magento/pub/media/catalog/product

## Importing products from CSV
A professional CSV importer is available:

```
php migration/scripts/import_products_from_csv.php --file=/home/pim/public_html/products.csv --batch-size=500 --images --resume
```

Options:
- --file=...            Path to CSV file (required)
- --batch-size=N        Number of rows per progress checkpoint (default 200)
- --dry-run             Validate and log without writing to Pimcore
- --images              Enable image import (requires MAGENTO_MEDIA_BASE)
- --resume              Continue from last checkpoint
- --limit=N             Stop after N items

CSV Columns expected:
- sku (required)
- name (required)
- description
- short_description
- category_ids          Comma-separated list of Magento category IDs present in Pimcore Category.magentoId
- image_files           Comma-separated relative paths under MAGENTO_MEDIA_BASE

The importer:
- Streams the CSV to keep memory low
- Upserts by SKU (or path fallback) to avoid duplicates
- Caches categories and reuses assets when possible
- Writes logs to migration/logs
- Saves a checkpoint to migration/logs/products_csv_checkpoint.json

## Magento DB optimized migration
`migration/scripts/run_optimized_migration.php` has been hardened to be idempotent:
- Upserts products by SKU/path
- Skips image imports unless MAGENTO_MEDIA_BASE is configured
- Uses larger batch sizes and disables versioning for speed

Run it as:
```
php migration/scripts/run_optimized_migration.php
```

## Troubleshooting
- If you see cache permission errors (e.g., FOSJsRouting), fix permissions and clear caches:
  - bash scripts/clean-cache.sh
  - bash scripts/fix-permissions-smart.sh
- Verify MAGENTO_MEDIA_BASE points to a readable path.
- Check logs under migration/logs/ and var/log/ for details.
