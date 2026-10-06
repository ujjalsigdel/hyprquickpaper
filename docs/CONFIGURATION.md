## Configuration

### `config.json`

```json
{
  "wallpaper_path": "~/Pictures/Wallpapers/",
  "cache_path": "~/.cache/quickshell/thumbs/",
  "wallpaper_tool": "auto",
  "custom_command": "",
  "post_apply": [],
  "notify_on_apply": false,
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
| `wallpaper_path` | Folder scanned for wallpapers. Supports images plus any extension in `video_extensions`. | Your real wallpaper directory, **with a trailing `/`**, e.g. `"~/Wallpapers/"`. |
| `cache_path` | Where generated thumbnails live. Auto-created on first run. | Leave default, or point at tmpfs if you have thousands of wallpapers. |
| `wallpaper_tool` | Selects which backend `commands.sh` uses for static images. | `"auto"` (default, detects the running daemon), or one of `awww`, `hyprpaper`, `waypaper`, `swaybg`, `feh`. |
| `custom_command` | If non-empty, overrides `wallpaper_tool` entirely. Runs with the picked path in `$WALLPAPER`. | Leave `""` for standard setups. Set it if your desktop shell manages wallpapers itself (Noctalia, custom IPC, etc.). See [Custom command](#custom-command) below. |
| `post_apply` | Optional. Array of shell commands run after every successful wallpaper change. Each runs with `$WALLPAPER` (picked file, may be a video) and `$WALLPAPER_STILL` (always a still image) exported. | Leave `[]` to skip. See [Post-apply hooks](#post-apply-hooks) below for examples. |
| `notify_on_apply` | Show a desktop notification after each pick (success or failure). Requires `notify-send`. | `false` by default. Set to `true` if you want feedback when the picker closes via keybind and you don't see terminal output. |
| `number_of_pictures` | Jump distance for the `u`/`d` fast-scroll keys (not a display count). | Larger folder → bigger number (10–15+). |
| `border_color` | Hex color of the selected card's border. | Any hex, e.g. `"#89b4fa"`. |
| `cache_batch_size` | Max parallel `convert`/`ffmpeg` jobs while building thumbnails. `0` = unlimited. | Set to roughly your CPU thread count (`4`–`16`) — don't leave at `0` with a large wallpaper folder. |
| `stable_copy_path` | Optional. If set, `commands.sh` also copies every applied wallpaper to this fixed path — handy if some other tool (lock screen, status bar script) wants to always read the current wallpaper from one unchanging filename. | Leave `""` to skip. Otherwise a full path, e.g. `"~/Pictures/wallpaper.png"`. |
| `video_extensions` | Which file extensions are treated as videos rather than static images, both by the picker and by `commands.sh`/`cache.sh`. | Default list covers the common ones (`mp4`, `webm`, `mov`, `avi`, `mkv`, `gif`, `m4v`, `flv`, `wmv`, `mpeg`, `3gp`) — trim or extend as needed. |
| `video_thumbnail_interval` | Seconds into a video `cache.sh` seeks before grabbing the thumbnail frame. Falls back to 1s, then a frame-0 grab, if the video is shorter than this. | `5` is a reasonable default; lower it if your clips are short. |

Changes to `config.json` apply live — no restart needed. **This does not apply to the daemon autostart change below** — that one needs a session restart, since it's a compositor-level setting outside this project's control.

**Which `wallpaper_tool` should I actually pick?**

> Note: `wallpaper_tool` only governs *static images*. Any file matching `video_extensions` always plays through `mpvpaper` instead, regardless of what `wallpaper_tool` is set to — none of the static-image backends can render video. See [Video Wallpapers](../README.md#-video-wallpapers).

- **`auto` (default) — recommended.** Detects which supported daemon is running (`awww`, `hyprpaper`, `swaybg`) and uses it. If none is running, prints a clear message telling you what to check or how to set `custom_command`.
- **`awww`** — nice transitions (formerly `swww`, renamed/re-based upstream in late 2025 — the old `swww`/`swww-daemon` binaries are effectively unmaintained now, so use `awww`/`awww-daemon`, not `swww`). Has no official package on Fedora — `cargo install awww` there only installs the client half, not the daemon. Works great once correctly installed; budget some troubleshooting time on Fedora, or fall back to `hyprpaper`/`swaybg`.
- **`hyprpaper`** — ships as part of the Hyprland project itself, so if you have Hyprland at all you already have access to it through the same channel (official repo, COPR, AUR, etc.). No transitions, but no separate third-party project to track either.
- **`swaybg`** — simplest possible option, no animated transitions, but extremely stable and rarely breaks across distro updates. Good if you just want it to work.
- **`waypaper`** / **`feh`** — included for completeness. `waypaper` wraps other backends; `feh` is X11/XWayland-only and not truly Wayland-native.

### `commands.sh`

You shouldn't need to edit this at all for the supported backends — just set `wallpaper_tool` above. It also writes the active wallpaper to `~/.cache/hyprquickpaper/current_wallpaper` after every pick, so the "highlight current wallpaper" feature works regardless of backend.

Video files (anything matching `video_extensions`) are detected automatically and dispatched to `mpvpaper` before the `wallpaper_tool` case block is ever reached — any currently-running `mpvpaper` process is killed first so an old video doesn't keep rendering underneath a new pick.

Only edit `commands.sh` directly if you need a backend that isn't in the preset list (e.g. a custom script). Add a new `case` branch following the existing pattern, or use `custom_command` instead (see below).

### Custom command

Some desktop shells manage wallpapers themselves and don't expose a plain `awww`/`hyprpaper`/`swaybg` daemon for third-party pickers to talk to. On those setups `wallpaper_tool: "auto"` will correctly report "no supported daemon found" — the fix is a one-line `custom_command`.

Set `custom_command` to whatever command your shell uses to set a wallpaper, and use `$WALLPAPER` where the path goes. The picker exports the chosen file's path into that variable before running your command.

Examples:

```json
// Noctalia v5+
"custom_command": "noctalia msg wallpaper-set \"$WALLPAPER\""

