<?php
/**
 * PLACEHOLDER IMAGE GENERATOR FOR AKENEO PIM
 * Date: 2026-04-29
 * Purpose: Generate professional placeholder images for products without images
 * 
 * Features:
 * - Category-specific color schemes
 * - Product SKU overlay
 * - "Image Coming Soon" branding
 * - Multiple sizes (1200x1200, 600x600, 300x300)
 * - Batch processing with progress tracking
 */

// Configuration
$config = [
    'output_dir' => '/home/pim/product_images/placeholders/',
    'sizes' => [
        'large' => ['width' => 1200, 'height' => 1200],
        'medium' => ['width' => 600, 'height' => 600],
        'thumbnail' => ['width' => 300, 'height' => 300]
    ],
    'font_path' => '/usr/share/fonts/dejavu/DejaVuSans-Bold.ttf',
    'company_name' => 'TechnoStationery'
];

// Category color schemes (professional palette)
$categoryColors = [
    'papeterie' => ['bg' => [240, 240, 250], 'accent' => [100, 120, 200], 'text' => [50, 50, 50]],
    'bureautique' => ['bg' => [245, 250, 245], 'accent' => [80, 150, 80], 'text' => [40, 40, 40]],
    'scolaire' => ['bg' => [255, 250, 240], 'accent' => [255, 180, 50], 'text' => [60, 60, 60]],
    'informatique' => ['bg' => [240, 245, 255], 'accent' => [50, 100, 200], 'text' => [30, 30, 30]],
    'beaux_arts' => ['bg' => [255, 245, 250], 'accent' => [200, 80, 150], 'text' => [50, 50, 50]],
    'default' => ['bg' => [248, 248, 248], 'accent' => [120, 120, 120], 'text' => [80, 80, 80]]
];

// Database connection
$db = new mysqli('127.0.0.1', 'root', 'YourNewStrongPassword', 'akeneo_pim', 3307);
if ($db->connect_error) {
    die("Database connection failed: " . $db->connect_error);
}

// Create output directories
foreach (['large', 'medium', 'thumbnail'] as $size) {
    $dir = $config['output_dir'] . $size;
    if (!is_dir($dir)) {
        mkdir($dir, 0755, true);
    }
}

/**
 * Generate placeholder image
 */
function generatePlaceholder($sku, $category, $size, $config, $colors) {
    $width = $size['width'];
    $height = $size['height'];
    
    // Create image
    $image = imagecreatetruecolor($width, $height);
    
    // Colors
    $bgColor = imagecolorallocate($image, $colors['bg'][0], $colors['bg'][1], $colors['bg'][2]);
    $accentColor = imagecolorallocate($image, $colors['accent'][0], $colors['accent'][1], $colors['accent'][2]);
    $textColor = imagecolorallocate($image, $colors['text'][0], $colors['text'][1], $colors['text'][2]);
    $borderColor = imagecolorallocate($image, 220, 220, 220);
    
    // Fill background
    imagefilledrectangle($image, 0, 0, $width, $height, $bgColor);
    
    // Draw border
    imagerectangle($image, 0, 0, $width - 1, $height - 1, $borderColor);
    
    // Draw accent shape (centered rectangle)
    $accentWidth = $width * 0.6;
    $accentHeight = $height * 0.4;
    $accentX = ($width - $accentWidth) / 2;
    $accentY = ($height - $accentHeight) / 2;
    imagefilledrectangle($image, $accentX, $accentY, $accentX + $accentWidth, $accentY + $accentHeight, $accentColor);
    
    // Check if font exists, otherwise use built-in font
    $useCustomFont = file_exists($config['font_path']);
    
    // Text settings
    $centerX = $width / 2;
    $centerY = $height / 2;
    
    if ($useCustomFont) {
        // Main text: "Image Coming Soon"
        $mainText = "Image Coming Soon";
        $fontSize = $width * 0.04;
        $textBox = imagettfbbox($fontSize, 0, $config['font_path'], $mainText);
        $textWidth = $textBox[2] - $textBox[0];
        $textX = $centerX - ($textWidth / 2);
        $textY = $centerY - 20;
        imagettftext($image, $fontSize, 0, $textX, $textY, $textColor, $config['font_path'], $mainText);
        
        // SKU
        $skuText = "SKU: " . $sku;
        $skuFontSize = $width * 0.03;
        $skuBox = imagettfbbox($skuFontSize, 0, $config['font_path'], $skuText);
        $skuWidth = $skuBox[2] - $skuBox[0];
        $skuX = $centerX - ($skuWidth / 2);
        $skuY = $centerY + 40;
        imagettftext($image, $skuFontSize, 0, $skuX, $skuY, $textColor, $config['font_path'], $skuText);
        
        // Company name
        $companyFontSize = $width * 0.025;
        $companyBox = imagettfbbox($companyFontSize, 0, $config['font_path'], $config['company_name']);
        $companyWidth = $companyBox[2] - $companyBox[0];
        $companyX = $centerX - ($companyWidth / 2);
        $companyY = $height - 40;
        imagettftext($image, $companyFontSize, 0, $companyX, $companyY, $accentColor, $config['font_path'], $config['company_name']);
    } else {
        // Fallback to built-in font
        $mainText = "Image Coming Soon";
        imagestring($image, 5, $centerX - 80, $centerY - 20, $mainText, $textColor);
        
        $skuText = "SKU: " . $sku;
        imagestring($image, 4, $centerX - 60, $centerY + 20, $skuText, $textColor);
        
        imagestring($image, 3, $centerX - 80, $height - 30, $config['company_name'], $accentColor);
    }
    
    return $image;
}

