<?php
/**
 * PHASE 1.2: ADD ENGLISH (en_US) TRANSLATIONS FOR LOCALIZABLE ATTRIBUTES
 * 
 * This script adds missing English translations for all localizable attributes.
 * Currently all translations are in French (fr_FR) only.
 * 
 * Usage: php /home/pim/public_html/webapp/phase1_add_english_translations.php
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
echo "PHASE 1.2: ADD ENGLISH (en_US) TRANSLATIONS\n";
echo "Date: " . date('Y-m-d H:i:s') . "\n";
echo "=" . str_repeat("=", 79) . "\n\n";

// Get all localizable attributes
$localizable = $pdo->query("
    SELECT a.id, a.code, t.label as fr_label, t.locale
    FROM pim_catalog_attribute a
    LEFT JOIN pim_catalog_attribute_translation t ON a.id = t.foreign_key AND t.locale = 'fr_FR'
    WHERE a.is_localizable = 1
    ORDER BY a.code
")->fetchAll();

echo "Found " . count($localizable) . " localizable attributes\n\n";

// Translation mapping (French to English)
// For common attributes, we use standard translations
// For custom attributes, we'll use the French label as-is or derive from code
$translation_map = [
    // Core attributes
    'name' => 'Name',
    'description' => 'Description',
    'short_description' => 'Short Description',
    'url_key' => 'URL Key',
    'meta_title' => 'Meta Title',
    'meta_description' => 'Meta Description',
    'meta_keywords' => 'Meta Keywords',
    'meta_keyword' => 'Meta Keyword',
    
    // Amasty attributes
    'amasty_preorder_cart_label' => 'Pre-Order Cart Label',
    'amasty_preorder_note' => 'Pre-Order Note',
    
    // Other Magento-related
    'amtoolkit_canonical' => 'Canonical URL',
    'category_ids' => 'Category IDs',
    'custom_layout_update' => 'Custom Layout Update',
    'en_promo' => 'Promo (EN)',
    'gallery' => 'Gallery',
    'has_options' => 'Has Options',
    'image_label' => 'Image Label',
    'links_title' => 'Links Title',
    'media_gallery' => 'Media Gallery',
    'mwishlist_sku' => 'Wishlist SKU',
    'quickorder_sku' => 'Quick Order SKU',
    'required_options' => 'Required Options',
    'news_from_date' => 'News From Date',
    'news_to_date' => 'News To Date',
    'gift_message_available' => 'Gift Message Available',
    'gift_message_recipient' => 'Gift Message Recipient',
    'gift_message_sender' => 'Gift Message Sender',
    'gift_message_message' => 'Gift Message',
    'options_container' => 'Options Container',
    'custom_design' => 'Custom Design',
    'custom_design_from' => 'Custom Design From',
    'custom_design_to' => 'Custom Design To',
    'page_layout' => 'Page Layout',
];

echo "Translation Strategy:\n";
echo "1. Use predefined English translations for known attributes\n";
echo "2. Derive from attribute code (convert snake_case to Title Case) for others\n";
echo "3. Use French label as fallback if available\n\n";

$stats = [
    'total_localizable' => count($localizable),
    'already_translated' => 0,
    'added' => 0,
    'errors' => 0,
];

echo "Processing translations...\n\n";

foreach ($localizable as $attr) {
    $code = $attr['code'];
    $fr_label = $attr['fr_label'] ?? null;
    
    // Check if en_US translation already exists
    $check = $pdo->prepare("
        SELECT COUNT(*) FROM pim_catalog_attribute_translation 
        WHERE foreign_key = ? AND locale = 'en_US'
    ");
    $check->execute([$attr['id']]);
    $exists = $check->fetchColumn();
    
    if ($exists > 0) {
        $stats['already_translated']++;
        continue;
    }
    
    // Determine English translation
    $en_label = null;
    
    // Priority 1: Predefined map
    if (isset($translation_map[$code])) {
        $en_label = $translation_map[$code];
    }
    // Priority 2: Derive from code (snake_case to Title Case)
    else {
        // Remove common prefixes
        $clean_code = preg_replace('/^(amasty_|am|mwishlist|quickorder)_/', '', $code);
        // Convert snake_case to Title Case
        $en_label = ucwords(str_replace('_', ' ', $clean_code));
    }
    
    // Insert translation
    try {
        $insert = $pdo->prepare("
            INSERT INTO pim_catalog_attribute_translation (foreign_key, label, locale)
            VALUES (?, ?, 'en_US')
        ");
        $insert->execute([$attr['id'], $en_label]);
        $stats['added']++;
        
        echo sprintf("  ✅ %-40s → %s\n", $code, $en_label);
    } catch (PDOException $e) {
        echo sprintf("  ❌ %-40s → Error: %s\n", $code, $e->getMessage());
        $stats['errors']++;
    }
}

echo "\n" . str_repeat("-", 80) . "\n";
echo "VERIFICATION\n";
echo str_repeat("-", 80) . "\n\n";

$verify = $pdo->query("
    SELECT 
        COUNT(DISTINCT a.id) as total_localizable,
        COUNT(DISTINCT CASE WHEN t.locale = 'en_US' THEN a.id END) as en_US_count,
        COUNT(DISTINCT CASE WHEN t.locale = 'fr_FR' THEN a.id END) as fr_FR_count
    FROM pim_catalog_attribute a
    LEFT JOIN pim_catalog_attribute_translation t ON a.id = t.foreign_key
    WHERE a.is_localizable = 1
")->fetch();

echo "Translation Coverage:\n";
echo "  Total localizable attributes: {$verify['total_localizable']}\n";
echo "  English (en_US): {$verify['en_US_count']} (" . 
     round(($verify['en_US_count']/$verify['total_localizable'])*100, 1) . "%)\n";
echo "  French (fr_FR): {$verify['fr_FR_count']} (" . 
     round(($verify['fr_FR_count']/$verify['total_localizable'])*100, 1) . "%)\n";

echo "\n" . str_repeat("-", 80) . "\n";
echo "SUMMARY\n";
echo str_repeat("-", 80) . "\n\n";

echo "Total localizable attributes: {$stats['total_localizable']}\n";
echo "Already had en_US translation: {$stats['already_translated']}\n";
echo "Added en_US translations: {$stats['added']}\n";
echo "Errors: {$stats['errors']}\n\n";

if ($stats['errors'] == 0 && $stats['added'] > 0) {
    echo "✅ Phase 1.2 completed successfully!\n";
    echo "All localizable attributes now have English translations.\n\n";
    
    echo "Next steps:\n";
    echo "1. Verify in Akeneo UI - check attribute labels appear correctly in English\n";
    echo "2. Run Phase 1.3: Enable completeness calculation\n";
    echo "3. Test user experience with English locale\n";
} else if ($stats['errors'] > 0) {
    echo "⚠️ Phase 1.2 completed with {$stats['errors']} errors\n";
    echo "Please review the errors above.\n";
}

echo "\n" . date('Y-m-d H:i:s') . "\n";
