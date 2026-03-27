#!/bin/bash

# Set PATH to include common binary locations
export PATH=/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin:/usr/local/cpanel/3rdparty/bin:$PATH

# Load NVM and set Node.js version
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm use 16 >/dev/null 2>&1 || nvm use default

# Colors for better readability
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Error handling
set -e
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
trap 'echo -e "${RED}Error: command \"${last_command}\" failed${NC}"' ERR

# Function to execute commands as pim user
run_as_pim() {
    "$@"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check required commands
check_requirements() {
    echo -e "${BLUE}Checking requirements...${NC}"
    required_commands=("php" "yarn" "node")
    
    for cmd in "${required_commands[@]}"; do
        if ! command_exists "$cmd"; then
            echo -e "${RED}Error: $cmd is not installed${NC}"
            exit 1
        fi
    done
}

# Function to set proper permissions
fix_permissions() {
    echo -e "${BLUE}Setting correct permissions...${NC}"
    
    # Create directories if they don't exist
    directories=(
        "var/cache"
        "var/logs"
        "var/uploads"
        "var/file_storage"
        "public/bundles"
        "public/media"
        "public/css"
        "public/js"
        "public/dist"
    )
    
    for dir in "${directories[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
        fi
    done
    
    # Set ownership for Apache/web server user (nobody)
    if command -v sudo >/dev/null 2>&1; then
        sudo chown -R pim:nobody var/cache var/logs var/uploads var/file_storage
        sudo chown -R pim:nobody public/bundles public/media public/css public/js public/dist
        
        # Set directory permissions with sudo
        sudo find var/cache var/logs var/uploads var/file_storage -type d -exec chmod 775 {} \;
        sudo find var/cache var/logs var/uploads var/file_storage -type f -exec chmod 664 {} \;
        sudo find public/bundles public/media public/css public/js public/dist -type d -exec chmod 775 {} \;
        sudo find public/bundles public/media public/css public/js public/dist -type f -exec chmod 664 {} \;
        
        # Ensure executables maintain permissions
        sudo find bin -type f -exec chmod 775 {} \;
        
        # Set specific ACLs if supported
        if command -v setfacl >/dev/null 2>&1; then
            sudo setfacl -R -m u:nobody:rwx -m u:pim:rwx var/cache var/logs var/uploads var/file_storage
            sudo setfacl -R -m u:nobody:rx -m u:pim:rwx public/bundles public/media public/css public/js public/dist
            sudo setfacl -dR -m u:nobody:rwx -m u:pim:rwx var/cache var/logs var/uploads var/file_storage
        fi
    else
        # Fallback if sudo is not available
        chown -R pim:nobody var/cache var/logs var/uploads var/file_storage public/bundles public/media public/css public/js public/dist
        chmod -R 775 var/cache var/logs var/uploads var/file_storage
        chmod -R 775 public/bundles public/media public/css public/js public/dist
        find bin -type f -exec chmod 775 {} \;
    fi
    
    # Set umask for new files
    umask 002
}

# Function to clear cache and optimize
clear_cache() {
    echo -e "${BLUE}Clearing and optimizing cache...${NC}"
    
    # Stop on errors
    set -e
    
    # Clear Symfony cache with proper permissions
    echo -e "${BLUE}Clearing Symfony cache...${NC}"
    if command -v sudo >/dev/null 2>&1; then
        sudo rm -rf var/cache/*
    else
        rm -rf var/cache/*
    fi
    
    # Clear and warmup Symfony cache
    run_as_pim php bin/console cache:clear --env=prod --no-warmup
    run_as_pim php bin/console cache:warmup --env=prod
    
    # Clear Redis cache if available
    if command_exists redis-cli && redis-cli ping >/dev/null 2>&1; then
        echo -e "${BLUE}Clearing Redis cache...${NC}"
        redis-cli flushall
    fi
    
    # Clear asset cache
    echo -e "${BLUE}Clearing asset cache...${NC}"
    if [ -d "public/bundles" ]; then
        rm -rf public/bundles/*
    fi
    if [ -d "public/media/cache" ]; then
        rm -rf public/media/cache/*
    fi
    
    # Rebuild assets
    echo -e "${BLUE}Rebuilding assets...${NC}"
    run_as_pim php bin/console pim:installer:assets --env=prod --clean
    run_as_pim php bin/console assets:install --env=prod --symlink
    
    # Clear and warmup Doctrine cache
    echo -e "${BLUE}Clearing Doctrine cache...${NC}"
    run_as_pim php bin/console doctrine:cache:clear-metadata --env=prod
    run_as_pim php bin/console doctrine:cache:clear-query --env=prod
    run_as_pim php bin/console doctrine:cache:clear-result --env=prod
    
    # Reindex Elasticsearch
    echo -e "${BLUE}Reindexing Elasticsearch...${NC}"
    run_as_pim php bin/console akeneo:elasticsearch:reset-indexes --env=prod
    run_as_pim php bin/console pim:product:index --all --env=prod
    
    # Fix permissions after cache operations
    fix_permissions
    
    echo -e "${GREEN}Cache operations completed successfully${NC}"
}

# Function to install/update dependencies
install_dependencies() {
    echo -e "${BLUE}Installing/updating dependencies...${NC}"
    run_as_pim php composer.phar install --no-interaction --optimize-autoloader
    run_as_pim yarn install
}

# Function to build assets
build_assets() {
    echo -e "${BLUE}Building assets...${NC}"
    
    # Ensure proper Node.js version and memory limit
    nvm use 16 >/dev/null 2>&1 || nvm use default
    export NODE_OPTIONS="--max-old-space-size=4096"
    
    # Clean existing assets - using find to avoid glob expansion issues
    if [ -d "public/bundles" ]; then
        find public/bundles -mindepth 1 -delete
    fi
    if [ -d "public/css" ]; then
        find public/css -mindepth 1 -delete
    fi
    if [ -d "public/js" ]; then
        find public/js -mindepth 1 -delete
    fi
    
    # Dump required paths for webpack
    php bin/console pim:installer:dump-require-paths --env=prod
    
    # Install assets
    php bin/console pim:installer:assets --env=prod --clean
    
    # Build webpack assets
    yarn webpack --env=prod
    
    # Generate version file for cache busting
    php bin/console pim:installer:assets-version --env=prod
}

# Function to optimize for production
optimize_production() {
    echo -e "${BLUE}Optimizing for production...${NC}"
    
    # Optimize Composer's autoloader
    run_as_pim php composer.phar dump-autoload --optimize --classmap-authoritative --no-dev
    
    # Optimize database
    run_as_pim php bin/console doctrine:schema:validate --env=prod
    
    # Clear and warmup cache with optimizations
    clear_cache
    
    # Optimize assets
    echo -e "${BLUE}Optimizing assets...${NC}"
    run_as_pim php bin/console assets:install --env=prod --symlink
    run_as_pim php bin/console pim:installer:assets-version --env=prod
    run_as_pim yarn cache clean
    
    # Set proper file permissions
    fix_permissions
    
    # Validate Elasticsearch configuration
    echo -e "${BLUE}Validating Elasticsearch...${NC}"
    run_as_pim php bin/console akeneo:elasticsearch:reset-indexes --env=prod
}

# Main script logic
case "$1" in
    "install")
        check_requirements
        fix_permissions
        install_dependencies
        clear_cache
        build_assets
        optimize_production
        echo -e "${GREEN}Installation completed successfully${NC}"
        ;;
        
    "update")
        check_requirements
        fix_permissions
        install_dependencies
        clear_cache
        build_assets
        echo -e "${GREEN}Update completed successfully${NC}"
        ;;
        
    "assets")
        check_requirements
        fix_permissions
        build_assets
        echo -e "${GREEN}Assets rebuilt successfully${NC}"
        ;;
        
    "permissions")
        fix_permissions
        echo -e "${GREEN}Permissions fixed successfully${NC}"
        ;;
        
    "cache")
        clear_cache
        echo -e "${GREEN}Cache cleared successfully${NC}"
        ;;
        
    "optimize")
        optimize_production
        echo -e "${GREEN}Production optimization completed successfully${NC}"
        ;;
        
    *)
        echo -e "${BLUE}Akeneo PIM Platform Management Script${NC}"
        echo -e "Usage: $0 {install|update|assets|permissions|cache|optimize}"
        echo -e "  ${GREEN}install${NC}     - Full installation and setup"
        echo -e "  ${GREEN}update${NC}      - Update dependencies and rebuild"
        echo -e "  ${GREEN}assets${NC}      - Rebuild frontend assets"
        echo -e "  ${GREEN}permissions${NC}  - Fix file permissions"
        echo -e "  ${GREEN}cache${NC}       - Clear and warmup cache"
        echo -e "  ${GREEN}optimize${NC}    - Optimize for production"
        exit 1
        ;;
esac

exit 0