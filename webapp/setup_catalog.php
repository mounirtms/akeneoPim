<?php
/**
 * Akeneo PIM - Setup Complete Catalog for TechnoStationery Magento Beta
 * Creates attributes, attribute groups, families, categories matching the Magento beta store
 */
error_reporting(E_ALL);
ini_set('display_errors', 1);

$baseUrl = 'https://pim.technostationery.com';

// Get beta DB connection for Akeneo config
$env = include '/home/beta/public_html/app/etc/env.php';
$betaDb = $env['db']['connection']['default'];
$parts = explode(':', $betaDb['host']);
$betaPdo = new PDO("mysql:host={$parts[0]};port={$parts[1]};dbname={$betaDb['dbname']}", $betaDb['username'], $betaDb['password']);

// Get Akeneo client credentials
$pimPdo = new PDO('mysql:host=127.0.0.1;port=3307;dbname=akeneo_pim', 'root', 'YourNewStrongPassword');
$client = $pimPdo->query("SELECT id, random_id, secret FROM pim_api_client LIMIT 1")->fetch(PDO::FETCH_ASSOC);
$clientId = $client['id'] . '_' . $client['random_id'];
$clientSecret = $client['secret'];

function getToken($baseUrl, $clientId, $clientSecret) {
    $ch = curl_init("$baseUrl/api/oauth/v1/token");
    curl_setopt_array($ch, [
        CURLOPT_POST => true,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_HTTPHEADER => ['Content-Type: application/json'],
        CURLOPT_POSTFIELDS => json_encode([
            'username' => 'admin',
            'password' => 'kVjW3GxKZCe9!!$',
            'grant_type' => 'password',
            'client_id' => $clientId,
            'client_secret' => $clientSecret
        ])
    ]);
    $resp = json_decode(curl_exec($ch), true);
    curl_close($ch);
    return $resp['access_token'] ?? null;
}

function apiCall($method, $url, $token, $data = null) {
    $ch = curl_init($url);
    curl_setopt_array($ch, [
        CURLOPT_CUSTOMREQUEST => $method,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_HTTPHEADER => [
            'Content-Type: application/json',
            "Authorization: Bearer $token"
        ],
    ]);
    if ($data !== null) {
        curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
    }
    $body = curl_exec($ch);
    $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    return ['code' => $code, 'body' => json_decode($body, true)];
}

function patchEntities($url, $token, $entities) {
    $lines = '';
    foreach ($entities as $entity) {
        $lines .= json_encode($entity) . "\n";
    }
    $ch = curl_init($url);
    curl_setopt_array($ch, [
        CURLOPT_CUSTOMREQUEST => 'PATCH',
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_HTTPHEADER => [
            'Content-Type: application/vnd.akeneo.collection+json',
            "Authorization: Bearer $token"
        ],
        CURLOPT_POSTFIELDS => $lines
    ]);
    $body = curl_exec($ch);
    $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    return ['code' => $code, 'body' => $body];
}

$token = getToken($baseUrl, $clientId, $clientSecret);
if (!$token) { die("Failed to get token\n"); }
echo "Token obtained\n";

// =====================================================
// 1. CREATE ATTRIBUTE GROUPS
// =====================================================
echo "\n=== CREATING ATTRIBUTE GROUPS ===\n";
$groups = [
    ['code' => 'identification', 'sort_order' => 1, 'labels' => ['en_US' => 'Identification', 'fr_FR' => 'Identification']],
    ['code' => 'marketing', 'sort_order' => 2, 'labels' => ['en_US' => 'Marketing', 'fr_FR' => 'Marketing']],
    ['code' => 'description', 'sort_order' => 3, 'labels' => ['en_US' => 'Description', 'fr_FR' => 'Description']],
    ['code' => 'media', 'sort_order' => 4, 'labels' => ['en_US' => 'Media', 'fr_FR' => 'Média']],
    ['code' => 'pricing', 'sort_order' => 5, 'labels' => ['en_US' => 'Pricing', 'fr_FR' => 'Prix']],
    ['code' => 'technical', 'sort_order' => 6, 'labels' => ['en_US' => 'Technical', 'fr_FR' => 'Technique']],
    ['code' => 'dimensions', 'sort_order' => 7, 'labels' => ['en_US' => 'Dimensions', 'fr_FR' => 'Dimensions']],
    ['code' => 'seo', 'sort_order' => 8, 'labels' => ['en_US' => 'SEO', 'fr_FR' => 'SEO']],
    ['code' => 'ecommerce', 'sort_order' => 9, 'labels' => ['en_US' => 'E-commerce', 'fr_FR' => 'E-commerce']],
];

