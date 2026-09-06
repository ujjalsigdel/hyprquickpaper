#!/usr/bin/env bash

# Example for SWWW:
# swww img "$WALLPAPER" --transition-type grow --transition-duration 1

# This is specifically for ml4w hyprland
WALLPAPER="$1"

if [ -n "$WALLPAPER" ]; then
    $HOME/.config/ml4w/scripts/ml4w-wallpaper "$WALLPAPER"
fi
