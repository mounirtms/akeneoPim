<?php
/**
 * QUICK SEO METADATA GENERATOR (FIXED VERSION)
 * Generates SEO metadata for all products with proper error handling
 * Date: 2026-04-29
 */

error_reporting(E_ALL);
ini_set('display_errors', 1);
set_time_limit(600); // 10 minutes

echo "=========================================\n";
echo "  SEO METADATA GENERATOR (FIXED)\n";
echo "=========================================\n";
echo "Date: " . date('Y-m-d H:i:s') . "\n\n";

// Configuration
$config = [
    'company_name' => 'TechnoStationery',
    'company_tagline' => 'Fournitures de Bureau et Papeterie de Qualité',
    'output_dir' => '/home/pim/public_html/webapp/metadata_exports/',
    'meta_description_length' => 155,
    'keywords_count' => 10
];

// Database connection
try {
    $pdo = new PDO(
        'mysql:host=127.0.0.1;port=3307;dbname=akeneo_pim;charset=utf8mb4',
        'akeneo_pim',
        'akeneo_pim',
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
    );
    echo "✓ Database connected\n\n";
} catch (PDOException $e) {
    die("❌ Connection failed: " . $e->getMessage() . "\n");
}

// Create output directory
if (!is_dir($config['output_dir'])) {
    mkdir($config['output_dir'], 0755, true);
}

// Category descriptions
$categoryDescriptions = [
    'papeterie' => 'Découvrez notre sélection de papeterie professionnelle et scolaire',
    'bureautique' => 'Fournitures de bureau essentielles pour votre espace de travail',
    'scolaire' => 'Tout pour la rentrée scolaire et les fournitures étudiantes',
    'informatique' => 'Accessoires informatiques et périphériques de qualité',
    'beaux_arts' => 'Matériel artistique pour vos créations et projets',
    'default' => 'Produits de qualité pour tous vos besoins'
];

// Functions
function generateMetaTitle($sku, $family, $config) {
    $title = $sku;
    if (!empty($family) && $family != 'products') {
        $title .= ' | ' . ucfirst($family);
    }
    $title .= ' | ' . $config['company_name'];
    
    if (strlen($title) > 60) {
        $title = substr($title, 0, 57) . '...';
    }
    
    return $title;
}

function generateMetaDescription($sku, $family, $config, $categoryDescriptions) {
    $description = $categoryDescriptions['default'] . '. ';
    $description .= 'Référence ' . $sku . '. ';
    
    $benefits = [
        'Livraison rapide en Algérie.',
        'Qualité garantie.',
        'Prix compétitifs.',
        'Stock disponible.'
    ];
    
    foreach ($benefits as $benefit) {
        if (strlen($description . $benefit) < $config['meta_description_length']) {
            $description .= $benefit . ' ';
        } else {
            break;
        }
    }
    
    if (strlen($description) > $config['meta_description_length']) {
        $description = substr($description, 0, $config['meta_description_length'] - 3) . '...';
    }
    
    return trim($description);
}

function generateMetaKeywords($sku, $family, $config) {
    $keywords = [];
    
    $keywords[] = strtolower($sku);
    
    if (!empty($family)) {
        $keywords[] = strtolower($family);
    }
    
    $genericKeywords = [
        'papeterie',
        'fourniture',
        'bureau',
        'algerie',
        'technostationery'
    ];
    
    $keywords = array_merge($keywords, $genericKeywords);
    $keywords = array_unique($keywords);
    $keywords = array_slice($keywords, 0, $config['keywords_count']);
    
    return implode(', ', $keywords);
}

// Main execution
echo "Step 1: Fetching products...\n";
echo "─────────────────────────────────────────\n";

$stmt = $pdo->query("
    SELECT p.id, p.identifier, f.code as family 
    FROM pim_catalog_product p 
    LEFT JOIN pim_catalog_family f ON p.family_id = f.id 
    ORDER BY p.identifier
");

$products = $stmt->fetchAll(PDO::FETCH_ASSOC);
$totalProducts = count($products);

echo "✓ Found $totalProducts products\n\n";

if ($totalProducts == 0) {
    die("❌ No products found in database\n");
}

// Prepare CSV export
echo "Step 2: Generating metadata...\n";
echo "─────────────────────────────────────────\n";

$csvFile = $config['output_dir'] . 'metadata_export_' . date('Ymd_His') . '.csv';
$csv = fopen($csvFile, 'w');

// CSV headers
fputcsv($csv, ['identifier', 'meta_title', 'meta_description', 'meta_keywords', 'short_description']);

$processed = 0;
$startTime = time();

foreach ($products as $product) {
    $identifier = $product['identifier'];
    $family = $product['family'] ?? 'products';
    
    // Generate metadata
    $metaTitle = generateMetaTitle($identifier, $family, $config);
    $metaDescription = generateMetaDescription($identifier, $family, $config, $categoryDescriptions);
    $metaKeywords = generateMetaKeywords($identifier, $family, $config);
    $shortDescription = substr($metaDescription, 0, 100);
    
    // Write to CSV
    fputcsv($csv, [
        $identifier,
        $metaTitle,
        $metaDescription,
        $metaKeywords,
        $shortDescription
    ]);
    
    $processed++;
    
    // Progress update every 1000 products
    if ($processed % 1000 == 0) {
        $elapsed = time() - $startTime;
        $rate = $processed / max($elapsed, 1);
        $remaining = ($totalProducts - $processed) / max($rate, 1);
        $percent = round(($processed / $totalProducts) * 100, 2);
        
        echo sprintf(
            "Progress: %d/%d (%.2f%%) - %.1f products/sec - ETA: %d sec\n",
            $processed, $totalProducts, $percent, $rate, (int)$remaining
        );
    }
}

fclose($csv);

$totalTime = time() - $startTime;

echo "\n=========================================\n";
echo "  GENERATION COMPLETE!\n";
echo "=========================================\n";
echo "Total products: $totalProducts\n";
echo "Metadata generated: $processed products\n";
echo "Total time: {$totalTime} seconds\n";
echo "Average rate: " . round($totalProducts / max($totalTime, 1), 2) . " products/sec\n";
echo "\nCSV Export:\n";
echo "  File: $csvFile\n";
echo "  Size: " . round(filesize($csvFile) / 1024, 2) . " KB\n";
echo "  Lines: " . ($processed + 1) . " (including header)\n";

// Show sample
echo "\n=== SAMPLE METADATA (First 5 Products) ===\n";
$csvRead = fopen($csvFile, 'r');
$header = fgetcsv($csvRead);
$sampleCount = 0;

while (($row = fgetcsv($csvRead)) !== false && $sampleCount < 5) {
    echo "\nProduct: {$row[0]}\n";
    echo "  Title: {$row[1]}\n";
    echo "  Description: {$row[2]}\n";
    echo "  Keywords: {$row[3]}\n";
    $sampleCount++;
}
fclose($csvRead);

echo "\n=========================================\n";
echo "✓ SEO metadata generation complete!\n";
echo "=========================================\n\n";

echo "NEXT STEPS:\n";
echo "1. Review CSV file: $csvFile\n";
echo "2. Import to Akeneo:\n";
echo "   - Log into https://pim.technostationery.com\n";
echo "   - Create import profile: product_seo_metadata_import\n";
echo "   - Upload CSV file\n";
echo "   - Map columns to attributes\n";
echo "   - Run import\n";
echo "3. Recalculate completeness:\n";
echo "   cd /home/pim/public_html\n";
echo "   php bin/console pim:completeness:calculate\n";
echo "\n";
