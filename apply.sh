#!/bin/bash
rm ~/.config/hypr/*.conf
ln -s $(pwd)/hypr/hyprland.conf ~/.config/hypr/hyprland.conf
ln -s $(pwd)/hypr/hyprlock.conf ~/.config/hypr/hyprlock.conf

rm ~/.config/waybar/*
ln -s config.jsonc ~/.config/waybar/config.jsonc
ln -s style.css ~/.config/waybar/style.css

rm ~/.zshrc
ln -s $(pwd)/.zshrc ~/.zshrc
