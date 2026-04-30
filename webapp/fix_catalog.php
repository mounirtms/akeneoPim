<?php
error_reporting(E_ALL);
$baseUrl = 'https://pim.technostationery.com';

$pdo = new PDO('mysql:host=127.0.0.1;port=3307;dbname=akeneo_pim', 'root', 'YourNewStrongPassword');
$client = $pdo->query("SELECT id, random_id, secret FROM pim_api_client LIMIT 1")->fetch(PDO::FETCH_ASSOC);
$clientId = $client['id'] . '_' . $client['random_id'];
$clientSecret = $client['secret'];

$ch = curl_init("$baseUrl/api/oauth/v1/token");
curl_setopt_array($ch, [CURLOPT_POST=>true, CURLOPT_RETURNTRANSFER=>true, CURLOPT_HTTPHEADER=>['Content-Type: application/json'],
    CURLOPT_POSTFIELDS=>json_encode(['username'=>'admin','password'=>'kVjW3GxKZCe9!!$','grant_type'=>'password','client_id'=>$clientId,'client_secret'=>$clientSecret])]);
$token = json_decode(curl_exec($ch), true)['access_token'];
curl_close($ch);
echo "Token: OK\n";

function apiPatch($url, $token, $data) {
    $ch = curl_init($url);
    curl_setopt_array($ch, [CURLOPT_CUSTOMREQUEST=>'PATCH', CURLOPT_RETURNTRANSFER=>true,
        CURLOPT_HTTPHEADER=>['Content-Type: application/json', "Authorization: Bearer $token"],
        CURLOPT_POSTFIELDS=>json_encode($data)]);
    $body = curl_exec($ch);
    $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    echo "  HTTP $code: " . substr($body, 0, 200) . "\n";
    return $code;
}

// 1. Fix image attributes
echo "\n=== CREATING IMAGE ATTRIBUTES ===\n";
$imageAttrs = [
    ['code' => 'image', 'type' => 'pim_catalog_image', 'group' => 'media', 'localizable' => false, 'scopable' => false, 'sort_order' => 1, 'labels' => ['en_US' => 'Main Image', 'fr_FR' => 'Image principale'], 'allowed_extensions' => ['jpg', 'jpeg', 'png', 'gif', 'webp']],
    ['code' => 'small_image', 'type' => 'pim_catalog_image', 'group' => 'media', 'localizable' => false, 'scopable' => false, 'sort_order' => 2, 'labels' => ['en_US' => 'Small Image', 'fr_FR' => 'Petite image'], 'allowed_extensions' => ['jpg', 'jpeg', 'png', 'gif', 'webp']],
    ['code' => 'thumbnail_img', 'type' => 'pim_catalog_image', 'group' => 'media', 'localizable' => false, 'scopable' => false, 'sort_order' => 3, 'labels' => ['en_US' => 'Thumbnail', 'fr_FR' => 'Miniature'], 'allowed_extensions' => ['jpg', 'jpeg', 'png', 'gif', 'webp']],
];

foreach ($imageAttrs as $attr) {
    $code = $attr['code'];
    echo "Creating $code:\n";
    apiPatch("$baseUrl/api/rest/v1/attributes/$code", $token, $attr);
}

// 2. Fix channel
echo "\n=== UPDATING CHANNEL ===\n";

// First check existing locales
$ch = curl_init("$baseUrl/api/rest/v1/locales?limit=100");
curl_setopt_array($ch, [CURLOPT_RETURNTRANSFER=>true, CURLOPT_HTTPHEADER=>["Authorization: Bearer $token"]]);
$locales = json_decode(curl_exec($ch), true);
curl_close($ch);
echo "Available locales: ";
foreach ($locales['_embedded']['items'] as $l) {
    if ($l['enabled']) echo $l['code'] . " ";
}
echo "\n";

// Enable fr_FR and ar_DZ locales
apiPatch("$baseUrl/api/rest/v1/channels/ecommerce", $token, [
    'code' => 'ecommerce',
    'currencies' => ['DZD', 'EUR', 'USD'],
    'locales' => ['en_US', 'fr_FR'],
    'category_tree' => 'master',
    'labels' => ['en_US' => 'E-commerce', 'fr_FR' => 'E-commerce']
]);

// 3. Now fix families with correct image attribute codes
echo "\n=== UPDATING FAMILIES ===\n";
$baseAttrs = ['sku','name','description','short_description','price','cost','special_price','image','small_image','thumbnail_img',
    'meta_title','meta_description','meta_keyword','url_key','weight','product_status','visibility','best_seller','a_la_une','trending','en_promo'];
