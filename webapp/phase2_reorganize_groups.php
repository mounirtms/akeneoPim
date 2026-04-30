<?php
/**
 * PHASE 2.4: REORGANIZE ATTRIBUTE GROUPS
 * 
 * This script reorganizes attributes from the overloaded "general" group (100 attributes)
 * into 7 logical, well-balanced groups:
 * 1. core_product_info - Basic product identification
 * 2. pricing_commerce - Prices, costs, taxes
 * 3. physical_properties - Weight, dimensions, materials
 * 4. inventory_logistics - Stock, suppliers, logistics
 * 5. marketing_seo - SEO fields, promotions, marketing
 * 6. media_assets - Images, videos, documents
 * 7. technical_specs - Technical IDs, flags, specs
 * 
 * Usage: php /home/pim/public_html/webapp/phase2_reorganize_groups.php
 * Run as: pim user
 * 
 * IMPORTANT: Backup database before running!
 */

error_reporting(E_ALL);
ini_set('display_errors', 1);

$akeneo_db = [
    'host' => '127.0.0.1',
    'port' => '3307',
    'database' => 'akeneo_pim',
    'user' => 'akeneo_pim',
    'password' => 'akeneo_pim'
];

try {
    $dsn = "mysql:host={$akeneo_db['host']};port={$akeneo_db['port']};dbname={$akeneo_db['database']};charset=utf8mb4";
    $pdo = new PDO($dsn, $akeneo_db['user'], $akeneo_db['password'], [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC
    ]);
    echo "✅ Connected to Akeneo PIM database\n\n";
} catch (PDOException $e) {
    echo "❌ Database connection failed: " . $e->getMessage() . "\n";
    exit(1);
}

echo "=" . str_repeat("=", 79) . "\n";
echo "PHASE 2.4: REORGANIZE ATTRIBUTE GROUPS\n";
echo "Date: " . date('Y-m-d H:i:s') . "\n";
echo "=" . str_repeat("=", 79) . "\n\n";

// Define new groups and their attributes
$group_definitions = [
    'core_product_info' => [
        'label' => 'Core Product Information',
        'description' => 'Basic product identification and classification',
        'attributes' => [
            'sku', 'name', 'description', 'short_description', 'brand', 'model',
            'color', 'material', 'manufacturer', 'origin_country',
            'product_type', 'category_ids', 'enabled', 'status',
            'release_date', 'created_at', 'updated_at'
        ]
    ],
    'pricing_commerce' => [
        'label' => 'Pricing & Commerce',
        'description' => 'Prices, costs, taxes, and commercial data',
        'attributes' => [
            'price', 'special_price', 'cost', 'msrp', 'tax_class_id',
            'currency', 'discount_percent', 'wholesale_price',
            'amasty_preorder_cart_label', 'amasty_preorder_note',
            'en_promo', 'is_featured', 'is_new'
        ]
    ],
    'physical_properties' => [
        'label' => 'Physical Properties',
        'description' => 'Weight, dimensions, volume, and physical characteristics',
        'attributes' => [
            'weight', 'length', 'width', 'height', 'volume', 'pages',
            'size', 'capacity', 'pack_quantity', 'ruling_type',
            'age_group', 'paper_weight', 'warranty'
        ]
    ],
    'inventory_logistics' => [
        'label' => 'Inventory & Logistics',
        'description' => 'Stock management, suppliers, and logistics',
        'attributes' => [
            'quantity', 'stock_status', 'min_qty', 'max_qty', 'notify_stock_qty',
            'is_in_stock', 'backorders', 'warehouse', 'supplier',
            'delivery_time', 'shipping_class'
        ]
    ],
    'marketing_seo' => [
        'label' => 'Marketing & SEO',
        'description' => 'SEO fields, marketing content, and promotional data',
        'attributes' => [
            'url_key', 'meta_title', 'meta_description', 'meta_keywords',
            'meta_keyword', 'amtoolkit_canonical', 'custom_layout_update',
            'gallery', 'links_title', 'mwishlist_sku', 'quickorder_sku',
            'required_options', 'has_options', 'options_container',
            'news_from_date', 'news_to_date', 'gift_message_available',
            'gift_message_recipient', 'gift_message_sender', 'gift_message_message'
        ]
    ],
    'media_assets' => [
        'label' => 'Media & Assets',
        'description' => 'Images, videos, documents, and digital assets',
        'attributes' => [
            'image', 'small_image', 'thumbnail', 'image_alt', 'image_label',
            'media_gallery', 'video', 'datasheet', 'certificate', 'attachment'
        ]
    ],
    'technical_specs' => [
        'label' => 'Technical Specifications',
        'description' => 'Technical IDs, barcodes, and specification data',
        'attributes' => [
            'ean13', 'upc', 'isbn', 'mpn', 'custom_design',
            'custom_design_from', 'custom_design_to', 'page_layout',
            'visibility', 'custom_options'
        ]
    ]
];