$resp = patchEntities("$baseUrl/api/rest/v1/attribute-groups", $token, $groups);
echo "Groups: HTTP {$resp['code']}\n";

// =====================================================
// 2. CREATE ATTRIBUTES matching Magento beta
// =====================================================
echo "\n=== CREATING ATTRIBUTES ===\n";
$attributes = [
    // Identification
    ['code' => 'name', 'type' => 'pim_catalog_text', 'group' => 'identification', 'localizable' => true, 'scopable' => false, 'sort_order' => 1, 'labels' => ['en_US' => 'Name', 'fr_FR' => 'Nom']],
    ['code' => 'techno_ref', 'type' => 'pim_catalog_text', 'group' => 'identification', 'localizable' => false, 'scopable' => false, 'unique' => true, 'sort_order' => 2, 'labels' => ['en_US' => 'Techno Reference', 'fr_FR' => 'Référence Techno']],
    ['code' => 'url_key', 'type' => 'pim_catalog_text', 'group' => 'identification', 'localizable' => false, 'scopable' => false, 'unique' => true, 'sort_order' => 3, 'labels' => ['en_US' => 'URL Key', 'fr_FR' => 'Clé URL']],
    ['code' => 'manufacturer', 'type' => 'pim_catalog_simpleselect', 'group' => 'identification', 'localizable' => false, 'scopable' => false, 'sort_order' => 4, 'labels' => ['en_US' => 'Manufacturer', 'fr_FR' => 'Fabricant']],
    ['code' => 'mgs_brand', 'type' => 'pim_catalog_simpleselect', 'group' => 'identification', 'localizable' => false, 'scopable' => false, 'sort_order' => 5, 'labels' => ['en_US' => 'Brand', 'fr_FR' => 'Marque']],
    
    // Description
    ['code' => 'description', 'type' => 'pim_catalog_textarea', 'group' => 'description', 'localizable' => true, 'scopable' => true, 'wysiwyg_enabled' => true, 'sort_order' => 1, 'labels' => ['en_US' => 'Description', 'fr_FR' => 'Description']],
    ['code' => 'short_description', 'type' => 'pim_catalog_textarea', 'group' => 'description', 'localizable' => true, 'scopable' => true, 'wysiwyg_enabled' => true, 'sort_order' => 2, 'labels' => ['en_US' => 'Short Description', 'fr_FR' => 'Description courte']],
    
    // SEO
    ['code' => 'meta_title', 'type' => 'pim_catalog_text', 'group' => 'seo', 'localizable' => true, 'scopable' => false, 'sort_order' => 1, 'labels' => ['en_US' => 'Meta Title', 'fr_FR' => 'Titre Meta']],
    ['code' => 'meta_description', 'type' => 'pim_catalog_textarea', 'group' => 'seo', 'localizable' => true, 'scopable' => false, 'sort_order' => 2, 'labels' => ['en_US' => 'Meta Description', 'fr_FR' => 'Description Meta']],
    ['code' => 'meta_keyword', 'type' => 'pim_catalog_textarea', 'group' => 'seo', 'localizable' => true, 'scopable' => false, 'sort_order' => 3, 'labels' => ['en_US' => 'Meta Keywords', 'fr_FR' => 'Mots-clés Meta']],
    
    // Pricing
    ['code' => 'price', 'type' => 'pim_catalog_price_collection', 'group' => 'pricing', 'localizable' => false, 'scopable' => false, 'decimals_allowed' => true, 'sort_order' => 1, 'labels' => ['en_US' => 'Price', 'fr_FR' => 'Prix']],
    ['code' => 'cost', 'type' => 'pim_catalog_price_collection', 'group' => 'pricing', 'localizable' => false, 'scopable' => false, 'decimals_allowed' => true, 'sort_order' => 2, 'labels' => ['en_US' => 'Cost', 'fr_FR' => 'Coût']],
    ['code' => 'special_price', 'type' => 'pim_catalog_price_collection', 'group' => 'pricing', 'localizable' => false, 'scopable' => false, 'decimals_allowed' => true, 'sort_order' => 3, 'labels' => ['en_US' => 'Special Price', 'fr_FR' => 'Prix spécial']],
    
    // Technical (variant axes in Magento)
    ['code' => 'color', 'type' => 'pim_catalog_simpleselect', 'group' => 'technical', 'localizable' => false, 'scopable' => false, 'sort_order' => 1, 'labels' => ['en_US' => 'Color', 'fr_FR' => 'Couleur']],
    ['code' => 'capacity', 'type' => 'pim_catalog_simpleselect', 'group' => 'technical', 'localizable' => false, 'scopable' => false, 'sort_order' => 2, 'labels' => ['en_US' => 'Capacity', 'fr_FR' => 'Capacité']],
    ['code' => 'pattern', 'type' => 'pim_catalog_simpleselect', 'group' => 'technical', 'localizable' => false, 'scopable' => false, 'sort_order' => 3, 'labels' => ['en_US' => 'Pattern', 'fr_FR' => 'Motif']],
    ['code' => 'type_product', 'type' => 'pim_catalog_simpleselect', 'group' => 'technical', 'localizable' => false, 'scopable' => false, 'sort_order' => 4, 'labels' => ['en_US' => 'Type', 'fr_FR' => 'Type']],
    ['code' => 'format', 'type' => 'pim_catalog_simpleselect', 'group' => 'technical', 'localizable' => false, 'scopable' => false, 'sort_order' => 5, 'labels' => ['en_US' => 'Format', 'fr_FR' => 'Format']],
    
    // Dimensions
    ['code' => 'size', 'type' => 'pim_catalog_simpleselect', 'group' => 'dimensions', 'localizable' => false, 'scopable' => false, 'sort_order' => 1, 'labels' => ['en_US' => 'Size', 'fr_FR' => 'Taille']],
    ['code' => 'dimension', 'type' => 'pim_catalog_simpleselect', 'group' => 'dimensions', 'localizable' => false, 'scopable' => false, 'sort_order' => 2, 'labels' => ['en_US' => 'Dimension', 'fr_FR' => 'Dimension']],
    ['code' => 'diameter', 'type' => 'pim_catalog_simpleselect', 'group' => 'dimensions', 'localizable' => false, 'scopable' => false, 'sort_order' => 3, 'labels' => ['en_US' => 'Diameter', 'fr_FR' => 'Diamètre']],
    ['code' => 'thickness', 'type' => 'pim_catalog_simpleselect', 'group' => 'dimensions', 'localizable' => false, 'scopable' => false, 'sort_order' => 4, 'labels' => ['en_US' => 'Thickness', 'fr_FR' => 'Épaisseur']],
    ['code' => 'weight', 'type' => 'pim_catalog_metric', 'group' => 'dimensions', 'localizable' => false, 'scopable' => false, 'metric_family' => 'Weight', 'default_metric_unit' => 'GRAM', 'decimals_allowed' => true, 'sort_order' => 5, 'labels' => ['en_US' => 'Weight', 'fr_FR' => 'Poids']],
    
    // Media
    ['code' => 'image', 'type' => 'pim_catalog_image', 'group' => 'media', 'localizable' => false, 'scopable' => false, 'allowed_extensions' => ['jpg', 'jpeg', 'png', 'gif', 'webp'], 'sort_order' => 1, 'labels' => ['en_US' => 'Main Image', 'fr_FR' => 'Image principale']],
    ['code' => 'small_image', 'type' => 'pim_catalog_image', 'group' => 'media', 'localizable' => false, 'scopable' => false, 'allowed_extensions' => ['jpg', 'jpeg', 'png', 'gif', 'webp'], 'sort_order' => 2, 'labels' => ['en_US' => 'Small Image', 'fr_FR' => 'Petite image']],
    ['code' => 'thumbnail', 'type' => 'pim_catalog_image', 'group' => 'media', 'localizable' => false, 'scopable' => false, 'allowed_extensions' => ['jpg', 'jpeg', 'png', 'gif', 'webp'], 'sort_order' => 3, 'labels' => ['en_US' => 'Thumbnail', 'fr_FR' => 'Miniature']],
    
    // E-commerce
    ['code' => 'visibility', 'type' => 'pim_catalog_simpleselect', 'group' => 'ecommerce', 'localizable' => false, 'scopable' => false, 'sort_order' => 1, 'labels' => ['en_US' => 'Visibility', 'fr_FR' => 'Visibilité']],
    ['code' => 'product_status', 'type' => 'pim_catalog_boolean', 'group' => 'ecommerce', 'localizable' => false, 'scopable' => false, 'sort_order' => 2, 'labels' => ['en_US' => 'Enabled', 'fr_FR' => 'Activé']],
    ['code' => 'best_seller', 'type' => 'pim_catalog_boolean', 'group' => 'ecommerce', 'localizable' => false, 'scopable' => false, 'sort_order' => 3, 'labels' => ['en_US' => 'Best Seller', 'fr_FR' => 'Meilleure vente']],
    ['code' => 'a_la_une', 'type' => 'pim_catalog_boolean', 'group' => 'ecommerce', 'localizable' => false, 'scopable' => false, 'sort_order' => 4, 'labels' => ['en_US' => 'Featured', 'fr_FR' => 'À la une']],
    ['code' => 'trending', 'type' => 'pim_catalog_boolean', 'group' => 'ecommerce', 'localizable' => false, 'scopable' => false, 'sort_order' => 5, 'labels' => ['en_US' => 'Trending', 'fr_FR' => 'Tendance']],
    ['code' => 'en_promo', 'type' => 'pim_catalog_text', 'group' => 'ecommerce', 'localizable' => false, 'scopable' => false, 'sort_order' => 6, 'labels' => ['en_US' => 'On Sale', 'fr_FR' => 'En promo']],
    ['code' => 'gender_product', 'type' => 'pim_catalog_simpleselect', 'group' => 'ecommerce', 'localizable' => false, 'scopable' => false, 'sort_order' => 7, 'labels' => ['en_US' => 'Gender', 'fr_FR' => 'Genre']],
];

