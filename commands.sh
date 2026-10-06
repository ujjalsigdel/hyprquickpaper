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
#
# After applying, optional post_apply hooks run (config.json's
# "post_apply" array) and, if "notify_on_apply" is true, a desktop
# notification is shown.
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$DIR/config.json"
source "$DIR/common.sh"

WALLPAPER="$1"
if [ -z "$WALLPAPER" ]; then
    exit 0
fi

TOOL=$(jq -r '.wallpaper_tool // "auto"' "$CONFIG")
CUSTOM_CMD=$(jq -r '.custom_command // ""' "$CONFIG")
NOTIFY_ENABLED=$(jq -r '.notify_on_apply // false' "$CONFIG")
VIDEO_EXT_PATTERN=$(get_video_extensions_pattern "$CONFIG")

# Tracks whether the wallpaper was actually applied. Used to decide which
# notification to send (and whether post_apply hooks should announce
# success). Set to true by each success path below.
OVERALL_SUCCESS=false

# Still-image counterpart to $WALLPAPER. For images this is identical to
# $WALLPAPER. For videos it's the cached .hq.jpg (or .jpg fallback) — the
# still frame cache.sh extracted. Theming tools that can't read video
# files should use this instead of $WALLPAPER in post_apply hooks.
WALLPAPER_STILL=""

# --- daemon detection --------------------------------------------------
detect_running_daemon() {
    if pgrep -x awww-daemon >/dev/null; then echo "awww"; return; fi
    if pgrep -x swww-daemon >/dev/null; then echo "awww"; return; fi   # legacy name
    if pgrep -x hyprpaper  >/dev/null; then echo "hyprpaper"; return; fi
    if pgrep -x swaybg     >/dev/null; then echo "swaybg"; return; fi
    echo ""
}

# --- notification helper ----------------------------------------------
# Silently no-ops if notifications are disabled in config.json or
# notify-send isn't installed. Call sites don't need to check either.
notify() {
    # notify TITLE BODY [URGENCY]
    [ "$NOTIFY_ENABLED" = "true" ] || return 0
    command -v notify-send &>/dev/null || return 0
    local title="$1" body="$2" urgency="${3:-normal}"
    local timeout=3000
    [ "$urgency" = "critical" ] && timeout=5000
    notify-send -u "$urgency" -t "$timeout" -a "hyprquickpaper" "$title" "$body"
}

# ALWAYS kill any running video wallpaper first.
pkill mpvpaper 2>/dev/null

if is_video "$WALLPAPER" "$VIDEO_EXT_PATTERN"; then
    echo "Detected video file: $WALLPAPER"

    # Locate the cached still for this video. cache.sh writes both
    # <name>.hq.jpg (native-res) and <name>.jpg (small thumbnail); prefer
    # the HQ one for theming tools that want the best-quality still.
    CACHE_PATH_RAW=$(jq -r '.cache_path // "~/.cache/quickshell/thumbs/"' "$CONFIG" | sed "s|^~|$HOME|")
    CACHE_PATH_RAW="${CACHE_PATH_RAW%/}/"
    VIDEO_NOEXT="$(basename "$WALLPAPER")"
    VIDEO_NOEXT="${VIDEO_NOEXT%.*}"
    if [ -f "${CACHE_PATH_RAW}${VIDEO_NOEXT}.hq.jpg" ]; then
        WALLPAPER_STILL="${CACHE_PATH_RAW}${VIDEO_NOEXT}.hq.jpg"
    elif [ -f "${CACHE_PATH_RAW}${VIDEO_NOEXT}.jpg" ]; then
        WALLPAPER_STILL="${CACHE_PATH_RAW}${VIDEO_NOEXT}.jpg"
    fi

    if command -v mpvpaper &>/dev/null; then
        MONITOR=$(get_monitor_output)
        echo "Using monitor: $MONITOR"

        # -f forks mpvpaper into the background itself, so we don't also
        # need a trailing '&' here.
        mpvpaper -f -o "no-audio loop" "$MONITOR" "$WALLPAPER"

        sleep 1
        if pgrep -f "mpvpaper.*$WALLPAPER" >/dev/null; then
            echo "✅ Video wallpaper started successfully on $MONITOR"
            OVERALL_SUCCESS=true
        else
            echo "⚠️  mpvpaper may not have started correctly"
        fi
    else
        echo "Error: mpvpaper not found. Please install it for video wallpapers."
        echo "  Arch: sudo pacman -S mpvpaper"
        notify "Video wallpaper failed" "mpvpaper not installed" critical
        exit 1
    fi
