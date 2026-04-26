<?php
/**
 * Akeneo to Magento 2 Sync Script
 * 
 * This script synchronizes products from Akeneo PIM to Magento 2 via REST API
 * 
 * Usage:
 *   php magento_sync.php --help
 *   php magento_sync.php --test-connection
 *   php magento_sync.php --pilot --limit=10
 *   php magento_sync.php --sync-categories
 *   php magento_sync.php --sync-products --batch-size=100
 * 
 * Requirements:
 *   - PHP 8.0+
 *   - curl extension
 *   - json extension
 *   - Akeneo PIM OAuth credentials
 *   - Magento 2 API token
 */

// Configuration
$config = [
    // Akeneo PIM Configuration
    'akeneo' => [
        'base_url' => 'https://pim.technostationery.com',
        'client_id' => '4_2o7xez37350kkck0cgo4w4o4o4ogsgcg0oowgsg4s8g4g84c8k',
        'client_secret' => '19zy0z10644kw0gwgs0oc4w4cgss88c0g00844ssso8g0c4og8',
        'username' => 'testadmin',
        'password' => 'testpass',
    ],
    
    // Magento 2 Configuration (TO BE FILLED)
    'magento' => [
        'base_url' => '', // e.g., 'https://beta.magento.technostationery.com'
        'api_token' => '', // To be generated after providing URL
        'admin_user' => 'bot',
        'admin_password' => '@dM1n$#@2o25B0T',
    ],
    
    // Sync Configuration
    'sync' => [
        'batch_size' => 100,
        'delay_between_batches' => 5, // seconds
        'max_retries' => 3,
        'timeout' => 30, // seconds
        'log_file' => __DIR__ . '/../var/logs/magento_sync.log',
        'error_log' => __DIR__ . '/../var/logs/magento_sync_errors.log',
    ],
    
    // Attribute Mapping (Akeneo -> Magento)
    'attribute_mapping' => [
        'sku' => 'sku',
        'name' => 'name',
        'description' => 'description',
        'short_description' => 'short_description',
        'price' => 'price',
        'weight' => 'weight',
        'status' => 'status',
        'visibility' => 'visibility',
        'tax_class_id' => 'tax_class_id',
    ],
    
    // Default Values
    'defaults' => [
        'attribute_set_id' => 4, // Default attribute set
        'type_id' => 'simple',
        'status' => 1, // Enabled
        'visibility' => 4, // Catalog, Search
        'tax_class_id' => 2, // Taxable Goods
        'weight' => 1.0,
    ],
];

class AkeneoMagentoSync {
    private $config;
    private $akeneoToken;
    private $stats = [
        'products_synced' => 0,
        'products_failed' => 0,
        'categories_synced' => 0,
        'errors' => [],
    ];
    
    public function __construct($config) {
        $this->config = $config;
    }
    
    /**
     * Main execution entry point
     */
    public function run($options) {
        $this->log("=== Akeneo → Magento Sync Started ===\n");
        $this->log("Timestamp: " . date('Y-m-d H:i:s') . "\n");
        
        // Parse command line options
        $mode = $this->parseOptions($options);
        
        try {
            switch ($mode) {
                case 'help':
                    $this->showHelp();
                    break;
                    
                case 'test':
                    $this->testConnection();
                    break;
                    
                case 'pilot':
                    $limit = $options['limit'] ?? 10;
                    $this->syncProducts($limit, true);
                    break;
                    
                case 'categories':
                    $this->syncCategories();
                    break;
                    
                case 'products':
                    $batchSize = $options['batch-size'] ?? $this->config['sync']['batch_size'];
                    $this->syncProducts(null, false, $batchSize);
                    break;
                    
                case 'incremental':
                    $this->syncIncremental();
                    break;
                    
                default:
                    $this->showHelp();
            }
            
            $this->log("\n=== Sync Statistics ===");
            $this->log("Products Synced: " . $this->stats['products_synced']);
            $this->log("Products Failed: " . $this->stats['products_failed']);
            $this->log("Categories Synced: " . $this->stats['categories_synced']);
            
        } catch (Exception $e) {
            $this->logError("FATAL ERROR: " . $e->getMessage());
            $this->log("Sync failed. Check error log for details.");
            exit(1);
        }
        
        $this->log("\n=== Sync Complete ===\n");
    }
    
