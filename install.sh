#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${HOME}/.local/bin"

echo "=== Building & Installing HyprQuickFrame ==="

# Check build dependencies
MISSING=0
for cmd in cmake grim magick wl-copy; do
    if command -v "$cmd" >/dev/null 2>&1; then
        printf "  \033[32m✓\033[0m %s\n" "$cmd"
    else
        printf "  \033[31m✗\033[0m %s (Required)\n" "$cmd"
        MISSING=1
    fi
done

if [ "$MISSING" -eq 1 ]; then
    echo "Please install missing required dependencies using your package manager."
    echo "Arch:   sudo pacman -S cmake qt6-declarative layer-shell-qt grim imagemagick wl-clipboard"
    echo "Fedora: sudo dnf install cmake qt6-qtdeclarative-devel layer-shell-qt-devel grim ImageMagick wl-clipboard"
    exit 1
fi

echo ""
echo "Compiling native hyprquickframe binary..."
cmake -B "${SCRIPT_DIR}/build" -DCMAKE_BUILD_TYPE=Release "${SCRIPT_DIR}"
cmake --build "${SCRIPT_DIR}/build" -j"$(nproc)"

mkdir -p "$BIN_DIR"
cp "${SCRIPT_DIR}/build/hyprquickframe" "${BIN_DIR}/hyprquickframe"
chmod +x "${BIN_DIR}/hyprquickframe"

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
echo "=== Setup Complete! ==="
echo "Binary installed to: ${BIN_DIR}/hyprquickframe"
echo "Add this keybinding to your ~/.config/hypr/hyprland.conf:"
echo "  bind = , Print, exec, hyprquickframe"
echo ""
echo "To test run right now:"
echo "  hyprquickframe"
