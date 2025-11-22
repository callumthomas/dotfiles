#!/bin/bash
# ~/.config/hypr/scripts/toggle-theme.sh

STATE_FILE="$HOME/.config/hypr/.theme-state"

# Read current state (default to dark)
if [ -f "$STATE_FILE" ]; then
    CURRENT=$(cat "$STATE_FILE")
else
    CURRENT="dark"
fi

# Toggle state
if [ "$CURRENT" = "dark" ]; then
    NEW_STATE="light"
    
    # Thunar - GTK theme
    gsettings set org.gnome.desktop.interface gtk-theme "Adwaita"
    gsettings set org.gnome.desktop.interface color-scheme "prefer-light"
    
    # Firefox - through environment (requires restart, but we can trigger profile preference)
    # For live switching, Firefox needs to be configured to respect system theme
    
    # Hyprpaper - change wallpaper
    hyprctl hyprpaper wallpaper "eDP-1,/path/to/your/light-wallpaper.jpg"
    
else
    NEW_STATE="dark"
    
    # Thunar - GTK theme
    gsettings set org.gnome.desktop.interface gtk-theme "Adwaita-dark"
    gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"
    
    # Hyprpaper - change wallpaper
    hyprctl hyprpaper wallpaper "eDP-1,/path/to/your/dark-wallpaper.jpg"
fi

# Save new state
echo "$NEW_STATE" > "$STATE_FILE"

# Optional: Send notification
notify-send "Theme Toggle" "Switched to $NEW_STATE mode"
