import QtQuick
import Quickshell

Item {
    id: root

    // ── Inputs ────────────────────────────────────────────────────────────
    property string tempPath:    ""
    property real monitorScale:  1.0
    property var  boxes:         []  // pre-detected boxes from detect_boxes.py (logical coords)

    // ── Outputs ───────────────────────────────────────────────────────────
    signal regionSelected(real x, real y, real width, real height)
    signal actionRequested(string action, real x, real y, real width, real height)

    // ── Shader customization ──────────────────────────────────────────────
    property real dimOpacity:       0.5
    property real borderRadius:     16.0
    property real outlineThickness: 2.0
    property url  fragmentShader:   Qt.resolvedUrl("../shaders/dimming.frag.qsb")

    // ── Selection state ───────────────────────────────────────────────────
    property real selectionX:      0
    property real selectionY:      0
    property real selectionWidth:  0
    property real selectionHeight: 0
    property bool hasSelection:    false
    property bool _isResizing:     selectionOverlay.isResizing

    onVisibleChanged: {
        if (!visible) {
            hasSelection = false
            _isDrawing   = false
            _ptCount     = 0
            _ptBuf       = []
            drawCanvas.requestPaint()
        }
    }

    // ── Drawing / gesture state ───────────────────────────────────────────
    property var  _ptBuf:        []
    property int  _ptCount:      0
    property real _sx:           0
    property real _sy:           0
    property real _lastX:        0
    property real _lastY:        0
    property real _totalPathLen: 0
    property bool _isDrawing:    false

    property bool _isWheeling:    false
    Timer {
        id: wheelTimer
        interval: 140
        onTriggered: root._isWheeling = false
    }

    // Smooth animated selection box (disabled during handle resize or mouse wheel for 1:1 precision)
    Behavior on selectionX      { enabled: !root._isResizing && !root._isWheeling; SpringAnimation { spring: 4; damping: 0.4 } }
    Behavior on selectionY      { enabled: !root._isResizing && !root._isWheeling; SpringAnimation { spring: 4; damping: 0.4 } }
    Behavior on selectionWidth  { enabled: !root._isResizing && !root._isWheeling; SpringAnimation { spring: 4; damping: 0.4 } }
    Behavior on selectionHeight { enabled: !root._isResizing && !root._isWheeling; SpringAnimation { spring: 4; damping: 0.4 } }

    // ── Dimming shader — dims whole screen, punches hole when selection exists ──
    ShaderEffect {
        anchors.fill: parent
        z: 0
        property vector4d selectionRect: root.hasSelection
            ? Qt.vector4d(root.selectionX, root.selectionY, root.selectionWidth, root.selectionHeight)
            : Qt.vector4d(0, 0, 0, 0)
        property real dimOpacity:       root.dimOpacity
        property vector2d screenSize:   Qt.vector2d(root.width, root.height)
        property real borderRadius:     root.borderRadius
        property real outlineThickness: root.outlineThickness
        fragmentShader: root.fragmentShader
    }

    // ── Google Lens Selection Overlay & Action Menu Card ──────────────────
    SelectionOverlay {
        id: selectionOverlay
        active: root.hasSelection && !root._isDrawing
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
        }
    }

    // ── "Ready" indicator shown while boxes are still loading ─────────────
    Rectangle {
        id: loadingBadge
        z: 5
        visible: root.boxes.length === 0
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 60
        width: loadText.contentWidth + 24; height: 26; radius: 13
        color: Qt.rgba(0.1, 0.12, 0.2, 0.85)
        border { color: Qt.rgba(0.6, 0.6, 0.7, 0.4); width: 1 }
        Text {
            id: loadText
            anchors.centerIn: parent
            text: "Detecting elements…"
            color: "#c0c8e0"; font.pixelSize: 12
        }
    }

    // ── Live Drawing Indicator Badge ─────────────────────────────────────
    Rectangle {
        id: drawDimLabel
        z: 5
        visible: root._isDrawing && root._ptBuf.length >= 4
        x: Math.max(8, Math.min(root.width - width - 8, root._lastX + 16))
        y: Math.max(8, Math.min(root.height - height - 8, root._lastY + 16))
        width: drawDimText.contentWidth + 18
        height: 24
        radius: 6
        color: Qt.rgba(0.08, 0.1, 0.16, 0.92)
        border { color: Qt.rgba(0.4, 0.65, 1.0, 0.6); width: 1 }

        Text {
            id: drawDimText
            anchors.centerIn: parent
            text: "Circling element…"
            color: "#dde8ff"
            font.pixelSize: 11
            font.bold: true
        }
    }

    // ── Circle / lasso stroke canvas ─────────────────────────────────────
    Canvas {
        id: drawCanvas
        anchors.fill: parent
        z: 2
        renderTarget: Canvas.FramebufferObject
        renderStrategy: Canvas.Cooperative
        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            const buf = root._ptBuf
            const n   = Math.floor(buf.length / 2)
            if (n < 2) return
            ctx.lineWidth   = 3
            ctx.strokeStyle = Qt.rgba(0.4, 0.65, 1.0, 0.90)
            ctx.fillStyle   = Qt.rgba(0.4, 0.65, 1.0, 0.12)
            ctx.lineCap     = "round"
            ctx.lineJoin    = "round"
            ctx.beginPath()
            ctx.moveTo(buf[0], buf[1])
            for (let i = 2; i < buf.length; i += 2)
                ctx.lineTo(buf[i], buf[i + 1])
            ctx.stroke()
            if (n > 6) { ctx.closePath(); ctx.fill() }
        }
    }

    // ── Confirm capture ───────────────────────────────────────────────────
    function _confirm() {
        if (!root.hasSelection || root.selectionWidth <= 0 || root.selectionHeight <= 0) return
        root.actionRequested(
            "default",
            Math.round(root.selectionX), Math.round(root.selectionY),
            Math.round(root.selectionWidth), Math.round(root.selectionHeight))
    }
    Shortcut { sequence: "Return"; enabled: root.hasSelection; onActivated: root._confirm() }
    Shortcut { sequence: "Space";  enabled: root.hasSelection; onActivated: root._confirm() }

    // ── Point-in-polygon ray-casting test ────────────────────────────────
    function _pointInPolygon(px, py, pts) {
        let inside = false
        const n = pts.length
        for (let i = 0, j = n - 2; i < n; j = i, i += 2) {
            const xi = pts[i],     yi = pts[i + 1]
            const xj = pts[j],     yj = pts[j + 1]
            const intersect = ((yi > py) !== (yj > py))
                && (px < (xj - xi) * (py - yi) / (yj - yi + 0.0000001) + xi)
            if (intersect) inside = !inside
        }
        return inside
    }

    // ── Smart Multi-Element & Enclosure Selection ────────────────────────
    function _resolveSelection(pts, circleMinX, circleMinY, circleMaxX, circleMaxY) {
        if (!root.boxes || root.boxes.length === 0) return null

        const cW = circleMaxX - circleMinX
        const cH = circleMaxY - circleMinY
        const cArea = cW * cH
        if (cArea <= 0) return null

        const hasPoly = pts && pts.length >= 8

        // 1. Evaluate candidate boxes
        let qualifying = []
        let bestSingle = null
        let bestSingleScore = -1.0

        for (let i = 0; i < root.boxes.length; i++) {
            const b  = root.boxes[i]
            const bx = b.x, by = b.y, bw = b.width, bh = b.height

            // Fast bounding-box rejection
            const ix1 = Math.max(bx, circleMinX)
            const iy1 = Math.max(by, circleMinY)
            const ix2 = Math.min(bx + bw, circleMaxX)
            const iy2 = Math.min(by + bh, circleMaxY)
            if (ix2 <= ix1 || iy2 <= iy1) continue

            const interArea = (ix2 - ix1) * (iy2 - iy1)
            const bArea     = bw * bh
            const boxCov    = interArea / bArea      // how much of the box is inside circle AABB
            const circleCov = interArea / cArea      // how much of circle is filled by box
            const iou       = interArea / (cArea + bArea - interArea)

            // Point-in-polygon check
            let polyInsideCount = 0
            if (hasPoly) {
                const cx = bx + bw * 0.5
                const cy = by + bh * 0.5
                if (_pointInPolygon(cx, cy, pts)) polyInsideCount += 2
                if (_pointInPolygon(bx, by, pts)) polyInsideCount++
                if (_pointInPolygon(bx + bw, by, pts)) polyInsideCount++
                if (_pointInPolygon(bx, by + bh, pts)) polyInsideCount++
                if (_pointInPolygon(bx + bw, by + bh, pts)) polyInsideCount++
            }

            const score = iou * 0.55 + circleCov * 0.25 + boxCov * 0.2
            if (score > bestSingleScore) {
                bestSingleScore = score
                bestSingle = b
            }

            // Qualifying check for multi-element grouping:
            // Exclude accidental edge grazes (boxCov >= 0.35, or center inside + boxCov >= 0.20)
            const isCenterInPoly = hasPoly && polyInsideCount >= 2
            const isSubstantiallyCovered = boxCov >= 0.35 || (isCenterInPoly && boxCov >= 0.20)

            if (isSubstantiallyCovered && bArea <= cArea * 2.2 && interArea >= 150) {
                qualifying.push({
                    box: b,
                    coverage: boxCov,
                    area: bArea,
                    score: score,
                    polyScore: polyInsideCount
                })
            }
        }

        // 2. Multi-card / multi-element union check
        if (qualifying.length >= 2) {
            // Sort by area descending (outer containers before child elements)
            qualifying.sort((a, b) => b.area - a.area)

            // Filter out child boxes whose parent container is already qualifying
            let topLevel = []
            for (let i = 0; i < qualifying.length; i++) {
                const q = qualifying[i].box
                let isChild = false
                for (let j = 0; j < topLevel.length; j++) {
                    const parent = topLevel[j].box
                    if (q.x >= parent.x - 4 && q.y >= parent.y - 4
                        && q.x + q.width <= parent.x + parent.width + 4
                        && q.y + q.height <= parent.y + parent.height + 4) {
                        isChild = true
                        break
                    }
                }
                if (!isChild) {
                    topLevel.push(qualifying[i])
                }
            }

            // If we have 2 or more disjoint top-level elements (e.g. 2 cards)
            if (topLevel.length >= 2) {
                let ux1 = Infinity, uy1 = Infinity, ux2 = -Infinity, uy2 = -Infinity
                for (let i = 0; i < topLevel.length; i++) {
                    const b = topLevel[i].box
                    if (b.x < ux1) ux1 = b.x
                    if (b.y < uy1) uy1 = b.y
                    if (b.x + b.width > ux2) ux2 = b.x + b.width
                    if (b.y + b.height > uy2) uy2 = b.y + b.height
                }
                const uW = ux2 - ux1
                const uH = uy2 - uy1
                const uArea = uW * uH
                if (uW > 0 && uH > 0 && uArea <= cArea * 3.0) {
                    return { x: ux1, y: uy1, width: uW, height: uH }
                }
            } else if (topLevel.length === 1) {
                return topLevel[0].box
            }
        }

        // 3. Single dominant box fallback (snaps directly to the circled paragraph or element)
        if (bestSingle && bestSingleScore >= 0.08) {
            return bestSingle
        }

        return null
    }

    // ── Single click on an element without drawing ───────────────────────
    function _selectBoxAt(px, py) {
        if (!root.boxes || root.boxes.length === 0) return
        let best = null
        let minArea = Infinity
        for (let i = 0; i < root.boxes.length; i++) {
            const b = root.boxes[i]
            if (px >= b.x && px <= b.x + b.width && py >= b.y && py <= b.y + b.height) {
                const area = b.width * b.height
                if (area < minArea && b.width >= 16 && b.height >= 16) {
                    minArea = area
                    best = b
                }
            }
        }
        if (best) {
            root.selectionX      = best.x
            root.selectionY      = best.y
            root.selectionWidth  = best.width
            root.selectionHeight = best.height
            root.hasSelection    = true
        }
    }

    // ── Mouse interaction ─────────────────────────────────────────────────
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        z: 3
        hoverEnabled: false
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: root.hasSelection ? Qt.PointingHandCursor : Qt.CrossCursor

        onWheel: (wheel) => {
            if (!root.hasSelection || root.selectionWidth <= 0 || root.selectionHeight <= 0) return
            root._isWheeling = true
            wheelTimer.restart()
            const factor = wheel.angleDelta.y > 0 ? 1.04 : 0.96
            const oldW = root.selectionWidth
            const oldH = root.selectionHeight
            const newW = Math.max(16, Math.min(root.width, oldW * factor))
            const newH = Math.max(10, Math.min(root.height, oldH * factor))
            root.selectionX = Math.max(0, root.selectionX - (newW - oldW) * 0.5)
            root.selectionY = Math.max(0, root.selectionY - (newH - oldH) * 0.5)
            root.selectionWidth = newW
            root.selectionHeight = newH
        }

        onPressed: (mouse) => {
            // Right-click: clear selection or cancel
            if (mouse.button === Qt.RightButton) {
                if (root.hasSelection) {
                    root.hasSelection = false
                    root._isDrawing   = false
                    root._ptCount     = 0
                    root._ptBuf       = []
                    drawCanvas.requestPaint()
                } else {
                    Quickshell.execDetached(["rm", "-f", root.tempPath])
                    Qt.quit()
                }
                return
            }

            if (mouse.button !== Qt.LeftButton) return

            root._sx           = mouse.x
            root._sy           = mouse.y
            root._lastX        = mouse.x
            root._lastY        = mouse.y
            root._totalPathLen = 0
            root._isDrawing    = false
            root._ptCount      = 1
            root._ptBuf        = [mouse.x, mouse.y]
        }

        onPositionChanged: (mouse) => {
            if (!(mouse.buttons & Qt.LeftButton)) return

            const ddx = mouse.x - root._lastX
            const ddy = mouse.y - root._lastY
            root._totalPathLen += Math.sqrt(ddx*ddx + ddy*ddy)
            root._lastX = mouse.x
            root._lastY = mouse.y

            // Start drawing gesture once cursor moves past click threshold (> 10px total path)
            if (!root._isDrawing && root._totalPathLen > 10) {
                root._isDrawing = true
                // Clear old selection so user sees fresh drawing gesture immediately
                root.hasSelection = false
            }

            if (!root._isDrawing) return

            root._ptBuf.push(mouse.x, mouse.y)
            root._ptCount++
            drawCanvas.requestPaint()
        }

        onReleased: (mouse) => {
            if (mouse.button !== Qt.LeftButton) return

            // ── Single click (no drag gesture) ───────────────────────────
            if (!root._isDrawing) {
                root._ptCount = 0
                root._ptBuf   = []
                drawCanvas.requestPaint()

                if (root.hasSelection) {
                    // ONE CLICK ANYWHERE CAPTURES CURRENT DETECTED BOX!
                    root._confirm()
                } else {
                    // Click on element to select it directly
                    root._selectBoxAt(mouse.x, mouse.y)
                }
                return
            }

            // ── Circle gesture completed ─────────────────────────────────
            root._isDrawing = false
            const buf = root._ptBuf
            root._ptCount = 0
            root._ptBuf   = []
            drawCanvas.requestPaint()

            if (buf.length < 4) return

            let minX = buf[0], minY = buf[1]
            let maxX = buf[0], maxY = buf[1]
            for (let i = 2; i < buf.length; i += 2) {
                const px = buf[i]
                const py = buf[i+1]
                if (px < minX) minX = px
                if (py < minY) minY = py
                if (px > maxX) maxX = px
                if (py > maxY) maxY = py
            }

            const best = root._resolveSelection(buf, minX, minY, maxX, maxY)
            if (best) {
                root.selectionX      = best.x
                root.selectionY      = best.y
                root.selectionWidth  = best.width
                root.selectionHeight = best.height
                root.hasSelection    = true
            } else {
                // Fallback to bounding box of drawn gesture if at least 12x12
                const w = maxX - minX
                const h = maxY - minY
                if (w >= 12 && h >= 12) {
                    root.selectionX      = minX
                    root.selectionY      = minY
                    root.selectionWidth  = w
                    root.selectionHeight = h
                    root.hasSelection    = true
                }
            }
        }
    }
}
