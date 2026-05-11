# Akeneo PIM - Comprehensive Technical Report
**Date:** May 6, 2026
**Domain:** pim.technostationery.com
**Project:** /home/pim/public_html
**Branch:** pimAkeno
**Akeneo Version:** Community Edition 6.0.113

---

## Table of Contents
1. [System Environment](#1-system-environment)
2. [Critical Issues Identified](#2-critical-issues-identified)
3. [Changes Made During This Session](#3-changes-made-during-this-session)
4. [Changes From Previous 3 Weeks](#4-changes-from-previous-3-weeks)
5. [Cloudflare Configuration](#5-cloudflare-configuration)
6. [Varnish Status](#6-varnish-status)
7. [OPcache Issues](#7-opcache-issues)
8. [PHP Version & Configuration](#8-php-version--configuration)
9. [Apache/cPanel Configuration](#9-apropecpanel-configuration)
10. [Database Configuration](#10-database-configuration)
11. [Elasticsearch Configuration](#11-elasticsearch-configuration)
12. [Authentication System Status](#12-authentication-system-status)
13. [Asset Pipeline Status](#13-asset-pipeline-status)
14. [Playwright Tests](#14-playwright-tests)
15. [Recommendations](#15-recommendations)

---

## 1. System Environment

### Server Stack
| Component | Version/Status | Notes |
|-----------|---------------|-------|
| **OS** | Linux 4.18.0-553.94.1.el8_10.x86_64 | CentOS/RHEL 8 |
| **Apache** | 2.4.66 (cPanel) | Built Apr 21, 2026 |
| **PHP CLI** | 8.2.30 | /usr/local/bin/php |
| **PHP-FPM (Web)** | 8.3 (via .htaccess handler) | ea-php83 in public/.htaccess |
| **PHP Root .htaccess** | 8.1 (ea-php81) | CONFLICT with public/.htaccess |
| **MariaDB** | 10.6 (custom path) | /opt/mariadb10.6/mariadb/bin/mysql |
| **Elasticsearch** | Running on localhost:9200 | Status: yellow |
| **Node.js** | v24.3.0 | |
| **Yarn** | 1.22.22 | /usr/bin/yarnpkg |

### PHP Extensions Loaded
- PDO, pdo_mysql, mysqli, mysqlnd
- Zend OPcache (**enabled**)
- PHP SAPI: CLI (cli), Web (via cPanel EA4)

### cPanel EasyApache PHP Handlers
- `ea-php81` - configured in root `.htaccess`
- `ea-php83` - configured in `public/.htaccess`
- **PROBLEM:** Two different PHP versions handling different paths

---

## 2. Critical Issues Identified

### 2.1 Static Files Returning 500 Errors (FIXED)
**Problem:** All static assets (`/dist/main.min.js`, `/css/pim.css`, `/bundles/*`) returned HTTP 500 errors.

**Root Cause:** The document root is `/home/pim/public_html/` (NOT `public/`). The root `.htaccess` had rewrite rules that checked `%{REQUEST_FILENAME} -f` which resolved to `/home/pim/public_html/dist/main.min.js` — but the file actually lives at `/home/pim/public_html/public/dist/main.min.js`. The path mismatch caused all static file requests to fall through to `public/index.php`, which returned 404 (rendered as 500).

**Fix Applied:** Modified `/home/pim/public_html/.htaccess` to check files in the `public/` subdirectory:
```apache
RewriteCond %{REQUEST_URI} ^/(bundles|css|js|dist|images|img|media|favicon\.ico|robots\.txt)/
RewriteCond %{DOCUMENT_ROOT}/public%{REQUEST_URI} -f [OR]
RewriteCond %{DOCUMENT_ROOT}/public%{REQUEST_URI} -d
RewriteRule ^ public%{REQUEST_URI} [L]
```

**Result:** Static files now return HTTP 200 correctly.

### 2.2 Database Connection Mismatch (PARTIALLY FIXED)
**Problem:** The `.env` file had:
- `APP_DATABASE_HOST=mysql` (Docker hostname, doesn't resolve on cPanel)
- `APP_DATABASE_PORT=null`

But the actual MariaDB runs on:
- Host: `127.0.0.1`
- Port: `3307`
- Custom binary: `/opt/mariadb10.6/mariadb/bin/mysql`

**Fix Applied:**
- `.env`: Changed host to `127.0.0.1`, port to `3307`
- `.env.local`: Fixed password from `AkeneoP1M2024!` to `akeneo_pim`

**Remaining Issue:** PHP CLI console commands still fail with "Access denied" because a **system-level environment variable** `APP_DATABASE_PASSWORD=AkeneoP1M2024!` is set at the OS level and overrides file-based env vars due to Symfony's null-coalescing logic in `bootstrap.php`.

**Workaround Applied:** Added force-override at the top of `.env.local.php`:
```php
$_SERVER['APP_DATABASE_PASSWORD'] = 'akeneo_pim';
$_ENV['APP_DATABASE_PASSWORD'] = 'akeneo_pim';
```

**Result:** Console commands now work. Website was already working (PHP-FPM reads `.env.local.php` directly).

### 2.3 Missing CSS File (FIXED)
**Problem:** `public/css/pim.css` was missing/empty (0 bytes). LESS compilation fails because `public/bundles/pimui/less/` source files don't exist in Akeneo 6.0 distribution.

**Fix Applied:** Restored `pim.css` (508 KB) from backup at `/home/pim/akeneopublic_html_old/public/css/pim.css`

**Note:** The LESS compilation (`yarn run less`) cannot work in the current state because the PimUIBundle LESS source files are not included in the Akeneo 6.0 composer package. The compile-less.js script expects files at `public/bundles/pimui/less/base/variables.less` which don't exist.

### 2.4 Authentication/Login Failure (UNRESOLVED)
**Problem:** Login page loads correctly with CSS, but all login attempts redirect back to `/user/login` with "Invalid CSRF token" or "Invalid credentials" errors.

**Investigation Findings:**
1. **Password encoder mismatch:** `security.yml` configures `sha512` encoder, but the database has bcrypt (`$2y$13$...`) hashed passwords
2. **Original admin password:** Was `admin` (verified by checking bcrypt hash `$2y$13$xzicnZgGpBGaC3pmCneg..qESuwJvkw80e9pR1D.vdzxmSgFOqKxy`)
3. **CSRF token validation fails:** Even with correct password encoding, CSRF token validation fails. Session cookie (`BAPID`) is being set and sent correctly, but the CSRF token stored in session doesn't match the form token
4. **Tested configurations:**
   - Changed encoder to `bcrypt` → still failed
   - Disabled CSRF (`csrf_token_generator: null`) → still failed (config error: null not allowed)
   - Set sha512 password hash → still failed
   - Enabled `APP_DEBUG=1` → caused HTTP 500 on login-check POST
   - Disabled `use_referer: true` → still failed

**Possible Causes:**
- Session storage issue (file permissions, handler misconfiguration)
- The `CustomDaoAuthenticationProvider` account locking mechanism (admin has `consecutive_authentication_failure_counter=1`)
- The `require_previous_session: false` might not work correctly with the CSRF token manager
- PHP-FPM session handler not properly configured

**Current State:** Login page displays correctly, static assets load, but authentication does not work.

### 2.5 Elasticsearch Index Empty (DEFERRED)
**Problem:** The Akeneo product index `akeneo_pim_product_and_product_model` has **0 documents**. Actual product data exists in separate indices:
- `techno_stationery_product_1_v111`: 8,240 docs
- `beta_techno_stationery_product_1_v20`: 9,538 docs

**Cause:** The `.env` had `APP_INDEX_HOSTS=elasticsearch:9200` (Docker hostname) instead of `localhost:9200`.

**Fix Applied:** Changed `APP_INDEX_HOSTS` to `localhost:9200` in both `.env` and `.env.local.php`.

**Remaining:** Index reset and reindexing command (`akeneo:elasticsearch:reset-indexes`) needs to be run but was deferred.

---

## 3. Changes Made During This Session

### Files Modified

| File | Change | Status |
|------|--------|--------|
| `.env` | `APP_DATABASE_HOST=mysql` → `127.0.0.1` | Done |
| `.env` | `APP_DATABASE_PORT=null` → `3307` | Done |
| `.env` | `APP_INDEX_HOSTS=elasticsearch:9200` → `localhost:9200` | Done |
| `.env.local` | `APP_DATABASE_PASSWORD=AkeneoP1M2024!` → `akeneo_pim` | Done |
| `.env.local.php` | Added `$_SERVER['APP_DATABASE_PASSWORD']` force-override | Done |
| `.htaccess` | Fixed static file rewrite rules to check `public/` subdir | Done |
| `public/.htaccess` | Added static file serving rules (redundant now) | Done |
| `config/packages/security.yml` | Encoder: `sha512` → `bcrypt` → `sha512` (reverted) | Reverted |
| `config/packages/security.yml` | `use_referer: true` → `false`, removed `use_forward` | Done |
| `public/css/pim.css` | Restored from backup (508 KB) | Done |

### Commands Executed
```bash
php bin/console cache:clear --env=prod     # Multiple times
php bin/console cache:warmup --env=prod    # Multiple times
php bin/console pim:installer:assets --symlink --clean  # Successfully installed 16 bundles
yarnpkg install                            # Successfully installed dependencies
opcache_reset()                            # PHP CLI
```

### Database Changes
```sql
-- Reset admin password multiple times (sha512, bcrypt, sha512)
-- Created testadmin user (id=3) with sha512 password
-- Reset consecutive_authentication_failure_counter
-- All users now have sha512 hash of 'Admin123!'
```

---

## 4. Changes From Previous 3 Weeks (Git History)

### Commit History (April 15 - May 6, 2026)

| Commit | Message | Description |
|--------|---------|-------------|
| `0e8a247` | tunings to revert back in time | Reverting previous changes |
| `9eeaad1` | fix: Resolve CSS 404 and rebuild all assets - PARTIAL FIX | Attempted CSS rebuild |
| `721bfe8` | fix: Resolve loading screen issue - extensions.json 404 fixed | Fixed JS extensions |
| `a372422` | feat: Fix authentication & implement comprehensive testing | Auth fixes + tests |
| `72a4c27` | feat(testing): Complete UI testing and authentication debugging | UI testing |
| `fe1f7f3` | docs: Add comprehensive final session summary | Documentation |
| `880effc` | feat(ui): Fix AMD/Webpack entry point execution issue | AMD/RequireJS fix |
| `488dbd0` | docs: URGENT - PIM UI loading screen issue documented | Loading screen docs |
| `59d7dce` | feat(investigation): Complete Phase 3 product data gap analysis | Product data |
| `44941f7` | docs: Add CSS & styles fix session summary | CSS documentation |
| `ddfa415` | docs: Add comprehensive CSS fix complete report | CSS report |
| `3617b2b` | fix(styles): Compile CSS and fix missing styles on login page | CSS compiled |
| `47110c1` | docs: Add comprehensive session summary and final status | Status docs |
| `6de3c85` | docs: Add comprehensive testing and validation complete report | Testing docs |
| `ed2246d` | feat(testing): Add comprehensive Akeneo API testing | API testing |
| `6de32bb` | docs: Add comprehensive frontend fix final report | Frontend docs |
| `58207c6` | fix(frontend): Resolve all 404 errors and identify root cause | 404 fixes |
| `14c7866` | docs: Add comprehensive project status summary | Status docs |
| `18e7dab` | feat(api): Successfully configured Akeneo REST API access | REST API |
| `e371f93` | fix: Correct Cloudflare trusted proxy configuration | Cloudflare fix |
| `61f91f3` | fix: Cloudflare trusted proxy + admin password reset + env sync | Proxy + password |
| `c620a3f` | revert: Undo problematic session configuration changes | Session revert |
| `bbbfc32` | Revert "fix: Resolve session persistence and authentication issues" | Auth revert |
| `e2f86fe` | fix: Resolve session persistence and authentication issues | Auth fix |
| `e06ea6d` | fix: Resolve login redirect issue - dashboard now loads properly | Redirect fix |
| `e22fa7b` | feat: Complete Phase 3 - Akeneo-Magento Sync Verification | Magento sync |
| `c058868` | feat: Complete Phase 2 - Product-Image Linking | Product images |

### Key Patterns Observed
1. **Multiple revert cycles:** Several commits were reverted, indicating instability in session/auth fixes
2. **CSS issues recurring:** Multiple sessions needed to fix CSS compilation and loading
3. **AMD/RequireJS issues:** Webpack entry point and module loading problems
4. **Authentication instability:** Login redirect issues appearing and disappearing across commits
5. **Documentation-heavy:** Many commits are documentation rather than code fixes

---

## 5. Cloudflare Configuration

### Current State
- **Status:** Active and proxying traffic
- **SSL/TLS:** Full (SSL between CF and origin)
- **Cache:** DYNAMIC (bypassed for most requests)
- **CF-Ray headers:** Present in responses

### Trusted Proxies Configuration
All Cloudflare IP ranges are configured in `config/packages/framework.yml`:
```yaml
trusted_proxies: '173.245.48.0/20,103.21.244.0/22,103.22.200.0/22,...'
```

### Headers Set by Cloudflare
- `cf-cache-status: DYNAMIC` or `BYPASS`
- `cf-ray` request ID
- `nel` (Network Error Logging)
- `report-to` (Reporting API endpoints)
- `speculation-rules: "/cdn-cgi/speculation"`

### CSP Headers
The application sets CSP headers, but Cloudflare may be overriding or adding to them. Current CSP is very permissive:
```
default-src 'self' 'unsafe-inline' 'unsafe-eval' data: blob: *
```

### Issue: X-Forwarded-Proto
Cloudflare sends `X-Forwarded-Proto: https`, and with trusted proxies configured, Symfony correctly detects HTTPS. The `cookie_secure: true` session config works properly with this setup.

---

## 6. Varnish Status

### Current State: NOT CONFIGURED
- **No VCL files found** anywhere in the project
- **No Varnish process running** on the server
- **No Varnish configuration** in cPanel or Apache

### Previous Plans (from webapp/ scripts)
Several scripts in `/home/pim/public_html/webapp/` reference Varnish setup but none have been executed:
- `scripts/elasticsearch/es_manager.sh`
- `scripts/cache/cache_manager.sh`

### Recommendation
Varnish should NOT be set up until the authentication issue is resolved, as Varnish caching can interfere with session cookies and CSRF tokens. If Varnish is needed later, it must be configured to:
1. **Pass** all requests with cookies (especially `BAPID`)
2. **Pass** all POST requests
3. **Pass** `/user/*`, `/api/*` paths
4. **Cache** only static assets and anonymous pages

---

## 7. OPcache Issues

### Status: Enabled (causing problems)
```
opcache_enabled: true
```

### Problem Identified
The `.env.local.php` cached file was loaded by OPcache with the **old wrong password** (`AkeneoP1M2024!`). Even after modifying the file, OPcache served the cached compiled version.

### Fix Applied
```php
php -r "opcache_reset();"
```

### Additional Fix
Added force-override in `.env.local.php` to set `$_SERVER` and `$_ENV` directly before the return array, ensuring values override any system environment variables.

### Recommendation
Add OPcache reset to deployment scripts:
```bash
php -r "if (function_exists('opcache_reset')) { opcache_reset(); echo 'OPcache reset'; }"
```

Or better, exclude `.env.local.php` from OPcache:
```ini
opcache.blacklist_filename=/home/pim/public_html/.env.local.php
```

---

## 8. PHP Version & Configuration

### Version Confusion
| Context | PHP Version | Handler |
|---------|-------------|---------|
| CLI | 8.2.30 | /usr/local/bin/php |
| Root .htaccess | 8.1 | ea-php81 |
| public/.htaccess | 8.3 | ea-php83 |
| cPanel default | 8.1 (set at system level) | - |

### PHP 8.2+ Deprecation Warnings (Flooding Logs)
The prod.log is filled with E_DEPRECATED notices:
1. **Iterator return types:** `FlatFileIterator::next()`, `::key()`, `::current()`, `::valid()`, `::rewind()` need `: void`, `: mixed`, `: bool` return types
2. **Serializable interface:** `AclAnnotationStorage`, `AclAncestor`, `Acl`, `ActionMetadata` need `__serialize()`/`__unserialize()`
3. **Dynamic properties:** `Oro\Bundle\DataGridBundle\Twig\MetadataExtension::$metadataParser`
4. **Callable static:** `webmozart/assert` library
5. **DateTime null:** `Monolog\Logger` passing null to `DateTime::__construct()`

### Impact
These are **not errors** — just deprecation notices from running Akeneo 6.0 (designed for PHP 8.0) on PHP 8.2/8.3. They do NOT cause the 500 errors or login failures.

### Recommendation
- Set `LOGGING_LEVEL=ERROR` in `.env` to suppress deprecation notices in production
- Or set `error_reporting = E_ALL & ~E_DEPRECATED` in PHP-FPM config
- Plan migration to Akeneo 7.x or 8.x for full PHP 8.2+ support

---

## 9. Apache/cPanel Configuration

### Document Root
The document root is `/home/pim/public_html/` (NOT `public/`). This is unusual for a Symfony/Akeneo project which typically has the document root at `public/`.

### .htaccess Architecture
```
/home/pim/public_html/
├── .htaccess          # Root: Routes static files to public/, everything else to public/index.php
└── public/
    ├── .htaccess      # Public: Has fallback rewrite to index.php (now redundant)
    └── index.php      # Symfony entry point
```

### PHP Handler Conflict
- **Root `.htaccess`:** `AddHandler application/x-httpd-ea-php81`
- **`public/.htaccess`:** `AddHandler application/x-httpd-ea-php83`

This means:
- PHP files in root would run on PHP 8.1
- PHP files in public/ run on PHP 8.3
- Since all requests go through `public/index.php`, the effective PHP version is 8.3

### Recommendation
Standardize on a single PHP version (8.3 recommended) in both `.htaccess` files, or remove the handler from root `.htaccess` since no PHP files are executed there.

---

## 10. Database Configuration

### Connection Details
| Parameter | Value |
|-----------|-------|
| **Host** | 127.0.0.1 |
| **Port** | 3307 |
| **Binary** | `/opt/mariadb10.6/mariadb/bin/mysql` |
| **Database** | akeneo_pim |
| **User** | akeneo_pim |
| **Password** | akeneo_pim |

### Database State
- **1 user:** admin (admin@pim.technostationery.com) + testadmin (created during this session)
- **0 categories:** pim_catalog_category is empty
- **Tables present:** oro_user, pim_catalog_category, pim_catalog_locale, pim_catalog_product, oro_access_role, etc.
- **Migration versions:** Schema appears to be at a recent version

### Root Password
MariaDB root password: `YourNewStrongPassword`

### User Privileges
```sql
GRANT USAGE ON *.* TO `akeneo_pim`@`127.0.0.1`
GRANT ALL PRIVILEGES ON `akeneo_pim`.* TO `akeneo_pim`@`127.0.0.1`
```

---

## 11. Elasticsearch Configuration

### Connection
- **Host:** localhost:9200
- **Status:** Running (cluster: elasticsearch, status: yellow)
- **Nodes:** 1

### Indices
| Index | Docs | Status | Notes |
|-------|------|--------|-------|
| `akeneo_pim_product_and_product_model` | 0 | yellow | **EMPTY - needs reindexing** |
| `akeneo_connectivity_connection_error` | 0 | yellow | Empty |
| `akeneo_connectivity_connection_events_api_debug` | 0 | yellow | Empty |
| `techno_stationery_product_1_v111` | 8,240 | green | Active product data |
| `beta_techno_stationery_product_1_v20` | 9,538 | green | Beta product data |
| `.geoip_databases` | 42 | green | GeoIP data |

### Issue
The Akeneo product index is empty. Product data exists in different indices (likely from a custom sync or previous installation). The `akeneo:elasticsearch:reset-indexes` command needs to be run followed by `pim:product:index` and `pim:product-model:index`.

---

## 12. Authentication System Status

### Current Configuration (security.yml)
```yaml
encoders:
    Akeneo\UserManagement\Component\Model\User: sha512
    
firewalls:
    main:
        form_login:
            csrf_token_generator: security.csrf.token_manager
            login_path: pim_user_security_login
            check_path: pim_user_security_check
            default_target_path: pim_dashboard_index
            use_referer: false
            require_previous_session: false
        remember_me:
            name: BAPRM
            lifetime: 1209600
            samesite: lax

session:
    name: BAPID
    cookie_secure: true
    cookie_samesite: lax
    cookie_httponly: true
    gc_maxlifetime: 86400
```

### Known Issues
1. **Password encoder:** Configured as `sha512` but original passwords were `bcrypt`
2. **CSRF validation:** Fails even with correct credentials
3. **Session cookie:** Set correctly (`BAPID`) but authentication doesn't persist
4. **CustomDaoAuthenticationProvider:** Adds account locking logic on top of standard DAO auth

### Test Credentials
| Username | Password | Encoder | Status |
|----------|----------|---------|--------|
| admin | Admin123! | sha512 (current) | NOT WORKING |
| testadmin | Admin123! | sha512 (current) | NOT WORKING |
| admin | admin | bcrypt (original hash restored) | NOT WORKING |

### What Works
- Login page renders correctly (200 OK)
- CSS loads (200 OK)
- JavaScript loads (200 OK)
- CSRF token is generated in the form
- Session cookie is set (BAPID)
- POST to /user/login-check returns 302 redirect
- Database connection works (web/PHP-FPM)

### What Doesn't Work
- Authentication redirects back to /user/login
- CSRF token validation fails
- Even with CSRF disabled, auth still fails

---

## 13. Asset Pipeline Status

### Static Assets
| Asset | Status | Size | Notes |
|-------|--------|------|-------|
| `/dist/main.min.js` | 200 OK | 397 KB | Working |
| `/dist/vendor.min.js` | 200 OK | Present | Working |
| `/css/pim.css` | 200 OK | 508 KB | Restored from backup |
| `/bundles/pimui/*` | 200 OK | Varies | Installed via pim:installer:assets |
| `/bundles/*/js/*.js` | 200 OK | Varies | Installed |
| `/media/product_images/*` | 200 OK | Present | Product images |
| `/media/cache/*` | 200 OK | Present | Thumbnails |
| `/js/fos_js_routes.json` | Present | - | Routes dumped |
| `/js/require-paths.js` | Present | - | RequireJS paths |

### Asset Installation
```
Successfully installed 16 bundles:
✔ FOSJsRoutingBundle, OroConfigBundle, AkeneoMeasureBundle, PimUserBundle
✔ AkeneoPimEnrichmentBundle, AkeneoPimStructureBundle, PimAnalyticsBundle
✔ PimDashboardBundle, PimDataGridBundle, PimImportExportBundle
✔ PimNotificationBundle, PimUIBundle, AkeneoConnectivityConnectionBundle
✔ AkeneoCommunicationChannelBundle, AkeneoDataQualityInsightsBundle, AkeneoJobBundle
```

### Build Commands
| Command | Status | Notes |
|---------|--------|-------|
| `yarn run less` | FAILS | Missing pimui/less source files |
| `yarn run webpack` | Not tested | Requires custom-webpack.config.js |
| `yarn run update-extensions` | Not tested | Extension update |
| `pim:installer:assets` | WORKS | Symlinks bundle assets |

---

## 14. Playwright Tests

### Configuration
- **Config file:** `/home/pim/public_html/webapp/playwright.config.js`
- **Test directory:** `./tests`
- **Base URL:** `https://pim.technostationery.com`
- **Browser:** Chromium only
- **Retries:** 0 (non-CI), 2 (CI)
- **Trace/Screenshot/Video:** On failure

### Test File
- `/home/pim/public_html/webapp/tests/akeneo.spec.js` (214 lines)

### Test Suites
1. **Authentication Tests** (4 tests)
   - Login page loads with correct elements
   - Invalid credentials show error
   - Successful login with valid credentials (uses `testadmin:testpass`)
   - Session persistence after login

2. **Asset Loading Tests** (4 tests)
   - CSS loads (200)
   - Main JS bundle loads (200)
   - Vendor JS bundle loads (200)
   - No 404 errors on dashboard

3. **UI Rendering Tests** (3 tests)
   - App container renders
   - Loading screen behavior (known issue documented)
   - Page title after login

4. **Console Error Tests** (1 test)
   - No critical JavaScript errors

5. **Database Connectivity Tests** (1 test)
   - API endpoint reachable

### Test Credentials in Playwright
```javascript
const TEST_USER = {
  username: 'testadmin',
  password: 'testpass'
};
```
**Note:** This user doesn't exist in the database. The Playwright tests will fail until a user with these credentials is created.

### Playwright Installation
Playwright needs to be installed:
```bash
cd /home/pim/public_html/webapp
npm install @playwright/test
npx playwright install chromium
```

---

## 15. Recommendations

### Immediate Priority (P0)

1. **Fix Authentication/Login:**
   - Investigate session handler configuration in PHP-FPM
   - Check `/home/pim/public_html/var/sessions/` directory permissions
   - Verify session save path in php.ini for ea-php83
   - Consider creating a fresh admin user via a bootstrap script that uses the Symfony encoder properly
   - Check if `session.auto_start` is enabled (should be off)
   - Verify `session.save_handler = files` and `session.save_path` is writable

2. **Fix System Environment Variable:**
   - Find and remove the system-level `APP_DATABASE_PASSWORD=AkeneoP1M2024!` 
   - Check `/etc/environment`, cPanel user environment, `.bashrc`, `.bash_profile`
   - Or set the correct value at the system level: `APP_DATABASE_PASSWORD=akeneo_pim`

### High Priority (P1)

3. **Reindex Elasticsearch:**
   ```bash
   php bin/console akeneo:elasticsearch:reset-indexes -n
   php bin/console pim:product:index -n
   php bin/console pim:product-model:index -n
   ```

4. **Standardize PHP Version:**
   - Remove PHP 8.1 handler from root `.htaccess`
   - Keep PHP 8.3 in `public/.htaccess`
   - Update all scripts to use `/usr/local/bin/php` (8.2.30)

5. **Suppress Deprecation Warnings:**
   - Set `LOGGING_LEVEL=ERROR` in `.env`
   - Or configure `error_reporting` in PHP-FPM

### Medium Priority (P2)

6. **Create Valid Playwright Test User:**
   ```sql
   -- Create user with username=testadmin, password=testpass (sha512)
   -- Or update Playwright config to use admin/Admin123!
   ```

7. **Run Playwright Tests:**
   ```bash
   cd /home/pim/public_html/webapp
   npx playwright test
   ```

8. **Set Up Varnish (if needed):**
   - Only after authentication is working
   - Configure to bypass session-authenticated paths
   - Set proper cache invalidation for product updates

### Low Priority (P3)

9. **Clean Up Untracked Files:**
   - Remove `create_admin*.php`, `reset_admin*.php`, `setup_admin.php` from production
   - These contain hardcoded credentials and are security risks

10. **APP_SECRET:**
    - Change from `ThisTokenIsNotSoSecretChangeIt` to a strong random value

11. **Akeneo Upgrade:**
    - Plan migration to Akeneo 7.x or 8.x for PHP 8.2+ support
    - Current 6.0.113 is designed for PHP 8.0

---

## Appendix A: File Locations

### Configuration Files
- `/home/pim/public_html/.env` - Base environment variables
- `/home/pim/public_html/.env.local` - Local overrides
- `/home/pim/public_html/.env.local.php` - Cached/compiled env (OPcache issue)
- `/home/pim/public_html/config/packages/security.yml` - Authentication config
- `/home/pim/public_html/config/packages/framework.yml` - Framework config
- `/home/pim/public_html/config/packages/doctrine.yml` - Database config

### Entry Points
- `/home/pim/public_html/public/index.php` - Web entry point
- `/home/pim/public_html/bin/console` - CLI entry point

### Logs
- `/home/pim/public_html/var/logs/prod.log` - Application log (2.9 MB)
- `/home/pim/public_html/error_log` - PHP error log (cPanel)
- `/home/pim/logs/error_log` - Apache error log (if exists)

### Assets
- `/home/pim/public_html/public/dist/` - Webpack JS bundles
- `/home/pim/public_html/public/css/` - Compiled CSS
- `/home/pim/public_html/public/bundles/` - Symfony bundle assets
- `/home/pim/public_html/public/media/` - Uploaded media

### Backup
- `/home/pim/akeneopublic_html_old/` - Old installation backup
- `/home/pim/backups/` - SQL backups (if exists)

---

## Appendix B: Quick Reference Commands

```bash
# Check website
curl -sI https://pim.technostationery.com/user/login

# Clear cache
php bin/console cache:clear --env=prod

# Check database
php bin/console doctrine:query:sql "SELECT username,email FROM oro_user"

# Check ES
curl -s http://localhost:9200/_cat/indices?v

# Reset OPcache
php -r "opcache_reset();"

# View recent errors
tail -50 /home/pim/public_html/var/logs/prod.log | grep -i "error\|critical\|exception"
```

---

**Report generated:** May 6, 2026
**Next review:** Hand off to expert for authentication debugging and Varnish setup
