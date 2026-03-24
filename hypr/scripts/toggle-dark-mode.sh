#!/bin/bash
# Toggle system color-scheme between dark and light via gsettings
# Requires xdg-desktop-portal-gtk to serve the Settings portal to apps

CURRENT=$(gsettings get org.gnome.desktop.interface color-scheme)

if [ "$CURRENT" = "'prefer-dark'" ]; then
  gsettings set org.gnome.desktop.interface color-scheme 'prefer-light'
else
  gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
fi
