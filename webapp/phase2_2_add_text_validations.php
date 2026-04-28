<?php
/**
 * Phase 1.2 & 2.2: Add Text Validation Rules
 * Date: 2026-04-28
 * 
 * Uses Akeneo's validation columns correctly:
 * - validation_rule: type (varchar 10)
 * - validation_regexp: pattern (varchar 500)
 * - max_characters, number_min, number_max, etc.
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

try {
    $pdo = new PDO($dsn, $user, $pass, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC
    ]);
    
    echo "✓ Connected to database\n\n";
    
    // ========================================
    // Phase 2.2: Add Text Validation Rules
    // ========================================
    echo "=== Phase 2.2: Adding Text Validation Rules ===\n";
    
    $validationsAdded = 0;
    
    // SKU validation (regexp)
    echo "\n1. SKU Validation:\n";
    $stmt = $pdo->prepare("SELECT id, validation_rule, validation_regexp FROM pim_catalog_attribute WHERE code = 'sku'");
    $stmt->execute();
    $sku = $stmt->fetch();
    
    if ($sku && (empty($sku['validation_regexp']) || $sku['validation_regexp'] === null)) {
        $stmt = $pdo->prepare("
            UPDATE pim_catalog_attribute 
            SET validation_rule = 'regexp', 
                validation_regexp = ?
            WHERE id = ?
        ");
        $stmt->execute(['^[A-Z0-9-_]{3,50}$', $sku['id']]);
        echo "  ✓ Added regexp validation for SKU\n";
        $validationsAdded++;
    } else {
        echo "  - SKU validation already configured\n";
    }
    
    // Name validation (max characters)
    echo "\n2. Name Validation:\n";
    $stmt = $pdo->prepare("SELECT id, max_characters FROM pim_catalog_attribute WHERE code = 'name'");
    $stmt->execute();
    $name = $stmt->fetch();
    
    if ($name && (empty($name['max_characters']) || $name['max_characters'] === null)) {
        $stmt = $pdo->prepare("UPDATE pim_catalog_attribute SET max_characters = ? WHERE id = ?");
        $stmt->execute([255, $name['id']]);
        echo "  ✓ Set max_characters=255 for name\n";
        $validationsAdded++;
    } else {
        echo "  - Name validation already configured (max: {$name['max_characters']})\n";
    }
    
    // Description validation (max characters)
    echo "\n3. Description Validation:\n";
    $stmt = $pdo->prepare("SELECT id, max_characters FROM pim_catalog_attribute WHERE code = 'description'");
    $stmt->execute();
    $desc = $stmt->fetch();
    
    if ($desc && (empty($desc['max_characters']) || $desc['max_characters'] === null)) {
        $stmt = $pdo->prepare("UPDATE pim_catalog_attribute SET max_characters = ? WHERE id = ?");
        $stmt->execute([5000, $desc['id']]);
        echo "  ✓ Set max_characters=5000 for description\n";
        $validationsAdded++;
    } else {
        echo "  - Description validation already configured (max: {$desc['max_characters']})\n";
    }
    
    // Short description validation
    echo "\n4. Short Description Validation:\n";
    $stmt = $pdo->prepare("SELECT id, max_characters FROM pim_catalog_attribute WHERE code = 'short_description'");
    $stmt->execute();
    $shortDesc = $stmt->fetch();
    
    if ($shortDesc && (empty($shortDesc['max_characters']) || $shortDesc['max_characters'] === null)) {
        $stmt = $pdo->prepare("UPDATE pim_catalog_attribute SET max_characters = ? WHERE id = ?");
        $stmt->execute([500, $shortDesc['id']]);
        echo "  ✓ Set max_characters=500 for short_description\n";
        $validationsAdded++;
    } else {
        echo "  - Short description validation already configured\n";
    }
    
    // URL Key validation (regexp)
    echo "\n5. URL Key Validation:\n";
    $stmt = $pdo->prepare("SELECT id, validation_rule, validation_regexp FROM pim_catalog_attribute WHERE code = 'url_key'");
    $stmt->execute();
    $urlKey = $stmt->fetch();
    
    if ($urlKey && (empty($urlKey['validation_regexp']) || $urlKey['validation_regexp'] === null)) {
        $stmt = $pdo->prepare("
            UPDATE pim_catalog_attribute 
            SET validation_rule = 'regexp',
                validation_regexp = ?
            WHERE id = ?
        ");
        $stmt->execute(['^[a-z0-9-]+$', $urlKey['id']]);
        echo "  ✓ Added regexp validation for url_key\n";
        $validationsAdded++;
    } else {
        echo "  - URL key validation already configured\n";
    }
    
    echo "\n";
    echo "=== Summary ===\n";
    echo "✓ Text validation rules added: {$validationsAdded}\n";
    echo "✓ Total validation rules: " . ($validationsAdded + 2) . " (including price & weight)\n";
    echo "\n";
    echo "Next steps:\n";
    echo "1. Clear cache: bin/console cache:clear --env=prod\n";
    echo "2. Test validations in Akeneo UI\n";
    echo "3. Run completeness calculation\n";
    echo "\n";
    
} catch (Exception $e) {
    echo "ERROR: " . $e->getMessage() . "\n";
    exit(1);
}
