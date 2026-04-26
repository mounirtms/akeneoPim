# Akeneo PIM & Magento Beta - Master Credentials Document

**CONFIDENTIAL - Do Not Share**  
**Date**: 2026-04-26  
**Last Updated**: System Audit Phase 1

---

## 🔐 Akeneo PIM Production

### System Access
- **URL**: https://pim.technostationery.com/
- **Environment**: Production (APP_ENV=prod)
- **Version**: Akeneo PIM 6.0 Community Edition

### Database Credentials
- **Host**: 127.0.0.1
- **Port**: 3307
- **Database**: akeneo_pim
- **Username**: akeneo_pim
- **Password**: akeneo_pim
- **Connection**: `mariadb -u akeneo_pim -pakeneo_pim -h 127.0.0.1 -P 3307 --skip-ssl akeneo_pim`

### Akeneo User Accounts

#### Admin Account (Primary)
- **Username**: admin
- **Email**: admin@pim.technostationery.com
- **Role**: Administrator
- **Status**: Active (enabled=1)
- **Purpose**: Primary system administrator

#### Test Admin Account
- **Username**: testadmin
- **Email**: test@test.com
- **Password**: testpass
- **Role**: Administrator
- **Status**: Active (enabled=1)
- **Purpose**: Testing and development

#### API Connector Account
- **Username**: apiconnector
- **Email**: apiconnector@pim.technostationery.com
- **Role**: API/Integration user
- **Status**: Active (enabled=1)
- **Purpose**: API integrations and connectors

#### Team Members
1. **Mounir Abderrahmani**
   - Username: mounir.ab
   - Email: mounir.ab@echno-dz.com (note: typo in DB - should be techno-dz.com)
   - Status: Active

2. **Khaled**
   - Username: khaled.ke
   - Email: khaled.ke@techno-dz.com
   - Status: Active

3. **Salah**
   - Username: salah.cs
   - Email: salah.cs@techno-dz.com
   - Status: Active

4. **Kacem**
   - Username: kacem.ba
   - Email: kacem.ba@techno-dz.com
   - Status: Active

### API Authentication
- **APP_SECRET**: 6567aeaddf1b99216fcea75ff203e656c33c2e042dcb6e1343f93f21a880e2a8
- **REST API Base**: https://pim.technostationery.com/api/rest/v1/
- **OAuth Endpoint**: https://pim.technostationery.com/api/oauth/v1/token
- **Authentication Methods**: 
  - Basic Auth (username:password)
  - OAuth 2.0 Client Credentials
  - OAuth 2.0 Password Grant

---

## 🛒 Magento 2 Beta Instance

### System Access
- **URL**: [TO BE CONFIRMED - Beta URL needed]
- **Admin Panel**: [Beta URL]/admin
- **Environment**: Beta/Testing

### Admin Account (Bot User)
- **Username**: bot
- **Password**: @dM1n$#@2o25B0T
- **Role**: Administrator
- **Purpose**: Automated integration and sync operations

### Notes
- This is the bot/admin user for automated catalog sync
- Credentials confirmed by user
- Will be used for Akeneo-Magento connector

---

## 🔌 Akeneo-Magento Connector Configuration

### Connector Status
- **Status**: TO BE CONFIGURED
- **Type**: REST API based sync
- **Direction**: Akeneo PIM → Magento 2 Beta

### Required Configuration Items
1. ☐ Magento Beta base URL
2. ☐ Magento REST API endpoint
3. ☐ Magento API token/key for bot user
4. ☐ Akeneo API user credentials (use apiconnector account)
5. ☐ Attribute mapping configuration
6. ☐ Category mapping configuration
7. ☐ Channel selection (ecommerce recommended)

### Sync Scope
- **Products**: 9,538 products in Akeneo
- **Categories**: 166 categories
- **Attributes**: 112 attributes
- **Families**: 18 product families

---

## 📊 Elasticsearch Configuration
- **Host**: localhost:9200
- **Product Index**: akeneo_pim_product_and_product_model
- **Events Index**: akeneo_connectivity_connection_events_api_debug
- **Error Index**: akeneo_connectivity_connection_error

---

## 🔒 Security Notes

### Password Policy
- Admin passwords should be rotated regularly
- API credentials should use OAuth when possible
- Bot credentials are single-purpose for automation

### Access Control
- testadmin: Used for development/testing only
- admin: Primary production administrator
- apiconnector: Limited to API operations only
- bot (Magento): Automated operations only

### Change Log
- 2026-04-26: Initial credential audit and documentation
- User confirmed: bot/@dM1n$#@2o25B0T for Magento Beta
- User confirmed: testadmin/testpass for Akeneo PIM

---

## 📝 Action Items

### Immediate
- [ ] Obtain Magento 2 Beta URL
- [ ] Generate Magento API token for bot user
- [ ] Configure Akeneo connector with Magento credentials
- [ ] Test API connectivity between systems

### Security
- [ ] Consider rotating admin passwords
- [ ] Enable 2FA for admin accounts (if not already)
- [ ] Review API access logs
- [ ] Document additional credentials if discovered

---

## 🆘 Emergency Access

If locked out of Akeneo:
```bash
# Reset admin password via CLI
cd /home/pim/public_html
bin/console akeneo:user:create --admin --password="newpassword" emergency_admin emergency@example.com Emergency Admin

# Or reset existing user
bin/console pim:user:reset-password admin newpassword
```

If locked out of database:
```bash
# Root database access (if available)
mariadb -u root -p
```

---

**End of Credentials Document**  
**Keep this file secure and update as needed**
