#!/usr/bin/env bash
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")/.."

rm -rf ~/.config/hypr
ln -s "$SCRIPT_DIR/hypr" ~/.config/hypr

rm -rf ~/.config/ags
ln -s "$SCRIPT_DIR/ags" ~/.config/ags

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

ln -sf "$SCRIPT_DIR/ssh/aws-ssm-ec2-proxy-command.sh" ~/.ssh/aws-ssm-ec2-proxy-command.sh

mv ~/.claude ~/.claude_old
ln -s "$SCRIPT_DIR/claude" ~/.claude

sudo ln -sf "$SCRIPT_DIR/tlp/tlp.conf" /etc/tlp.conf
sudo systemctl enable --now tlp.service
sudo systemctl enable --now NetworkManager-dispatcher.service
sudo systemctl mask systemd-rfkill.service systemd-rfkill.socket

rm -rf ~/.config/gammastep
ln -s "$SCRIPT_DIR/gammastep" ~/.config/gammastep

sudo ln -sf "$SCRIPT_DIR/modprobe/thinkpad_acpi.conf" /etc/modprobe.d/thinkpad_acpi.conf
sudo ln -sf "$SCRIPT_DIR/modprobe/mt7925e.conf" /etc/modprobe.d/mt7925e.conf
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
