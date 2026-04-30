<?php
/**
 * Phase 6: Attribute Group Analysis
 * Analyzes current attribute distribution and suggests reorganization
 */

require_once __DIR__ . '/../vendor/autoload.php';

use Symfony\Component\Dotenv\Dotenv;

$dotenv = new Dotenv();
$dotenv->load(__DIR__ . '/../.env');

echo "=========================================\n";
echo "PHASE 6: ATTRIBUTE GROUP ANALYSIS\n";
echo "Date: " . date('Y-m-d H:i:s') . "\n";
echo "=========================================\n\n";

// Get database credentials
$databaseUrl = $_ENV['DATABASE_URL'] ?? getenv('DATABASE_URL');

if (preg_match('/mysql:\/\/([^:]+):([^@]+)@([^\/]+)\/([^?]+)/', $databaseUrl, $matches)) {
    $user = $matches[1];
    $pass = $matches[2];
    $host = $matches[3];
    $dbname = $matches[4];
    
    try {
        $dsn = "mysql:host=$host;dbname=$dbname;charset=utf8mb4";
        $pdo = new PDO($dsn, $user, $pass);
        $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
        
        echo "✓ Database connected\n\n";
        
        // Get attribute groups with counts
        echo "1. CURRENT ATTRIBUTE GROUP DISTRIBUTION\n";
        echo "========================================\n\n";
        
        $stmt = $pdo->query("
            SELECT 
                g.id,
                g.code,
                g.sort_order,
                COUNT(a.id) as attr_count,
                GROUP_CONCAT(a.code ORDER BY a.code SEPARATOR ', ') as attributes
            FROM pim_catalog_attribute_group g
            LEFT JOIN pim_catalog_attribute a ON a.group_id = g.id
            GROUP BY g.id
            ORDER BY g.sort_order, g.code
        ");
        
        $groups = $stmt->fetchAll(PDO::FETCH_ASSOC);
        $totalAttributes = 0;
        
        echo "Group Summary:\n";
        echo str_repeat('-', 80) . "\n";
        printf("%-30s | %10s | %s\n", "Group Code", "Attributes", "Sort Order");
        echo str_repeat('-', 80) . "\n";
        
        foreach ($groups as $group) {
            printf("%-30s | %10d | %d\n", 
                $group['code'], 
                $group['attr_count'],
                $group['sort_order']
            );
            $totalAttributes += $group['attr_count'];
        }
        
        echo str_repeat('-', 80) . "\n";
        printf("%-30s | %10d |\n", "TOTAL", $totalAttributes);
        echo str_repeat('-', 80) . "\n\n";
        
        // Find the "general" group or largest group
        $largestGroup = null;
        $maxCount = 0;
        foreach ($groups as $group) {
            if ($group['attr_count'] > $maxCount) {
                $maxCount = $group['attr_count'];
                $largestGroup = $group;
            }
        }
        
        if ($largestGroup && $largestGroup['attr_count'] > 20) {
            echo "⚠️  ISSUE DETECTED:\n";
            echo "Group '{$largestGroup['code']}' contains {$largestGroup['attr_count']} attributes!\n";
            echo "Recommendation: Distribute attributes into more specific groups.\n\n";
        }
        
        // Get attribute details for the largest group
        if ($largestGroup) {
            echo "2. ATTRIBUTES IN '{$largestGroup['code']}' GROUP\n";
            echo "========================================\n\n";
            
            $stmt = $pdo->prepare("
                SELECT 
                    a.code,
                    a.attribute_type,
                    a.is_scopable,
                    a.is_localizable,
                    COALESCE(t.label, a.code) as label
                FROM pim_catalog_attribute a
                LEFT JOIN pim_catalog_attribute_translation t 
                    ON a.id = t.foreign_key AND t.locale = 'en_US'
                WHERE a.group_id = ?
                ORDER BY a.code
            ");
            $stmt->execute([$largestGroup['id']]);
            $attributes = $stmt->fetchAll(PDO::FETCH_ASSOC);
            
            // Categorize attributes by type
            $byType = [];
            foreach ($attributes as $attr) {
                $type = $attr['attribute_type'];
                if (!isset($byType[$type])) {
                    $byType[$type] = [];
                }
                $byType[$type][] = $attr;
            }
            
            echo "Attributes by Type:\n";
            foreach ($byType as $type => $attrs) {
                echo "\n" . strtoupper($type) . " (" . count($attrs) . " attributes):\n";
                echo str_repeat('-', 80) . "\n";
                
                foreach (array_slice($attrs, 0, 10) as $attr) {
                    $scope = $attr['is_scopable'] ? 'Scopable' : 'Global';
                    $locale = $attr['is_localizable'] ? 'Localizable' : 'Non-localizable';
                    echo "  • {$attr['code']}\n";
                    echo "    Label: {$attr['label']}\n";
                    echo "    Scope: $scope | Locale: $locale\n";
                }
                
                if (count($attrs) > 10) {
                    echo "  ... and " . (count($attrs) - 10) . " more\n";
                }
            }
        }
        
        // Suggest reorganization strategy
        echo "\n\n3. REORGANIZATION STRATEGY\n";
        echo "========================================\n\n";
        
        echo "Recommended Attribute Groups:\n\n";
        
        $suggestedGroups = [
            'marketing' => [
                'label' => 'Marketing Information',
                'description' => 'SEO, descriptions, marketing copy',
                'sort_order' => 10,
                'examples' => ['meta_title', 'meta_description', 'seo_', 'marketing_', 'description']
            ],
            'technical' => [
                'label' => 'Technical Specifications',
                'description' => 'Technical details, dimensions, weights',
                'sort_order' => 20,
                'examples' => ['technical_', 'spec_', 'dimension', 'weight', 'capacity']
            ],
            'media' => [
                'label' => 'Media & Images',
                'description' => 'Images, videos, documents',
                'sort_order' => 30,
                'examples' => ['image', 'picture', 'photo', 'video', 'document', 'file']
            ],
            'pricing' => [
                'label' => 'Pricing & Commercial',
                'description' => 'Prices, costs, margins',
                'sort_order' => 40,
                'examples' => ['price', 'cost', 'margin', 'promo', 'discount']
            ],
            'logistics' => [
                'label' => 'Logistics & Shipping',
                'description' => 'Shipping, packaging, warehouse',
                'sort_order' => 50,
                'examples' => ['shipping', 'package', 'warehouse', 'stock', 'logistics']
            ]
        ];
        
        foreach ($suggestedGroups as $code => $info) {
            echo "Group: {$info['label']} (code: $code)\n";
            echo "  Sort Order: {$info['sort_order']}\n";
            echo "  Description: {$info['description']}\n";
            echo "  Pattern examples: " . implode(', ', $info['examples']) . "\n\n";
        }
        
        echo "4. IMPLEMENTATION SCRIPT\n";
        echo "========================================\n\n";
        
        echo "To reorganize attributes, you can:\n\n";
        echo "Option A - Use Akeneo UI:\n";
        echo "  1. Settings > Attributes\n";
        echo "  2. Select attributes\n";
        echo "  3. Edit > Change attribute group\n\n";
        
        echo "Option B - Use API/Database (Careful!):\n";
        echo "  1. Create new attribute groups via UI\n";
        echo "  2. Note the group IDs\n";
        echo "  3. Run SQL updates (with backup!)\n\n";
        
        echo "Option C - Use provided reorganization script:\n";
        echo "  cd /home/pim/public_html/webapp\n";
        echo "  php reorganize_attributes.php --dry-run\n";
        echo "  php reorganize_attributes.php --execute\n\n";
        
        // Save analysis to file
        $reportFile = __DIR__ . '/attribute_group_analysis_' . date('Ymd_His') . '.txt';
        ob_start();
        
        echo "ATTRIBUTE GROUP ANALYSIS REPORT\n";
        echo "Generated: " . date('Y-m-d H:i:s') . "\n";
        echo str_repeat('=', 80) . "\n\n";
        
        echo "Current Distribution:\n";
        foreach ($groups as $group) {
            echo "  {$group['code']}: {$group['attr_count']} attributes\n";
        }
        
        echo "\nLargest Group: {$largestGroup['code']} ({$largestGroup['attr_count']} attributes)\n";
        echo "\nRecommendation: Create specific groups and distribute attributes\n";
        
        $report = ob_get_clean();
        file_put_contents($reportFile, $report);
        
        echo "\n✓ Analysis saved to: $reportFile\n";
        
    } catch (PDOException $e) {
        echo "✗ Database error: " . $e->getMessage() . "\n";
    }
} else {
    echo "✗ Could not parse DATABASE_URL\n";
}

echo "\n=========================================\n";
echo "ANALYSIS COMPLETE\n";
echo "=========================================\n";

