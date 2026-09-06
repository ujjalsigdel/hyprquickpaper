# 🖼️ HyprQuickPaper

A fast, themeable, keyboard-driven Wayland wallpaper picker built with **Quickshell** and **QML** for Hyprland. Inspired by [ilyamiro's dots](https://github.com/ilyamiro/nixos-configuration).

> [!IMPORTANT]
> **Out-of-the-Box Setup Notice:**  
> HyprQuickPaper is pre-configured out of the box to work seamlessly with **ML4W Dotfiles** (`ml4w-wallpaper`). If you use standard `swww`, `hyprpaper`, `feh`, or `waypaper`, you **must** edit `config.json` and `commands.sh` before running!

---

## ✨ Features

* **Multiple Layout Modes:** Switch dynamically between Bottom Dock, Coverflow, and Classic list layouts.
* **Sheared Bottom-Dock:** Parallelogram card deck featuring smooth rounded corners, uniform level height alignment, and an active selection glow effect.
* **Lossless Artwork Preview:** High-quality background rendering updating in real-time behind your selected wallpaper.
* **Embedded Custom Typography:** Built-in support for the futuristic *Anurati* stencil display font (no manual font installation required).

---

## 📸 Layout Preview

| **Bottom Dock (Default)** | **Coverflow** | **Classic List** |
| :---: | :---: | :---: |
| ![Bottom Dock](assets/screenshots/bottom-dock.jpg) | ![Coverflow](assets/screenshots/coverflow.jpg) | ![Classic List](assets/screenshots/classic.jpg) |

*(Note: Add your screenshot images under `assets/screenshots/` to display them above!)*

---

## 📋 Dependencies

Ensure you have the following installed on your system:
* **[Quickshell](https://git.outfoxxed.me/quickshell/quickshell)** (`qs` / `quickshell`)
* **`jq`** (for JSON parsing)
* **`imagemagick`** (`convert` / `magick` for thumbnail generation)
* **`bash`** & **`fontconfig`**

---

## 🚀 Installation

Clone this repository directly into your Quickshell config directory and run the setup script:

```bash
git clone [https://github.com/ujjalsigdel/hyprquickpaper.git](https://github.com/ujjalsigdel/hyprquickpaper.git) ~/.config/quickshell/hyprquickpaper
cd ~/.config/quickshell/hyprquickpaper
./install.sh
