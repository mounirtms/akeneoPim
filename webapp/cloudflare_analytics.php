<?php
/**
 * Cloudflare Analytics Integration
 * Fetches analytics data from Cloudflare API
 * 
 * Date: 2026-04-30
 */

class CloudflareAnalytics {
    private $config;
    private $zoneId;
    private $apiBase;
    
    public function __construct() {
        $this->config = require __DIR__ . '/cloudflare_config.php';
        $this->zoneId = $this->config['zone_id'];
        $this->apiBase = $this->config['api_base'];
    }
    
    /**
     * Make API request to Cloudflare
     */
    private function request($endpoint, $params = []) {
        $url = $this->apiBase . $endpoint;
        
        if (!empty($params)) {
            $url .= '?' . http_build_query($params);
        }
        
        $ch = curl_init($url);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_HTTPHEADER, [
            'X-Auth-Email: ' . $this->config['email'],
            'X-Auth-Key: ' . $this->config['global_api_key'],
            'Content-Type: application/json'
        ]);
        
        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);
        
        if ($httpCode !== 200) {
            error_log("Cloudflare API error: HTTP $httpCode - $response");
            return null;
        }
        
        return json_decode($response, true);
    }
    
    /**
     * Get zone information
     */
    public function getZoneInfo() {
        $data = $this->request("/zones/{$this->zoneId}");
        
        if (!$data || !$data['success']) {
            return null;
        }
        
        return [
            'name' => $data['result']['name'] ?? 'Unknown',
            'status' => $data['result']['status'] ?? 'Unknown',
            'paused' => $data['result']['paused'] ?? false,
            'plan' => $data['result']['plan']['name'] ?? 'Unknown',
            'name_servers' => $data['result']['name_servers'] ?? []
        ];
    }
    
    /**
     * Get analytics for last 24 hours
     */
    public function getAnalytics24h() {
        $params = [
            'since' => -1440, // Last 24 hours in minutes
            'until' => 0
        ];
        
        $data = $this->request("/zones/{$this->zoneId}/analytics/dashboard", $params);
        
        if (!$data || !$data['success']) {
            return null;
        }
        
        $result = $data['result']['totals'] ?? [];
        
        return [
            'requests' => [
                'all' => $result['requests']['all'] ?? 0,
                'cached' => $result['requests']['cached'] ?? 0,
                'uncached' => $result['requests']['uncached'] ?? 0
            ],
            'bandwidth' => [
                'all' => $result['bandwidth']['all'] ?? 0,
                'cached' => $result['bandwidth']['cached'] ?? 0,
                'uncached' => $result['bandwidth']['uncached'] ?? 0
            ],
            'threats' => $result['threats']['all'] ?? 0,
            'pageviews' => $result['pageviews']['all'] ?? 0,
            'uniques' => $result['uniques']['all'] ?? 0
        ];
    }
    
    /**
     * Get cache hit rate
     */
    public function getCacheHitRate() {
        $analytics = $this->getAnalytics24h();
        
        if (!$analytics) {
            return 0;
        }
        
        $total = $analytics['requests']['all'];
        $cached = $analytics['requests']['cached'];
        
        if ($total == 0) {
            return 0;
        }
        
        return round(($cached / $total) * 100, 2);
    }
    
    /**
     * Get bandwidth savings
     */
    public function getBandwidthSavings() {
        $analytics = $this->getAnalytics24h();
        
        if (!$analytics) {
            return [
                'saved' => 0,
                'percentage' => 0
            ];
        }
        
        $cached = $analytics['bandwidth']['cached'];
        $total = $analytics['bandwidth']['all'];
        
        if ($total == 0) {
            return [
                'saved' => 0,
                'percentage' => 0
            ];
        }
        
        return [
            'saved' => $cached,
            'saved_human' => $this->formatBytes($cached),
            'percentage' => round(($cached / $total) * 100, 2)
        ];
    }
    
    /**
     * Get analytics for last 7 days
     */
    public function getAnalytics7d() {
        $params = [
            'since' => -10080, // Last 7 days in minutes
            'until' => 0
        ];
        
        $data = $this->request("/zones/{$this->zoneId}/analytics/dashboard", $params);
        
        if (!$data || !$data['success']) {
            return null;
        }
        
        $result = $data['result']['totals'] ?? [];
        
        return [
            'requests' => [
                'all' => $result['requests']['all'] ?? 0,
                'cached' => $result['requests']['cached'] ?? 0,
                'uncached' => $result['requests']['uncached'] ?? 0
            ],
            'bandwidth' => [
                'all' => $result['bandwidth']['all'] ?? 0,
                'cached' => $result['bandwidth']['cached'] ?? 0,
                'uncached' => $result['bandwidth']['uncached'] ?? 0
            ],
            'threats' => $result['threats']['all'] ?? 0,
            'pageviews' => $result['pageviews']['all'] ?? 0,
            'uniques' => $result['uniques']['all'] ?? 0
        ];
    }
    
    /**
     * Get SSL/TLS settings
     */
    public function getSSLSettings() {
        $data = $this->request("/zones/{$this->zoneId}/settings/ssl");
        
        if (!$data || !$data['success']) {
            return 'Unknown';
        }
        
        return $data['result']['value'] ?? 'Unknown';
    }
    
    /**
     * Get security level
     */
    public function getSecurityLevel() {
        $data = $this->request("/zones/{$this->zoneId}/settings/security_level");
        
        if (!$data || !$data['success']) {
            return 'Unknown';
        }
        
        return $data['result']['value'] ?? 'Unknown';
    }
    
    /**
     * Get firewall events (threats)
     */
    public function getFirewallEvents() {
        $data = $this->request("/zones/{$this->zoneId}/firewall/events", [
            'per_page' => 10
        ]);
        
        if (!$data || !$data['success']) {
            return [];
        }
        
        return $data['result'] ?? [];
    }
    
    /**
     * Purge cache
     */
    public function purgeCache($purgeEverything = true) {
        $url = $this->apiBase . "/zones/{$this->zoneId}/purge_cache";
        
        $ch = curl_init($url);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_HTTPHEADER, [
            'X-Auth-Email: ' . $this->config['email'],
            'X-Auth-Key: ' . $this->config['global_api_key'],
            'Content-Type: application/json'
        ]);
        curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode([
            'purge_everything' => $purgeEverything
        ]));
        
        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);
        
        $data = json_decode($response, true);
        
        return [
            'success' => $data['success'] ?? false,
            'message' => $data['success'] ? 'Cache purged successfully' : 'Failed to purge cache'
        ];
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
        return [
            'zone' => $this->getZoneInfo(),
            'analytics_24h' => $this->getAnalytics24h(),
            'analytics_7d' => $this->getAnalytics7d(),
            'cache_hit_rate' => $this->getCacheHitRate(),
            'bandwidth_savings' => $this->getBandwidthSavings(),
            'ssl_mode' => $this->getSSLSettings(),
            'security_level' => $this->getSecurityLevel(),
            'timestamp' => date('Y-m-d H:i:s')
        ];
    }
}

