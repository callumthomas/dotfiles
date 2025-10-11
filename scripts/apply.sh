#!/bin/bash
rm -rf ~/.config/hypr
ln -s $(pwd)/hypr ~/.config/hypr

rm -rf ~/.config/waybar
ln -s $(pwd)/waybar ~/.config/waybar

rm -rf ~/.config/nvim
ln -s $(pwd)/nvim ~/.config/nvim

rm ~/.zshrc
ln -s $(pwd)/.zshrc ~/.zshrc
