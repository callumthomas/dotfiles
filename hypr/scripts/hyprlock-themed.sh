#!/bin/bash
# Launch hyprlock with the config that matches the current GTK color-scheme.

SCHEME=$(gsettings get org.gnome.desktop.interface color-scheme)

if [ "$SCHEME" = "'prefer-dark'" ]; then
  exec hyprlock --config ~/.config/hypr/hyprlock-dark.conf
else
  exec hyprlock --config ~/.config/hypr/hyprlock.conf
fi
