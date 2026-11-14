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
    property bool isZooming: false

    signal rectChangeRequested(real newX, real newY, real newWidth, real newHeight)
    signal actionTriggered(string action, real x, real y, real width, real height)
    signal dismissed()

    visible: active && selectionWidth > 0 && selectionHeight > 0
    z: 10
    anchors.fill: parent

    // ── Hit-testing geometry ───────────────────────────────────────────────
    readonly property real _grab: 16        // corner grab radius
    readonly property real _edgeGrab: 9     // edge grab thickness
    readonly property real _minSize: 24

    // ── Drag state in screen coordinates ──────────────────────────────────
    property string _zone: ""
    property real _pressX: 0
    property real _pressY: 0
    property real _origX: 0
    property real _origY: 0
    property real _origW: 0
    property real _origH: 0
    property bool _dragged: false
    property bool ctrlHeld: false

    Timer {
        id: zoomTimer
        interval: 140
        onTriggered: root.isZooming = false
    }

    // Returns "topLeft", "top", "topRight", "right", "bottomRight",
    // "bottom", "bottomLeft", "left", "move" or "" for no hit.
    function _zoneAt(px, py) {
        if (root.selectionWidth <= 0 || root.selectionHeight <= 0) return ""

        const x1 = root.selectionX
        const y1 = root.selectionY
        const x2 = x1 + root.selectionWidth
        const y2 = y1 + root.selectionHeight
        const g  = root._grab

        // Fast reject: outside the frame's grab margin
        if (px < x1 - g || px > x2 + g || py < y1 - g || py > y2 + g) return ""

        const nearL = px <= x1 + g
        const nearR = px >= x2 - g
        const nearT = py <= y1 + g
        const nearB = py >= y2 - g

        // Corners first so they always win over the edge strips
        if (nearT && nearL) return "topLeft"
        if (nearT && nearR) return "topRight"
        if (nearB && nearL) return "bottomLeft"
        if (nearB && nearR) return "bottomRight"

        if (py <= y1 + root._edgeGrab) return "top"
        if (py >= y2 - root._edgeGrab) return "bottom"
        if (px <= x1 + root._edgeGrab) return "left"
        if (px >= x2 - root._edgeGrab) return "right"

        // Interior — drag to reposition the selection
        if (px >= x1 && px <= x2 && py >= y1 && py <= y2) return "move"
        return ""
    }

    function _cursorFor(zone, ctrlHeld) {
        switch (zone) {
        case "topLeft":
        case "bottomRight":  return Qt.SizeFDiagCursor
        case "topRight":
        case "bottomLeft":   return Qt.SizeBDiagCursor
        case "top":
        case "bottom":       return Qt.SizeVerCursor
        case "left":
        case "right":        return Qt.SizeHorCursor
        case "move":         return ctrlHeld ? Qt.SizeAllCursor : Qt.CrossCursor
        default:             return Qt.CrossCursor
        }
    }

    function _applyDrag(dx, dy) {
        const minS   = root._minSize
        const right  = root._origX + root._origW
        const bottom = root._origY + root._origH

        let nx = root._origX
        let ny = root._origY
        let nw = root._origW
        let nh = root._origH
        const z = root._zone

        switch (z) {
        case "move":
            nx = Math.max(0, Math.min(root.screenWidth  - nw, root._origX + dx))
            ny = Math.max(0, Math.min(root.screenHeight - nh, root._origY + dy))
            break
        case "left":
        case "topLeft":
        case "bottomLeft":
            nx = Math.max(0, Math.min(right - minS, root._origX + dx))
            nw = right - nx
            break
        case "right":
        case "topRight":
        case "bottomRight":
            nw = Math.max(minS, Math.min(root.screenWidth - root._origX, root._origW + dx))
            break
        }

        switch (z) {
        case "top":
        case "topLeft":
        case "topRight":
            ny = Math.max(0, Math.min(bottom - minS, root._origY + dy))
            nh = bottom - ny
            break
        case "bottom":
        case "bottomLeft":
        case "bottomRight":
            nh = Math.max(minS, Math.min(root.screenHeight - root._origY, root._origH + dy))
            break
        }

        root.rectChangeRequested(nx, ny, nw, nh)
    }

    // ── Static full-screen interaction layer ──────────────────────────────
    // Keeping this layer fixed in screen space is what makes resizing stable:
    // the old per-handle MouseAreas moved together with the box, which made
    // coordinate mapping drift and broke several corners/edges.
    MouseArea {
        id: interactionArea
        anchors.fill: parent
        z: 0
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton

        cursorShape: {
            const zone = root._zoneAt(mouseX, mouseY)
            // While actively moving, use a grabbing hand so the user sees it's a move.
            if (root._zone === "move" && root.isResizing) return Qt.ClosedHandCursor
            return root._cursorFor(zone, root.ctrlHeld)
        }

        onPressed: (mouse) => {
            root.ctrlHeld = (mouse.modifiers & Qt.ControlModifier) !== 0
            const z = root._zoneAt(mouse.x, mouse.y)
            if (z === "") {
                // Let the selector underneath start a fresh gesture
                mouse.accepted = false
                return
            }
            if (z === "move" && !root.ctrlHeld) {
                // Dragging inside a selection without Ctrl must not move the box:
                // pass the event through so a draw/redraw gesture underneath works.
                mouse.accepted = false
                return
            }
            root._zone    = z
            root._pressX  = mouse.x
            root._pressY  = mouse.y
            root._origX   = root.selectionX
            root._origY   = root.selectionY
            root._origW   = root.selectionWidth
            root._origH   = root.selectionHeight
            root._dragged = false
            root.isResizing = true
            mouse.accepted = true
        }

        onPositionChanged: (mouse) => {
            root.ctrlHeld = (mouse.modifiers & Qt.ControlModifier) !== 0
            if (root._zone === "" || !(mouse.buttons & Qt.LeftButton)) return

            const dx = mouse.x - root._pressX
            const dy = mouse.y - root._pressY
            if (Math.abs(dx) > 2 || Math.abs(dy) > 2) root._dragged = true

            root._applyDrag(dx, dy)
        }

        onReleased: (mouse) => {
            if (mouse.button !== Qt.LeftButton) return
            const z = root._zone
            const wasDragged = root._dragged

            root._zone = ""
            root._dragged = false
            root.isResizing = false
            root.ctrlHeld = false

            // A plain click inside the selection confirms it (same as before).
            if (z === "move" && !wasDragged) {
                root.actionTriggered("default",
                    Math.round(root.selectionX), Math.round(root.selectionY),
                    Math.round(root.selectionWidth), Math.round(root.selectionHeight))
            }
        }

        onCanceled: {
            root._zone = ""
            root._dragged = false
            root.isResizing = false
            root.ctrlHeld = false
        }

        // Wheel = proportional resize around the selection centre
        onWheel: (wheel) => {
            const step = wheel.angleDelta.y > 0 ? 1.04 : 0.96
            const oldW = root.selectionWidth
            const oldH = root.selectionHeight
            if (oldW <= 0 || oldH <= 0) { wheel.accepted = false; return }

            const newW = Math.max(root._minSize, Math.min(root.screenWidth,  oldW * step))
            const newH = Math.max(root._minSize, Math.min(root.screenHeight, oldH * step))
            const nx = Math.max(0, Math.min(root.screenWidth  - newW, root.selectionX - (newW - oldW) * 0.5))
            const ny = Math.max(0, Math.min(root.screenHeight - newH, root.selectionY - (newH - oldH) * 0.5))

            root.isZooming = true
            zoomTimer.restart()
            root.rectChangeRequested(nx, ny, newW, newH)
            wheel.accepted = true
        }
    }

    // ── 4 Outer Curved Corner Brackets (visual only) ──────────────────────
    Item {
        id: boxFrame
        x: root.selectionX
        y: root.selectionY
        width: root.selectionWidth
        height: root.selectionHeight

        Image {
            x: -4; y: -4; width: 32; height: 32
            source: Qt.resolvedUrl("../icons/lens_corner.svg")
            rotation: 0
        }

        Image {
            x: parent.width - 28; y: -4; width: 32; height: 32
            source: Qt.resolvedUrl("../icons/lens_corner.svg")
            rotation: 90
        }

        Image {
            x: parent.width - 28; y: parent.height - 28; width: 32; height: 32
            source: Qt.resolvedUrl("../icons/lens_corner.svg")
            rotation: 180
        }

        Image {
            x: -4; y: parent.height - 28; width: 32; height: 32
            source: Qt.resolvedUrl("../icons/lens_corner.svg")
            rotation: 270
        }

        // ── 4 Edge Drag Grips (visual only) ───────────────────────────────
        Rectangle {
            x: (parent.width - 28) / 2; y: -2
            width: 28; height: 4; radius: 2
            color: "#ffffff"
            border { color: Qt.rgba(0, 0, 0, 0.35); width: 0.5 }
        }

        Rectangle {
            x: (parent.width - 28) / 2; y: parent.height - 2
            width: 28; height: 4; radius: 2
            color: "#ffffff"
            border { color: Qt.rgba(0, 0, 0, 0.35); width: 0.5 }
        }

        Rectangle {
            x: -2; y: (parent.height - 28) / 2
            width: 4; height: 28; radius: 2
            color: "#ffffff"
            border { color: Qt.rgba(0, 0, 0, 0.35); width: 0.5 }
        }

        Rectangle {
            x: parent.width - 2; y: (parent.height - 28) / 2
            width: 4; height: 28; radius: 2
            color: "#ffffff"
            border { color: Qt.rgba(0, 0, 0, 0.35); width: 0.5 }
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