$resp = patchEntities("$baseUrl/api/rest/v1/attributes", $token, $attributes);
echo "Attributes: HTTP {$resp['code']}\n";
echo "  Response: " . substr($resp['body'], 0, 500) . "\n";

// =====================================================
// 3. CREATE ATTRIBUTE OPTIONS for select attributes
// =====================================================
echo "\n=== CREATING ATTRIBUTE OPTIONS ===\n";

// Fetch options from Magento beta
$selectAttrs = ['color', 'capacity', 'pattern', 'format', 'size', 'dimension', 'diameter', 'thickness', 'manufacturer', 'mgs_brand', 'gender_product'];

foreach ($selectAttrs as $attrCode) {
    $magentoAttrCode = ($attrCode === 'type_product') ? 'type' : $attrCode;
    
    $stmt = $betaPdo->prepare("SELECT eao.option_id, eaov.value 
        FROM eav_attribute ea 
        JOIN eav_attribute_option eao ON ea.attribute_id = eao.attribute_id 
        LEFT JOIN eav_attribute_option_value eaov ON eao.option_id = eaov.option_id AND eaov.store_id = 0
        WHERE ea.attribute_code = ? AND ea.entity_type_id = 4 
        ORDER BY eao.sort_order LIMIT 100");
    $stmt->execute([$magentoAttrCode]);
    $options = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    if (empty($options)) continue;
    
    $pimOptions = [];
    foreach ($options as $opt) {
        if (empty($opt['value'])) continue;
        // Create a code from the value
        $optCode = strtolower(preg_replace('/[^a-zA-Z0-9]+/', '_', $opt['value']));
        $optCode = trim($optCode, '_');
        if (empty($optCode) || strlen($optCode) > 100) continue;
        
        $pimOptions[] = [
            'code' => $optCode,
            'attribute' => $attrCode,
            'sort_order' => count($pimOptions) + 1,
            'labels' => ['en_US' => $opt['value'], 'fr_FR' => $opt['value']]
        ];
    }
    
    if (!empty($pimOptions)) {
        $resp = patchEntities("$baseUrl/api/rest/v1/attributes/$attrCode/options", $token, $pimOptions);
        echo "  $attrCode: " . count($pimOptions) . " options, HTTP {$resp['code']}\n";
    }
}

// Add visibility options
$visibilityOptions = [
    ['code' => 'not_visible', 'attribute' => 'visibility', 'labels' => ['en_US' => 'Not Visible Individually']],
    ['code' => 'catalog', 'attribute' => 'visibility', 'labels' => ['en_US' => 'Catalog']],
    ['code' => 'search', 'attribute' => 'visibility', 'labels' => ['en_US' => 'Search']],
    ['code' => 'catalog_search', 'attribute' => 'visibility', 'labels' => ['en_US' => 'Catalog, Search']],
];
patchEntities("$baseUrl/api/rest/v1/attributes/visibility/options", $token, $visibilityOptions);

// Add type_product options from Magento 'type' attribute
$stmt = $betaPdo->prepare("SELECT eao.option_id, eaov.value 
    FROM eav_attribute ea 
    JOIN eav_attribute_option eao ON ea.attribute_id = eao.attribute_id 
    LEFT JOIN eav_attribute_option_value eaov ON eao.option_id = eaov.option_id AND eaov.store_id = 0
    WHERE ea.attribute_code = 'type' AND ea.entity_type_id = 4 
    ORDER BY eao.sort_order LIMIT 100");
$stmt->execute();
$typeOptions = $stmt->fetchAll(PDO::FETCH_ASSOC);
$pimTypeOptions = [];
foreach ($typeOptions as $opt) {
    if (empty($opt['value'])) continue;
    $optCode = strtolower(preg_replace('/[^a-zA-Z0-9]+/', '_', $opt['value']));
    $optCode = trim($optCode, '_');
    if (empty($optCode) || strlen($optCode) > 100) continue;
    $pimTypeOptions[] = ['code' => $optCode, 'attribute' => 'type_product', 'labels' => ['en_US' => $opt['value'], 'fr_FR' => $opt['value']]];
}
if (!empty($pimTypeOptions)) {
    patchEntities("$baseUrl/api/rest/v1/attributes/type_product/options", $token, $pimTypeOptions);
    echo "  type_product: " . count($pimTypeOptions) . " options\n";
}

// =====================================================
// 4. CREATE FAMILIES matching Magento attribute sets
// =====================================================
echo "\n=== CREATING FAMILIES ===\n";
$baseAttrs = ['sku','name','description','short_description','price','cost','special_price','image','small_image','thumbnail',
    'meta_title','meta_description','meta_keyword','url_key','weight','product_status','visibility','best_seller','a_la_une','trending','en_promo'];

$families = [
    ['code' => 'scolaire', 'labels' => ['en_US' => 'Scolaire', 'fr_FR' => 'Scolaire'],
     'attributes' => array_merge($baseAttrs, ['color','capacity','pattern','format','size','dimension','diameter','thickness','type_product','techno_ref','manufacturer','mgs_brand','gender_product']),
     'attribute_as_label' => 'name', 'attribute_as_image' => 'image'],
    ['code' => 'ecriture', 'labels' => ['en_US' => 'Écriture & Coloriage', 'fr_FR' => 'Écriture & Coloriage'],
     'attributes' => array_merge($baseAttrs, ['color','capacity','diameter','type_product','techno_ref','manufacturer','mgs_brand']),
     'attribute_as_label' => 'name', 'attribute_as_image' => 'image'],
    ['code' => 'beaux_arts', 'labels' => ['en_US' => 'Beaux Arts', 'fr_FR' => 'Beaux Arts'],
     'attributes' => array_merge($baseAttrs, ['color','capacity','dimension','type_product','techno_ref','manufacturer','mgs_brand']),
     'attribute_as_label' => 'name', 'attribute_as_image' => 'image'],
    ['code' => 'bureautique', 'labels' => ['en_US' => 'Bureautique & Informatique', 'fr_FR' => 'Bureautique & Informatique'],
     'attributes' => array_merge($baseAttrs, ['color','capacity','dimension','format','type_product','techno_ref','manufacturer','mgs_brand']),
     'attribute_as_label' => 'name', 'attribute_as_image' => 'image'],
    ['code' => 'calculatrices', 'labels' => ['en_US' => 'Calculatrices', 'fr_FR' => 'Calculatrices'],
     'attributes' => array_merge($baseAttrs, ['color','type_product','techno_ref','manufacturer','mgs_brand']),
     'attribute_as_label' => 'name', 'attribute_as_image' => 'image'],
    ['code' => 'bags_sac', 'labels' => ['en_US' => 'Bags & Sacs', 'fr_FR' => 'Sacs & Bagagerie'],
     'attributes' => array_merge($baseAttrs, ['color','pattern','size','type_product','techno_ref','manufacturer','mgs_brand','gender_product']),
     'attribute_as_label' => 'name', 'attribute_as_image' => 'image'],
    ['code' => 'informatique', 'labels' => ['en_US' => 'Informatique', 'fr_FR' => 'Informatique'],
     'attributes' => array_merge($baseAttrs, ['color','capacity','dimension','type_product','techno_ref','manufacturer','mgs_brand']),
     'attribute_as_label' => 'name', 'attribute_as_image' => 'image'],
    ['code' => 'bricolage', 'labels' => ['en_US' => 'Bricolage', 'fr_FR' => 'Bricolage'],
     'attributes' => array_merge($baseAttrs, ['color','capacity','dimension','type_product','techno_ref','manufacturer','mgs_brand']),
     'attribute_as_label' => 'name', 'attribute_as_image' => 'image'],
    ['code' => 'loisirs_creatifs', 'labels' => ['en_US' => 'Loisirs Créatifs', 'fr_FR' => 'Loisirs Créatifs'],
     'attributes' => array_merge($baseAttrs, ['color','capacity','dimension','type_product','techno_ref','manufacturer','mgs_brand']),
     'attribute_as_label' => 'name', 'attribute_as_image' => 'image'],
    ['code' => 'crayons', 'labels' => ['en_US' => 'Crayons', 'fr_FR' => 'Crayons'],
     'attributes' => array_merge($baseAttrs, ['color','capacity','diameter','type_product','techno_ref','manufacturer','mgs_brand']),
     'attribute_as_label' => 'name', 'attribute_as_image' => 'image'],
    ['code' => 'tableau', 'labels' => ['en_US' => 'Tableau', 'fr_FR' => 'Tableau'],
     'attributes' => array_merge($baseAttrs, ['color','dimension','type_product','techno_ref','manufacturer','mgs_brand']),
     'attribute_as_label' => 'name', 'attribute_as_image' => 'image'],
    ['code' => 'cahier', 'labels' => ['en_US' => 'Cahier & Registre', 'fr_FR' => 'Cahier & Registre'],
     'attributes' => array_merge($baseAttrs, ['color','capacity','format','dimension','thickness','type_product','techno_ref','manufacturer','mgs_brand']),
     'attribute_as_label' => 'name', 'attribute_as_image' => 'image'],
    ['code' => 'products', 'labels' => ['en_US' => 'General Products', 'fr_FR' => 'Produits généraux'],
     'attributes' => array_merge($baseAttrs, ['color','capacity','pattern','format','size','dimension','diameter','thickness','type_product','techno_ref','manufacturer','mgs_brand','gender_product']),
     'attribute_as_label' => 'name', 'attribute_as_image' => 'image'],
    ['code' => 'made_in_algeria', 'labels' => ['en_US' => 'Made in Algeria', 'fr_FR' => 'Made in Algeria'],
     'attributes' => array_merge($baseAttrs, ['color','capacity','dimension','type_product','techno_ref','manufacturer','mgs_brand']),
     'attribute_as_label' => 'name', 'attribute_as_image' => 'image'],
];

$resp = patchEntities("$baseUrl/api/rest/v1/families", $token, $families);
echo "Families: HTTP {$resp['code']}\n";
echo "  Response: " . substr($resp['body'], 0, 500) . "\n";

// =====================================================
// 5. CREATE CATEGORIES matching Magento structure
// =====================================================
echo "\n=== CREATING CATEGORIES ===\n";

// Main categories tree
$categories = [
    ['code' => 'master', 'labels' => ['en_US' => 'Master Catalog', 'fr_FR' => 'Catalogue principal']],
    // Level 1
    ['code' => 'tous_les_produits', 'parent' => 'master', 'labels' => ['en_US' => 'All Products', 'fr_FR' => 'Tous les produits']],
    ['code' => 'promos', 'parent' => 'master', 'labels' => ['en_US' => 'Promos', 'fr_FR' => 'Promos']],
    ['code' => 'a_la_une_cat', 'parent' => 'master', 'labels' => ['en_US' => 'Featured', 'fr_FR' => 'À la une']],
    ['code' => 'top_tendance', 'parent' => 'master', 'labels' => ['en_US' => 'Top Trending', 'fr_FR' => 'Top tendance']],
    ['code' => 'meilleur_ventes', 'parent' => 'master', 'labels' => ['en_US' => 'Best Sellers', 'fr_FR' => 'Meilleures ventes']],
    ['code' => 'made_in_algeria_cat', 'parent' => 'master', 'labels' => ['en_US' => 'Made in Algeria', 'fr_FR' => 'Made in Algeria']],
    ['code' => 'adhesifs_accessoires', 'parent' => 'master', 'labels' => ['en_US' => 'Adhesives & Accessories', 'fr_FR' => 'Adhésifs & Accessoires']],
    ['code' => 'carnets_notes', 'parent' => 'master', 'labels' => ['en_US' => 'Notebooks & Notes', 'fr_FR' => 'Carnets & Notes']],
    // Level 2 under Tous les produits
    ['code' => 'scolaire_cat', 'parent' => 'tous_les_produits', 'labels' => ['en_US' => 'School Supplies', 'fr_FR' => 'Scolaire']],
    ['code' => 'loisirs_creatifs_cat', 'parent' => 'tous_les_produits', 'labels' => ['en_US' => 'Creative Leisure', 'fr_FR' => 'Loisirs créatifs']],
    ['code' => 'beaux_arts_cat', 'parent' => 'tous_les_produits', 'labels' => ['en_US' => 'Fine Arts', 'fr_FR' => 'Beaux arts']],
    ['code' => 'bureautique_informatique', 'parent' => 'tous_les_produits', 'labels' => ['en_US' => 'Office & IT', 'fr_FR' => 'Bureautique & Informatique']],
    ['code' => 'bricolage_cat', 'parent' => 'tous_les_produits', 'labels' => ['en_US' => 'DIY', 'fr_FR' => 'Bricolage']],
    ['code' => 'ecriture_coloriage', 'parent' => 'tous_les_produits', 'labels' => ['en_US' => 'Writing & Coloring', 'fr_FR' => 'Écriture & Coloriage']],
    ['code' => 'technique_cat', 'parent' => 'tous_les_produits', 'labels' => ['en_US' => 'Technical', 'fr_FR' => 'Technique']],
    ['code' => 'equipement_hotel_magasin', 'parent' => 'tous_les_produits', 'labels' => ['en_US' => 'Hotel & Store Equipment', 'fr_FR' => 'Équipement hôtel & magasin']],
    ['code' => 'instruments_coupe', 'parent' => 'tous_les_produits', 'labels' => ['en_US' => 'Cutting Instruments', 'fr_FR' => 'Instruments de coupe']],
    ['code' => 'feuilles_mobiles', 'parent' => 'tous_les_produits', 'labels' => ['en_US' => 'Loose Sheets', 'fr_FR' => 'Feuilles mobiles']],
    // Level 3 - subcategories
    ['code' => 'ecriture_correction', 'parent' => 'ecriture_coloriage', 'labels' => ['en_US' => 'Writing & Correction', 'fr_FR' => 'Écriture & Correction']],
    ['code' => 'coloriage', 'parent' => 'ecriture_coloriage', 'labels' => ['en_US' => 'Coloring', 'fr_FR' => 'Coloriage']],
    ['code' => 'tracages', 'parent' => 'scolaire_cat', 'labels' => ['en_US' => 'Tracing', 'fr_FR' => 'Traçages']],
    ['code' => 'calculatrices_cat', 'parent' => 'bureautique_informatique', 'labels' => ['en_US' => 'Calculators', 'fr_FR' => 'Calculatrices']],
    ['code' => 'colles_adhesifs', 'parent' => 'adhesifs_accessoires', 'labels' => ['en_US' => 'Glues & Adhesives', 'fr_FR' => 'Colles & Adhésifs']],
    ['code' => 'supports_papier', 'parent' => 'scolaire_cat', 'labels' => ['en_US' => 'Paper Supports', 'fr_FR' => 'Supports en papier']],
    ['code' => 'bagagerie', 'parent' => 'scolaire_cat', 'labels' => ['en_US' => 'Bags', 'fr_FR' => 'Bagagerie']],
    ['code' => 'agrafages', 'parent' => 'bureautique_informatique', 'labels' => ['en_US' => 'Stapling', 'fr_FR' => 'Agrafages']],
    ['code' => 'classement_archivage', 'parent' => 'bureautique_informatique', 'labels' => ['en_US' => 'Filing & Archiving', 'fr_FR' => 'Classement & Archivage']],
    ['code' => 'materiels_beaux_arts', 'parent' => 'beaux_arts_cat', 'labels' => ['en_US' => 'Fine Arts Supplies', 'fr_FR' => 'Matériels beaux arts']],
    ['code' => 'peintures', 'parent' => 'beaux_arts_cat', 'labels' => ['en_US' => 'Paints', 'fr_FR' => 'Peintures']],
    ['code' => 'dessin_art_graphique', 'parent' => 'beaux_arts_cat', 'labels' => ['en_US' => 'Drawing & Graphic Art', 'fr_FR' => 'Dessin & Art graphique']],
    ['code' => 'activites_creatives', 'parent' => 'loisirs_creatifs_cat', 'labels' => ['en_US' => 'Creative Activities', 'fr_FR' => 'Activités créatives']],
    // Adhesives sub-categories
    ['code' => 'devidoir_ruban', 'parent' => 'adhesifs_accessoires', 'labels' => ['en_US' => 'Tape Dispensers', 'fr_FR' => 'Dévidoir ruban adhésif']],
    ['code' => 'colles_stick', 'parent' => 'adhesifs_accessoires', 'labels' => ['en_US' => 'Stick Glues', 'fr_FR' => 'Colles stick']],
    ['code' => 'colles_liquides', 'parent' => 'adhesifs_accessoires', 'labels' => ['en_US' => 'Liquid Glues', 'fr_FR' => 'Colles liquides']],
    ['code' => 'ruban_adhesif', 'parent' => 'adhesifs_accessoires', 'labels' => ['en_US' => 'Adhesive Tape', 'fr_FR' => 'Ruban adhésif']],
];

$resp = patchEntities("$baseUrl/api/rest/v1/categories", $token, $categories);
echo "Categories: HTTP {$resp['code']}\n";
echo "  Response: " . substr($resp['body'], 0, 500) . "\n";

// =====================================================
// 6. CREATE CHANNEL
// =====================================================
echo "\n=== CREATING CHANNEL ===\n";
$channel = [
    'code' => 'ecommerce',
    'currencies' => ['DZD', 'EUR', 'USD'],
    'locales' => ['en_US', 'fr_FR', 'ar_DZ'],
    'category_tree' => 'master',
    'labels' => ['en_US' => 'E-commerce', 'fr_FR' => 'E-commerce']
];
$resp = apiCall('PATCH', "$baseUrl/api/rest/v1/channels/ecommerce", $token, $channel);
echo "Channel ecommerce: HTTP {$resp['code']}\n";

echo "\n=== SETUP COMPLETE ===\n";
echo "Attribute groups: " . count($groups) . "\n";
echo "Attributes: " . count($attributes) . "\n";
echo "Families: " . count($families) . "\n";
echo "Categories: " . count($categories) . "\n";
