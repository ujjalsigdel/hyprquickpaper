#!/usr/bin/env bash

TARGET="$1"
if [ -z "$TARGET" ]; then
    echo "Usage: $0 <qml-file>" >&2
    exit 1
fi

# Expand ~ to $HOME in case Hyprland passed it literally
TARGET="${TARGET/#\~/$HOME}"

# Look specifically for "qs -p" or "quickshell -p" followed by the target path.
# This prevents the script from accidentally matching and killing itself.
if pgrep -f "qs -p $TARGET" > /dev/null || pgrep -f "quickshell -p $TARGET" > /dev/null; then
    # It's running, kill it.
    pkill -f "qs -p $TARGET" 2>/dev/null || true
    pkill -f "quickshell -p $TARGET" 2>/dev/null || true
else
    # It's not running, start it in the background.
    qs -p "$TARGET" >/dev/null 2>&1 &
fi
