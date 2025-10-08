#!/bin/bash
rm ~/.config/hypr/*.conf
ln -s $(pwd)/hypr/hyprland.conf ~/.config/hypr/hyprland.conf
ln -s $(pwd)/hypr/hyprlock.conf ~/.config/hypr/hyprlock.conf

rm ~/.zshrc
ln -s $(pwd)/.zshrc ~/.zshrc
