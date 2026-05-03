#!/bin/bash

# Determine the correct PIM URL
if [ -f "public/index.php" ]; then
    # Check if we're running on a specific domain
    if [ -n "$HOSTNAME" ]; then
        echo "http://$HOSTNAME/public/index.php"
    else
        echo "http://localhost/public/index.php"
    fi
else
    echo "http://localhost/index.php"
fi
