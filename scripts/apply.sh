#!/bin/bash
rm -rf ~/.config/hypr
ln -s $(pwd)/hypr ~/.config/hypr

rm -rf ~/.config/waybar
ln -s $(pwd)/waybar ~/.config/waybar

rm -rf ~/.config/nvim
ln -s $(pwd)/nvim ~/.config/nvim

rm -rf ~/.config/fish
ln -s $(pwd)/fish ~/.config/fish

rm -rf ~/.config/ghostty
ln -s $(pwd)/ghostty ~/.config/ghostty

rm -f ~/.tmux.conf
ln -s $(pwd)/tmux/.tmux.conf ~/.tmux.conf

rm -rf ~/.config/sessions
ln -s $(pwd)/tmux/sessions ~/.config/sessions
