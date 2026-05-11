<?php
$_ENV['APP_ENV'] = $_SERVER['APP_ENV'] = 'prod';

require 'config/bootstrap.php';
require 'vendor/autoload.php';

// Create a minimal kernel just to get the database connection
try {
    // Try using the Symfony kernel's built-in container
    include 'vendor/symfony/symfony/src/Symfony/Component/HttpKernel/Kernel.php';
    
    // Get the container from console application
    $input = new \Symfony\Component\Console\Input\ArgvInput();
    $output = new \Symfony\Component\Console\Output\ConsoleOutput();
    $app = new \Symfony\Bundle\FrameworkBundle\Console\Application(
        require 'config/bootstrap.php'
    );
    
    $kernel = $app->getKernel();
    $connection = $kernel->getContainer()->get('doctrine.orm.entity_manager')->getConnection();
    
    echo "✓ Database connection established\n";
    
    // Import the smaller SQL file
    $sql = file_get_contents('/home/pim/akeneo_pim_backup_20260423_112704.sql');
    
    // Split into statements
    $statements = preg_split('/;[\r\n]+/', $sql, -1, PREG_SPLIT_NO_EMPTY);
    echo "Executing " . count($statements) . " statements...\n";
    
    $count = 0;
    foreach ($statements as $stmt) {
        $stmt = trim($stmt);
        if (!empty($stmt) && !preg_match('/^#|^--/', $stmt)) {
            try {
                $connection->executeStatement($stmt);
                $count++;
            } catch (\Throwable $e) {
                // Ignore some errors
            }
        }
    }
    
    echo "✓ Imported $count statements\n";
    
} catch (\Throwable $e) {
    echo "Error: " . $e->getMessage() . "\n";
    var_dump($e);
}
?>
