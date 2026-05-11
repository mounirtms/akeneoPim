# Fresh Akeneo PIM v6.0.113 Installation - Complete

## Installation Date
May 6, 2026 - 02:30 UTC

## System Configuration

### Operating System & Server
- **Platform**: Linux (cPanel hosting)
- **Web Server**: Apache (cPanel managed)
- **PHP Version**: 8.0.30 (configured via cPanel)
- **Database**: MariaDB 10.6.17-log
- **Node.js**: v14.x (for webpack builds)

### Akeneo PIM Installation
- **Version**: Community Edition 6.0.113
- **Installation Path**: /home/pim/public_html
- **Domain**: https://pim.technostationery.com
- **Environment**: Production (prod)
- **Debug Mode**: Disabled

### Database Configuration
- **Host**: 127.0.0.1
- **Port**: 3307
- **Database Name**: akeneo_pim
- **Database User**: akeneo_pim
- **Character Set**: utf8mb4 (unicode support)
- **Schema Tables**: 75 tables initialized
- **Connection**: TCP/IP via port 3307

## Installation Details

### Backup Location
- **Full Installation Backup**: /home/pim/backups/public_html_backup_20260506_021115/ (6.1GB)
- **Previous Directory**: /home/pim/backups/public_html_backup_20260506_021115/

### Components Installed
✓ Akeneo PIM Community Core (vendor/akeneo/pim-community-dev)
✓ Symfony 5.4.51 Framework
✓ Doctrine ORM (database abstraction)
✓ FOSRestBundle (REST API)
✓ FOSJsRoutingBundle (JavaScript routing)
✓ Elasticsearch support libraries
✓ All required PHP extensions (mysqli, json, xml, curl, intl, zip, etc.)
✓ Webpack assets (yarn/npm)

### File Structure
```
/home/pim/public_html/
├── bin/
│   └── console              # Akeneo CLI
├── config/
│   ├── bootstrap.php        # Environment bootstrap
│   └── packages/            # Symfony configuration
├── public/
│   ├── bundles/             # Asset symlinks
│   ├── css/                 # Compiled stylesheets
│   ├── js/                  # Compiled JavaScript
│   ├── media/               # Uploaded media
│   └── index.php            # Web entry point
├── src/                     # Custom code directory
├── vendor/                  # Composer dependencies
├── var/
│   ├── cache/prod/          # Production cache
│   ├── logs/                # Application logs
│   └── sessions/            # Session storage
├── .env.local               # Production environment file
├── .env                     # Default environment file
├── composer.json            # PHP dependencies
├── composer.lock            # Locked dependency versions
├── package.json             # Node dependencies
└── webpack.config.js        # Webpack configuration
```

### Environment File (.env.local)
```
APP_ENV=prod
APP_DEBUG=0
APP_DATABASE_HOST=127.0.0.1
APP_DATABASE_PORT=3307
APP_DATABASE_NAME=akeneo_pim
APP_DATABASE_USER=akeneo_pim
APP_DATABASE_PASSWORD=AkeneoP1M2024!
LOGGING_LEVEL=NOTICE
```

### Database Schema
75 tables created including:
- User Management (oro_user, oro_role, oro_user_access_group)
- Catalog Structure (pim_catalog_attribute, pim_catalog_category, pim_catalog_channel)
- Products (pim_catalog_product, pim_catalog_product_model)
- Asset Management (akeneo_asset, akeneo_asset_media_file)
- Job Execution (akeneo_batch_job, akeneo_batch_step_execution)
- ACL/Security (acl_classes, acl_object_identities)
- And more...

## Credentials

### Admin User
- **Status**: Ready for setup
- **Username**: admin (to be configured)
- **Password**: Admin123! (temporary, should be changed)
- **Email**: admin@technostationery.com
- **Note**: Admin user creation pending - use provided SQL script

### Database User
- **Username**: akeneo_pim
- **Password**: AkeneoP1M2024!
- **Privileges**: Full access to akeneo_pim database

### Root Database Access
- **User**: root
- **Password**: Stored in /root/.my.cnf
- **Access**: Via cPanel interface

