#!/bin/bash
set -euo pipefail
sudo pacman -S --noconfirm \
	docker \
	docker-compose \
	openssh \
	aws-cli-v2 \
	kubectl \
	nodejs \
	npm \
	nvm \
	composer \
	mysql-clients \
	postgresql-libs \
	postgresql \
	k9s

paru -S --noconfirm \
	datagrip \
	datagrip-jre

sudo npm i -g yarn

sudo usermod -aG docker $USER
echo "Note: log out and back in for 'docker' group membership to take effect"

sudo pacman -S php-gd php-igbinary php-redis php-grpc php-pgsql
paru -S php-pear php-protobuf phpenv
sudo pecl install decimal

# Enable PHP extensions in /etc/php/php.ini (idempotent — no-op once uncommented)
sudo sed -i 's/^;extension=gd$/extension=gd/' /etc/php/php.ini
sudo sed -i 's/^;extension=igbinary$/extension=igbinary/' /etc/php/php.ini
sudo sed -i 's/^;extension=redis$/extension=redis/' /etc/php/php.ini
sudo sed -i 's/^;extension=grpc$/extension=grpc/' /etc/php/php.ini
sudo sed -i 's/^;extension=decimal$/extension=decimal/' /etc/php/php.ini
sudo sed -i 's/^;extension=protobuf$/extension=protobuf/' /etc/php/php.ini
sudo sed -i 's/^;extension=pdo_pgsql$/extension=pdo_pgsql/' /etc/php/php.ini
