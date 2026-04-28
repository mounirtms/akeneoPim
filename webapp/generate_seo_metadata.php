<?php
/**
 * SEO Metadata Generation Script
 * Date: 2026-04-28
 * 
 * Generates missing SEO metadata for all products:
 * - url_key: Generated from product name (slugified)
 * - meta_title: Generated from product name
 * - meta_description: Generated from description or name
 * - meta_keyword: Generated from name + category
 */

require_once __DIR__ . '/../vendor/autoload.php';

use Symfony\Component\Dotenv\Dotenv;

$dotenv = new Dotenv();
$dotenv->load(__DIR__ . '/../.env');

$host = '127.0.0.1';
$port = '3307';
$dbname = 'akeneo_pim';
$user = 'root';
$pass = 'YourNewStrongPassword';

$dsn = "mysql:host={$host};port={$port};dbname={$dbname};charset=utf8mb4";

// Dry run mode - set to false to actually generate metadata
$DRY_RUN = true;

function slugify($text) {
    // Replace non letter or digits by -
    $text = preg_replace('~[^\pL\d]+~u', '-', $text);
    // Transliterate
    $text = iconv('utf-8', 'us-ascii//TRANSLIT', $text);
    // Remove unwanted characters
    $text = preg_replace('~[^-\w]+~', '', $text);
    // Trim
    $text = trim($text, '-');
    // Remove duplicate -
    $text = preg_replace('~-+~', '-', $text);
    // Lowercase
    $text = strtolower($text);
    
    if (empty($text)) {
        return 'n-a';
    }
    
    return $text;
}

try {
    $pdo = new PDO($dsn, $user, $pass, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC
    ]);
    
    echo "================================================================================\n";
    echo "SEO METADATA GENERATION FOR AKENEO PRODUCTS\n";
    echo "Date: " . date('Y-m-d H:i:s') . "\n";
    echo "Mode: " . ($DRY_RUN ? "DRY RUN (no changes)" : "LIVE (will update database)") . "\n";
    echo "================================================================================\n\n";
    
    // Get all products
    $stmt = $pdo->query("
        SELECT 
            p.id,
            p.identifier as sku,
            p.raw_values
        FROM pim_catalog_product p
        WHERE p.is_enabled = 1
        LIMIT 10
    ");
    
    $products = $stmt->fetchAll();
    $totalProducts = count($products);
    
    echo "Found {$totalProducts} products to process\n\n";
    
    $updated = 0;
    $skipped = 0;
    
    foreach ($products as $product) {
        $sku = $product['sku'];
        $rawValues = json_decode($product['raw_values'], true);
        
        // Extract product name (English)
        $name = null;
        if (isset($rawValues['name']['<all_channels>']['en_US'])) {
            $name = $rawValues['name']['<all_channels>']['en_US'];
        }
        
        if (!$name) {
            echo "  ⚠️  Skipping {$sku}: No English name found\n";
            $skipped++;
            continue;
        }
        
        // Generate SEO metadata
        $urlKey = slugify($name);
        $metaTitle = substr($name, 0, 255); // Max 255 chars
        
        // Extract description for meta_description
        $description = null;
        if (isset($rawValues['description']['<all_channels>']['en_US'])) {
            $description = strip_tags($rawValues['description']['<all_channels>']['en_US']);
            $description = substr($description, 0, 500); // Max 500 chars
        }
        
        $metaDescription = $description ? substr($description, 0, 160) : substr($name, 0, 160);
        $metaKeyword = strtolower($name);
        
        echo "  Processing: {$sku}\n";
        echo "    Name: {$name}\n";
        echo "    URL Key: {$urlKey}\n";
        echo "    Meta Title: {$metaTitle}\n";
        echo "    Meta Description: " . substr($metaDescription, 0, 50) . "...\n";
        
        if (!$DRY_RUN) {
            // Update raw_values with new SEO fields
            $rawValues['url_key']['<all_channels>']['<all_locales>'] = $urlKey;
            $rawValues['meta_title']['<all_channels>']['en_US'] = $metaTitle;
            $rawValues['meta_description']['<all_channels>']['en_US'] = $metaDescription;
            $rawValues['meta_keyword']['<all_channels>']['en_US'] = $metaKeyword;
            
            $newRawValues = json_encode($rawValues);
            
            $updateStmt = $pdo->prepare("
                UPDATE pim_catalog_product 
                SET raw_values = ?, 
                    updated = NOW()
                WHERE id = ?
            ");
            $updateStmt->execute([$newRawValues, $product['id']]);
            
            $updated++;
        } else {
            $updated++;
        }
        
        echo "\n";
        
        if ($updated >= 10 && $DRY_RUN) {
            echo "  [DRY RUN] Showing first 10 products only...\n";
            break;
        }
    }
    
    echo "\n";
    echo "================================================================================\n";
    echo "SUMMARY\n";
    echo "================================================================================\n";
    echo "Total products found: {$totalProducts}\n";
    echo "Products processed: {$updated}\n";
    echo "Products skipped: {$skipped}\n";
    
    if ($DRY_RUN) {
        echo "\n⚠️  DRY RUN MODE - No changes were made to the database\n";
        echo "To apply changes, set \$DRY_RUN = false in the script\n";
    } else {
        echo "\n✅ SUCCESS - SEO metadata has been generated!\n";
        echo "\nNext steps:\n";
        echo "1. Clear Akeneo cache: bin/console cache:clear --env=prod\n";
        echo "2. Reindex Elasticsearch: bin/console akeneo:elasticsearch:reset-indexes --env=prod\n";
        echo "3. Verify in Akeneo UI\n";
    }
    
    echo "\n";
    
} catch (Exception $e) {
    echo "ERROR: " . $e->getMessage() . "\n";
    echo "Stack trace:\n" . $e->getTraceAsString() . "\n";
    exit(1);
}
