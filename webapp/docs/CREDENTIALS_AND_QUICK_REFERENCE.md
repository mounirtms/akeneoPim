# Akeneo PIM - Credentials & Quick Reference

## System Access

### PIM Application
- **URL**: https://pim.technostationery.com
- **Environment**: Production (APP_ENV=prod)

### Database
- **Host**: 127.0.0.1
- **Port**: 3307
- **Database**: akeneo_pim
- **User**: root
- **Password**: YourNewStrongPassword
- **Command**: `/opt/mariadb10.6/mariadb/bin/mysql -u root -p'YourNewStrongPassword' -h 127.0.0.1 -P 3307 akeneo_pim`

### Services
- **Elasticsearch**: localhost:9200
- **Node.js**: v24.3.0 (system), v20.20.0 (Akeneo build)
- **PHP**: 8.3.29

## Key Commands

### Cache Management
```bash
cd /home/pim/public_html
php bin/console cache:clear --env=prod
php bin/console cache:warmup --env=prod
```

### Asset Building
```bash
npm run less              # Compile CSS
npm run webpack           # Build JS bundles
npm run update-extensions # Generate extensions.json
php bin/console assets:install --env=prod --symlink
```

### Data Operations
```bash
php bin/console pim:completeness:calculate --env=prod
```

## File Locations

### Application
- **Root**: /home/pim/public_html
- **Logs**: /home/pim/public_html/var/logs/prod.log
- **Cache**: /home/pim/public_html/var/cache/prod/
- **Public**: /home/pim/public_html/public/

### Documentation
- **This Guide**: /home/pim/public_html/webapp/docs/CREDENTIALS_AND_QUICK_REFERENCE.md
- **Deployment**: /home/pim/public_html/webapp/docs/COMPLETE_DEPLOYMENT_GUIDE.md
- **Production Fixes**: /home/pim/public_html/webapp/docs/PRODUCTION_STABILITY_FIX_20260429.md

### Archives
- **Old Audits**: /home/pim/public_html/webapp/archive/2026-04-audits/
- **Old Reports**: /home/pim/public_html/webapp/archive/2026-04-reports/
- **Old Scripts**: /home/pim/public_html/webapp/archive/2026-04-scripts/

## Platform Statistics (as of 2026-04-30)
- **Products**: 9,538
- **Product Models**: 418
- **Categories**: 166
- **Attributes**: 112
- **Families**: 18
- **Channels**: 3

## Recent Fixes Applied (2026-04-29/30)
1. ✅ Fixed ConnectionWithCredentials TypeError
2. ✅ Rebuilt all CSS/JS assets
3. ✅ Fixed webpack chunk conflicts
4. ✅ Fixed category selector import
5. ✅ Fixed completeness calculation errors
6. ✅ Installed bundle symlinks
7. ✅ Generated extensions.json
8. ✅ Fixed file permissions

## Troubleshooting

### CSS/JS Not Loading
```bash
# Rebuild assets
npm run less
npm run webpack
php bin/console assets:install --env=prod --symlink
php bin/console cache:clear --env=prod
```

### 404 Errors on Bundles
```bash
php bin/console assets:install --env=prod --symlink --relative
```

### Completeness Issues
```bash
php bin/console pim:completeness:calculate --env=prod
```

### Check Application Status
```bash
php bin/console --env=prod about
curl -I https://pim.technostationery.com/
```
