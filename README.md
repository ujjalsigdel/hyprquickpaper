# 🖼️ HyprQuickPaper

A fast, themeable, keyboard-driven Wayland wallpaper picker built with **Quickshell** and **QML** for Hyprland (and any other `wlr-layer-shell` compositor). Pick a wallpaper with `h`/`l`, jump around with `u`/`d`, confirm with `Space`/`Enter`, bail with `Esc`.

Originally based on [iamsurjog/hyprquickpaper](https://github.com/iamsurjog/hyprquickpaper), itself inspired by [ilyamiro's dots](https://github.com/ilyamiro/nixos-configuration). This fork is rebuilt to run on **any** Wayland wallpaper backend, not just ML4W dotfiles.

> [!IMPORTANT]
> Out of the box this only needs **one** edit for most non-ML4W users: set `wallpaper_tool` in `config.json`. See [Configuration](#-configuration) below — everything else is optional tuning.
>
> **If you're switching which backend you use** (e.g. from `hyprpaper` to `awww`, or vice versa), `config.json` is only half the job — you also need to make sure the right daemon autostarts with your compositor. See [Switching wallpaper backends](#-switching-wallpaper-backends-the-part-configjson-cant-do) below. Skipping this step is the #1 cause of "the picker applies, but nothing changes."

> **Supported compositors only**  
> This project requires a compositor that implements the `wlr-layer-shell` protocol  
> (Hyprland, Sway, niri, river, …).  
>
> It does **not** work on GNOME / Mutter, KDE Plasma, or any compositor that lacks  
> `zwlr-layer-shell-v1`. Running it there produces:
> ```
> WARN: Failed to initialize layershell integration
> ```
> and the UI never appears.  
>
> For GNOME there is a separate GTK4 implementation:  
> [hugo-sants/hyprquickpaper-gnome](https://github.com/hugo-sants/hyprquickpaper-gnome)

### Environment requirements

| Compositor          | Status     | Notes                                      |
|---------------------|------------|--------------------------------------------|
| Hyprland            | ✅ Supported | Primary target                             |
| Sway / niri / river | ✅ Supported | Any wlr-layer-shell compositor             |
| GNOME / Mutter      | ❌ Not supported | Use the GTK4 fork linked above          |
| KDE Plasma          | ❌ Not supported | No wlr-layer-shell                         |
| X11                 | ❌ Not supported | Wayland only                               |

---

## 🧩 How it works: two separate pieces

This project is really two things working together, and it helps to know the difference before you touch `config.json`:

- **Quickshell** (via `shell.qml` / `shell-*.qml`) is the picker UI itself — the card deck, the animations, keyboard navigation, thumbnail rendering. It's what you actually see and interact with. Quickshell has no idea how to change your desktop background; that's not its job.
- **The wallpaper backend** (`awww`, `hyprpaper`, `swaybg`, `waypaper`, `feh`, or `ml4w`) is a separate program whose only job is: take an image path, paint it on screen. Once you press `Space`/`Enter` in the picker, `commands.sh` hands the chosen file off to whichever backend `wallpaper_tool` in `config.json` names. Most of these backends (`awww`, `hyprpaper`, `swaybg`) run as a **background daemon** that must already be running before `commands.sh` can talk to it — that daemon is started by your compositor config, not by this project. See [Switching wallpaper backends](#-switching-wallpaper-backends-the-part-configjson-cant-do).

So Quickshell is always used — no choice there, it's the engine this whole project runs on. `wallpaper_tool` is the one thing you pick based on what's actually installed and running on your system. See [Configuration](#-configuration) for which backend to choose.

---

## ✨ Features

- **Multiple layout modes** — Bottom Dock, Coverflow, Coverflow+Widgets, Classic list, and a no-blur widgets variant. Switch by editing one line in `shell.qml`.
- **Video wallpapers** *(Classic layout only, for now — see [Video Wallpapers](#-video-wallpapers))* — `.mp4`/`.webm`/`.mov`/etc. play via `mpvpaper`, auto-thumbnailed with `ffmpeg`, and tagged with a **VIDEO** badge in the picker.
- **Sheared bottom-dock deck** — parallelogram cards, rounded corners, uniform height, active-selection glow border.
- **Lossless full-quality background preview** — renders the actual full-resolution image behind the dock (not the downscaled thumbnail), crossfaded between picks.
- **Automatic thumbnail cache** — downscaled previews generated via ImageMagick so scrolling stays smooth with hundreds of wallpapers.
- **Live config reload** — `config.json` changes apply immediately, no restart needed.
- **Fully keyboard-driven** — no mouse required, though clicking works too.
- **Backend-agnostic** — works with awww, hyprpaper, waypaper, swaybg, or feh via a single config field, no bash editing required for common setups.
- **Embedded custom typography** — bundled display font, no manual install needed.

---

## 📸 Layouts

### Bottom Dock *(default)*
A sheared, parallelogram card deck along the bottom of the screen, uniform card height, with the focused card scaled up and outlined in your accent color.

![Bottom Dock](assets/screenshots/bottom-dock.jpg)

---

### Coverflow Family
Cards fan out in 3D-style perspective around the focused item, classic "coverflow" browsing feel.

| Layout | Description | Screenshot |
|--------|-------------|------------|
| **Coverflow** | Classic 3D coverflow with background blur | ![Coverflow](assets/screenshots/coverflow.jpg) |
| **Coverflow Clear** | Coverflow without background blur — use this if your compositor/GPU can't keep blur smooth | ![Coverflow Clear](assets/screenshots/coverflow-clear.jpg) |
| **Coverflow Minimal** | Coverflow without on-screen widgets (clock/info) layered in | ![Coverflow Minimal](assets/screenshots/coverflow-minimal.jpg) |

---

### Floating Family

#### Floating (with widgets & reflections)
Features a tiered, 3D floating cloud effect with an ultra-smooth background blur and a glassmorphic Date & Time overlay in the top center.

| Layout | Description | Screenshot |
|--------|-------------|------------|
| **Floating** | Blurred background with glassmorphic date/time overlay, reflections on all cards | ![Floating](assets/screenshots/floating.jpg) |
| **Floating Center Reflection** | Blurred background with date/time, reflection only on center card | ![Floating Center](assets/screenshots/floating-center-relfection.jpg) |
| **Floating Clean** | Blurred background with date/time, no reflections | ![Floating Clean](assets/screenshots/floating-clean.jpg) |

#### Floating Clear (without blur, with widgets)
Replaces the heavily blurred background with the original high-resolution wallpaper in crisp detail, keeping the sleek Date & Time overlay on top.

| Layout | Description | Screenshot |
|--------|-------------|------------|
| **Floating Clear** | High-res wallpaper with date/time, reflections on all cards | ![Floating Clear](assets/screenshots/floating-clear.jpg) |
| **Floating Clear Clean** | High-res wallpaper with date/time, no reflections | ![Floating Clear Clean](assets/screenshots/floating-clear-clean.jpg) |

#### Floating Minimal (without blur, no widgets)
Offers a completely unobstructed view of your high-resolution wallpaper by removing the Date & Time overlay entirely, keeping focus purely on the 3D card deck.

| Layout | Description | Screenshot |
|--------|-------------|------------|
| **Floating Minimal** | High-res wallpaper, no date/time, reflections on all cards | ![Floating Minimal](assets/screenshots/floating-minimal.jpg) |
| **Floating Minimal Clean** | High-res wallpaper, no date/time, no reflections | ![Floating Minimal Clean](assets/screenshots/floating-minimal-clean.jpg) |

---

### Hexacomb
A honeycomb grid of hexagonal tiles, navigable in both directions (columns and rows) instead of a single strip. Idea for this layout taken from [Horizon0427/Arch-Config](https://github.com/Horizon0427/Arch-Config) — the hex-grid wallpaper picker there was the inspiration, rebuilt here from scratch for Quickshell/QML.

![Hexacomb](assets/screenshots/hexcomb.jpg)

---

### Classic List
A plain vertical/list layout — lightest on GPU, good for weaker hardware or minimal setups.

![Classic List](assets/screenshots/classic.jpg)

---

## 🎬 Video Wallpapers

Video files (`.mp4`, `.webm`, `.mov`, and whatever else you list in `video_extensions`) can be used as wallpapers alongside static images — **currently only in the Classic layout** (`shell-classic.qml`). Support for the other layouts hasn't been ported over yet; see the note in [`shell.qml`](#shellqml--which-layout-renders) above.

**How it works:**
- `cache.sh` scans `wallpaper_path` for anything matching `video_extensions`, and grabs a still frame with `ffmpeg` (seeking to `video_thumbnail_interval` seconds in, falling back to 1s, then frame 0, for short clips) to use as the thumbnail — the same caching flow as image wallpapers, just via `ffmpeg` instead of `convert`.
- In the picker, video entries are visually tagged with a small **VIDEO** badge over their thumbnail.
- Selecting one hands it off through `commands.sh`, which detects it's a video and always plays it through `mpvpaper`, muted and looping, regardless of what `wallpaper_tool` is set to — `awww`/`hyprpaper`/etc. can't render video at all, so this path bypasses them entirely.

**Requirements:** `ffmpeg` (thumbnailing) and `mpvpaper` (playback) — see [Dependencies](#-dependencies). `mpvpaper` isn't in most distros' official repos, so `install.sh` will point you at the AUR or a source build if it can't install it directly.

**Config:** `video_extensions` (which extensions count as video) and `video_thumbnail_interval` (thumbnail seek time) — see [Configuration](#-configuration).

**Porting video support to another layout:** copy `isVideoFile()`, `getThumbnailSource()`, and the `videoExtensions` property from `shell-classic.qml`, extend that layout's `FolderListModel.nameFilters` to include video extensions, and add the VIDEO-badge `Rectangle` to its delegate. No bash changes needed — `cache.sh`/`commands.sh` already handle any layout's video files identically.

---

> Screenshots referenced above go under `assets/screenshots/` in this repo — add your own there.

---

## 📋 Dependencies

`install.sh` detects your package manager (pacman / dnf / apt) and installs all of these automatically, including the one that's easy to miss:

- [Quickshell](https://quickshell.org) (`qs` / `quickshell`) — renders the whole UI
- `jq` — parses `config.json`
- `imagemagick` (`convert`) — generates the thumbnail cache
- **Qt5Compat GraphicalEffects** QML module — powers the rounded-corner card masking; not bundled with base Qt
- A wallpaper backend of your choice: `awww`, `hyprpaper`, `waypaper`, `swaybg`, or `feh`
- `ffmpeg` — generates video thumbnails *(only needed if you have video wallpapers)*
- `mpvpaper` — plays video wallpapers *(only needed if you have video wallpapers; not in official repos on most distros — `install.sh` prints AUR/source-build instructions since it can't always install this one for you)*

If your package manager isn't pacman/dnf/apt, or Quickshell isn't packaged for your distro yet, `install.sh` will print manual install pointers when it can't handle something itself — follow those rather than hunting for commands here.

**How to tell if Qt5Compat is the problem:** if the picker window opens but stays blank/transparent, or you see QML import errors mentioning `Qt5Compat` in your terminal when launching, that module is missing — re-run `install.sh` or install it manually per your distro's package name above.

---

## 🚀 Installation

```bash
git clone https://github.com/ujjalsigdel/hyprquickpaper.git ~/.config/hyprquickpaper
cd ~/.config/hyprquickpaper
chmod +x install.sh
./install.sh
```

Then launch with:
```bash
qs -p ~/.config/hyprquickpaper
```

Bind it to a Hyprland key so you don't retype that — add to `hyprland.conf` or `Keybindings.lua`:
```ini
bind = SUPER, W, exec, qs -p ~/.config/hyprquickpaper
```
or
```lua
hl.bind(
	mainMod .. " + CTRL + W",
	hl.dsp.exec_cmd("qs -p ~/.config/hyprquickpaper"),
	{ description = "Open HyprQuickPaper Wallpaper Picker" }
)
```

---

## ⚙️ Configuration

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
| `video_extensions` | Which file extensions are treated as videos (Classic layout only — see [Video Wallpapers](#-video-wallpapers)) rather than static images, both by the picker and by `commands.sh`/`cache.sh`. | Default list covers the common ones (`mp4`, `webm`, `mov`, `avi`, `mkv`, `gif`, `m4v`, `flv`, `wmv`, `mpeg`, `3gp`) — trim or extend as needed. |
| `video_thumbnail_interval` | Seconds into a video `cache.sh` seeks before grabbing the thumbnail frame. Falls back to 1s, then a frame-0 grab, if the video is shorter than this. | `5` is a reasonable default; lower it if your clips are short. |

Changes to `config.json` apply live — no restart needed. **This does not apply to the daemon autostart change below** — that one needs a session restart, since it's a compositor-level setting outside this project's control.

**Which `wallpaper_tool` should I actually pick?**

> Note: `wallpaper_tool` only governs *static images*. Any file matching `video_extensions` always plays through `mpvpaper` instead, regardless of what `wallpaper_tool` is set to — none of the static-image backends can render video. See [Video Wallpapers](#-video-wallpapers).

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

> **Video wallpaper support is currently Classic-only.** `shell-classic.qml` is the only layout with video detection, the `.jpg`-thumbnail lookup, and the **VIDEO** badge wired in. The other layouts' `FolderListModel.nameFilters` only match `.png`/`.jpg`/`.jpeg`, so video files simply won't appear in the picker there yet — they're not broken, just filtered out. If you want videos in another layout, see [Video Wallpapers](#-video-wallpapers) below for what to port over.

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

---

## ⌨️ Keybindings

| Key | Action |
|---|---|
| `h` / `←` | Previous wallpaper |
| `l` / `→` | Next wallpaper |
| `u` | Jump backward by `number_of_pictures` |
| `d` | Jump forward by `number_of_pictures` |
| `Space` / `Enter` | Apply the focused wallpaper and close |
| `Esc` | Close without changing anything |
| Mouse click | Select a card; click the already-selected card to apply it |

---

## 🛠️ Troubleshooting              

| Symptom | Fix |
|---|---|
| Blank/transparent window on launch | Missing Qt5Compat GraphicalEffects module — see Dependencies above. |
| Stuck on "Caching…", thumbnails never load | Confirm `cache_path` is writable and `convert` (ImageMagick) is on `PATH`: `which convert`. |
| Deck opens fine, but pressing Enter/Space does nothing | Two possible causes, check in order: **(1)** `wallpaper_tool` in `config.json` doesn't match what's actually installed (e.g. set to `hyprpaper` but you have `awww` installed) — fix in `config.json`. **(2)** `wallpaper_tool` is correct, but that backend's daemon isn't actually running — see [Switching wallpaper backends](#-switching-wallpaper-backends-the-part-configjson-cant-do) and check with `pgrep -a <daemon-name>`. |
| Picker doesn't highlight my actual current wallpaper | Confirm your `shell-*.qml` file's tracker path matches `~/.cache/hyprquickpaper/current_wallpaper` (this repo's default) rather than an old ML4W path. |
| Thumbnail generation freezes/slows the system on first launch | Lower `cache_batch_size` to your CPU thread count instead of `0`. |
| `.webp` wallpapers don't show up | The folder filter only matches `.png`/`.jpg`/`.jpeg` (plus `video_extensions`) — see Customization below. |
| Video files don't show up in the picker at all | Video support is currently Classic-layout only — see [Video Wallpapers](#-video-wallpapers). If you're already on `shell-classic.qml`, confirm the file's extension is listed in `video_extensions`. |
| Video wallpaper thumbnail is stuck on 🎬/never generates | Confirm `ffmpeg` is on `PATH` (`which ffmpeg`) and `cache_path` is writable. Check the `cache.sh` output for "Warning: Could not generate thumbnail for …" — some codecs/containers `ffmpeg` can't seek into will need a re-encode. |
| Video wallpaper thumbnail shows but it won't actually play | Confirm `mpvpaper` is installed (`which mpvpaper`) — it's not in most distros' official repos, see [Dependencies](#-dependencies). Video playback always goes through `mpvpaper` regardless of `wallpaper_tool`. |
| Wallpaper doesn't survive a reboot | Expected — this project doesn't manage boot-time restore. See "Persistence across reboots" above. |

---

## 🧩 Customization ideas

- Add more wallpaper formats: update the `find` filter in `cache.sh` and the `nameFilters` in whichever `shell-*.qml` you use to include `.webp` (or any other static image format).
- Port video wallpaper support to a layout other than Classic — see [Video Wallpapers](#-video-wallpapers) for what to copy over.
- Add a new wallpaper backend: add a `case` branch to `commands.sh`.
- Full-desktop re-theming on every pick (pywal/wallust-style): `commands.sh` has a commented-out "run your own commands after every wallpaper change" section at the bottom — uncomment and adapt it to regenerate a colorscheme and reload whatever apps you theme (waybar, notifications, browser, etc.). It runs after the wallpaper is set regardless of which `wallpaper_tool` you use.
- Add more layouts: copy an existing `shell-*.qml`, tweak it, and add the filename as an option in `shell.qml`.
- Swap the bundled font for your own by replacing the embedded font resource.

---

## 🤝 Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). PRs for new backends, layouts, or distro packaging (AUR, Nix, COPR) are welcome.
