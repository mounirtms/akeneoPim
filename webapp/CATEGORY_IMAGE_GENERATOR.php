#!/usr/bin/env php
<?php
/**
 * CATEGORY IMAGE GENERATOR FOR AKENEO PIM
 * Generates professional category images (hero banners + thumbnails)
 * 
 * @author Techno DZ
 * @date 2026-04-29
 */

// Configuration
$config = [
    'output_dir' => '/home/pim/category_images',
    'hero_size' => [1920, 600],
    'thumb_size' => [400, 400],
    'icon_size' => [200, 200],
];

// Database configuration
$db_config = [
    'host' => '127.0.0.1',
    'port' => '3307',
    'database' => 'akeneo_pim',
    'username' => 'akeneo_pim',
    'password' => 'akeneo_pim',
];

// Color schemes for categories
$categoryColors = [
    'default' => ['#2C3E50', '#3498DB'],
    'writing' => ['#8E44AD', '#9B59B6'],
    'office' => ['#2980B9', '#3498DB'],
    'school' => ['#E67E22', '#F39C12'],
    'art' => ['#E74C3C', '#C0392B'],
    'organization' => ['#16A085', '#1ABC9C'],
    'paper' => ['#34495E', '#7F8C8D'],
    'technology' => ['#2C3E50', '#34495E'],
    'gifts' => ['#D35400', '#E67E22'],
    'seasonal' => ['#27AE60', '#2ECC71'],
];

echo "\n";
echo "=========================================\n";
echo "  CATEGORY IMAGE GENERATOR\n";
echo "=========================================\n";
echo "Date: " . date('Y-m-d H:i:s') . "\n\n";

// Create output directories
@mkdir($config['output_dir'], 0755, true);
@mkdir($config['output_dir'] . '/hero', 0755, true);
@mkdir($config['output_dir'] . '/thumbnail', 0755, true);
@mkdir($config['output_dir'] . '/icon', 0755, true);
echo "✓ Output directories created\n";

// Connect to database
try {
    $dsn = "mysql:host={$db_config['host']};port={$db_config['port']};dbname={$db_config['database']};charset=utf8mb4";
    $pdo = new PDO($dsn, $db_config['username'], $db_config['password'], [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    ]);
    echo "✓ Database connected\n";
} catch (PDOException $e) {
    die("✗ Database connection failed: " . $e->getMessage() . "\n");
}

// Get categories
$query = "
    SELECT code, 
           COALESCE(
               JSON_UNQUOTE(JSON_EXTRACT(labels, '$.en_US')),
               JSON_UNQUOTE(JSON_EXTRACT(labels, '$.fr_FR')),
               code
           ) as label
    FROM pim_catalog_category 
    WHERE code != 'master'
    ORDER BY code
";

$stmt = $pdo->query($query);
$categories = $stmt->fetchAll();
$total = count($categories);

echo "✓ Found {$total} categories to process\n\n";

// Function to get category colors
function getCategoryColors($label, $categoryColors) {
    $label_lower = strtolower($label);
    
    foreach ($categoryColors as $key => $colors) {
        if (stripos($label_lower, $key) !== false) {
            return $colors;
        }
    }
    
    return $categoryColors['default'];
}

// Function to hex to RGB
function hexToRgb($hex) {
    $hex = str_replace('#', '', $hex);
    return [
        hexdec(substr($hex, 0, 2)),
        hexdec(substr($hex, 2, 2)),
        hexdec(substr($hex, 4, 2))
    ];
}

// Function to generate gradient image
function generateImage($width, $height, $color1, $color2, $text, $fontSize) {
    $image = imagecreatetruecolor($width, $height);
    
    $rgb1 = hexToRgb($color1);
    $rgb2 = hexToRgb($color2);
    
    // Create gradient
    for ($y = 0; $y < $height; $y++) {
        $ratio = $y / $height;
        $r = $rgb1[0] + ($rgb2[0] - $rgb1[0]) * $ratio;
        $g = $rgb1[1] + ($rgb2[1] - $rgb1[1]) * $ratio;
        $b = $rgb1[2] + ($rgb2[2] - $rgb1[2]) * $ratio;
        
        $color = imagecolorallocate($image, $r, $g, $b);
        imageline($image, 0, $y, $width, $y, $color);
    }
    
    // Add text
    $white = imagecolorallocate($image, 255, 255, 255);
    $black = imagecolorallocatealpha($image, 0, 0, 0, 50);
    
    // Use default font (GD built-in)
    $textWidth = imagefontwidth(5) * strlen($text);
    $x = ($width - $textWidth) / 2;
    $y = ($height - imagefontheight(5)) / 2;
    
    // Shadow
    imagestring($image, 5, $x + 2, $y + 2, $text, $black);
    // Text
    imagestring($image, 5, $x, $y, $text, $white);
    
    return $image;
}

