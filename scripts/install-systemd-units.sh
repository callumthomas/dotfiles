#!/usr/bin/env bash
# Install dotfiles' systemd user units by symlinking them into
# ~/.config/systemd/user/ and enabling them.
set -euo pipefail

SRC_DIR="$(cd "$(dirname "$0")/.." && pwd)/systemd/user"
DEST_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"

mkdir -p "$DEST_DIR"

for unit in "$SRC_DIR"/*.service; do
  name="$(basename "$unit")"
  ln -sfv "$unit" "$DEST_DIR/$name"
done

systemctl --user daemon-reload
echo "Installed units:"
ls -l "$DEST_DIR"/*.service
echo
echo "Next: enable each unit you want auto-started, e.g."
echo "  systemctl --user enable --now sibyl.service"
