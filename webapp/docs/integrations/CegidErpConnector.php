<?php
/**
 * Cegid ERP API Connector for Akeneo PIM
 * 
 * This connector handles bi-directional synchronization between
 * Akeneo PIM and Cegid Retail/Y2 ERP system.
 * 
 * @author Akeneo Integration Team
 * @date April 23, 2026
 */

namespace AkeneoIntegration\CegidErp;

class CegidErpConnector
{
    private $config;
    private $client;
    private $sftpClient;
    private $logger;
    private $transformer;
    
    /**
     * Configuration
     */
    private const CONFIG = [
        // Cegid API Connection
        'cegid_api_url' => 'https://your-cegid-server.com/api/v1',
        'cegid_api_key' => '', // Set via environment variable
        'cegid_api_secret' => '', // Set via environment variable
        'cegid_company_code' => 'TECHNO',
        
        // Cegid SFTP Connection
        'sftp_host' => 'sftp.cegid-server.com',
        'sftp_port' => 22,
        'sftp_username' => 'akeneo',
        'sftp_password' => '', // Set via environment variable
        'sftp_private_key' => '/path/to/private/key',
        'sftp_import_path' => '/import/products/',
        'sftp_export_path' => '/export/products/',
        
        // Akeneo Connection
        'akeneo_base_url' => 'https://pim.technostationery.com',
        'akeneo_client_id' => '2_ml5f52erhggg0s484gckwgs4kg8gwc4c48ksgko4gkgos4k48',
        'akeneo_client_secret' => '', // Set via environment variable
        'akeneo_username' => 'apiconnector',
        'akeneo_password' => 'ApiP@ss2026!',
        'akeneo_channel' => 'cegid_erp',
        
        // Sync Configuration
        'batch_size' => 100,
        'retry_attempts' => 3,
        'timeout' => 120,
        'file_format' => 'UDX', // UDX or CSV
    ];
    
    /**
     * Field Mapping: Akeneo => Cegid
     */
    private const FIELD_MAPPING = [
        // Product Master
        'identifier' => 'Article.Code',              // Product Code
        'sku' => 'Article.CodeBarre',                // Barcode
        'name' => 'Article.Libelle',                 // Description
        'short_description' => 'Article.LibelleCourt', // Short Description
        
        // Pricing
        'price-DZD' => 'TarifVente.PrixVente',      // Selling Price
        'cost' => 'TarifAchat.PrixAchat',           // Purchase Price
        'tax_rate' => 'Article.TauxTVA',            // VAT Rate
        
        // Physical Attributes
        'weight' => 'Article.Poids',                 // Weight
        'volume' => 'Article.Volume',                // Volume
        'color' => 'Article.Coloris',                // Color
        'size' => 'Article.Taille',                  // Size
        
        // Inventory
        'stock_quantity' => 'Stock.QteDispo',        // Available Qty
        'warehouse' => 'Stock.CodeDepot',            // Warehouse Code
        'min_stock' => 'Stock.SeuilMini',            // Minimum Stock
        'max_stock' => 'Stock.SeuilMaxi',            // Maximum Stock
        
        // Categories
        'categories' => 'Famille.Code',              // Product Family
        'brand' => 'Marque.Code',                    // Brand Code
        
        // Supplier
        'supplier' => 'Fournisseur.Code',            // Supplier Code
        'supplier_ref' => 'Article.RefFournisseur',  // Supplier Reference
        
        // Sales
        'min_order_qty' => 'Article.QteVenteMini',   // Minimum Sale Qty
        'is_active' => 'Article.Actif',              // Active Status
    ];
    
    public function __construct()
    {
        $this->loadConfig();
        $this->initializeClients();
        $this->logger = new Logger('cegid_erp');
        $this->transformer = new DataTransformer();
    }
    
