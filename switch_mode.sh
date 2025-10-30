#!/bin/bash

if [ "$1" = "prod" ]; then
    echo "Switching to production mode..."
    cp .env.prod .env
    echo "APP_ENV=prod" > .env.local
    echo "Production mode activated"
elif [ "$1" = "dev" ]; then
    echo "Switching to development mode..."
    cp .env.local .env
    echo "Development mode activated"
else
    echo "Usage: ./switch_mode.sh [dev|prod]"
    exit 1
fi

# Clear cache
rm -rf var/cache/*
echo "Cache cleared"