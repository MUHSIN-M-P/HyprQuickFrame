import QtQuick

Item {
    id: root

    property real selectionX: 0
    property real selectionY: 0
    property real selectionWidth: 0
    property real selectionHeight: 0
    property bool active: false
    property real screenWidth: 1920
    property real screenHeight: 1080
    property bool isResizing: false

    signal rectChangeRequested(real newX, real newY, real newWidth, real newHeight)
    signal actionTriggered(string action, real x, real y, real width, real height)
    signal dismissed()

    visible: active && selectionWidth > 0 && selectionHeight > 0
    z: 10

    // ── Drag state in screen coordinates ──────────────────────────────────
    property real _dragStartX: 0
    property real _dragStartY: 0
    property real _origX: 0
    property real _origY: 0
    property real _origW: 0
    property real _origH: 0

    function _startDrag(screenX, screenY) {
        _dragStartX = screenX
        _dragStartY = screenY
        _origX = root.selectionX
        _origY = root.selectionY
        _origW = root.selectionWidth
        _origH = root.selectionHeight
        root.isResizing = true
    }

    function _endDrag() {
        root.isResizing = false
    }

    // ── Outer Selection Handles (aligned with box perimeter) ──
    Item {
        id: boxFrame
        x: root.selectionX
        y: root.selectionY
        width: root.selectionWidth
        height: root.selectionHeight

        // ── 4 Outer Curved Corner Brackets ────────────────────────────────
        // Top-Left Corner ⌜
        Image {
            x: -4; y: -4; width: 32; height: 32
            source: Qt.resolvedUrl("../icons/lens_corner.svg")
            rotation: 0
            MouseArea {
                anchors.fill: parent; anchors.margins: -8
                cursorShape: Qt.SizeFDiagCursor
                onPressed: (mouse) => {
                    const pt = mapToItem(root, mouse.x, mouse.y)
                    root._startDrag(pt.x, pt.y)
                }
                onReleased: root._endDrag()
                onPositionChanged: (mouse) => {
                    if (!pressed) return
                    const pt = mapToItem(root, mouse.x, mouse.y)
                    const dx = pt.x - root._dragStartX
                    const dy = pt.y - root._dragStartY
                    const right = root._origX + root._origW
                    const bottom = root._origY + root._origH
                    const newX = Math.max(0, Math.min(right - 24, root._origX + dx))
                    const newY = Math.max(0, Math.min(bottom - 24, root._origY + dy))
                    root.rectChangeRequested(newX, newY, right - newX, bottom - newY)
                }
            }
        }

        // Top-Right Corner ⌝
        Image {
            x: parent.width - 28; y: -4; width: 32; height: 32
            source: Qt.resolvedUrl("../icons/lens_corner.svg")
            rotation: 90
            MouseArea {
                anchors.fill: parent; anchors.margins: -8
                cursorShape: Qt.SizeBDiagCursor
                onPressed: (mouse) => {
                    const pt = mapToItem(root, mouse.x, mouse.y)
                    root._startDrag(pt.x, pt.y)
                }
                onReleased: root._endDrag()
                onPositionChanged: (mouse) => {
                    if (!pressed) return
                    const pt = mapToItem(root, mouse.x, mouse.y)
                    const dx = pt.x - root._dragStartX
                    const dy = pt.y - root._dragStartY
                    const bottom = root._origY + root._origH
                    const newY = Math.max(0, Math.min(bottom - 24, root._origY + dy))
                    const newW = Math.max(24, Math.min(root.screenWidth - root._origX, root._origW + dx))
                    root.rectChangeRequested(root._origX, newY, newW, bottom - newY)
                }
            }
        }

        // Bottom-Right Corner ⌟
        Image {
            x: parent.width - 28; y: parent.height - 28; width: 32; height: 32
            source: Qt.resolvedUrl("../icons/lens_corner.svg")
            rotation: 180
            MouseArea {
                anchors.fill: parent; anchors.margins: -8
                cursorShape: Qt.SizeFDiagCursor
                onPressed: (mouse) => {
                    const pt = mapToItem(root, mouse.x, mouse.y)
                    root._startDrag(pt.x, pt.y)
                }
                onReleased: root._endDrag()
                onPositionChanged: (mouse) => {
                    if (!pressed) return
                    const pt = mapToItem(root, mouse.x, mouse.y)
                    const dx = pt.x - root._dragStartX
                    const dy = pt.y - root._dragStartY
                    const newW = Math.max(24, Math.min(root.screenWidth - root._origX, root._origW + dx))
                    const newH = Math.max(24, Math.min(root.screenHeight - root._origY, root._origH + dy))
                    root.rectChangeRequested(root._origX, root._origY, newW, newH)
                }
            }
        }

        // Bottom-Left Corner ⌞
        Image {
            x: -4; y: parent.height - 28; width: 32; height: 32
            source: Qt.resolvedUrl("../icons/lens_corner.svg")
            rotation: 270
            MouseArea {
                anchors.fill: parent; anchors.margins: -8
                cursorShape: Qt.SizeBDiagCursor
                onPressed: (mouse) => {
                    const pt = mapToItem(root, mouse.x, mouse.y)
                    root._startDrag(pt.x, pt.y)
                }
                onReleased: root._endDrag()
                onPositionChanged: (mouse) => {
                    if (!pressed) return
                    const pt = mapToItem(root, mouse.x, mouse.y)
                    const dx = pt.x - root._dragStartX
                    const dy = pt.y - root._dragStartY
                    const right = root._origX + root._origW
                    const newX = Math.max(0, Math.min(right - 24, root._origX + dx))
                    const newH = Math.max(24, Math.min(root.screenHeight - root._origY, root._origH + dy))
                    root.rectChangeRequested(newX, root._origY, right - newX, newH)
                }
            }
        }

        // ── 4 Edge Drag Grips ──────────────────────────────────────────────
        // Top Edge Grip
        Rectangle {
            x: (parent.width - 28) / 2; y: -2
            width: 28; height: 4; radius: 2
            color: "#ffffff"
            border { color: Qt.rgba(0, 0, 0, 0.35); width: 0.5 }
        }
        MouseArea {
            anchors { left: parent.left; right: parent.right }
            anchors.leftMargin: 26; anchors.rightMargin: 26
            y: -10; height: 20
            cursorShape: Qt.SizeVerCursor
            onPressed: (mouse) => {
                const pt = mapToItem(root, mouse.x, mouse.y)
                root._startDrag(pt.x, pt.y)
            }
            onReleased: root._endDrag()
            onPositionChanged: (mouse) => {
                if (!pressed) return
                const pt = mapToItem(root, mouse.x, mouse.y)
                const dy = pt.y - root._dragStartY
                const bottom = root._origY + root._origH
                const newY = Math.max(0, Math.min(bottom - 24, root._origY + dy))
                root.rectChangeRequested(root._origX, newY, root._origW, bottom - newY)
            }
        }

        // Bottom Edge Grip
        Rectangle {
            x: (parent.width - 28) / 2; y: parent.height - 2
            width: 28; height: 4; radius: 2
            color: "#ffffff"
            border { color: Qt.rgba(0, 0, 0, 0.35); width: 0.5 }
        }
        MouseArea {
            anchors { left: parent.left; right: parent.right }
            anchors.leftMargin: 26; anchors.rightMargin: 26
            y: parent.height - 10; height: 20
            cursorShape: Qt.SizeVerCursor
            onPressed: (mouse) => {
                const pt = mapToItem(root, mouse.x, mouse.y)
                root._startDrag(pt.x, pt.y)
            }
            onReleased: root._endDrag()
            onPositionChanged: (mouse) => {
                if (!pressed) return
                const pt = mapToItem(root, mouse.x, mouse.y)
                const dy = pt.y - root._dragStartY
                const newH = Math.max(24, Math.min(root.screenHeight - root._origY, root._origH + dy))
                root.rectChangeRequested(root._origX, root._origY, root._origW, newH)
            }
        }

        // Left Edge Grip
        Rectangle {
            x: -2; y: (parent.height - 28) / 2
            width: 4; height: 28; radius: 2
            color: "#ffffff"
            border { color: Qt.rgba(0, 0, 0, 0.35); width: 0.5 }
        }
        MouseArea {
            anchors { top: parent.top; bottom: parent.bottom }
            anchors.topMargin: 26; anchors.bottomMargin: 26
            x: -10; width: 20
            cursorShape: Qt.SizeHorCursor
            onPressed: (mouse) => {
                const pt = mapToItem(root, mouse.x, mouse.y)
                root._startDrag(pt.x, pt.y)
            }
            onReleased: root._endDrag()
            onPositionChanged: (mouse) => {
                if (!pressed) return
                const pt = mapToItem(root, mouse.x, mouse.y)
                const dx = pt.x - root._dragStartX
                const right = root._origX + root._origW
                const newX = Math.max(0, Math.min(right - 24, root._origX + dx))
                root.rectChangeRequested(newX, root._origY, right - newX, root._origH)
            }
        }

        // Right Edge Grip
        Rectangle {
            x: parent.width - 2; y: (parent.height - 28) / 2
            width: 4; height: 28; radius: 2
            color: "#ffffff"
            border { color: Qt.rgba(0, 0, 0, 0.35); width: 0.5 }
        }
        MouseArea {
            anchors { top: parent.top; bottom: parent.bottom }
            anchors.topMargin: 26; anchors.bottomMargin: 26
            x: parent.width - 10; width: 20
            cursorShape: Qt.SizeHorCursor
            onPressed: (mouse) => {
                const pt = mapToItem(root, mouse.x, mouse.y)
                root._startDrag(pt.x, pt.y)
            }
            onReleased: root._endDrag()
            onPositionChanged: (mouse) => {
                if (!pressed) return
                const pt = mapToItem(root, mouse.x, mouse.y)
                const dx = pt.x - root._dragStartX
                const newW = Math.max(24, Math.min(root.screenWidth - root._origX, root._origW + dx))
            }
        }
    }

    // ── Google Lens Floating "Copy text" Action Pill ──────────────────────
    Rectangle {
        id: copyPill
        x: Math.max(8, Math.min(root.screenWidth - width - 8, root.selectionX))
        y: (root.selectionY + root.selectionHeight + height + 14 <= root.screenHeight)
           ? (root.selectionY + root.selectionHeight + 8)
           : Math.max(8, root.selectionY - height - 8)

        width: pillRow.implicitWidth + 28
        height: 38
        radius: 19

        // Pure Google Lens white capsule with soft ambient shadow
        color: pillArea.containsMouse ? "#f1f3f4" : "#ffffff"
        border { color: Qt.rgba(0.0, 0.0, 0.0, 0.12); width: 1 }

        Behavior on color { ColorAnimation { duration: 80 } }
        Behavior on x { NumberAnimation { duration: 60 } }
        Behavior on y { NumberAnimation { duration: 60 } }

        scale: pillArea.pressed ? 0.96 : (pillArea.containsMouse ? 1.02 : 1.0)
        Behavior on scale { NumberAnimation { duration: 80 } }

        Row {
            id: pillRow
            anchors.centerIn: parent
            spacing: 8

            Image {
                width: 17; height: 17
                anchors.verticalCenter: parent.verticalCenter
                source: Qt.resolvedUrl("../icons/copy_text.svg")
                fillMode: Image.PreserveAspectFit
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Copy text"
                color: "#1f1f1f"
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }
        }

        MouseArea {
            id: pillArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.actionTriggered("ocr", root.selectionX, root.selectionY, root.selectionWidth, root.selectionHeight)
            }
        }
    }
}
