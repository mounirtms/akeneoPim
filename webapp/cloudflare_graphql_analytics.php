<?php
/**
 * Cloudflare GraphQL Analytics Integration
 * Fetches analytics data from Cloudflare GraphQL API
 * 
 * Date: 2026-04-30
 * Repository: https://github.com/mounirtms/akeneoPim.git
 */

class CloudflareGraphQLAnalytics {
    private $config;
    private $zoneId;
    private $graphqlEndpoint = 'https://api.cloudflare.com/client/v4/graphql';
    
    public function __construct() {
        $this->config = require __DIR__ . '/cloudflare_config.php';
        $this->zoneId = $this->config['zone_id'];
    }
    
    /**
     * Execute GraphQL query
     */
    private function query($graphql) {
        $ch = curl_init($this->graphqlEndpoint);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_HTTPHEADER, [
            'X-Auth-Email: ' . $this->config['email'],
            'X-Auth-Key: ' . $this->config['global_api_key'],
            'Content-Type: application/json'
        ]);
        curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode([
            'query' => $graphql
        ]));
        
        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);
        
        if ($httpCode !== 200) {
            error_log("Cloudflare GraphQL error: HTTP $httpCode - $response");
            return null;
        }
        
        $data = json_decode($response, true);
        
        if (isset($data['errors'])) {
            error_log("GraphQL errors: " . json_encode($data['errors']));
            return null;
        }
        
        return $data['data'] ?? null;
    }
    
    /**
     * Get analytics for last 7 days
     */
    public function getAnalytics7d() {
        $query = <<<'GRAPHQL'
query {
  viewer {
    zones(filter: {zoneTag: "%ZONE_ID%"}) {
      httpRequests1dGroups(limit: 7, filter: {date_gt: "2026-04-23"}) {
        sum {
          requests
          cachedRequests
          bandwidth
          cachedBandwidth
          threats
          pageViews
        }
        dimensions {
          date
        }
      }
    }
  }
}
GRAPHQL;
        
        $query = str_replace('%ZONE_ID%', $this->zoneId, $query);
        $data = $this->query($query);
        
        if (!$data) {
            return null;
        }
        
        return $data['viewer']['zones'][0]['httpRequests1dGroups'] ?? [];
    }
    
    /**
     * Get analytics for last 24 hours
     */
    public function getAnalytics24h() {
        $query = <<<'GRAPHQL'
query {
  viewer {
    zones(filter: {zoneTag: "%ZONE_ID%"}) {
      httpRequests1hGroups(limit: 24, filter: {datetime_gt: "2026-04-29T00:00:00Z"}) {
        sum {
          requests
          cachedRequests
          bandwidth
          cachedBandwidth
          threats
          pageViews
        }
        dimensions {
          datetime
        }
      }
    }
  }
}
GRAPHQL;
        
        $query = str_replace('%ZONE_ID%', $this->zoneId, $query);
        $data = $this->query($query);
        
        if (!$data) {
            return null;
        }
        
        return $data['viewer']['zones'][0]['httpRequests1hGroups'] ?? [];
    }
    
    /**
     * Get cache hit rate
     */
    public function getCacheHitRate($period = '24h') {
        $analytics = $period === '24h' ? $this->getAnalytics24h() : $this->getAnalytics7d();
        
        if (!$analytics) {
            return 0;
        }
        
        $totalRequests = 0;
        $cachedRequests = 0;
        
        foreach ($analytics as $row) {
            $totalRequests += $row['sum']['requests'] ?? 0;
            $cachedRequests += $row['sum']['cachedRequests'] ?? 0;
        }
        
        if ($totalRequests == 0) {
            return 0;
        }
        
        return round(($cachedRequests / $totalRequests) * 100, 2);
    }
    
    /**
     * Get bandwidth savings
     */
    public function getBandwidthSavings($period = '24h') {
        $analytics = $period === '24h' ? $this->getAnalytics24h() : $this->getAnalytics7d();
        
        if (!$analytics) {
            return ['saved' => 0, 'percentage' => 0, 'saved_human' => '0 B'];
        }
        
        $totalBandwidth = 0;
        $cachedBandwidth = 0;
        
        foreach ($analytics as $row) {
            $totalBandwidth += $row['sum']['bandwidth'] ?? 0;
            $cachedBandwidth += $row['sum']['cachedBandwidth'] ?? 0;
        }
        
        if ($totalBandwidth == 0) {
            return ['saved' => 0, 'percentage' => 0, 'saved_human' => '0 B'];
        }
        
        return [
            'saved' => $cachedBandwidth,
            'saved_human' => $this->formatBytes($cachedBandwidth),
            'percentage' => round(($cachedBandwidth / $totalBandwidth) * 100, 2)
        ];
    }
    
    /**
     * Get total metrics
     */
    public function getTotalMetrics($period = '24h') {
        $analytics = $period === '24h' ? $this->getAnalytics24h() : $this->getAnalytics7d();
        
        if (!$analytics) {
            return null;
        }
        
        $totals = [
            'requests' => 0,
            'cachedRequests' => 0,
            'bandwidth' => 0,
            'cachedBandwidth' => 0,
            'threats' => 0,
            'pageViews' => 0
        ];
        
        foreach ($analytics as $row) {
            $totals['requests'] += $row['sum']['requests'] ?? 0;
            $totals['cachedRequests'] += $row['sum']['cachedRequests'] ?? 0;
            $totals['bandwidth'] += $row['sum']['bandwidth'] ?? 0;
            $totals['cachedBandwidth'] += $row['sum']['cachedBandwidth'] ?? 0;
            $totals['threats'] += $row['sum']['threats'] ?? 0;
            $totals['pageViews'] += $row['sum']['pageViews'] ?? 0;
        }
        
        return $totals;
    }
    
    /**
     * Format bytes to human readable
     */
    private function formatBytes($bytes, $precision = 2) {
        $units = ['B', 'KB', 'MB', 'GB', 'TB'];
        
        for ($i = 0; $bytes > 1024 && $i < count($units) - 1; $i++) {
            $bytes /= 1024;
        }
        
        return round($bytes, $precision) . ' ' . $units[$i];
    }
    
    /**
     * Get comprehensive dashboard data
     */
    public function getDashboardData() {
        $metrics24h = $this->getTotalMetrics('24h');
        $metrics7d = $this->getTotalMetrics('7d');
        
        return [
            'zone_id' => $this->zoneId,
            'cache_hit_rate_24h' => $this->getCacheHitRate('24h'),
            'cache_hit_rate_7d' => $this->getCacheHitRate('7d'),
            'bandwidth_savings_24h' => $this->getBandwidthSavings('24h'),
            'bandwidth_savings_7d' => $this->getBandwidthSavings('7d'),
            'metrics_24h' => $metrics24h,
            'metrics_7d' => $metrics7d,
            'timestamp' => date('Y-m-d H:i:s')
        ];
    }
}

