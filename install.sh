#!/usr/bin/env bash
set -e

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
        # Quickshell is AUR-only on Arch, not in the official repos.
        if command -v yay &>/dev/null; then
            yay -S --needed quickshell-git
        elif command -v paru &>/dev/null; then
            paru -S --needed quickshell-git
        else
            echo "Quickshell is only on the AUR for Arch — install an AUR helper first, then run:"
            echo "    yay -S quickshell-git      (or: paru -S quickshell-git)"
        fi
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

# --- Default wallpaper backend ---
echo "==> Checking awww (default wallpaper backend)..."
if ! command -v awww &>/dev/null; then
    echo "--> awww not found, installing..."
    if command -v pacman &>/dev/null; then
        sudo pacman -S --needed awww
    elif command -v dnf &>/dev/null; then
        echo "Note: awww has no official Fedora package yet."
        echo "  'cargo install awww' only installs the client, not awww-daemon —"
        echo "  you'll need to build both from source, or pick a different"
        echo "  wallpaper_tool (hyprpaper/swaybg) in config.json instead."
    elif command -v apt &>/dev/null; then
        echo "Note: awww is usually not packaged for Debian/Ubuntu."
        echo "  Build from source, or change wallpaper_tool in config.json to"
        echo "  hyprpaper/swaybg instead."
    else
        echo "Please install awww manually (or change wallpaper_tool in config.json)."
    fi
else
    echo "--> awww already present."
fi

# --- Initialize Cache Directories & Placeholder Files ---
echo "==> Initializing local cache directories..."
mkdir -p ~/.cache/hyprquickpaper
mkdir -p ~/.cache/quickshell/thumbs
touch ~/.cache/hyprquickpaper/current_wallpaper

echo "==> Setting script execution permissions..."
chmod +x cache.sh commands.sh install.sh

echo "==> Setup complete!"
echo ""
echo "Before running, make sure you've edited config.json:"
echo "  - wallpaper_path -> your real wallpaper folder"
echo "  - wallpaper_tool -> awww | hyprpaper | waypaper | swaybg | feh | ml4w | mpvpaper"
echo "  - video_extensions -> list of video extensions to support"
echo ""
echo "If you are using default awww:"
echo "  Make sure awww-daemon is started by Hyprland (add to hyprland.conf):"
echo "       exec-once = awww-daemon"
echo "  (ML4W users: this instead goes in ~/.config/hypr/conf/autostart.lua as hl.exec_cmd(\"awww-daemon\"))"
echo ""
echo "For video support, make sure mpvpaper is installed:"
echo "  - Arch: yay -S mpvpaper (AUR)"
echo "  - Other distros: build from https://github.com/GhostNaN/mpvpaper"
echo ""
echo "Then launch with:"
echo "  qs -p ~/.config/hyprquickpaper"
