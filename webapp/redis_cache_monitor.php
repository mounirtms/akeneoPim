#!/usr/bin/env php
<?php
/**
 * Redis Cache Monitor
 * Monitors Redis cache performance and hit rates
 * 
 * Date: 2026-04-30
 * Repository: https://github.com/mounirtms/akeneoPim.git
 * Branch: oldbranch
 */

class RedisCacheMonitor {
    private $redis;
    private $databases = [
        1 => 'App Cache',
        2 => 'Doctrine Result Cache',
        3 => 'Doctrine System Cache',
        4 => 'Validator Cache',
        5 => 'Serializer Cache',
        6 => 'Session Storage'
    ];
    
    public function __construct() {
        $this->redis = new Redis();
        $this->redis->connect('localhost', 6379);
    }
    
    /**
     * Get cache statistics for all databases
     */
    public function getCacheStats() {
        $stats = [];
        
        foreach ($this->databases as $db => $name) {
            $this->redis->select($db);
            $info = $this->redis->info('stats');
            
            $keys = $this->redis->dbSize();
            $memory = $this->redis->info('memory');
            
            $stats[$db] = [
                'name' => $name,
                'keys' => $keys,
                'memory_used' => $memory['used_memory_human'] ?? 'N/A',
                'hits' => $info['keyspace_hits'] ?? 0,
                'misses' => $info['keyspace_misses'] ?? 0,
                'hit_rate' => $this->calculateHitRate($info)
            ];
        }
        
        return $stats;
    }
    
    /**
     * Calculate cache hit rate
     */
    private function calculateHitRate($info) {
        $hits = $info['keyspace_hits'] ?? 0;
        $misses = $info['keyspace_misses'] ?? 0;
        $total = $hits + $misses;
        
        if ($total == 0) {
            return 0;
        }
        
        return round(($hits / $total) * 100, 2);
    }
    
    /**
     * Get overall Redis stats
     */
    public function getOverallStats() {
        $this->redis->select(0);
        $info = $this->redis->info();
        
        return [
            'version' => $info['redis_version'] ?? 'Unknown',
            'uptime_days' => round(($info['uptime_in_seconds'] ?? 0) / 86400, 2),
            'connected_clients' => $info['connected_clients'] ?? 0,
            'used_memory' => $info['used_memory_human'] ?? 'N/A',
            'used_memory_peak' => $info['used_memory_peak_human'] ?? 'N/A',
            'total_commands' => $info['total_commands_processed'] ?? 0,
            'ops_per_sec' => $info['instantaneous_ops_per_sec'] ?? 0,
            'evicted_keys' => $info['evicted_keys'] ?? 0,
            'expired_keys' => $info['expired_keys'] ?? 0,
            'keyspace_hits' => $info['keyspace_hits'] ?? 0,
            'keyspace_misses' => $info['keyspace_misses'] ?? 0
        ];
    }
    
    /**
     * Display dashboard
     */
    public function displayDashboard() {
        echo "╔══════════════════════════════════════════════════════════════╗\n";
        echo "║           Redis Cache Performance Monitor                    ║\n";
        echo "╚══════════════════════════════════════════════════════════════╝\n\n";
        
        $overall = $this->getOverallStats();
        
        echo "📊 Overall Redis Stats:\n";
        echo "  Version: " . $overall['version'] . "\n";
        echo "  Uptime: " . $overall['uptime_days'] . " days\n";
        echo "  Memory Used: " . $overall['used_memory'] . " (Peak: " . $overall['used_memory_peak'] . ")\n";
        echo "  Connected Clients: " . $overall['connected_clients'] . "\n";
        echo "  Operations/sec: " . $overall['ops_per_sec'] . "\n";
        echo "  Total Commands: " . number_format($overall['total_commands']) . "\n";
        
        $totalHits = $overall['keyspace_hits'];
        $totalMisses = $overall['keyspace_misses'];
        $totalRequests = $totalHits + $totalMisses;
        $overallHitRate = $totalRequests > 0 ? round(($totalHits / $totalRequests) * 100, 2) : 0;
        
        echo "\n🎯 Cache Performance:\n";
        echo "  Total Hits: " . number_format($totalHits) . "\n";
        echo "  Total Misses: " . number_format($totalMisses) . "\n";
        echo "  Overall Hit Rate: " . $overallHitRate . "%\n";
        echo "  Evicted Keys: " . number_format($overall['evicted_keys']) . "\n";
        echo "  Expired Keys: " . number_format($overall['expired_keys']) . "\n";
        
        echo "\n💾 Cache by Database:\n";
        $stats = $this->getCacheStats();
        
        foreach ($stats as $db => $data) {
            echo "\n  DB{$db}: {$data['name']}\n";
            echo "    Keys: " . number_format($data['keys']) . "\n";
            echo "    Memory: " . $data['memory_used'] . "\n";
            echo "    Hits: " . number_format($data['hits']) . "\n";
            echo "    Misses: " . number_format($data['misses']) . "\n";
            echo "    Hit Rate: " . $data['hit_rate'] . "%\n";
        }
        
        echo "\n⚡ Performance Status: ";
        if ($overallHitRate >= 90) {
            echo "EXCELLENT ✅\n";
        } elseif ($overallHitRate >= 80) {
            echo "GOOD ✓\n";
        } elseif ($overallHitRate >= 60) {
            echo "FAIR ⚠\n";
        } else {
            echo "NEEDS IMPROVEMENT ❌\n";
        }
        
        echo "\nTimestamp: " . date('Y-m-d H:i:s') . "\n";
    }
    
    /**
     * Export stats as JSON
     */
    public function exportJson() {
        return json_encode([
            'overall' => $this->getOverallStats(),
            'databases' => $this->getCacheStats(),
            'timestamp' => date('Y-m-d H:i:s')
        ], JSON_PRETTY_PRINT);
    }
}

// CLI usage
if (php_sapi_name() === 'cli') {
    try {
        $monitor = new RedisCacheMonitor();
        
        if (isset($argv[1]) && $argv[1] === '--json') {
            echo $monitor->exportJson();
        } else {
            $monitor->displayDashboard();
        }
    } catch (Exception $e) {
        echo "Error: " . $e->getMessage() . "\n";
        exit(1);
    }
}
