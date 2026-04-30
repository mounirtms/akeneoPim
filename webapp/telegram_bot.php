#!/usr/bin/env php
<?php
/**
 * Telegram Bot for Akeneo PIM Monitoring
 * Sends alerts and monitoring data to Telegram
 * 
 * Date: 2026-04-30
 * Repository: https://github.com/mounirtms/akeneoPim.git
 * Branch: oldbranch
 * 
 * Setup Instructions:
 * 1. Create a Telegram bot via @BotFather
 * 2. Get your chat ID from @userinfobot
 * 3. Set environment variables:
 *    export TELEGRAM_BOT_TOKEN="your_bot_token"
 *    export TELEGRAM_CHAT_ID="your_chat_id"
 */

class AkeneoTelegramBot {
    private $botToken;
    private $chatId;
    private $apiUrl;
    
    public function __construct() {
        $this->botToken = getenv('TELEGRAM_BOT_TOKEN') ?: '';
        $this->chatId = getenv('TELEGRAM_CHAT_ID') ?: '';
        
        if (empty($this->botToken)) {
            throw new Exception("TELEGRAM_BOT_TOKEN environment variable not set");
        }
        
        if (empty($this->chatId)) {
            throw new Exception("TELEGRAM_CHAT_ID environment variable not set");
        }
        
        $this->apiUrl = "https://api.telegram.org/bot{$this->botToken}";
    }
    
    /**
     * Send message to Telegram
     */
    public function sendMessage($message, $parseMode = 'HTML') {
        $url = $this->apiUrl . '/sendMessage';
        
        $data = [
            'chat_id' => $this->chatId,
            'text' => $message,
            'parse_mode' => $parseMode,
            'disable_web_page_preview' => true
        ];
        
        $ch = curl_init($url);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_POSTFIELDS, http_build_query($data));
        
        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);
        
        if ($httpCode !== 200) {
            error_log("Telegram API error: HTTP $httpCode - $response");
            return false;
        }
        
        return json_decode($response, true);
    }
    
    /**
     * Format system health report
     */
    public function sendHealthReport() {
        $report = $this->generateHealthReport();
        
        $message = "🏥 <b>Akeneo PIM Health Report</b>\n\n";
        $message .= "🕐 <b>Time:</b> " . date('Y-m-d H:i:s') . "\n\n";
        
        // Services status
        $message .= "🔧 <b>Services:</b>\n";
        foreach ($report['services'] as $service => $status) {
            $emoji = $status ? '✅' : '❌';
            $message .= "  $emoji $service: " . ($status ? 'Running' : 'Down') . "\n";
        }
        $message .= "\n";
        
        // System metrics
        $message .= "📊 <b>System Metrics:</b>\n";
        $message .= "  💾 Disk: {$report['disk']['used']}% used\n";
        $message .= "  🧠 Memory: {$report['memory']['used']}% used\n";
        $message .= "  ⚡ Load: {$report['load']}\n\n";
        
        // Cache
        $message .= "💨 <b>Cache:</b>\n";
        $message .= "  📁 File Cache: {$report['cache']['size']}\n";
        $message .= "  📝 Files: " . number_format($report['cache']['files']) . "\n\n";
        
        // Database
        $message .= "🗄️ <b>Database:</b>\n";
        $message .= "  📦 Products: " . number_format($report['database']['products']) . "\n";
        $message .= "  📂 Categories: " . number_format($report['database']['categories']) . "\n\n";
        
        // Overall health
        $healthEmoji = $report['health']['score'] >= 80 ? '🟢' : ($report['health']['score'] >= 60 ? '🟡' : '🔴');
        $message .= "$healthEmoji <b>Overall Health:</b> {$report['health']['score']}%\n";
        $message .= "  Status: {$report['health']['status']}";
        
        return $this->sendMessage($message);
    }
    
    /**
     * Send alert
     */
    public function sendAlert($title, $details, $severity = 'warning') {
        $emoji = [
            'critical' => '🚨',
            'warning' => '⚠️',
            'info' => 'ℹ️',
            'success' => '✅'
        ];
        
        $icon = $emoji[$severity] ?? '📢';
        
        $message = "$icon <b>$title</b>\n\n";
        $message .= $details . "\n\n";
        $message .= "🕐 " . date('Y-m-d H:i:s');
        
        return $this->sendMessage($message);
    }
    
    /**
     * Generate health report data
     */
    private function generateHealthReport() {
        $report = [
            'services' => $this->checkServices(),
            'disk' => $this->getDiskUsage(),
            'memory' => $this->getMemoryUsage(),
            'load' => $this->getLoadAverage(),
            'cache' => $this->getCacheInfo(),
            'database' => $this->getDatabaseInfo(),
            'health' => ['score' => 0, 'status' => 'Unknown']
        ];
        
        // Calculate health score
        $score = 100;
        if (!$report['services']['redis']) $score -= 10;
        if (!$report['services']['elasticsearch']) $score -= 20;
        if ($report['disk']['used'] > 80) $score -= 15;
        if ($report['memory']['used'] > 90) $score -= 20;
        
        $report['health']['score'] = max(0, $score);
        $report['health']['status'] = $score >= 80 ? 'Excellent' : ($score >= 60 ? 'Good' : 'Poor');
        
        return $report;
    }
    
    private function checkServices() {
        return [
            'redis' => $this->exec('redis-cli ping') === 'PONG',
            'elasticsearch' => $this->exec('curl -s http://localhost:9200/_cluster/health') !== false,
            'mariadb' => $this->exec('mysqladmin -h 127.0.0.1 -P 3307 ping') !== false
        ];
    }
    
    private function getDiskUsage() {
        $output = $this->exec("df -h /home/pim/public_html | tail -1 | awk '{print $5}'");
        $used = intval(str_replace('%', '', $output));
        return ['used' => $used, 'available' => 100 - $used];
    }
    
    private function getMemoryUsage() {
        $output = $this->exec("free | grep Mem | awk '{print ($3/$2) * 100.0}'");
        $used = round(floatval($output));
        return ['used' => $used, 'available' => 100 - $used];
    }
    
    private function getLoadAverage() {
        $output = $this->exec("uptime | awk -F'load average:' '{print $2}'");
        return trim($output);
    }
    
    private function getCacheInfo() {
        $size = $this->exec("du -sh /home/pim/public_html/var/cache/prod 2>/dev/null | cut -f1") ?: '0';
        $files = intval($this->exec("find /home/pim/public_html/var/cache/prod -type f 2>/dev/null | wc -l") ?: 0);
        return ['size' => $size, 'files' => $files];
    }
    
    private function getDatabaseInfo() {
        $products = intval($this->exec("mysql -h 127.0.0.1 -P 3307 -u root -pYourNewStrongPassword akeneo_pim -se 'SELECT COUNT(*) FROM pim_catalog_product' 2>/dev/null") ?: 0);
        $categories = intval($this->exec("mysql -h 127.0.0.1 -P 3307 -u root -pYourNewStrongPassword akeneo_pim -se 'SELECT COUNT(*) FROM pim_catalog_category' 2>/dev/null") ?: 0);
        return ['products' => $products, 'categories' => $categories];
    }
    
    private function exec($command) {
        $output = @shell_exec($command);
        return $output ? trim($output) : false;
    }
    
    /**
     * Test bot connection
     */
    public function testConnection() {
        $url = $this->apiUrl . '/getMe';
        
        $ch = curl_init($url);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);
        
        if ($httpCode === 200) {
            $data = json_decode($response, true);
            return $data['ok'] ?? false;
        }
        
        return false;
    }
}

