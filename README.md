# 🖼️ HyprQuickPaper

A fast, themeable, keyboard-driven Wayland wallpaper picker built with **Quickshell** and **QML** for Hyprland (and any other `wlr-layer-shell` compositor). Handles both static images and video wallpapers, across multiple layouts. Pick with `h`/`l`, jump around with `u`/`d`, confirm with `Space`/`Enter`, bail with `Esc`.

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

> **Note:** In the demo video, there's a noticeable delay after selecting a video before it gets applied. This was caused by some module issues during recording — on the same config, it's currently snappy. Actual performance may vary depending on your system.

---

## 🎯 Who is this for?

HyprQuickPaper is a picker, not a platform: no daemon, no database, no wallpaper
management — it hands your choice to whatever backend you already run.

**This is for you if:**
- You already have a rice and just want a fast keybound picker
- You're happy using a layout as-is, or forking one and tweaking the QML yourself
- You don't want a background daemon running when you're not picking wallpapers

**Not for you if you want:**
- Full library management, Wallpaper Engine Scenes, auto theming, or scheduling

If that's what you need, check out [skwd-wall](https://github.com/liixini/skwd-wall) — a much bigger wallpaper engine that covers all of that. Different tool, different job.

---

## ✨ Features

- **Multiple layout modes** — Bottom Dock, Coverflow, Floating, Grid, Hexacomb, and more.
- **Video wallpapers** — `.mp4`/`.webm`/`.mov`/etc. play via `mpvpaper`, auto-thumbnailed with `ffmpeg`. Supported in **every layout except Hexacomb**.
- **Lossless background preview** — Renders the full-resolution image behind the dock.
- **Automatic thumbnail cache** — Smooth scrolling for hundreds of wallpapers.
- **Live config reload** — `config.json` changes apply immediately.
- **Backend-agnostic** — Works seamlessly with awww, hyprpaper, waypaper, swaybg, or feh.

---

## 📸 Layouts

| Layout | Description |
|--------|-------------|
| **Classic List** *(default)* | Plain vertical/list (lightest on GPU) |
| **Bottom Dock**  | Sheared parallelogram deck along the bottom |
| **Coverflow** | 3D perspective coverflow |
| **Coverflow Clear** | Coverflow without blur |
| **Coverflow Minimal** | Coverflow without widgets |
| **Floating** | Tiered 3D cloud with glassmorphic overlay |
| **Floating Clear** | Floating with high-res background |
| **Floating Minimal** | Floating without overlay |
| **Hexacomb** | Honeycomb grid (2D navigation) |
| **Grid View** | A two-pane grid browser |

*All layouts support video wallpapers except Hexacomb.*

See [Layout Gallery](docs/LAYOUTS.md) to get a proper overview of all the layouts.

---

## 🧩 Architecture: How it works

This project relies on two separate components working together:

- **The UI (Quickshell):** The visual picker (`shell.qml`) that handles the card deck, animations, thumbnails, and keyboard navigation.
- **The Wallpaper Backend:** The background daemon (`awww`, `hyprpaper`, `swaybg`, etc.) that actually paints the image on your screen.

