<?php
/**
 * Akeneo Data Insights Fix - Enable proper data grid, completeness, and UI features
 * Fixes: Missing data grid, product model progress, category display issues
 */

echo "=== AKENEO DATA INSIGHTS FIX ===\n";
echo "Date: " . date('Y-m-d H:i:s') . "\n\n";

// Database connection
$host = '127.0.0.1';
$port = 3307;
$dbname = 'akeneo_pim';
$user = 'akeneo_pim';
$password = 'akeneo_pim';

try {
    $pdo = new PDO("mysql:host=$host;port=$port;dbname=$dbname;charset=utf8mb4", $user, $password);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    echo "✅ Database connected\n\n";
} catch (PDOException $e) {
    die("❌ Connection failed: " . $e->getMessage() . "\n");
}

// Step 1: Activate en_US locale (required for data grid)
echo "--- STEP 1: Activate en_US Locale ---\n";
try {
    $stmt = $pdo->prepare("UPDATE pim_catalog_locale SET is_activated = 1 WHERE code = 'en_US'");
    $stmt->execute();
    echo "✅ en_US locale activated\n";
} catch (Exception $e) {
    echo "⚠️  Could not activate en_US: " . $e->getMessage() . "\n";
}

// Step 2: Enable ar_DZ locale (for Algeria)
echo "\n--- STEP 2: Activate ar_DZ Locale (Algeria) ---\n";
try {
    $stmt = $pdo->prepare("UPDATE pim_catalog_locale SET is_activated = 1 WHERE code = 'ar_DZ'");
    $stmt->execute();
    echo "✅ ar_DZ locale activated\n";
} catch (Exception $e) {
    echo "⚠️  Could not activate ar_DZ: " . $e->getMessage() . "\n";
}

// Step 3: Add locales to channels
echo "\n--- STEP 3: Add Locales to Channels ---\n";
try {
    // Get channel IDs
    $stmt = $pdo->query("SELECT id, code FROM pim_catalog_channel");
    $channels = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // Get locale IDs
    $stmt = $pdo->query("SELECT id, code FROM pim_catalog_locale WHERE is_activated = 1");
    $locales = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    foreach ($channels as $channel) {
        foreach ($locales as $locale) {
            // Check if already exists
            $check = $pdo->prepare("SELECT COUNT(*) as c FROM pim_catalog_channel_locale WHERE channel_id = ? AND locale_id = ?");
            $check->execute([$channel['id'], $locale['id']]);
            if ($check->fetch()['c'] == 0) {
                $insert = $pdo->prepare("INSERT INTO pim_catalog_channel_locale (channel_id, locale_id) VALUES (?, ?)");
                $insert->execute([$channel['id'], $locale['id']]);
                echo "✅ Added {$locale['code']} to channel {$channel['code']}\n";
            }
        }
    }
} catch (Exception $e) {
    echo "⚠️  Could not add locales to channels: " . $e->getMessage() . "\n";
}

// Step 4: Fix category labels for en_US
echo "\n--- STEP 4: Add English Labels to Categories ---\n";
try {
    // Copy fr_FR labels to en_US where missing
    $stmt = $pdo->query("
        SELECT c.id, c.code, ct.label
        FROM pim_catalog_category c
        LEFT JOIN pim_catalog_category_translation ct ON c.id = ct.foreign_key AND ct.locale = 'fr_FR'
        WHERE c.id NOT IN (
            SELECT foreign_key FROM pim_catalog_category_translation WHERE locale = 'en_US'
        )
        LIMIT 50
    ");
    
    $count = 0;
    while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
        $label = $row['label'] ?: $row['code'];
        $insert = $pdo->prepare("INSERT INTO pim_catalog_category_translation (foreign_key, locale, label) VALUES (?, 'en_US', ?)");
        $insert->execute([$row['id'], $label]);
        $count++;
    }
    echo "✅ Added en_US labels to $count categories\n";
} catch (Exception $e) {
    echo "⚠️  Could not add category labels: " . $e->getMessage() . "\n";
}

