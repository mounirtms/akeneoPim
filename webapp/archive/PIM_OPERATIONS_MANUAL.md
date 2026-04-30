# Techno Stationery - Akeneo PIM Operations Manual
## pim.technostationery.com | v2.0 | 2026-03-28

---

## QUICK START

```bash
# Deploy all fixes (idempotent, safe to re-run):
sudo bash /home/pim/public_html/webapp/deploy_comprehensive.sh

# Check system status:
bash /home/pim/public_html/webapp/pim_status.sh

# Full health check:
cd /home/pim/public_html/webapp && bash pim health --verbose
```

---

## 1. SYSTEM OVERVIEW

| Component       | Detail                                              |
|-----------------|-----------------------------------------------------|
| URL             | https://pim.technostationery.com                    |
| Admin login     | admin / PimAdmin2026!                               |
| PHP             | 8.2 (cli: /usr/bin/php)                             |
| Database        | MariaDB 127.0.0.1:3307 / akeneo_pim                |
| Elasticsearch   | localhost:9200                                      |
| PIM root        | /home/pim/public_html                               |
| Webapp scripts  | /home/pim/public_html/webapp                        |
| API client_id   | 1_3yhbczkw7osgcw8wg44k84os4sc04w4wc80ks08sw8cc8c40sw |
| API secret      | 50vx3l4u4l4wwcsok4kcwkoo44oo0s0o8s0kcs0gc0c8g0oow4  |
| Channel         | ecommerce                                           |
| Locales         | en_US, fr_FR                                        |
| Currencies      | DZD, EUR, USD                                       |

### Current Data

| Entity     | Count |
|------------|-------|
| Products   | 8,054 |
| Categories | 712   |
| Families   | 1     |
| Attributes | 32    |

---

## 2. CLI COMMANDS (via `pim` wrapper)

All commands are run from `/home/pim/public_html/webapp`.

### Cache Management
```bash
bash pim cache full-reset     # Clear + warmup + fix permissions
bash pim cache clear           # Clear only
bash pim cache warmup          # Warmup only
bash pim cache fix-perms       # Fix ownership/permissions
bash pim cache status          # View cache info
bash pim cache doctrine        # Rebuild Doctrine metadata
bash pim cache routing         # Rebuild routing cache
bash pim cache translations    # Rebuild translation cache
```

### Elasticsearch
```bash
bash pim es index-all          # Reindex products + product models
bash pim es index-products     # Reindex products only
bash pim es index-models       # Reindex product models only
bash pim es status             # View index stats
bash pim es health             # Cluster health
bash pim es reset              # WARNING: Reset all indices
bash pim es update-mapping     # Update mappings
```

### Deployment
```bash
bash pim deploy full           # Full: cache + assets + webpack + validate
bash pim deploy quick          # Quick: cache only
bash pim deploy assets         # Rebuild assets
bash pim deploy webpack        # Rebuild webpack bundles
bash pim deploy validate       # Run post-deploy checks
bash pim deploy js-routes      # Regenerate JS routes
```

### Maintenance
```bash
bash pim maintain list-jobs         # List all batch jobs
bash pim maintain clean-jobs        # Fix stuck jobs
bash pim maintain purge-jobs 30     # Purge job executions older than N days
bash pim maintain purge-messages    # Purge messenger queue
bash pim maintain completeness      # Recalculate product completeness
bash pim maintain clean-attributes  # Remove orphaned attribute values
bash pim maintain version-refresh   # Refresh entity versions
bash pim maintain version-purge 90  # Purge versions older than N days
bash pim maintain db-validate       # Validate DB schema
bash pim maintain oauth-clean       # Clean expired tokens
bash pim maintain create-oauth      # Create new API client
bash pim maintain system-info       # System information
bash pim maintain volume-report     # Aggregate volume metrics
```

### Cron Management
```bash
bash pim cron install          # Install cron jobs
bash pim cron uninstall        # Remove cron jobs
bash pim cron status           # View cron status
bash pim cron list             # Preview cron entries
bash pim cron run-all          # Run all tasks manually
```

### Health Check
```bash
bash pim health                # Standard health check
bash pim health --verbose      # Detailed output
bash pim health --json         # JSON output (for monitoring)
bash pim health --quiet        # Exit code only (0/1/2)
```

---

## 3. MAGENTO SYNC COMMANDS

### Magento -> Akeneo (initial import)
```bash
cd /home/pim/public_html

# Import categories from Magento beta DB
python3 var/magento_to_akeneo_sync.py --categories

# Import products (all)
python3 var/magento_to_akeneo_sync.py --products

# Import everything
python3 var/magento_to_akeneo_sync.py --all

# Import with limit (testing)
python3 var/magento_to_akeneo_sync.py --products --limit 50

# Initial setup (adds fr_FR locale, DZD currency)
python3 var/magento_to_akeneo_sync.py --all --setup
```

