# 🖼️ HyprQuickPaper

A fast, themeable, keyboard-driven Wayland wallpaper picker built with **Quickshell** and **QML** for Hyprland (and any other `wlr-layer-shell` compositor). Pick a wallpaper with `h`/`l`, jump around with `u`/`d`, confirm with `Space`/`Enter`, bail with `Esc`.

Originally based on [iamsurjog/hyprquickpaper](https://github.com/iamsurjog/hyprquickpaper), itself inspired by [ilyamiro's dots](https://github.com/ilyamiro/nixos-configuration). This fork is rebuilt to run on **any** Wayland wallpaper backend, not just ML4W dotfiles.

> [!IMPORTANT]
> Out of the box this only needs **one** edit for most non-ML4W users: set `wallpaper_tool` in `config.json`. See [Configuration](#-configuration) below — everything else is optional tuning.

---

## ✨ Features

- **Multiple layout modes** — Bottom Dock, Coverflow, Coverflow+Widgets, Classic list, and a no-blur widgets variant. Switch by editing one line in `shell.qml`.
- **Sheared bottom-dock deck** — parallelogram cards, rounded corners, uniform height, active-selection glow border.
- **Lossless full-quality background preview** — renders the actual full-resolution image behind the dock (not the downscaled thumbnail), crossfaded between picks.
- **Automatic thumbnail cache** — downscaled previews generated via ImageMagick so scrolling stays smooth with hundreds of wallpapers.
- **Live config reload** — `config.json` changes apply immediately, no restart needed.
- **Fully keyboard-driven** — no mouse required, though clicking works too.
- **Backend-agnostic** — works with swww, hyprpaper, waypaper, swaybg, or feh via a single config field, no bash editing required for common setups.
- **Embedded custom typography** — bundled display font, no manual install needed.

---

## 📸 Layouts

### Bottom Dock *(default)*
A sheared, parallelogram card deck along the bottom of the screen, uniform card height, with the focused card scaled up and outlined in your accent color.

![Bottom Dock](assets/screenshots/bottom-dock.jpg)

### Coverflow
Cards fan out in 3D-style perspective around the focused item, classic "coverflow" browsing feel.

![Coverflow](assets/screenshots/coverflow.jpg)

### Coverflow + Widgets
Same coverflow browsing, with extra on-screen widgets (clock/info) layered in.

*(add a screenshot to `assets/screenshots/coverflow-widgets.jpg` and update the link here)*

### Classic List
A plain vertical/list layout — lightest on GPU, good for weaker hardware or minimal setups.

![Classic List](assets/screenshots/classic.jpg)

### Widgets (No Blur)
Same widget layout as Coverflow+Widgets, with background blur disabled — use this if your compositor/GPU can't keep blur smooth.

*(add a screenshot to `assets/screenshots/widgets-noblur.jpg` and update the link here)*

> Screenshots referenced above go under `assets/screenshots/` in this repo — add your own there.

---

## 📋 Dependencies — and how to actually install each one

| Dependency | What it's for |
|---|---|
| [Quickshell](https://quickshell.org) (`qs` / `quickshell`) | Renders the whole UI. |
| `jq` | Parses `config.json` in `cache.sh` / `commands.sh`. |
| `imagemagick` (`convert`) | Generates the thumbnail cache. |
| **Qt5Compat GraphicalEffects QML module** | Powers the rounded-corner card masking (`Qt5Compat.GraphicalEffects` import). Easy to miss — not bundled with base Qt. |
| A wallpaper backend: `swww`, `hyprpaper`, `waypaper`, `swaybg`, or `feh` | Whichever `commands.sh` actually calls (set via `wallpaper_tool` in `config.json`). |

`install.sh` handles all of the above automatically where possible. If it can't (e.g. no supported package manager, or Quickshell not packaged for your distro), here's exactly what to run yourself:

<details>
<summary><b>Arch / Arch-based</b></summary>

```bash
# Core tools
sudo pacman -S --needed jq imagemagick

# Qt5Compat GraphicalEffects
sudo pacman -S --needed qt6-5compat

# Quickshell — AUR only, not in the official repos
yay -S quickshell-git      # or: paru -S quickshell-git

# A wallpaper backend, e.g.:
sudo pacman -S --needed swww
```
</details>

<details>
<summary><b>Fedora</b></summary>

```bash
# Core tools
sudo dnf install -y jq ImageMagick

# Qt5Compat GraphicalEffects
sudo dnf install -y qt6-qt5compat

# Quickshell — via community COPR
sudo dnf copr enable errornointernet/quickshell
sudo dnf install -y quickshell

# A wallpaper backend, e.g. swww (may need to be built from source/COPR on Fedora)
```
</details>

<details>
<summary><b>Debian / Ubuntu</b></summary>

```bash
# Core tools
sudo apt update && sudo apt install -y jq imagemagick

# Qt5Compat GraphicalEffects
sudo apt install -y qml6-module-qt5compat-graphicaleffects

# Quickshell — no official .deb yet. Two working options:
#   1) Nix:  nix profile install nixpkgs#quickshell
#   2) Build from source: https://git.outfoxxed.me/quickshell/quickshell (see BUILD.md)
```
</details>

<details>
<summary><b>NixOS / Nix (any distro)</b></summary>

Quickshell ships an embedded flake — see the [Quickshell Nix install docs](https://quickshell.org/docs/guide/install-setup) for the flake snippet. `jq`, `imagemagick`, and `qt6.qt5compat` are all in nixpkgs normally.
</details>

**How to tell if Qt5Compat is actually the problem:** if the picker window opens but stays blank/transparent, or you see QML import errors mentioning `Qt5Compat` in your terminal when launching with `qs -c hyprquickpaper`, that's the missing module — install it per your distro above and relaunch.

---

## 🚀 Installation

```bash
git clone https://github.com/<you>/hyprquickpaper.git ~/.config/quickshell/hyprquickpaper
cd ~/.config/quickshell/hyprquickpaper
./install.sh
```

Then launch with:
```bash
qs -c hyprquickpaper
```

Bind it to a Hyprland key so you don't retype that — add to `hyprland.conf`:
```ini
bind = SUPER, W, exec, qs -c hyprquickpaper
```

---

## ⚙️ Configuration

### `config.json`

```json
{
  "wallpaper_path": "~/Pictures/Wallpapers/",
  "cache_path": "~/.cache/quickshell/thumbs/",
  "wallpaper_tool": "swww",
  "number_of_pictures": 7,
  "border_color": "#C27B63",
  "cache_batch_size": 20
}
```

| Key | Meaning | What to set |
|---|---|---|
| `wallpaper_path` | Folder scanned for `.png`/`.jpg`/`.jpeg` files. | Your real wallpaper directory, **with a trailing `/`**, e.g. `"~/Wallpapers/"`. |
| `cache_path` | Where generated thumbnails live. Auto-created on first run. | Leave default, or point at tmpfs if you have thousands of wallpapers. |
| `wallpaper_tool` | **This is the one field almost everyone needs to change.** Selects which backend `commands.sh` uses. | One of `swww`, `hyprpaper`, `waypaper`, `swaybg`, `feh`, `ml4w`. |
| `number_of_pictures` | Jump distance for the `u`/`d` fast-scroll keys (not a display count). | Larger folder → bigger number (10–15+). |
| `border_color` | Hex color of the selected card's border. | Any hex, e.g. `"#89b4fa"`. |
| `cache_batch_size` | Max parallel `convert` jobs while building thumbnails. `0` = unlimited. | Set to roughly your CPU thread count (`4`–`16`) — don't leave at `0` with a large wallpaper folder. |

Changes apply live — no restart needed.

### `commands.sh`

You shouldn't need to edit this at all for the six supported backends — just set `wallpaper_tool` above. It also writes the active wallpaper to `~/.cache/hyprquickpaper/current_wallpaper` after every pick, so the "highlight current wallpaper" feature works regardless of backend.

Only edit `commands.sh` directly if you need a backend that isn't in the preset list (e.g. `mpvpaper`, a custom script) — add a new `case` branch following the existing pattern.

> **Don't just copy `ml4w-wallpaper` from an ML4W install and point `commands.sh` at it.** That script also drives a hyprpaper template, ImageMagick wallpaper "effects", ML4W's own wallpaper-generated cache, and SDDM background sync — all tied to a full ML4W install. Outside of ML4W it will error out or silently no-op. Use the `swww`/`hyprpaper`/etc. presets above instead — they do the one job (set the wallpaper) with no hidden dependencies.

### `shell.qml` — which layout renders

```qml
property string activeLayout: "shell-bottom-dock.qml"
```
Only one line should be uncommented. Options: `shell-bottom-dock.qml`, `shell-coverflow.qml`, `shell-coverflow-widgets.qml`, `shell-classic.qml`, `shell-widgets-noblur.qml`.

### `shell-*.qml` — repoint the "current wallpaper" tracker (one command, fixes all layouts)

```bash
cd ~/.config/quickshell/hyprquickpaper
sed -i 's#/.cache/ml4w/hyprland-dotfiles/current_wallpaper#/.cache/hyprquickpaper/current_wallpaper#' shell-*.qml
```
This matches the path `commands.sh` now writes to, so whichever layout is active correctly pre-highlights your current wallpaper on open — no ML4W required.

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
| Blank/transparent window on launch | Missing Qt5Compat GraphicalEffects module — see the per-distro install commands above. |
| Stuck on "Caching…", thumbnails never load | Confirm `cache_path` is writable and `convert` (ImageMagick) is on `PATH`: `which convert`. |
| Wallpaper picked but nothing changes | `wallpaper_tool` in `config.json` doesn't match what's actually installed/running (e.g. set to `hyprpaper` but you're running `swww`). |
| Picker doesn't highlight my actual current wallpaper | Run the `sed` fix above — it wasn't applied yet, or you're still on the ML4W-specific path. |
| Thumbnail generation freezes/slows the system on first launch | Lower `cache_batch_size` to your CPU thread count instead of `0`. |
| `.webp`/`.gif` wallpapers don't show up | The folder filter only matches `.png`/`.jpg`/`.jpeg` — see Customization below. |

---

## 🧩 Customization ideas

- Add more wallpaper formats: update the `find` filter in `cache.sh` and the `nameFilters` in whichever `shell-*.qml` you use to include `.webp`/`.gif`.
- Add a new wallpaper backend: add a `case` branch to `commands.sh`.
- Add more layouts: copy an existing `shell-*.qml`, tweak it, and add the filename as an option in `shell.qml`.
- Swap the bundled font for your own by replacing the embedded font resource.

---

## 🤝 Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). PRs for new backends, layouts, or distro packaging (AUR, Nix, COPR) are welcome.

## 📄 License

MIT — see [LICENSE](LICENSE). *(Add a LICENSE file if one isn't present yet.)*
