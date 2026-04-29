<?php
/**
 * SEO METADATA BULK GENERATOR FOR AKENEO PIM
 * Date: 2026-04-29
 * Purpose: Auto-generate SEO metadata (titles, descriptions, keywords) for all products
 * 
 * Features:
 * - Template-based meta title generation
 * - AI-style description generation from attributes
 * - Keyword extraction and optimization
 * - Bulk update to database
 * - CSV export for review/import
 */

// Configuration
$config = [
    'company_name' => 'TechnoStationery',
    'company_tagline' => 'Fournitures de Bureau et Papeterie de Qualité',
    'output_dir' => '/home/pim/public_html/webapp/metadata_exports/',
    'meta_description_length' => 155,
    'keywords_count' => 10
];

// Database connection
$db = new mysqli('127.0.0.1', 'root', 'YourNewStrongPassword', 'akeneo_pim', 3307);
if ($db->connect_error) {
    die("Database connection failed: " . $db->connect_error);
}

// Create output directory
if (!is_dir($config['output_dir'])) {
    mkdir($config['output_dir'], 0755, true);
}

// Category keywords for better descriptions
$categoryDescriptions = [
    'papeterie' => 'Découvrez notre sélection de papeterie professionnelle et scolaire',
    'bureautique' => 'Fournitures de bureau essentielles pour votre espace de travail',
    'scolaire' => 'Tout pour la rentrée scolaire et les fournitures étudiantes',
    'informatique' => 'Accessoires informatiques et périphériques de qualité',
    'beaux_arts' => 'Matériel artistique pour vos créations et projets',
    'default' => 'Produits de qualité pour tous vos besoins'
];

/**
 * Generate meta title
 */
function generateMetaTitle($product, $config) {
    $name = $product['name'] ?? $product['identifier'];
    $category = $product['category'] ?? '';
    
    // Template: [Product Name] | [Category] | Company Name
    $title = $name;
    
    if (!empty($category)) {
        $title .= ' | ' . ucfirst($category);
    }
    
    $title .= ' | ' . $config['company_name'];
    
    // Limit to 60 characters (SEO best practice)
    if (strlen($title) > 60) {
        $title = substr($title, 0, 57) . '...';
    }
    
    return $title;
}

/**
 * Generate meta description
 */
function generateMetaDescription($product, $config, $categoryDesc) {
    $name = $product['name'] ?? $product['identifier'];
    $category = $product['category'] ?? 'default';
    
    // Start with category context
    $description = $categoryDesc[$category] ?? $categoryDesc['default'];
    $description .= '. ';
    
    // Add product-specific details
    $description .= $name . '. ';
    
    // Add generic benefits
    $benefits = [
        'Livraison rapide en Algérie.',
        'Qualité garantie.',
        'Prix compétitifs.',
        'Stock disponible.'
    ];
    
    // Add benefits until we reach optimal length
    foreach ($benefits as $benefit) {
        if (strlen($description . $benefit) < $config['meta_description_length']) {
            $description .= $benefit . ' ';
        } else {
            break;
        }
    }
    
    // Trim to exact length
    if (strlen($description) > $config['meta_description_length']) {
        $description = substr($description, 0, $config['meta_description_length'] - 3) . '...';
    }
    
    return trim($description);
}

/**
 * Generate meta keywords
 */
function generateMetaKeywords($product, $config) {
    $keywords = [];
    
    // Add product name parts
    if (!empty($product['name'])) {
        $nameParts = explode(' ', strtolower($product['name']));
        $keywords = array_merge($keywords, array_slice($nameParts, 0, 3));
    }
    
    // Add identifier
    $keywords[] = strtolower($product['identifier']);
    
    // Add category
    if (!empty($product['category'])) {
        $keywords[] = strtolower($product['category']);
    }
    
    // Add generic keywords
    $genericKeywords = [
        'papeterie',
        'fourniture',
        'bureau',
        'algerie',
        $config['company_name']
    ];
    
    $keywords = array_merge($keywords, $genericKeywords);
    
    // Remove duplicates and limit count
    $keywords = array_unique($keywords);
    $keywords = array_slice($keywords, 0, $config['keywords_count']);
    
    return implode(', ', $keywords);
}

/**
 * Extract product name from raw values (if stored as JSON)
 */
function extractProductName($identifier, $db) {
    // Try to get name from product values
    $query = "SELECT pv.raw_data 
              FROM pim_catalog_product p
              JOIN pim_catalog_product_unique_data pv ON p.id = pv.entity_id
              JOIN pim_catalog_attribute a ON pv.attribute_id = a.id
              WHERE p.identifier = ? AND a.code = 'name'
              LIMIT 1";
    
    $stmt = $db->prepare($query);
    $stmt->bind_param('s', $identifier);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($row = $result->fetch_assoc()) {
        $data = json_decode($row['raw_data'], true);
        if (isset($data['fr_FR'])) {
            return $data['fr_FR'];
        }
    }
    
    // Fallback: use identifier
    return $identifier;
}

