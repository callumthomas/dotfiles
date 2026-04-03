#!/bin/bash
sudo pacman -S --noconfirm \
	base-devel \
	linux-headers \
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
	btop \
	dart-sass \
	xdg-desktop-portal-gtk

sudo pacman -Rns dolphin kitty

git clone https://aur.archlinux.org/yay.git /tmp/yay && cd /tmp/yay && makepkg -si

yay -S --noconfirm \
	hyprcap \
	claude-code \
	clipse \
	aylurs-gtk-shell-git \
	libastal-hyprland-git \
	libastal-wireplumber-git \
	libastal-network-git \
	libastal-bluetooth-git \
	libastal-battery-git \
	libastal-mpris-git \
	libastal-notifd-git \
	libastal-tray-git
