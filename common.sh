#!/usr/bin/env bash
#
# hyprquickpaper — shared helpers
# --------------------------------
# Sourced by both commands.sh and cache.sh so the video-detection and
# monitor-detection logic only lives in one place.

# get_video_extensions_pattern CONFIG_PATH
# Reads config.json's "video_extensions" array ONCE and returns it as an
# "ext1|ext2|ext3" string for use in a regex. Call this ONCE per script run
# and pass the result into is_video() below — do NOT call this per file.
# (Calling jq per file was the actual bottleneck: scanning a folder with
# hundreds of wallpapers meant hundreds of jq subprocess spawns just to
# answer "is this a video?", competing for CPU with the QML picker that's
# trying to render at the same time.)
get_video_extensions_pattern() {
    local config="$1"
    jq -r '
        (.video_extensions // ["mp4","webm","mov","avi","mkv","gif","m4v","flv","wmv","mpeg","3gp"])
        | join("|")
    ' "$config"
}

# is_video FILE EXT_PATTERN
# EXT_PATTERN is the "ext1|ext2|..." string from get_video_extensions_pattern.
# Pure bash regex match — no subprocess spawned, so this is cheap to call
# once per file in a loop.
is_video() {
    local file="$1"
    local ext_pattern="$2"
    local lower="${file,,}"
    local pattern_lower="${ext_pattern,,}"
    [[ "$lower" =~ \.($pattern_lower)$ ]]
}

# get_monitor_output
# Prefers the currently focused monitor (Hyprland/Sway); falls back to the
# first monitor reported by either IPC, then to "eDP-1" if neither
# compositor's socket is reachable at all.
get_monitor_output() {
    local output
    if command -v hyprctl &>/dev/null; then
        output=$(hyprctl monitors -j | jq -r '(map(select(.focused == true)) + .)[0].name' 2>/dev/null)
        if [ -n "$output" ] && [ "$output" != "null" ]; then
            echo "$output"
            return 0
        fi
    fi
    if command -v swaymsg &>/dev/null; then
        output=$(swaymsg -t get_outputs | jq -r '(map(select(.focused == true)) + .)[0].name' 2>/dev/null)
        if [ -n "$output" ] && [ "$output" != "null" ]; then
            echo "$output"
            return 0
        fi
    fi
    echo "eDP-1"
}