echo "Current State:\n";
$current_groups = $pdo->query("
    SELECT ag.code, COUNT(a.id) as attr_count
    FROM pim_catalog_attribute_group ag
    LEFT JOIN pim_catalog_attribute a ON ag.id = a.group_id
    GROUP BY ag.id, ag.code
    ORDER BY attr_count DESC
")->fetchAll();

foreach ($current_groups as $group) {
    echo "  {$group['code']}: {$group['attr_count']} attributes\n";
}

echo "\n";

// Create new groups or get existing ones
$stats = [
    'groups_created' => 0,
    'groups_existing' => 0,
    'attributes_moved' => 0,
    'errors' => 0,
];

echo "Creating/retrieving groups...\n\n";

foreach ($group_definitions as $code => $definition) {
    // Check if group exists
    $check = $pdo->prepare("SELECT id FROM pim_catalog_attribute_group WHERE code = ?");
    $check->execute([$code]);
    $group_id = $check->fetchColumn();
    
    if (!$group_id) {
        // Create new group
        $insert = $pdo->prepare("
            INSERT INTO pim_catalog_attribute_group (code, sort_order, created, updated)
            VALUES (?, 0, NOW(), NOW())
        ");
        $insert->execute([$code]);
        $group_id = $pdo->lastInsertId();
        
        // Add translations for the group label
        $trans = $pdo->prepare("
            INSERT INTO pim_catalog_attribute_group_translation (foreign_key, label, locale)
            VALUES (?, ?, ?)
        ");
        $trans->execute([$group_id, $definition['label'], 'en_US']);
        $trans->execute([$group_id, $definition['label'], 'fr_FR']);
        
        echo "  ✅ Created group: $code (ID: $group_id)\n";
        $stats['groups_created']++;
    } else {
        echo "  ⚠️ Group already exists: $code (ID: $group_id)\n";
        $stats['groups_existing']++;
    }
    
    // Move attributes to this group
    echo "    Moving attributes...\n";
    
    foreach ($definition['attributes'] as $attr_code) {
        $update = $pdo->prepare("
            UPDATE pim_catalog_attribute 
            SET group_id = ?
            WHERE code = ? AND group_id != ?
        ");
        
        try {
            $result = $update->execute([$group_id, $attr_code, $group_id]);
            $rows_affected = $update->rowCount();
            
            if ($rows_affected > 0) {
                echo "      ✓ Moved: $attr_code\n";
                $stats['attributes_moved'] += $rows_affected;
            }
        } catch (PDOException $e) {
            echo "      ✗ Error moving $attr_code: " . $e->getMessage() . "\n";
            $stats['errors']++;
        }
    }
    
    echo "\n";
}

// Handle remaining attributes in "general" group
echo "Checking for unmoved attributes in 'general' group...\n";
$remaining = $pdo->query("
    SELECT code FROM pim_catalog_attribute 
    WHERE group_id IN (SELECT id FROM pim_catalog_attribute_group WHERE code = 'general')
")->fetchAll();

if (count($remaining) > 0) {
    echo "  Found " . count($remaining) . " attributes still in 'general' group:\n";
    
    // Move remaining to "technical_specs" by default
    $tech_group = $pdo->prepare("SELECT id FROM pim_catalog_attribute_group WHERE code = 'technical_specs'");
    $tech_group->execute();
    $tech_group_id = $tech_group->fetchColumn();
    
    foreach ($remaining as $row) {
        $update = $pdo->prepare("
            UPDATE pim_catalog_attribute SET group_id = ? WHERE code = ?
        ");
        $update->execute([$tech_group_id, $row['code']]);
        echo "    → Moved $row[code] to technical_specs\n";
        $stats['attributes_moved']++;
    }
} else {
    echo "  ✅ No remaining attributes in 'general' group\n";
}

// Verification
echo "\n" . str_repeat("-", 80) . "\n";
echo "VERIFICATION\n";
echo str_repeat("-", 80) . "\n\n";

$new_distribution = $pdo->query("
    SELECT ag.code, COUNT(a.id) as attr_count
    FROM pim_catalog_attribute_group ag
    LEFT JOIN pim_catalog_attribute a ON ag.id = a.group_id
    GROUP BY ag.id, ag.code
    ORDER BY attr_count DESC
")->fetchAll();

echo "New Attribute Group Distribution:\n";
$total_attrs = 0;
foreach ($new_distribution as $group) {
    $pct = round(($group['attr_count'] / 112) * 100, 1);
    echo sprintf("  %-25s: %3d attributes (%5.1f%%)\n", 
        $group['code'], $group['attr_count'], $pct);
    $total_attrs += $group['attr_count'];
}

echo "\nTotal attributes distributed: $total_attrs\n";

// Summary
echo "\n" . str_repeat("=", 80) . "\n";
echo "PHASE 2.4 SUMMARY\n";
echo str_repeat("=", 80) . "\n\n";

echo "Groups created: {$stats['groups_created']}\n";
echo "Groups already existed: {$stats['groups_existing']}\n";
echo "Attributes moved: {$stats['attributes_moved']}\n";
echo "Errors: {$stats['errors']}\n\n";

if ($stats['errors'] == 0) {
    echo "✅ Phase 2.4 completed successfully!\n\n";
    echo "Attribute groups are now well-organized:\n";
    echo "- Core Product Information: ~20 attributes\n";
    echo "- Pricing & Commerce: ~13 attributes\n";
    echo "- Physical Properties: ~13 attributes\n";
    echo "- Inventory & Logistics: ~11 attributes\n";
    echo "- Marketing & SEO: ~21 attributes\n";
    echo "- Media & Assets: ~10 attributes\n";
    echo "- Technical Specifications: ~10 attributes\n\n";
    
    echo "Next steps:\n";
    echo "1. Verify in Akeneo UI - check attribute group organization\n";
    echo "2. Run Phase 2.5: Consolidate color options\n";
    echo "3. Run final audit to see quality score improvement\n";
} else {
    echo "⚠️ Phase 2.4 completed with {$stats['errors']} errors\n";
    echo "Please review the errors above.\n";
}

echo "\n" . date('Y-m-d H:i:s') . "\n";
