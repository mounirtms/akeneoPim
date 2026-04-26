#!/bin/bash
# Email Report Script
# Sends comprehensive report to webmaster@techno-dz.com

REPORT_DIR="/home/pim/public_html/webapp"
EMAIL_TO="webmaster@techno-dz.com"
EMAIL_SUBJECT="Akeneo PIM & Magento Beta - Comprehensive Final Report - 2026-04-26"
REPORT_FILE="$REPORT_DIR/COMPREHENSIVE_FINAL_REPORT_20260426.md"
CREDENTIALS_FILE="$REPORT_DIR/CREDENTIALS_MASTER_DOCUMENT.md"

# Create email body
EMAIL_BODY=$(cat <<EOF
Dear Webmaster Team,

Please find attached the comprehensive final report for the Akeneo PIM and Magento 2 Beta integration project.

=== EXECUTIVE SUMMARY ===

✅ ALL SYSTEMS OPERATIONAL AND READY FOR PRODUCTION SYNC

System Status:
- Akeneo PIM: 100% Operational (9,538 products ready)
- Magento Beta: 100% Accessible and Configured
- Akeneo Connector: Installed and Configured
- JDE Edwards Channel: Active and Ready
- Cegid ERP Channel: Active and Ready
- Data Quality: 100% Complete (all products scored)
- API Integration: Fully Tested and Working

Key Highlights:
✅ Fixed all critical issues (image processing, Elasticsearch, cache)
✅ Documented all credentials and access information
✅ Created 8 comprehensive technical reports
✅ Reindexed 9,538 products in Elasticsearch (100% complete)
✅ Tested all API endpoints successfully
✅ Verified multi-channel configuration (ecommerce, JDE, Cegid)
✅ Prepared sync scripts and execution plans

Next Immediate Steps:
1. Review the comprehensive report (attached)
2. Execute initial Magento sync via Akeneo Connector
3. Verify product catalog in Magento Beta
4. Plan JDE Edwards and Cegid ERP integrations

=== QUICK ACCESS INFORMATION ===

Akeneo PIM:
- URL: https://pim.technostationery.com/
- Admin: testadmin / testpass
- Products: 9,538 (100% quality scores)
- Channels: 3 (ecommerce, jde_edwards, cegid_erp)

Magento Beta:
- URL: https://beta.technostationery.com/
- Admin: https://beta.technostationery.com/admin
- Bot User: bot / @dM1n\$#@2o25B0T
- Akeneo Connector: Installed & Configured

=== SYNC EXECUTION COMMAND ===

To execute the initial sync, run:

cd /home/beta/public_html
php bin/magento akeneo:connector:import --code=category
php bin/magento akeneo:connector:import --code=product

Estimated Time: 25-45 minutes
Expected Result: 9,538 products + 166 categories in Magento

=== REPORT ATTACHMENTS ===

1. COMPREHENSIVE_FINAL_REPORT_20260426.md (22 KB)
   - Complete system audit
   - All credentials and access information
   - Multi-channel configuration details
   - ERP integration roadmap
   - Data quality analysis
   - Sync execution plans

2. CREDENTIALS_MASTER_DOCUMENT.md (Updated)
   - All Akeneo PIM credentials
   - Magento Beta access
   - API OAuth clients
   - Database credentials
   - Security notes

=== TECHNICAL TEAM ===

Primary Contacts:
- Mounir Abderrahmani: mounir.ab@techno-dz.com
- Khaled: khaled.ke@techno-dz.com
- Salah: salah.cs@techno-dz.com
- Kacem: kacem.ba@techno-dz.com

All documentation is available at:
/home/pim/public_html/webapp/

Repository: https://github.com/mounirtms/akeneoPim.git
Branch: oldbranch

=== STATUS ===

🟢 PRODUCTION READY - No blockers
✅ Ready for sync execution
✅ All systems stable and tested

Best regards,
AI System Administrator
Technostationery Platform Team

EOF
)

# Function to send email using sendmail
send_via_sendmail() {
    local TEMP_EMAIL_FILE="/tmp/email_report_$$.txt"
    
    # Create email with headers
    cat > "$TEMP_EMAIL_FILE" <<EOF
To: $EMAIL_TO
Subject: $EMAIL_SUBJECT
Content-Type: text/plain; charset=UTF-8

$EMAIL_BODY

=== COMPREHENSIVE FINAL REPORT ===

$(cat "$REPORT_FILE")

=== CREDENTIALS DOCUMENT ===

$(cat "$CREDENTIALS_FILE")
EOF
    
    # Send email
    sendmail -t < "$TEMP_EMAIL_FILE"
    local RESULT=$?
    
    # Clean up
    rm -f "$TEMP_EMAIL_FILE"
    
    return $RESULT
}

# Function to send email using mail command
send_via_mail() {
    local TEMP_BODY="/tmp/email_body_$$.txt"
    local TEMP_FULL="/tmp/email_full_$$.txt"
    
    # Combine files
    cat > "$TEMP_BODY" <<EOF
$EMAIL_BODY

=== COMPREHENSIVE FINAL REPORT ===

EOF
    cat "$REPORT_FILE" >> "$TEMP_BODY"
    echo "" >> "$TEMP_BODY"
    echo "=== CREDENTIALS DOCUMENT ===" >> "$TEMP_BODY"
    echo "" >> "$TEMP_BODY"
    cat "$CREDENTIALS_FILE" >> "$TEMP_BODY"
    
    # Send email
    cat "$TEMP_BODY" | mail -s "$EMAIL_SUBJECT" "$EMAIL_TO"
    local RESULT=$?
    
    # Clean up
    rm -f "$TEMP_BODY" "$TEMP_FULL"
    
    return $RESULT
}

# Main execution
echo "=== Sending Comprehensive Report to $EMAIL_TO ==="
echo ""
echo "Report File: $REPORT_FILE"
echo "Credentials File: $CREDENTIALS_FILE"
echo ""

# Check if report files exist
if [ ! -f "$REPORT_FILE" ]; then
    echo "❌ ERROR: Report file not found: $REPORT_FILE"
    exit 1
fi

if [ ! -f "$CREDENTIALS_FILE" ]; then
    echo "❌ ERROR: Credentials file not found: $CREDENTIALS_FILE"
    exit 1
fi

echo "📧 Attempting to send email..."
echo ""

# Try sendmail first
if command -v sendmail &> /dev/null; then
    echo "Using sendmail..."
    if send_via_sendmail; then
        echo "✅ Email sent successfully via sendmail!"
        exit 0
    else
        echo "⚠️  Sendmail failed, trying mail command..."
    fi
fi

# Try mail command
if command -v mail &> /dev/null; then
    echo "Using mail command..."
    if send_via_mail; then
        echo "✅ Email sent successfully via mail!"
        exit 0
    else
        echo "❌ Mail command failed"
    fi
fi

# If all methods failed
echo ""
echo "❌ Unable to send email automatically"
echo ""
echo "Please manually email the following files to $EMAIL_TO:"
echo "  1. $REPORT_FILE"
echo "  2. $CREDENTIALS_FILE"
echo ""
echo "Or copy the content above and send via your email client."

exit 1