// CLI usage
if (php_sapi_name() === 'cli') {
    $cf = new CloudflareAnalytics();
    
    echo "╔══════════════════════════════════════════════════════════╗\n";
    echo "║          Cloudflare Analytics Dashboard                  ║\n";
    echo "╚══════════════════════════════════════════════════════════╝\n\n";
    
    $data = $cf->getDashboardData();
    
    echo "Zone Information:\n";
    echo "  Name: " . ($data['zone']['name'] ?? 'N/A') . "\n";
    echo "  Status: " . ($data['zone']['status'] ?? 'N/A') . "\n";
    echo "  Plan: " . ($data['zone']['plan'] ?? 'N/A') . "\n";
    echo "  SSL Mode: " . $data['ssl_mode'] . "\n";
    echo "  Security Level: " . $data['security_level'] . "\n\n";
    
    if ($data['analytics_24h']) {
        echo "Last 24 Hours:\n";
        echo "  Total Requests: " . number_format($data['analytics_24h']['requests']['all']) . "\n";
        echo "  Cached Requests: " . number_format($data['analytics_24h']['requests']['cached']) . "\n";
        echo "  Cache Hit Rate: " . $data['cache_hit_rate'] . "%\n";
        echo "  Bandwidth Saved: " . $data['bandwidth_savings']['saved_human'] . " (" . $data['bandwidth_savings']['percentage'] . "%)\n";
        echo "  Threats Blocked: " . number_format($data['analytics_24h']['threats']) . "\n";
        echo "  Page Views: " . number_format($data['analytics_24h']['pageviews']) . "\n";
        echo "  Unique Visitors: " . number_format($data['analytics_24h']['uniques']) . "\n\n";
    }
    
    if ($data['analytics_7d']) {
        echo "Last 7 Days:\n";
        echo "  Total Requests: " . number_format($data['analytics_7d']['requests']['all']) . "\n";
        echo "  Cached Requests: " . number_format($data['analytics_7d']['requests']['cached']) . "\n";
        echo "  Threats Blocked: " . number_format($data['analytics_7d']['threats']) . "\n";
        echo "  Page Views: " . number_format($data['analytics_7d']['pageviews']) . "\n";
        echo "  Unique Visitors: " . number_format($data['analytics_7d']['uniques']) . "\n";
    }
}