    /**
     * Export products from Akeneo to Cegid ERP
     * 
     * @param array $productIdentifiers
     * @return array Results
     */
    public function exportToCegid(array $productIdentifiers): array
    {
        $results = [
            'success' => 0,
            'failed' => 0,
            'errors' => [],
            'file_path' => null
        ];
        
        $this->logger->info('Starting Cegid export', [
            'product_count' => count($productIdentifiers)
        ]);
        
        try {
            // Fetch products from Akeneo
            $products = $this->fetchAkeneoProducts($productIdentifiers);
            
            // Transform to Cegid format
            $cegidData = $this->transformer->toCegidFormat($products, self::FIELD_MAPPING);
            
            // Generate export file
            $exportFile = $this->generateExportFile($cegidData);
            $results['file_path'] = $exportFile;
            
            // Upload to Cegid SFTP
            if ($this->uploadToSftp($exportFile)) {
                $results['success'] = count($products);
                
                // Trigger Cegid import job (if API available)
                $this->triggerCegidImport('product_import');
                
            } else {
                $results['failed'] = count($products);
                $results['errors'][] = 'Failed to upload file to SFTP';
            }
            
        } catch (\Exception $e) {
            $results['failed'] = count($productIdentifiers);
            $results['errors'][] = $e->getMessage();
            $this->logger->error('Cegid export failed', [
                'error' => $e->getMessage()
            ]);
        }
        
        $this->logger->info('Cegid export complete', $results);
        return $results;
    }
    
    /**
     * Import updates from Cegid ERP to Akeneo
     * 
     * @param string $updateType price|stock|master
     * @return array Results
     */
    public function importFromCegid(string $updateType = 'price'): array
    {
        $results = [
            'success' => 0,
            'failed' => 0,
            'errors' => []
        ];
        
        $this->logger->info('Starting Cegid import', [
            'update_type' => $updateType
        ]);
        
        try {
            // Download file from Cegid SFTP
            $fileName = $this->getLatestCegidFile($updateType);
            
            if (!$fileName) {
                throw new \Exception('No Cegid export file found');
            }
            
            $localFile = $this->downloadFromSftp($fileName);
            
            // Parse Cegid file
            $cegidData = $this->parseCegidFile($localFile);
            
            // Transform to Akeneo format
            $akeneoData = $this->transformer->toAkeneoFormat($cegidData, self::FIELD_MAPPING);
            
            // Update in Akeneo
            foreach ($akeneoData as $productData) {
                try {
                    $this->updateAkeneoProduct($productData);
                    $results['success']++;
                } catch (\Exception $e) {
                    $results['failed']++;
                    $results['errors'][] = [
                        'product' => $productData['identifier'],
                        'error' => $e->getMessage()
                    ];
                }
            }
            
            // Archive processed file
            $this->archiveCegidFile($fileName);
            
        } catch (\Exception $e) {
            $this->logger->error('Cegid import failed', [
                'error' => $e->getMessage()
            ]);
            throw $e;
        }
        
        $this->logger->info('Cegid import complete', $results);
        return $results;
    }
    
    /**
     * Generate export file in Cegid format (UDX or CSV)
     */
    private function generateExportFile(array $data): string
    {
        $timestamp = date('Ymd_His');
        $fileName = "akeneo_products_{$timestamp}";
        
        if ($this->config['file_format'] === 'UDX') {
            return $this->generateUdxFile($data, $fileName);
        } else {
            return $this->generateCsvFile($data, $fileName);
        }
    }
    
    /**
     * Generate UDX (Cegid proprietary format) file
     */
    private function generateUdxFile(array $data, string $fileName): string
    {
        $filePath = "/tmp/{$fileName}.udx";
        $handle = fopen($filePath, 'w');
        
        // UDX Header
        fwrite($handle, "TYPE=ARTICLE\n");
        fwrite($handle, "VERSION=1.0\n");
        fwrite($handle, "DATE=" . date('Y-m-d H:i:s') . "\n");
        fwrite($handle, "COUNT=" . count($data) . "\n");
        fwrite($handle, "---\n");
        
        // UDX Data
        foreach ($data as $product) {
            fwrite($handle, "[ARTICLE]\n");
            foreach ($product as $field => $value) {
                fwrite($handle, "$field=$value\n");
            }
            fwrite($handle, "[/ARTICLE]\n");
        }
        
        fclose($handle);
        
        $this->logger->info("Generated UDX file: $filePath");
        return $filePath;
    }
    
