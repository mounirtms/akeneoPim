# ERP Integration Architecture Documentation
**Akeneo PIM Multi-Channel Integration**  
**Date:** 2026-04-23  
**Version:** 1.0  
**Author:** AI Development Team

---

## Table of Contents
1. [Overview](#overview)
2. [Integration Architecture](#integration-architecture)
3. [Channel Configuration](#channel-configuration)
4. [JDE Edwards Integration](#jde-edwards-integration)
5. [Cegid ERP Integration](#cegid-erp-integration)
6. [Data Flow & Synchronization](#data-flow--synchronization)
7. [API Specifications](#api-specifications)
8. [Error Handling & Monitoring](#error-handling--monitoring)
9. [Security & Authentication](#security--authentication)
10. [Deployment Guide](#deployment-guide)

---

## Overview

### Purpose
This document outlines the multi-channel integration architecture for Akeneo PIM, enabling seamless data synchronization between:
- **Magento E-commerce** (existing)
- **JDE Edwards ERP** (new)
- **Cegid ERP** (new)

### Business Objectives
- Centralize product data management in Akeneo PIM
- Automate data synchronization across multiple systems
- Ensure data consistency and quality
- Reduce manual data entry and errors
- Enable real-time or scheduled updates

### System Overview
```
┌─────────────────────────────────────────────────────────────┐
│                    Akeneo PIM (Master)                     │
│                   8,217 Products                            │
│          Currency: DZD | Locales: fr_FR, en_US             │
└───────┬──────────────────┬──────────────────┬──────────────┘
        │                  │                  │
        ▼                  ▼                  ▼
┌───────────────┐  ┌──────────────┐  ┌──────────────┐
│   Magento     │  │ JDE Edwards  │  │  Cegid ERP   │
│  E-commerce   │  │     ERP      │  │              │
│   Channel     │  │   Channel    │  │   Channel    │
└───────────────┘  └──────────────┘  └──────────────┘
```

---

## Integration Architecture

### Architectural Principles
1. **Master Data Management**: Akeneo PIM is the single source of truth
2. **Event-Driven**: Changes trigger automatic synchronization
3. **Batch Processing**: Support for bulk updates and scheduled jobs
4. **Error Recovery**: Automatic retry logic with exponential backoff
5. **Audit Trail**: Complete logging of all data transfers

### Integration Patterns

#### Pattern 1: Push Integration (Akeneo → Target System)
```
Akeneo PIM → API Gateway → Target System (Magento/JDE/Cegid)
```
- Used for: Product data, prices, descriptions, images
- Frequency: Real-time or scheduled
- Method: REST API calls

#### Pattern 2: Pull Integration (Target System → Akeneo)
```
Target System → Akeneo API → Data Validation → Storage
```
- Used for: Inventory levels, order data (if needed)
- Frequency: Scheduled (hourly/daily)
- Method: REST API or file-based

#### Pattern 3: File-Based Integration
```
Akeneo → CSV/XML Export → SFTP/FTP → Target System Import
```
- Used for: Bulk updates, legacy system compatibility
- Frequency: Daily batches
- Method: File transfer protocols

---

## Channel Configuration

### Created Channels

#### 1. E-commerce Channel (Magento)
```yaml
Code: ecommerce
Category Tree: master (ID: 1)
Locales: fr_FR, en_US
Currencies: DZD
Purpose: Magento 2 integration
Status: Active
```

#### 2. JDE Edwards ERP Channel
```yaml
Code: jde_edwards
Category Tree: master (ID: 1)
Locales: fr_FR, en_US
Currencies: DZD, EUR
Purpose: JDE Edwards ERP integration
Status: Active (Pending API Configuration)
```

#### 3. Cegid ERP Channel
```yaml
Code: cegid_erp
Category Tree: master (ID: 1)
Locales: fr_FR, en_US
Currencies: DZD, EUR
Purpose: Cegid ERP integration
Status: Active (Pending API Configuration)
```

### Channel Verification
```bash
# Verify channels in database
cd /home/pim/public_html
mariadb akeneo_pim -e "
SELECT 
    c.code as channel_code,
    COUNT(DISTINCT cl.locale_id) as locales,
    COUNT(DISTINCT cc.currency_id) as currencies
FROM pim_catalog_channel c
LEFT JOIN pim_catalog_channel_locale cl ON c.id = cl.channel_id
LEFT JOIN pim_catalog_channel_currency cc ON c.id = cc.channel_id
GROUP BY c.code
ORDER BY c.code;
"
```

---

## JDE Edwards Integration

### Overview
**JD Edwards EnterpriseOne** is a comprehensive ERP system providing integrated applications for financial management, manufacturing, supply chain, and distribution.

### Integration Method
**Primary**: REST API Integration  
**Fallback**: File-based (CSV) integration

### API Endpoints

#### 1. Product Master Data Sync
```http
POST /jderest/v2/dataservice/P4101
Content-Type: application/json
Authorization: Bearer {token}

{
  "identifier": "1140619022",
  "name": "Product Name",
  "price": 1500.00,
  "currency": "DZD",
  "description": "Product description in French",
  "category": "cat_3",
  "attributes": {
    "weight": "0.5",
    "dimensions": "10x20x5"
  }
}
```

#### 2. Price Updates
```http
PUT /jderest/v2/dataservice/P4106
Content-Type: application/json

{
  "identifier": "1140619022",
  "price": 1600.00,
  "currency": "DZD",
  "effective_date": "2026-04-23"
}
```

### Data Mapping

| Akeneo Field | JDE Edwards Field | Type | Required |
|-------------|-------------------|------|----------|
| identifier | LITM (Item Number) | String(25) | Yes |
| name (fr_FR) | DSC1 (Description) | String(30) | Yes |
| price (DZD) | UPRC (Unit Price) | Decimal | Yes |
| sku | AITM (Short Item Number) | String(8) | Yes |
| weight | WEIGHTE (Weight) | Decimal | No |
| family | STKC (Stock Class) | String(4) | No |

### Synchronization Schedule
- **Full Sync**: Daily at 02:00 AM (CET)
- **Delta Sync**: Every 4 hours
- **Real-time**: For critical price updates

### Implementation Script
Location: `/home/pim/public_html/webapp/JdeEdwardsConnector.php`

```php
<?php
// Example connector class structure
class JdeEdwardsConnector {
    private $apiEndpoint;
    private $accessToken;
    
    public function syncProducts(array $products): array {
        // Implementation for product sync
    }
    
    public function syncPrices(array $prices): array {
        // Implementation for price sync
    }
    
    public function handleErrors($response): void {
        // Error handling logic
    }
}
```

### Configuration Required
1. **API Credentials**
   - JDE Server URL
   - Client ID / Client Secret
   - Environment (Production/Test)

2. **Network Access**
   - Whitelist Akeneo PIM IP
   - Configure firewall rules
   - VPN access if required

3. **Testing Checklist**
   - [ ] Test product creation
   - [ ] Test product updates
   - [ ] Test price synchronization
   - [ ] Test error scenarios
   - [ ] Performance testing (bulk operations)

---

## Cegid ERP Integration

### Overview
**Cegid** is a French ERP solution specializing in retail, wholesale, and manufacturing sectors.

### Integration Method
**Primary**: File-based (CSV/XML) via SFTP  
**Secondary**: REST API (if available)

### File Specifications

#### 1. Product Export Format (CSV)
```csv
SKU,Name,Description,Price,Currency,Category,Stock,UpdateDate
1140619022,"Product Name","Description text",1500.00,DZD,cat_3,100,2026-04-23
```

#### 2. Product Export Format (XML)
```xml
<?xml version="1.0" encoding="UTF-8"?>
<Products>
  <Product>
    <SKU>1140619022</SKU>
    <Name><![CDATA[Product Name]]></Name>
    <Description><![CDATA[Description text]]></Description>
    <Price currency="DZD">1500.00</Price>
    <Category>cat_3</Category>
    <Stock>100</Stock>
    <UpdateDate>2026-04-23</UpdateDate>
  </Product>
</Products>
```

### SFTP Configuration
```yaml
Host: sftp.cegid-erp.example.com
Port: 22
Username: akeneo_integration
Authentication: SSH Key
Remote Path: /import/products/
File Naming: products_YYYYMMDD_HHMMSS.csv
Encoding: UTF-8
```

### Data Mapping

| Akeneo Field | Cegid Field | Format | Notes |
|-------------|-------------|--------|-------|
| identifier | Référence | String(20) | Primary key |
| name (fr_FR) | Libellé | String(100) | Required |
| price (DZD) | Prix_TTC | Decimal(10,2) | Including tax |
| description | Description | Text | HTML allowed |
| family | Famille | String(10) | Cegid family code |
| image | CheminImage | String(255) | Relative path |

### Synchronization Schedule
- **Full Export**: Daily at 01:00 AM (CET)
- **Delta Export**: Every 6 hours
- **File Retention**: 30 days on SFTP server

### Implementation Script
Location: `/home/pim/public_html/webapp/CegidErpConnector.php`

```php
<?php
class CegidErpConnector {
    private $sftpHost;
    private $sftpPort;
    
    public function exportProducts(array $products): string {
        // Generate CSV file
        $csv = $this->generateCSV($products);
        // Upload to SFTP
        return $this->uploadToSFTP($csv);
    }
    
    public function generateCSV(array $products): string {
        // CSV generation logic
    }
    
    public function uploadToSFTP(string $content): bool {
        // SFTP upload logic
    }
}
```

### Configuration Required
1. **SFTP Access**
   - Server hostname/IP
   - SSH key pair generation
   - Public key registration with Cegid

2. **File Format Validation**
   - Column order verification
   - Data type validation
   - Character encoding test

3. **Testing Checklist**
   - [ ] SFTP connection test
   - [ ] File upload test
   - [ ] Full product export (sample)
   - [ ] Delta export test
   - [ ] Error file handling
   - [ ] Cegid import validation

---

## Data Flow & Synchronization

### Flow Diagram
```
┌──────────────────────────────────────────────────────────────┐
│  Akeneo PIM Event System                                     │
│  (Product Update, Price Change, Image Upload)                │
└────────────────────┬─────────────────────────────────────────┘
                     │
                     ▼
         ┌───────────────────────┐
         │   Event Listener      │
         │   (Symfony Events)    │
         └───┬───────────┬───────┘
             │           │
      ┌──────▼──┐    ┌──▼──────┐
      │ Magento │    │   ERP   │
      │  Queue  │    │  Queue  │
      └────┬────┘    └────┬────┘
           │              │
           ▼              ▼
    ┌──────────┐    ┌───────────┐
    │ Magento  │    │ JDE/Cegid │
    │  Sync    │    │   Sync    │
    └──────────┘    └───────────┘
```

### Synchronization Types

#### 1. Real-Time Sync
- **Trigger**: Product update in Akeneo
- **Target**: Critical fields (price, stock status)
- **Method**: Immediate API call
- **Timeout**: 30 seconds
- **Retry**: 3 attempts with exponential backoff

#### 2. Scheduled Sync
- **Frequency**: Configurable (hourly, daily)
- **Target**: Full catalog updates
- **Method**: Batch processing
- **Batch Size**: 100 products per batch
- **Duration**: Estimated 2-4 hours for full catalog

#### 3. Manual Sync
- **Trigger**: Admin panel button
- **Target**: Selected products or categories
- **Method**: On-demand API call
- **Use Case**: Emergency updates, testing

### Sync Status Tracking
```sql
-- Create sync log table
CREATE TABLE IF NOT EXISTS akeneo_sync_log (
    id INT AUTO_INCREMENT PRIMARY KEY,
    channel_code VARCHAR(50) NOT NULL,
    product_identifier VARCHAR(255),
    sync_type ENUM('real-time', 'scheduled', 'manual'),
    status ENUM('pending', 'in_progress', 'success', 'failed'),
    error_message TEXT,
    started_at DATETIME,
    completed_at DATETIME,
    INDEX idx_channel (channel_code),
    INDEX idx_status (status),
    INDEX idx_created (started_at)
);
```

---

## API Specifications

### Akeneo REST API Endpoints

#### Authentication
```http
POST /api/oauth/v1/token
Content-Type: application/json

{
  "grant_type": "password",
  "username": "admin",
  "password": "PimAdmin2026!",
  "client_id": "{client_id}",
  "client_secret": "{client_secret}"
}
```

#### Get Products
```http
GET /api/rest/v1/products?limit=100&with_count=true
Authorization: Bearer {access_token}
```

#### Update Product
```http
PATCH /api/rest/v1/products/{identifier}
Content-Type: application/json

{
  "values": {
    "price": [{
      "locale": null,
      "scope": "jde_edwards",
      "data": [{
        "amount": "1500.00",
        "currency": "DZD"
      }]
    }]
  }
}
```

### Rate Limiting
- **API Calls**: 1000 requests per hour
- **Batch Size**: Maximum 100 items per request
- **Timeout**: 60 seconds per request

---

## Error Handling & Monitoring

### Error Categories

#### 1. Connection Errors
- **Symptoms**: Timeout, connection refused
- **Action**: Retry with exponential backoff
- **Alert**: After 3 consecutive failures

#### 2. Authentication Errors
- **Symptoms**: 401 Unauthorized, 403 Forbidden
- **Action**: Refresh token, check credentials
- **Alert**: Immediate notification to admin

#### 3. Data Validation Errors
- **Symptoms**: 400 Bad Request, validation failures
- **Action**: Log error, skip record, continue
- **Alert**: Daily summary report

#### 4. System Errors
- **Symptoms**: 500 Internal Server Error
- **Action**: Pause sync, investigate
- **Alert**: Immediate notification

### Monitoring Dashboard
Location: `/home/pim/public_html/webapp/quality_dashboard_standalone.php`

**Metrics Tracked:**
- Total products synced (by channel)
- Sync success rate
- Average sync duration
- Failed syncs (last 24h)
- API response times
- Error frequency by type

### Logging
```php
// Log format
[2026-04-23 22:00:00] JDE_SYNC.INFO: 
  Product sync started for channel jde_edwards 
  {"batch_size": 100, "products": [1140619022, ...]}

[2026-04-23 22:01:30] JDE_SYNC.SUCCESS: 
  Synced 100 products successfully 
  {"duration": 90, "success": 98, "failed": 2}

[2026-04-23 22:01:31] JDE_SYNC.ERROR: 
  Failed to sync product 1140619025 
  {"error": "Invalid price format", "product": 1140619025}
```

---

## Security & Authentication

### API Security

#### 1. OAuth 2.0 for JDE Edwards
```yaml
Grant Type: Client Credentials
Token Endpoint: https://jde.example.com/oauth2/token
Token Lifetime: 3600 seconds
Refresh: Automatic before expiration
```

#### 2. SSH Key Authentication for Cegid SFTP
```bash
# Generate SSH key pair
ssh-keygen -t rsa -b 4096 -f ~/.ssh/cegid_integration_key

# Share public key with Cegid admin
cat ~/.ssh/cegid_integration_key.pub
```

### Data Encryption
- **In Transit**: TLS 1.2+ for all API calls
- **At Rest**: Database encryption enabled
- **Credentials**: Stored in environment variables, never in code

### Access Control
```yaml
Akeneo Admin User: admin
JDE Integration User: jde_integration_user
Cegid Integration User: cegid_integration_user

Permissions:
  - Read: All products
  - Write: Limited to sync user's scope
  - Delete: Restricted (admin only)
```

---

## Deployment Guide

### Prerequisites
- [x] Akeneo PIM 6.0+ installed
- [x] PHP 8.1+ with required extensions
- [x] MariaDB 11.4+ database
- [x] Composer installed
- [x] Network access to target systems

### Step 1: Channel Creation
```bash
cd /home/pim/public_html/webapp
bash create_erp_channels.sh
```

### Step 2: Configure API Credentials
```bash
# Edit .env.local
nano /home/pim/public_html/.env.local

# Add:
JDE_API_ENDPOINT=https://jde.example.com/api
JDE_CLIENT_ID=your_client_id
JDE_CLIENT_SECRET=your_client_secret

CEGID_SFTP_HOST=sftp.cegid-erp.example.com
CEGID_SFTP_PORT=22
CEGID_SFTP_USER=akeneo_integration
CEGID_SFTP_KEY=/home/pim/.ssh/cegid_integration_key
```

### Step 3: Install Dependencies
```bash
cd /home/pim/public_html
composer require guzzlehttp/guzzle
composer require phpseclib/phpseclib
```

### Step 4: Clear Cache
```bash
php bin/console cache:clear --env=prod
bash webapp/fix_cache_permissions.sh
```

### Step 5: Test Connections
```bash
# Test JDE Edwards API
php webapp/test_jde_connection.php

# Test Cegid SFTP
php webapp/test_cegid_sftp.php
```

### Step 6: Configure Cron Jobs
```bash
# Edit crontab
crontab -e

# Add sync jobs:
# JDE Edwards - Every 4 hours
0 */4 * * * cd /home/pim/public_html && php webapp/sync_jde_edwards.php >> /home/pim/logs/jde_sync.log 2>&1

# Cegid - Daily at 1 AM
0 1 * * * cd /home/pim/public_html && php webapp/sync_cegid_erp.php >> /home/pim/logs/cegid_sync.log 2>&1
```

### Step 7: Monitor & Verify
```bash
# Check sync logs
tail -f /home/pim/logs/jde_sync.log
tail -f /home/pim/logs/cegid_sync.log

# Check dashboard
# Visit: https://pim.technostationery.com/dashboard
```

---

## Appendix

### A. Glossary
- **PIM**: Product Information Management
- **ERP**: Enterprise Resource Planning
- **SKU**: Stock Keeping Unit
- **DZD**: Algerian Dinar
- **SFTP**: SSH File Transfer Protocol

### B. Reference Links
- Akeneo API Docs: https://api.akeneo.com/
- JDE Edwards REST API: https://docs.oracle.com/cd/E53430_01/EOTRS/
- Cegid Integration Guide: https://docs.cegid.com/

### C. Support Contacts
- Akeneo Admin: admin@techno-dz.com
- IT Support: webmaster@techno-dz.com
- Marketing: marketting@techno-dz.com

### D. Change Log

| Date | Version | Changes | Author |
|------|---------|---------|--------|
| 2026-04-23 | 1.0 | Initial architecture documentation | AI Dev Team |

---

**Document Status**: Draft  
**Review Required**: Yes  
**Next Review Date**: 2026-05-01

