<?php

require_once __DIR__ . '/MigrationAutoloader.php';
require_once __DIR__ . '/../../vendor/autoload.php';

use Migration\MigrationAutoloader;
use Migration\Database\MagentoConnection;
use Migration\Util\ProgressTracker;
use Pimcore\Bootstrap;
use Pimcore\Model\DataObject\ClassDefinition;

// Register our autoloader
MigrationAutoloader::register();

// Bootstrap Pimcore
Bootstrap::startup();

class OptimizedMigration
{
    private $db;
    private $logger;
    
    public function __construct()
    {
        $this->db = MagentoConnection::getInstance();
        $this->setupLogging();
    }
    
    private function setupLogging()
    {
        $logDir = __DIR__ . '/../logs';
        if (!is_dir($logDir)) {
            mkdir($logDir, 0777, true);
        }
        
        $this->logger = new \Monolog\Logger('migration');
        $this->logger->pushHandler(new \Monolog\Handler\StreamHandler(
            $logDir . '/migration_' . date('Y-m-d_His') . '.log',
            \Monolog\Logger::DEBUG
        ));
    }
    
    public function run()
    {
        try {
            $this->log("Starting optimized migration process...");
            
            // Step 1: Verify database connection
            $this->log("Testing database connection...");
            $productCount = $this->db->getProductCount();
            $this->log("Found $productCount products to migrate");
            
            // Step 2: Create/update class definitions
            $this->setupClassDefinitions();
            
            // Step 3: Import categories
            $this->importCategories();
            
            // Step 4: Import products in batches
            $this->importProducts($productCount);
            
            $this->log("Migration completed successfully!");
            
        } catch (\Exception $e) {
            $this->log("ERROR: " . $e->getMessage());
            $this->log($e->getTraceAsString());
            throw $e;
        }
    }
    
    private function setupClassDefinitions()
    {
        $this->log("Setting up class definitions...");
        
        // Load and create classes from definitions
        foreach (['Brand', 'Category', 'Product'] as $className) {
            $definitionFile = __DIR__ . "/../class-definitions/$className.php";
            if (file_exists($definitionFile)) {
                require_once $definitionFile;
                $class = "\\AppBundle\\Model\\DataObject\\{$className}Class";
                if (class_exists($class)) {
                    $class::create();
                    $this->log("Created/updated $className class definition");
                }
            }
        }
    }
    
    private function importCategories()
    {
        $this->log("Importing categories...");
        
        $categories = $this->db->getCategories();
        if (empty($categories)) {
            $this->log("No categories found to import");
            return;
        }
        
        $progress = new ProgressTracker(count($categories), "Categories");
        
        foreach ($categories as $cat) {
            try {
                // Create category object
                $category = new \Pimcore\Model\DataObject\Category();
                $category->setKey(\Pimcore\Model\Element\Service::getValidKey($cat['name'], 'object'));
                $category->setParent(\Pimcore\Model\DataObject\Service::createFolderByPath("/Categories"));
                $category->setPublished(true);
                
                // Set fields
                $category->setName($cat['name']);
                $category->setDescription($cat['description']);
                $category->setMagentoId($cat['entity_id']);
                $category->setSortOrder($cat['position']);
                
                $category->save();
                $progress->increment();
                
            } catch (\Exception $e) {
                $this->log("Error importing category {$cat['name']}: " . $e->getMessage());
            }
        }
    }
    
