<?php

require_once __DIR__ . '/../../vendor/autoload.php';
require_once __DIR__ . '/MigrationAutoloader.php';

use Migration\Database\MagentoConnection;
use Migration\Util\ProgressTracker;
use Pimcore\Model\DataObject;
use Pimcore\Model\Element\Service;

class ResilientMigration
{
    private $db;
    private $logger;
    private $errors = [];
    private $stats = [
        'categories' => ['total' => 0, 'success' => 0, 'failed' => 0],
        'products' => ['total' => 0, 'success' => 0, 'failed' => 0],
    ];
    
    public function __construct()
    {
        $this->db = MagentoConnection::getInstance();
        $this->setupLogging();
    }
    
    public function run()
    {
        try {
            $this->log("Starting resilient migration process...");
            
            // Import categories first
            $categories = $this->db->getCategories();
            $this->stats['categories']['total'] = count($categories);
            
            $this->log("Starting category import: {$this->stats['categories']['total']} categories found");
            $this->importCategories($categories);
            
            // Import products
            $totalProducts = $this->db->getProductCount();
            $this->stats['products']['total'] = $totalProducts;
            
            $this->log("Starting product import: {$this->stats['products']['total']} products found");
            $this->importProducts();
            
            // Report results
            $this->reportResults();
            
        } catch (\Exception $e) {
            $this->logError("Fatal error: " . $e->getMessage());
            throw $e;
        }
    }
    
    private function importCategories($categories)
    {
        $progress = new ProgressTracker(count($categories), "Categories");
        $folder = DataObject\Service::createFolderByPath("/Categories");
        
        foreach ($categories as $cat) {
            try {
                if (empty($cat['name'])) {
                    $this->logWarning("Skipping category with empty name (ID: {$cat['entity_id']})");
                    $this->stats['categories']['failed']++;
                    continue;
                }
                
                $key = Service::getValidKey($cat['name'], 'object');
                
                // Check if category exists
                $existing = DataObject\Category::getByPath("/Categories/$key");
                if ($existing) {
                    $this->log("Category '{$cat['name']}' already exists, updating...");
                } else {
                    $category = new DataObject\Category();
                    $category->setKey($key);
                    $category->setParent($folder);
                }
                
                $category->setPublished(true);
                $category->setName($cat['name']);
                $category->setDescription($cat['description']);
                $category->setMagentoId($cat['entity_id']);
                $category->setSortOrder($cat['position']);
                
                $category->save();
                $this->stats['categories']['success']++;
                
            } catch (\Exception $e) {
                $this->logError("Error importing category '{$cat['name']}': " . $e->getMessage());
                $this->stats['categories']['failed']++;
            }
            
            $progress->increment();
        }
    }
    
    private function importProducts()
    {
        $batchSize = 50;
        $progress = new ProgressTracker($this->stats['products']['total'], "Products");
        $folder = DataObject\Service::createFolderByPath("/Products");
        $offset = 0;
        
        do {
            $products = $this->db->getProducts($batchSize, $offset);
            if (empty($products)) {
                break;
            }
            
            foreach ($products as $prod) {
                try {
                    if (empty($prod['sku'])) {
                        $this->logWarning("Skipping product with empty SKU (ID: {$prod['entity_id']})");
                        $this->stats['products']['failed']++;
                        continue;
                    }
                    
                    $key = Service::getValidKey($prod['sku'], 'object');
                    
                    // Check if product exists
                    $existing = DataObject\Product::getByPath("/Products/$key");
                    if ($existing) {
                        $this->log("Product '{$prod['sku']}' already exists, updating...");
                        $product = $existing;
                    } else {
                        $product = new DataObject\Product();
                        $product->setKey($key);
                        $product->setParent($folder);
                    }
                    
                    $product->setPublished(true);
                    $product->setSku($prod['sku']);
                    $product->setTitle($prod['name'] ?: $prod['sku']);
                    
                    // Set description in default language
                    if (!empty($prod['description'])) {
                        $product->setDescription($prod['description'], 'en');
                    }
                    if (!empty($prod['short_description'])) {
                        $product->setShortDescription($prod['short_description'], 'en');
                    }
                    
                    // Import categories
                    $this->importProductCategories($product, $prod['entity_id']);
                    
                    // Import images
                    $this->importProductImages($product, $prod['entity_id']);
                    
                    $product->save();
                    $this->stats['products']['success']++;
                    
                } catch (\Exception $e) {
                    $this->logError("Error importing product '{$prod['sku']}': " . $e->getMessage());
                    $this->stats['products']['failed']++;
                }
                
                $progress->increment();
            }
            
            $offset += $batchSize;
            
        } while (true);
    }
    
