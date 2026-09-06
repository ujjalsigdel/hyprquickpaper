# 🖼️ HyprQuickPaper

A fast, themeable, keyboard-driven Wayland wallpaper picker built with **Quickshell** and **QML** for Hyprland (and other `wlr-layer-shell` compositors). Pick a wallpaper with `h`/`l`, jump around with `u`/`d`, confirm with `Space`/`Enter`, bail with `Esc`.

Originally based on [iamsurjog/hyprquickpaper](https://github.com/iamsurjog/hyprquickpaper), itself inspired by [ilyamiro's dots](https://github.com/ilyamiro/nixos-configuration). This fork rebuilds and re-documents it for general use beyond ML4W dotfiles.

> [!IMPORTANT]
> **This project ships pre-configured for ML4W Dotfiles.** If you are **not** using `ml4w-wallpaper`, you **must** edit three things before it will work correctly: `config.json`, `commands.sh`, **and** the `activeWallpaperFile` path inside whichever `shell-*.qml` layout you use. See the [Configuration](#-configuration-read-this-before-running) section — it's not optional.

---

## ✨ Features

- **Multiple layout modes** — switch between Bottom Dock, Coverflow, Coverflow+Widgets, Classic list, and a no-blur widgets variant by editing one line in `shell.qml`.
- **Sheared bottom-dock deck** — parallelogram cards, rounded corners, uniform height, active-selection glow border.
- **Lossless full-quality background preview** — the picker renders the actual selected image full-res behind the dock (not the downscaled thumbnail), crossfaded between picks.
- **Automatic thumbnail cache** — generates and reuses downscaled previews via ImageMagick so scrolling stays smooth even with hundreds of wallpapers.
- **Live config reload** — `config.json` changes apply immediately without restarting (no need to relaunch Quickshell after tweaking colors/paths).
- **Fully keyboard-driven** — no mouse required (though clicking works too).
- **Embedded custom typography** — no manual font install needed for the bundled display font.

---

## 📸 Layout Preview

| Bottom Dock | Coverflow | Classic List |
|---|---|---|
| ![Bottom Dock](assets/screenshots/bottom-dock.jpg) | ![Coverflow](assets/screenshots/coverflow.jpg) | ![Classic](assets/screenshots/classic.jpg) |

*(Add your own screenshots under `assets/screenshots/` — the images above are placeholders referencing that path.)*

Two more layouts ship but aren't pictured yet: `shell-coverflow-widgets.qml` (coverflow + extra widgets, **the default layout out of the box**) and `shell-widgets-noblur.qml` (same widgets, blur disabled — use this if your GPU/compositor struggles with blur).

---

## 📋 Dependencies

Install these before running `install.sh` (or let `install.sh` attempt it for you):

| Package | Why it's needed |
|---|---|
| [Quickshell](https://git.outfoxxed.me/quickshell/quickshell) (`qs` / `quickshell`) | The QML runtime/shell that renders everything. |
| `jq` | Parses `config.json` inside `cache.sh`. |
| `imagemagick` (`convert`) | Generates the downscaled thumbnail cache. |
| **Qt6 5-Compat module** (Arch: `qt6-5compat`) | Provides `Qt5Compat.GraphicalEffects`, used for the rounded-corner card masking. **Not installed by `install.sh` — install manually if it's missing.** |
| `bash`, `fontconfig`, `findutils` | Scripting + the bundled font. |
| A Wayland compositor with `wlr-layer-shell` support (Hyprland, Sway, etc.) | Required for the overlay panel itself. |
| A wallpaper-setting tool: `swww`, `hyprpaper`, `swaybg`, `waypaper`, or `feh` | Whatever `commands.sh` actually calls — see below. Not installed automatically; pick one and install it yourself. |

---

## 🚀 Installation

```bash
git clone https://github.com/<you>/hyprquickpaper.git ~/.config/quickshell/hyprquickpaper
cd ~/.config/quickshell/hyprquickpaper
./install.sh
```

`install.sh` will:
1. Detect your package manager (`pacman` / `dnf` / `apt`) and install `jq` + `imagemagick` if missing.
2. Attempt to install Quickshell if it isn't already on your system (may require AUR/`quickshell-git` on Arch if not in the official repos).
3. `chmod +x` the shell scripts.

Then launch it with:
```bash
qs -c hyprquickpaper
```
(Because it was cloned into `~/.config/quickshell/hyprquickpaper`, Quickshell resolves the config by name via `-c <name>`.)

Bind it to a Hyprland key so you don't have to type that every time — add to `hyprland.conf`:
```ini
bind = SUPER, W, exec, qs -c hyprquickpaper
```

---

## ⚙️ Configuration — read this before running

There are **three** places to edit, not two. Skipping any of them means the picker will either fail to set your wallpaper, or just never highlight your current one on open (harmless but confusing).

### 1. `config.json` — paths and appearance

```json
{
  "wallpaper_path": "~/Pictures/Wallpapers/",
  "cache_path": "~/.cache/quickshell/thumbs/",
  "number_of_pictures": 7,
  "border_color": "#C27B63",
  "cache_batch_size": 20
}
```

| Key | Meaning | What to set |
|---|---|---|
| `wallpaper_path` | Folder scanned for `.png` / `.jpg` / `.jpeg` files. Used for both thumbnails and the full-quality background preview. | Your real wallpaper directory, **with a trailing `/`**, e.g. `"~/Wallpapers/"`. `~` is expanded for you. |
| `cache_path` | Where generated thumbnails live. Auto-created on first run. | Leave default, or point somewhere faster (e.g. tmpfs) if you have thousands of wallpapers. |
| `number_of_pictures` | **Not a display count** — it's the jump distance for the `u`/`d` fast-scroll keys. | Larger folder → bigger number (10–15+) so fast-scroll actually saves time. |
| `border_color` | Hex color of the selected card's highlight border. | Any hex, e.g. `"#89b4fa"`, to match your theme. |
| `cache_batch_size` | Max parallel `convert` (ImageMagick) processes while building the thumbnail cache. `0` = unlimited, all at once. | Set to roughly your CPU thread count (`4`–`16`). Avoid `0` on large wallpaper folders — it will spawn one process per image simultaneously and can hang low-core machines. |

Config changes are picked up **live** — no restart needed.

### 2. `commands.sh` — how a picked wallpaper actually gets applied

This is the file you are most likely to need to change. It receives the chosen file's full path as `$1` and must call whatever tool applies wallpapers on your system. **Only one snippet in the sections below is what actually runs — delete or comment out the rest.**

<details>
<summary><b>swww</b> (recommended for most non-ML4W setups)</summary>

```bash
#!/usr/bin/env bash
WALLPAPER="$1"
if [ -n "$WALLPAPER" ]; then
    swww img "$WALLPAPER" --transition-type grow --transition-duration 1 --transition-fps 60
fi
```
Requires `swww-daemon` running first — add `exec-once = swww-daemon` to `hyprland.conf`.
</details>

<details>
<summary><b>hyprpaper</b></summary>

```bash
#!/usr/bin/env bash
WALLPAPER="$1"
if [ -n "$WALLPAPER" ]; then
    hyprctl hyprpaper unload all
    hyprctl hyprpaper preload "$WALLPAPER"
    hyprctl hyprpaper wallpaper ",$WALLPAPER"
fi
```
`unload all` prevents old wallpapers from piling up in memory across repeated picks.
</details>

<details>
<summary><b>waypaper</b> (as a CLI backend)</summary>

```bash
#!/usr/bin/env bash
WALLPAPER="$1"
if [ -n "$WALLPAPER" ]; then
    waypaper --wallpaper "$WALLPAPER"
fi
```
</details>

<details>
<summary><b>swaybg</b></summary>

```bash
#!/usr/bin/env bash
WALLPAPER="$1"
if [ -n "$WALLPAPER" ]; then
    pkill swaybg
    swaybg -i "$WALLPAPER" -m fill &
fi
```
</details>

<details>
<summary><b>feh</b> (X11/XWayland only — not truly Wayland-native)</summary>

```bash
#!/usr/bin/env bash
WALLPAPER="$1"
if [ -n "$WALLPAPER" ]; then
    feh --bg-fill "$WALLPAPER"
fi
```
</details>

<details>
<summary><b>ML4W</b> (default, out of the box)</summary>

```bash
#!/usr/bin/env bash
WALLPAPER="$1"
if [ -n "$WALLPAPER" ]; then
    $HOME/.config/ml4w/scripts/ml4w-wallpaper "$WALLPAPER"
fi
```
</details>

After editing: `chmod +x commands.sh`.

### 3. `shell.qml` + the active layout file — which UI renders, and the ML4W state-tracking hook

**a) Pick your layout in `shell.qml`:**
```qml
property string activeLayout: "shell-coverflow-widgets.qml"
```
Only one line should be uncommented. Options: `shell-bottom-dock.qml`, `shell-coverflow.qml`, `shell-coverflow-widgets.qml`, `shell-classic.qml`, `shell-widgets-noblur.qml`.

**b) Fix the "highlight current wallpaper on open" hook inside that layout file.**
Every `shell-*.qml` layout contains this block, which is how the picker figures out which card to pre-select when it opens (by reading ML4W's own state file):
```qml
FileView {
    id: activeWallpaperFile
    path: Quickshell.env("HOME") + "/.cache/ml4w/hyprland-dotfiles/current_wallpaper"
    watchChanges: false
}
```
If you're not on ML4W, this path won't exist — nothing breaks, it just silently falls back to opening on the middle wallpaper every time. To make it actually track your current wallpaper:
1. Have `commands.sh` write the chosen path to your own state file, e.g. append this line to whichever `commands.sh` variant you used above:
   ```bash
   echo "$WALLPAPER" > "$HOME/.cache/hyprquickpaper/current_wallpaper"
   ```
2. Point the `FileView` above at that same path:
   ```qml
   path: Quickshell.env("HOME") + "/.cache/hyprquickpaper/current_wallpaper"
   ```

---

## ⌨️ Keybindings

| Key | Action |
|---|---|
| `h` / `←` | Previous wallpaper |
| `l` / `→` | Next wallpaper |
| `u` | Jump backward by `number_of_pictures` |
| `d` | Jump forward by `number_of_pictures` |
| `Space` / `Enter` | Apply the currently focused wallpaper and close |
| `Esc` | Close without changing anything |
| Mouse click | Click a card to select it; click the already-selected card to apply it |

---

## 🛠️ Troubleshooting

- **Blank/transparent screen on launch** — usually missing `Qt5Compat.GraphicalEffects` (package `qt6-5compat` on Arch). Confirm it's installed.
- **Thumbnails never show, stuck on "Caching…"** — check `cache_path` is writable and `imagemagick`'s `convert` is on your `PATH`. Also confirm your images are `.jpg`/`.jpeg`/`.png` — other formats (`.webp`, `.gif`) aren't picked up by the current folder filter.
- **Wallpaper picked but nothing changes** — `commands.sh` almost certainly still points at the ML4W script. See [Configuration](#-configuration-read-this-before-running) above.
- **Picker doesn't highlight my actual current wallpaper on open** — expected unless you've repointed the `activeWallpaperFile` path (see above); it's a cosmetic fallback, not a crash.
- **Thumbnail generation is slow/freezes system on first launch** — lower `cache_batch_size` in `config.json` to your CPU thread count instead of leaving it unlimited (`0`) or very high.

---

## 🧩 Customization ideas

- Swap the bundled font for your own by replacing the embedded font resource.
- Add more layouts by copying an existing `shell-*.qml` and registering the filename in `shell.qml`.
- Extend `cache.sh`'s `find` filter to include `.webp`/`.gif` if your wallpaper folder uses them (update the `FolderListModel` `nameFilters` in the QML layout to match).

---

## 🤝 Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Issues and PRs for additional layouts, wallpaper-tool backends, or packaging (AUR, Nix) are welcome.

## 📄 License

MIT — see [LICENSE](LICENSE). *(Add a LICENSE file if one isn't present yet — this matters if you want others to freely reuse/fork it.)*
