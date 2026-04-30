#!/bin/bash
################################################################################
# CATEGORY IMAGE GENERATOR FOR AKENEO PIM
# Generates professional category images (hero banners + thumbnails)
# 
# @author Techno DZ
# @date 2026-04-29
################################################################################

set -e

# Configuration
OUTPUT_DIR="/home/pim/category_images"
HERO_SIZE="1920x600"
THUMB_SIZE="400x400"
ICON_SIZE="200x200"
DB_HOST="localhost"
DB_PORT="3307"
DB_NAME="akeneo_pim"
DB_USER="root"
DB_PASS=""

# Color scheme for categories
declare -A CATEGORY_COLORS=(
    ["default"]="#2C3E50,#3498DB"
    ["writing"]="#8E44AD,#9B59B6"
    ["office"]="#2980B9,#3498DB"
    ["school"]="#E67E22,#F39C12"
    ["art"]="#E74C3C,#C0392B"
    ["organization"]="#16A085,#1ABC9C"
    ["paper"]="#34495E,#7F8C8D"
    ["technology"]="#2C3E50,#34495E"
    ["gifts"]="#D35400,#E67E22"
    ["seasonal"]="#27AE60,#2ECC71"
)

echo ""
echo "========================================="
echo "  CATEGORY IMAGE GENERATOR"
echo "========================================="
echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Create output directories
mkdir -p "$OUTPUT_DIR"/{hero,thumbnail,icon}
echo "✓ Output directories created"

