#!/usr/bin/env bash
#
# hyprquickpaper wallpaper backend dispatcher
# ---------------------------------------------
# You should NOT normally need to edit this file. Instead, set
# "wallpaper_tool" in config.json to one of:
#   awww | hyprpaper | waypaper | swaybg | feh | ml4w
#
# Video files (mp4/webm/mov/etc, see "video_extensions" in config.json)
# are always played through mpvpaper, regardless of "wallpaper_tool" —
# none of the static-image backends above can render video.
#
# Only edit the case block below if you need a backend that isn't
# listed (e.g. a custom script).
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$DIR/config.json"
source "$DIR/common.sh"

WALLPAPER="$1"
if [ -z "$WALLPAPER" ]; then
    exit 0
fi

TOOL=$(jq -r '.wallpaper_tool // "awww"' "$CONFIG")
VIDEO_EXT_PATTERN=$(get_video_extensions_pattern "$CONFIG")

# ALWAYS kill any running video wallpaper first, whether we're about to
# set an image or a different video — otherwise the old mpvpaper process
# keeps rendering underneath/instead of the new wallpaper.
pkill mpvpaper 2>/dev/null

if is_video "$WALLPAPER" "$VIDEO_EXT_PATTERN"; then
    echo "Detected video file: $WALLPAPER"

    if command -v mpvpaper &>/dev/null; then
        MONITOR=$(get_monitor_output)
        echo "Using monitor: $MONITOR"

        # -f forks mpvpaper into the background itself, so we don't also
        # need a trailing '&' here.
        mpvpaper -f -o "no-audio loop" "$MONITOR" "$WALLPAPER"

        sleep 1
        if pgrep -f "mpvpaper.*$WALLPAPER" >/dev/null; then
            echo "✅ Video wallpaper started successfully on $MONITOR"
        else
            echo "⚠️  mpvpaper may not have started correctly"
        fi
    else
        echo "Error: mpvpaper not found. Please install it for video wallpapers."
        echo "  Arch: sudo pacman -S mpvpaper"
        exit 1
    fi
else
    echo "Using $TOOL for image wallpaper: $WALLPAPER"

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
            echo "hyprquickpaper: unknown wallpaper_tool '$TOOL' in config.json, defaulting to awww" >&2
            awww img "$WALLPAPER" --transition-type grow --transition-duration 1
            ;;
    esac
fi

# Track the active wallpaper ourselves so the picker can highlight it
# the next time it opens, regardless of what backend/type you used.
mkdir -p "$HOME/.cache/hyprquickpaper"
echo "$WALLPAPER" > "$HOME/.cache/hyprquickpaper/current_wallpaper"

# --- Optional: keep a copy of the current wallpaper at a fixed path ---
# Set "stable_copy_path" in config.json (e.g. "~/Pictures/wallpaper.png")
# if you want some OTHER tool (a lock screen, a status-bar script, a
# theming script) to always be able to read the current wallpaper from
# one unchanging filename. Leave it empty ("") in config.json to skip
# this entirely.
#
# For video wallpapers we copy the cached *thumbnail* (a still jpg)
# rather than the raw video file, since anything reading stable_copy_path
# almost certainly expects a static image.
STABLE_COPY_PATH=$(jq -r '.stable_copy_path // ""' "$CONFIG")
if [ -n "$STABLE_COPY_PATH" ]; then
    EXPANDED_COPY_PATH="${STABLE_COPY_PATH/#\~/$HOME}"
    mkdir -p "$(dirname "$EXPANDED_COPY_PATH")"

    if is_video "$WALLPAPER" "$VIDEO_EXT_PATTERN"; then
        CACHE_PATH=$(jq -r '.cache_path // "~/.cache/quickshell/thumbs/"' "$CONFIG" | sed "s|^~|$HOME|")
        CACHE_PATH="${CACHE_PATH%/}/"
        FILENAME_NOEXT="$(basename "$WALLPAPER")"
        FILENAME_NOEXT="${FILENAME_NOEXT%.*}"
        THUMB="${CACHE_PATH}${FILENAME_NOEXT}.jpg"

        if [ -f "$THUMB" ]; then
            cp "$THUMB" "$EXPANDED_COPY_PATH"
        else
            echo "hyprquickpaper: no cached thumbnail found for '$WALLPAPER', skipping stable_copy_path update" >&2
        fi
    else
        cp "$WALLPAPER" "$EXPANDED_COPY_PATH"
    fi
fi

# --- Optional: run your own commands after every wallpaper change ---
# Anything here runs after the wallpaper is set, no matter which
# wallpaper_tool you picked above, and for both images and videos.
# Useful for things like:
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