// Noctalia v4
"custom_command": "noctalia-shell ipc call wallpaper set \"$WALLPAPER\""

// Any shell that exposes a wallpaper IPC
"custom_command": "your-shell ipc wallpaper set \"$WALLPAPER\""
```

`custom_command` takes priority over `wallpaper_tool` — if it's non-empty, the daemon detection and case dispatch are skipped entirely. Leave it empty to use the normal backend path.

### Post-apply hooks

After the wallpaper is applied, `commands.sh` can run any list of shell
commands you want — colorscheme regeneration, bar reloads, notification
daemons, anything. Set `post_apply` in config.json to an array of shell
commands. Each runs with two variables exported:

- `$WALLPAPER` — the picked file. For videos this is the `.mp4`/`.webm`.
- `$WALLPAPER_STILL` — always a still image. For images it's the same as
  `$WALLPAPER`; for videos it's the cached `.hq.jpg` (or `.jpg` fallback).

Theming tools that can't read video files should use `$WALLPAPER_STILL`.
Anything else can use `$WALLPAPER`.

Hooks run in order. If one fails, a warning is printed and the remaining
hooks still run — so a broken bar reload won't stop your colorscheme from
being generated.

**matugen example:**
```json
"post_apply": [
  "matugen image \"$WALLPAPER_STILL\" --type scheme-tonal-spot --prefer saturation",
  "killall -SIGUSR2 waybar",
  "swaync-client -rs"
]
```

**wallust example:**
```json
"post_apply": [
  "wallust run \"$WALLPAPER_STILL\"",
  "killall -SIGUSR2 waybar"
]
```

**pywal example:**
```json
"post_apply": [
  "wal -i \"$WALLPAPER_STILL\"",
  "killall -SIGUSR2 waybar"
]
```

**Hyprpaper config persistence example** — rewrite `hyprpaper.conf` so the
current wallpaper survives a daemon restart:

```json                                                     
"post_apply": [
  "printf 'preload = %s\\nwallpaper {\\n  monitor =\\n  path = %s\\n  fit_mode = cover\\n}\\n' \"$WALLPAPER\" \"$WALLPAPER\" > ~/.config/hypr/hyprpaper.conf"
]
```

(Only do this if hyprpaper is your `wallpaper_tool` and you don't have
hand-written custom entries in that file you'd rather keep.)

### `shell.qml` — which layout renders

```qml
property string activeLayout: "shell-classic.qml"
```
Only one line should be uncommented. Options include `shell-classic.qml`, `shell-bottom-dock.qml`, `shell-coverflow.qml` (and its clear/minimal variants), the `shell-floating-*.qml` family, `shell-grid-view.qml`, and `shell-hexcomb.qml`.

> **Video wallpaper support is available in every layout except Hexacomb.** All other layouts' `FolderListModel.nameFilters` include the configured video extensions, and cards display the cached `.jpg` thumbnail with a **VIDEO** badge.

---

## 🔁 Switching wallpaper backends (the part `config.json` can't do)

Setting `wallpaper_tool` only tells `commands.sh` which command to run — it doesn't start the backend's daemon (`awww`, `hyprpaper`, `swaybg` all need one running in the background, autostarted by your compositor config, not by this project). If you switch backends, make sure only the new daemon autostarts, or the old one may still be running and fighting it for the output.

Where that autostart line lives depends on your Hyprland config style:

- **Classic `hyprland.conf`** — in `~/.config/hypr/hyprland.conf` (or a `source =`-included file):
  ```ini
  exec-once = awww-daemon
  ```
- **Lua-based configs** (used by many dotfiles sets; the autostart block usually lives under `~/.config/hypr/conf/`):
  ```lua
  -- in ~/.config/hypr/conf/autostart.lua
  hl.exec_cmd("awww-daemon")
  ```

Swap the line/comment to whichever daemon you're switching to.

> If your desktop shell manages wallpapers itself (Noctalia, etc.), you don't need a daemon autostart at all — set `custom_command` in `config.json` instead and let the shell handle it.

This change only takes effect on your next login/session — `hyprctl reload` won't re-run it. After restarting, confirm the right daemon is running with `pgrep -a <daemon-name>` before testing the picker.

---

## Loading label appears on battery or low-end PCs

**Symptom:** On opening the picker, you briefly see `Loading…` on the cards
before the images appear or the label flashes for a moment.

**Why:** The picker hides itself until the current background image is
decoded, then fades in. Card thumbnails decode in parallel and usually
finish first — but on slow storage or under power-save, card decodes lag
behind the background, so the reveal fires while cards are still empty.

**Fix:** open the layout file your `shell.qml` points at (`activeLayout`),
and raise two values. Both are named the same across layouts.

### 1. Increase the reveal delay

Find the timer that gates the reveal and double its value:

```qml
// Floating and Grid layouts — one-shot fallback
Timer {
    id: revealFallback
    interval: 800          // ← raise to 1500 or 2000
    ...
}
```

```qml
// Bottom Dock and Coverflow layouts — polling timer with a bailout
if (!list.moving || elapsed > 250) {   // ← raise 250 to 600 or 800
```

### 2. Increase the fade duration

Find the fade-in animation and raise its duration:

```qml
NumberAnimation {
    id: revealAnimation
    duration: 220          // ← raise to 400 for a gentler fade
    ...
}
```

In Grid View the same value lives on `contentRoot`'s `Behavior on opacity`
rather than a `revealAnimation` block, but the change is identical: raise
the duration to `400`.

A 400–500 ms fade gives late-decoding cards time to arrive while the panel
is still becoming visible, so `Loading…` rarely shows even on slow hardware.

**Verify:** open the picker on battery (or run `cpupower frequency-set -g
powersave` on a desktop to force the same conditions) — the fade-in should
look the same as on AC power.