### Akeneo -> Magento (reverse sync / push-back)
```bash
cd /home/pim/public_html/webapp

# Dry run - see what would change (last 24h updates)
python3 akeneo_to_magento_sync.py --products --dry-run

# Push product changes to Magento (last 24h)
python3 akeneo_to_magento_sync.py --products

# Push changes from last 48 hours
python3 akeneo_to_magento_sync.py --products --since 48

# Push categories
python3 akeneo_to_magento_sync.py --categories

# Push everything with limit
python3 akeneo_to_magento_sync.py --all --limit 100 --dry-run
```

### Sync Workflow (recommended)
```
1. Initial import:   Magento -> Akeneo (--all --setup)
2. Enrich in PIM:    Edit products via PIM UI
3. Push changes:     Akeneo -> Magento (--products --since 24)
4. Verify:           Check Magento admin for updated data
```

---

## 4. AKENEO REST API

### Authentication
```bash
# Get access token
curl -X POST https://pim.technostationery.com/api/oauth/v1/token \
  -d 'grant_type=password' \
  -d 'client_id=1_3yhbczkw7osgcw8wg44k84os4sc04w4wc80ks08sw8cc8c40sw' \
  -d 'client_secret=50vx3l4u4l4wwcsok4kcwkoo44oo0s0o8s0kcs0gc0c8g0oow4' \
  -d 'username=admin' \
  -d 'password=PimAdmin2026!'
```

### Common API Calls
```bash
TOKEN="<access_token_from_above>"

# List products
curl -H "Authorization: Bearer $TOKEN" \
  https://pim.technostationery.com/api/rest/v1/products?limit=10

# Get single product
curl -H "Authorization: Bearer $TOKEN" \
  https://pim.technostationery.com/api/rest/v1/products/SKU123

# List categories
curl -H "Authorization: Bearer $TOKEN" \
  https://pim.technostationery.com/api/rest/v1/categories?limit=100

# List families
curl -H "Authorization: Bearer $TOKEN" \
  https://pim.technostationery.com/api/rest/v1/families

# List attributes
curl -H "Authorization: Bearer $TOKEN" \
  https://pim.technostationery.com/api/rest/v1/attributes?limit=100

# List channels
curl -H "Authorization: Bearer $TOKEN" \
  https://pim.technostationery.com/api/rest/v1/channels

# Create/update product (PATCH)
curl -X PATCH -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  https://pim.technostationery.com/api/rest/v1/products/SKU123 \
  -d '{"values":{"name":[{"locale":"en_US","scope":null,"data":"New Name"}]}}'
```

---

## 5. DIRECT SYMFONY CONSOLE COMMANDS

```bash
cd /home/pim/public_html

# Cache
php bin/console cache:clear --env=prod
php bin/console cache:warmup --env=prod

# Product indexing
php bin/console pim:product:index --all --env=prod
php bin/console pim:product-model:index --all --env=prod

# Completeness
php bin/console pim:completeness:calculate --env=prod

# Data Quality Insights
php bin/console pim:data-quality-insights:schedule-periodic-tasks --env=prod
php bin/console pim:data-quality-insights:prepare-evaluations --env=prod
php bin/console pim:data-quality-insights:evaluations --env=prod

# Job management
php bin/console akeneo:batch:list-jobs --env=prod

# Messenger purge (fixed syntax)
php bin/console akeneo:messenger:doctrine:purge-messages messenger_messages default --retention-time=7200 --env=prod
php bin/console akeneo:messenger:doctrine:purge-messages messenger_messages ui_job --retention-time=7200 --env=prod
php bin/console akeneo:messenger:doctrine:purge-messages messenger_messages import_export_job --retention-time=7200 --env=prod

# OAuth
php bin/console fos:oauth-server:clean --env=prod
php bin/console pim:oauth-server:list-clients --env=prod

# Versioning
php bin/console pim:versioning:refresh --env=prod
php bin/console pim:versioning:purge --more-than-days 90 --force --env=prod

# Router debugging
php bin/console debug:router --env=prod
```

---

## 6. CRON SCHEDULE

