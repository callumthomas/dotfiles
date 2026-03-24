#!/bin/bash
sudo pacman -S --noconfirm \
	base-devel \
	git \
	ghostty \
	fish \
	firefox \
	nvim \
	hyprlock \
	hyprpaper \
	hypridle \
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
	ttf-cascadia-code-nerd \
	lsof \
	gammastep \
	btop 

sudo pacman -Rns dolphin kitty

git clone https://aur.archlinux.org/yay.git /tmp/yay && cd /tmp/yay && makepkg -si

yay -S --noconfirm \
	hyprcap \
	claude-code \
	clipse