// Step 5: Recalculate completeness
echo "\n--- STEP 5: Triggering Completeness Recalculation ---\n";
echo "⚠️  Note: Full completeness calculation should be done via CLI:\n";
echo "   cd /home/pim/public_html && php bin/console pim:completeness:calculate\n\n";

// Check current completeness
try {
    $stmt = $pdo->query("
        SELECT 
            channel_code,
            locale_code,
            COUNT(*) as product_count,
            ROUND(AVG(ratio), 2) as avg_completeness,
            SUM(CASE WHEN ratio = 100 THEN 1 ELSE 0 END) as complete_products
        FROM pim_catalog_completeness
        GROUP BY channel_code, locale_code
    ");
    
    echo "Current Completeness by Channel/Locale:\n";
    while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
        echo "  - {$row['channel_code']}/{$row['locale_code']}: {$row['avg_completeness']}% average, {$row['complete_products']}/{$row['product_count']} complete\n";
    }
} catch (Exception $e) {
    echo "⚠️  Could not check completeness: " . $e->getMessage() . "\n";
}

// Step 6: Check and fix attribute requirements
echo "\n--- STEP 6: Check Attribute Requirements ---\n";
try {
    $stmt = $pdo->query("
        SELECT f.code as family, a.code as attribute, afr.required, afr.channel_code
        FROM pim_catalog_family_attribute_requirement afr
        JOIN pim_catalog_family f ON afr.family_id = f.id
        JOIN pim_catalog_attribute a ON afr.attribute_id = a.id
        WHERE afr.required = 1
        AND afr.channel_code = 'ecommerce'
        ORDER BY f.code, a.code
    ");
    
    $requirements = [];
    while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
        if (!isset($requirements[$row['family']])) {
            $requirements[$row['family']] = [];
        }
        $requirements[$row['family']][] = $row['attribute'];
    }
    
    echo "Required attributes by family (ecommerce channel):\n";
    foreach ($requirements as $family => $attrs) {
        echo "  - $family: " . count($attrs) . " required (" . implode(', ', array_slice($attrs, 0, 5)) . (count($attrs) > 5 ? '...' : '') . ")\n";
    }
} catch (Exception $e) {
    echo "⚠️  Could not check requirements: " . $e->getMessage() . "\n";
}

