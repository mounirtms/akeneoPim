#!/bin/bash

echo "================================================================="
echo "URGENT: RESTORING AKENEO PIM FROM MAGENTO"
echo "================================================================="
echo ""
echo "Date: $(date)"
echo "Source: Magento at /home/beta/public_html"
echo "Target: Akeneo PIM at /home/pim/public_html"
echo "Products to restore: 9,538"
echo ""

# Create restore log
RESTORE_LOG="/home/pim/restore_$(date +%Y%m%d_%H%M%S).log"

echo "Step 1: Export all data from Magento Akeneo Connector..." | tee -a "$RESTORE_LOG"
cd /home/beta/public_html

# Check Akeneo connector jobs
php bin/magento akeneo_connector:import --help 2>&1 | tee -a "$RESTORE_LOG"

echo ""
echo "Step 2: Running Akeneo import from Magento..." | tee -a "$RESTORE_LOG"

# Run all import jobs
for job in category family attribute attribute_option product; do
    echo "Importing $job..." | tee -a "$RESTORE_LOG"
    timeout 600 php bin/magento akeneo_connector:import --code="$job" 2>&1 | tee -a "$RESTORE_LOG"
    echo "Completed $job import" | tee -a "$RESTORE_LOG"
    echo "" | tee -a "$RESTORE_LOG"
done

echo ""
echo "Step 3: Verify import in Akeneo database..." | tee -a "$RESTORE_LOG"
/opt/mariadb10.6/mariadb/bin/mysql -u root -p'YourNewStrongPassword' -h 127.0.0.1 -P 3307 akeneo_pim -e "
SELECT 'Products' as entity_type, COUNT(*) as count FROM pim_catalog_product
UNION ALL  
SELECT 'Families', COUNT(*) FROM pim_catalog_family
UNION ALL
SELECT 'Attributes', COUNT(*) FROM pim_catalog_attribute
UNION ALL
SELECT 'Categories', COUNT(*) FROM pim_catalog_category
UNION ALL
SELECT 'Users', COUNT(*) FROM oro_user;" 2>&1 | tee -a "$RESTORE_LOG"

echo ""
echo "================================================================="
echo "Restore log saved to: $RESTORE_LOG"
echo "================================================================="