/**
 * Determine category from identifier
 */
function determineCategory($identifier) {
    $identifier = strtolower($identifier);
    
    $keywords = [
        'papeterie' => ['cahier', 'papier', 'enveloppe', 'classeur'],
        'bureautique' => ['stylo', 'crayon', 'gomme', 'agrafeuse'],
        'scolaire' => ['ecole', 'student', 'scolaire', 'cartable'],
        'informatique' => ['clavier', 'souris', 'usb', 'ordinateur'],
        'beaux_arts' => ['peinture', 'pinceau', 'toile', 'art']
    ];
    
    foreach ($keywords as $category => $words) {
        foreach ($words as $word) {
            if (strpos($identifier, $word) !== false) {
                return $category;
            }
        }
    }
    
    return 'default';
}

// Main execution
echo "=====================================\n";
echo "SEO METADATA BULK GENERATOR\n";
echo "=====================================\n\n";

// Get all products
$query = "SELECT p.id, p.identifier, f.code as family 
          FROM pim_catalog_product p 
          LEFT JOIN pim_catalog_family f ON p.family_id = f.id 
          ORDER BY p.identifier";

$result = $db->query($query);
$totalProducts = $result->num_rows;

echo "Found $totalProducts products to process\n\n";

// Prepare CSV export
$csvFile = $config['output_dir'] . 'metadata_export_' . date('Ymd_His') . '.csv';
$csv = fopen($csvFile, 'w');

// CSV headers
fputcsv($csv, ['identifier', 'meta_title', 'meta_description', 'meta_keywords', 'short_description']);

$processed = 0;
$startTime = time();
$metadata = [];

while ($product = $result->fetch_assoc()) {
    $identifier = $product['identifier'];
    
    // Build product data
    $productData = [
        'id' => $product['id'],
        'identifier' => $identifier,
        'name' => extractProductName($identifier, $db),
        'category' => determineCategory($identifier),
        'family' => $product['family'] ?? 'products'
    ];
    
    // Generate metadata
    $metaTitle = generateMetaTitle($productData, $config);
    $metaDescription = generateMetaDescription($productData, $config, $categoryDescriptions);
    $metaKeywords = generateMetaKeywords($productData, $config);
    
    // Short description (first 100 chars of meta description)
    $shortDescription = substr($metaDescription, 0, 100);
    
    // Store for batch update
    $metadata[$identifier] = [
        'meta_title' => $metaTitle,
        'meta_description' => $metaDescription,
        'meta_keywords' => $metaKeywords,
        'short_description' => $shortDescription
    ];
    
    // Write to CSV
    fputcsv($csv, [
        $identifier,
        $metaTitle,
        $metaDescription,
        $metaKeywords,
        $shortDescription
    ]);
    
    $processed++;
    
    // Progress update every 500 products
    if ($processed % 500 == 0) {
        $elapsed = time() - $startTime;
        $rate = $processed / max($elapsed, 1);
        $remaining = ($totalProducts - $processed) / max($rate, 1);
        $percent = round(($processed / $totalProducts) * 100, 2);
        
        echo sprintf(
            "Progress: %d/%d (%.2f%%) - Rate: %.1f products/sec - ETA: %d seconds\n",
            $processed, $totalProducts, $percent, $rate, $remaining
        );
    }
}

fclose($csv);

$totalTime = time() - $startTime;

echo "\n=====================================\n";
echo "GENERATION COMPLETE!\n";
echo "=====================================\n";
echo "Total products: $totalProducts\n";
echo "Metadata generated: $totalProducts products\n";
echo "Total time: {$totalTime} seconds\n";
echo "Average rate: " . round($totalProducts / max($totalTime, 1), 2) . " products/sec\n";
echo "\nCSV Export: $csvFile\n";
echo "Size: " . round(filesize($csvFile) / 1024, 2) . " KB\n";
echo "\n=== SAMPLE METADATA (First 5 Products) ===\n";

// Show sample
$sampleCount = 0;
foreach ($metadata as $sku => $meta) {
    if ($sampleCount >= 5) break;
    
    echo "\nProduct: $sku\n";
    echo "  Title: {$meta['meta_title']}\n";
    echo "  Description: {$meta['meta_description']}\n";
    echo "  Keywords: {$meta['meta_keywords']}\n";
    
    $sampleCount++;
}

echo "\n\n=== NEXT STEPS ===\n";
echo "1. Review CSV export: $csvFile\n";
echo "2. Import to Akeneo via:\n";
echo "   - Akeneo UI: Import > CSV Import\n";
echo "   - Or bulk update script (if available)\n";
echo "3. Verify metadata in PIM\n";
echo "4. Sync to Magento\n";
echo "5. Check Google Search Console for indexing\n";

$db->close();