    /**
     * Generate CSV file
     */
    private function generateCsvFile(array $data, string $fileName): string
    {
        $filePath = "/tmp/{$fileName}.csv";
        $handle = fopen($filePath, 'w');
        
        // CSV Header
        if (count($data) > 0) {
            fputcsv($handle, array_keys($data[0]), ';');
        }
        
        // CSV Data
        foreach ($data as $product) {
            fputcsv($handle, $product, ';');
        }
        
        fclose($handle);
        
        $this->logger->info("Generated CSV file: $filePath");
        return $filePath;
    }
    
    /**
     * Parse Cegid file (UDX or CSV)
     */
    private function parseCegidFile(string $filePath): array
    {
        $extension = pathinfo($filePath, PATHINFO_EXTENSION);
        
        if ($extension === 'udx') {
            return $this->parseUdxFile($filePath);
        } else {
            return $this->parseCsvFile($filePath);
        }
    }
    
    /**
     * Parse UDX file
     */
    private function parseUdxFile(string $filePath): array
    {
        $data = [];
        $currentProduct = [];
        $inProduct = false;
        
        $lines = file($filePath, FILE_IGNORE_NEW_LINES);
        
        foreach ($lines as $line) {
            if ($line === '[ARTICLE]') {
                $inProduct = true;
                $currentProduct = [];
            } elseif ($line === '[/ARTICLE]') {
                $inProduct = false;
                if (!empty($currentProduct)) {
                    $data[] = $currentProduct;
                }
            } elseif ($inProduct && strpos($line, '=') !== false) {
                list($key, $value) = explode('=', $line, 2);
                $currentProduct[$key] = $value;
            }
        }
        
        return $data;
    }
    
    /**
     * Parse CSV file
     */
    private function parseCsvFile(string $filePath): array
    {
        $data = [];
        $handle = fopen($filePath, 'r');
        
        // Read header
        $header = fgetcsv($handle, 0, ';');
        
        // Read data
        while (($row = fgetcsv($handle, 0, ';')) !== false) {
            $data[] = array_combine($header, $row);
        }
        
        fclose($handle);
        
        return $data;
    }
    
    /**
     * Upload file to Cegid SFTP
     */
    private function uploadToSftp(string $localFile): bool
    {
        try {
            $remoteFile = $this->config['sftp_import_path'] . basename($localFile);
            
            $this->sftpClient->put($remoteFile, $localFile);
            
            $this->logger->info("Uploaded file to SFTP: $remoteFile");
            return true;
            
        } catch (\Exception $e) {
            $this->logger->error("SFTP upload failed", [
                'error' => $e->getMessage()
            ]);
            return false;
        }
    }
    
    /**
     * Download file from Cegid SFTP
     */
    private function downloadFromSftp(string $remoteFile): string
    {
        $localFile = "/tmp/" . basename($remoteFile);
        
        try {
            $this->sftpClient->get($remoteFile, $localFile);
            
            $this->logger->info("Downloaded file from SFTP: $remoteFile");
            return $localFile;
            
        } catch (\Exception $e) {
            $this->logger->error("SFTP download failed", [
                'error' => $e->getMessage()
            ]);
            throw $e;
        }
    }
    
    /**
     * Get latest Cegid export file
     */
    private function getLatestCegidFile(string $updateType): ?string
    {
        try {
            $files = $this->sftpClient->nlist($this->config['sftp_export_path']);
            
            // Filter by update type
            $pattern = "/{$updateType}_";
            $matchingFiles = array_filter($files, function($file) use ($pattern) {
                return preg_match($pattern, $file);
            });
            
            if (empty($matchingFiles)) {
                return null;
            }
            
            // Sort by date (newest first)
            rsort($matchingFiles);
            
            return $this->config['sftp_export_path'] . $matchingFiles[0];
            
        } catch (\Exception $e) {
            $this->logger->error("Failed to list SFTP files", [
                'error' => $e->getMessage()
            ]);
            return null;
        }
    }
    
    /**
     * Archive processed Cegid file
     */
    private function archiveCegidFile(string $fileName): void
    {
        try {
            $archivePath = str_replace('/export/', '/archive/', $fileName);
            $this->sftpClient->rename($fileName, $archivePath);
            
            $this->logger->info("Archived file: $archivePath");
            
        } catch (\Exception $e) {
            $this->logger->warning("Failed to archive file", [
                'file' => $fileName,
                'error' => $e->getMessage()
            ]);
        }
    }
    
