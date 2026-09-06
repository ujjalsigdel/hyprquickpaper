#!/usr/bin/env bash

CONFIG="${1:-.}/config.json"

if [[ ! -f "$CONFIG" ]]; then
    echo "Error: config.json not found"
    exit 1
fi

# Expand tilde (~) into $HOME
wallpaper_path=$(jq -r '.wallpaper_path' "$CONFIG" | sed "s|^~|$HOME|")
cache_path=$(jq -r '.cache_path' "$CONFIG" | sed "s|^~|$HOME|")
cache_batch_size=$(jq -r '.cache_batch_size' "$CONFIG")

# Ensure trailing slashes
wallpaper_path="${wallpaper_path%/}/"
cache_path="${cache_path%/}/"

mkdir -p "$cache_path"

echo "Scanning $wallpaper_path for wallpapers..."

find "$wallpaper_path" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) | while read -r img; do
filename=$(basename "$img")
out="${cache_path}${filename}"

if [[ -f "$out" ]]; then
    continue
fi

echo "Generating thumbnail for $filename"
convert "$img" -thumbnail x500 -strip -quality 85 "$out" &

# Only limit jobs if batch_size > 0
if (( cache_batch_size > 0 )); then
    while (( $(jobs -rp | wc -l) >= cache_batch_size )); do
        wait -n
    done
fi
done

wait
echo "Thumbnails generated successfully."
