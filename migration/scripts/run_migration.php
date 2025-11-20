<?php

require_once __DIR__ . '/../../vendor/autoload.php';

class MigrationOrchestrator
{
    private $startTime;
    
    public function __construct()
    {
        $this->startTime = microtime(true);
    }
    
    public function run()
    {
        try {
            $this->log("Starting Magento to Pimcore migration...");
            
            // Step 1: Analyze Magento data model
            $this->log("\nStep 1: Analyzing Magento data model");
            $this->runScript('analyze_magento_model.php');
            
            // Step 2: Set up Pimcore classes
            $this->log("\nStep 2: Setting up Pimcore classes");
            $this->runScript('setup_pimcore_classes.php');
            
            // Step 3: Import Magento attributes
            $this->log("\nStep 3: Importing Magento attributes");
            $this->runScript('import_magento_attributes.php');
            
            // Step 4: Import categories
            $this->log("\nStep 4: Importing categories");
            $this->runScript('import_categories.php');
            
            // Step 5: Import products
            $this->log("\nStep 5: Importing products");
            $this->runScript('import_products.php');
            
            $duration = round(microtime(true) - $this->startTime, 2);
            $this->log("\nMigration completed successfully! Duration: {$duration}s");
            
        } catch (Exception $e) {
            $this->log("Error: " . $e->getMessage());
            exit(1);
        }
    }
    
    private function runScript($script)
    {
        $this->log("Running $script...");
        
        $output = [];
        $returnVar = 0;
        
        exec("php " . __DIR__ . "/$script 2>&1", $output, $returnVar);
        
        if ($returnVar !== 0) {
            throw new \RuntimeException("Error running $script:\n" . implode("\n", $output));
        }
        
        foreach ($output as $line) {
            $this->log("  $line");
        }
    }
    
    private function log($message)
    {
        $timestamp = date('Y-m-d H:i:s');
        echo "[$timestamp] $message\n";
        
        // Also log to file
        $logFile = __DIR__ . '/../logs/migration.log';
        $dir = dirname($logFile);
        if (!is_dir($dir)) {
            mkdir($dir, 0777, true);
        }
        
        file_put_contents($logFile, "[$timestamp] $message\n", FILE_APPEND);
    }
}

// Run the migration
$orchestrator = new MigrationOrchestrator();
$orchestrator->run();