// CLI usage
if (php_sapi_name() === 'cli') {
    $cf = new CloudflareGraphQLAnalytics();
    
    echo "╔══════════════════════════════════════════════════════════╗\n";
    echo "║     Cloudflare GraphQL Analytics Dashboard               ║\n";
    echo "╚══════════════════════════════════════════════════════════╝\n\n";
    
    $data = $cf->getDashboardData();
    
    echo "📊 Last 24 Hours:\n";
    if ($data['metrics_24h']) {
        echo "  Total Requests: " . number_format($data['metrics_24h']['requests']) . "\n";
        echo "  Cached Requests: " . number_format($data['metrics_24h']['cachedRequests']) . "\n";
        echo "  Cache Hit Rate: " . $data['cache_hit_rate_24h'] . "%\n";
        echo "  Bandwidth: " . $cf->formatBytes($data['metrics_24h']['bandwidth']) . "\n";
        echo "  Cached Bandwidth: " . $cf->formatBytes($data['metrics_24h']['cachedBandwidth']) . "\n";
        echo "  Bandwidth Saved: " . $data['bandwidth_savings_24h']['saved_human'] . " (" . $data['bandwidth_savings_24h']['percentage'] . "%)\n";
        echo "  Threats Blocked: " . number_format($data['metrics_24h']['threats']) . "\n";
        echo "  Page Views: " . number_format($data['metrics_24h']['pageViews']) . "\n\n";
    }
    
    echo "📈 Last 7 Days:\n";
    if ($data['metrics_7d']) {
        echo "  Total Requests: " . number_format($data['metrics_7d']['requests']) . "\n";
        echo "  Cached Requests: " . number_format($data['metrics_7d']['cachedRequests']) . "\n";
        echo "  Cache Hit Rate: " . $data['cache_hit_rate_7d'] . "%\n";
        echo "  Bandwidth: " . $cf->formatBytes($data['metrics_7d']['bandwidth']) . "\n";
        echo "  Bandwidth Saved: " . $data['bandwidth_savings_7d']['saved_human'] . " (" . $data['bandwidth_savings_7d']['percentage'] . "%)\n";
        echo "  Threats Blocked: " . number_format($data['metrics_7d']['threats']) . "\n";
        echo "  Page Views: " . number_format($data['metrics_7d']['pageViews']) . "\n";
    }
    
    echo "\nTimestamp: " . $data['timestamp'] . "\n";
}
