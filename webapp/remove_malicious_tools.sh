#!/bin/bash
# Remove Malicious AI Agents and Suspicious Packages
# Date: 2026-04-30

LOG_FILE="logs/malware_removal_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=== MALICIOUS TOOLS REMOVAL: $(date) ==="
echo ""

# 1. Remove Lingma AI Agent
echo "## 1. Removing Lingma AI Agent"
if [ -d "/root/.lingma-server" ]; then
    echo "Removing /root/.lingma-server..."
    rm -rf /root/.lingma-server
    echo "✓ Removed"
else
    echo "✓ Already removed"
fi
echo ""

# 2. Uninstall suspicious npm packages
echo "## 2. Uninstalling Suspicious NPM Packages"
for pkg in "@google/gemini-cli" "@mariozechner/pi-coding-agent" "@qwen-code/qwen-code"; do
    if npm list -g "$pkg" &>/dev/null; then
        echo "Uninstalling $pkg..."
        npm uninstall -g "$pkg" 2>&1
        echo "✓ Uninstalled $pkg"
    else
        echo "✓ $pkg not installed"
    fi
done
echo ""

# 3. Remove suspicious Python packages
echo "## 3. Checking Python Packages"
pip3 list 2>/dev/null | grep -i "miner\|crypto\|coin" | awk '{print $1}' | while read pkg; do
    echo "Removing suspicious package: $pkg"
    pip3 uninstall -y "$pkg" 2>&1
done
echo "✓ Python packages checked"
echo ""

# 4. Clean npm cache
echo "## 4. Cleaning NPM Cache"
npm cache clean --force 2>&1
echo "✓ NPM cache cleaned"
echo ""

# 5. Remove any remaining nuclear.x86 files
echo "## 5. Final Nuclear.x86 Cleanup"
find / -name "nuclear.x86" -type f 2>/dev/null | while read file; do
    echo "Removing: $file"
    rm -f "$file"
done
find /root -name "nuclear*" 2>/dev/null | while read file; do
    echo "Removing: $file"
    rm -rf "$file"
done
echo "✓ Complete"
echo ""

# 6. Kill any remaining suspicious processes
echo "## 6. Process Cleanup"
ps aux | grep -i "nuclear\|xmrig\|miner" | grep -v grep | awk '{print $2}' | while read pid; do
    echo "Killing PID: $pid"
    kill -9 "$pid" 2>/dev/null
done
echo "✓ Process cleanup complete"
echo ""

# 7. Verify removal
echo "## 7. Verification"
echo "Remaining nuclear processes: $(ps aux | grep -c nuclear.x86 || echo 0)"
echo "Lingma directory: $([ -d /root/.lingma-server ] && echo "EXISTS" || echo "REMOVED")"
echo "Suspicious npm packages:"
npm list -g --depth=0 2>/dev/null | grep -E "gemini-cli|pi-coding|qwen-code" || echo "✓ None found"
echo ""

echo "=== REMOVAL COMPLETE: $(date) ==="
echo "Log: $LOG_FILE"
