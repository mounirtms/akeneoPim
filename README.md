# Pimcore Installation

This is a Pimcore CMS installation for managing content and products.

## System Overview

- Pimcore v11
- Symfony 7.3
- PHP 8.1+
- MariaDB 10.6

## Initial Setup

1. Clone the repository
2. Run composer install:
   ```
   composer install
   ```
3. Create database:
   ```
   php create_db.php
   ```
4. Import Pimcore schema:
   ```
   php import_pimcore_schema.php
   ```
5. Install Pimcore database:
   ```
   php install_pimcore_db.php
   ```
6. Create admin user:
   ```
   php create_admin_user.php
   ```

## Maintenance Commands

### Clear Cache
```
rm -rf var/cache/*
```

### Rebuild Classes
```
php bin/console pimcore:build:classes --env=prod
```

### Update Dependencies
```
composer update
```

### Fix Permissions
```
# Set file permissions
find . -type f -exec chmod 644 {} \;
find . -type d -exec chmod 755 {} \;

# Set ownership
chown -R pim:nobody .

# Set write permissions for var directories
chmod -R 775 var/classes var/cache var/log var/sessions var/tmp var/installer
chown -R pim:nobody var/classes var/cache var/log var/sessions var/tmp var/installer
```

### Restart Web Server
```
service httpd restart
```

### Switch Environment Mode
```
# Development mode
./switch_mode.sh dev

# Production mode
./switch_mode.sh prod
```

### Database Commands

#### Validate Database Schema
```
php bin/console doctrine:schema:validate --env=prod
```

#### Update Database Schema
```
php bin/console doctrine:schema:update --force --env=prod
```

## Common Issues and Solutions

### Admin Panel Not Loading
1. Check that all installation steps have been completed
2. Clear cache:
   ```
   rm -rf var/cache/*
   ```
3. Rebuild classes:
   ```
   php bin/console pimcore:build:classes --env=prod
   ```
4. Restart web server:
   ```
   service httpd restart
   ```

### Permission Issues
Run the fix permissions commands listed above.

### White Screen After Login
1. Verify database is properly initialized
2. Check that admin user exists:
   ```
   php create_admin_user.php
   ```

## File Locations

- Web root: `/home/pim/public_html/public`
- Configuration: `/home/pim/public_html/config`
- Custom code: `/home/pim/public_html/src`
- Logs: `/home/pim/public_html/var/log`
- Cache: `/home/pim/public_html/var/cache`

## Access

- Frontend: https://your-domain.com
- Admin: https://your-domain.com/admin/login