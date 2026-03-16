#!/bin/bash
sudo pacman -S --noconfirm \
	git \
	ghostty \
	fish \
	firefox \
	nvim \
	hyprlock \
	hyprpaper \
	less \
	wl-clipboard \
	tmux \
	waybar \
	ttf-font-awesome \
	otf-font-awesome \
	thunar \
	ripgrep \
	lazygit \
	socat \
	glow \
	ttf-cascadia-code-nerd 

sudo pacman -Rns dolphin kitty

git clone https://aur.archlinux.org/yay.git /tmp/yay && cd /tmp/yay && makepkg -si

yay -S --noconfirm \
	hyprcap \
	claude-code
