#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")/.."

link() {
	local src="$1" dst="$2"
	# If dst exists and isn't already pointing where we want, back it up.
	if [[ -e "$dst" || -L "$dst" ]] && [[ "$(readlink -- "$dst" 2>/dev/null || true)" != "$src" ]]; then
		mv -n -- "$dst" "${dst}.bak.$(date +%s)" 2>/dev/null || rm -rf -- "$dst"
	fi
	ln -sfn -- "$src" "$dst"
}

link "$SCRIPT_DIR/hypr"        ~/.config/hypr
link "$SCRIPT_DIR/ags"         ~/.config/ags
link "$SCRIPT_DIR/nvim"        ~/.config/nvim
link "$SCRIPT_DIR/fish"        ~/.config/fish
link "$SCRIPT_DIR/ghostty"     ~/.config/ghostty
link "$SCRIPT_DIR/gammastep"   ~/.config/gammastep
link "$SCRIPT_DIR/tmux/.tmux.conf" ~/.tmux.conf
link "$SCRIPT_DIR/tmux/sessions"   ~/.config/sessions
link "$SCRIPT_DIR/ssh/config"  ~/.ssh/config
link "$SCRIPT_DIR/ssh/aws-ssm-ec2-proxy-command.sh" ~/.ssh/aws-ssm-ec2-proxy-command.sh
link "$SCRIPT_DIR/claude"      ~/.claude
