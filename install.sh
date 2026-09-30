#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CANONICAL_DIR="$HOME/.config/quickshell/hyprquickpaper"

echo "==> Checking and installing dependencies..."

install_pkg() {
    local cmd=$1
    local pkg=$2

    if ! command -v "$cmd" &>/dev/null; then
        echo "--> Installing missing dependency: $pkg"

        if command -v pacman &>/dev/null; then
            sudo pacman -S --needed --noconfirm "$pkg"

        elif command -v dnf &>/dev/null; then
            sudo dnf install -y "$pkg"

        elif command -v apt &>/dev/null; then
            sudo apt update && sudo apt install -y "$pkg"

        else
            echo "Could not detect package manager."
            echo "Please install $pkg manually."
            return 1
        fi
    fi
}

# --- Core CLI tools ---
install_pkg "jq" "jq" || true
# ImageMagick: package name differs across distros
if command -v pacman &>/dev/null; then
    install_pkg "convert" "imagemagick" || true          # Arch
elif command -v dnf &>/dev/null; then
    install_pkg "convert" "ImageMagick" || true          # Fedora
elif command -v apt &>/dev/null; then
    install_pkg "convert" "imagemagick" || true          # Debian/Ubuntu
else
    install_pkg "convert" "ImageMagick" || true          # fallback guess
fi

# --- Video support ---
echo "==> Checking video dependencies..."
install_pkg "ffmpeg" "ffmpeg" || true

# mpvpaper is NOT in official repos on most distros
echo "==> Checking mpvpaper (video wallpaper support)..."
if ! command -v mpvpaper &>/dev/null; then
    echo "--> mpvpaper not found."

    if command -v pacman &>/dev/null; then
        # Arch: mpvpaper is in the AUR
        if command -v yay &>/dev/null; then
            yay -S --needed mpvpaper
        elif command -v paru &>/dev/null; then
            paru -S --needed mpvpaper
        else
            echo "mpvpaper is on the AUR for Arch — install an AUR helper first, then run:"
            echo "    yay -S mpvpaper      (or: paru -S mpvpaper)"
            echo ""
            echo "Or install from source: https://github.com/GhostNaN/mpvpaper"
        fi
    elif command -v dnf &>/dev/null; then
        echo "mpvpaper is not packaged for Fedora. Install from source:"
        echo "    git clone https://github.com/GhostNaN/mpvpaper.git"
        echo "    cd mpvpaper"
        echo "    make"
        echo "    sudo make install"
        echo ""
        echo "Or try: sudo dnf install mpvpaper  # if available in copr"
    elif command -v apt &>/dev/null; then
        echo "mpvpaper is not packaged for Debian/Ubuntu. Install from source:"
        echo "    sudo apt install build-essential git libmpv-dev libwayland-dev"
        echo "    git clone https://github.com/GhostNaN/mpvpaper.git"
        echo "    cd mpvpaper"
        echo "    make"
        echo "    sudo make install"
    else
        echo "Please install mpvpaper manually:"
        echo "    https://github.com/GhostNaN/mpvpaper"
    fi
else
    echo "--> mpvpaper already present."
fi

# --- Qt5Compat.GraphicalEffects ---
echo "==> Checking Qt5Compat GraphicalEffects module..."
if command -v pacman &>/dev/null; then
    sudo pacman -S --needed --noconfirm qt6-5compat || echo "Warning: could not install qt6-5compat automatically."
elif command -v dnf &>/dev/null; then
    sudo dnf install -y qt6-qt5compat || echo "Warning: could not install qt6-qt5compat automatically."
elif command -v apt &>/dev/null; then
    sudo apt update && sudo apt install -y qml6-module-qt5compat-graphicaleffects || echo "Warning: could not install qml6-module-qt5compat-graphicaleffects automatically."
else
    echo "Could not detect package manager."
    echo "Install the 'Qt5Compat GraphicalEffects' QML module manually — without it,"
    echo "the picker will fail to render the rounded-corner cards."
fi

# --- Quickshell itself ---
echo "==> Checking Quickshell..."
if ! command -v quickshell &>/dev/null && ! command -v qs &>/dev/null; then
    echo "--> Quickshell not detected."
    if command -v pacman &>/dev/null; then
        sudo pacman -S --needed quickshell || echo "Warning: could not install quickshell automatically."
    elif command -v dnf &>/dev/null; then
        sudo dnf copr enable -y errornointernet/quickshell || echo "Warning: could not enable the quickshell copr automatically."
        sudo dnf install -y quickshell || echo "Warning: could not install quickshell automatically. See https://quickshell.org/docs/guide/install-setup"
    elif command -v apt &>/dev/null; then
        echo "Quickshell has no official Debian/Ubuntu package yet. Two working options:"
        echo "  1) Install Nix, then: nix profile install nixpkgs#quickshell"
        echo "  2) Build from source: https://git.outfoxxed.me/quickshell/quickshell (see BUILD.md)"
    else
        echo "Could not detect package manager. See https://quickshell.org/docs/guide/install-setup"
    fi
fi

