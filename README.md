# HyprQuickFrame

An intelligent, lightning-fast, and beautiful screenshot tool for Hyprland / Wayland with smart element detection, circle-to-select snapping, enhanced OCR, and buttery-smooth animations built with native **Qt6 & Wayland Layer Shell** (no Quickshell dependency required).

---

## ✨ Features

- **🎯 Circle-to-Select & Smart Element Snapping:**
  - Draw a quick circle or lasso around any button, card, or text block to automatically snap to its exact bounding box.
  - One-click capture on detected UI elements.
  - Theme-adaptive auto-Canny detection running seamlessly in the background across dark, OLED, and light desktop themes.
- **📝 High-Accuracy OCR Pipeline:**
  - One-click / one-key toggle to extract text directly from selected regions.
  - Built-in preprocessing pipeline (300% upscale, grayscale conversion, and border padding) boosting character recognition by up to 40% on standard 96 DPI displays.
- **🪟 Intelligent Window & Region Capture:**
  - Hover-snap directly to any active Hyprland window.
  - Drag-to-select regions with live floating dimension pills (`W × H`).
  - Fullscreen instant capture.
- **⚡ Zero-Jank Performance:**
  - Native C++ executable with zero runtime shell daemons.
  - Asynchronous background texture loading prevents UI thread freezes on 4K and multi-monitor setups.
  - Hardware-accelerated GPU drawing via Qt FramebufferObject and branchless anti-aliased shaders.
  - Direct piping to `wl-copy` with explicit `image/png` MIME headers (no redundant disk writes when copying).
- **⌨️ Keyboard & Mouse Micro-Controls:**
  - Mode switching shortcuts: `1` (Region), `2` (Box/Circle), `3` (Window), `4` (Screen).
  - Quick toggles: `S` (Save to Disk), `O` (OCR Mode).
  - Fine-tuning: Mouse wheel over a selection box smoothly expands or contracts its boundaries.
  - Easy cancel: `Esc` or Right-Click anywhere instantly dismisses or clears the selection.

---

## 📦 Dependencies

Ensure these standard packages are installed on your system:

| Package | Purpose | Standard Package Name |
| :--- | :--- | :--- |
| **qt6-declarative** | Qt6 Quick / QML runtime | `qt6-declarative` / `qt6-qtdeclarative-devel` |
| **layer-shell-qt** | Wayland Layer Shell support | `layer-shell-qt` / `layer-shell-qt-devel` |
| **grim** | Screen capture | `grim` |
| **imagemagick** | Image cropping & OCR preprocessing | `imagemagick` / `ImageMagick` |
| **wl-clipboard** | Wayland clipboard integration | `wl-clipboard` |
| **tesseract** *(Optional)* | OCR text extraction | `tesseract` + `tesseract-data-eng` |
| **python-opencv** *(Optional)*| Element & paragraph detection | `python-opencv` (`python3-opencv`) |
| **python-numpy** *(Optional)* | Element detection math | `python-numpy` (`python3-numpy`) |

---

## 🚀 Quick Install

### One-Command Setup:
```bash
git clone https://github.com/MUHSIN-M-P/HyprQuickFrame.git
cd HyprQuickFrame
./install.sh
```

### Manual / Distribution Setup

#### Arch Linux
1. Install dependencies:
   ```bash
   sudo pacman -S cmake qt6-declarative layer-shell-qt grim imagemagick wl-clipboard tesseract tesseract-data-eng python-opencv python-numpy
   ```
2. Clone and build:
   ```bash
   git clone https://github.com/MUHSIN-M-P/HyprQuickFrame.git
   cd HyprQuickFrame
   cmake -B build -DCMAKE_BUILD_TYPE=Release
   cmake --build build
   sudo cmake --install build
   ```

#### Fedora
```bash
sudo dnf install cmake qt6-qtdeclarative-devel layer-shell-qt-devel grim ImageMagick wl-clipboard tesseract tesseract-langpack-eng python3-opencv python3-numpy
git clone https://github.com/MUHSIN-M-P/HyprQuickFrame.git
cd HyprQuickFrame
./install.sh
```

#### Nix / NixOS
Add HyprQuickFrame to your flake inputs:
```nix
{
  inputs = {
    hyprquickframe = {
      url = "github:MUHSIN-M-P/HyprQuickFrame";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
```
Or run directly:
```bash
nix run github:MUHSIN-M-P/HyprQuickFrame
```

---

## ⚙️ Hyprland Configuration

Add these keybindings to your `~/.config/hypr/hyprland.conf`:

```ini
# Launch HyprQuickFrame on Print Screen
bind = , Print, exec, hyprquickframe

# Quick region screenshot
bind = $mainMod, Print, exec, hyprquickframe

# Meta + Shift + S (macOS / Windows style shortcut)
bind = $mainMod SHIFT, S, exec, hyprquickframe
```

---

## ⌨️ Controls & Shortcuts

| Key / Action | Description |
| :--- | :--- |
| **1** | Switch to **Region** mode |
| **2** | Switch to **Box / Circle-to-Select** mode |
| **3** | Switch to **Window** mode |
| **4** | Capture **Full Screen** immediately |
| **S** | Toggle **Save to Disk** on/off |
| **O** | Toggle **OCR Mode** on/off |
| **Mouse Wheel** | Fine-tune / resize the snapped bounding box |
| **Enter** / **Space** / **Left Click** | Confirm and copy/save current selection |
| **Right Click** | Clear current selection (or exit if empty) |
| **Escape** | Cancel and close overlay |

---

## 📂 Configuration & Output Directories

HyprQuickFrame saves screenshots to the first existing directory found in this order:
1. `$HQS_DIR` (Custom override environment variable)
2. `$XDG_SCREENSHOTS_DIR`
3. `$XDG_PICTURES_DIR`
4. `$HOME/Pictures`

---

## 📄 License

Licensed under the MIT License.
* **Original Work:** [HyprQuickshot](https://github.com/JamDon2/hyprquickshot) © 2025 JamDon2.
* **Enhanced and Modified by Myself**.
