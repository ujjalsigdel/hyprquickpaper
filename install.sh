#!/usr/bin/env bash

set -e

echo "==> Checking and installing dependencies..."

# Package installer helper
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
            echo "⚠️ Could not detect package manager. Please install $pkg manually."
        fi
    fi
}

# Install required CLI tools
install_pkg "jq"
install_pkg "imagemagick"

# Install Quickshell if missing
if ! command -v quickshell &>/dev/null && ! command -v qs &>/dev/null; then
    echo "--> Quickshell not detected. Attempting installation..."
    if command -v pacman &>/dev/null; then
        sudo pacman -S --needed --noconfirm quickshell || echo "⚠️ If quickshell is not in official repos, install quickshell-git via AUR."
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y quickshell
    elif command -v apt &>/dev/null; then
        sudo apt install -y quickshell
    fi
fi

echo "==> Setting script execution permissions..."
chmod +x cache.sh commands.sh install.sh

echo "==> Setup complete!"
echo "==> Run: quickshell -p ~/.config/hyprquickpaper"
