#!/bin/bash
sudo pacman -S --noconfirm docker docker-compose nodejs npm nvm aws-cli composer openssh
sudo npm i -g yarn
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash

sudo usermod -aG docker $USER
newgrp docker
