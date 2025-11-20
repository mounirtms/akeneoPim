# 📋 Pimcore Permission Commands - Line by Line Reference

## 🎯 THE ROOT CAUSE OF YOUR PERMISSION ISSUES

When you run commands as `root`, cache files get created as `root:root`.
Apache runs as user `pim`, so it cannot write to these files = 500 errors.

**Solution**: Always ensure files are owned by `pim:nobody` with correct permissions.

---

## ✅ COMPLETE FIX - Run These Commands Line by Line

### Step 1: Change Ownership to pim:nobody
```bash
cd /home/pim/public_html
chown -R pim:nobody /home/pim/public_html
```
**Explanation**: Changes ALL files to be owned by pim user and nobody group.

### Step 2: Set Directory Permissions to 775
```bash
find /home/pim/public_html -type d -exec chmod 775 {} \;
```
**Explanation**: 
- Owner (pim): read+write+execute (7)
- Group (nobody): read+write+execute (7)  
- Others: read+execute (5)

### Step 3: Set File Permissions to 664
```bash
find /home/pim/public_html -type f -exec chmod 664 {} \;
```
**Explanation**:
- Owner (pim): read+write (6)
- Group (nobody): read+write (6)
- Others: read only (4)

### Step 4: Make bin/console Executable
```bash
chmod +x /home/pim/public_html/bin/console
```
**Explanation**: Console needs execute permission to run.

### Step 5: Critical Directories Need 777
```bash
chmod -R 777 /home/pim/public_html/var/cache
chmod -R 777 /home/pim/public_html/var/log
chmod -R 777 /home/pim/public_html/var/tmp
chmod -R 777 /home/pim/public_html/var/sessions
```
**Explanation**: These directories need full write access for Apache.

### Step 6: Set Sticky Bit on var Directory
```bash
chmod -R g+s /home/pim/public_html/var
```
**Explanation**: Ensures new files inherit the group (nobody).

### Step 7: Clear Cache
```bash
rm -rf /home/pim/public_html/var/cache/*
```
**Explanation**: Remove old cache files owned by root.

### Step 8: Rebuild Cache as pim User
```bash
su - pim -c "cd /home/pim/public_html && php bin/console cache:clear --env=prod"
```
**Explanation**: Rebuilds cache as pim user, not root.

---

## 🔄 QUICK FIX (Run When Site Breaks)

```bash
cd /home/pim/public_html
chown -R pim:nobody .
chmod -R 777 var/
rm -rf var/cache/*
su - pim -c "cd /home/pim/public_html && php bin/console cache:clear --env=prod"
```

---

## 📊 VERIFY PERMISSIONS

Check who owns files:
```bash
ls -la /home/pim/public_html/ | head -20
```

Check var directory permissions:
```bash
ls -ld /home/pim/public_html/var/*
```

Check current user:
```bash
whoami  # Should show: root or pim
```

---

## ⚠️ IMPORTANT RULES

### ❌ DON'T DO THIS:
```bash
# Running as root creates root-owned cache files
php bin/console cache:clear  
```

### ✅ DO THIS INSTEAD:
```bash
# Run as pim user
su - pim -c "cd /home/pim/public_html && php bin/console cache:clear"
```

---

## 🔧 ALWAYS RUN AS PIM USER

When running Pimcore commands, always use:

```bash
su - pim -c "cd /home/pim/public_html && php bin/console YOUR_COMMAND"
```

Or switch to pim user first:
```bash
su - pim
cd /home/pim/public_html
php bin/console YOUR_COMMAND
exit  # Back to root
```

---

## 📝 PERMISSION NUMBERS EXPLAINED

### Directory: 775
- 7 (owner): rwx (read+write+execute)
- 7 (group): rwx (read+write+execute)
- 5 (other): r-x (read+execute)

### File: 664
- 6 (owner): rw- (read+write)
- 6 (group): rw- (read+write)
- 4 (other): r-- (read only)

### Critical dirs: 777
- 7 (owner): rwx (full access)
- 7 (group): rwx (full access)
- 7 (other): rwx (full access)

---

## 🚀 AUTOMATED SCRIPT

I've created a script that fixes everything:

```bash
cd /home/pim/public_html
bash ./FIX_PERMISSIONS_COMPLETE.sh
```

This script:
1. Changes ownership to pim:nobody
2. Sets correct permissions (775/664)
3. Makes executables
4. Sets 777 on cache/log
5. Clears and rebuilds cache as pim user

---

## 🔍 TROUBLESHOOTING

### If site returns 500 error:
```bash
# Check ownership
ls -la /home/pim/public_html/var/cache/

# If owned by root, fix it:
chown -R pim:nobody /home/pim/public_html/var/
chmod -R 777 /home/pim/public_html/var/cache/
rm -rf /home/pim/public_html/var/cache/*
```

### Check Apache user:
```bash
ps aux | grep httpd | head -5
# Should show user: pim or nobody
```

### Test permissions:
```bash
# Try creating a file as pim user
su - pim -c "touch /home/pim/public_html/var/test.txt"
ls -l /home/pim/public_html/var/test.txt
# Should show: pim nobody
rm /home/pim/public_html/var/test.txt
```

---

## ✅ CORRECT WORKFLOW

1. **Run commands as root** → Files become root:root ❌
2. **Site breaks** (500 error)
3. **Fix permissions**: `chown -R pim:nobody`
4. **Clear cache as pim**: `su - pim -c "php bin/console cache:clear"`
5. **Site works** ✅

**Better**: Always run Pimcore commands as pim user from the start!

---

## 📋 CHECKLIST

After running permission fix, verify:
- [ ] var/cache owned by pim:nobody (775 or 777)
- [ ] var/log owned by pim:nobody (777)
- [ ] var/sessions owned by pim:nobody (777)
- [ ] bin/console is executable (755 or 775)
- [ ] Homepage returns 200 OK
- [ ] Admin login returns 200 OK

