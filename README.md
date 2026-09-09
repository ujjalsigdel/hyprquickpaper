# 🖼️ HyprQuickPaper

A fast, themeable, keyboard-driven Wayland wallpaper picker built with **Quickshell** and **QML** for Hyprland (and any other `wlr-layer-shell` compositor). Pick a wallpaper with `h`/`l`, jump around with `u`/`d`, confirm with `Space`/`Enter`, bail with `Esc`.

Originally based on [iamsurjog/hyprquickpaper](https://github.com/iamsurjog/hyprquickpaper), itself inspired by [ilyamiro's dots](https://github.com/ilyamiro/nixos-configuration). This fork is rebuilt to run on **any** Wayland wallpaper backend.

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

https://github.com/user-attachments/assets/5d9b33d8-4af2-49c8-ae8b-fc3031d17e4d

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
| **Classic List** *(default)*| Plain vertical/list (lightest on GPU) |
| **Bottom Dock**  | Sheared parallelogram deck along the bottom |
| **Coverflow** | 3D perspective coverflow |
| **Coverflow Clear** | Coverflow without blur |
| **Coverflow Minimal** | Coverflow without widgets |
| **Floating** | Tiered 3D cloud with glassmorphic overlay |
| **Floating Clear** | Floating with high-res background |
| **Floating Minimal** | Floating without overlay |
| **Hexacomb** | Honeycomb grid (2D navigation) |
| **Grid View** | A two-pane grid browser |

See [Layout Gallery](docs/LAYOUTS.md) to get proper overview of all the layouts.

---

## 🧩 Architecture: How it works

This project relies on two separate components working together:

- **The UI (Quickshell):** The visual picker (`shell.qml`) that handles the card deck, animations, thumbnails, and keyboard navigation. 
- **The Wallpaper Backend:** The background daemon (`awww`, `hyprpaper`, `swaybg`, etc.) that actually paints the image on your screen. 

When you press `Enter`, the UI hands the chosen file to the `wallpaper_tool` defined in your `config.json`. 
> ⚠️ **Note:** Your backend daemon must be autostarted by your compositor (e.g., in `hyprland.conf`), not by this project. See [Switching wallpaper backends](docs/CONFIGURATION.md#-switching-wallpaper-backends-the-part-configjson-cant-do).

---

## 🎬 Video Wallpapers

You can use video files (e.g., `.mp4`, `.webm`) alongside static images. **Currently supported in the Classic layout only (`shell-classic.qml`).**

- **How it works:** `cache.sh` generates a still thumbnail using `ffmpeg`, and the UI displays a **VIDEO** badge. When selected, the UI bypasses your static image backend and plays the video automatically via `mpvpaper` (muted and looping).
- **Requirements:** `ffmpeg` (for thumbnails) and `mpvpaper` (for playback). *(Note: `mpvpaper` usually requires an AUR/source build).*
- **Config:** Adjust `video_extensions` and `video_thumbnail_interval` in [Configuration](docs/CONFIGURATION.md).
- **Porting to other layouts:** Copy `isVideoFile()`, `getThumbnailSource()`, and `videoExtensions` from `shell-classic.qml`. Add the video extensions to your layout's `nameFilters`, and copy the VIDEO badge `Rectangle` into the delegate. No bash changes are needed.

Tip : you can use [mpvpaper-stop](https://github.com/pvtoari/mpvpaper-stop) to pause the wallpaper when it’s in background to save on resources and battery usage.

---

## 📋 Dependencies

`install.sh` detects your package manager (pacman / dnf / apt) and installs all of these automatically, including the one that's easy to miss or simply checkout [Hyprland Wiki](https://wiki.hypr.land/Useful-Utilities/Wallpapers/):

- [Quickshell](https://quickshell.org) (`qs` / `quickshell`) — renders the whole UI
- `jq` — parses `config.json`
- `imagemagick` (`convert`) — generates the thumbnail cache
- **Qt5Compat GraphicalEffects** QML module — powers the rounded-corner card masking; not bundled with base Qt
- A wallpaper backend of your choice: [awww](https://codeberg.org/LGFae/awww), [hyprpaper](https://wiki.hypr.land/Hypr-Ecosystem/hyprpaper/), [waypaper](https://github.com/anufrievroman/waypaper), [swaybg](https://github.com/swaywm/swaybg), or `feh`
- `ffmpeg` — generates video thumbnails *(only needed if you have video wallpapers)*
- [mpvpaper](https://github.com/GhostNaN/mpvpaper) — plays video wallpapers *(only needed if you have video wallpapers; not in official repos on most distros — `install.sh` prints AUR/source-build instructions since it can't always install this one for you)*

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
| Deck opens fine, but pressing Enter/Space does nothing | Two possible causes, check in order: **(1)** `wallpaper_tool` in `config.json` doesn't match what's actually installed (e.g. set to `hyprpaper` but you have `awww` installed) — fix in `config.json`. **(2)** `wallpaper_tool` is correct, but that backend's daemon isn't actually running — see [Switching wallpaper backends](docs/CONFIGURATION.md#-switching-wallpaper-backends-the-part-configjson-cant-do) and check with `pgrep -a <daemon-name>`. |
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
