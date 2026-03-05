#!/usr/bin/env bash
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")/.."

rm -rf ~/.config/hypr
ln -s "$SCRIPT_DIR/hypr" ~/.config/hypr

rm -rf ~/.config/waybar
ln -s "$SCRIPT_DIR/waybar" ~/.config/waybar

rm -rf ~/.config/nvim
ln -s "$SCRIPT_DIR/nvim" ~/.config/nvim

rm -rf ~/.config/fish
ln -s "$SCRIPT_DIR/fish" ~/.config/fish

rm -rf ~/.config/ghostty
ln -s "$SCRIPT_DIR/ghostty" ~/.config/ghostty

rm -f ~/.tmux.conf
ln -s "$SCRIPT_DIR/tmux/.tmux.conf" ~/.tmux.conf

rm -rf ~/.config/sessions
ln -s "$SCRIPT_DIR/tmux/sessions" ~/.config/sessions

mv ~/.ssh/config ~/.ssh/config_old
ln -s "$SCRIPT_DIR/ssh/config" ~/.ssh/config

mv ~/.claude ~/.claude_old
ln -s "$SCRIPT_DIR/claude" ~/.claude 