    /**
     * Test connections to both Akeneo and Magento
     */
    private function testConnection() {
        $this->log("Testing Akeneo PIM connection...");
        
        // Get Akeneo token
        $this->akeneoToken = $this->getAkeneoToken();
        if ($this->akeneoToken) {
            $this->log("✓ Akeneo OAuth successful");
        } else {
            throw new Exception("Failed to get Akeneo token");
        }
        
        // Test Akeneo API
        $products = $this->getAkeneoProducts(1);
        if ($products) {
            $this->log("✓ Akeneo API accessible");
            $this->log("  Sample product SKU: " . $products[0]['identifier']);
        } else {
            throw new Exception("Failed to fetch products from Akeneo");
        }
        
        // Test Magento (if configured)
        if (!empty($this->config['magento']['base_url']) && !empty($this->config['magento']['api_token'])) {
            $this->log("\nTesting Magento 2 connection...");
            
            $response = $this->magentoRequest('GET', '/rest/V1/products?searchCriteria[pageSize]=1');
            if ($response && isset($response['items'])) {
                $this->log("✓ Magento API accessible");
                $this->log("  Current product count: " . ($response['total_count'] ?? 0));
            } else {
                $this->log("⚠ Magento API test failed or not configured");
            }
        } else {
            $this->log("\n⚠ Magento configuration not complete");
            $this->log("  Please add Magento URL and API token to config");
        }
        
        $this->log("\n✓ Connection test complete");
    }
    
