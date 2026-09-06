#!/usr/bin/env bash
set -e

echo "==> Checking and installing dependencies..."

install_pkg() {
    local pkg=$1
    if ! command -v "$pkg" &>/dev/null; then
        echo "--> Installing missing dependency: $pkg"
        if command -v pacman &>/dev/null; then
            sudo pacman -S --needed --noconfirm "$pkg"
        elif command -v dnf &>/dev/null; then
            sudo dnf install -y "$pkg"
        elif command -v apt &>/dev/null; then
            sudo apt update && sudo apt install -y "$pkg"
        else
            echo "Could not detect package manager. Please install $pkg manually."
        fi
    fi
}

# --- Core CLI tools ---
install_pkg "jq"
install_pkg "imagemagick"

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

echo "==> Setting script execution permissions..."
chmod +x cache.sh commands.sh install.sh

echo "==> Setup complete!"
echo ""
echo "Before running, make sure you've edited config.json:"
echo "  - wallpaper_path -> your real wallpaper folder"
echo "  - wallpaper_tool -> swww | hyprpaper | waypaper | swaybg | feh | ml4w"
echo ""
echo "Then launch with:"
echo "  qs -p ~/.config/hyprquickpaper"
