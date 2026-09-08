## Configuration

### `config.json`

```json
{
  "wallpaper_path": "~/Pictures/Wallpapers/",
  "cache_path": "~/.cache/quickshell/thumbs/",
  "wallpaper_tool": "awww",
  "number_of_pictures": 7,
  "border_color": "#C27B63",
  "cache_batch_size": 20,
  "stable_copy_path": "",
  "video_extensions": ["mp4", "webm", "mov", "avi", "mkv", "gif", "m4v", "flv", "wmv", "mpeg", "3gp"],
  "video_thumbnail_interval": 5
}
```

| Key | Meaning | What to set |
|---|---|---|
| `wallpaper_path` | Folder scanned for `.png`/`.jpg`/`.jpeg` files. | Your real wallpaper directory, **with a trailing `/`**, e.g. `"~/Wallpapers/"`. |
| `cache_path` | Where generated thumbnails live. Auto-created on first run. | Leave default, or point at tmpfs if you have thousands of wallpapers. |
| `wallpaper_tool` | **This is the one field almost everyone needs to change.** Selects which backend `commands.sh` uses. | One of `awww`, `hyprpaper`, `waypaper`, `swaybg`, `feh`, `ml4w`. |
| `number_of_pictures` | Jump distance for the `u`/`d` fast-scroll keys (not a display count). | Larger folder → bigger number (10–15+). |
| `border_color` | Hex color of the selected card's border. | Any hex, e.g. `"#89b4fa"`. |
| `cache_batch_size` | Max parallel `convert` jobs while building thumbnails. `0` = unlimited. | Set to roughly your CPU thread count (`4`–`16`) — don't leave at `0` with a large wallpaper folder. |
| `stable_copy_path` | Optional. If set, `commands.sh` also copies every applied wallpaper to this fixed path — handy if some other tool (lock screen, status bar script) wants to always read the current wallpaper from one unchanging filename. | Leave `""` to skip. Otherwise a full path, e.g. `"~/Pictures/wallpaper.png"`. |
| `video_extensions` | Which file extensions are treated as videos (Classic layout only — see [Video Wallpapers](../README.md#-video-wallpapers)) rather than static images, both by the picker and by `commands.sh`/`cache.sh`. | Default list covers the common ones (`mp4`, `webm`, `mov`, `avi`, `mkv`, `gif`, `m4v`, `flv`, `wmv`, `mpeg`, `3gp`) — trim or extend as needed. |
| `video_thumbnail_interval` | Seconds into a video `cache.sh` seeks before grabbing the thumbnail frame. Falls back to 1s, then a frame-0 grab, if the video is shorter than this. | `5` is a reasonable default; lower it if your clips are short. |

Changes to `config.json` apply live — no restart needed. **This does not apply to the daemon autostart change below** — that one needs a session restart, since it's a compositor-level setting outside this project's control.

**Which `wallpaper_tool` should I actually pick?**

> Note: `wallpaper_tool` only governs *static images*. Any file matching `video_extensions` always plays through `mpvpaper` instead, regardless of what `wallpaper_tool` is set to — none of the static-image backends can render video. See [Video Wallpapers](../README.md#-video-wallpapers).

- **`awww` (default) — recommended for almost everyone.** Nicest-looking transitions (formerly `swww`, renamed/re-based upstream in late 2025 — the old `swww`/`swww-daemon` binaries are effectively unmaintained now, so use `awww`/`awww-daemon`, not `swww`). It's had some packaging turbulence around the rename, and has no official package on Fedora — `cargo install awww` there only installs the client half, not the daemon. Works great once correctly installed, just budget a bit of troubleshooting time on Fedora so Build from source, or change wallpaper_tool in config.json to hyprpaper/swaybg instead. 
- **`hyprpaper`** — ships as part of the Hyprland project itself, so if you have Hyprland at all you already have access to it through the same channel (official repo, COPR, AUR, etc.). No transitions, but no separate third-party project to track either.
- **`swaybg`** — simplest possible option, no animated transitions, but extremely stable and rarely breaks across distro updates. Good if you just want it to work.
- **`ml4w`** — only if you already have the full ML4W dotfiles installed; it's a thin wrapper around `hyprpaper` with ML4W-specific extras (effects, SDDM sync) layered on. If you don't already have ML4W, use `awww` or `hyprpaper` directly instead.

### `commands.sh`

You shouldn't need to edit this at all for the six supported backends — just set `wallpaper_tool` above. It also writes the active wallpaper to `~/.cache/hyprquickpaper/current_wallpaper` after every pick, so the "highlight current wallpaper" feature works regardless of backend.

Video files (anything matching `video_extensions`) are detected automatically and dispatched to `mpvpaper` before the `wallpaper_tool` case block is ever reached — any currently-running `mpvpaper` process is killed first so an old video doesn't keep rendering underneath a new pick.

Only edit `commands.sh` directly if you need a backend that isn't in the preset list (e.g. a custom script). Add a new `case` branch following the existing pattern.

> **If you are using ML4W like me, Don't just copy `ml4w-wallpaper` from an ML4W install and point `commands.sh` at it.** That script also drives a hyprpaper template, ImageMagick wallpaper "effects", ML4W's own wallpaper-generated cache, and SDDM background sync — all tied to a full ML4W install. Outside of ML4W it will error out or silently no-op. Use the `awww`/`hyprpaper`/etc. presets above instead — they do the one job (set the wallpaper) with no hidden dependencies.

### `shell.qml` — which layout renders

```qml
property string activeLayout: "shell-bottom-dock.qml"
```
Only one line should be uncommented. Options: `shell-bottom-dock.qml`, `shell-coverflow.qml`, `shell-coverflow-widgets.qml`, `shell-classic.qml`, `shell-widgets-noblur.qml`.

> **Video wallpaper support is currently Classic-only.** `shell-classic.qml` is the only layout with video detection, the `.jpg`-thumbnail lookup, and the **VIDEO** badge wired in. The other layouts' `FolderListModel.nameFilters` only match `.png`/`.jpg`/`.jpeg`, so video files simply won't appear in the picker there yet — they're not broken, just filtered out. If you want videos in another layout, see [Video Wallpapers](../README.md#-video-wallpapers) below for what to port over.

---

## 🔁 Switching wallpaper backends (the part `config.json` can't do)

Setting `wallpaper_tool` only tells `commands.sh` which command to run — it doesn't start the backend's daemon (`awww`, `hyprpaper`, `swaybg` all need one running in the background, autostarted by your compositor config, not by this project). If you switch backends, make sure only the new daemon autostarts, or the old one may still be running and fighting it for the output.

Where that autostart line lives depends on your setup:

- **Plain Hyprland** — in `~/.config/hypr/hyprland.conf` (or a `source =`-included file):
  ```ini
  exec-once = awww-daemon
  ```
- **ML4W (Lua-based config)** — inside `~/.config/hypr/conf/autostart.lua`:
  ```lua
  -- awww daemon
  hl.exec_cmd("awww-daemon")
  ```
  Swap the line/comment to whichever daemon you're switching to. (Don't confuse this with `~/.config/ml4w/settings/wallpaper-app` — that only controls which picker UI ML4W's own keybind opens, `quickshell` or `waypaper`, and has nothing to do with the wallpaper daemon.)

This change only takes effect on your next login/session — `hyprctl reload` won't re-run it. After restarting, confirm the right daemon is running with `pgrep -a <daemon-name>` before testing the picker.

