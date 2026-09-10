import QtQuick  
  
Item {  
    id: root  
      
    signal regionSelected(real x, real y, real width, real height)  
    signal actionRequested(string action, real x, real y, real width, real height)

    // Shader customization properties  
    property real dimOpacity: 0.6  
    property real borderRadius: 16.0  
    property real outlineThickness: 2.0  
    property url fragmentShader: Qt.resolvedUrl("../shaders/dimming.frag.qsb")  
      
    property point startPos  
    property real selectionX: 0  
    property real selectionY: 0  
    property real selectionWidth: 0  
    property real selectionHeight: 0  
    property bool hasSelection: false
      
    property real targetX: 0  
    property real targetY: 0  
    property real targetWidth: 0  
    property real targetHeight: 0  

    property bool _isResizing: selectionOverlay.isResizing
      
    Behavior on selectionX { enabled: !root._isResizing; SpringAnimation { spring: 4; damping: 0.4 } }  
    Behavior on selectionY { enabled: !root._isResizing; SpringAnimation { spring: 4; damping: 0.4 } }  
    Behavior on selectionHeight { enabled: !root._isResizing; SpringAnimation { spring: 4; damping: 0.4 } }  
    Behavior on selectionWidth { enabled: !root._isResizing; SpringAnimation { spring: 4; damping: 0.4 } }  
      
    // Shader overlay  
    ShaderEffect {  
        anchors.fill: parent  
        z: 0  
          
        property vector4d selectionRect: root.hasSelection
            ? Qt.vector4d(root.selectionX, root.selectionY, root.selectionWidth, root.selectionHeight)
            : Qt.vector4d(root.targetX, root.targetY, root.targetWidth, root.targetHeight)
        property real dimOpacity: root.dimOpacity  
        property vector2d screenSize: Qt.vector2d(root.width, root.height)  
        property real borderRadius: root.borderRadius  
        property real outlineThickness: root.outlineThickness  
          
        fragmentShader: root.fragmentShader  
    }  

    // ── Google Lens Selection Overlay & Action Menu Card ──────────────────
    SelectionOverlay {
        id: selectionOverlay
        active: root.hasSelection && !mouseArea.pressed
        selectionX: root.selectionX
        selectionY: root.selectionY
        selectionWidth: root.selectionWidth
        selectionHeight: root.selectionHeight
        screenWidth: root.width
        screenHeight: root.height

        onRectChangeRequested: (nx, ny, nw, nh) => {
            root.selectionX = nx
            root.selectionY = ny
            root.selectionWidth = nw
            root.selectionHeight = nh
        }

        onActionTriggered: (action, x, y, w, h) => {
            root.actionRequested(action, x, y, w, h)
        }
        onDismissed: {
            root.hasSelection = false
            root.targetWidth = 0
            root.targetHeight = 0
            root.selectionWidth = 0
            root.selectionHeight = 0
        }
    }
      
    // ── Live Drag Dimension Badge ─────────────────────────────────────────
    Rectangle {
        id: dimLabel
        z: 5
        visible: mouseArea.pressed && root.targetWidth > 10 && root.targetHeight > 10
        x: Math.max(8, Math.min(root.width - width - 8, mouseArea.mouseX + 16))
        y: Math.max(8, Math.min(root.height - height - 8, mouseArea.mouseY + 16))
        width: dimText.contentWidth + 16
        height: 24
        radius: 6
        color: Qt.rgba(0.08, 0.1, 0.16, 0.92)
        border { color: Qt.rgba(0.4, 0.65, 1.0, 0.6); width: 1 }

        Text {
            id: dimText
            anchors.centerIn: parent
            text: Math.round(root.targetWidth) + " × " + Math.round(root.targetHeight)
            color: "#dde8ff"
            font.pixelSize: 11
            font.bold: true
        }
    }

    // ── Confirm Shortcuts ─────────────────────────────────────────────────
    function _confirm() {
        if (!root.hasSelection || root.selectionWidth <= 0 || root.selectionHeight <= 0) return
        root.actionRequested(
            "default",
            Math.round(root.selectionX), Math.round(root.selectionY),
            Math.round(root.selectionWidth), Math.round(root.selectionHeight))
    }
    Shortcut { sequence: "Return"; enabled: root.hasSelection; onActivated: root._confirm() }
    Shortcut { sequence: "Space";  enabled: root.hasSelection; onActivated: root._confirm() }

    MouseArea {  
        id: mouseArea  
        anchors.fill: parent  
        z: 3  
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: root.hasSelection ? Qt.PointingHandCursor : Qt.CrossCursor
          
        Timer {  
            id: updateTimer  
            interval: 16  
            repeat: true  
            running: mouseArea.pressed  
            onTriggered: {  
                root.selectionX = root.targetX  
                root.selectionY = root.targetY  
                root.selectionWidth = root.targetWidth  
                root.selectionHeight = root.targetHeight  
            }  
        }  
          
        onPressed: (mouse) => {  
            if (mouse.button === Qt.RightButton) {
                root.hasSelection = false
                root.targetWidth = 0
                root.targetHeight = 0
                root.selectionWidth = 0
                root.selectionHeight = 0
                return
            }
            // If clicking outside existing selection, start fresh drag
            root.hasSelection = false
            root.startPos = Qt.point(mouse.x, mouse.y)  
            root.targetX = mouse.x  
            root.targetY = mouse.y  
            root.targetWidth = 0  
            root.targetHeight = 0  
        }  
          
        onPositionChanged: (mouse) => {  
            if (pressed && (mouse.buttons & Qt.LeftButton)) {  
                const x = Math.min(root.startPos.x, mouse.x)  
                const y = Math.min(root.startPos.y, mouse.y)  
                const width = Math.abs(mouse.x - root.startPos.x)  
                const height = Math.abs(mouse.y - root.startPos.y)  
                  
                root.targetX = x  
                root.targetY = y  
                root.targetWidth = width  
                root.targetHeight = height  
            }  
        }  
          
        onReleased: (mouse) => {  
            if (mouse.button !== Qt.LeftButton) return
            if (root.targetWidth >= 12 && root.targetHeight >= 12) {
                root.selectionX = root.targetX
                root.selectionY = root.targetY
                root.selectionWidth = root.targetWidth
                root.selectionHeight = root.targetHeight
                root.hasSelection = true
            }
        }  
    }  
}
