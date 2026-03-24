#!/bin/bash
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
	postgresql-libs


sudo npm i -g yarn

sudo usermod -aG docker $USER
newgrp docker

sudo pacman -S php-gd php-igbinary php-redis php-grpc php-pgsql
yay -S php-pear php-protobuf phpenv
sudo pecl install decimal

echo "PHP extensions installed"
echo "update php.ini to enable"
echo "
extension=gd
extension=igbinary
extension=redis
extension=grpc
extension=decimal
extension=protobuf
extension=pdo_pgsql
"