    private function importProducts($totalProducts)
    {
        $this->log("Starting product import...");

        \Pimcore\Model\Version::disable();

        $batchSize = 100; // larger batch for fewer DB trips
        $progress = new ProgressTracker($totalProducts, "Products");
        $offset = 0;

        do {
            $products = $this->db->getProducts($batchSize, $offset);
            if (empty($products)) {
                break;
            }

            foreach ($products as $prod) {
                try {
                    // Idempotent upsert by SKU or path
                    $existing = null;
                    if (method_exists(\Pimcore\Model\DataObject\Product::class, 'getBySku')) {
                        $existing = \Pimcore\Model\DataObject\Product::getBySku($prod['sku'], 1);
                        if (!($existing instanceof \Pimcore\Model\DataObject\Product)) {
                            $existing = null;
                        }
                    } else {
                        $path = '/Products/' . \Pimcore\Model\Element\Service::getValidKey($prod['sku'], 'object');
                        $existing = \Pimcore\Model\DataObject\Product::getByPath($path);
                    }

                    $product = $existing ?: new \Pimcore\Model\DataObject\Product();
                    if (!$existing) {
                        $product->setKey(\Pimcore\Model\Element\Service::getValidKey($prod['sku'], 'object'));
                        $product->setParent(\Pimcore\Model\DataObject\Service::createFolderByPath("/Products"));
                    }

                    // Set basic fields
                    if (method_exists($product, 'setSku')) $product->setSku($prod['sku']);
                    if (method_exists($product, 'setTitle')) $product->setTitle($prod['name'] ?? '');
                    if (method_exists($product, 'setDescription')) $product->setDescription($prod['description'] ?? '');
                    if (method_exists($product, 'setShortDescription')) $product->setShortDescription($prod['short_description'] ?? '');

                    // Import categories
                    $this->importProductCategories($product, $prod['entity_id']);

                    // Import images (guarded by config)
                    $this->importProductImages($product, $prod['entity_id']);

                    $product->setPublished(true);
                    $product->save();
                    $progress->increment();

                } catch (\Exception $e) {
                    $this->log("Error importing product {$prod['sku']}: " . $e->getMessage());
                }
            }

            $offset += $batchSize;

        } while (true);
    }
    
    private function importProductCategories($product, $productId)
    {
        $categoryIds = $this->db->getProductCategories($productId);
        $categories = [];
        
        foreach ($categoryIds as $catId) {
            $category = \Pimcore\Model\DataObject\Category::getByMagentoId($catId);
            if ($category) {
                $categories[] = $category;
            }
        }
        
        if (!empty($categories)) {
            $product->setCategories($categories);
        }
    }
    
    private function importProductImages($product, $productId)
    {
        $images = $this->db->getProductImages($productId);
        $gallery = [];
        
        foreach ($images as $img) {
            try {
                $asset = $this->importProductImage($img['file']);
                if ($asset) {
                    $gallery[] = $asset;
                }
            } catch (\Exception $e) {
                $this->log("Error importing image {$img['file']}: " . $e->getMessage());
            }
        }
        
        if (!empty($gallery)) {
            $product->setImages($gallery);
        }
    }
    
    private function importProductImage($imagePath)
    {
        $mediaBase = getenv('MAGENTO_MEDIA_BASE');
        if (!$mediaBase) {
            static $warned = false;
            if (!$warned) {
                $this->log('MAGENTO_MEDIA_BASE not set, skipping image imports');
                $warned = true;
            }
            return null;
        }

        $folder = \Pimcore\Model\Asset\Service::createFolderByPath("/product-images");
        $filename = basename($imagePath);
        $assetPath = '/product-images/' . $filename;

        // Check if asset already exists
        $asset = \Pimcore\Model\Asset::getByPath($assetPath);
        if ($asset) {
            return $asset;
        }

        $src = rtrim($mediaBase, '/') . '/' . ltrim($imagePath, '/');
        if (!is_file($src)) {
            $this->log("Image not found: $src");
            return null;
        }
        $imageData = @file_get_contents($src);

        if ($imageData) {
            $asset = new \Pimcore\Model\Asset();
            $asset->setParent($folder);
            $asset->setKey(\Pimcore\Model\Element\Service::getValidKey($filename, 'asset'));
            $asset->setData($imageData);
            $asset->save();

            return $asset;
        }

        return null;
    }
    
    private function log($message)
    {
        $this->logger->info($message);
        echo date('Y-m-d H:i:s') . " - $message\n";
    }
}

// Run the optimized migration
$migration = new OptimizedMigration();
$migration->run();