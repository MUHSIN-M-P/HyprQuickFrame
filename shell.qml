import QtQuick 
import QtQuick.Controls 
import QtCore

import "src"

FreezeScreen {
    id: root
    visible: true

    tempPath: (typeof bridge !== "undefined" && bridge) ? bridge.tempPath : ""

    Settings {
        id: settings
        category: "Hyprquickshot"
        property bool saveToDisk: true 
        property string lastMode: "region"
        property bool ocrMode: false
    }

    property var    detectedBoxes: (typeof bridge !== "undefined" && bridge) ? bridge.detectedBoxes : []
    property string mode:          settings.lastMode

    // ── Keyboard Shortcuts ────────────────────────────────────────────────
    Shortcut {
        sequence: "Escape"
        onActivated: {
            if (typeof bridge !== "undefined" && bridge) {
                bridge.cancel()
            } else {
                Qt.quit()
            }
        }
    }
    Shortcut { sequence: "1"; onActivated: { root.mode = "region"; settings.lastMode = "region" } }
    Shortcut { sequence: "2"; onActivated: { root.mode = "box";    settings.lastMode = "box" } }
    Shortcut { sequence: "3"; onActivated: { root.mode = "window"; settings.lastMode = "window" } }
    Shortcut { sequence: "4"; onActivated: { root.processScreenshot(0, 0, root.width, root.height) } }
    Shortcut { sequence: "s"; onActivated: { settings.saveToDisk = !settings.saveToDisk } }
    Shortcut { sequence: "o"; onActivated: { settings.ocrMode = !settings.ocrMode } }

    function executeAction(action, x, y, width, height) {
        root.visible = false
        if (typeof bridge !== "undefined" && bridge) {
            bridge.saveToDisk = settings.saveToDisk
            bridge.executeAction(action, x, y, width, height)
        }
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
        tempPath:     root.tempPath
        monitorScale: (typeof bridge !== "undefined" && bridge) ? bridge.monitorScale : 1.0
        boxes:        root.detectedBoxes
        dimOpacity:   0.5; borderRadius: 16.0; outlineThickness: 2.0
        onRegionSelected: (x, y, w, h) => root.processScreenshot(x, y, w, h)
        onActionRequested: (action, x, y, w, h) => root.executeAction(action, x, y, w, h)
    }

    WindowSelector {
        visible: root.mode === "window"
        anchors.fill: parent
        dimOpacity: 0.5; borderRadius: 16.0; outlineThickness: 2.0
        onRegionSelected: (x, y, w, h) => root.processScreenshot(x, y, w, h)
    }

    // ── Bottom toolbar ────────────────────────────────────────────────────
    Rectangle {
        id: toolbar
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 40
        width: toolbarRow.width + 24
        height: toolbarRow.height + 16
        color: Qt.rgba(0.08, 0.1, 0.14, 0.88)
        border { color: Qt.rgba(0.4, 0.5, 0.7, 0.35); width: 1 }
        radius: 14

        Row {
            id: toolbarRow
            anchors.centerIn: parent
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
                            source: Qt.resolvedUrl(`icons/${modelData.icon}.svg`)
                            fillMode: Image.PreserveAspectFit
                        }

                        onClicked: {
                            root.mode = modelData.mode
                            settings.lastMode = modelData.mode
                            if (modelData.mode === "screen")
                                root.processScreenshot(0, 0, root.width, root.height)
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

                Row {
                    spacing: 8; anchors.verticalCenter: parent.verticalCenter
                    Text { text: "OCR Mode"; color: "#fff"; font.pixelSize: 14
                           verticalAlignment: Text.AlignVCenter; anchors.verticalCenter: parent.verticalCenter }
                    Switch { checked: settings.ocrMode; onCheckedChanged: settings.ocrMode = checked }
                }
            }
        }
    }
}