# Get categories from database
CATEGORIES=$(mysql --skip-ssl -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -D"$DB_NAME" -se "
    SELECT code, 
           COALESCE(
               JSON_UNQUOTE(JSON_EXTRACT(labels, '$.en_US')),
               JSON_UNQUOTE(JSON_EXTRACT(labels, '$.fr_FR')),
               code
           ) as label
    FROM pim_catalog_category 
    WHERE code != 'master'
    ORDER BY code
")

TOTAL=$(echo "$CATEGORIES" | wc -l)
echo "✓ Found $TOTAL categories to process"
echo ""

# Function to determine category color scheme
get_category_colors() {
    local category_name=$1
    local colors="${CATEGORY_COLORS[default]}"
    
    for key in "${!CATEGORY_COLORS[@]}"; do
        if [[ "$category_name" == *"$key"* ]] || [[ "$category_name" == *"${key^^}"* ]]; then
            colors="${CATEGORY_COLORS[$key]}"
            break
        fi
    done
    
    echo "$colors"
}

# Function to generate hero banner
generate_hero_banner() {
    local code=$1
    local label=$2
    local output="$OUTPUT_DIR/hero/${code}.jpg"
    
    # Get colors
    local colors=$(get_category_colors "$label")
    local color1=$(echo "$colors" | cut -d',' -f1)
    local color2=$(echo "$colors" | cut -d',' -f2)
    
    # Generate gradient background with text overlay
    convert -size $HERO_SIZE \
        gradient:"$color1"-"$color2" \
        -gravity center \
        -font Arial-Bold -pointsize 80 -fill white \
        -stroke '#00000080' -strokewidth 2 \
        -annotate +0+0 "$label" \
        -quality 85 \
        "$output"
}

# Function to generate thumbnail
generate_thumbnail() {
    local code=$1
    local label=$2
    local output="$OUTPUT_DIR/thumbnail/${code}.jpg"
    
    # Get colors
    local colors=$(get_category_colors "$label")
    local color1=$(echo "$colors" | cut -d',' -f1)
    local color2=$(echo "$colors" | cut -d',' -f2)
    
    # Generate square thumbnail with centered text
    convert -size $THUMB_SIZE \
        gradient:"$color1"-"$color2" \
        -gravity center \
        -font Arial-Bold -pointsize 36 -fill white \
        -stroke '#00000060' -strokewidth 1 \
        -annotate +0+0 "$(echo "$label" | fold -w 15 -s)" \
        -quality 85 \
        "$output"
}

# Function to generate icon
generate_icon() {
    local code=$1
    local label=$2
    local output="$OUTPUT_DIR/icon/${code}.jpg"
    
    # Get colors
    local colors=$(get_category_colors "$label")
    local color1=$(echo "$colors" | cut -d',' -f1)
    
    # Generate small icon with first letter
    local first_letter=$(echo "$label" | cut -c1 | tr '[:lower:]' '[:upper:]')
    
    convert -size $ICON_SIZE \
        xc:"$color1" \
        -gravity center \
        -font Arial-Bold -pointsize 120 -fill white \
        -stroke '#00000040' -strokewidth 2 \
        -annotate +0+0 "$first_letter" \
        -quality 85 \
        "$output"
}

# Process categories
PROCESSED=0
START_TIME=$(date +%s)

while IFS=$'\t' read -r code label; do
    # Clean label
    label=$(echo "$label" | sed 's/[^a-zA-Z0-9 ]//g' | xargs)
    [ -z "$label" ] && label="$code"
    
    # Generate images
    generate_hero_banner "$code" "$label" 2>/dev/null || true
    generate_thumbnail "$code" "$label" 2>/dev/null || true
    generate_icon "$code" "$label" 2>/dev/null || true
    
    ((PROCESSED++))
    
    # Progress indicator
    if [ $((PROCESSED % 10)) -eq 0 ]; then
        ELAPSED=$(($(date +%s) - START_TIME))
        RATE=$(echo "scale=1; $PROCESSED / $ELAPSED" | bc -l 2>/dev/null || echo "0")
        REMAINING=$((TOTAL - PROCESSED))
        ETA=$(echo "scale=0; $REMAINING / $RATE" | bc -l 2>/dev/null || echo "0")
        
        printf "\rProgress: %d/%d (%.1f%%) | Rate: %.1f/s | ETA: %02d:%02d:%02d" \
            $PROCESSED $TOTAL \
            $(echo "scale=1; ($PROCESSED * 100) / $TOTAL" | bc -l) \
            $RATE \
            $((ETA / 3600)) $(((ETA % 3600) / 60)) $((ETA % 60))
    fi
done <<< "$CATEGORIES"

echo ""
echo ""

# Summary
ELAPSED=$(($(date +%s) - START_TIME))
HERO_COUNT=$(find "$OUTPUT_DIR/hero" -name "*.jpg" | wc -l)
THUMB_COUNT=$(find "$OUTPUT_DIR/thumbnail" -name "*.jpg" | wc -l)
ICON_COUNT=$(find "$OUTPUT_DIR/icon" -name "*.jpg" | wc -l)
TOTAL_SIZE=$(du -sh "$OUTPUT_DIR" | cut -f1)

echo "========================================="
echo "  GENERATION COMPLETE"
echo "========================================="
echo "Categories processed: $PROCESSED"
echo "Hero banners (${HERO_SIZE}): $HERO_COUNT"
echo "Thumbnails (${THUMB_SIZE}): $THUMB_COUNT"
echo "Icons (${ICON_SIZE}): $ICON_COUNT"
echo "Total images: $((HERO_COUNT + THUMB_COUNT + ICON_COUNT))"
echo "Total size: $TOTAL_SIZE"
echo "Processing time: $(date -d@$ELAPSED -u +%H:%M:%S)"
echo ""
echo "Output directory: $OUTPUT_DIR/"
echo ""

# Generate CSV import file
CSV_FILE="$OUTPUT_DIR/category_images_import.csv"
echo "code,hero_image,thumbnail_image,icon_image" > "$CSV_FILE"

while IFS=$'\t' read -r code label; do
    echo "$code,$OUTPUT_DIR/hero/${code}.jpg,$OUTPUT_DIR/thumbnail/${code}.jpg,$OUTPUT_DIR/icon/${code}.jpg" >> "$CSV_FILE"
done <<< "$CATEGORIES"

echo "✓ CSV import file: $CSV_FILE"
echo ""

echo "NEXT STEPS:"
echo "1. Review images in: $OUTPUT_DIR/"
echo "2. Import via Akeneo UI or API"
echo "3. Assign to categories via bulk import"
echo "4. Sync to Magento: php bin/console akeneo:category:sync"
echo ""
echo "✓ Category image generation completed!"
