#!/bin/bash
# CHECK_EMAIL_CONFIG.sh - Check cPanel email configuration
# Date: 2026-05-06

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📧 EMAIL CONFIGURATION AUDIT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "1. cPanel Email Accounts Check..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
# Check email accounts in cPanel
if [ -d "/home/pim/mail" ]; then
    echo "✓ Mail directory exists: /home/pim/mail"
    MAIL_DOMAINS=$(ls -1 /home/pim/mail 2>/dev/null | grep -v "cur\|new\|tmp" || echo "")
    if [ -n "$MAIL_DOMAINS" ]; then
        echo "✓ Mail domains found:"
        echo "$MAIL_DOMAINS" | sed 's/^/    /'
        
        for domain in $MAIL_DOMAINS; do
            if [ -d "/home/pim/mail/$domain" ]; then
                ACCOUNTS=$(ls -1 /home/pim/mail/$domain 2>/dev/null | wc -l | tr -d ' ')
                echo "    → $domain: $ACCOUNTS email accounts"
            fi
        done
    else
        echo "✗ No mail domains configured"
    fi
else
    echo "✗ Mail directory not found"
fi
echo ""

echo "2. SMTP Configuration Check..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
# Check for common SMTP ports
netstat -tlnp 2>/dev/null | grep -E ":(25|465|587|2525)" | head -10 || echo "Netstat unavailable, checking process list..."
ps aux | grep -E "exim|postfix|sendmail" | grep -v grep | head -5 || echo "No mail daemon found"
echo ""

echo "3. Current Akeneo Mailer Configuration..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ -f ".env.local" ]; then
    echo "From .env.local:"
    grep -E "MAILER_" .env.local 2>/dev/null || echo "  No MAILER_ variables found"
else
    echo "✗ .env.local not found"
fi
echo ""

if [ -f "config/packages/swiftmailer.yaml" ] || [ -f "config/packages/mailer.yaml" ]; then
    echo "From config files:"
    [ -f "config/packages/swiftmailer.yaml" ] && cat config/packages/swiftmailer.yaml || true
    [ -f "config/packages/mailer.yaml" ] && cat config/packages/mailer.yaml || true
else
    echo "✗ Mailer config files not found"
fi
echo ""

echo "4. Recommended Email Configuration..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "For cPanel SMTP (recommended):"
echo "  MAILER_URL=smtp://mail.pim.technostationery.com:587?encryption=tls&auth_mode=login"
echo "  MAILER_USER=noreply@technostationery.com"
echo "  MAILER_PASSWORD=<email_password>"
echo ""
echo "For localhost (testing only):"
echo "  MAILER_URL=smtp://localhost:25"
echo ""
echo "Current setting in .env.local:"
grep "MAILER_URL" .env.local 2>/dev/null || echo "  Not configured"
echo ""

echo "5. Test Email Command..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "To test email sending, run:"
echo "  php bin/console swiftmailer:email:send --from=noreply@technostationery.com --to=test@example.com --subject='Test' --body='Test email'"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Email configuration audit complete"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
