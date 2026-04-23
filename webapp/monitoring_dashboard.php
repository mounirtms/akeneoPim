<?php
/**
 * Akeneo PIM Comprehensive Monitoring Dashboard
 * Real-time system health and performance metrics
 * Date: 2026-04-23
 */

header('Content-Type: text/html; charset=utf-8');

// Database connection
$db_host = '127.0.0.1';
$db_port = 3307;
$db_name = 'akeneo_pim';
$db_user = 'root';
$db_pass = 'YourNewStrongPassword';

try {
    $pdo = new PDO("mysql:host=$db_host;port=$db_port;dbname=$db_name;charset=utf8mb4", $db_user, $db_pass);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
} catch (PDOException $e) {
    die("Connection failed: " . $e->getMessage());
}

// Fetch metrics
function getMetrics($pdo) {
    $metrics = [];
    
    // Product metrics
    $stmt = $pdo->query("
        SELECT 
            COUNT(*) as total_products,
            SUM(is_enabled) as enabled_products,
            COUNT(*) - SUM(is_enabled) as disabled_products
        FROM pim_catalog_product
    ");
    $products = $stmt->fetch(PDO::FETCH_ASSOC);
    $metrics['products'] = $products;
    
    // Channel metrics
    $stmt = $pdo->query("
        SELECT 
            c.code,
            c.category_id,
            COUNT(DISTINCT cl.locale_id) as locale_count,
            COUNT(DISTINCT cc.currency_id) as currency_count
        FROM pim_catalog_channel c
        LEFT JOIN pim_catalog_channel_locale cl ON c.id = cl.channel_id
        LEFT JOIN pim_catalog_channel_currency cc ON c.id = cc.channel_id
        GROUP BY c.id, c.code, c.category_id
    ");
    $metrics['channels'] = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // Family metrics
    $stmt = $pdo->query("
        SELECT 
            f.code as family_code,
            COUNT(p.id) as product_count
        FROM pim_catalog_family f
        LEFT JOIN pim_catalog_product p ON f.id = p.family_id
        GROUP BY f.id, f.code
        ORDER BY product_count DESC
        LIMIT 10
    ");
    $metrics['families'] = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // Category metrics
    $stmt = $pdo->query("SELECT COUNT(*) as total FROM pim_catalog_category");
    $metrics['categories'] = $stmt->fetch(PDO::FETCH_ASSOC)['total'];
    
    // Attribute metrics
    $stmt = $pdo->query("
        SELECT attribute_type, COUNT(*) as count 
        FROM pim_catalog_attribute 
        GROUP BY attribute_type 
        ORDER BY count DESC
    ");
    $metrics['attributes'] = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // File storage metrics
    $stmt = $pdo->query("SELECT COUNT(*) as total FROM akeneo_file_storage_file_info");
    $metrics['file_storage'] = $stmt->fetch(PDO::FETCH_ASSOC)['total'];
    
    // Recent updates
    $stmt = $pdo->query("
        SELECT identifier, updated 
        FROM pim_catalog_product 
        ORDER BY updated DESC 
        LIMIT 10
    ");
    $metrics['recent_updates'] = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // Database size
    $stmt = $pdo->query("
        SELECT 
            TABLE_NAME,
            ROUND((DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024, 2) AS size_mb,
            TABLE_ROWS
        FROM information_schema.TABLES
        WHERE TABLE_SCHEMA = 'akeneo_pim'
            AND TABLE_NAME LIKE 'pim_catalog_%'
        ORDER BY (DATA_LENGTH + INDEX_LENGTH) DESC
        LIMIT 10
    ");
    $metrics['database_tables'] = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // User metrics
    $stmt = $pdo->query("SELECT COUNT(*) as total, SUM(enabled) as active FROM oro_user");
    $metrics['users'] = $stmt->fetch(PDO::FETCH_ASSOC);
    
    return $metrics;
}

// System metrics
function getSystemMetrics() {
    $metrics = [];
    
    // Disk usage
    $catalog_path = '/home/pim/public_html/var/file_storage/catalog/';
    $cache_path = '/home/pim/public_html/var/cache/';
    $logs_path = '/home/pim/public_html/var/logs/';
    
    if (is_dir($catalog_path)) {
        $metrics['disk']['catalog_files'] = shell_exec("find $catalog_path -type f | wc -l");
        $metrics['disk']['catalog_size'] = shell_exec("du -sh $catalog_path | awk '{print $1}'");
    }
    
    if (is_dir($cache_path)) {
        $metrics['disk']['cache_size'] = shell_exec("du -sh $cache_path | awk '{print $1}'");
    }
    
    if (is_dir($logs_path)) {
        $metrics['disk']['logs_size'] = shell_exec("du -sh $logs_path | awk '{print $1}'");
    }
    
    // Recent errors
    $log_file = '/home/pim/public_html/var/logs/prod.log';
    if (file_exists($log_file)) {
        $errors = shell_exec("tail -100 $log_file | grep -E 'CRITICAL|ERROR' | wc -l");
        $metrics['errors']['recent'] = trim($errors);
    }
    
    // MariaDB status
    $metrics['mariadb']['version'] = shell_exec("/opt/mariadb10.6/mariadb/bin/mysql -u root -p'YourNewStrongPassword' -h 127.0.0.1 -P 3307 -e 'SELECT VERSION();' 2>/dev/null | tail -1");
    
    return $metrics;
}

$db_metrics = getMetrics($pdo);
$sys_metrics = getSystemMetrics();

// Calculate health score
$health_score = 100;
if ($db_metrics['products']['total_products'] == 0) $health_score -= 30;
if ($db_metrics['file_storage'] < 100) $health_score -= 20;
if (isset($sys_metrics['errors']['recent']) && $sys_metrics['errors']['recent'] > 10) $health_score -= 15;
if (count($db_metrics['channels']) < 2) $health_score -= 10;

$health_status = $health_score >= 80 ? 'Excellent' : ($health_score >= 60 ? 'Good' : ($health_score >= 40 ? 'Fair' : 'Poor'));
$health_color = $health_score >= 80 ? '#28a745' : ($health_score >= 60 ? '#ffc107' : ($health_score >= 40 ? '#fd7e14' : '#dc3545'));

?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta http-equiv="refresh" content="30">
    <title>Akeneo PIM - Monitoring Dashboard</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { 
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            padding: 20px;
            color: #333;
        }
        .container { max-width: 1400px; margin: 0 auto; }
        .header {
            background: white;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
            margin-bottom: 20px;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        .header h1 { color: #667eea; font-size: 28px; }
        .header .timestamp { color: #666; font-size: 14px; }
        .health-score {
            background: white;
            padding: 20px;
            border-radius: 10px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
            margin-bottom: 20px;
            text-align: center;
        }
        .health-score h2 { margin-bottom: 15px; color: #333; }
        .score-circle {
            width: 150px;
            height: 150px;
            border-radius: 50%;
            margin: 0 auto 15px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 48px;
            font-weight: bold;
            color: white;
            background: <?= $health_color ?>;
        }
        .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(350px, 1fr)); gap: 20px; margin-bottom: 20px; }
        .card {
            background: white;
            padding: 25px;
            border-radius: 10px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
        }
        .card h3 {
            color: #667eea;
            margin-bottom: 15px;
            font-size: 18px;
            border-bottom: 2px solid #667eea;
            padding-bottom: 10px;
        }
        .metric {
            display: flex;
            justify-content: space-between;
            padding: 10px 0;
            border-bottom: 1px solid #eee;
        }
        .metric:last-child { border-bottom: none; }
        .metric-label { color: #666; font-weight: 500; }
        .metric-value { 
            color: #333;
            font-weight: bold;
            padding: 4px 12px;
            background: #f8f9fa;
            border-radius: 4px;
        }
        .channel-badge {
            display: inline-block;
            padding: 6px 12px;
            background: #667eea;
            color: white;
            border-radius: 5px;
            margin: 5px;
            font-size: 13px;
        }
        .table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 15px;
        }
        .table th, .table td {
            padding: 10px;
            text-align: left;
            border-bottom: 1px solid #eee;
        }
        .table th {
            background: #f8f9fa;
            font-weight: 600;
            color: #667eea;
        }
        .status-ok { color: #28a745; font-weight: bold; }
        .status-warning { color: #ffc107; font-weight: bold; }
        .status-error { color: #dc3545; font-weight: bold; }
        .footer {
            background: white;
            padding: 15px;
            border-radius: 10px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
            text-align: center;
            color: #666;
            font-size: 14px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div>
                <h1>🎯 Akeneo PIM Monitoring Dashboard</h1>
                <p style="color: #666; margin-top: 5px;">Real-time System Health & Performance</p>
            </div>
            <div class="timestamp">
                <strong>Last Updated:</strong><br>
                <?= date('Y-m-d H:i:s') ?><br>
                <small>Auto-refresh: 30s</small>
            </div>
        </div>

        <div class="health-score">
            <h2>System Health Score</h2>
            <div class="score-circle"><?= $health_score ?>%</div>
            <h3 style="color: <?= $health_color ?>;"><?= $health_status ?></h3>
        </div>

        <div class="grid">
            <!-- Products Card -->
            <div class="card">
                <h3>📦 Products Overview</h3>
                <div class="metric">
                    <span class="metric-label">Total Products</span>
                    <span class="metric-value"><?= number_format($db_metrics['products']['total_products']) ?></span>
                </div>
                <div class="metric">
                    <span class="metric-label">Enabled</span>
                    <span class="metric-value status-ok"><?= number_format($db_metrics['products']['enabled_products']) ?></span>
                </div>
                <div class="metric">
                    <span class="metric-label">Disabled</span>
                    <span class="metric-value"><?= number_format($db_metrics['products']['disabled_products']) ?></span>
                </div>
                <div class="metric">
                    <span class="metric-label">Completion Rate</span>
                    <span class="metric-value status-ok">
                        <?= $db_metrics['products']['total_products'] > 0 
                            ? round(($db_metrics['products']['enabled_products'] / $db_metrics['products']['total_products']) * 100, 1) 
                            : 0 ?>%
                    </span>
                </div>
            </div>

            <!-- Channels Card -->
            <div class="card">
                <h3>🌐 Active Channels</h3>
                <?php foreach ($db_metrics['channels'] as $channel): ?>
                    <div class="channel-badge">
                        <?= strtoupper($channel['code']) ?>
                        (<?= $channel['locale_count'] ?> locales, <?= $channel['currency_count'] ?> currencies)
                    </div>
                <?php endforeach; ?>
            </div>

            <!-- Storage Card -->
            <div class="card">
                <h3>💾 Storage & Files</h3>
                <div class="metric">
                    <span class="metric-label">DB File Records</span>
                    <span class="metric-value"><?= number_format($db_metrics['file_storage']) ?></span>
                </div>
                <div class="metric">
                    <span class="metric-label">Catalog Files</span>
                    <span class="metric-value"><?= number_format(trim($sys_metrics['disk']['catalog_files'] ?? 0)) ?></span>
                </div>
                <div class="metric">
                    <span class="metric-label">Catalog Size</span>
                    <span class="metric-value"><?= trim($sys_metrics['disk']['catalog_size'] ?? 'N/A') ?></span>
                </div>
                <div class="metric">
                    <span class="metric-label">Cache Size</span>
                    <span class="metric-value"><?= trim($sys_metrics['disk']['cache_size'] ?? 'N/A') ?></span>
                </div>
                <div class="metric">
                    <span class="metric-label">Logs Size</span>
                    <span class="metric-value"><?= trim($sys_metrics['disk']['logs_size'] ?? 'N/A') ?></span>
                </div>
            </div>

            <!-- System Card -->
            <div class="card">
                <h3>⚙️ System Status</h3>
                <div class="metric">
                    <span class="metric-label">Categories</span>
                    <span class="metric-value"><?= number_format($db_metrics['categories']) ?></span>
                </div>
                <div class="metric">
                    <span class="metric-label">Families</span>
                    <span class="metric-value"><?= count($db_metrics['families']) ?></span>
                </div>
                <div class="metric">
                    <span class="metric-label">Users</span>
                    <span class="metric-value"><?= $db_metrics['users']['active'] ?> / <?= $db_metrics['users']['total'] ?></span>
                </div>
                <div class="metric">
                    <span class="metric-label">MariaDB</span>
                    <span class="metric-value status-ok"><?= trim($sys_metrics['mariadb']['version'] ?? 'Unknown') ?></span>
                </div>
                <div class="metric">
                    <span class="metric-label">Recent Errors (100 lines)</span>
                    <span class="metric-value <?= ($sys_metrics['errors']['recent'] ?? 0) > 10 ? 'status-error' : 'status-ok' ?>">
                        <?= $sys_metrics['errors']['recent'] ?? 'N/A' ?>
                    </span>
                </div>
            </div>
        </div>

        <!-- Top Families Table -->
        <div class="card">
            <h3>👨‍👩‍👧‍👦 Top 10 Product Families</h3>
            <table class="table">
                <thead>
                    <tr>
                        <th>Family Code</th>
                        <th>Product Count</th>
                        <th>Percentage</th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach ($db_metrics['families'] as $family): ?>
                        <tr>
                            <td><strong><?= htmlspecialchars($family['family_code']) ?></strong></td>
                            <td><?= number_format($family['product_count']) ?></td>
                            <td>
                                <?= $db_metrics['products']['total_products'] > 0 
                                    ? round(($family['product_count'] / $db_metrics['products']['total_products']) * 100, 1) 
                                    : 0 ?>%
                            </td>
                        </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>
        </div>

        <!-- Attribute Types -->
        <div class="card">
            <h3>🏷️ Attribute Types Distribution</h3>
            <table class="table">
                <thead>
                    <tr>
                        <th>Attribute Type</th>
                        <th>Count</th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach ($db_metrics['attributes'] as $attr): ?>
                        <tr>
                            <td><?= htmlspecialchars($attr['attribute_type']) ?></td>
                            <td><strong><?= $attr['count'] ?></strong></td>
                        </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>
        </div>

        <!-- Recent Updates -->
        <div class="card">
            <h3>🕒 Recent Product Updates</h3>
            <table class="table">
                <thead>
                    <tr>
                        <th>Product Identifier</th>
                        <th>Last Updated</th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach ($db_metrics['recent_updates'] as $update): ?>
                        <tr>
                            <td><?= htmlspecialchars($update['identifier']) ?></td>
                            <td><?= $update['updated'] ?></td>
                        </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>
        </div>

        <!-- Database Tables -->
        <div class="card">
            <h3>💿 Top 10 Database Tables by Size</h3>
            <table class="table">
                <thead>
                    <tr>
                        <th>Table Name</th>
                        <th>Size (MB)</th>
                        <th>Rows</th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach ($db_metrics['database_tables'] as $table): ?>
                        <tr>
                            <td><?= htmlspecialchars($table['TABLE_NAME']) ?></td>
                            <td><strong><?= number_format($table['size_mb'], 2) ?> MB</strong></td>
                            <td><?= number_format($table['TABLE_ROWS']) ?></td>
                        </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>
        </div>

        <div class="footer">
            <p><strong>Akeneo PIM Monitoring Dashboard</strong> | Powered by AI Development Team | 2026-04-23</p>
            <p style="margin-top: 5px; font-size: 12px;">
                URL: https://pim.technostationery.com/webapp/monitoring_dashboard.php
            </p>
        </div>
    </div>
</body>
</html>