else
    # For images, the picked file IS the still image.
    WALLPAPER_STILL="$WALLPAPER"

    # ---- Priority 1: user's custom command ----------------------------
    if [ -n "$CUSTOM_CMD" ]; then
        echo "Using custom_command from config.json:"
        echo "    $CUSTOM_CMD"
        WALLPAPER="$WALLPAPER" bash -c "$CUSTOM_CMD"
        status=$?
        if [ "$status" -eq 0 ]; then
            OVERALL_SUCCESS=true
        else
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

        # If the configured tool's daemon isn't running, fall back to
        # whichever supported daemon IS running.
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

        if [ "$status" -eq 0 ] && [ -n "$TOOL" ]; then
            OVERALL_SUCCESS=true
        elif [ "$status" -ne 0 ] && [ -n "$TOOL" ]; then
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

# --- Desktop notification ---------------------------------------------
# One notification per pick, gated on notify_on_apply in config.json.
# Success and failure both use the same helper.
if [ "$OVERALL_SUCCESS" = true ]; then
    notify "Wallpaper set" "$(basename "$WALLPAPER")"
else
    notify "Wallpaper failed" "See terminal for details" critical
fi

# Track the active wallpaper ourselves so the picker can highlight it
# the next time it opens, regardless of what backend/type you used.
mkdir -p "$HOME/.cache/hyprquickpaper"
echo "$WALLPAPER" > "$HOME/.cache/hyprquickpaper/current_wallpaper"

# --- Optional: keep a copy of the current wallpaper at a fixed path ---
STABLE_COPY_PATH=$(jq -r '.stable_copy_path // ""' "$CONFIG")
if [ -n "$STABLE_COPY_PATH" ]; then
    EXPANDED_COPY_PATH="${STABLE_COPY_PATH/#\~/$HOME}"
    mkdir -p "$(dirname "$EXPANDED_COPY_PATH")"

    if [ -n "$WALLPAPER_STILL" ] && [ -f "$WALLPAPER_STILL" ]; then
        cp "$WALLPAPER_STILL" "$EXPANDED_COPY_PATH"
    elif is_video "$WALLPAPER" "$VIDEO_EXT_PATTERN"; then
        echo "hyprquickpaper: no cached thumbnail found for '$WALLPAPER', skipping stable_copy_path update" >&2
    else
        cp "$WALLPAPER" "$EXPANDED_COPY_PATH"
    fi
fi

# --- Optional post-apply hooks ----------------------------------------
# Each entry in `post_apply` (config.json) runs after the wallpaper is
# applied. `$WALLPAPER` is the picked file (may be a video). For theming
# tools that need a still image, `$WALLPAPER_STILL` points to the
# original file for images, or the .hq.jpg / .jpg for videos.
#
# Example config.json:
#   "post_apply": [
#     "matugen image \"$WALLPAPER_STILL\" --type scheme-tonal-spot",
#     "killall -SIGUSR2 waybar",
#     "swaync-client -rs"
#   ]
POST_APPLY_COUNT=$(jq -r '.post_apply // [] | length' "$CONFIG")
if [ "$POST_APPLY_COUNT" -gt 0 ]; then
    echo ""
    echo "Running post_apply hooks ($POST_APPLY_COUNT)..."
    for i in $(seq 0 $((POST_APPLY_COUNT - 1))); do
        CMD=$(jq -r ".post_apply[$i]" "$CONFIG")
        echo "  → $CMD"
        WALLPAPER="$WALLPAPER" WALLPAPER_STILL="$WALLPAPER_STILL" \
            bash -c "$CMD" || \
            echo "    ⚠️  hook failed (exit $?); continuing"
    done
fi