/**
 * Determine category from product identifier or family
 */
function determineCategory($product) {
    $identifier = strtolower($product['identifier']);
    $family = strtolower($product['family'] ?? 'default');
    
    // Try to match category keywords
    $keywords = [
        'papeterie' => ['cahier', 'papier', 'enveloppe', 'classeur'],
        'bureautique' => ['stylo', 'crayon', 'gomme', 'agrafeuse'],
        'scolaire' => ['ecole', 'student', 'scolaire', 'cartable'],
        'informatique' => ['clavier', 'souris', 'usb', 'ordinateur'],
        'beaux_arts' => ['peinture', 'pinceau', 'toile', 'art']
    ];
    
    foreach ($keywords as $category => $words) {
        foreach ($words as $word) {
            if (strpos($identifier, $word) !== false || strpos($family, $word) !== false) {
                return $category;
            }
        }
    }
    
    return 'default';
}

// Main execution
echo "=====================================\n";
echo "PLACEHOLDER IMAGE GENERATOR\n";
echo "=====================================\n\n";

// Get all products
$query = "SELECT p.identifier, f.code as family 
          FROM pim_catalog_product p 
          LEFT JOIN pim_catalog_family f ON p.family_id = f.id 
          ORDER BY p.identifier";

$result = $db->query($query);
$totalProducts = $result->num_rows;

echo "Found $totalProducts products to process\n";
echo "Output directory: {$config['output_dir']}\n\n";

$processed = 0;
$startTime = time();

while ($product = $result->fetch_assoc()) {
    $sku = $product['identifier'];
    $category = determineCategory($product);
    $colors = $categoryColors[$category] ?? $categoryColors['default'];
    
    // Generate images in all sizes
    foreach ($config['sizes'] as $sizeName => $size) {
        $image = generatePlaceholder($sku, $category, $size, $config, $colors);
        $filename = $config['output_dir'] . $sizeName . '/' . $sku . '.jpg';
        imagejpeg($image, $filename, 90);
        imagedestroy($image);
    }
    
    $processed++;
    
    // Progress update every 100 products
    if ($processed % 100 == 0) {
        $elapsed = time() - $startTime;
        $rate = $processed / max($elapsed, 1);
        $remaining = ($totalProducts - $processed) / max($rate, 1);
        $percent = round(($processed / $totalProducts) * 100, 2);
        
        echo sprintf(
            "Progress: %d/%d (%.2f%%) - Rate: %.1f imgs/sec - ETA: %d seconds\n",
            $processed, $totalProducts, $percent, $rate, $remaining
        );
    }
}

$totalTime = time() - $startTime;

echo "\n=====================================\n";
echo "GENERATION COMPLETE!\n";
echo "=====================================\n";
echo "Total products: $totalProducts\n";
echo "Images generated: " . ($totalProducts * 3) . " (3 sizes each)\n";
echo "Total time: {$totalTime} seconds\n";
echo "Average rate: " . round($totalProducts / max($totalTime, 1), 2) . " products/sec\n";
echo "\nOutput locations:\n";
echo "- Large (1200x1200): {$config['output_dir']}large/\n";
echo "- Medium (600x600): {$config['output_dir']}medium/\n";
echo "- Thumbnail (300x300): {$config['output_dir']}thumbnail/\n";
echo "\nNext step: Run IMAGE_BULK_UPLOADER.php to import to Akeneo\n";

$db->close();
