# 📧 EMAIL NOTIFICATION SYSTEM - IMPLEMENTATION GUIDE

**Date**: April 22, 2026  
**Status**: ✅ **CONFIGURED & READY**  
**Recipients**: webmaster@techno-dz.com, marketing@techno-dz.com

---

## ✅ WHAT WAS CREATED

### 1. Event Subscriber System
**File**: `src/EventSubscriber/CatalogNotificationSubscriber.php`

**Features**:
- ✅ Automatic email notifications for catalog events
- ✅ Product updates/deletions monitoring
- ✅ Product model change tracking
- ✅ Batch notifications (50 items threshold)
- ✅ Job failure/completion alerts
- ✅ Bulk update notifications

**Events Monitored**:
```php
StorageEvents::POST_SAVE          → Product saved
StorageEvents::POST_SAVE_ALL      → Bulk product save
StorageEvents::POST_REMOVE        → Product deleted
akeneo_batch.after_job_execution  → Import/Export completion
```

### 2. Configuration Files

#### A. Notification Configuration
**File**: `config/packages/notifications.yaml`

**Parameters**:
```yaml
notification_email_webmaster: 'webmaster@techno-dz.com'
notification_email_marketing: 'marketing@techno-dz.com'
notification_email_from: 'noreply@technostationery.com'
notification_enabled: true
notification_batch_size: 50
notification_send_interval: 300  # 5 minutes
```

**Monolog Handlers**:
- `webmaster_email`: Critical errors (ERROR level)
- `webmaster_daily`: Daily digest (WARNING level)
- Email format: HTML with full details

#### B. Service Configuration
**File**: `config/services/notifications.yaml`

**Service Definition**:
```yaml
App\EventSubscriber\CatalogNotificationSubscriber:
    arguments:
        $mailer: '@mailer.mailer'
        $logger: '@monolog.logger'
        $marketingEmail: '%notification_email_marketing%'
        $webmasterEmail: '%notification_email_webmaster%'
        $fromEmail: '%notification_email_from%'
        $enabled: '%notification_enabled%'
    tags:
        - { name: kernel.event_subscriber }
```

---

## 📧 NOTIFICATION TYPES

### For Webmaster (webmaster@techno-dz.com)

#### 1. Critical System Errors
**Trigger**: ERROR level logs  
**Subject**: `[AKENEO CRITICAL] System Error on PIM`  
**Content**:
- Error message
- Stack trace
- Timestamp
- Affected component

#### 2. Job Failures
**Trigger**: Import/Export job fails  
**Subject**: `[AKENEO ERROR] Job Failed: {JobName}`  
**Content**:
- Job name and type
- Failure status
- Error messages (list)
- Link to job details
- Timestamp

#### 3. Daily Digest
**Trigger**: End of day (WARNING level aggregation)  
**Subject**: `[AKENEO] Daily System Report`  
**Content**:
- Warning summary
- System health status
- Performance metrics
- Recommendations

---

### For Marketing (marketing@techno-dz.com)

#### 1. Product Model Changes
**Trigger**: Product model save/delete  
**Subject**: `[AKENEO] Product Model {Action}: {Code}`  
**Content**:
- Product model code
- Family information
- Action performed (created/updated/deleted)
- Link to view in PIM
- Timestamp

**Example**:
```
Product Model Updated

Code: T-SHIRT-BLUE
Family: Clothing
Action: Updated
Time: 2026-04-22 21:30:00
[View in PIM]
```

#### 2. Bulk Product Updates
**Trigger**: >10 products updated at once  
**Subject**: `[AKENEO] Bulk Update: {Count} products`  
**Content**:
- Number of products affected
- Update type
- Timestamp
- Link to product list

#### 3. Import/Export Completion
**Trigger**: Job completes with >100 items  
**Subject**: `[AKENEO] Job Completed: {JobName} ({Count} items)`  
**Content**:
- Job name and type
- Items processed count
- Duration
- Link to job details
- Timestamp

#### 4. Batch Product Changes
**Trigger**: 50 accumulated product changes  
**Subject**: `[AKENEO] Catalog Updates: {Count} changes`  
**Content**:
- Total changes count
- Updated vs deleted breakdown
- Detailed list with timestamps
- Link to product catalog

**Example**:
```
Catalog Updates Summary

Total Changes: 50
Updated: 45
Deleted: 5

Details:
• Updated: SKU-001 (at 14:30:15)
• Updated: SKU-002 (at 14:30:16)
• Deleted: SKU-OLD (at 14:31:00)
...

[View Products]
```

