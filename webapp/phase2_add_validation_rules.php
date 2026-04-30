<?php
/**
 * PHASE 2.1-2.3: ADD VALIDATION RULES FOR ATTRIBUTES
 * 
 * This script adds comprehensive validation rules to prevent invalid data entry:
 * - Numeric validations (price, weight, dimensions)
 * - Text validations (SKU, names, descriptions)
 * - File/Media validations (images, documents)
 * 
 * Usage: php /home/pim/public_html/webapp/phase2_add_validation_rules.php
 * Run as: pim user
 * 
 * IMPORTANT: Backup database before running!
 */

error_reporting(E_ALL);
ini_set('display_errors', 1);

$akeneo_db = [
    'host' => '127.0.0.1',
    'port' => '3307',
    'database' => 'akeneo_pim',
    'user' => 'akeneo_pim',
    'password' => 'akeneo_pim'
];

try {
    $dsn = "mysql:host={$akeneo_db['host']};port={$akeneo_db['port']};dbname={$akeneo_db['database']};charset=utf8mb4";
    $pdo = new PDO($dsn, $akeneo_db['user'], $akeneo_db['password'], [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC
    ]);
    echo "✅ Connected to Akeneo PIM database\n\n";
} catch (PDOException $e) {
    echo "❌ Database connection failed: " . $e->getMessage() . "\n";
    exit(1);
}

echo "=" . str_repeat("=", 79) . "\n";
echo "PHASE 2: ADD VALIDATION RULES & REORGANIZE ATTRIBUTE GROUPS\n";
echo "Date: " . date('Y-m-d H:i:s') . "\n";
echo "=" . str_repeat("=", 79) . "\n\n";

$stats = [
    'numeric_validations' => 0,
    'text_validations' => 0,
    'file_validations' => 0,
    'errors' => 0,
];

###############################################################################
# SECTION 1: NUMERIC ATTRIBUTE VALIDATION
###############################################################################
echo "SECTION 1: Adding Numeric Attribute Validations\n";
echo str_repeat("-", 80) . "\n\n";

$numeric_rules = [
    'price' => [
        'number_min' => 0.01,
        'number_max' => 1000000.00,
        'decimals_allowed' => 1,
        'negative_allowed' => 0,
        'description' => 'Price must be between 0.01 and 1,000,000 with up to 2 decimals'
    ],
    'special_price' => [
        'number_min' => 0.01,
        'number_max' => 1000000.00,
        'decimals_allowed' => 1,
        'negative_allowed' => 0,
        'description' => 'Special price must be between 0.01 and 1,000,000'
    ],
    'cost' => [
        'number_min' => 0,
        'number_max' => 1000000.00,
        'decimals_allowed' => 1,
        'negative_allowed' => 0,
        'description' => 'Cost must be non-negative'
    ],
    'weight' => [
        'number_min' => 1,
        'number_max' => 100000,
        'decimals_allowed' => 0,
        'negative_allowed' => 0,
        'description' => 'Weight must be positive integer (grams)'
    ],
    'quantity' => [
        'number_min' => 0,
        'number_max' => 999999,
        'decimals_allowed' => 0,
        'negative_allowed' => 0,
        'description' => 'Quantity must be non-negative integer'
    ],
    'length' => [
        'number_min' => 0.1,
        'number_max' => 10000,
        'decimals_allowed' => 1,
        'negative_allowed' => 0,
        'description' => 'Length must be positive (millimeters)'
    ],
    'width' => [
        'number_min' => 0.1,
        'number_max' => 10000,
        'decimals_allowed' => 1,
        'negative_allowed' => 0,
        'description' => 'Width must be positive (millimeters)'
    ],
    'height' => [
        'number_min' => 0.1,
        'number_max' => 10000,
        'decimals_allowed' => 1,
        'negative_allowed' => 0,
        'description' => 'Height must be positive (millimeters)'
    ],
    'pages' => [
        'number_min' => 1,
        'number_max' => 10000,
        'decimals_allowed' => 0,
        'negative_allowed' => 0,
        'description' => 'Pages must be positive integer'
    ],
];