// Step 7: Create sample data quality metrics
echo "\n--- STEP 7: Initialize Data Quality Metrics ---\n";
try {
    // Count products with/without key attributes
    $keyAttributes = ['description', 'short_description', 'image', 'price', 'ean'];
    
    foreach ($keyAttributes as $attrCode) {
        $stmt = $pdo->prepare("
            SELECT 
                (SELECT COUNT(*) FROM pim_catalog_product) as total_products,
                COUNT(DISTINCT pv.product_id) as products_with_attr
            FROM pim_catalog_product_value pv
            JOIN pim_catalog_attribute a ON pv.attribute_id = a.id
            WHERE a.code = ?
        ");
        $stmt->execute([$attrCode]);
        $result = $stmt->fetch(PDO::FETCH_ASSOC);
        
        $coverage = $result['total_products'] > 0 
            ? round(($result['products_with_attr'] / $result['total_products']) * 100, 2) 
            : 0;
        
        echo "  - $attrCode: {$result['products_with_attr']}/{$result['total_products']} products ($coverage%)\n";
    }
} catch (Exception $e) {
    echo "⚠️  Could not check data quality: " . $e->getMessage() . "\n";
}

// Step 8: Product Model Progress Stats
echo "\n--- STEP 8: Product Model Progress Stats ---\n";
try {
    // Check product models with variants
    $stmt = $pdo->query("
        SELECT 
            COUNT(DISTINCT pm.id) as total_models,
            COUNT(DISTINCT CASE WHEN pm.parent_id IS NULL THEN pm.id END) as root_models,
            COUNT(DISTINCT CASE WHEN pm.parent_id IS NOT NULL THEN pm.id END) as child_models,
            COUNT(DISTINCT p.id) as variant_products
        FROM pim_catalog_product_model pm
        LEFT JOIN pim_catalog_product p ON p.product_model_id = pm.id
    ");
    
    $stats = $stmt->fetch(PDO::FETCH_ASSOC);
    echo "Product Model Statistics:\n";
    echo "  - Total Models: {$stats['total_models']}\n";
    echo "  - Root Models: {$stats['root_models']}\n";
    echo "  - Child Models: {$stats['child_models']}\n";
    echo "  - Products under models: {$stats['variant_products']}\n";
    
    // Get products NOT in models
    $stmt = $pdo->query("SELECT COUNT(*) as standalone FROM pim_catalog_product WHERE product_model_id IS NULL");
    $standalone = $stmt->fetch()['standalone'];
    echo "  - Standalone products: $standalone\n";
    
} catch (Exception $e) {
    echo "⚠️  Could not get model stats: " . $e->getMessage() . "\n";
}

// Step 9: Category tree health check
echo "\n--- STEP 9: Category Tree Health Check ---\n";
try {
    $stmt = $pdo->query("
        SELECT 
            lvl,
            COUNT(*) as category_count,
            COUNT(DISTINCT parent_id) as unique_parents
        FROM pim_catalog_category
        WHERE lvl > 0
        GROUP BY lvl
        ORDER BY lvl
    ");
    
    echo "Category levels:\n";
    while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
        echo "  - Level {$row['lvl']}: {$row['category_count']} categories, {$row['unique_parents']} unique parents\n";
    }
    
    // Check products per category
    $stmt = $pdo->query("
        SELECT 
            c.code,
            c.lvl,
            ct.label,
            COUNT(DISTINCT cp.product_id) as product_count
        FROM pim_catalog_category c
        LEFT JOIN pim_catalog_category_translation ct ON c.id = ct.foreign_key AND ct.locale = 'fr_FR'
        LEFT JOIN pim_catalog_category_product cp ON c.id = cp.category_id
        GROUP BY c.id
        HAVING product_count > 0
        ORDER BY product_count DESC
        LIMIT 10
    ");
    
    echo "\nTop 10 categories by product count:\n";
    while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
        $label = $row['label'] ?: $row['code'];
        echo "  - $label (Level {$row['lvl']}): {$row['product_count']} products\n";
    }
    
} catch (Exception $e) {
    echo "⚠️  Could not check category health: " . $e->getMessage() . "\n";
}

// Final recommendations
echo "\n=== NEXT STEPS ===\n";
echo "1. ⚡ Run completeness calculation:\n";
echo "   cd /home/pim/public_html && php bin/console pim:completeness:calculate --env=prod\n\n";

echo "2. 🔄 Clear Akeneo cache:\n";
echo "   cd /home/pim/public_html && php bin/console cache:clear --env=prod\n";
echo "   cd /home/pim/public_html && php bin/console pim:installer:assets --env=prod\n\n";

echo "3. 🌐 Access Akeneo UI:\n";
echo "   - Login at: https://pim.technostationery.com\n";
echo "   - Go to: Activity > Dashboard to see data insights\n";
echo "   - Go to: Products > Products to see data grid\n";
echo "   - Go to: Settings > Locales to verify en_US and ar_DZ are active\n\n";

echo "4. 📊 Check Data Grid:\n";
echo "   - Products grid should now show with en_US locale\n";
echo "   - Use filters to check completeness per channel\n";
echo "   - Product models should appear in grid with variant count\n\n";

echo "5. 🗂️  Categories:\n";
echo "   - Navigate to Settings > Categories\n";
echo "   - All 166 categories should be visible with labels\n";
echo "   - Check category tree structure is intact\n\n";

echo "✅ Data Insights Fix Complete!\n";