---

## 🔧 CONFIGURATION REQUIREMENTS

### Step 1: SMTP Credentials (CRITICAL)

**Current Status**: ⚠️ Mailer disabled (null transport)

**Required**: Real SMTP configuration

**Options**:

#### Option A: Gmail/Google Workspace
```bash
# In .env file:
MAILER_URL=smtp://youremail%40gmail.com:app-password@smtp.gmail.com:587?encryption=tls
```

#### Option B: SendGrid
```bash
MAILER_URL=smtp://apikey:YOUR_API_KEY@smtp.sendgrid.net:587
```

#### Option C: Office 365
```bash
MAILER_URL=smtp://user%40domain.com:password@smtp.office365.com:587?encryption=tls
```

#### Option D: Local/Hosting SMTP
```bash
# Get from hosting provider
MAILER_URL=smtp://username:password@smtp.example.com:587?encryption=tls
```

**Setup Guide**:
```bash
cd /home/pim/public_html/webapp
./configure_email.sh
```

### Step 2: Clear Cache
```bash
cd /home/pim/public_html
php -d allow_url_fopen=1 bin/console cache:clear --env=prod
cd webapp && ./fix_cache_permissions.sh
```

### Step 3: Verify Configuration
```bash
# Check if event subscriber is registered
php bin/console debug:event-dispatcher | grep -i catalog

# Check if service is loaded
php bin/console debug:container CatalogNotificationSubscriber
```

---

## 🧪 TESTING THE SYSTEM

### Test 1: Update a Product
1. Login to PIM: https://pim.technostationery.com/user/login
2. Navigate to any product
3. Make a small change (e.g., update description)
4. Save the product
5. Check logs:
   ```bash
   tail -f /home/pim/public_html/var/logs/prod.log | grep -i notification
   ```

**Expected**: Log entry showing notification queued

### Test 2: Update a Product Model
1. Go to Product Models section
2. Edit any product model
3. Save changes
4. **Expected Email** to marketing@techno-dz.com:
   - Subject: `[AKENEO] Product Model Updated: {code}`
   - Body with model details and PIM link

### Test 3: Bulk Update (Batch Test)
1. Import CSV with 15+ products
2. **Expected Email** to marketing@techno-dz.com:
   - Subject: `[AKENEO] Bulk Update: 15 products`

### Test 4: Cause an Error (Webmaster Test)
1. Try to import invalid CSV
2. **Expected Email** to webmaster@techno-dz.com:
   - Subject: `[AKENEO ERROR] Job Failed: {job}`
   - Error details included

---

## 📊 NOTIFICATION BEHAVIOR

### Batching Logic
```
Products/Changes: Accumulate up to 50 items
Send Trigger: When 50 items reached OR manual flush
Purpose: Avoid email spam for high-volume operations
```

### Immediate Notifications
These are sent immediately (no batching):
- Product model changes
- Job failures
- Critical errors
- Bulk operations (>10 items at once)

### Delayed Notifications
These are batched:
- Individual product updates
- Individual product deletions
- Category changes

---

## 🔍 MONITORING & DEBUGGING

### Check Notification Logs
```bash
# View notification activity
tail -100 /home/pim/public_html/var/logs/prod.log | grep -i notification

# Check for email sending errors
tail -100 /home/pim/public_html/var/logs/prod.log | grep -i "failed to send"

# Monitor in real-time
tail -f /home/pim/public_html/var/logs/prod.log | grep -E "notification|email"
```

### Verify Event Subscription
```bash
cd /home/pim/public_html

# List all event subscribers
php bin/console debug:event-dispatcher

# Check specific events
php bin/console debug:event-dispatcher akeneo.storage.post_save
```

### Test Email Configuration
```bash
# Check mailer config
php bin/console debug:config framework mailer --env=prod

# Expected output (after SMTP config):
# enabled: true
# dsn: smtp://...
```

---

## 🛠️ CUSTOMIZATION

### Change Email Recipients

**File**: `config/packages/notifications.yaml`

```yaml
parameters:
    notification_email_webmaster: 'your-admin@domain.com'
    notification_email_marketing: 'your-marketing@domain.com'
    notification_email_from: 'noreply@yourdomain.com'
```

### Adjust Batch Size

```yaml
parameters:
    notification_batch_size: 100  # Default: 50
```

### Enable/Disable Notifications

```yaml
parameters:
    notification_enabled: false  # Set to false to disable
```

### Add More Recipients

