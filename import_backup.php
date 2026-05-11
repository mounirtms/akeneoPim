<?php
use Symfony\Bundle\FrameworkBundle\Console\Application;
use Symfony\Component\Console\Input\StringInput;
use Symfony\Component\Console\Output\BufferedOutput;

// Set up Akeneo kernel
require_once 'config/bootstrap.php';

try {
    $_ENV['APP_ENV'] = $_SERVER['APP_ENV'] = 'prod';
    $_ENV['APP_DEBUG'] = $_SERVER['APP_DEBUG'] = 0;
    
    // Get the kernel
    $kernel = new \Pim\Kernel('prod', false);
    $kernel->boot();
    
    // Get the database connection
    $connection = $kernel->getContainer()->get('doctrine.orm.entity_manager')->getConnection();
    
    echo "✓ Connected to database via Akeneo\n";
    echo "  Database: " . $connection->getDatabase() . "\n";
    
    // Test connection
    $version = $connection->fetchOne("SELECT VERSION()");
    echo "  MariaDB: $version\n\n";
    
    // Disable checks
    echo "Disabling integrity checks...\n";
    $connection->executeStatement("SET FOREIGN_KEY_CHECKS=0");
    $connection->executeStatement("SET UNIQUE_CHECKS=0");
    
    // Import SQL
    $sqlFile = '/home/pim/backups/akeneo_latest.sql';
    echo "Importing SQL file (" . round(filesize($sqlFile) / (1024*1024)) . "MB)...\n";
    
    $sql = file_get_contents($sqlFile);
    $statements = preg_split('/;[\r\n]+/', $sql, -1, PREG_SPLIT_NO_EMPTY);
    
    echo "Total statements: " . count($statements) . "\n\n";
    
    $count = 0;
    $errors = 0;
    $startTime = time();
    
    foreach ($statements as $stmt) {
        $stmt = trim($stmt);
        
        if (empty($stmt) || preg_match('/^#|^--/', $stmt)) {
            continue;
        }
        
        try {
            $connection->executeStatement($stmt);
            $count++;
            
            if ($count % 500 === 0) {
                $elapsed = time() - $startTime;
                $rate = $count / max($elapsed, 1);
                echo "[" . date('H:i:s') . "] $count statements (@" . round($rate) . "/s)\n";
                flush();
            }
        } catch (\Throwable $e) {
            $errors++;
            $msg = $e->getMessage();
            if (strpos($msg, 'already exists') === false && strpos($msg, 'duplicate') === false) {
                echo "E";
            }
        }
    }
    
    echo "\n\n✓ Import completed!\n";
    echo "  Statements: $count\n";
    echo "  Errors: $errors\n";
    
    // Re-enable
    $connection->executeStatement("SET FOREIGN_KEY_CHECKS=1");
    $connection->executeStatement("SET UNIQUE_CHECKS=1");
    
    // Verify
    echo "\nVerifying...\n";
    $tables = $connection->fetchOne("SELECT COUNT(*) FROM information_schema.tables WHERE table_schema=?", [$connection->getDatabase()]);
    echo "✓ Tables created: $tables\n";
    
    echo "\n✓✓✓ Database ready! ✓✓✓\n";
    
    $kernel->shutdown();
    
} catch (\Throwable $e) {
    echo "Error: " . $e->getMessage() . "\n";
    echo $e->getTraceAsString() . "\n";
    exit(1);
}
?>
