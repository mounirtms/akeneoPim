<?php
/**
 * PHASE 2.1: ADD NUMERIC VALIDATION RULES
 * Date: 2026-04-27
 * Purpose: Add validation rules for numeric attributes (price, weight, quantity, etc.)
 * 
 * This script will:
 * 1. Add validation for price (> 0, decimals allowed)
 * 2. Add validation for weight (> 0)
 * 3. Add validation for quantity (>= 0)
 * 4. Add validation for dimensions
 */

error_reporting(E_ALL);
ini_set('display_errors', 1);

$host = '127.0.0.1';
$port = '3307';
$dbname = 'akeneo_pim';
$username = 'akeneo_pim';
$password = 'akeneo_pim';

try {
    $pdo = new PDO("mysql:host=$host;port=$port;dbname=$dbname;charset=utf8mb4", $username, $password);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    echo "\n" . str_repeat("=", 80) . "\n";
    echo "PHASE 2.1: ADD NUMERIC VALIDATION RULES\n";
    echo "Date: " . date('Y-m-d H:i:s') . "\n";
    echo str_repeat("=", 80) . "\n\n";
} catch (PDOException $e) {
    die("Database connection failed: " . $e->getMessage() . "\n");
}

$DRY_RUN = false; // Set to false to apply changes

echo "Mode: " . ($DRY_RUN ? "DRY RUN" : "LIVE") . "\n\n";

// Define validation rules for numeric attributes
$numericValidations = [
    'price' => [
        'number_min' => 0.01,
        'number_max' => 1000000.00,
        'decimals_allowed' => true,
        'negative_allowed' => false,
        'description' => 'Price must be between 0.01 and 1,000,000'
    ],
    'weight' => [
        'number_min' => 0.01,
        'number_max' => 999999,
        'decimals_allowed' => true,
        'negative_allowed' => false,
        'description' => 'Weight in grams, must be positive'
    ],
    'qty' => [
        'number_min' => 0,
        'number_max' => 999999,
        'decimals_allowed' => false,
        'negative_allowed' => false,
        'description' => 'Quantity must be >= 0'
    ],
    'quantity' => [
        'number_min' => 0,
        'number_max' => 999999,
        'decimals_allowed' => false,
        'negative_allowed' => false,
        'description' => 'Quantity must be >= 0'
    ],
];

echo "Configuring validation rules...\n";
echo str_repeat("-", 80) . "\n\n";

$configured = 0;
$skipped = 0;
$notFound = 0;

foreach ($numericValidations as $attrCode => $rules) {
    // Check if attribute exists
    $stmt = $pdo->prepare("SELECT id, attribute_type FROM pim_catalog_attribute WHERE code = ?");
    $stmt->execute([$attrCode]);
    $attr = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$attr) {
        echo "⚠ Attribute '$attrCode' not found - skipping\n";
        $notFound++;
        continue;
    }
    
    // Check if it's a numeric type
    $numericTypes = ['pim_catalog_number', 'pim_catalog_metric', 'pim_catalog_price_collection'];
    if (!in_array($attr['attribute_type'], $numericTypes)) {
        echo "⚠ Attribute '$attrCode' is not numeric (type: {$attr['attribute_type']}) - skipping\n";
        $skipped++;
        continue;
    }
    
    echo "Attribute: $attrCode (ID: {$attr['id']})\n";
    echo "  Rule: {$rules['description']}\n";
    
    if (!$DRY_RUN) {
        $stmt = $pdo->prepare("
            UPDATE pim_catalog_attribute 
            SET number_min = ?,
                number_max = ?,
                decimals_allowed = ?,
                negative_allowed = ?
            WHERE id = ?
        ");
        
        $stmt->execute([
            $rules['number_min'],
            $rules['number_max'],
            $rules['decimals_allowed'] ? 1 : 0,
            $rules['negative_allowed'] ? 1 : 0,
            $attr['id']
        ]);
        
        echo "  ✓ Configured\n";
        $configured++;
    } else {
        echo "  [DRY RUN] Would configure\n";
        $configured++;
    }
    
    echo "\n";
}

echo str_repeat("-", 80) . "\n";
echo "Summary:\n";
echo "  Configured: $configured\n";
echo "  Skipped (wrong type): $skipped\n";
echo "  Not found: $notFound\n\n";

// Verification
echo str_repeat("=", 80) . "\n";
echo "VERIFICATION\n";
echo str_repeat("=", 80) . "\n\n";

$stmt = $pdo->query("
    SELECT 
        code,
        attribute_type,
        number_min,
        number_max,
        decimals_allowed,
        negative_allowed
    FROM pim_catalog_attribute
    WHERE number_min IS NOT NULL OR number_max IS NOT NULL
    ORDER BY code
");

$results = $stmt->fetchAll(PDO::FETCH_ASSOC);

echo "Attributes with numeric validation:\n\n";
printf("%-20s | %-25s | %-10s | %-10s | Decimals | Negative\n", "Code", "Type", "Min", "Max");
echo str_repeat("-", 100) . "\n";

foreach ($results as $row) {
    printf("%-20s | %-25s | %-10s | %-10s | %-8s | %s\n",
        $row['code'],
        $row['attribute_type'],
        $row['number_min'] ?? '-',
        $row['number_max'] ?? '-',
        $row['decimals_allowed'] ? 'Yes' : 'No',
        $row['negative_allowed'] ? 'Yes' : 'No'
    );
}

echo "\n" . str_repeat("=", 80) . "\n";
if (!$DRY_RUN) {
    echo "✅ Numeric validation rules configured!\n";
} else {
    echo "This was a DRY RUN. Set \$DRY_RUN = false to apply.\n";
}
echo str_repeat("=", 80) . "\n\n";
