#!/bin/bash

prompt_confirm() {
  while true; do
    read -r -p "${1:-Proceed?} [y/n]: " REPLY
    case $REPLY in
    [yY])
      echo "Installing oh-my-zsh..."
      return 0
      ;;
    [nN])
      echo "Skipping."
      return 1
      ;;
    *) echo "Invalid input, please answer y or n." ;;
    esac
  done
}

sudo pacman -S --noconfirm docker docker-compose nodejs npm nvm aws-cli-v2 composer openssh kubectl mysql-clients postgresql-libs
sudo npm i -g yarn

if prompt_confirm "Install nvm?"; then
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
fi

sudo usermod -aG docker $USER
newgrp docker

sudo pacman -S php-gd php-igbinary php-redis php-grpc php-pgsql
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
extension=pdo_pgsql
"
