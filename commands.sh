#!/usr/bin/env bash
#
# hyprquickpaper wallpaper backend dispatcher
# ---------------------------------------------
# You should NOT normally need to edit this file. Instead, set
# "wallpaper_tool" in config.json to one of:
#   swww | hyprpaper | waypaper | swaybg | feh | ml4w
#
# Only edit the case block below if you need a backend that isn't
# listed (e.g. a custom script, mpvpaper, etc).
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$DIR/config.json"
WALLPAPER="$1"
if [ -z "$WALLPAPER" ]; then
    exit 0
fi
TOOL=$(jq -r '.wallpaper_tool // "swww"' "$CONFIG")
case "$TOOL" in
    awww|swww)
        # Requires: exec-once = awww-daemon in hyprland.conf
        awww img "$WALLPAPER" --transition-type grow --transition-duration 1 --transition-fps 60
        ;;
    hyprpaper)
    hyprctl hyprpaper preload "$WALLPAPER" 2>/dev/null
    hyprctl hyprpaper wallpaper ",$WALLPAPER"
    ;;
    waypaper)
        waypaper --wallpaper "$WALLPAPER"
        ;;
    swaybg)
        pkill swaybg 2>/dev/null
        swaybg -i "$WALLPAPER" -m fill &
        ;;
    feh)
        # X11 / XWayland only — not truly Wayland-native
        feh --bg-fill "$WALLPAPER"
        ;;
    ml4w)
        # Only works if you actually have the full ML4W dotfiles installed.
        "$HOME/.config/ml4w/scripts/ml4w-wallpaper" "$WALLPAPER"
        ;;
    *)
        echo "hyprquickpaper: unknown wallpaper_tool '$TOOL' in config.json, defaulting to swww" >&2
        swww img "$WALLPAPER" --transition-type grow --transition-duration 1
        ;;
esac

# Track the active wallpaper ourselves so the picker can highlight it
# the next time it opens, regardless of what backend you use.
# See shell-*.qml's "activeWallpaperFile" — point it at this same path.
mkdir -p "$HOME/.cache/hyprquickpaper"
echo "$WALLPAPER" > "$HOME/.cache/hyprquickpaper/current_wallpaper"

# --- Optional: keep a copy of the current wallpaper at a fixed path ---
# Set "stable_copy_path" in config.json (e.g. "~/Pictures/wallpaper.png")
# if you want some OTHER tool (a lock screen, a status-bar script, a
# theming script) to always be able to read the current wallpaper from
# one unchanging filename, instead of parsing current_wallpaper above.
# Leave it empty ("") in config.json to skip this entirely.
STABLE_COPY_PATH=$(jq -r '.stable_copy_path // ""' "$CONFIG")
if [ -n "$STABLE_COPY_PATH" ]; then
    EXPANDED_COPY_PATH="${STABLE_COPY_PATH/#\~/$HOME}"
    mkdir -p "$(dirname "$EXPANDED_COPY_PATH")"
    cp "$WALLPAPER" "$EXPANDED_COPY_PATH"
fi

# --- Optional: run your own commands after every wallpaper change ---
# Anything here runs after the wallpaper is set, no matter which
# wallpaper_tool you picked above. Useful for things like:
#   - regenerating a colorscheme from the new wallpaper (pywal, wallust)
#   - reloading bars/notification daemons/other apps so they pick up
#     the new colors
#   - re-theming other apps (browser, Spotify, OSD, etc.)
# These are commented out by default since they depend entirely on
# YOUR setup — uncomment and adapt only the ones you actually use.
#
# wallust run "$WALLPAPER"
# killall -SIGUSR2 waybar
# swaync-client -rs
