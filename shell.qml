import QtQuick 
import QtQuick.Controls 
import Quickshell 
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Io
import QtCore

import "src"

FreezeScreen {
    id: root
    visible: false

    property var activeScreen: null

    Settings {
        id: settings
        category: "Hyprquickshot"
        property bool saveToDisk: true 
        property string lastMode: "region"
        property bool ocrMode: false
    }

    function initCapture() {
        if (activeScreen !== null) return
        const monitor = Hyprland.focusedMonitor
        if (!monitor) return

        for (const screen of Quickshell.screens) {
            if (screen.name === monitor.name) {
                activeScreen = screen
                const timestamp = Date.now()
                const path = Quickshell.cachePath(`screenshot-${timestamp}.png`)
                tempPath = path
                grimProcess.command = ["grim", "-g",
                    `${screen.x},${screen.y} ${screen.width}x${screen.height}`, path]
                grimProcess.running = true
                break
            }
        }
    }

    Component.onCompleted: initCapture()

    Connections {
        target: Hyprland
        enabled: activeScreen === null
        function onFocusedMonitorChanged() { initCapture() }
    }

    targetScreen: activeScreen

    property var    hyprlandMonitor: Hyprland.focusedMonitor
    property var    detectedBoxes:   []   // populated by detectProcess after grim exits
    property string mode:            settings.lastMode

    // ── Keyboard Shortcuts ────────────────────────────────────────────────
    Shortcut {
        sequence: "Escape"
        onActivated: {
            Quickshell.execDetached(["rm", "-f", root.tempPath])
            Qt.quit()
        }
    }
    Shortcut { sequence: "1"; onActivated: { root.mode = "region"; settings.lastMode = "region" } }
    Shortcut { sequence: "2"; onActivated: { root.mode = "box";    settings.lastMode = "box" } }
    Shortcut { sequence: "3"; onActivated: { root.mode = "window"; settings.lastMode = "window" } }
    Shortcut { sequence: "4"; onActivated: { root.processScreenshot(0, 0, root.targetScreen.width, root.targetScreen.height) } }
    Shortcut { sequence: "s"; onActivated: { settings.saveToDisk = !settings.saveToDisk } }
    Shortcut { sequence: "o"; onActivated: { settings.ocrMode = !settings.ocrMode } }

    // ── grim: take the frozen screenshot ─────────────────────────────────
    Process {
        id: grimProcess
        running: false
        onExited: {
            root.visible = true
            // Start background element detection immediately
            if (root.tempPath) {
                detectProcess.command = [
                    "python3",
                    Quickshell.shellPath("src/detect_boxes.py"),
                    root.tempPath,
                    String(root.hyprlandMonitor ? root.hyprlandMonitor.scale : 1.0)
                ]
                detectProcess.running = true
            }
        }
    }

    // ── detect_boxes: one-shot background element scan ────────────────────
    Process {
        id: detectProcess
        running: false

        stdout: StdioCollector { id: detectOut }

        onExited: {
            try {
                const parsed = JSON.parse(detectOut.text)
                if (Array.isArray(parsed)) {
                    root.detectedBoxes = parsed
                }
            } catch(e) {
                console.warn("BoxSelector: failed to parse detect_boxes output:", e)
            }
        }
    }

    // ── screenshotProcess: crop frozen region + OCR/copy/save ───────────────
    Process {
        id: screenshotProcess
        running: false
        onExited: (code) => {
            if (code !== 0)
                console.warn("screenshotProcess exited with code:", code)
            Qt.quit()
        }
        stdout: StdioCollector { onStreamFinished: { if (this.text) console.log("stdout:", this.text) } }
        stderr: StdioCollector { onStreamFinished: { if (this.text) console.warn("stderr:", this.text) } }
    }

    function executeAction(action, x, y, width, height) {
        const lx = Math.round(x)
        const ly = Math.round(y)
        const lw = Math.max(1, Math.round(width))
        const lh = Math.max(1, Math.round(height))
        const scale = root.hyprlandMonitor ? root.hyprlandMonitor.scale : 1
        const px = Math.round(lx * scale)
        const py = Math.round(ly * scale)
        const pw = Math.max(1, Math.round(lw * scale))
        const ph = Math.max(1, Math.round(lh * scale))
        const crop = `${pw}x${ph}+${px}+${py}`

        const picsDir = Quickshell.env("HQS_DIR")
                     || Quickshell.env("XDG_SCREENSHOTS_DIR")
                     || Quickshell.env("XDG_PICTURES_DIR")
                     || (Quickshell.env("HOME") + "/Pictures")

        const ts     = Qt.formatDateTime(new Date(), "yyyy-MM-dd_hh-mm-ss")
        const out    = `${picsDir}/screenshot-${ts}.png`

        if (action === "ocr") {
            // Enhanced OCR Pipeline: crop -> 300% upscale + grayscale + white border -> tesseract LSTM
            screenshotProcess.command = [
                "sh", "-c",
                `tmp=$(mktemp --suffix=.png)
                 pre=$(mktemp --suffix=.png)
                 magick "${root.tempPath}" -crop "${crop}" +repage "$tmp" || exit 1
                 magick "$tmp" -resize 300% -colorspace Gray -sharpen 0x1 -bordercolor white -border 10x10 "$pre"
                 text=$(tesseract "$pre" stdout -l eng --psm 6 --oem 1 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                 rm -f "$pre"
                 if [ -n "$text" ]; then
                   printf '%s' "$text" | wl-copy
                   notify-send -a "HyprQuickFrame" "OCR Text Copied" "$text"
                 else
                   notify-send -a "HyprQuickFrame" "OCR Text" "No text recognized in selection" -u low
                 fi
                 ${settings.saveToDisk ? `cp "$tmp" "${out}"` : ""}
                 rm -f "$tmp" "${root.tempPath}"`
            ]
        } else if (action === "translate") {
            // Google Lens search / translation: OCR text -> open in Google Search
            screenshotProcess.command = [
                "sh", "-c",
                `tmp=$(mktemp --suffix=.png)
                 pre=$(mktemp --suffix=.png)
                 magick "${root.tempPath}" -crop "${crop}" +repage "$tmp" || exit 1
                 magick "$tmp" -resize 300% -colorspace Gray -sharpen 0x1 -bordercolor white -border 10x10 "$pre"
                 text=$(tesseract "$pre" stdout -l eng --psm 6 --oem 1 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                 rm -f "$pre"
                 if [ -n "$text" ]; then
                   printf '%s' "$text" | wl-copy
                   notify-send -a "HyprQuickFrame" "Google Lens" "Opening search for: $text"
                   python3 -c "import urllib.parse, webbrowser, sys; webbrowser.open('https://www.google.com/search?q=' + urllib.parse.quote(sys.argv[1]))" "$text"
                 else
                   notify-send -a "HyprQuickFrame" "Google Lens" "No text recognized to translate" -u low
                 fi
                 rm -f "$tmp" "${root.tempPath}"`
            ]
        } else if (action === "save" || (action === "default" && settings.saveToDisk)) {
            // Save to disk + clipboard with explicit image/png MIME
            screenshotProcess.command = [
                "sh", "-c",
                `magick "${root.tempPath}" -crop "${crop}" +repage "${out}" && wl-copy -t image/png < "${out}" && notify-send -a "HyprQuickFrame" "Screenshot Saved" "${out}" -i "${out}" && rm -f "${root.tempPath}"`
            ]
        } else {
            // Direct pipe to wl-copy (zero extra disk writes)
            screenshotProcess.command = [
                "sh", "-c",
                `magick "${root.tempPath}" -crop "${crop}" +repage png:- | wl-copy -t image/png && notify-send -a "HyprQuickFrame" "Screenshot Copied" "Copied to clipboard" && rm -f "${root.tempPath}"`
            ]
        }

        // Hide overlay and execute action
        root.visible = false
        screenshotProcess.running = true
    }

    function processScreenshot(x, y, width, height) {
        root.executeAction(settings.ocrMode ? "ocr" : "default", x, y, width, height)
    }

    // ── Selectors ─────────────────────────────────────────────────────────

    RegionSelector {
        visible: root.mode === "region"
        anchors.fill: parent
        dimOpacity: 0.5; borderRadius: 16.0; outlineThickness: 2.0
        onRegionSelected: (x, y, w, h) => root.processScreenshot(x, y, w, h)
        onActionRequested: (action, x, y, w, h) => root.executeAction(action, x, y, w, h)
    }

    BoxSelector {
        visible: root.mode === "box"
        anchors.fill: parent
        tempPath:    root.tempPath
        monitorScale: root.hyprlandMonitor ? root.hyprlandMonitor.scale : 1.0
        boxes:       root.detectedBoxes
        dimOpacity:  0.5; borderRadius: 16.0; outlineThickness: 2.0
        onRegionSelected: (x, y, w, h) => root.processScreenshot(x, y, w, h)
        onActionRequested: (action, x, y, w, h) => root.executeAction(action, x, y, w, h)
    }

    WindowSelector {
        visible: root.mode === "window"
        anchors.fill: parent
        monitor: root.hyprlandMonitor
        dimOpacity: 0.5; borderRadius: 16.0; outlineThickness: 2.0
        onRegionSelected: (x, y, w, h) => root.processScreenshot(x, y, w, h)
    }

    // ── Bottom toolbar ────────────────────────────────────────────────────
    WrapperRectangle {
        id: toolbar
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 40
        color: Qt.rgba(0.08, 0.1, 0.14, 0.88)
        border { color: Qt.rgba(0.4, 0.5, 0.7, 0.35); width: 1 }
        radius: 14
        margin: 8

        Row {
            spacing: 20

            // Mode buttons
            Row {
                id: buttonRow
                spacing: 8

                Repeater {
                    model: [
                        { mode: "region", icon: "region", key: "1" },
                        { mode: "box",    icon: "box",    key: "2" },
                        { mode: "window", icon: "window", key: "3" },
                        { mode: "screen", icon: "screen", key: "4" }
                    ]

                    Button {
                        id: modeBtn
                        implicitWidth: 48; implicitHeight: 48

                        ToolTip.visible: modeBtn.hovered
                        ToolTip.text: modelData.mode.toUpperCase() + " [" + modelData.key + "]"
                        ToolTip.delay: 250

                        background: Rectangle {
                            radius: 8
                            color: mode === modelData.mode
                                   ? Qt.rgba(0.3, 0.45, 0.8, 0.6)
                                   : modeBtn.hovered
                                     ? Qt.rgba(0.35, 0.4, 0.5, 0.5)
                                     : Qt.rgba(0.2, 0.22, 0.28, 0.5)
                            border {
                                color: mode === modelData.mode
                                       ? Qt.rgba(0.5, 0.7, 1.0, 0.7)
                                       : "transparent"
                                width: 1
                            }
                            Behavior on color { ColorAnimation { duration: 100 } }
                        }

                        contentItem: Image {
                            anchors.centerIn: parent
                            width: 24; height: 24
                            source: Quickshell.shellPath(`icons/${modelData.icon}.svg`)
                            fillMode: Image.PreserveAspectFit
                        }

                        onClicked: {
                            root.mode = modelData.mode
                            settings.lastMode = modelData.mode
                            if (modelData.mode === "screen")
                                processScreenshot(0, 0, root.targetScreen.width, root.targetScreen.height)
                        }
                    }
                }
            }

            // Toggles
            Row {
                spacing: 16
                anchors.verticalCenter: buttonRow.verticalCenter

                Row {
                    spacing: 8; anchors.verticalCenter: parent.verticalCenter
                    Text { text: "Save to disk"; color: "#fff"; font.pixelSize: 14
                           verticalAlignment: Text.AlignVCenter; anchors.verticalCenter: parent.verticalCenter }
                    Switch { checked: settings.saveToDisk; onCheckedChanged: settings.saveToDisk = checked }
                }
            }
        }
    }
}
