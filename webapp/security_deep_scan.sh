#!/bin/bash
# Deep Security Scan & Malicious Tool Removal
# Date: 2026-04-30

LOG_FILE="logs/security_deep_scan_$(date +%Y%m%d_%H%M%S).log"
REPORT_FILE="SECURITY_SCAN_REPORT_$(date +%Y%m%d).md"

exec > >(tee -a "$LOG_FILE") 2>&1

echo "=== SECURITY DEEP SCAN START: $(date) ==="
echo ""

# 1. Check Lingma AI Agent (suspicious .lingma-server in /root)
echo "## 1. Lingma AI Agent Check"
if [ -d "/root/.lingma-server" ]; then
    echo "⚠️  FOUND: Lingma AI agent at /root/.lingma-server"
    du -sh /root/.lingma-server 2>/dev/null || echo "Cannot access"
    find /root/.lingma-server -type f -name "*.sh" -o -name "*.js" 2>/dev/null | head -10
    echo "ACTION: Flagged for removal"
else
    echo "✓ Lingma not found"
fi
echo ""

# 2. Check suspicious npm global packages
echo "## 2. NPM Global Packages Audit"
echo "Installed global packages:"
npm list -g --depth=0 2>/dev/null || echo "npm not available"
echo ""
echo "Checking for suspicious packages:"
for pkg in "gemini-cli" "pi-coding-agent" "qwen-code"; do
    if npm list -g "$pkg" &>/dev/null; then
        echo "⚠️  SUSPICIOUS: $pkg found"
    else
        echo "✓ $pkg not found"
    fi
done
echo ""

# 3. Check Python pip for malicious packages
echo "## 3. Python Packages Audit"
echo "Global pip packages:"
pip3 list 2>/dev/null | grep -i "miner\|crypto\|coin\|monero" || echo "No suspicious Python packages"
echo ""

# 4. Check recent cron jobs
echo "## 4. Cron Jobs Analysis"
echo "Root crontab:"
crontab -l 2>/dev/null || echo "No root crontab"
echo ""
echo "Pim user crontab:"
sudo -u pim crontab -l 2>/dev/null || echo "No pim crontab"
echo ""

# 5. Check systemd services for malware
echo "## 5. Systemd Services Check"
systemctl list-units --type=service --state=running | grep -i "miner\|crypto\|nuclear" || echo "No suspicious services"
echo ""

# 6. Check network connections
echo "## 6. Active Network Connections"
echo "Checking mining pool connections:"
netstat -tupn 2>/dev/null | grep -E "5221|3333|4444|8080|14444|45560" || echo "✓ No mining pool connections"
echo ""

# 7. Check SSH access logs for intrusion vector
echo "## 7. Recent SSH Access (last 50 entries)"
grep -i "Accepted" /var/log/secure 2>/dev/null | tail -20 || echo "No SSH logs accessible"
echo ""

# 8. Check for hidden files in common locations
echo "## 8. Hidden Files Scan"
find /tmp /var/tmp /dev/shm -type f -name ".*" 2>/dev/null | head -10 || echo "No hidden files"
echo ""

# 9. Check process tree for anomalies
echo "## 9. Process Tree Analysis"
pstree -p | grep -i "nuclear\|miner\|xmrig" || echo "✓ No mining processes"
echo ""

# 10. File integrity check
echo "## 10. Modified System Files (last 7 days)"
find /usr/bin /usr/sbin -type f -mtime -7 2>/dev/null | head -10 || echo "No recent modifications"
echo ""

echo "=== SCAN COMPLETE: $(date) ==="
echo "Full log: $LOG_FILE"
