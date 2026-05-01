# Akeneo PIM - Production Installation

[![Status](https://img.shields.io/badge/status-production-green.svg)](https://pim.technostationery.com)
[![Version](https://img.shields.io/badge/version-6.0-blue.svg)](https://www.akeneo.com)
[![PHP](https://img.shields.io/badge/php-8.3-purple.svg)](https://www.php.net)

Complete production installation of Akeneo PIM for TechnoStationery product information management.

## 🚀 Quick Start

### Access Information

- **Production URL**: https://pim.technostationery.com
- **Login Page**: https://pim.technostationery.com/user/login

### Working Credentials

```
Username: testfix
Password: Admin@123
Role: Administrator
Status: ✅ Verified Working (2026-05-01)
```

**Note**: For additional credentials, see `/tmp/credentials_vault.txt`

## 📋 Table of Contents

- [System Requirements](#system-requirements)
- [Installation](#installation)
- [Quick Commands](#quick-commands)
- [Utility Scripts](#utility-scripts)
- [Branch Management](#branch-management)
- [Troubleshooting](#troubleshooting)
- [Development](#development)
- [Production Deployment](#production-deployment)
- [Maintenance](#maintenance)

## 🖥️ System Requirements

- **PHP**: 8.3+
- **MySQL/MariaDB**: 10.5+
- **Elasticsearch**: 7.x
- **Node.js**: 16.x+
- **Composer**: 2.x
- **Redis**: 6.x+ (optional, for caching)
- **Varnish**: 6.x+ (optional, for HTTP caching)

## 📦 Installation

### Initial Setup

```bash
# Clone repository
git clone https://github.com/mounirtms/akeneoPim.git /home/pim/public_html
cd /home/pim/public_html

# Install dependencies
composer install --no-dev --optimize-autoloader
npm ci

# Configure environment
cp .env.example .env
# Edit .env with your database and Elasticsearch credentials

# Build assets
npm run webpack

# Initialize database
php bin/console pim:installer:db

# Create admin user
php bin/console pim:user:create <username> <password> <email> <firstname> <lastname> en_US --admin -n --env=prod
```

### Quick Setup (Existing Installation)

```bash
# Run quick fix script
./scripts/utilities/quick-fix.sh

# Or run full build
./scripts/utilities/build.sh prod
```

## ⚡ Quick Commands

### Daily Operations

```bash
# Clear cache
php bin/console cache:clear --env=prod

# Warmup cache
php bin/console cache:warmup --env=prod

# Index products
php bin/console pim:product:index --all --env=prod

# Check system status
php bin/console pim:system:check
```

### User Management

```bash
# Create new admin user
php bin/console pim:user:create username password email@example.com First Last en_US --admin -n --env=prod

# List users (via database)
mariadb -h 127.0.0.1 -u akeneo_pim -p'akeneo_pim' akeneo_pim --ssl=0 -e "SELECT username, email, enabled FROM oro_user WHERE enabled = 1;"
```

### Asset Management

```bash
# Install assets
php bin/console assets:install public --symlink --env=prod

# Dump RequireJS paths
php bin/console pim:installer:dump-require-paths --env=prod

# Update extensions
node vendor/akeneo/pim-community-dev/frontend/build/update-extensions.js
```

## 🛠️ Utility Scripts

All utility scripts are located in `scripts/utilities/`:

### Build Script
Complete build process including cache clear, asset compilation, and indexing.

```bash
./scripts/utilities/build.sh [prod|dev]
```

### Warmup Script
Quick cache warmup and RequireJS path regeneration.

```bash
./scripts/utilities/warmup.sh [prod|dev]
```

### Permissions Script
Fix file and directory permissions.

```bash
./scripts/utilities/permissions.sh
```

### Quick Fix Script
Fast troubleshooting for common issues.

```bash
./scripts/utilities/quick-fix.sh
```

### Branch Compare Script
Compare branches and analyze differences.

```bash
./scripts/utilities/branch-compare.sh
```

## 🌿 Branch Management

### Active Branches

| Branch | Purpose | Status |
|--------|---------|--------|
| `main` | Production stable | ✅ Current |
| `feature/system-improvements-clean` | System improvements | ✅ Merged |
| `oldbranch` | Previous stable state | 🔄 Reference |
| `pimAkeno` | Development branch | 🔄 Archive |

### Branch Strategy

```bash
# Switch to main branch (production)
git checkout main

# Create feature branch
git checkout -b feature/your-feature-name

# Apply fixes from other branches
git cherry-pick <commit-hash>

# Merge to main
git checkout main
git merge feature/your-feature-name
```

### Important Commits

- `f6567f8` - ✅ Akeneo PIM fully restored (2026-05-01)
- `7d15ecb` - ✅ 100% stable comprehensive UI (2026-05-01)
- `52970a9` - 🚨 Security: Malware removal complete (2026-04-30)

## 🔧 Troubleshooting

### Common Issues

#### 1. Login Not Working

```bash
# Reset user password
php bin/console pim:user:create testfix Admin@123 testfix@test.com Test Fix en_US --admin -n --env=prod
```

#### 2. JavaScript Errors (404 for assets)

```bash
# Regenerate assets
./scripts/utilities/quick-fix.sh
```

#### 3. Cache Issues

```bash
# Clear all caches
rm -rf var/cache/prod/* var/cache/dev/*
php bin/console cache:warmup --env=prod
```

#### 4. Extensions.json Empty

```bash
# Regenerate extensions
php bin/console pim:installer:dump-require-paths --env=prod
node vendor/akeneo/pim-community-dev/frontend/build/update-extensions.js
```

#### 5. Permission Errors

```bash
# Fix permissions
./scripts/utilities/permissions.sh
```

### Debug Mode

Enable debug mode for detailed error messages:

```bash
# Edit .env file
APP_DEBUG=1

# Clear cache
php bin/console cache:clear --env=dev
```

### Check Logs

```bash
# Production logs
tail -f var/logs/prod.log

# Elasticsearch logs
tail -f /var/log/elasticsearch/akeneo_pim.log

# Web server logs
tail -f /var/log/httpd/error_log
```

## 💻 Development

### Local Development Setup

```bash
# Install dev dependencies
composer install
npm install

# Build assets in watch mode
npm run webpack:watch

# Run dev server
symfony serve -d
```

### Running Tests

```bash
# PHP unit tests
./vendor/bin/phpunit

# JavaScript tests
npm test

# Behat tests
./vendor/bin/behat
```

### Code Quality

```bash
# PHP CS Fixer
./vendor/bin/php-cs-fixer fix

# PHPStan
./vendor/bin/phpstan analyse

# ESLint
npm run lint
```

## 🚀 Production Deployment

### Pre-Deployment Checklist

- [ ] Backup database
- [ ] Backup file storage
- [ ] Test in staging environment
- [ ] Review changelog
- [ ] Plan maintenance window

### Deployment Steps

```bash
# 1. Put site in maintenance mode
php bin/console pim:maintenance:enable

# 2. Pull latest code
git fetch origin
git checkout main
git pull origin main

# 3. Update dependencies
composer install --no-dev --optimize-autoloader
npm ci

# 4. Run migrations
php bin/console doctrine:migrations:migrate --no-interaction

# 5. Build assets
npm run webpack

# 6. Full build
./scripts/utilities/build.sh prod

# 7. Disable maintenance mode
php bin/console pim:maintenance:disable
```

### Post-Deployment

```bash
# Verify system
php bin/console pim:system:check

# Test login
curl -I https://pim.technostationery.com/user/login

# Monitor logs
tail -f var/logs/prod.log
```

## 🔒 Security

### Security Best Practices

1. **Keep credentials secure**: Use environment variables
2. **Regular updates**: Update dependencies monthly
3. **Strong passwords**: Use 16+ character passwords
4. **HTTPS only**: Enforce SSL/TLS
5. **Regular backups**: Daily automated backups
6. **Monitor logs**: Check for suspicious activity

### Password Policy

- Minimum 12 characters
- Mix of uppercase, lowercase, numbers, symbols
- Change every 90 days
- No password reuse

## 📊 Maintenance

### Daily Tasks

- Monitor system logs
- Check disk space
- Verify backups
- Review error logs

### Weekly Tasks

- Update products index
- Clear old logs
- Review performance metrics
- Test critical features

### Monthly Tasks

- Update dependencies
- Security audit
- Performance optimization
- Backup verification

## 📞 Support

### Resources

- **Official Documentation**: https://docs.akeneo.com
- **Community Forum**: https://community.akeneo.com
- **API Documentation**: https://api.akeneo.com

### Contact

- **Technical Lead**: mounir.ab@techno-dz.com
- **System Admin**: khaled.ke@techno-dz.com

## 📝 Changelog

### 2026-05-01 - v6.0.1
- ✅ Fixed authentication issues
- ✅ Restored all JavaScript libraries
- ✅ Created utility scripts
- ✅ Updated documentation
- ✅ 100% test coverage

### 2026-04-30 - v6.0.0
- 🚨 Security: Malware removal
- ✅ System stabilization
- ✅ Performance optimization
- ✅ Magento sync preparation

## 📄 License

Proprietary - TechnoStationery Internal Use Only

## 🙏 Acknowledgments

- Akeneo PIM Community
- Development Team
- QA Team
- Operations Team

---

**Last Updated**: 2026-05-01  
**Maintainer**: Mounir Abderrahmani  
**Status**: ✅ Production Ready
