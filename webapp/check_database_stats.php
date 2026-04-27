<?php
// Bootstrap Symfony to access services
require_once __DIR__ . '/../vendor/autoload.php';

use Symfony\Component\Dotenv\Dotenv;

// Load environment variables
$dotenv = new Dotenv();
$dotenv->load(__DIR__ . '/../.env');

echo "=========================================\n";
echo "DATABASE STATISTICS CHECK\n";
echo "Date: " . date('Y-m-d H:i:s') . "\n";
echo "=========================================\n\n";

// Get database URL from environment
$databaseUrl = $_ENV['DATABASE_URL'] ?? getenv('DATABASE_URL');
echo "Database URL: " . preg_replace('/:[^:@]+@/', ':****@', $databaseUrl) . "\n\n";

// Parse the URL
if (preg_match('/mysql:\/\/([^:]+):([^@]+)@([^:]+):(\d+)\/([^?]+)/', $databaseUrl, $matches)) {
    $user = $matches[1];
    $pass = $matches[2];
    $host = $matches[3];
    $port = $matches[4];
    $dbname = $matches[5];
    
    try {
        $dsn = "mysql:host=$host;port=$port;dbname=$dbname;charset=utf8mb4";
        $pdo = new PDO($dsn, $user, $pass);
        $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
        
        echo "✓ Database connection successful\n\n";
        
        // Get product counts
        echo "1. PRODUCTS:\n";
        $stmt = $pdo->query("SELECT COUNT(*) as count FROM pim_catalog_product");
        $total = $stmt->fetch(PDO::FETCH_ASSOC)['count'];
        
        $stmt = $pdo->query("SELECT COUNT(*) as count FROM pim_catalog_product WHERE is_enabled = 1");
        $enabled = $stmt->fetch(PDO::FETCH_ASSOC)['count'];
        
        echo "   Total: $total\n";
        echo "   Enabled: $enabled\n";
        echo "   Disabled: " . ($total - $enabled) . "\n\n";
        
        // Get category counts
        echo "2. CATEGORIES:\n";
        $stmt = $pdo->query("SELECT COUNT(*) as count FROM pim_catalog_category");
        $categories = $stmt->fetch(PDO::FETCH_ASSOC)['count'];
        echo "   Total: $categories\n\n";
        
        // Get attribute counts
        echo "3. ATTRIBUTES:\n";
        $stmt = $pdo->query("SELECT COUNT(*) as count FROM pim_catalog_attribute");
        $attributes = $stmt->fetch(PDO::FETCH_ASSOC)['count'];
        echo "   Total: $attributes\n";
        
        $stmt = $pdo->query("SELECT attribute_type, COUNT(*) as count FROM pim_catalog_attribute GROUP BY attribute_type ORDER BY count DESC");
        echo "   By Type:\n";
        while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
            echo "      - {$row['attribute_type']}: {$row['count']}\n";
        }
        echo "\n";
        
        // Get attribute group counts
        echo "4. ATTRIBUTE GROUPS:\n";
        $stmt = $pdo->query("SELECT COUNT(*) as count FROM pim_catalog_attribute_group");
        $groups = $stmt->fetch(PDO::FETCH_ASSOC)['count'];
        echo "   Total: $groups\n";
        
        $stmt = $pdo->query("
            SELECT g.code, g.sort_order, COUNT(a.id) as attr_count
            FROM pim_catalog_attribute_group g
            LEFT JOIN pim_catalog_attribute a ON a.group_id = g.id
            GROUP BY g.id
            ORDER BY g.sort_order, g.code
        ");
        echo "   Details:\n";
        while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
            echo "      - {$row['code']}: {$row['attr_count']} attributes\n";
        }
        echo "\n";
        
        // Get family counts
        echo "5. FAMILIES:\n";
        $stmt = $pdo->query("SELECT COUNT(*) as count FROM pim_catalog_family");
        $families = $stmt->fetch(PDO::FETCH_ASSOC)['count'];
        echo "   Total: $families\n";
        
        $stmt = $pdo->query("
            SELECT f.code, COUNT(DISTINCT p.id) as product_count
            FROM pim_catalog_family f
            LEFT JOIN pim_catalog_product p ON p.family_id = f.id
            GROUP BY f.id
            ORDER BY product_count DESC
            LIMIT 10
        ");
        echo "   Top 10 families by product count:\n";
        while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
            echo "      - {$row['code']}: {$row['product_count']} products\n";
        }
        echo "\n";
        
        // Get channel counts
        echo "6. CHANNELS:\n";
        $stmt = $pdo->query("SELECT COUNT(*) as count FROM pim_catalog_channel");
        $channels = $stmt->fetch(PDO::FETCH_ASSOC)['count'];
        echo "   Total: $channels\n";
        
        $stmt = $pdo->query("SELECT code FROM pim_catalog_channel");
        echo "   Channels:\n";
        while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
            echo "      - {$row['code']}\n";
        }
        echo "\n";
        
        // Get locale counts
        echo "7. LOCALES:\n";
        $stmt = $pdo->query("SELECT COUNT(*) as count FROM pim_catalog_locale WHERE is_activated = 1");
        $locales = $stmt->fetch(PDO::FETCH_ASSOC)['count'];
        echo "   Active: $locales\n";
        
        $stmt = $pdo->query("SELECT code FROM pim_catalog_locale WHERE is_activated = 1");
        echo "   Active locales:\n";
        $localeList = [];
        while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
            $localeList[] = $row['code'];
        }
        echo "      " . implode(', ', $localeList) . "\n\n";
        
        // Summary
        echo "=========================================\n";
        echo "SUMMARY\n";
        echo "=========================================\n";
        echo "Products: $total (enabled: $enabled)\n";
        echo "Categories: $categories\n";
        echo "Attributes: $attributes\n";
        echo "Attribute Groups: $groups\n";
        echo "Families: $families\n";
        echo "Channels: $channels\n";
        echo "Active Locales: $locales\n";
        echo "=========================================\n";
        
    } catch (PDOException $e) {
        echo "✗ Database error: " . $e->getMessage() . "\n";
    }
} else {
    echo "✗ Could not parse DATABASE_URL\n";
}

