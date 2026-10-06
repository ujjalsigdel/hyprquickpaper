#!/usr/bin/env bash
# set-layout.sh <config-dir> <layout-file>
# Writes "active_layout" to <config-dir>/config.json.
set -e

CONFIG_DIR="${1:-.}"
LAYOUT="${2:-}"

if [ -z "$LAYOUT" ]; then
    echo "Error: layout filename required" >&2
    exit 1
fi

CONFIG="$CONFIG_DIR/config.json"
if [ ! -f "$CONFIG" ]; then
    echo "Error: $CONFIG not found" >&2
    exit 1
fi

tmp=$(mktemp)
if jq --arg l "$LAYOUT" '.active_layout = $l' "$CONFIG" > "$tmp"; then
    mv "$tmp" "$CONFIG"
else
    rm -f "$tmp"
    echo "Error: failed to update config.json" >&2
    exit 1
fi
