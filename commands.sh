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
    swww)
        # Requires: exec-once = swww-daemon in your hyprland.conf
        swww img "$WALLPAPER" --transition-type grow --transition-duration 1 --transition-fps 60
        ;;

    hyprpaper)
        # unload all first so old wallpapers don't pile up in memory
        hyprctl hyprpaper unload all
        hyprctl hyprpaper preload "$WALLPAPER"
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