    private function importProductCategories($product, $productId)
    {
        $categoryIds = $this->db->getProductCategories($productId);
        $categories = [];
        
        foreach ($categoryIds as $catId) {
            $category = DataObject\Category::getByMagentoId($catId, ['limit' => 1]);
            if ($category instanceof DataObject\Category) {
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
                $this->logWarning("Error importing image {$img['file']}: " . $e->getMessage());
            }
        }
        
        if (!empty($gallery)) {
            $product->setImages($gallery);
        }
    }
    
    private function importProductImage($imagePath)
    {
        $folder = DataObject\Service::createFolderByPath("/product-images");
        $filename = basename($imagePath);
        $assetPath = '/product-images/' . $filename;
        
        // Check if asset already exists
        $asset = \Pimcore\Model\Asset::getByPath($assetPath);
        if ($asset) {
            return $asset;
        }
        
        // Get image data from Magento
        $magentoMediaPath = '/path/to/magento/media/catalog/product' . $imagePath;
        if (file_exists($magentoMediaPath)) {
            $imageData = file_get_contents($magentoMediaPath);
            
            if ($imageData) {
                $asset = new \Pimcore\Model\Asset();
                $asset->setParent($folder);
                $asset->setKey(Service::getValidKey($filename, 'asset'));
                $asset->setData($imageData);
                $asset->save();
                
                return $asset;
            }
        }
        
        return null;
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
    
    private function reportResults()
    {
        $this->log("\nMigration Results:");
        $this->log("=================");
        $this->log("Categories:");
        $this->log("  Total: {$this->stats['categories']['total']}");
        $this->log("  Successful: {$this->stats['categories']['success']}");
        $this->log("  Failed: {$this->stats['categories']['failed']}");
        $this->log("\nProducts:");
        $this->log("  Total: {$this->stats['products']['total']}");
        $this->log("  Successful: {$this->stats['products']['success']}");
        $this->log("  Failed: {$this->stats['products']['failed']}");
        
        if (!empty($this->errors)) {
            $this->log("\nErrors encountered:");
            foreach ($this->errors as $error) {
                $this->log("- $error");
            }
        }
    }
    
    private function log($message)
    {
        $this->logger->info($message);
        echo date('Y-m-d H:i:s') . " - $message\n";
    }
    
    private function logWarning($message)
    {
        $this->logger->warning($message);
        echo date('Y-m-d H:i:s') . " - WARNING: $message\n";
    }
    
    private function logError($message)
    {
        $this->errors[] = $message;
        $this->logger->error($message);
        echo date('Y-m-d H:i:s') . " - ERROR: $message\n";
    }
}

// Set up error handling
ini_set('display_errors', 1);
error_reporting(E_ALL);
set_error_handler(function($errno, $errstr, $errfile, $errline) {
    throw new ErrorException($errstr, 0, $errno, $errfile, $errline);
});

// Increase memory limit and execution time
ini_set('memory_limit', '2G');
set_time_limit(0);

// Run the migration
try {
    $migration = new ResilientMigration();
    $migration->run();
} catch (\Exception $e) {
    echo "Fatal error: " . $e->getMessage() . "\n";
    echo "Stack trace:\n" . $e->getTraceAsString() . "\n";
    exit(1);
}