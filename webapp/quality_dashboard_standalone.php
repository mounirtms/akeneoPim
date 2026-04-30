#!/usr/bin/env php
<?php
/**
 * Akeneo PIM - Manual Data Quality Dashboard (Standalone)
 * Direct database connection without Symfony bootstrap
 */

// Database configuration
$dbHost = '127.0.0.1';
$dbPort = '3307';
$dbName = 'akeneo_pim';
$dbUser = 'akeneo_pim';
$dbPass = 'akeneo_pim';

try {
    $pdo = new PDO(
        "mysql:host=$dbHost;port=$dbPort;dbname=$dbName;charset=utf8mb4",
        $dbUser,
        $dbPass,
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
    );
    
    echo "\n";
    echo "=========================================\n";
    echo "Akeneo PIM - Data Quality Dashboard\n";
    echo "Generated: " . date('Y-m-d H:i:s') . "\n";
    echo "=========================================\n\n";
    
    // 1. Total Products
    $totalProducts = $pdo->query("SELECT COUNT(*) FROM pim_catalog_product")->fetchColumn();
    echo "📊 PRODUCT OVERVIEW\n";
    echo "-------------------------------------------\n";
    echo "Total Products: " . number_format($totalProducts) . "\n\n";
    
    // 2. Products by Family
    echo "📁 PRODUCTS BY FAMILY\n";
    echo "-------------------------------------------\n";
    $stmt = $pdo->query("
        SELECT 
            f.code as family,
            COUNT(p.id) as count,
            ROUND(COUNT(p.id) * 100.0 / $totalProducts, 2) as percentage
        FROM pim_catalog_product p
        JOIN pim_catalog_family f ON f.id = p.family_id
        GROUP BY f.code
        ORDER BY count DESC
    ");
    
    while ($family = $stmt->fetch(PDO::FETCH_ASSOC)) {
        printf("%-30s %6d products (%5.1f%%)\n", 
            $family['family'], 
            $family['count'], 
            $family['percentage']
        );
    }
    echo "\n";
    
    // 3. Completeness by Key Attributes
    echo "✅ ATTRIBUTE COMPLETENESS\n";
    echo "-------------------------------------------\n";
    
    // Count products with price (DZD)
    $withPrice = $pdo->query("
        SELECT COUNT(*) 
        FROM pim_catalog_product 
        WHERE raw_values LIKE '%\"price\"%' 
        AND raw_values LIKE '%DZD%'
    ")->fetchColumn();
    printf("Products with Price (DZD):    %6d / %6d (%5.1f%%)\n", 
        $withPrice, $totalProducts, ($withPrice/$totalProducts)*100);
    
    // Count products with name (fr_FR)
    $withName = $pdo->query("
        SELECT COUNT(DISTINCT p.id)
        FROM pim_catalog_product p
        WHERE p.raw_values LIKE '%\"name\"%' 
        AND p.raw_values LIKE '%fr_FR%'
    ")->fetchColumn();
    printf("Products with Name (fr_FR):   %6d / %6d (%5.1f%%)\n", 
        $withName, $totalProducts, ($withName/$totalProducts)*100);
    
    // Count products with description
    $withDesc = $pdo->query("
        SELECT COUNT(DISTINCT p.id)
        FROM pim_catalog_product p
        WHERE p.raw_values LIKE '%\"description\"%'
    ")->fetchColumn();
    printf("Products with Description:    %6d / %6d (%5.1f%%)\n", 
        $withDesc, $totalProducts, ($withDesc/$totalProducts)*100);
    
    // Count products with categories
    $withCategories = $pdo->query("
        SELECT COUNT(DISTINCT product_id) 
        FROM pim_catalog_category_product
    ")->fetchColumn();
    printf("Products with Categories:     %6d / %6d (%5.1f%%)\n", 
        $withCategories, $totalProducts, ($withCategories/$totalProducts)*100);
    
    echo "\n";
    
    // 4. Category Coverage
    echo "📂 CATEGORY DISTRIBUTION\n";
    echo "-------------------------------------------\n";
    $totalCategories = $pdo->query("SELECT COUNT(*) FROM pim_catalog_category")->fetchColumn();
    $categoriesWithProducts = $pdo->query("
        SELECT COUNT(DISTINCT c.id)
        FROM pim_catalog_category c
        JOIN pim_catalog_category_product cp ON cp.category_id = c.id
    ")->fetchColumn();
    $totalCategoryLinks = $pdo->query("SELECT COUNT(*) FROM pim_catalog_category_product")->fetchColumn();
    
    echo "Total Categories: " . $totalCategories . "\n";
    echo "Categories with Products: " . $categoriesWithProducts . " (" . 
        round(($categoriesWithProducts/$totalCategories)*100, 1) . "%)\n";
    echo "Total Category Assignments: " . number_format($totalCategoryLinks) . "\n";
    echo "Avg Categories per Product: " . round($totalCategoryLinks/$totalProducts, 2) . "\n\n";
    
    // 5. Top Categories
    echo "🏆 TOP 10 CATEGORIES BY PRODUCT COUNT\n";
    echo "-------------------------------------------\n";
    $stmt = $pdo->query("
        SELECT 
            c.code,
            COUNT(cp.product_id) as product_count
        FROM pim_catalog_category c
        JOIN pim_catalog_category_product cp ON cp.category_id = c.id
        GROUP BY c.id, c.code
        ORDER BY product_count DESC
        LIMIT 10
    ");
    
    while ($cat = $stmt->fetch(PDO::FETCH_ASSOC)) {
        printf("%-40s %6d products\n", $cat['code'], $cat['product_count']);
    }
    echo "\n";
    
    // 6. Currency Usage
    echo "💰 CURRENCY CONFIGURATION\n";
    echo "-------------------------------------------\n";
    $stmt = $pdo->query("
        SELECT code, is_activated 
        FROM pim_catalog_currency 
        WHERE is_activated = 1
    ");
    
    echo "Active Currencies:\n";
    while ($curr = $stmt->fetch(PDO::FETCH_ASSOC)) {
        echo "  - " . $curr['code'] . "\n";
    }
    echo "\n";
    
    // 7. Locale Configuration
    echo "🌍 LOCALE CONFIGURATION\n";
    echo "-------------------------------------------\n";
    $stmt = $pdo->query("
        SELECT code, is_activated 
        FROM pim_catalog_locale 
        WHERE is_activated = 1
    ");
    
    echo "Active Locales:\n";
    while ($loc = $stmt->fetch(PDO::FETCH_ASSOC)) {
        echo "  - " . $loc['code'] . "\n";
    }
    echo "\n";
    
    // 8. Overall Quality Score
    echo "⭐ OVERALL QUALITY SCORE\n";
    echo "-------------------------------------------\n";
    
    $priceScore = ($withPrice/$totalProducts) * 100;
    $nameScore = ($withName/$totalProducts) * 100;
    $descScore = ($withDesc/$totalProducts) * 100;
    $catScore = ($withCategories/$totalProducts) * 100;
    
    $overallScore = ($priceScore + $nameScore + $descScore + $catScore) / 4;
    
    printf("Price Completeness:       %5.1f%%\n", $priceScore);
    printf("Name Completeness:        %5.1f%%\n", $nameScore);
    printf("Description Completeness: %5.1f%%\n", $descScore);
    printf("Category Assignment:      %5.1f%%\n", $catScore);
    echo "-------------------------------------------\n";
    printf("OVERALL QUALITY SCORE:    %5.1f%% ", $overallScore);
    
    if ($overallScore >= 95) {
        echo "🌟 EXCELLENT\n";
    } elseif ($overallScore >= 85) {
        echo "✅ GOOD\n";
    } elseif ($overallScore >= 75) {
        echo "⚠️  NEEDS IMPROVEMENT\n";
    } else {
        echo "❌ POOR\n";
    }
    
    echo "\n";
    
    // 9. Recommendations
    echo "💡 RECOMMENDATIONS\n";
    echo "-------------------------------------------\n";
    
    if ($nameScore < 95) {
        $missing = $totalProducts - $withName;
        echo "⚠️  Add names to " . $missing . " products\n";
    }
    
    if ($descScore < 95) {
        $missing = $totalProducts - $withDesc;
        echo "⚠️  Add descriptions to " . $missing . " products\n";
    }
    
    if ($catScore < 100) {
        $missing = $totalProducts - $withCategories;
        echo "⚠️  Assign categories to " . $missing . " products\n";
    }
    
    if ($overallScore >= 95) {
        echo "✅ Catalog quality is excellent! Keep maintaining it.\n";
    }
    
    echo "\n=========================================\n";
    echo "Dashboard generation complete!\n";
    echo "=========================================\n\n";
    
    exit(0);
    
} catch (Exception $e) {
    echo "❌ Error: " . $e->getMessage() . "\n\n";
    exit(1);
}