When you press `Enter`, the UI hands the chosen file to the `wallpaper_tool` defined in your `config.json`.
> ⚠️ **Note:** Your backend daemon must be autostarted by your compositor (e.g., in `hyprland.conf`), not by this project. See [Switching wallpaper backends](docs/CONFIGURATION.md#-switching-wallpaper-backends-the-part-configjson-cant-do).

---

## 🎬 Video Wallpapers

Video files (`.mp4`, `.webm`, `.mov`, etc.) work alongside static images in **every layout except Hexacomb**.

- **How it works:** `cache.sh` uses `ffmpeg` to extract one high-quality frame from each video, then derives a small picker thumbnail from it. Cards show the thumbnail with a **VIDEO** badge, and layouts with a full-screen background preview show the HQ still. On selection, the UI bypasses your static image backend and plays the video via `mpvpaper` (muted, looping).
- **Cache layout:** for each `foo.mp4` you get `foo.jpg` (picker thumbnail) and `foo.hq.jpg` (background preview still). Both regenerate automatically if deleted or missing.
- **Requirements:** `ffmpeg` for thumbnails, `mpvpaper` for playback. *(mpvpaper usually requires an AUR/source build — `install.sh` prints instructions since it can't always install it for you.)*
- **Config:** adjust `video_extensions` and `video_thumbnail_interval` in [Configuration](docs/CONFIGURATION.md).
- **Saving resources:** [mpvpaper-stop](https://github.com/pvtoari/mpvpaper-stop) pauses playback when the wallpaper isn't visible — worth using on laptops.

---

## 📋 Dependencies

`install.sh` automatically sets up dependencies. If your package manager isn't pacman/dnf/apt, or Quickshell isn't packaged for your distro yet, `install.sh` will print manual install pointers when it can't handle something itself — follow those rather than hunting for commands here. Also check out the [Hyprland Wiki](https://wiki.hypr.land/Useful-Utilities/Wallpapers/):

- [Quickshell](https://quickshell.org) (`qs` / `quickshell`) — renders the whole UI
- `jq` — parses `config.json`
- `imagemagick` (`convert`) — generates the thumbnail cache
- **Qt5Compat GraphicalEffects** QML module — powers the rounded-corner card masking; not bundled with base Qt
- A wallpaper backend of your choice: [awww](https://codeberg.org/LGFae/awww), [hyprpaper](https://wiki.hypr.land/Hypr-Ecosystem/hyprpaper/), [waypaper](https://github.com/anufrievroman/waypaper), [swaybg](https://github.com/swaywm/swaybg), or `feh`
- `ffmpeg` — generates video thumbnails *(only needed if you have video wallpapers)*
- [mpvpaper](https://github.com/GhostNaN/mpvpaper) — plays video wallpapers *(only needed if you have video wallpapers; not in official repos on most distros — `install.sh` prints AUR/source-build instructions since it can't always install this one for you)*

> 💡 **Having issues launching or generating thumbnails?** Check the **[Troubleshooting Guide](docs/TROUBLESHOOTING.md)**.

---

## 🚀 Installation

```bash
git clone https://github.com/ujjalsigdel/hyprquickpaper.git ~/.config/quickshell/hyprquickpaper
cd ~/.config/quickshell/hyprquickpaper
chmod +x install.sh
./install.sh
```

Then launch with:
```bash
qs -p ~/.config/quickshell/hyprquickpaper
```

Bind it to a Hyprland key so you don't retype that — add to `hyprland.conf` or `Keybindings.lua`:
```ini
bind = SUPER, W, exec, qs -p ~/.config/quickshell/hyprquickpaper
```
or
```lua
hl.bind(
	mainMod .. " + CTRL + W",
	hl.dsp.exec_cmd("qs -p ~/.config/quickshell/hyprquickpaper"),
	{ description = "Open HyprQuickPaper Wallpaper Picker" }
)
```

---

## ⚙️ Configuration

Edit `config.json` — the **only required change** for most users:

```json
{
  "wallpaper_tool": "auto",
  "wallpaper_path": "~/Pictures/Wallpapers/"
}
```

**Key fields:**
- `wallpaper_tool` — Which backend to use. `"auto"` (default) detects your running daemon; you can also set `awww`, `hyprpaper`, `swaybg`, etc.
- `wallpaper_path` — Your wallpaper folder
- `custom_command` — Optional. For desktop shells that manage wallpapers themselves (Noctalia, etc.) — set this to whatever command your shell uses, with `$WALLPAPER` as the path.
- `post_apply` — Optional array of shell commands to run after every wallpaper change. Ideal for matugen/wallust/pywal theming or reloading your bar.
- `video_extensions` — Video formats to support

See [Full Configuration](docs/CONFIGURATION.md) — covers all fields, backend switching, custom commands, video setup, and layout selection.

> [!TIP]
> **On battery or a low-end PC, you may briefly see `Loading…` on the cards when the picker opens.** It's cosmetic — images just haven't decoded yet. Fixable by raising two numbers in your layout file: see [Loading label appears on battery or low-end PCs](docs/CONFIGURATION.md#loading-label-appears-on-battery-or-low-end-pcs).

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

If you encounter issues like a blank window on launch, missing thumbnails, or video playback errors, check out the full guide:

➡️ **[View the Troubleshooting Guide](docs/TROUBLESHOOTING.md)**

---

## 🧩 Customization ideas

- Add more wallpaper formats: update the `find` filter in `cache.sh` and the `nameFilters` in whichever `shell-*.qml` you use to include `.webp` (or any other static image format).
- Port video wallpaper support to Hexacomb — copy `isVideoFile()`, `getThumbnailSource()`, `getVideoPreviewSource()`, the `videoExtensions` property, and the VIDEO badge `Rectangle` from any existing layout.
- Add a new wallpaper backend: add a `case` branch to `commands.sh`.
- Full-desktop re-theming on every pick (pywal/wallust-style): `commands.sh` has a commented-out "run your own commands after every wallpaper change" section at the bottom — uncomment and adapt it to regenerate a colorscheme and reload whatever apps you theme (waybar, notifications, browser, etc.). It runs after the wallpaper is set regardless of which `wallpaper_tool` you use.
- Add more layouts: copy an existing `shell-*.qml`, tweak it, and add the filename as an option in `shell.qml`.
- Swap the bundled font for your own by replacing the embedded font resource.

---

## 🤝 Contributing

See [CONTRIBUTING.md](docs/CONTRIBUTING.md). PRs for new backends, layouts, or distro packaging (AUR, Nix, COPR) are welcome.