$allAttrs = array_merge($baseAttrs, ['color','capacity','pattern','format','size','dimension','diameter','thickness','type_product','techno_ref','manufacturer','mgs_brand','gender_product']);

$families = [
    ['code' => 'scolaire', 'attributes' => $allAttrs, 'attribute_as_label' => 'name', 'attribute_as_image' => 'image'],
    ['code' => 'ecriture', 'attributes' => array_merge($baseAttrs, ['color','capacity','diameter','type_product','techno_ref','manufacturer','mgs_brand']), 'attribute_as_label' => 'name', 'attribute_as_image' => 'image'],
    ['code' => 'beaux_arts', 'attributes' => array_merge($baseAttrs, ['color','capacity','dimension','type_product','techno_ref','manufacturer','mgs_brand']), 'attribute_as_label' => 'name', 'attribute_as_image' => 'image'],
    ['code' => 'bureautique', 'attributes' => array_merge($baseAttrs, ['color','capacity','dimension','format','type_product','techno_ref','manufacturer','mgs_brand']), 'attribute_as_label' => 'name', 'attribute_as_image' => 'image'],
    ['code' => 'calculatrices', 'attributes' => array_merge($baseAttrs, ['color','type_product','techno_ref','manufacturer','mgs_brand']), 'attribute_as_label' => 'name', 'attribute_as_image' => 'image'],
    ['code' => 'bags_sac', 'attributes' => array_merge($baseAttrs, ['color','pattern','size','type_product','techno_ref','manufacturer','mgs_brand','gender_product']), 'attribute_as_label' => 'name', 'attribute_as_image' => 'image'],
    ['code' => 'informatique', 'attributes' => array_merge($baseAttrs, ['color','capacity','dimension','type_product','techno_ref','manufacturer','mgs_brand']), 'attribute_as_label' => 'name', 'attribute_as_image' => 'image'],
    ['code' => 'bricolage', 'attributes' => array_merge($baseAttrs, ['color','capacity','dimension','type_product','techno_ref','manufacturer','mgs_brand']), 'attribute_as_label' => 'name', 'attribute_as_image' => 'image'],
    ['code' => 'loisirs_creatifs', 'attributes' => array_merge($baseAttrs, ['color','capacity','dimension','type_product','techno_ref','manufacturer','mgs_brand']), 'attribute_as_label' => 'name', 'attribute_as_image' => 'image'],
    ['code' => 'crayons', 'attributes' => array_merge($baseAttrs, ['color','capacity','diameter','type_product','techno_ref','manufacturer','mgs_brand']), 'attribute_as_label' => 'name', 'attribute_as_image' => 'image'],
    ['code' => 'tableau', 'attributes' => array_merge($baseAttrs, ['color','dimension','type_product','techno_ref','manufacturer','mgs_brand']), 'attribute_as_label' => 'name', 'attribute_as_image' => 'image'],
    ['code' => 'cahier', 'attributes' => array_merge($baseAttrs, ['color','capacity','format','dimension','thickness','type_product','techno_ref','manufacturer','mgs_brand']), 'attribute_as_label' => 'name', 'attribute_as_image' => 'image'],
    ['code' => 'products', 'attributes' => $allAttrs, 'attribute_as_label' => 'name', 'attribute_as_image' => 'image'],
    ['code' => 'made_in_algeria', 'attributes' => array_merge($baseAttrs, ['color','capacity','dimension','type_product','techno_ref','manufacturer','mgs_brand']), 'attribute_as_label' => 'name', 'attribute_as_image' => 'image'],
];

foreach ($families as $fam) {
    echo "Family {$fam['code']}:\n";
    apiPatch("$baseUrl/api/rest/v1/families/{$fam['code']}", $token, $fam);
}

// 4. Remove old test products from previous setup
echo "\n=== CLEANUP OLD TEST PRODUCTS ===\n";
$oldSkus = ['TECHNO-PEN-001', 'TECHNO-NB-001', 'TECHNO-PEN-002'];
foreach ($oldSkus as $sku) {
    $ch = curl_init("$baseUrl/api/rest/v1/products/$sku");
    curl_setopt_array($ch, [CURLOPT_CUSTOMREQUEST=>'DELETE', CURLOPT_RETURNTRANSFER=>true,
        CURLOPT_HTTPHEADER=>["Authorization: Bearer $token"]]);
    curl_exec($ch);
    $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    echo "  Delete $sku: HTTP $code\n";
}

echo "\nDone!\n";
