#!/usr/bin/env bash
#
# hyprquickpaper wallpaper backend dispatcher
# ---------------------------------------------
# For static images, this script picks a backend in this priority order:
#
#   1. `custom_command` in config.json — if non-empty, this runs with the
#      wallpaper path in $WALLPAPER. Use this for anything not covered by
#      the built-in list (Noctalia IPC, custom scripts, D-Bus, etc.).
#
#   2. `wallpaper_tool` in config.json — a named backend: awww, hyprpaper,
#      waypaper, swaybg, feh. Or "auto" to detect the running daemon.
#
#   3. Fallback — if the chosen tool's daemon isn't running, fall back to
#      whichever supported daemon IS running, and say so.
#
# Video files (mp4/webm/mov/etc, see "video_extensions" in config.json)
# are always played through mpvpaper, regardless of the above.
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$DIR/config.json"
source "$DIR/common.sh"

WALLPAPER="$1"
if [ -z "$WALLPAPER" ]; then
    exit 0
fi

TOOL=$(jq -r '.wallpaper_tool // "auto"' "$CONFIG")
CUSTOM_CMD=$(jq -r '.custom_command // ""' "$CONFIG")
VIDEO_EXT_PATTERN=$(get_video_extensions_pattern "$CONFIG")

# --- daemon detection --------------------------------------------------
# Returns the name of a running supported wallpaper daemon, or "" if none.
detect_running_daemon() {
    if pgrep -x awww-daemon >/dev/null; then echo "awww"; return; fi
    if pgrep -x swww-daemon >/dev/null; then echo "awww"; return; fi   # legacy name
    if pgrep -x hyprpaper  >/dev/null; then echo "hyprpaper"; return; fi
    if pgrep -x swaybg     >/dev/null; then echo "swaybg"; return; fi
    echo ""
}

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
    # ---- Priority 1: user's custom command ----------------------------
    if [ -n "$CUSTOM_CMD" ]; then
        echo "Using custom_command from config.json:"
        echo "    $CUSTOM_CMD"
        WALLPAPER="$WALLPAPER" bash -c "$CUSTOM_CMD"
        status=$?
        if [ "$status" -ne 0 ]; then
            echo ""
            echo "⚠️  custom_command failed (exit $status)."
            echo "    Verify the command works standalone:"
            echo "        WALLPAPER=\"$WALLPAPER\" $CUSTOM_CMD"
            echo ""
        fi
    else
        # ---- Priority 2: named tool, or auto-detect -------------------
        if [ "$TOOL" = "auto" ]; then
            DETECTED=$(detect_running_daemon)
            if [ -n "$DETECTED" ]; then
                echo "Auto-detected running daemon: $DETECTED"
                TOOL="$DETECTED"
            else
                echo "⚠️  No supported wallpaper daemon detected."
                echo ""
                echo "    Start one of these daemons and try again:"
                echo "        awww-daemon  |  hyprpaper  |  swaybg"
                echo ""
                echo "    Or, if your desktop shell manages wallpapers itself"
                echo "    (Noctalia, end-4 dots, etc.), set 'custom_command'"
                echo "    in config.json to whichever command your shell uses."
                echo "    See README.md → Configuration for examples."
                echo ""
                TOOL=""
            fi
        fi

        # If the configured tool's daemon isn't running, try to start it,
        # then fall back to whichever supported daemon IS running.
        case "$TOOL" in
            awww|swww)
                if ! pgrep -x awww-daemon >/dev/null && ! pgrep -x swww-daemon >/dev/null; then
                    RUNNING=$(detect_running_daemon)
                    if [ -n "$RUNNING" ]; then
                        echo "Note: '$TOOL' daemon not running; falling back to '$RUNNING'."
                        TOOL="$RUNNING"
                    fi
                fi
                ;;
            hyprpaper)
                if ! pgrep -x hyprpaper >/dev/null; then
                    RUNNING=$(detect_running_daemon)
                    if [ -n "$RUNNING" ]; then
                        echo "Note: '$TOOL' daemon not running; falling back to '$RUNNING'."
                        TOOL="$RUNNING"
                    fi
                fi
                ;;
        esac

        # ---- Priority 3: dispatch -------------------------------------
        status=0
        if [ -n "$TOOL" ]; then
            echo "Using $TOOL for image wallpaper: $WALLPAPER"
            case "$TOOL" in
                awww|swww)
                    # awww and legacy swww share compatible CLIs; awww is
                    # the maintained successor and preferred binary name.
                    awww img "$WALLPAPER" --transition-type grow --transition-duration 1 --transition-fps 60 || status=$?
                    ;;
                hyprpaper)
                    hyprctl hyprpaper preload "$WALLPAPER" 2>/dev/null
                    hyprctl hyprpaper wallpaper ",$WALLPAPER" || status=$?
                    ;;
                waypaper)
                    waypaper --wallpaper "$WALLPAPER" || status=$?
                    ;;
                swaybg)
                    pkill swaybg 2>/dev/null
                    swaybg -i "$WALLPAPER" -m fill &
                    ;;
                feh)
                    # X11 / XWayland only — not truly Wayland-native
                    feh --bg-fill "$WALLPAPER" || status=$?
                    ;;
                *)
                    echo "hyprquickpaper: unknown wallpaper_tool '$TOOL' in config.json, defaulting to awww" >&2
                    awww img "$WALLPAPER" --transition-type grow --transition-duration 1 || status=$?
                    ;;
            esac
        else
            status=1
        fi

        if [ "$status" -ne 0 ] && [ -n "$TOOL" ]; then
            echo ""
            echo "⚠️  Failed to apply wallpaper (exit $status)."
            echo "    Backend: $TOOL"
            echo "    Check the daemon is running:"
            echo "        pgrep -a -f 'awww-daemon|hyprpaper|swaybg'"
            echo "    Or set 'custom_command' in config.json to a working command."
            echo ""
        fi
    fi
fi

# Track the active wallpaper ourselves so the picker can highlight it
# the next time it opens, regardless of what backend/type you used.
mkdir -p "$HOME/.cache/hyprquickpaper"
echo "$WALLPAPER" > "$HOME/.cache/hyprquickpaper/current_wallpaper"

STABLE_COPY_PATH=$(jq -r '.stable_copy_path // ""' "$CONFIG")
if [ -n "$STABLE_COPY_PATH" ]; then
    EXPANDED_COPY_PATH="${STABLE_COPY_PATH/#\~/$HOME}"
    mkdir -p "$(dirname "$EXPANDED_COPY_PATH")"

    if is_video "$WALLPAPER" "$VIDEO_EXT_PATTERN"; then
        CACHE_PATH=$(jq -r '.cache_path // "~/.cache/quickshell/thumbs/"' "$CONFIG" | sed "s|^~|$HOME|")
        CACHE_PATH="${CACHE_PATH%/}/"
        FILENAME_NOEXT="$(basename "$WALLPAPER")"
        FILENAME_NOEXT="${FILENAME_NOEXT%.*}"
        HQ_THUMB="${CACHE_PATH}${FILENAME_NOEXT}.hq.jpg"
        SMALL_THUMB="${CACHE_PATH}${FILENAME_NOEXT}.jpg"

        if [ -f "$HQ_THUMB" ]; then
            cp "$HQ_THUMB" "$EXPANDED_COPY_PATH"
        elif [ -f "$SMALL_THUMB" ]; then
            cp "$SMALL_THUMB" "$EXPANDED_COPY_PATH"
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
