#!/bin/bash
sudo pacman -S --noconfirm docker docker-compose nodejs npm nvm aws-cli-v2 composer openssh kubectl mysql-clients postgresql-libs
sudo npm i -g yarn
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash

sudo usermod -aG docker $USER
newgrp docker

sudo pacman -S php-gd php-igbinary php-redis php-grpc
yay -S php-pear php-protobuf
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
"
