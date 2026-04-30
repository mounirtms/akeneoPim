<?php
/**
 * Comprehensive Data Relationship & Attribute Checker
 * Checks: Product-Category links, Product-Attribute relations, Family attributes, Completeness
 */

echo "=== COMPREHENSIVE DATA RELATIONSHIP CHECKER ===\n";
echo "Date: " . date('Y-m-d H:i:s') . "\n\n";

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

// 1. Check Product-Category Relationships
echo "--- 1. PRODUCT-CATEGORY RELATIONSHIPS ---\n";
try {
    // Products without categories
    $stmt = $pdo->query("
        SELECT COUNT(*) as orphan_count
        FROM pim_catalog_product p
        WHERE p.id NOT IN (SELECT DISTINCT product_id FROM pim_catalog_category_product)
    ");
    $orphans = $stmt->fetch()['orphan_count'];
    
    // Products with categories
    $stmt = $pdo->query("
        SELECT COUNT(DISTINCT product_id) as categorized
        FROM pim_catalog_category_product
    ");
    $categorized = $stmt->fetch()['categorized'];
    
    // Total products
    $stmt = $pdo->query("SELECT COUNT(*) as total FROM pim_catalog_product");
    $total = $stmt->fetch()['total'];
    
    echo "Total Products: $total\n";
    echo "Products WITH categories: $categorized (" . round(($categorized/$total)*100, 2) . "%)\n";
    echo "Products WITHOUT categories (orphans): $orphans (" . round(($orphans/$total)*100, 2) . "%)\n";
    
    if ($orphans > 0) {
        echo "\n⚠️  Found $orphans orphan products! Listing first 10:\n";
        $stmt = $pdo->query("
            SELECT p.id, p.identifier, f.code as family
            FROM pim_catalog_product p
            LEFT JOIN pim_catalog_family f ON p.family_id = f.id
            WHERE p.id NOT IN (SELECT DISTINCT product_id FROM pim_catalog_category_product)
            LIMIT 10
        ");
        while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
            echo "  - SKU: {$row['identifier']}, Family: {$row['family']}\n";
        }
    }
    
    // Categories with product counts
    $stmt = $pdo->query("
        SELECT c.code, c.lvl, COUNT(cp.product_id) as product_count
        FROM pim_catalog_category c
        LEFT JOIN pim_catalog_category_product cp ON c.id = cp.category_id
        GROUP BY c.id
        HAVING product_count = 0
        ORDER BY c.lvl
    ");
    $emptyCategories = $stmt->fetchAll(PDO::FETCH_ASSOC);
    echo "\nCategories with NO products: " . count($emptyCategories) . "\n";
    if (count($emptyCategories) > 0 && count($emptyCategories) <= 10) {
        foreach ($emptyCategories as $cat) {
            echo "  - {$cat['code']} (Level {$cat['lvl']})\n";
        }
    }
    
} catch (Exception $e) {
    echo "⚠️  Error checking product-category relationships: " . $e->getMessage() . "\n";
}

// 2. Check Product-Family-Attribute Relationships
echo "\n--- 2. PRODUCT-FAMILY-ATTRIBUTE RELATIONSHIPS ---\n";
try {
    // Products by family
    $stmt = $pdo->query("
        SELECT f.code as family, COUNT(p.id) as product_count
        FROM pim_catalog_family f
        LEFT JOIN pim_catalog_product p ON f.id = p.family_id
        GROUP BY f.id
        ORDER BY product_count DESC
    ");
    
    echo "Products by Family:\n";
    $totalByFamily = 0;
    while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
        echo "  - {$row['family']}: {$row['product_count']} products\n";
        $totalByFamily += $row['product_count'];
    }
    
    // Products without family
    $stmt = $pdo->query("SELECT COUNT(*) as no_family FROM pim_catalog_product WHERE family_id IS NULL");
    $noFamily = $stmt->fetch()['no_family'];
    echo "\nProducts WITHOUT family: $noFamily\n";
    
    if ($noFamily > 0) {
        echo "⚠️  WARNING: Products without family cannot have proper attributes!\n";
    }
    
} catch (Exception $e) {
    echo "⚠️  Error checking family relationships: " . $e->getMessage() . "\n";
}

// 3. Check Attributes per Family
echo "\n--- 3. ATTRIBUTES PER FAMILY ---\n";
try {
    $stmt = $pdo->query("
        SELECT f.code as family, COUNT(DISTINCT fa.attribute_id) as attr_count
        FROM pim_catalog_family f
        JOIN pim_catalog_family_attribute fa ON f.id = fa.family_id
        GROUP BY f.id
        ORDER BY attr_count DESC
    ");
    
    echo "Attributes assigned to families:\n";
    while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
        echo "  - {$row['family']}: {$row['attr_count']} attributes\n";
    }
    
} catch (Exception $e) {
    echo "⚠️  Error checking family attributes: " . $e->getMessage() . "\n";
}

// 4. Check Product Values (actual data)
echo "\n--- 4. PRODUCT ATTRIBUTE VALUES ---\n";
try {
    // Get schema info first
    $tables = [];
    $stmt = $pdo->query("SHOW TABLES LIKE 'pim%product%value%'");
    while ($row = $stmt->fetch(PDO::FETCH_NUM)) {
        $tables[] = $row[0];
    }
    
    echo "Product value tables found: " . count($tables) . "\n";
    foreach ($tables as $table) {
        $stmt = $pdo->query("SELECT COUNT(*) as cnt FROM $table");
        $count = $stmt->fetch()['cnt'];
        echo "  - $table: $count records\n";
    }
    
} catch (Exception $e) {
    echo "⚠️  Could not check product values: " . $e->getMessage() . "\n";
}

// 5. Check Critical Ecommerce Attributes Coverage
echo "\n--- 5. CRITICAL ECOMMERCE ATTRIBUTES COVERAGE ---\n";
try {
    $criticalAttrs = [
        'sku' => 'SKU/Identifier',
        'name' => 'Product Name',
        'description' => 'Description',
        'short_description' => 'Short Description',
        'price' => 'Price',
        'image' => 'Main Image',
        'thumbnail' => 'Thumbnail',
        'small_image' => 'Small Image',
        'ean' => 'EAN/Barcode',
        'weight' => 'Weight',
        'meta_title' => 'SEO Meta Title',
        'meta_description' => 'SEO Meta Description'
    ];
    
    echo "Checking critical attributes:\n";
    foreach ($criticalAttrs as $code => $label) {
        $stmt = $pdo->prepare("SELECT id, attribute_type FROM pim_catalog_attribute WHERE code = ?");
        $stmt->execute([$code]);
        $attr = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if ($attr) {
            echo "  ✅ $label ($code): EXISTS (type: {$attr['attribute_type']})\n";
        } else {
            echo "  ❌ $label ($code): MISSING\n";
        }
    }
    
} catch (Exception $e) {
    echo "⚠️  Error checking attributes: " . $e->getMessage() . "\n";
}

// 6. Check Product Model Relationships
echo "\n--- 6. PRODUCT MODEL RELATIONSHIPS ---\n";
try {
    // Products linked to models
    $stmt = $pdo->query("
        SELECT COUNT(*) as with_model
        FROM pim_catalog_product
        WHERE product_model_id IS NOT NULL
    ");
    $withModel = $stmt->fetch()['with_model'];
    
    $stmt = $pdo->query("
        SELECT COUNT(*) as without_model
        FROM pim_catalog_product
        WHERE product_model_id IS NULL
    ");
    $withoutModel = $stmt->fetch()['without_model'];
    
    echo "Products WITH product model: $withModel\n";
    echo "Standalone products: $withoutModel\n";
    
    // Models with products
    $stmt = $pdo->query("
        SELECT pm.code, COUNT(p.id) as variant_count
        FROM pim_catalog_product_model pm
        LEFT JOIN pim_catalog_product p ON pm.id = p.product_model_id
        GROUP BY pm.id
        HAVING variant_count > 0
        ORDER BY variant_count DESC
        LIMIT 10
    ");
    
    echo "\nTop 10 Product Models by variant count:\n";
    while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
        echo "  - {$row['code']}: {$row['variant_count']} variants\n";
    }
    
} catch (Exception $e) {
    echo "⚠️  Error checking product models: " . $e->getMessage() . "\n";
}

// 7. Check Channel-Locale Assignments
echo "\n--- 7. CHANNEL-LOCALE ASSIGNMENTS ---\n";
try {
    $stmt = $pdo->query("
        SELECT ch.code as channel, GROUP_CONCAT(l.code SEPARATOR ', ') as locales
        FROM pim_catalog_channel ch
        LEFT JOIN pim_catalog_channel_locale cl ON ch.id = cl.channel_id
        LEFT JOIN pim_catalog_locale l ON cl.locale_id = l.id
        GROUP BY ch.id
    ");
    
    echo "Channel locale assignments:\n";
    while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
        $locales = $row['locales'] ?: 'NONE';
        echo "  - {$row['channel']}: $locales\n";
    }
    
} catch (Exception $e) {
    echo "⚠️  Error checking channel-locale: " . $e->getMessage() . "\n";
}

// 8. Generate Fix Recommendations
echo "\n=== FIX RECOMMENDATIONS ===\n";

$recommendations = [];

if (isset($orphans) && $orphans > 0) {
    $recommendations[] = "❌ CRITICAL: $orphans products without categories - assign to default category";
}

if (isset($noFamily) && $noFamily > 0) {
    $recommendations[] = "❌ CRITICAL: $noFamily products without family - assign to 'default' family";
}

if (count($emptyCategories) > 10) {
    $recommendations[] = "⚠️  WARNING: " . count($emptyCategories) . " empty categories - consider cleanup";
}

if (empty($recommendations)) {
    echo "✅ No critical issues found! All relationships appear healthy.\n";
} else {
    foreach ($recommendations as $rec) {
        echo "$rec\n";
    }
}

echo "\n✅ Comprehensive check complete!\n";
echo "\nLog saved to: comprehensive_relationship_check_" . date('Ymd_His') . ".log\n";
