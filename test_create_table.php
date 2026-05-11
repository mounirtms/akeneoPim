<?php
// Use Akeneo's own connection mechanism
$_ENV['APP_ENV'] = $_SERVER['APP_ENV'] = 'prod';

// Load bootstrap
require 'config/bootstrap.php';
require 'vendor/autoload.php';

// Create kernel and get connection
$kernel = new \Symfony\Component\HttpKernel\Kernel('prod', false);
$kernel->boot();

$connection = $kernel->getContainer()->get('doctrine')->getConnection();

try {
    echo "✓ Connected via Akeneo\n";
    
    // Try creating a test table
    $connection->executeStatement("DROP TABLE IF EXISTS test_connection");
    $connection->executeStatement("CREATE TABLE test_connection (id INT PRIMARY KEY AUTO_INCREMENT, data VARCHAR(255))");
    echo "✓ Created test table\n";
    
    // Insert test data
    $connection->executeStatement("INSERT INTO test_connection (data) VALUES ('test')");
    echo "✓ Inserted test data\n";
    
    // Query test data
    $result = $connection->fetchOne("SELECT COUNT(*) FROM test_connection");
    echo "✓ Query result: $result rows\n";
    
    // Drop test table
    $connection->executeStatement("DROP TABLE IF EXISTS test_connection");
    echo "✓ Dropped test table\n";
    
    echo "\n✓✓✓ Database is writable and working! ✓✓✓\n";
    
} catch (\Throwable $e) {
    echo "Error: " . $e->getMessage() . "\n";
}
?>