| Time          | Freq       | Task                               |
|---------------|------------|-------------------------------------|
| */5 * * * *   | 5 min      | Messenger consumer (job queue)      |
| 0 1 * * *     | Daily 1AM  | Clean stuck job executions          |
| 15 1 * * *    | Daily 1:15 | Purge messenger queue               |
| 30 1 * * *    | Daily 1:30 | Purge old versions (>90d)           |
| 45 1 * * *    | Daily 1:45 | Purge old job executions (>90d)     |
| 0 2 * * *     | Daily 2AM  | DQI evaluation pipeline             |
| 0 3 * * *     | Daily 3AM  | Connectivity audit update           |
| 0 4 * * *     | Daily 4AM  | Clean expired OAuth tokens          |
| 30 4 * * *    | Daily 4:30 | Volume metrics aggregation          |
| 0 5 * * *     | Daily 5AM  | System health check                 |
| 0 0 * * *     | Daily 12AM | Log rotation (>50MB)                |
| 0 1 * * 0     | Sun 1AM    | Product completeness recalculation  |
| 0 2 * * 0     | Sun 2AM    | Full Elasticsearch reindex          |
| 0 3 * * 0     | Sun 3AM    | Version refresh                     |

---

## 7. TUNING GUIDE

### Elasticsearch
```bash
# Set replicas to 0 (single node - removes yellow warning)
curl -X PUT localhost:9200/_settings -H 'Content-Type: application/json' \
  -d '{"index.number_of_replicas": 0}'

# Check health
curl localhost:9200/_cluster/health?pretty
```

### PHP OPcache (recommended settings)
```ini
opcache.memory_consumption=256
opcache.max_accelerated_files=20000
opcache.validate_timestamps=0
```

### MySQL/MariaDB
```ini
innodb_buffer_pool_size=1G
innodb_log_file_size=256M
query_cache_type=0
```

### Suppress PHP Deprecation Notices
Edit php.ini:
```ini
error_reporting = E_ALL & ~E_DEPRECATED & ~E_NOTICE
```

---

## 8. KNOWN ISSUES

| Issue                       | Status   | Resolution                        |
|-----------------------------|----------|-----------------------------------|
| process is not defined (JS) | FIXED    | process-polyfill.js injected      |
| SPA routes return 404       | FIXED    | TemplateController defaults added |
| Imagick not installed       | FIXED    | LiipImagine set to GD driver     |
| robots.txt missing          | FIXED    | Created in public/               |
| Messenger purge fails       | FIXED    | Correct table+queue args          |
| DZD currency disabled       | FIXED    | Activated in DB + channel         |
| Import/export jobs missing  | FIXED    | 18 CSV jobs created in DB         |
| ES cluster yellow           | Expected | Single-node, set replicas=0       |
| PHP deprecation notices     | Manual   | Set error_reporting in php.ini    |

---

## 9. FILE LOCATIONS

| File / Directory                                        | Purpose                     |
|---------------------------------------------------------|-----------------------------|
| `/home/pim/public_html`                                 | PIM root directory          |
| `/home/pim/public_html/webapp/pim`                      | Master CLI entry point      |
| `/home/pim/public_html/webapp/deploy_comprehensive.sh`  | Comprehensive deploy script |
| `/home/pim/public_html/webapp/pim_status.sh`            | System status checker       |
| `/home/pim/public_html/webapp/akeneo_to_magento_sync.py`| Reverse sync (PIM->Magento) |
| `/home/pim/public_html/webapp/pim_layout_fixes.css`     | CSS fallback styles         |
| `/home/pim/public_html/var/magento_to_akeneo_sync.py`   | Forward sync (Magento->PIM) |
| `/home/pim/public_html/var/deploy_all_fixes.sh`         | Legacy deploy script (v1)   |
| `/home/pim/public_html/var/fix_spa_routes.sh`           | SPA route patcher           |
| `/home/pim/public_html/var/logs/magento_sync.log`       | Forward sync log            |
| `/home/pim/public_html/var/logs/akeneo_to_magento_sync.log` | Reverse sync log        |
| `/home/pim/public_html/public/dist/process-polyfill.js` | JS polyfill for vendor.min  |
| `/home/pim/public_html/public/css/pim.css`              | Main CSS (with appended fixes) |
| `/home/pim/public_html/config/routes.yaml`              | SPA route fallbacks         |
| `/home/pim/public_html/config/packages/liip_imagine.yml`| GD driver override          |

---

## 10. MAGENTO BETA DATABASE

| Setting    | Value                |
|------------|----------------------|
| Host       | 127.0.0.1            |
| Port       | 3307                 |
| Database   | beta_dBT8x12y22      |
| User       | root                 |
| Password   | YourNewStrongPassword|
| SSL        | disabled             |

```bash
# Connect directly
mysql -h 127.0.0.1 -P 3307 -u root -p'YourNewStrongPassword' --ssl=false beta_dBT8x12y22

# Check product count
mysql -h 127.0.0.1 -P 3307 -u root -p'YourNewStrongPassword' --ssl=false beta_dBT8x12y22 \
  -e "SELECT COUNT(*) as products FROM catalog_product_entity;"
```

---

*Last updated: 2026-03-28 | Akeneo PIM Community Edition on PHP 8.2*