    /**
     * Trigger Cegid import job via API
     */
    private function triggerCegidImport(string $jobName): void
    {
        try {
            $response = $this->client->post('/jobs/trigger', [
                'json' => [
                    'jobName' => $jobName,
                    'companyCode' => $this->config['cegid_company_code']
                ]
            ]);
            
            $this->logger->info("Triggered Cegid import job: $jobName");
            
        } catch (\Exception $e) {
            $this->logger->warning("Failed to trigger Cegid import", [
                'job' => $jobName,
                'error' => $e->getMessage()
            ]);
        }
    }
    
    /**
     * Fetch products from Akeneo API
     */
    private function fetchAkeneoProducts(array $identifiers): array
    {
        $products = [];
        
        foreach ($identifiers as $identifier) {
            try {
                $product = $this->akeneoClient->getProductApi()->get($identifier);
                $products[] = $product;
            } catch (\Exception $e) {
                $this->logger->warning("Failed to fetch product $identifier", [
                    'error' => $e->getMessage()
                ]);
            }
        }
        
        return $products;
    }
    
    /**
     * Update product in Akeneo
     */
    private function updateAkeneoProduct(array $productData): void
    {
        $this->akeneoClient->getProductApi()->upsert(
            $productData['identifier'],
            $productData
        );
    }
    
    /**
     * Load configuration from environment
     */
    private function loadConfig(): void
    {
        $this->config = self::CONFIG;
        
        // Override with environment variables
        $this->config['cegid_api_key'] = getenv('CEGID_API_KEY') ?: '';
        $this->config['cegid_api_secret'] = getenv('CEGID_API_SECRET') ?: '';
        $this->config['sftp_password'] = getenv('CEGID_SFTP_PASSWORD') ?: '';
        $this->config['akeneo_client_secret'] = getenv('AKENEO_CLIENT_SECRET') ?: '';
        $this->config['akeneo_password'] = getenv('AKENEO_PASSWORD') ?: 'ApiP@ss2026!';
    }
    
    /**
     * Initialize HTTP and SFTP clients
     */
    private function initializeClients(): void
    {
        // Cegid API client
        $this->client = new \GuzzleHttp\Client([
            'base_uri' => $this->config['cegid_api_url'],
            'timeout' => $this->config['timeout'],
            'headers' => [
                'X-API-Key' => $this->config['cegid_api_key'],
                'X-API-Secret' => $this->config['cegid_api_secret'],
                'Content-Type' => 'application/json',
                'Accept' => 'application/json'
            ]
        ]);
        
        // SFTP client
        $this->sftpClient = new \phpseclib3\Net\SFTP(
            $this->config['sftp_host'],
            $this->config['sftp_port']
        );
        
        if (!empty($this->config['sftp_private_key'])) {
            $key = \phpseclib3\Crypt\PublicKeyLoader::load(
                file_get_contents($this->config['sftp_private_key'])
            );
            $this->sftpClient->login($this->config['sftp_username'], $key);
        } else {
            $this->sftpClient->login(
                $this->config['sftp_username'],
                $this->config['sftp_password']
            );
        }
        
        // Akeneo client
        $clientBuilder = new \Akeneo\Pim\ApiClient\AkeneoPimClientBuilder(
            $this->config['akeneo_base_url']
        );
        
        $this->akeneoClient = $clientBuilder->buildAuthenticatedByPassword(
            $this->config['akeneo_client_id'],
            $this->config['akeneo_client_secret'],
            $this->config['akeneo_username'],
            $this->config['akeneo_password']
        );
    }
}

/**
 * Usage Example:
 * 
 * $connector = new CegidErpConnector();
 * 
 * // Export products to Cegid
 * $results = $connector->exportToCegid(['product1', 'product2', 'product3']);
 * 
 * // Import price updates from Cegid
 * $results = $connector->importFromCegid('price');
 * 
 * // Import stock updates from Cegid
 * $results = $connector->importFromCegid('stock');
 */
