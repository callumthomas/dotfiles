#!/bin/bash
# Toggle system color-scheme between dark and light via gsettings
# Requires xdg-desktop-portal-gtk to serve the Settings portal to apps

CURRENT=$(gsettings get org.gnome.desktop.interface color-scheme)
PAPER_CONF="$HOME/.config/hypr/hyprpaper.conf"

if [ "$CURRENT" = "'prefer-dark'" ]; then
  gsettings set org.gnome.desktop.interface color-scheme 'prefer-light'
  WALLPAPER="~/.config/hypr/wallpaper/wave.jpeg"
else
  gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
  WALLPAPER="~/.config/hypr/wallpaper/wave-dark.png"
fi

sed -i "s|^\( *path *= *\).*|\1$WALLPAPER|" "$PAPER_CONF"

killall hyprpaper 2>/dev/null
for _ in 1 2 3 4 5 6 7 8 9 10; do
  pgrep -x hyprpaper >/dev/null || break
  sleep 0.1
done
hyprctl dispatch exec hyprpaper >/dev/null 2>&1
