<?php
/**
 * PHASE 1.3: ENABLE COMPLETENESS CALCULATION
 * 
 * This script enables and triggers product completeness calculation.
 * Completeness tracks how complete product data is for publication readiness.
 * 
 * Usage: php /home/pim/public_html/webapp/phase1_enable_completeness.php
 * Run as: pim user
 * 
 * IMPORTANT: This requires running Akeneo console commands
 */

error_reporting(E_ALL);
ini_set('display_errors', 1);

echo "=" . str_repeat("=", 79) . "\n";
echo "PHASE 1.3: ENABLE COMPLETENESS CALCULATION\n";
echo "Date: " . date('Y-m-d H:i:s') . "\n";
echo "=" . str_repeat("=", 79) . "\n\n";

$akeneo_root = '/home/pim/public_html';
$console = $akeneo_root . '/bin/console';

if (!file_exists($console)) {
    echo "❌ Akeneo console not found at: $console\n";
    exit(1);
}

echo "✅ Found Akeneo console: $console\n\n";

// Step 1: Check if completeness service is available
echo "Step 1: Checking completeness service...\n";
exec("$console list | grep -i completeness", $output, $return_var);

if ($return_var == 0 && !empty($output)) {
    echo "✅ Completeness commands available:\n";
    foreach ($output as $line) {
        echo "   $line\n";
    }
    echo "\n";
} else {
    echo "⚠️ Completeness commands not found in console\n";
    echo "Alternative: Will use direct database approach\n\n";
}

// Step 2: Check database configuration
echo "Step 2: Checking database configuration...\n";

$akeneo_db = [
    'host' => '127.0.0.1',
    'port' => '3307',
    'database' => 'akeneo_pim',
    'user' => 'akeneo_pim',
    'password' => 'akeneo_pim'
];

try {
    $dsn = "mysql:host={$akeneo_db['host']};port={$akeneo_db['port']};dbname={$akeneo_db['database']};charset=utf8mb4";
    $pdo = new PDO($dsn, $akeneo_db['user'], $akeneo_db['password'], [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC
    ]);
    echo "✅ Connected to database\n\n";
} catch (PDOException $e) {
    echo "❌ Database connection failed: " . $e->getMessage() . "\n";
    exit(1);
}

// Step 3: Count products that need completeness calculation
$product_count = $pdo->query("SELECT COUNT(*) FROM pim_catalog_product")->fetchColumn();
echo "Step 3: Products requiring completeness calculation: $product_count\n\n";

// Step 4: Try to trigger completeness via console
echo "Step 4: Attempting to trigger completeness calculation...\n";
echo "(This may take several minutes for $product_count products)\n\n";

$command = "cd $akeneo_root && php bin/console pim:completeness:calculate --env=prod 2>&1";
echo "Running: $command\n\n";

// Run in background with nohup
$pid_file = '/home/pim/public_html/webapp/completeness_calculation.pid';

// Check if already running
if (file_exists($pid_file)) {
    $old_pid = trim(file_get_contents($pid_file));
    if (posix_getsid($old_pid)) {
        echo "⚠️ Completeness calculation already running (PID: $old_pid)\n";
        echo "Please wait for it to complete or kill it first.\n";
        exit(1);
    }
}

echo "Starting completeness calculation in background...\n";
exec("nohup $command > /home/pim/public_html/webapp/logs/completeness_calculation.log 2>&1 & echo $!", $output, $return_var);

if (!empty($output)) {
    $pid = trim(end($output));
    file_put_contents($pid_file, $pid);
    
    echo "✅ Completeness calculation started (PID: $pid)\n\n";
    echo "Monitor progress:\n";
    echo "  tail -f /home/pim/public_html/webapp/logs/completeness_calculation.log\n\n";
    echo "Check status:\n";
    echo "  ps -p $pid\n\n";
} else {
    echo "⚠️ Could not start background process\n";
    echo "Running in foreground mode (this will take a while)...\n\n";
    exec($command, $fg_output, $fg_return);
    
    foreach ($fg_output as $line) {
        echo "   $line\n";
    }
}

// Step 5: Set up cron job for daily recalculation
echo "\nStep 5: Setting up daily completeness calculation cron job...\n";

$cron_command = "0 3 * * * cd $akeneo_root && php bin/console pim:completeness:calculate --env=prod >> /home/pim/public_html/webapp/logs/completeness_cron.log 2>&1";
$cron_file = '/home/pim/public_html/webapp/completeness_crontab.txt';

$cron_content = "# Akeneo PIM - Daily Completeness Calculation\n";
$cron_content .= "# Runs at 3:00 AM every day\n";
$cron_content .= "$cron_command\n";

file_put_contents($cron_file, $cron_content);

echo "✅ Cron job configuration saved to: $cron_file\n\n";
echo "To install the cron job, run:\n";
echo "  crontab -l > /tmp/current_crontab\n";
echo "  cat $cron_file >> /tmp/current_crontab\n";
echo "  crontab /tmp/current_crontab\n\n";

// Step 6: Verification (if completeness table has data)
echo "Step 6: Verification...\n";
sleep(5); // Wait a few seconds to see if any records are created

$completeness_count = $pdo->query("SELECT COUNT(*) FROM pim_catalog_completeness")->fetchColumn();
echo "Completeness records in database: $completeness_count\n";

if ($completeness_count > 0) {
    $avg = $pdo->query("SELECT AVG(completeness) FROM pim_catalog_completeness")->fetchColumn();
    echo "Average completeness: " . round($avg, 1) . "%\n";
    echo "✅ Completeness calculation is working!\n";
} else {
    echo "⚠️ No completeness records yet (calculation may still be running)\n";
    echo "Check the log file for progress.\n";
}

echo "\n" . str_repeat("=", 80) . "\n";
echo "PHASE 1.3 COMPLETE\n";
echo str_repeat("=", 80) . "\n\n";

echo "Next steps:\n";
echo "1. Monitor completeness calculation progress in log file\n";
echo "2. Once complete, verify completeness scores in Akeneo UI\n";
echo "3. Install cron job for automated daily calculation\n";
echo "4. Move to Phase 2: Add validation rules\n";

echo "\n" . date('Y-m-d H:i:s') . "\n";
