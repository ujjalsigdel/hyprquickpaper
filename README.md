# 🖼️ HyprQuickPaper

A fast, themeable, keyboard-driven Wayland wallpaper picker built with **Quickshell** and **QML** for Hyprland (and any other `wlr-layer-shell` compositor). Pick a wallpaper with `h`/`l`, jump around with `u`/`d`, confirm with `Space`/`Enter`, bail with `Esc`.

Originally based on [iamsurjog/hyprquickpaper](https://github.com/iamsurjog/hyprquickpaper), itself inspired by [ilyamiro's dots](https://github.com/ilyamiro/nixos-configuration). This fork is rebuilt to run on **any** Wayland wallpaper backend, not just ML4W dotfiles.

> [!IMPORTANT]
> **Before using:** Make sure `wallpaper_tool` in `config.json` matches your installed backend (`awww`, `hyprpaper`, `swaybg`, etc.), and the backend's daemon is running.  
> See the [Configuration Guide](docs/CONFIGURATION.md) for details.

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

## 🎬 Demo


---

## ✨ Features

- **Multiple layout modes** — Bottom Dock, Coverflow, Hexacomb, Grid, and more.
- **Video wallpapers** — `.mp4`/`.webm`/`.mov`/etc. play via `mpvpaper`, auto-thumbnailed with `ffmpeg`.
- **Lossless background preview** — Renders the full-resolution image behind the dock.
- **Automatic thumbnail cache** — Smooth scrolling for hundreds of wallpapers.
- **Live config reload** — `config.json` changes apply immediately.
- **Backend-agnostic** — Works seamlessly with awww, hyprpaper, waypaper, swaybg, or feh.

---

## 📸 Layouts

| Layout | Description |
|--------|-------------|
| **Bottom Dock** *(default)* | Sheared parallelogram deck along the bottom |
| **Coverflow** | 3D perspective coverflow |
| **Coverflow Clear** | Coverflow without blur |
| **Coverflow Minimal** | Coverflow without widgets |
| **Floating** | Tiered 3D cloud with glassmorphic overlay |
| **Floating Clear** | Floating with high-res background |
| **Floating Minimal** | Floating without overlay |
| **Hexacomb** | Honeycomb grid (2D navigation) |
| **Classic List** | Plain vertical/list (lightest on GPU) |

See [Layout Gallery](docs/LAYOUTS.md) to get proper overview of all the layouts.

---

## 🧩 How it works: two separate pieces

This project is really two things working together, and it helps to know the difference before you touch `config.json`:

- **Quickshell** (via `shell.qml` / `shell-*.qml`) is the picker UI itself — the card deck, the animations, keyboard navigation, thumbnail rendering. It's what you actually see and interact with. Quickshell has no idea how to change your desktop background; that's not its job.
- **The wallpaper backend** (`awww`, `hyprpaper`, `swaybg`, `waypaper`, `feh`, or `ml4w`) is a separate program whose only job is: take an image path, paint it on screen. Once you press `Space`/`Enter` in the picker, `commands.sh` hands the chosen file off to whichever backend `wallpaper_tool` in `config.json` names. Most of these backends (`awww`, `hyprpaper`, `swaybg`) run as a **background daemon** that must already be running before `commands.sh` can talk to it — that daemon is started by your compositor config, not by this project. See [Switching wallpaper backends](#-switching-wallpaper-backends-the-part-configjson-cant-do).

So Quickshell is always used — no choice there, it's the engine this whole project runs on. `wallpaper_tool` is the one thing you pick based on what's actually installed and running on your system. See [Configuration](#-configuration) for which backend to choose.

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

Edit `config.json` — the **only required change** for most users:

```json
{
  "wallpaper_tool": "awww",
  "wallpaper_path": "~/Pictures/Wallpapers/"
}
```

**Key fields:**
- `wallpaper_tool` — Which backend to use (`awww`, `hyprpaper`, `swaybg`, etc.)
- `wallpaper_path` — Your wallpaper folder
- `video_extensions` — Video formats to support (Classic layout only)

See [Full Configuration](docs/CONFIGURATION.md) — covers all fields, backend switching, video setup, and layout selection.

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

See [CONTRIBUTING.md](docs/CONTRIBUTING.md). PRs for new backends, layouts, or distro packaging (AUR, Nix, COPR) are welcome.
