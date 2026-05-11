=== POST-DEPLOYMENT COMPREHENSIVE TESTS ===
Started: Wed May  6 12:31:53 CET 2026

## 1. WEB SERVER TESTS
---
✓ PASS: Apache is running (7 processes)
✓ PASS: Apache listening on ports 80/443

## 2. APPLICATION TESTS
---
✓ PASS: Root path redirects correctly
✓ PASS: Login page renders correctly
✓ PASS: Response time: 655ms (target <1000ms)

## 3. DATABASE TESTS
---
✓ PASS: Database connection established
✗ FAIL: Product count low: 1 (expected >9000)

## 4. FILE SYSTEM TESTS
---
✓ PASS: Cache optimized: 5993 files
✓ PASS: Log file writable
✓ PASS: Media directory accessible (569M)

## 5. SYMFONY TESTS
---
✓ PASS: Symfony console: Symfony 5.4.51 (env: prod, debug: false)
✓ PASS: Akeneo commands available: 32
✓ PASS: Routing system operational

## 6. SECURITY TESTS
---
✓ PASS: Security .htaccess files: 4/4
✓ PASS: All critical directories writable

## 7. OPTIMIZATION VERIFICATION
---
✓ PASS: robots.txt optimized: 604 bytes
✓ PASS: index.php ownership: pim:pim
✓ PASS: PHP handler updated: ea-php83

## 8. LOG ANALYSIS
---
✗ FAIL: High error count: 17
⚠ WARNING: 0
0 new critical errors detected
✗ FAIL: New critical errors: 0
0

## TEST SUMMARY
---
Total Tests: 20
Passed: 17
Failed: 3
Success Rate: 85%

## STATUS: ✓ GOOD (85%)

## PRODUCTION STATUS
---
🌐 Website: https://pim.technostationery.com/user/login
📊 Products: 1
⏱️ Response Time: 655ms
💾 Cache Files: 5993
🔒 Security: 4/4 protections

Testing completed: Wed May  6 12:31:58 CET 2026
Report saved: POST_DEPLOY_TEST_REPORT_20260506_123153.md