**Option 1**: Multiple recipients in configuration
```yaml
# In CatalogNotificationSubscriber.php, modify constructor
public function __construct(
    ...
    array $marketingEmails = ['marketing@techno-dz.com', 'team@techno-dz.com'],
    ...
)
```

**Option 2**: CC/BCC in email
```php
// In subscriber methods
$email = (new Email())
    ->from($this->fromEmail)
    ->to($this->marketingEmail)
    ->cc('extra@techno-dz.com')  // Add CC
    ->subject('...')
    ->html('...');
```

---

## 📋 EMAIL TEMPLATES

### Product Model Update Template
```html
<h2>Product Model Updated</h2>
<p><strong>Code:</strong> {code}</p>
<p><strong>Family:</strong> {family}</p>
<p><strong>Action:</strong> Updated</p>
<p><strong>Time:</strong> {timestamp}</p>
<p><a href="https://pim.technostationery.com/enrich/product-model/{code}">View in PIM</a></p>
```

### Job Failure Template
```html
<h2 style="color: #d32f2f;">Job Failed</h2>
<p><strong>Job Name:</strong> {jobName}</p>
<p><strong>Type:</strong> {jobType}</p>
<p><strong>Status:</strong> <span style="color: #d32f2f;">{status}</span></p>
<p><strong>Time:</strong> {timestamp}</p>
<h3>Failure Messages:</h3>
<ul>
  <li>{error1}</li>
  <li>{error2}</li>
</ul>
<p><a href="https://pim.technostationery.com/job">View Job Details</a></p>
```

### Batch Summary Template
```html
<h2>Catalog Updates Summary</h2>
<p><strong>Total Changes:</strong> {count}</p>
<p><strong>Updated:</strong> {updated}</p>
<p><strong>Deleted:</strong> {deleted}</p>
<h3>Details:</h3>
<ul>
  <li>Updated: SKU-001 (at 14:30:15)</li>
  <li>Updated: SKU-002 (at 14:30:16)</li>
  ...
</ul>
<p><a href="https://pim.technostationery.com/enrich/product/">View Products</a></p>
```

---

## 🚀 PRODUCTION READINESS

### ✅ Completed
- [x] Event subscriber created
- [x] Service configuration added
- [x] Notification parameters defined
- [x] Monolog handlers configured
- [x] Email templates implemented
- [x] Batch notification logic
- [x] Error handling included

### ⏳ Pending (User Action)
- [ ] SMTP credentials configured
- [ ] Cache cleared after SMTP setup
- [ ] Test email sent and received
- [ ] Marketing team notified of new system
- [ ] Webmaster team notified of alerts

---

## 📞 SUPPORT & TROUBLESHOOTING

### Email Not Sending?

**Check 1**: SMTP Configuration
```bash
grep MAILER_URL /home/pim/public_html/.env
# Should NOT be: null://localhost
# Should be: smtp://...
```

**Check 2**: Framework Mailer Enabled
```bash
php bin/console debug:config framework mailer --env=prod
# enabled: true (not false)
```

**Check 3**: Cache Cleared
```bash
ls -la /home/pim/public_html/var/cache/prod/ | head -5
# Verify recent timestamp
```

**Check 4**: Event Subscriber Registered
```bash
php bin/console debug:event-dispatcher | grep CatalogNotification
# Should show the subscriber
```

### Emails Going to Spam?

**Solutions**:
1. Use authenticated SMTP (not localhost)
2. Configure SPF/DKIM records for your domain
3. Use reputable email service (SendGrid, etc.)
4. Add technostationery.com to recipient's whitelist

### Too Many Emails?

**Adjust batch size**:
```yaml
# In config/packages/notifications.yaml
notification_batch_size: 100  # Increase from 50
```

**Disable for testing**:
```yaml
notification_enabled: false
```

---

## 🎯 SUMMARY

**What's Working**:
- ✅ Event system configured
- ✅ Notification logic implemented
- ✅ Email templates created
- ✅ Service registered
- ✅ Two recipient groups configured

**What's Needed**:
- ⏳ SMTP credentials (from user)
- ⏳ Cache clear after SMTP setup
- ⏳ Test notification

**Once SMTP Configured**:
- Webmaster gets: Errors, job failures, daily digest
- Marketing gets: Product updates, model changes, catalog events

---

**Created By**: AI Assistant  
**Date**: April 22, 2026  
**Status**: ✅ **READY FOR SMTP CONFIGURATION**  
**Next**: Get SMTP credentials and test!
