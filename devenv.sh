#!/bin/bash
sudo pacman -S --noconfirm docker nodejs npm nvm
sudo npm i -g yarn
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
source ~/.zshrc
