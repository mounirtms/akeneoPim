# 🔧 CLOUDFLARE FIX INSTRUCTIONS
**Urgent Action Required** | **Est. Time**: 10 minutes

---

## 🎯 PROBLEM

The Akeneo PIM application is working correctly on the server, but **Cloudflare is blocking access** with a 403 Forbidden error.

**Working**: https://pim.technostationery.com/user/login ✅  
**Blocked**: https://pim.technostationery.com/ ❌ (403 Forbidden)

---

## ✅ STEP-BY-STEP FIX

### Step 1: Login to Cloudflare (2 minutes)

1. Go to: **https://dash.cloudflare.com/**
2. Login with your Cloudflare credentials
3. Select domain: **pim.technostationery.com**

---

### Step 2: Purge Cache (2 minutes)

1. Click **Caching** in the left sidebar
2. Click **Configuration**
3. Scroll to **Purge Cache** section
4. Click **Purge Everything** button
5. Confirm: Click **Purge Everything** in the popup
6. Wait for confirmation message: "Successfully purged everything"

---

### Step 3: Check Firewall/WAF (3 minutes)

1. Click **Security** in the left sidebar
2. Click **Events** or **Activity Log**
3. Look for recent blocks (Ray ID: `9f7a465bec262b9d`)
4. Check if your IP address is blocked

**If IP is blocked**:
- Click **Add rule** or **IP Access Rules**
- Add your IP address
- Set action to: **Allow** or **Whitelist**
- Click **Add**

---

### Step 4: Adjust Security Level (1 minute)

1. Click **Security** in the left sidebar
2. Click **Settings**
3. Find **Security Level**
4. If set to "I'm Under Attack", change to **Medium** or **Low**
5. Save changes

---

### Step 5: Create Bypass Page Rules (Optional - 3 minutes)

**For testing purposes**, create rules to bypass cache:

1. Click **Rules** in the left sidebar
2. Click **Page Rules**
3. Click **Create Page Rule**

**Rule 1 - Bypass login/user pages**:
- URL pattern: `pim.technostationery.com/user/*`
- Setting: Cache Level → **Bypass**
- Save

**Rule 2 - Bypass root (temporary)**:
- URL pattern: `pim.technostationery.com/`
- Setting: Cache Level → **Bypass**
- Save

*Note: These rules help during testing. Remove Rule 2 after verification.*

---

## 🧪 VERIFICATION

After completing the steps above:

### Test 1: Browser Test
1. **Clear your browser cache** (Ctrl+Shift+Delete)
2. Visit: https://pim.technostationery.com/
3. **Expected**: Should redirect to /user/login
4. **If 403 persists**: Wait 5 minutes for cache propagation

### Test 2: Curl Test
```bash
curl -I https://pim.technostationery.com/
```
**Expected output**:
- `HTTP/2 200` or `HTTP/2 302`
- NOT `HTTP/2 403`

### Test 3: Login Test
1. Go to: https://pim.technostationery.com/user/login
2. Login with: `admin` / `Admin123!`
3. **Expected**: Dashboard loads successfully

---

## 🚨 IF STILL BLOCKED

### Additional Checks:

**1. Development Mode** (temporary):
- In Cloudflare dashboard → **Caching** → **Configuration**
- Enable **Development Mode** (bypasses cache for 3 hours)
- Test again

**2. Check Rate Limiting**:
- Go to **Security** → **Rate Limiting**
- Check if rules are triggered
- Adjust or temporarily disable

**3. Bot Fight Mode**:
- Go to **Security** → **Bots**
- Check if "Bot Fight Mode" is blocking
- Adjust sensitivity

**4. Super Bot Fight Mode** (if on paid plan):
- May be blocking legitimate traffic
- Temporarily disable for testing

---

## ✅ SUCCESS CONFIRMATION

You'll know it's fixed when:
- ✅ https://pim.technostationery.com/ redirects to login
- ✅ No 403 Forbidden error
- ✅ Akeneo PIM loads in browser
- ✅ Login works with admin credentials

---

## 📞 NEED HELP?

**Cloudflare Support**:
- Support Portal: https://support.cloudflare.com/
- Provide Ray ID: `9f7a465bec262b9d`
- Mention: "403 Forbidden after server configuration change"

**Alternative**: Share Cloudflare access temporarily with technical team for immediate fix.

---

## ⏰ ESTIMATED TIME

- **If you have Cloudflare access**: 10 minutes
- **If you need to contact Cloudflare support**: 1-2 hours
- **If you grant access to technical team**: 10 minutes

---

**Priority**: 🔴 HIGH - Application is working but unreachable due to CDN  
**Impact**: Users cannot access the system via root URL  
**Workaround**: Direct login URL works: https://pim.technostationery.com/user/login

