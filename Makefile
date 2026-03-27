#
# This file is a template Makefile. Some targets are presented here as examples.
# Feel free to customize it to your needs!
#
CMD_ON_PROJECT = docker-compose run -u www-data --rm php
PHP_RUN = $(CMD_ON_PROJECT) php
YARN_RUN = docker-compose run -u node --rm -e YARN_REGISTRY -e PUPPETEER_SKIP_CHROMIUM_DOWNLOAD node yarn

ifdef NO_DOCKER
  CMD_ON_PROJECT =
  YARN_RUN = yarnpkg
  PHP_RUN = php
endif

.DEFAULT_GOAL := dev

yarn.lock: package.json
	PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=1 $(YARN_RUN) install

node_modules: yarn.lock
	PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=1 $(YARN_RUN) install

.PHONY: javascript-extensions
javascript-extensions:
	$(YARN_RUN) run update-extensions

.PHONY: front-packages
front-packages:
	$(YARN_RUN) run packages:build

.PHONY: assets
assets:
	$(CMD_ON_PROJECT) mkdir -p public/bundles public/js
	$(PHP_RUN) bin/console pim:installer:assets --symlink --clean

.PHONY: css
css:
	$(CMD_ON_PROJECT) mkdir -p public/css
	$(YARN_RUN) run less

.PHONY: javascript-prod
javascript-prod:
	$(CMD_ON_PROJECT) mkdir -p public/dist
	$(YARN_RUN) run webpack

.PHONY: javascript-dev
javascript-dev:
	$(CMD_ON_PROJECT) mkdir -p public/dist
	$(YARN_RUN) run webpack-dev

.PHONY: front
front: assets css front-packages javascript-dev

.PHONY: database
database:
	$(PHP_RUN) bin/console pim:installer:db ${O}

.PHONY: cache
cache:
	$(CMD_ON_PROJECT) rm -rf var/cache && $(PHP_RUN) bin/console cache:warmup

composer.lock: composer.json
	$(PHP_RUN) -d memory_limit=4G /opt/cpanel/composer/bin/composer update --ignore-platform-req=ext-apcu

vendor: composer.lock
	$(PHP_RUN) -d memory_limit=4G /opt/cpanel/composer/bin/composer install --ignore-platform-req=ext-apcu

.PHONY: dependencies
dependencies: vendor node_modules

.PHONY: dev
dev:
	$(MAKE) dependencies
	$(MAKE) pim-dev

.PHONY: prod
prod:
	$(MAKE) dependencies
	$(MAKE) pim-prod

.PHONY: pim-prod
pim-prod:
ifndef NO_DOCKER
	APP_ENV=prod $(MAKE) up
	docker/wait_docker_up.sh
endif
	$(MAKE) cache
	$(MAKE) assets
	$(MAKE) front-packages
	$(MAKE) javascript-prod
	$(MAKE) css
	$(MAKE) javascript-extensions
	APP_ENV=prod $(MAKE) database O="--catalog vendor/akeneo/pim-community-dev/src/Akeneo/Platform/Bundle/InstallerBundle/Resources/fixtures/minimal"

.PHONY: pim-dev
pim-dev:
ifndef NO_DOCKER
	APP_ENV=dev $(MAKE) up
	docker/wait_docker_up.sh
endif
	$(MAKE) cache
	$(MAKE) assets
	$(MAKE) front-packages
	$(MAKE) javascript-dev
	$(MAKE) css
	$(MAKE) javascript-extensions
	APP_ENV=dev $(MAKE) database O="--catalog vendor/akeneo/pim-community-dev/src/Akeneo/Platform/Bundle/InstallerBundle/Resources/fixtures/icecat_demo_dev"

.PHONY: up
up:
	docker-compose up -d --remove-orphans

.PHONY: down
down:
	docker-compose down -v

.PHONY: upgrade-front
upgrade-front:
	$(MAKE) node_modules
	$(MAKE) cache
	$(MAKE) assets
	$(MAKE) front-packages
	$(MAKE) javascript-prod
	$(MAKE) css
	$(MAKE) javascript-extensions

# Makefile for Akeneo PIM

# Detect if docker-compose is available
DOCKER_COMPOSE_AVAILABLE := $(shell command -v docker-compose 2> /dev/null)

# If docker-compose is not available, set NO_DOCKER=1
ifeq ($(DOCKER_COMPOSE_AVAILABLE),)
    NO_DOCKER=1
endif

# Default environment
ENV ?= dev

# PHP command
PHP = php

# Yarn command
YARN = yarnpkg

# Console command
CONSOLE = $(PHP) bin/console

# Assets installation
assets:
	mkdir -p public/bundles public/js
	$(CONSOLE) pim:installer:assets --symlink --clean

# CSS compilation
css:
	mkdir -p public/css
	$(YARN) run less

# JavaScript development build
javascript-dev:
	mkdir -p public/dist
	$(YARN) run webpack --config ./custom-webpack.config.js --env=dev

# JavaScript production build
javascript-prod:
	mkdir -p public/dist
	$(YARN) run webpack --config ./custom-webpack.config.js --env=prod

# Database setup
database:
	$(CONSOLE) doctrine:database:create --if-not-exists
	$(CONSOLE) pim:installer:db --env=$(ENV)

# Cache operations
cache:
	$(CONSOLE) cache:clear --env=$(ENV)
	$(CONSOLE) cache:warmup --env=$(ENV)

# Install composer dependencies
composer:
	composer install

# Install yarn dependencies
yarn:
	$(YARN) install

# Frontend build
front: assets css javascript-prod

# Development mode
dev: assets css javascript-dev

# Production mode
prod: assets css javascript-prod

.PHONY: assets css javascript-dev javascript-prod database cache composer yarn front dev prod