// Process categories
$processed = 0;
$startTime = microtime(true);

foreach ($categories as $category) {
    $code = $category['code'];
    $label = preg_replace('/[^a-zA-Z0-9 ]/', '', $category['label']);
    if (empty($label)) $label = $code;
    
    // Limit label length
    if (strlen($label) > 30) {
        $label = substr($label, 0, 27) . '...';
    }
    
    // Get colors
    $colors = getCategoryColors($label, $categoryColors);
    
    // Generate hero banner
    $hero = generateImage($config['hero_size'][0], $config['hero_size'][1], $colors[0], $colors[1], strtoupper($label), 5);
    imagejpeg($hero, $config['output_dir'] . '/hero/' . $code . '.jpg', 85);
    imagedestroy($hero);
    
    // Generate thumbnail
    $thumb = generateImage($config['thumb_size'][0], $config['thumb_size'][1], $colors[0], $colors[1], $label, 4);
    imagejpeg($thumb, $config['output_dir'] . '/thumbnail/' . $code . '.jpg', 85);
    imagedestroy($thumb);
    
    // Generate icon
    $firstLetter = strtoupper(substr($label, 0, 1));
    $icon = imagecreatetruecolor($config['icon_size'][0], $config['icon_size'][1]);
    $rgb = hexToRgb($colors[0]);
    $bgColor = imagecolorallocate($icon, $rgb[0], $rgb[1], $rgb[2]);
    imagefill($icon, 0, 0, $bgColor);
    
    $white = imagecolorallocate($icon, 255, 255, 255);
    $textWidth = imagefontwidth(5) * strlen($firstLetter);
    $x = ($config['icon_size'][0] - $textWidth) / 2;
    $y = ($config['icon_size'][1] - imagefontheight(5)) / 2;
    imagestring($icon, 5, $x, $y, $firstLetter, $white);
    
    imagejpeg($icon, $config['output_dir'] . '/icon/' . $code . '.jpg', 85);
    imagedestroy($icon);
    
    $processed++;
    
    if ($processed % 10 === 0) {
        $elapsed = microtime(true) - $startTime;
        $rate = $processed / $elapsed;
        $eta = ($total - $processed) / $rate;
        
        echo sprintf(
            "\rProgress: %d/%d (%.1f%%) | Rate: %.1f/s | ETA: %s",
            $processed,
            $total,
            ($processed / $total) * 100,
            $rate,
            gmdate('H:i:s', $eta)
        );
    }
}

echo "\n\n";

// Generate CSV import file
$csvFile = $config['output_dir'] . '/category_images_import_' . date('Ymd_His') . '.csv';
$csv = fopen($csvFile, 'w');
fputcsv($csv, ['code', 'hero_image', 'thumbnail_image', 'icon_image']);

foreach ($categories as $category) {
    fputcsv($csv, [
        $category['code'],
        $config['output_dir'] . '/hero/' . $category['code'] . '.jpg',
        $config['output_dir'] . '/thumbnail/' . $category['code'] . '.jpg',
        $config['output_dir'] . '/icon/' . $category['code'] . '.jpg',
    ]);
}
fclose($csv);

// Summary
$elapsed = microtime(true) - $startTime;
$heroCount = count(glob($config['output_dir'] . '/hero/*.jpg'));
$thumbCount = count(glob($config['output_dir'] . '/thumbnail/*.jpg'));
$iconCount = count(glob($config['output_dir'] . '/icon/*.jpg'));

echo "=========================================\n";
echo "  GENERATION COMPLETE\n";
echo "=========================================\n";
echo "Categories processed: {$processed}\n";
echo "Hero banners: {$heroCount}\n";
echo "Thumbnails: {$thumbCount}\n";
echo "Icons: {$iconCount}\n";
echo "Total images: " . ($heroCount + $thumbCount + $iconCount) . "\n";
echo "Processing time: " . gmdate('H:i:s', $elapsed) . "\n";
echo "\nOutput directory: {$config['output_dir']}/\n";
echo "CSV import file: {$csvFile}\n\n";

echo "NEXT STEPS:\n";
echo "1. Review images in: {$config['output_dir']}/\n";
echo "2. Import via Akeneo UI or API\n";
echo "3. Assign to categories via bulk import\n";
echo "4. Sync to Magento\n\n";

echo "✓ Category image generation completed!\n\n";
