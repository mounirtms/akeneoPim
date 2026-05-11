# Manual Login Test Instructions

## Credentials
- **URL:** https://pim.technostationery.com/user/login
- **Username:** admin
- **Password:** Admin123!

## Test Steps

1. **Open Login Page**
   - Navigate to: https://pim.technostationery.com/user/login
   - Verify the page loads with CSS styling
   - Check browser console (F12) for any errors

2. **Submit Login Form**
   - Enter username: `admin`
   - Enter password: `Admin123!`
   - Click "Login" or press Enter

3. **Expected Results**
   - ✅ Should redirect to dashboard
   - ✅ Should see Akeneo PIM interface
   - ✅ Should see product count: 8,217 products
   - ✅ Should see navigation menu

4. **If Login Fails**
   Check the following:
   - Browser console errors (F12 → Console tab)
   - Network tab responses (F12 → Network tab)
   - Try clearing browser cache (Ctrl+Shift+Delete)
   - Try in incognito/private mode

## Database Verification

Current database status:
- Database: akeneo_pim (port 3307)
- Admin user: enabled
- Password hash: Valid for "Admin123!"
- Products: 8,217
- Categories: 166
- Attributes: 112

## Automated Test Results

Last test run: $(date)
- Homepage redirect: PASS
- Login elements: PASS  
- CSS loading: PASS (2/2 files)
- JavaScript loading: PASS (14/15 files)
- Login functionality: Needs manual verification

## Troubleshooting

If you see "Invalid credentials":
1. Database password hash is correct
2. Check security.yaml encoder configuration
3. Clear Symfony cache: `php bin/console cache:clear --env=prod`
4. Check var/logs/prod.log for authentication errors

## Support Files
- Test report: /home/pim/public_html/webapp/pim_test_report.json
- Screenshots: /home/pim/public_html/webapp/test_*.png
- Logs: /home/pim/public_html/var/logs/prod.log