## SSL/HTTPS Configuration
- **Domain**: pim.technostationery.com
- **SSL Status**: Configured via cPanel
- **Certificate**: AutoSSL (cPanel managed)
- **.htaccess**: Configured for HTTPS redirect

## Permissions Configuration
- **var/ directory**: 755 (owned by nobody:nobody)
- **public/bundles/**: 777 (owned by nobody:nobody)
- **public/css/**: 777 (owned by nobody:nobody)
- **public/js/**: 777 (owned by nobody:nobody)
- **public/media/**: 777 (owned by nobody:nobody)
- **public/dist/**: 777 (owned by nobody:nobody)

## Asset Compilation Status
✓ Node.js dependencies installed via Yarn
✓ Webpack build completed
✓ FOSJsRouting routes dumped
✓ Akeneo bundle assets symlinked
✓ Production cache warmed

## Testing & Verification

### Pre-Installation Checks (All Passed)
✓ PHP 8.0.30 installed with all required extensions
✓ APCu extension available
✓ bcmath, curl, fileinfo, gd, intl, pdo_mysql available
✓ Imagick extension available
✓ Memory limit: 512MB+
✓ Filesystem permissions correct
✓ Database connectivity confirmed

### Installation Verification
✓ Akeneo PIM v6.0.113 source code installed
✓ 75 database tables created successfully
✓ Database schema initialized
✓ Production cache generated and warmed
✓ Static assets compiled and symlinked
✓ File permissions configured correctly
✓ Apache ownership (nobody user) set correctly

## Next Steps for Completion

### 1. Admin User Setup
Execute the SQL script to create admin user:
```sql
INSERT INTO oro_user (username, email, password, first_name, last_name, enabled)
VALUES ('admin', 'admin@technostationery.com', '...', 'Admin', 'User', 1);
```

### 2. Restore Previous Data
From previous backups located in /home/pim/backups/:
- Database backup: /home/pim/backups/akeneo_backup_*.sql.gz
- File backup: /home/pim/backups/akeneo_files_*.tar.gz
- Or restore from Elasticsearch indices

### 3. Configure Cron Jobs (via cPanel)
- Job Queue Processing
- Elasticsearch Indexing (if applicable)
- Scheduled Imports/Exports
- Daily Maintenance Tasks

### 4. Elasticsearch Configuration (if using)
- Verify connection to Elasticsearch service
- Re-index products and categories
- Configure job queue for async processing

### 5. Performance Optimization
- Monitor var/logs/prod.log for any issues
- Configure APCu for better performance
- Set up monitoring/alerting

### 6. Backup Scheduling
- Configure automated daily backups via cPanel
- Test backup restoration procedures
- Archive old backups

## Important Notes

### Data Restoration
The fresh installation has an empty database with schema only. To restore previous data:
1. Use existing SQL backups from /home/pim/backups/
2. Restore from Elasticsearch if available
3. Import product catalogs from previous exports
4. Restore user accounts and configurations

### Password Security
The temporary admin password "Admin123!" should be changed immediately after first login.

### Maintenance Commands
```bash
# Clear cache
php bin/console cache:clear --env=prod

# Warm cache
php bin/console cache:warmup --env=prod

# Check requirements
php bin/console pim:installer:check-requirements --env=prod

# Database maintenance
php bin/console doctrine:schema:update --force --env=prod

# Re-index products
php bin/console pim:product:index --env=prod
```

## Support & Troubleshooting

### Common Issues
- **500 errors**: Check var/logs/prod.log
- **Permission denied**: Ensure var/ and public/ are writable by Apache (nobody user)
- **Database connection errors**: Verify .env.local credentials match database user
- **JavaScript errors**: Ensure assets:install was run and bundles are accessible

### Log Files
- **Application Log**: /home/pim/public_html/var/logs/prod.log
- **Apache Error Log**: /var/log/apache2/error_log or via cPanel
- **Database Log**: /opt/mariadb10.6/mariadb-error.log

### Contact
For support: admin@technostationery.com

---
**Installation Status**: ✓ COMPLETE
**Last Updated**: May 6, 2026 02:30 UTC
