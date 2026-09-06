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
install_pkg "jq" "jq"
# ImageMagick: package name differs across distros
if command -v pacman &>/dev/null; then
    install_pkg "convert" "imagemagick"          # Arch
elif command -v dnf &>/dev/null; then
    install_pkg "convert" "ImageMagick"          # Fedora
elif command -v apt &>/dev/null; then
    install_pkg "convert" "imagemagick"          # Debian/Ubuntu
else
    install_pkg "convert" "ImageMagick"          # fallback guess
fi

# --- Qt5Compat.GraphicalEffects (required by shell-*.qml for rounded card masks) ---
echo "==> Checking Qt5Compat GraphicalEffects module..."
if command -v pacman &>/dev/null; then
    sudo pacman -S --needed --noconfirm qt6-5compat
elif command -v dnf &>/dev/null; then
    sudo dnf install -y qt6-qt5compat
elif command -v apt &>/dev/null; then
    sudo apt update && sudo apt install -y qml6-module-qt5compat-graphicaleffects
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
        sudo dnf copr enable -y errornointernet/quickshell
        sudo dnf install -y quickshell
    elif command -v apt &>/dev/null; then
        echo "Quickshell has no official Debian/Ubuntu package yet. Two working options:"
        echo "  1) Install Nix, then: nix profile install nixpkgs#quickshell"
        echo "  2) Build from source: https://git.outfoxxed.me/quickshell/quickshell (see BUILD.md)"
    else
        echo "Could not detect package manager. See https://quickshell.org/docs/guide/install-setup"
    fi
fi

# --- Default wallpaper backend (matches config.json default) ---
echo "==> Checking awww (default wallpaper backend)..."
if ! command -v awww &>/dev/null; then
    echo "--> awww not found, installing..."
    if command -v pacman &>/dev/null; then
        # awww (formerly swww) is AUR-only on Arch, not in the official repos.
        if command -v yay &>/dev/null; then
            yay -S --needed awww
        elif command -v paru &>/dev/null; then
            paru -S --needed awww
        else
            echo "awww is only on the AUR for Arch — install an AUR helper first, then run:"
            echo "    yay -S awww      (or: paru -S awww)"
        fi
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
# This was for hyprpaper when it was default 
# echo "==> Checking hyprpaper (default wallpaper backend)..."
# if ! command -v hyprpaper &>/dev/null; then
#     echo "--> hyprpaper not found, installing..."
#     if command -v pacman &>/dev/null; then
#         sudo pacman -S --needed --noconfirm hyprpaper
#     elif command -v dnf &>/dev/null; then
#         sudo dnf install -y hyprpaper
#     elif command -v apt &>/dev/null; then
#         echo "Note: hyprpaper is usually not packaged for Debian/Ubuntu."
#         echo "You can keep the default or later change wallpaper_tool in config.json."
#     else
#         echo "Please install hyprpaper manually (or change wallpaper_tool in config.json)."
#     fi
# else
#     echo "--> hyprpaper already present."
# fi

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
echo "  - wallpaper_tool -> awww | hyprpaper | waypaper | swaybg | feh | ml4w"
echo " If you are using default awww"
echo " Make sure awww-daemon is started by Hyprland (add to hyprland.conf):"
echo "       exec-once = awww-daemon"
echo " (ML4W users: this instead goes in ~/.config/hypr/conf/autostart.lua as hl.exec_cmd(\"awww-daemon\"))"
echo ""
echo "Then launch with:"
echo "  qs -p ~/.config/hyprquickpaper"
