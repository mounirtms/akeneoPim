<?php

// Set up error handling
ini_set('display_errors', 1);
error_reporting(E_ALL);

try {
    $projectRoot = realpath(__DIR__ . '/../..');
    require_once $projectRoot . '/vendor/autoload.php';

    // Load environment variables
    if (file_exists($projectRoot . '/.env')) {
        (new \Symfony\Component\Dotenv\Dotenv())->load($projectRoot . '/.env');
    }

    // Initialize Pimcore
    \Pimcore\Bootstrap::setProjectRoot($projectRoot);
    $kernel = \Pimcore\Bootstrap::startupCli();
    \Pimcore::setKernel($kernel);

    // Initialize database if needed
    $setup = new \Pimcore\Bundle\InstallBundle\Installer();
    if (!$setup->isInstalled()) {
        echo "Initializing Pimcore database...\n";
        $setup->setupDatabase([
            'username' => 'root',
            'password' => 'YourNewStrongPassword',
            'dbname' => 'pimcore',
            'host' => '127.0.0.1',
            'port' => 3307
        ]);
        echo "Pimcore database initialized\n";
    }

    echo "Pimcore bootstrapped successfully\n";
} catch (\Exception $e) {
    echo "Error during initialization: " . $e->getMessage() . "\n";
    echo "Stack trace:\n" . $e->getTraceAsString() . "\n";
    exit(1);
}

use Pimcore\Model\DataObject;
use Pimcore\Model\Element\Service;
use PDO;
use PDOException;

class MagentoConnection {
    private $pdo;
    private static $instance = null;
    
    public function __construct() {
        try {
            $this->pdo = new PDO(
                'mysql:host=127.0.0.1;port=3307;dbname=technadminy7_dBT8x12y22;charset=utf8mb4',
                'root',
                'YourNewStrongPassword',
                [
                    PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                    PDO::MYSQL_ATTR_INIT_COMMAND => "SET NAMES utf8mb4"
                ]
            );
        } catch (PDOException $e) {
            throw new \RuntimeException("Could not connect to Magento database: " . $e->getMessage());
        }
    }
    
    public static function getInstance() {
        if (self::$instance === null) {
            self::$instance = new self();
        }
        return self::$instance;
    }
    
    public function getProductCount() {
        try {
            $sql = "SELECT COUNT(DISTINCT e.entity_id) as count FROM catalog_product_entity e";
            return $this->pdo->query($sql)->fetch()['count'];
        } catch (PDOException $e) {
            throw new \RuntimeException("Error getting product count: " . $e->getMessage());
        }
    }
    
    public function getCategories() {
        try {
            $sql = "SELECT DISTINCT
                        e.entity_id,
                        vn.value as name,
                        e.parent_id,
                        e.position,
                        vd.value as description
                    FROM catalog_category_entity e
                    LEFT JOIN catalog_category_entity_varchar vn ON e.entity_id = vn.entity_id 
                        AND vn.attribute_id = (SELECT attribute_id FROM eav_attribute WHERE attribute_code = 'name' 
                            AND entity_type_id = (SELECT entity_type_id FROM eav_entity_type WHERE entity_type_code = 'catalog_category'))
                    LEFT JOIN catalog_category_entity_text vd ON e.entity_id = vd.entity_id 
                        AND vd.attribute_id = (SELECT attribute_id FROM eav_attribute WHERE attribute_code = 'description' 
                            AND entity_type_id = (SELECT entity_type_id FROM eav_entity_type WHERE entity_type_code = 'catalog_category'))
                    WHERE e.level > 0
                    ORDER BY e.parent_id, e.position";
            return $this->pdo->query($sql)->fetchAll();
        } catch (PDOException $e) {
            throw new \RuntimeException("Error getting categories: " . $e->getMessage());
        }
    }
    
    public function getProducts($limit = null, $offset = 0) {
        try {
            $sql = "SELECT DISTINCT
                        e.entity_id,
                        e.sku,
                        vn.value as name,
                        vd.value as description,
                        vs.value as short_description,
                        e.created_at,
                        e.updated_at
                    FROM catalog_product_entity e
                    LEFT JOIN catalog_product_entity_varchar vn ON e.entity_id = vn.entity_id 
                        AND vn.attribute_id = (SELECT attribute_id FROM eav_attribute WHERE attribute_code = 'name' 
                            AND entity_type_id = (SELECT entity_type_id FROM eav_entity_type WHERE entity_type_code = 'catalog_product'))
                    LEFT JOIN catalog_product_entity_text vd ON e.entity_id = vd.entity_id 
                        AND vd.attribute_id = (SELECT attribute_id FROM eav_attribute WHERE attribute_code = 'description' 
                            AND entity_type_id = (SELECT entity_type_id FROM eav_entity_type WHERE entity_type_code = 'catalog_product'))
                    LEFT JOIN catalog_product_entity_text vs ON e.entity_id = vs.entity_id 
                        AND vs.attribute_id = (SELECT attribute_id FROM eav_attribute WHERE attribute_code = 'short_description' 
                            AND entity_type_id = (SELECT entity_type_id FROM eav_entity_type WHERE entity_type_code = 'catalog_product'))";
                            
            if ($limit) {
                $sql .= " LIMIT " . (int)$offset . ", " . (int)$limit;
            }
            
            return $this->pdo->query($sql)->fetchAll();
        } catch (PDOException $e) {
            throw new \RuntimeException("Error getting products: " . $e->getMessage());
        }
    }
    
    public function getProductCategories($productId) {
        try {
            $sql = "SELECT category_id FROM catalog_category_product WHERE product_id = ?";
            $stmt = $this->pdo->prepare($sql);
            $stmt->execute([$productId]);
            return $stmt->fetchAll(PDO::FETCH_COLUMN);
        } catch (PDOException $e) {
            throw new \RuntimeException("Error getting product categories: " . $e->getMessage());
        }
    }
    
