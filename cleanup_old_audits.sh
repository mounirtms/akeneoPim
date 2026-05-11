#!/bin/bash
################################################################################
# CLEANUP OLD AUDITS AND TEMPORARY FILES
# Date: May 6, 2026
# Purpose: Remove old audit files, logs, and temporary artifacts
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo ""
echo "################################################################################"
echo "#                    CLEANUP OLD AUDITS & FILES                                #"
echo "################################################################################"
echo ""

PROJECT_DIR="/home/pim/public_html"
ARCHIVE_DIR="$PROJECT_DIR/archived_audits_$(date +%Y%m%d)"

cd "$PROJECT_DIR"

# Create archive directory
mkdir -p "$ARCHIVE_DIR"

echo -e "${GREEN}📦 Archiving old audit files...${NC}"
echo ""

# Find and archive old audit files
echo "Finding audit files..."
find . -maxdepth 2 -name "*AUDIT*.md" -o -name "*AUDIT*.sh" | while read file; do
    if [ -f "$file" ]; then
        echo "  → $(basename "$file")"
        cp "$file" "$ARCHIVE_DIR/"
        rm "$file"
    fi
done

# Find and archive old report files
echo ""
echo "Finding report files..."
find . -maxdepth 2 -name "*REPORT*.md" | while read file; do
    if [ -f "$file" ]; then
        echo "  → $(basename "$file")"
        cp "$file" "$ARCHIVE_DIR/"
        rm "$file"
    fi
done

# Archive webapp documentation (keep only essential)
echo ""
echo "Archiving webapp documentation..."
if [ -d "webapp" ]; then
    cd webapp
    
    # Essential files to keep
    KEEP_FILES=(
        "package.json"
        "package-lock.json"
        "playwright.config.js"
        "README.md"
    )
    
    # Archive and remove all .md and .sh files except essential
    find . -maxdepth 1 \( -name "*.md" -o -name "*.sh" -o -name "*.txt" -o -name "*.log" \) | while read file; do
        BASENAME=$(basename "$file")
        KEEP=0
        
        for keep_file in "${KEEP_FILES[@]}"; do
            if [ "$BASENAME" = "$keep_file" ]; then
                KEEP=1
                break
            fi
        done
        
        if [ $KEEP -eq 0 ] && [ -f "$file" ]; then
            echo "  → $BASENAME"
            cp "$file" "$ARCHIVE_DIR/"
            rm "$file"
        fi
    done
    
    cd ..
fi

# Archive old logs (keep only last 7 days)
echo ""
echo "Archiving old logs..."
if [ -d "var/logs" ]; then
    find var/logs -name "*.log-*" -mtime +7 -type f | while read file; do
        if [ -f "$file" ]; then
            echo "  → $(basename "$file")"
            gzip "$file"
            mv "${file}.gz" "$ARCHIVE_DIR/"
        fi
    done
fi

# Remove temporary files
echo ""
echo -e "${GREEN}🗑️  Removing temporary files...${NC}"
echo ""

TEMP_PATTERNS=(
    "*.tmp"
    "*.bak"
    "*~"
    "*.old"
    "*.backup"
    "*_backup_*"
)

for pattern in "${TEMP_PATTERNS[@]}"; do
    find . -maxdepth 2 -name "$pattern" -type f | while read file; do
        if [ -f "$file" ]; then
            echo "  → $(basename "$file")"
            rm "$file"
        fi
    done
done

# Compress archive
echo ""
echo -e "${GREEN}📦 Compressing archive...${NC}"
cd "$(dirname "$ARCHIVE_DIR")"
tar -czf "$(basename "$ARCHIVE_DIR").tar.gz" "$(basename "$ARCHIVE_DIR")"
rm -rf "$ARCHIVE_DIR"

ARCHIVE_SIZE=$(ls -lh "$(basename "$ARCHIVE_DIR").tar.gz" | awk '{print $5}')

echo ""
echo -e "${GREEN}✅ Cleanup complete!${NC}"
echo ""
echo "📊 Summary:"
echo "  - Archive created: $(basename "$ARCHIVE_DIR").tar.gz ($ARCHIVE_SIZE)"
echo "  - Old audits and reports removed from project"
echo "  - Temporary files cleaned"
echo "  - Old logs archived"
echo ""
echo "💡 To restore archived files:"
echo "   tar -xzf $(basename "$ARCHIVE_DIR").tar.gz"
echo ""