    /**
     * Get OAuth access token from Akeneo
     */
    private function getAkeneoToken() {
        $url = $this->config['akeneo']['base_url'] . '/api/oauth/v1/token';
        
        $data = [
            'grant_type' => 'password',
            'client_id' => $this->config['akeneo']['client_id'],
            'client_secret' => $this->config['akeneo']['client_secret'],
            'username' => $this->config['akeneo']['username'],
            'password' => $this->config['akeneo']['password'],
        ];
        
        $ch = curl_init($url);
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_POSTFIELDS, http_build_query($data));
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
        
        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);
        
        if ($httpCode === 200) {
            $result = json_decode($response, true);
            return $result['access_token'] ?? null;
        }
        
        return null;
    }
    
    /**
     * Get products from Akeneo API
     */
    private function getAkeneoProducts($limit = null, $page = 1) {
        if (!$this->akeneoToken) {
            $this->akeneoToken = $this->getAkeneoToken();
        }
        
        $url = $this->config['akeneo']['base_url'] . '/api/rest/v1/products';
        $url .= '?limit=' . ($limit ?? 100);
        $url .= '&page=' . $page;
        
        $ch = curl_init($url);
        curl_setopt($ch, CURLOPT_HTTPHEADER, [
            'Authorization: Bearer ' . $this->akeneoToken,
            'Content-Type: application/json',
        ]);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
        
        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);
        
        if ($httpCode === 200) {
            $result = json_decode($response, true);
            return $result['_embedded']['items'] ?? [];
        }
        
        return [];
    }
    
    /**
     * Sync products to Magento
     */
    private function syncProducts($limit = null, $dryRun = false, $batchSize = 100) {
        $this->log("\n=== Syncing Products ===");
        $this->log("Mode: " . ($dryRun ? "DRY RUN (Pilot)" : "LIVE SYNC"));
        $this->log("Limit: " . ($limit ?? "ALL"));
        $this->log("Batch Size: $batchSize\n");
        
        if (empty($this->config['magento']['base_url'])) {
            $this->log("⚠ Magento URL not configured. Cannot proceed with sync.");
            $this->log("Please provide Magento 2 Beta URL in config.");
            return;
        }
        
        $page = 1;
        $processed = 0;
        
        while (true) {
            $products = $this->getAkeneoProducts($batchSize, $page);
            
            if (empty($products)) {
                break;
            }
            
            foreach ($products as $product) {
                if ($limit && $processed >= $limit) {
                    break 2;
                }
                
                $this->log("Processing: " . $product['identifier']);
                
                if (!$dryRun) {
                    // TODO: Implement actual Magento sync
                    // $this->syncProductToMagento($product);
                    $this->log("  → Would sync to Magento (not implemented yet)");
                } else {
                    $this->log("  → Dry run - no changes made");
                }
                
                $processed++;
                $this->stats['products_synced']++;
            }
            
            $page++;
            
            if ($this->config['sync']['delay_between_batches'] > 0) {
                sleep($this->config['sync']['delay_between_batches']);
            }
        }
        
        $this->log("\nProcessed $processed products");
    }
    
    /**
     * Sync categories to Magento
     */
    private function syncCategories() {
        $this->log("\n=== Syncing Categories ===");
        // TODO: Implement category sync
        $this->log("Category sync not yet implemented");
    }
    
    /**
     * Make request to Magento API
     */
    private function magentoRequest($method, $endpoint, $data = null) {
        if (empty($this->config['magento']['api_token'])) {
            return null;
        }
        
        $url = $this->config['magento']['base_url'] . $endpoint;
        
        $ch = curl_init($url);
        curl_setopt($ch, CURLOPT_CUSTOMREQUEST, $method);
        curl_setopt($ch, CURLOPT_HTTPHEADER, [
            'Authorization: Bearer ' . $this->config['magento']['api_token'],
            'Content-Type: application/json',
        ]);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
        
        if ($data) {
            curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
        }
        
        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);
        
        if ($httpCode >= 200 && $httpCode < 300) {
            return json_decode($response, true);
        }
        
        return null;
    }
    
    /**
     * Parse command line options
     */
    private function parseOptions($argv) {
        if (isset($argv['help'])) {
            return 'help';
        }
        if (isset($argv['test-connection'])) {
            return 'test';
        }
        if (isset($argv['pilot'])) {
            return 'pilot';
        }
        if (isset($argv['sync-categories'])) {
            return 'categories';
        }
        if (isset($argv['sync-products'])) {
            return 'products';
        }
        if (isset($argv['incremental'])) {
            return 'incremental';
        }
        
        return 'help';
    }
    
    /**
     * Show help message
     */
    private function showHelp() {
        echo "\nAkeneo → Magento 2 Sync Script\n";
        echo "===============================\n\n";
        echo "Usage:\n";
        echo "  php magento_sync.php --help\n";
        echo "  php magento_sync.php --test-connection\n";
        echo "  php magento_sync.php --pilot --limit=10\n";
        echo "  php magento_sync.php --sync-categories\n";
        echo "  php magento_sync.php --sync-products --batch-size=100\n";
        echo "  php magento_sync.php --incremental\n\n";
        echo "Options:\n";
        echo "  --help              Show this help message\n";
        echo "  --test-connection   Test Akeneo and Magento connectivity\n";
        echo "  --pilot             Run pilot sync (10 products by default)\n";
        echo "  --limit=N           Limit number of products to sync\n";
        echo "  --sync-categories   Sync categories only\n";
        echo "  --sync-products     Sync all products\n";
        echo "  --batch-size=N      Number of products per batch (default: 100)\n";
        echo "  --incremental       Sync only updated products\n\n";
    }
    
    /**
     * Log message
     */
    private function log($message) {
        echo $message . "\n";
        
        if (!empty($this->config['sync']['log_file'])) {
            file_put_contents(
                $this->config['sync']['log_file'],
                date('[Y-m-d H:i:s] ') . $message . "\n",
                FILE_APPEND
            );
        }
    }
    
    /**
     * Log error
     */
    private function logError($message) {
        $this->log("ERROR: " . $message);
        
        if (!empty($this->config['sync']['error_log'])) {
            file_put_contents(
                $this->config['sync']['error_log'],
                date('[Y-m-d H:i:s] ') . $message . "\n",
                FILE_APPEND
            );
        }
        
        $this->stats['errors'][] = $message;
    }
}

// Main execution
if (php_sapi_name() === 'cli') {
    // Parse command line arguments
    $options = getopt('', [
        'help',
        'test-connection',
        'pilot',
        'sync-categories',
        'sync-products',
        'incremental',
        'limit:',
        'batch-size:',
    ]);
    
    $sync = new AkeneoMagentoSync($config);
    $sync->run($options);
}
