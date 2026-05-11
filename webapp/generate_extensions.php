<?php
/**
 * Generate extensions.json from all form_extensions/*.yml files
 */

require __DIR__ . '/../vendor/autoload.php';

use Symfony\Component\Yaml\Yaml;
use Symfony\Component\Finder\Finder;

$finder = new Finder();
$finder->files()
    ->in(__DIR__ . '/../vendor/akeneo/pim-community-dev')
    ->path('/form_extensions/')
    ->name('*.yml');

$extensions = [];
$attributeFields = [];
$jobs = [];

echo "Processing form extension files...\n";
$count = 0;

foreach ($finder as $file) {
    $count++;
    try {
        $content = Yaml::parseFile($file->getRealPath());
        
        if (isset($content['extensions']) && is_array($content['extensions'])) {
            foreach ($content['extensions'] as $key => $value) {
                $extensions[$key] = $value;
            }
        }
        
        if (isset($content['attribute_fields']) && is_array($content['attribute_fields'])) {
            foreach ($content['attribute_fields'] as $key => $value) {
                $attributeFields[$key] = $value;
            }
        }
        
        if (isset($content['jobs']) && is_array($content['jobs'])) {
            foreach ($content['jobs'] as $key => $value) {
                $jobs[$key] = $value;
            }
        }
        
        echo ".";
        if ($count % 50 == 0) echo " $count\n";
        
    } catch (Exception $e) {
        echo "\nError parsing {$file->getFilename()}: " . $e->getMessage() . "\n";
    }
}

echo "\n\nFound:\n";
echo "  - Extensions: " . count($extensions) . "\n";
echo "  - Attribute Fields: " . count($attributeFields) . "\n";
echo "  - Jobs: " . count($jobs) . "\n";

// Write to extensions.json
$outputPath = __DIR__ . '/../public/js/extensions.json';
$output = [
    'extensions' => $extensions,
    'attribute_fields' => $attributeFields,
    'jobs' => $jobs
];

file_put_contents($outputPath, json_encode($output, JSON_PRETTY_PRINT));
echo "\n✓ Generated: $outputPath\n";

// Show sample of pim-app extension
if (isset($extensions['pim-app'])) {
    echo "\n✓ pim-app extension found:\n";
    echo json_encode($extensions['pim-app'], JSON_PRETTY_PRINT) . "\n";
} else {
    echo "\n✗ WARNING: pim-app extension NOT found!\n";
}

echo "\nFirst 5 extensions:\n";
$i = 0;
foreach ($extensions as $key => $value) {
    if ($i++ >= 5) break;
    echo "  - $key\n";
}

