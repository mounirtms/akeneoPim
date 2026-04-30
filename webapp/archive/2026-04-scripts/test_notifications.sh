#!/bin/bash
# Test script for email notifications

PIM_ROOT="/home/pim/public_html"
cd "$PIM_ROOT" || exit 1

echo "Testing email notification system..."
echo ""
echo "Available event subscribers:"
php bin/console debug:event-dispatcher --env=prod 2>/dev/null | grep -E "(Product|Category|Model|System)" || echo "Could not list event subscribers"

echo ""
echo "Mailer configuration:"
php bin/console debug:config framework mailer --env=prod 2>/dev/null || echo "Could not display mailer config"

echo ""
echo "To manually trigger a test notification, create/update a product in the PIM."