    public function getProductImages($productId) {
        try {
            $sql = "SELECT 
                        g.value as file,
                        v.position,
                        v.label
                    FROM catalog_product_entity_media_gallery g
                    LEFT JOIN catalog_product_entity_media_gallery_value v ON g.value_id = v.value_id
                    WHERE g.entity_id = ?
                    ORDER BY v.position";
            $stmt = $this->pdo->prepare($sql);
            $stmt->execute([$productId]);
            return $stmt->fetchAll();
        } catch (PDOException $e) {
            throw new \RuntimeException("Error getting product images: " . $e->getMessage());
        }
    }
}

class ProgressTracker {
    private $total;
    private $current = 0;
    private $lastUpdate = 0;
    private $startTime;
    private $name;
    
    public function __construct($total, $name = 'Progress') {
        $this->total = $total;
        $this->name = $name;
        $this->startTime = microtime(true);
        $this->updateProgress(0);
    }
    
    public function increment($amount = 1) {
        $this->current += $amount;
        $this->updateProgress();
    }
    
    private function updateProgress() {
        $now = microtime(true);
        // Update every 1 second or when complete
        if ($now - $this->lastUpdate >= 1 || $this->current >= $this->total) {
            $percent = ($this->total > 0) ? round(($this->current / $this->total) * 100, 1) : 0;
            $elapsed = $now - $this->startTime;
            $rate = ($elapsed > 0) ? round($this->current / $elapsed, 2) : 0;
            $eta = ($rate > 0) ? round(($this->total - $this->current) / $rate) : 0;
            
            echo sprintf("\r%s: [%-50s] %d/%d (%s%%) - %s/s - ETA: %s     ",
                $this->name,
                str_repeat('=', floor($percent / 2)) . '>',
                $this->current,
                $this->total,
                $percent,
                $rate,
                $this->formatTime($eta)
            );
            
            if ($this->current >= $this->total) {
                echo "\nCompleted in " . round($elapsed, 2) . " seconds\n";
            }
            
            $this->lastUpdate = $now;
        }
    }
    
    private function formatTime($seconds) {
        if ($seconds < 60) {
            return round($seconds) . 's';
        } elseif ($seconds < 3600) {
            return round($seconds / 60) . 'm';
        } else {
            return round($seconds / 3600, 1) . 'h';
        }
    }
}

class ResilientMigration {
    private $db;
    private $logger;
    private $errors = [];
    private $stats = [
        'categories' => ['total' => 0, 'success' => 0, 'failed' => 0],
        'products' => ['total' => 0, 'success' => 0, 'failed' => 0],
    ];
    
    public function __construct() {
        $this->db = MagentoConnection::getInstance();
        $this->setupLogging();
    }
    
    private function setupFolderStructure() {
        $this->log("Setting up folder structure...");
        
        // Get root folder (ID 1)
        $root = DataObject::getById(1);
        if (!$root instanceof DataObject\Folder) {
            $this->log("ERROR: Root folder (ID 1) not found!");
            throw new \RuntimeException("Root folder (ID 1) not found!");
        }
        
        // Create Categories folder
        $categoriesFolder = DataObject\Folder::getByPath("/Categories");
        if (!$categoriesFolder instanceof DataObject\Folder) {
            $categoriesFolder = new DataObject\Folder();
            $categoriesFolder->setKey("Categories");
            $categoriesFolder->setParent($root);
            $categoriesFolder->save();
            $this->log("Created Categories folder");
        }
        
        // Create Products folder
        $productsFolder = DataObject\Folder::getByPath("/Products");
        if (!$productsFolder instanceof DataObject\Folder) {
            $productsFolder = new DataObject\Folder();
            $productsFolder->setKey("Products");
            $productsFolder->setParent($root);
            $productsFolder->save();
            $this->log("Created Products folder");
        }
        
        // Create product-images folder
        $imagesFolder = DataObject\Folder::getByPath("/product-images");
        if (!$imagesFolder instanceof DataObject\Folder) {
            $imagesFolder = new DataObject\Folder();
            $imagesFolder->setKey("product-images");
            $imagesFolder->setParent($root);
            $imagesFolder->save();
            $this->log("Created product-images folder");
        }
    }

    public function run() {
        try {
            $this->log("Starting resilient migration process...");
            
            // Set up folder structure
            $this->setupFolderStructure();
            
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
    
    private function importCategories($categories) {
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
                    $category = $existing;
                } else {
                    $category = new DataObject\Category();
                    $category->setKey($key);
                    $category->setParent($folder);
                }
                
                $category->setPublished(true);
                $category->setName($cat['name'], 'en');
                $category->setDescription($cat['description'], 'en');
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
    
    private function importProducts() {
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
                    $product->setTitle($prod['name'] ?: $prod['sku'], 'en');
                    
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
    
    private function importProductCategories($product, $productId) {
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
    
    private function importProductImages($product, $productId) {
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
    
    private function importProductImage($imagePath) {
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
    
    private function setupLogging() {
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
    
    private function reportResults() {
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
    
    private function log($message) {
        $this->logger->info($message);
        echo date('Y-m-d H:i:s') . " - $message\n";
    }
    
    private function logWarning($message) {
        $this->logger->warning($message);
        echo date('Y-m-d H:i:s') . " - WARNING: $message\n";
    }
    
    private function logError($message) {
        $this->errors[] = $message;
        $this->logger->error($message);
        echo date('Y-m-d H:i:s') . " - ERROR: $message\n";
    }
}

// Set up error handling
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