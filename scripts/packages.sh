#!/bin/bash
sudo pacman -S --noconfirm \
	base-devel \
	cmake \
	rust \
	linux-headers \
	git \
	ghostty \
	fish \
	firefox \
	neovim \
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
	tree-sitter-cli \
	lazygit \
	socat \
	glow \
	ttf-cascadia-code-nerd \
	lsof \
	gammastep \
	btop \
	fd \
	fzf \
	jq \
	aws-cli \
	kubectl \
	lazydocker \
	upower \
	inotify-tools \
	dart-sass \
	libnotify \
	python \
	xdg-desktop-portal-gtk \
	eza \
	bat

sudo pacman -Rns dolphin kitty

git clone https://aur.archlinux.org/paru.git /tmp/paru && cd /tmp/paru && makepkg -si

paru -S --noconfirm \
	hyprcap \
	claude-code \
	clipse

# AGS / Astal — required for the ags bar
paru -S --noconfirm \
	aylurs-gtk-shell-git \
	libastal-hyprland-git \
	libastal-wireplumber-git \
	libastal-network-git \
	libastal-bluetooth-git \
	libastal-battery-git \
	libastal-mpris-git \
	libastal-notifd-git \
	libastal-tray-git
