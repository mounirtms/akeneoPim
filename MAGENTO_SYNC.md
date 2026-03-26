# Magento-Pimcore Synchronization

This document describes how to synchronize data between Pimcore and Magento systems.

## Overview

The synchronization system allows automatic transfer of product and category data from Pimcore to Magento. It consists of:

1. Database synchronization scripts
2. Configuration files
3. Command-line interface
4. Cron job automation

## Files

- `/scripts/sync/pimcore_to_magento_sync.php` - Basic synchronization script
- `/scripts/sync/magento_sync_service.php` - Advanced synchronization service with logging
- `/config/magento_sync.yaml` - Configuration file
- `/bin/magento-sync` - Command-line interface
- `/config/magento_sync_cron` - Cron job configuration

## Setup

1. Ensure both Pimcore and Magento databases are accessible
2. Configure database credentials in `/config/magento_sync.yaml`
3. Test the synchronization manually:
   ```
   cd /home/pim/public_html
   php bin/magento-sync
   ```

## Configuration

The synchronization can be configured via `/config/magento_sync.yaml`:

```yaml
magento:
  database:
    host: '127.0.0.1'
    port: 3307
    name: 'beta_dBT8x12y22'
    username: 'root'
    password: 'YourNewStrongPassword'

sync:
  # Which entities to sync
  products: true
  categories: true
  
  # Product sync options
  product:
    # Only sync published products
    only_published: true
    
    # Fields to sync
    fields:
      - sku
      - name
      - description
      - short_description
      - price
      - status
      - visibility
      - weight
      
  # Category sync options
  category:
    fields:
      - name
      - description
      
logging:
  enabled: true
  file: '/home/pim/public_html/var/log/magento_sync.log'
```

## Automation

To automatically synchronize data on a schedule:

1. Install the cron jobs:
   ```
   crontab /home/pim/public_html/config/magento_sync_cron
   ```

2. Verify the cron jobs are installed:
   ```
   crontab -l
   ```

By default, the synchronization runs every hour. You can modify the schedule by editing `/config/magento_sync_cron`.

## Manual Execution

To manually run the synchronization:

```
cd /home/pim/public_html
php bin/magento-sync
```

Logs are written to `/home/pim/public_html/var/log/magento_sync.log`.

## Troubleshooting

1. Check the log file for errors:
   ```
   tail -f /home/pim/public_html/var/log/magento_sync.log
   ```

2. Verify database connectivity:
   ```
   mysql -u root -p'YourNewStrongPassword' -h 127.0.0.1 -P 3307 beta_dBT8x12y22 -e "SELECT COUNT(*) FROM catalog_product_entity"
   ```

3. Check Pimcore data:
   ```
   cd /home/pim/public_html
   bin/console pimcore:object:list --class Product
   ```

## Extending the Synchronization

To add more fields to the synchronization:

1. Modify `/config/magento_sync.yaml` to include additional fields
2. Update the synchronization scripts to handle the new fields
3. Ensure the corresponding Magento attributes exist

## Limitations

1. The current implementation does not handle product images
2. Category hierarchy is simplified (all categories are placed under the default category)
3. Does not handle product associations (related, upsell, cross-sell products)
4. Does not support configurable, bundled, or grouped products
5. Does not handle inventory/stock synchronization

These limitations can be addressed in future enhancements to the synchronization system.