#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")/.."
sudo pacman -S --noconfirm \
	fprintd \
	brightnessctl \
	tlp \
	tlp-rdw

yay -S --noconfirm \
	thinkfan \
	evdi-dkms-git \
	displaylink \
	aylurs-gtk-shell-git \
	libastal-hyprland-git \
	libastal-wireplumber-git \
	libastal-network-git \
	libastal-bluetooth-git \
	libastal-battery-git \
	libastal-mpris-git \
	libastal-notifd-git \
	libastal-tray-git


sudo ln -sf "$SCRIPT_DIR/tlp/tlp.conf" /etc/tlp.conf
sudo systemctl enable --now tlp.service
sudo systemctl enable --now NetworkManager-dispatcher.service
sudo systemctl mask systemd-rfkill.service systemd-rfkill.socket

sudo ln -sf "$SCRIPT_DIR/modprobe/thinkpad_acpi.conf" /etc/modprobe.d/thinkpad_acpi.conf
sudo ln -sf "$SCRIPT_DIR/modprobe/mt7925e.conf" /etc/modprobe.d/mt7925e.conf

sudo systemctl disable --now wifi-resume.service 2>/dev/null || true
sudo rm -f /etc/systemd/system/wifi-resume.service
sudo ln -sf "$SCRIPT_DIR/system-sleep/wifi-mt7925e" /etc/systemd/system-sleep/wifi-mt7925e
sudo ln -sf "$SCRIPT_DIR/sysctl/90-inotify.conf" /etc/sysctl.d/90-inotify.conf
sudo sysctl --system >/dev/null
sudo ln -sf "$SCRIPT_DIR/thinkfan/thinkfan.yaml" /etc/thinkfan.yaml
sudo ln -sf "$SCRIPT_DIR/scripts/fan-set.sh" /usr/local/bin/fan-set
sudo cp "$SCRIPT_DIR/sudoers/fan-set" /etc/sudoers.d/fan-set
sudo chown root:root /etc/sudoers.d/fan-set
sudo chmod 440 /etc/sudoers.d/fan-set
sudo ln -sf "$SCRIPT_DIR/scripts/charge-set.sh" /usr/local/bin/charge-set
sudo cp "$SCRIPT_DIR/sudoers/charge-set" /etc/sudoers.d/charge-set
sudo chown root:root /etc/sudoers.d/charge-set
sudo chmod 440 /etc/sudoers.d/charge-set
sudo systemctl enable --now thinkfan.service