// CLI usage
if (php_sapi_name() === 'cli') {
    try {
        $bot = new AkeneoTelegramBot();
        
        $command = $argv[1] ?? 'help';
        
        switch ($command) {
            case 'test':
                echo "Testing Telegram bot connection...\n";
                if ($bot->testConnection()) {
                    echo "✓ Bot connection successful!\n";
                    $bot->sendMessage("✅ Akeneo PIM Telegram Bot is now connected!");
                } else {
                    echo "✗ Bot connection failed!\n";
                    exit(1);
                }
                break;
                
            case 'health':
                echo "Sending health report...\n";
                $result = $bot->sendHealthReport();
                if ($result) {
                    echo "✓ Health report sent!\n";
                } else {
                    echo "✗ Failed to send health report\n";
                    exit(1);
                }
                break;
                
            case 'alert':
                $title = $argv[2] ?? 'Test Alert';
                $details = $argv[3] ?? 'This is a test alert from Akeneo PIM';
                $severity = $argv[4] ?? 'info';
                
                echo "Sending alert...\n";
                $result = $bot->sendAlert($title, $details, $severity);
                if ($result) {
                    echo "✓ Alert sent!\n";
                } else {
                    echo "✗ Failed to send alert\n";
                    exit(1);
                }
                break;
                
            case 'help':
            default:
                echo "Akeneo PIM Telegram Bot\n\n";
                echo "Setup:\n";
                echo "  1. Create bot with @BotFather on Telegram\n";
                echo "  2. Get chat ID from @userinfobot\n";
                echo "  3. Set environment variables:\n";
                echo "     export TELEGRAM_BOT_TOKEN=\"your_token\"\n";
                echo "     export TELEGRAM_CHAT_ID=\"your_chat_id\"\n\n";
                echo "Usage:\n";
                echo "  php telegram_bot.php test              - Test bot connection\n";
                echo "  php telegram_bot.php health            - Send health report\n";
                echo "  php telegram_bot.php alert <title> <details> [severity]\n";
                echo "                                          - Send custom alert\n\n";
                echo "Severity levels: critical, warning, info, success\n";
                break;
        }
        
    } catch (Exception $e) {
        echo "Error: " . $e->getMessage() . "\n";
        exit(1);
    }
}
