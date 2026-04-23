<?php
/**
 * Real-Time Data Quality Dashboard
 * Comprehensive monitoring for Akeneo PIM
 * Date: 2026-04-23
 */

// Database connection
$host = '127.0.0.1';
$port = 3307;
$dbname = 'akeneo_pim';
$username = 'root';
$password = 'YourNewStrongPassword';

try {
    $pdo = new PDO("mysql:host=$host;port=$port;dbname=$dbname", $username, $password);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
} catch(PDOException $e) {
    die("Connection failed: " . $e->getMessage());
}

// Get statistics
$stats = [];

// Product statistics
$stmt = $pdo->query("
    SELECT 
        COUNT(*) as total,
        SUM(CASE WHEN is_enabled = 1 THEN 1 ELSE 0 END) as enabled,
        SUM(CASE WHEN is_enabled = 0 THEN 1 ELSE 0 END) as disabled
    FROM pim_catalog_product
");
$stats['products'] = $stmt->fetch(PDO::FETCH_ASSOC);

// Channel statistics
$stmt = $pdo->query("SELECT code, id FROM pim_catalog_channel ORDER BY code");
$stats['channels'] = $stmt->fetchAll(PDO::FETCH_ASSOC);

// Category statistics
$stmt = $pdo->query("SELECT COUNT(*) as total FROM pim_catalog_category");
$stats['categories'] = $stmt->fetch(PDO::FETCH_ASSOC);

// Family statistics
$stmt = $pdo->query("
    SELECT 
        f.code,
        COUNT(p.id) as product_count
    FROM pim_catalog_family f
    LEFT JOIN pim_catalog_product p ON f.id = p.family_id
    GROUP BY f.code
    ORDER BY product_count DESC
    LIMIT 10
");
$stats['families'] = $stmt->fetchAll(PDO::FETCH_ASSOC);

// Attribute statistics
$stmt = $pdo->query("SELECT COUNT(*) as total FROM pim_catalog_attribute");
$stats['attributes'] = $stmt->fetch(PDO::FETCH_ASSOC);

// File storage statistics
$stmt = $pdo->query("SELECT COUNT(*) as total FROM akeneo_file_storage_file_info");
$stats['files'] = $stmt->fetch(PDO::FETCH_ASSOC);

// Recent updates
$stmt = $pdo->query("
    SELECT identifier, is_enabled, updated 
    FROM pim_catalog_product 
    ORDER BY updated DESC 
    LIMIT 10
");
$stats['recent_updates'] = $stmt->fetchAll(PDO::FETCH_ASSOC);

// Calculate quality score
$enabled_pct = ($stats['products']['total'] > 0) 
    ? round(($stats['products']['enabled'] / $stats['products']['total']) * 100, 1) 
    : 0;

$has_files = $stats['files']['total'] > 0;
$quality_score = ($enabled_pct * 0.5) + ($has_files ? 25 : 0) + 25; // Base 25 + enabled 50% + files 25%

?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Akeneo PIM - Data Quality Dashboard</title>
    <meta http-equiv="refresh" content="30">
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: #333;
            padding: 20px;
        }
        .container {
            max-width: 1400px;
            margin: 0 auto;
        }
        .header {
            background: white;
            padding: 30px;
            border-radius: 10px;
            margin-bottom: 20px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
        }
        .header h1 {
            color: #667eea;
            font-size: 32px;
            margin-bottom: 10px;
        }
        .header .subtitle {
            color: #666;
            font-size: 14px;
        }
        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
            margin-bottom: 20px;
        }
        .card {
            background: white;
            padding: 25px;
            border-radius: 10px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
        }
        .card h2 {
            font-size: 18px;
            color: #667eea;
            margin-bottom: 15px;
            border-bottom: 2px solid #f0f0f0;
            padding-bottom: 10px;
        }
        .metric {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 12px 0;
            border-bottom: 1px solid #f0f0f0;
        }
        .metric:last-child {
            border-bottom: none;
        }
        .metric-label {
            color: #666;
            font-size: 14px;
        }
        .metric-value {
            font-size: 24px;
            font-weight: bold;
            color: #333;
        }
        .metric-value.success {
            color: #10b981;
        }
        .metric-value.warning {
            color: #f59e0b;
        }
        .metric-value.error {
            color: #ef4444;
        }
        .quality-score {
            text-align: center;
            padding: 30px;
        }
        .score-circle {
            width: 150px;
            height: 150px;
            border-radius: 50%;
            background: linear-gradient(135deg, #10b981 0%, #059669 100%);
            display: flex;
            align-items: center;
            justify-content: center;
            margin: 0 auto 20px;
            font-size: 48px;
            font-weight: bold;
            color: white;
            box-shadow: 0 4px 20px rgba(16, 185, 129, 0.4);
        }
        .table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 15px;
        }
        .table th {
            background: #f9fafb;
            padding: 12px;
            text-align: left;
            font-size: 12px;
            color: #666;
            font-weight: 600;
            text-transform: uppercase;
        }
        .table td {
            padding: 12px;
            border-bottom: 1px solid #f0f0f0;
            font-size: 14px;
        }
        .table tr:hover {
            background: #f9fafb;
        }
        .badge {
            display: inline-block;
            padding: 4px 12px;
            border-radius: 12px;
            font-size: 12px;
            font-weight: 600;
        }
        .badge.success {
            background: #d1fae5;
            color: #065f46;
        }
        .badge.error {
            background: #fee2e2;
            color: #991b1b;
        }
        .footer {
            text-align: center;
            color: white;
            padding: 20px;
            font-size: 14px;
        }
        .refresh-info {
            background: rgba(255,255,255,0.2);
            padding: 10px 20px;
            border-radius: 5px;
            display: inline-block;
            margin-top: 10px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🎯 Akeneo PIM Data Quality Dashboard</h1>
            <div class="subtitle">
                Real-time monitoring • Last updated: <?php echo date('Y-m-d H:i:s'); ?> • Auto-refresh: 30 seconds
            </div>
        </div>

        <div class="grid">
            <!-- Quality Score -->
            <div class="card">
                <h2>Overall Quality Score</h2>
                <div class="quality-score">
                    <div class="score-circle"><?php echo round($quality_score); ?>%</div>
                    <div class="metric-label">
                        <?php if ($quality_score >= 90): ?>
                            ✅ Excellent
                        <?php elseif ($quality_score >= 75): ?>
                            ⚠️ Good
                        <?php else: ?>
                            ❌ Needs Improvement
                        <?php endif; ?>
                    </div>
                </div>
            </div>

            <!-- Product Statistics -->
            <div class="card">
                <h2>Product Statistics</h2>
                <div class="metric">
                    <span class="metric-label">Total Products</span>
                    <span class="metric-value success"><?php echo number_format($stats['products']['total']); ?></span>
                </div>
                <div class="metric">
                    <span class="metric-label">Enabled</span>
                    <span class="metric-value success"><?php echo number_format($stats['products']['enabled']); ?></span>
                </div>
                <div class="metric">
                    <span class="metric-label">Disabled</span>
                    <span class="metric-value <?php echo $stats['products']['disabled'] > 0 ? 'warning' : 'success'; ?>">
                        <?php echo number_format($stats['products']['disabled']); ?>
                    </span>
                </div>
                <div class="metric">
                    <span class="metric-label">Enabled Rate</span>
                    <span class="metric-value success"><?php echo $enabled_pct; ?>%</span>
                </div>
            </div>

            <!-- Catalog Structure -->
            <div class="card">
                <h2>Catalog Structure</h2>
                <div class="metric">
                    <span class="metric-label">Categories</span>
                    <span class="metric-value"><?php echo number_format($stats['categories']['total']); ?></span>
                </div>
                <div class="metric">
                    <span class="metric-label">Attributes</span>
                    <span class="metric-value"><?php echo number_format($stats['attributes']['total']); ?></span>
                </div>
                <div class="metric">
                    <span class="metric-label">Channels</span>
                    <span class="metric-value"><?php echo count($stats['channels']); ?></span>
                </div>
                <div class="metric">
                    <span class="metric-label">Files</span>
                    <span class="metric-value <?php echo $has_files ? 'success' : 'warning'; ?>">
                        <?php echo number_format($stats['files']['total']); ?>
                    </span>
                </div>
            </div>
        </div>

        <!-- Channels -->
        <div class="card">
            <h2>Integration Channels</h2>
            <table class="table">
                <thead>
                    <tr>
                        <th>Channel Code</th>
                        <th>Channel ID</th>
                        <th>Status</th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach ($stats['channels'] as $channel): ?>
                    <tr>
                        <td><strong><?php echo htmlspecialchars($channel['code']); ?></strong></td>
                        <td><?php echo $channel['id']; ?></td>
                        <td><span class="badge success">Active</span></td>
                    </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>
        </div>

        <!-- Top Families -->
        <div class="card">
            <h2>Top Product Families</h2>
            <table class="table">
                <thead>
                    <tr>
                        <th>Family Code</th>
                        <th>Product Count</th>
                        <th>Percentage</th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach ($stats['families'] as $family): ?>
                    <tr>
                        <td><strong><?php echo htmlspecialchars($family['code']); ?></strong></td>
                        <td><?php echo number_format($family['product_count']); ?></td>
                        <td>
                            <?php 
                            $pct = ($stats['products']['total'] > 0) 
                                ? round(($family['product_count'] / $stats['products']['total']) * 100, 1) 
                                : 0;
                            echo $pct . '%';
                            ?>
                        </td>
                    </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>
        </div>

        <!-- Recent Updates -->
        <div class="card">
            <h2>Recent Product Updates</h2>
            <table class="table">
                <thead>
                    <tr>
                        <th>Product Identifier</th>
                        <th>Status</th>
                        <th>Last Updated</th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach ($stats['recent_updates'] as $product): ?>
                    <tr>
                        <td><strong><?php echo htmlspecialchars($product['identifier']); ?></strong></td>
                        <td>
                            <span class="badge <?php echo $product['is_enabled'] ? 'success' : 'error'; ?>">
                                <?php echo $product['is_enabled'] ? 'Enabled' : 'Disabled'; ?>
                            </span>
                        </td>
                        <td><?php echo date('Y-m-d H:i:s', strtotime($product['updated'])); ?></td>
                    </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>
        </div>

        <div class="footer">
            <div>✅ Akeneo PIM Data Quality Dashboard</div>
            <div class="refresh-info">Auto-refreshing every 30 seconds</div>
            <div style="margin-top: 10px; font-size: 12px; opacity: 0.8;">
                Database: MariaDB 10.6 (Port 3307) • Website: https://pim.technostationery.com
            </div>
        </div>
    </div>
</body>
</html>
<?php
// Close connection
$pdo = null;
?>
