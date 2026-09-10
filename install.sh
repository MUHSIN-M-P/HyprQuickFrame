#!/usr/bin/env bash
set -e

TARGET_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/HyprQuickFrame"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Installing HyprQuickFrame ==="
echo "Target directory: $TARGET_DIR"

if [ "$SCRIPT_DIR" != "$TARGET_DIR" ]; then
    mkdir -p "$TARGET_DIR"
    cp -r "$SCRIPT_DIR"/* "$TARGET_DIR/"
    echo "Files copied successfully."
else
    echo "Already in target directory."
fi

echo ""
echo "Checking required dependencies:"
MISSING=0
for cmd in quickshell grim magick wl-copy; do
    if command -v "$cmd" >/dev/null 2>&1; then
        printf "  \033[32m✓\033[0m %s\n" "$cmd"
    else
        printf "  \033[31m✗\033[0m %s (Required)\n" "$cmd"
        MISSING=1
    fi
done

echo ""
echo "Checking optional dependencies (for Smart Detection & OCR):"
for cmd in tesseract python3; do
    if command -v "$cmd" >/dev/null 2>&1; then
        printf "  \033[32m✓\033[0m %s\n" "$cmd"
    else
        printf "  \033[33m-\033[0m %s (Optional)\n" "$cmd"
    fi
done

if command -v python3 >/dev/null 2>&1; then
    python3 -c "import cv2, numpy" >/dev/null 2>&1 && \
        printf "  \033[32m✓\033[0m python-opencv & python-numpy\n" || \
        printf "  \033[33m-\033[0m python-opencv / python-numpy (Optional for paragraph detection)\n"
fi

echo ""
if [ "$MISSING" -eq 1 ]; then
    echo "Please install missing required dependencies using your package manager."
    echo "Arch: sudo pacman -S grim imagemagick wl-clipboard && yay -S quickshell"
fi

echo ""
echo "=== Setup Complete! ==="
echo "Add this keybinding to your ~/.config/hypr/hyprland.conf:"
echo "  bind = , Print, exec, quickshell -c HyprQuickFrame -n"
echo ""
echo "To test run right now:"
echo "  quickshell -c HyprQuickFrame -n"
