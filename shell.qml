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
    }

    property var    detectedBoxes: (typeof bridge !== "undefined" && bridge) ? bridge.detectedBoxes : []
    property string mode:          settings.lastMode

    readonly property var modesList: ["region", "box", "window", "screen"]
    readonly property int modeIndex: Math.max(0, modesList.indexOf(root.mode))

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

    function executeAction(action, x, y, width, height) {
        root.visible = false
        if (typeof bridge !== "undefined" && bridge) {
            bridge.saveToDisk = settings.saveToDisk
            bridge.executeAction(action, x, y, width, height)
        }
    }

    function processScreenshot(x, y, width, height) {
        root.executeAction("default", x, y, width, height)
    }

    // ── Selectors ─────────────────────────────────────────────────────────

    RegionSelector {
        visible: root.mode === "region"
        anchors.fill: parent
        dimOpacity: 0.5; borderRadius: 12.0; outlineThickness: 1.5
        onRegionSelected: (x, y, w, h) => root.processScreenshot(x, y, w, h)
        onActionRequested: (action, x, y, w, h) => root.executeAction(action, x, y, w, h)
    }

    BoxSelector {
        visible: root.mode === "box"
        anchors.fill: parent
        tempPath:     root.tempPath
        monitorScale: (typeof bridge !== "undefined" && bridge) ? bridge.monitorScale : 1.0
        boxes:        root.detectedBoxes
        dimOpacity:   0.5; borderRadius: 12.0; outlineThickness: 1.5
        onRegionSelected: (x, y, w, h) => root.processScreenshot(x, y, w, h)
        onActionRequested: (action, x, y, w, h) => root.executeAction(action, x, y, w, h)
    }

    WindowSelector {
        visible: root.mode === "window"
        anchors.fill: parent
        dimOpacity: 0.5; borderRadius: 12.0; outlineThickness: 1.5
        onRegionSelected: (x, y, w, h) => root.processScreenshot(x, y, w, h)
    }

    // ── Apple-Style Bottom Floating Toolbar ───────────────────────────────
    Rectangle {
        id: toolbar
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 44
        width: toolbarRow.implicitWidth + 32
        height: 64
        radius: 32

        // Apple frosted dark glass appearance
        color: Qt.rgba(0.11, 0.12, 0.15, 0.90)
        border {
            color: Qt.rgba(1.0, 1.0, 1.0, 0.18)
            width: 1
        }

        Row {
            id: toolbarRow
            anchors.centerIn: parent
            spacing: 20

            // Apple Segmented Mode Switcher
            Rectangle {
                id: segmentedContainer
                width: segmentedRow.implicitWidth + 8
                height: 50
                radius: 25
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.rgba(0.0, 0.0, 0.0, 0.35)
                border {
                    color: Qt.rgba(1.0, 1.0, 1.0, 0.10)
                    width: 1
                }

                // Smooth Sliding Active Pill Indicator (Apple Blue)
                Rectangle {
                    id: slidingIndicator
                    width: 58
                    height: 42
                    radius: 21
                    y: 4
                    x: 4 + root.modeIndex * (58 + 6)
                    color: "#0a84ff"
                    border {
                        color: Qt.rgba(0.45, 0.78, 1.0, 0.75)
                        width: 1
                    }

                    Behavior on x {
                        NumberAnimation {
                            duration: 240
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                Row {
                    id: segmentedRow
                    anchors.centerIn: parent
                    spacing: 6

                    Repeater {
                        model: [
                            { mode: "region", icon: "region", key: "1", title: "Area" },
                            { mode: "box",    icon: "box",    key: "2", title: "Smart Box" },
                            { mode: "window", icon: "window", key: "3", title: "Window" },
                            { mode: "screen", icon: "screen", key: "4", title: "Full Screen" }
                        ]

                        Item {
                            id: segBtn
                            width: 58
                            height: 42

                            readonly property bool isSelected: root.mode === modelData.mode

                            ToolTip.visible: segMouseArea.containsMouse
                            ToolTip.text: modelData.title + " [" + modelData.key + "]"
                            ToolTip.delay: 200

                            Image {
                                id: segIcon
                                anchors.centerIn: parent
                                width: 24; height: 24
                                source: Qt.resolvedUrl(`icons/${modelData.icon}.svg`)
                                fillMode: Image.PreserveAspectFit
                                opacity: segBtn.isSelected ? 1.0 : (segMouseArea.containsMouse ? 0.88 : 0.55)
                                scale: segBtn.isSelected ? 1.06 : (segMouseArea.pressed ? 0.94 : (segMouseArea.containsMouse ? 1.03 : 0.96))

                                Behavior on opacity { NumberAnimation { duration: 140 } }
                                Behavior on scale { NumberAnimation { duration: 140 } }
                            }

                            MouseArea {
                                id: segMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.mode = modelData.mode
                                    settings.lastMode = modelData.mode
                                    if (modelData.mode === "screen")
                                        root.processScreenshot(0, 0, root.width, root.height)
                                }
                            }
                        }
                    }
                }
            }

            // Elegant Divider
            Rectangle {
                width: 1.5
                height: 30
                radius: 0.75
                color: Qt.rgba(1.0, 1.0, 1.0, 0.15)
                anchors.verticalCenter: parent.verticalCenter
            }

            // Apple-Style "Save to disk" Toggle
            Item {
                id: saveToggleContainer
                implicitWidth: saveRow.implicitWidth
                implicitHeight: 36
                anchors.verticalCenter: parent.verticalCenter

                Row {
                    id: saveRow
                    spacing: 11
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        text: "Save to disk"
                        color: settings.saveToDisk ? "#ffffff" : "#c4c8d4"
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        verticalAlignment: Text.AlignVCenter
                        anchors.verticalCenter: parent.verticalCenter

                        Behavior on color { ColorAnimation { duration: 180 } }
                    }

                    // Custom Apple iOS/macOS Pill Switch
                    Rectangle {
                        id: switchTrack
                        width: 48
                        height: 28
                        radius: 14
                        anchors.verticalCenter: parent.verticalCenter
                        color: settings.saveToDisk ? "#34c759" : Qt.rgba(1.0, 1.0, 1.0, 0.16)
                        border {
                            color: settings.saveToDisk ? Qt.rgba(0.2, 0.85, 0.35, 0.6) : Qt.rgba(1.0, 1.0, 1.0, 0.12)
                            width: 1
                        }

                        Behavior on color { ColorAnimation { duration: 200 } }

                        Rectangle {
                            id: switchThumb
                            width: 24
                            height: 24
                            radius: 12
                            y: 2
                            x: settings.saveToDisk ? parent.width - width - 2 : 2
                            color: "#ffffff"

                            Behavior on x {
                                NumberAnimation {
                                    duration: 200
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: settings.saveToDisk = !settings.saveToDisk
                }
            }

            // Elegant Divider
            Rectangle {
                width: 1.5
                height: 30
                radius: 0.75
                color: Qt.rgba(1.0, 1.0, 1.0, 0.15)
                anchors.verticalCenter: parent.verticalCenter
            }

            // Apple Close / Cancel Capsule Button
            Rectangle {
                width: 32
                height: 32
                radius: 16
                anchors.verticalCenter: parent.verticalCenter
                color: escMouseArea.pressed
                       ? Qt.rgba(1.0, 1.0, 1.0, 0.25)
                       : (escMouseArea.containsMouse ? Qt.rgba(1.0, 1.0, 1.0, 0.16) : Qt.rgba(1.0, 1.0, 1.0, 0.08))
                border {
                    color: Qt.rgba(1.0, 1.0, 1.0, 0.15)
                    width: 1
                }

                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    color: escMouseArea.containsMouse ? "#ffffff" : "#b0b5c4"
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }

                ToolTip.visible: escMouseArea.containsMouse
                ToolTip.text: "Cancel [Esc]"
                ToolTip.delay: 200

                MouseArea {
                    id: escMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (typeof bridge !== "undefined" && bridge) {
                            bridge.cancel()
                        } else {
                            Qt.quit()
                        }
                    }
                }
            }
        }
    }
}
