#!/usr/bin/env bash

CONFIG="${1:-.}/config.json"

if [[ ! -f "$CONFIG" ]]; then
    echo "Error: config.json not found"
    exit 1
fi

DIR="$(cd "$(dirname "$CONFIG")" && pwd)"
source "$DIR/common.sh"

# Expand tilde (~) into $HOME
wallpaper_path=$(jq -r '.wallpaper_path' "$CONFIG" | sed "s|^~|$HOME|")
cache_path=$(jq -r '.cache_path' "$CONFIG" | sed "s|^~|$HOME|")
cache_batch_size=$(jq -r '.cache_batch_size' "$CONFIG")
video_thumbnail_interval=$(jq -r '.video_thumbnail_interval // 5' "$CONFIG")
VIDEO_EXT_PATTERN=$(get_video_extensions_pattern "$CONFIG")

# Ensure trailing slashes
wallpaper_path="${wallpaper_path%/}/"
cache_path="${cache_path%/}/"

mkdir -p "$cache_path"

echo "Scanning $wallpaper_path for images..."

while read -r img; do
    filename=$(basename "$img")
    out="${cache_path}${filename}"

    if [[ -f "$out" ]]; then
        continue
    fi

    echo "Generating thumbnail for $filename"

    if command -v magick &>/dev/null; then
        magick "$img" -thumbnail x500 -strip -quality 85 "$out" 2>/dev/null &
    else
        convert "$img" -thumbnail x500 -strip -quality 85 "$out" 2>/dev/null &
    fi

    if (( cache_batch_size > 0 )); then
        while (( $(jobs -rp | wc -l) >= cache_batch_size )); do
            wait -n
        done
    fi
done < <(find "$wallpaper_path" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \))

# Let all image jobs finish before starting video jobs so the batch-size
# throttle above only ever governs one kind of job at a time.
wait
echo "Image thumbnails done."

if command -v ffmpeg &>/dev/null; then
    echo "Scanning $wallpaper_path for videos..."

    # Build a `find -iname "*.ext1" -o -iname "*.ext2" ...` expression once,
    # same style as the image loop above — lets find() filter natively
    # instead of running every file in the folder through is_video()/jq.
    IFS='|' read -ra video_exts <<< "$VIDEO_EXT_PATTERN"
    video_find_expr=()
    for ext in "${video_exts[@]}"; do
        if [ "${#video_find_expr[@]}" -gt 0 ]; then
            video_find_expr+=(-o)
        fi
        video_find_expr+=(-iname "*.${ext}")
    done

    while read -r video; do
        filename=$(basename "$video")
        filename_noext="${filename%.*}"
        out="${cache_path}${filename_noext}.jpg"

        if [[ -f "$out" ]]; then
            continue
        fi

        echo "Generating thumbnail for video: $filename"

        (
            # Try the configured seek point first (video_thumbnail_interval,
            # default 5s), then 1s in if the clip is shorter than that,
            # then finally without any seek at all.
            ffmpeg -i "$video" -ss "$video_thumbnail_interval" -vframes 1 \
                -vf "scale=500:-1:flags=lanczos" -q:v 2 "$out" -y 2>/dev/null

            if [ ! -f "$out" ]; then
                ffmpeg -i "$video" -ss 1 -vframes 1 \
                    -vf "scale=500:-1:flags=lanczos" -q:v 2 "$out" -y 2>/dev/null
            fi

            if [ ! -f "$out" ]; then
                ffmpeg -i "$video" -vframes 1 -q:v 2 "$out" -y 2>/dev/null
            fi

            if [ ! -f "$out" ]; then
                echo "Warning: Could not generate thumbnail for $filename"
            fi
        ) &

        if (( cache_batch_size > 0 )); then
            while (( $(jobs -rp | wc -l) >= cache_batch_size )); do
                wait -n
            done
        fi
    done < <(find "$wallpaper_path" -type f \( "${video_find_expr[@]}" \))

    wait
else
    echo "ffmpeg not found — skipping video thumbnail generation (install ffmpeg to enable it)."
fi

echo "Thumbnails generated successfully."
