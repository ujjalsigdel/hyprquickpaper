## 🛠️ Troubleshooting              

| Symptom | Fix |
|---|---|
| Blank/transparent window on launch | Missing Qt5Compat GraphicalEffects module — see Dependencies above. |
| Stuck on "Caching…", thumbnails never load | Confirm `cache_path` is writable and `convert` (ImageMagick) is on `PATH`: `which convert`. |
| Deck opens fine, but pressing Enter/Space does nothing | Two possible causes, check in order: **(1)** `wallpaper_tool` in `config.json` doesn't match what's actually installed (e.g. set to `hyprpaper` but you have `awww` installed) — fix in `config.json`. **(2)** `wallpaper_tool` is correct, but that backend's daemon isn't actually running — see [Switching wallpaper backends](CONFIGURATION.md#-switching-wallpaper-backends-the-part-configjson-cant-do) and check with `pgrep -a <daemon-name>`. |
| Picker doesn't highlight my actual current wallpaper | Confirm your `shell-*.qml` file's tracker path matches `~/.cache/hyprquickpaper/current_wallpaper` (this repo's default) rather than an old ML4W path. |
| Thumbnail generation freezes/slows the system on first launch | Lower `cache_batch_size` to your CPU thread count instead of `0`. |
| `.webp` wallpapers don't show up | The folder filter only matches `.png`/`.jpg`/`.jpeg` (plus `video_extensions`) — see Customization below. |
| Video files don't show up in the picker at all | Video support is currently Classic-layout only — see [Video Wallpapers](../README.md#-video-wallpapers). If you're already on `shell-classic.qml`, confirm the file's extension is listed in `video_extensions`. |
| Video wallpaper thumbnail is stuck on 🎬/never generates | Confirm `ffmpeg` is on `PATH` (`which ffmpeg`) and `cache_path` is writable. Check the `cache.sh` output for "Warning: Could not generate thumbnail for …" — some codecs/containers `ffmpeg` can't seek into will need a re-encode. |
| Video wallpaper thumbnail shows but it won't actually play | Confirm `mpvpaper` is installed (`which mpvpaper`) — it's not in most distros' official repos, see [Dependencies](../README.md#-dependencies). Video playback always goes through `mpvpaper` regardless of `wallpaper_tool`. |
| Wallpaper doesn't survive a reboot | Expected — this project doesn't manage boot-time restore. See "Persistence across reboots" above. |

---