foreach ($numeric_rules as $code => $rules) {
    // Check if attribute exists
    $attr = $pdo->prepare("SELECT id, attribute_type FROM pim_catalog_attribute WHERE code = ?");
    $attr->execute([$code]);
    $row = $attr->fetch();
    
    if (!$row) {
        echo "  ⚠️ Attribute '$code' not found, skipping\n";
        continue;
    }
    
    if ($row['attribute_type'] !== 'pim_catalog_number') {
        echo "  ⚠️ Attribute '$code' is not a number type ({$row['attribute_type']}), skipping\n";
        continue;
    }
    
    // Update validation rules
    $update = $pdo->prepare("
        UPDATE pim_catalog_attribute SET
            number_min = ?,
            number_max = ?,
            decimals_allowed = ?,
            negative_allowed = ?
        WHERE code = ?
    ");
    
    try {
        $update->execute([
            $rules['number_min'],
            $rules['number_max'],
            $rules['decimals_allowed'],
            $rules['negative_allowed'],
            $code
        ]);
        
        echo "  ✅ {$code}: {$rules['description']}\n";
        $stats['numeric_validations']++;
    } catch (PDOException $e) {
        echo "  ❌ {$code}: Error - " . $e->getMessage() . "\n";
        $stats['errors']++;
    }
}

echo "\nNumeric validations added: {$stats['numeric_validations']}\n\n";

###############################################################################
# SECTION 2: TEXT ATTRIBUTE VALIDATION
###############################################################################
echo "SECTION 2: Adding Text Attribute Validations\n";
echo str_repeat("-", 80) . "\n\n";

$text_rules = [
    'sku' => [
        'validation_regexp' => '^[A-Z0-9][A-Z0-9_-]{2,62}[A-Z0-9]$',
        'max_characters' => 64,
        'description' => 'SKU: Alphanumeric with hyphens/underscores, 4-64 chars'
    ],
    'url_key' => [
        'validation_regexp' => '^[a-z0-9][a-z0-9-]{2,253}$',
        'max_characters' => 255,
        'description' => 'URL Key: Lowercase alphanumeric with hyphens, max 255 chars'
    ],
    'name' => [
        'validation_regexp' => '^.+$',
        'max_characters' => 255,
        'description' => 'Name: Required, max 255 chars'
    ],
    'description' => [
        'max_characters' => 2000,
        'description' => 'Description: Max 2000 chars'
    ],
    'short_description' => [
        'max_characters' => 500,
        'description' => 'Short description: Max 500 chars'
    ],
    'meta_title' => [
        'max_characters' => 70,
        'description' => 'Meta title: Max 70 chars (SEO best practice)'
    ],
    'meta_description' => [
        'max_characters' => 160,
        'description' => 'Meta description: Max 160 chars (SEO best practice)'
    ],
    'meta_keywords' => [
        'max_characters' => 255,
        'description' => 'Meta keywords: Max 255 chars'
    ],
    'ean13' => [
        'validation_regexp' => '^\d{13}$',
        'max_characters' => 13,
        'description' => 'EAN-13: Exactly 13 digits'
    ],
];

foreach ($text_rules as $code => $rules) {
    // Check if attribute exists
    $attr = $pdo->prepare("SELECT id, attribute_type FROM pim_catalog_attribute WHERE code = ?");
    $attr->execute([$code]);
    $row = $attr->fetch();
    
    if (!$row) {
        echo "  ⚠️ Attribute '$code' not found, skipping\n";
        continue;
    }
    
    if (!in_array($row['attribute_type'], ['pim_catalog_text', 'pim_catalog_textarea'])) {
        echo "  ⚠️ Attribute '$code' is not a text type ({$row['attribute_type']}), skipping\n";
        continue;
    }
    
    // Update validation rules
    $update = $pdo->prepare("
        UPDATE pim_catalog_attribute SET
            validation_regexp = ?,
            max_characters = ?
        WHERE code = ?
    ");
    
    try {
        $update->execute([
            $rules['validation_regexp'] ?? null,
            $rules['max_characters'] ?? null,
            $code
        ]);
        
        echo "  ✅ {$code}: {$rules['description']}\n";
        $stats['text_validations']++;
    } catch (PDOException $e) {
        echo "  ❌ {$code}: Error - " . $e->getMessage() . "\n";
        $stats['errors']++;
    }
}

echo "\nText validations added: {$stats['text_validations']}\n\n";

###############################################################################
# SECTION 3: FILE/MEDIA VALIDATION
###############################################################################
echo "SECTION 3: Adding File/Media Validations\n";
echo str_repeat("-", 80) . "\n\n";

$file_rules = [
    'image' => [
        'allowed_extensions' => 'jpg,jpeg,png,webp',
        'max_file_size' => 2.00,
        'description' => 'Image: JPEG/PNG/WebP, max 2MB'
    ],
    'image_alt' => [
        'allowed_extensions' => 'jpg,jpeg,png,webp',
        'max_file_size' => 2.00,
        'description' => 'Alt image: JPEG/PNG/WebP, max 2MB'
    ],
    'small_image' => [
        'allowed_extensions' => 'jpg,jpeg,png,webp',
        'max_file_size' => 1.00,
        'description' => 'Small image: JPEG/PNG/WebP, max 1MB'
    ],
    'thumbnail' => [
        'allowed_extensions' => 'jpg,jpeg,png,webp',
        'max_file_size' => 0.50,
        'description' => 'Thumbnail: JPEG/PNG/WebP, max 500KB'
    ],
    'datasheet' => [
        'allowed_extensions' => 'pdf',
        'max_file_size' => 5.00,
        'description' => 'Datasheet: PDF only, max 5MB'
    ],
    'certificate' => [
        'allowed_extensions' => 'pdf',
        'max_file_size' => 3.00,
        'description' => 'Certificate: PDF only, max 3MB'
    ],
    'video' => [
        'allowed_extensions' => 'mp4,webm',
        'max_file_size' => 50.00,
        'description' => 'Video: MP4/WebM, max 50MB'
    ],
    'attachment' => [
        'allowed_extensions' => 'pdf,doc,docx,xls,xlsx',
        'max_file_size' => 10.00,
        'description' => 'Attachment: PDF/DOC/XLS, max 10MB'
    ],
];

foreach ($file_rules as $code => $rules) {
    // Check if attribute exists
    $attr = $pdo->prepare("SELECT id, attribute_type FROM pim_catalog_attribute WHERE code = ?");
    $attr->execute([$code]);
    $row = $attr->fetch();
    
    if (!$row) {
        echo "  ⚠️ Attribute '$code' not found, skipping\n";
        continue;
    }
    
    if ($row['attribute_type'] !== 'pim_catalog_image') {
        echo "  ⚠️ Attribute '$code' is not an image type ({$row['attribute_type']}), skipping\n";
        continue;
    }
    
    // Update validation rules
    $update = $pdo->prepare("
        UPDATE pim_catalog_attribute SET
            allowed_extensions = ?,
            max_file_size = ?
        WHERE code = ?
    ");
    
    try {
        $update->execute([
            $rules['allowed_extensions'],
            $rules['max_file_size'],
            $code
        ]);
        
        echo "  ✅ {$code}: {$rules['description']}\n";
        $stats['file_validations']++;
    } catch (PDOException $e) {
        echo "  ❌ {$code}: Error - " . $e->getMessage() . "\n";
        $stats['errors']++;
    }
}

echo "\nFile/media validations added: {$stats['file_validations']}\n\n";

###############################################################################
# SUMMARY
###############################################################################
echo str_repeat("=", 80) . "\n";
echo "PHASE 2 VALIDATION RULES SUMMARY\n";
echo str_repeat("=", 80) . "\n\n";

echo "Numeric validations: {$stats['numeric_validations']}\n";
echo "Text validations: {$stats['text_validations']}\n";
echo "File validations: {$stats['file_validations']}\n";
echo "Errors: {$stats['errors']}\n\n";

$total_validations = $stats['numeric_validations'] + $stats['text_validations'] + $stats['file_validations'];
echo "Total validations added: $total_validations\n";

// Verify total
$with_validation = $pdo->query("
    SELECT COUNT(*) FROM pim_catalog_attribute 
    WHERE validation_rule IS NOT NULL 
       OR validation_regexp IS NOT NULL
       OR number_min IS NOT NULL
       OR max_characters IS NOT NULL
       OR allowed_extensions IS NOT NULL
")->fetchColumn();

echo "Total attributes with validation: $with_validation / 112\n\n";

if ($stats['errors'] == 0) {
    echo "✅ Phase 2 validation rules added successfully!\n\n";
    echo "Next steps:\n";
    echo "1. Test validations in Akeneo UI - try entering invalid data\n";
    echo "2. Verify error messages appear correctly\n";
    echo "3. Run Phase 2.4: Reorganize attribute groups\n";
    echo "4. Run Phase 2.5: Consolidate color options\n";
} else {
    echo "⚠️ Phase 2 completed with {$stats['errors']} errors\n";
    echo "Please review the errors above.\n";
}

echo "\n" . date('Y-m-d H:i:s') . "\n";