# --- Wallpaper backend ---
# awww is a sensible default to install for users who don't already have a
# wallpaper daemon running. Users on a desktop shell that manages wallpapers
# itself (Noctalia, etc.) can ignore this and set 'custom_command' in
# config.json instead. Auto-detection at runtime finds whichever daemon the
# user actually has running.
echo "==> Checking awww (default wallpaper backend)..."
if ! command -v awww &>/dev/null; then
    echo "--> awww not found, installing..."
    if command -v pacman &>/dev/null; then
        sudo pacman -S --needed awww || echo "Warning: could not install awww automatically."
    elif command -v dnf &>/dev/null; then
        echo "Note: awww has no official Fedora package yet."
        echo "  'cargo install awww' only installs the client, not awww-daemon —"
        echo "  you'll need to build both from source, or use hyprpaper/swaybg"
        echo "  (set 'wallpaper_tool' in config.json, or leave it as \"auto\")."
    elif command -v apt &>/dev/null; then
        echo "Note: awww is usually not packaged for Debian/Ubuntu."
        echo "  Build from source, or use hyprpaper/swaybg instead"
        echo "  (set 'wallpaper_tool' in config.json, or leave it as \"auto\")."
    else
        echo "Please install awww manually, or use hyprpaper/swaybg."
    fi
else
    echo "--> awww already present."
fi

# --- Initialize Cache Directories & Placeholder Files ---
echo "==> Initializing local cache directories..."
mkdir -p ~/.cache/hyprquickpaper
mkdir -p ~/.cache/quickshell/thumbs
touch ~/.cache/hyprquickpaper/current_wallpaper

# --- Make scripts executable before invoking any of them ---
chmod +x cache.sh commands.sh install.sh

# --- Seed the wallpaper folder with sample images if config points nowhere useful ---
# Reads wallpaper_path from config.json, expands ~, and only copies sample
# images when the configured folder is missing or has no images. Users who
# already pointed config.json at their real wallpaper folder see nothing
# copied and no messages.
CONFIG_FILE="$SCRIPT_DIR/config.json"
if [ -f "$CONFIG_FILE" ] && command -v jq &>/dev/null; then
    WALLPAPER_PATH=$(jq -r '.wallpaper_path // ""' "$CONFIG_FILE")
    WALLPAPER_PATH="${WALLPAPER_PATH/#\~/$HOME}"

    if [ -n "$WALLPAPER_PATH" ] && ! find "$WALLPAPER_PATH" -maxdepth 1 -type f \
            \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) \
            2>/dev/null | head -n1 | grep -q .; then

        SAMPLE_SRC="$SCRIPT_DIR/assets/screenshots"
        if [ -d "$SAMPLE_SRC" ] && \
           find "$SAMPLE_SRC" -maxdepth 1 -type f \
                \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) \
                2>/dev/null | head -n1 | grep -q .; then

            mkdir -p "$WALLPAPER_PATH"
            find "$SAMPLE_SRC" -maxdepth 1 -type f \
                \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) \
                -exec cp -n {} "$WALLPAPER_PATH/" \;

            echo ""
            echo "==> Wallpaper folder: $WALLPAPER_PATH"
            echo "    No images were found there, so a few sample images from"
            echo "    assets/screenshots/ were copied in so the picker has"
            echo "    something to display on first launch."
            echo ""
            echo "    These are placeholders. To use your own wallpapers:"
            echo "      1. Delete the samples:  rm \"$WALLPAPER_PATH\"/*.jpg"
            echo "      2. Drop your real wallpapers into that folder,"
            echo "         OR change 'wallpaper_path' in config.json to point"
            echo "         at wherever your wallpapers actually live."
            echo ""
        fi
    fi
fi

# --- Pre-generate thumbnails so first launch is clean ---
echo "==> Pre-generating thumbnails (this may take a moment)..."
if [ -f "$SCRIPT_DIR/config.json" ] && [ -x "$SCRIPT_DIR/cache.sh" ]; then
    bash "$SCRIPT_DIR/cache.sh" "$SCRIPT_DIR" || \
        echo "Warning: cache.sh did not finish cleanly — thumbnails will still be generated on first picker launch."
fi

# --- Strip .git if installed to the canonical location ---
# The cloned repo's history isn't needed at runtime. If the user cloned
# somewhere else (a dev checkout), .git is left alone.
if [ -d "$SCRIPT_DIR/.git" ]; then
    if [ "$SCRIPT_DIR" = "$CANONICAL_DIR" ]; then
        echo "==> Removing .git (not needed after install)..."
        rm -rf "$SCRIPT_DIR/.git"
    else
        echo "==> Keeping .git (installed outside the default location — likely a dev checkout)."
    fi
fi

echo "==> Setup complete!"
echo ""
echo "Before running, make sure you've edited config.json:"
echo "  - wallpaper_path   -> your real wallpaper folder"
echo "  - wallpaper_tool   -> auto | awww | hyprpaper | waypaper | swaybg | feh"
echo "  - custom_command   -> (optional) for shells that manage wallpapers themselves"
echo "  - video_extensions -> list of video extensions to support"
echo ""
echo "Wallpaper daemon autostart:"
echo "  Depending on your Hyprland setup, the autostart line goes in one of:"
echo ""
echo "    Classic config:  ~/.config/hypr/hyprland.conf"
echo "        exec-once = awww-daemon"
echo ""
echo "    Lua-based configs (some dotfiles use these):"
echo "        ~/.config/hypr/conf/autostart.lua"
echo "        hl.exec_cmd(\"awww-daemon\")"
echo ""
echo "  If your desktop shell already manages wallpapers itself (Noctalia,"
echo "  end-4 dots, etc.), skip the daemon line and set 'custom_command' in"
echo "  config.json instead. See README.md for examples."
echo ""
echo "For video support, make sure mpvpaper is installed:"
echo "  - Arch: yay -S mpvpaper (AUR)"
echo "  - Other distros: build from https://github.com/GhostNaN/mpvpaper"
echo ""
echo "Then launch with:"
echo "  qs -p ~/.config/quickshell/hyprquickpaper"
