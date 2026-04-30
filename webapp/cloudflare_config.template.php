<?php
/**
 * Cloudflare Configuration - Template
 * Copy to cloudflare_config.php and fill in your credentials
 * 
 * DO NOT COMMIT cloudflare_config.php to git!
 * 
 * Date: 2026-04-30
 * Repository: https://github.com/mounirtms/akeneoPim.git
 */

return [
    'email' => getenv('CLOUDFLARE_EMAIL') ?: 'your-email@example.com',
    'global_api_key' => getenv('CLOUDFLARE_API_KEY') ?: 'your-global-api-key-here',
    'api_token' => getenv('CLOUDFLARE_API_TOKEN') ?: 'your-api-token-here',
    'dashboard_token' => getenv('CLOUDFLARE_DASHBOARD_TOKEN') ?: 'your-dashboard-token-here',
    'zone_id' => getenv('CLOUDFLARE_ZONE_ID') ?: 'your-zone-id-here',
    'account_id' => getenv('CLOUDFLARE_ACCOUNT_ID') ?: 'your-account-id-here',
    'origin_ca_key' => getenv('CLOUDFLARE_ORIGIN_CA_KEY') ?: 'your-origin-ca-key-here',
    'api_base' => 'https://api.cloudflare.com/client/v4',
];

/*
 * SETUP INSTRUCTIONS:
 * 
 * Option 1: Environment Variables (Recommended)
 * ---------------------------------------------
 * export CLOUDFLARE_EMAIL="your-email@example.com"
 * export CLOUDFLARE_API_KEY="your-global-api-key"
 * export CLOUDFLARE_API_TOKEN="your-api-token"
 * export CLOUDFLARE_DASHBOARD_TOKEN="your-dashboard-token"
 * export CLOUDFLARE_ZONE_ID="your-zone-id"
 * export CLOUDFLARE_ACCOUNT_ID="your-account-id"
 * export CLOUDFLARE_ORIGIN_CA_KEY="your-origin-ca-key"
 * 
 * Option 2: Local Configuration File
 * ---------------------------------
 * 1. Copy this file: cp cloudflare_config.template.php cloudflare_config.php
 * 2. Edit cloudflare_config.php and replace the placeholder values
 * 3. Ensure cloudflare_config.php is in .gitignore
 * 
 * Security Note:
 * - Keep credentials secure
 * - Use environment variables in production
 * - Never commit credentials to git
 * - Rotate keys regularly
 */
