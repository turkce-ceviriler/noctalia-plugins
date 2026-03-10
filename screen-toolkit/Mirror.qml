import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Widgets
import qs.Services.UI

Item {
    id: root

    property bool isVisible: false
    function show()   { isVisible = true  }
    function hide()   { isVisible = false }
    function toggle() { isVisible = !isVisible }

    // FIX: shared state lifted to root — one mirror, one camera stream,
    // position/size/flip shared across all delegates so only the primary
    // screen delegate is active and the rest are transparent passthroughs.
    property bool isSquare:   true
    property bool isFlipped:  true
    property int  currentWidth:  300
    property int  currentHeight: 300
    property int  xPos: -1   // -1 = uninitialised, set on first show
    property int  yPos: -1

    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: win
            required property ShellScreen modelData

            // FIX: only the primary screen hosts the actual mirror
            readonly property bool isPrimary: modelData === Quickshell.screens[0]

            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            visible: root.isVisible
            exclusionMode: ExclusionMode.Ignore

            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.namespace: "noctalia-mirror"

            onVisibleChanged: {
                // Initialise position to top-right on first show
                if (visible && isPrimary && root.xPos === -1) {
                    root.xPos = screen.width  - root.currentWidth  - 24
                    root.yPos = Math.round((screen.height - root.currentHeight) / 2)
                }
            }

            readonly property bool isInteracting:
                isPrimary && (dragArea.pressed || resizeBR.pressed || resizeBL.pressed ||
                              resizeTR.pressed || resizeTL.pressed)

            Item { id: fullMask; anchors.fill: parent }

            mask: Region {
                item: win.isInteracting ? fullMask : container
            }

            // ── Camera — only active on primary screen ──
            MediaDevices { id: mediaDevices }

            Rectangle {
                id: container
                visible: win.isPrimary
                x: root.xPos
                y: root.yPos
                width:  root.currentWidth
                height: root.currentHeight
                radius: Style.radiusL
                color: "black"
                clip: true

                CaptureSession {
                    id: captureSession
                    camera: Camera {
                        id: camera
                        // FIX: only activate camera on the primary delegate —
                        // prevents N simultaneous camera streams on multi-monitor
                        active: win.visible && win.isPrimary
                        cameraDevice: mediaDevices.videoInputs.length > 0
                            ? mediaDevices.videoInputs[0]
                            : null
                    }
                    videoOutput: videoOutput
                }

                VideoOutput {
                    id: videoOutput
                    anchors.fill: parent
                    fillMode: VideoOutput.PreserveAspectCrop
                    transform: Scale {
                        origin.x: videoOutput.width / 2
                        xScale: root.isFlipped ? -1 : 1
                    }
                }

                // ── No camera fallback ──────────────────
                Column {
                    anchors.centerIn: parent
                    spacing: Style.marginS
                    visible: mediaDevices.videoInputs.length === 0
                    NIcon { anchors.horizontalCenter: parent.horizontalCenter; icon: "video-off"; color: Color.mOnSurfaceVariant }
                    NText { anchors.horizontalCenter: parent.horizontalCenter; text: "No camera found"; color: Color.mOnSurfaceVariant; pointSize: Style.fontSizeXS }
                }

                HoverHandler { id: containerHover }

                MouseArea {
                    id: dragArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                    property point startPoint: Qt.point(0, 0)
                    property int startX: 0; property int startY: 0

                    onPressed: mouse => {
                        startPoint = mapToItem(null, mouse.x, mouse.y)
                        startX = root.xPos; startY = root.yPos
                    }
                    onPositionChanged: mouse => {
                        if (!pressed) return
                        var p = mapToItem(null, mouse.x, mouse.y)
                        // FIX: clamp so the mirror can't be dragged fully off-screen
                        root.xPos = Math.max(0, Math.min(win.screen.width  - root.currentWidth,  startX + (p.x - startPoint.x)))
                        root.yPos = Math.max(0, Math.min(win.screen.height - root.currentHeight, startY + (p.y - startPoint.y)))
                    }
                }

                // ── Controls ────────────────────────────
                Row {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottomMargin: Style.marginM
                    spacing: Style.marginS
                    z: 3
                    opacity: containerHover.hovered ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    // Square/Wide toggle
                    Rectangle {
                        width: 36; height: 36; radius: 18
                        color: Qt.rgba(0, 0, 0, 0.65)
                        NIcon { anchors.centerIn: parent; icon: root.isSquare ? "arrows-maximize" : "crop"; color: "white" }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.isSquare = !root.isSquare
                                root.currentWidth  = root.isSquare ? 300 : 480
                                root.currentHeight = 300
                                // Re-clamp position after size change
                                root.xPos = Math.max(0, Math.min(win.screen.width  - root.currentWidth,  root.xPos))
                                root.yPos = Math.max(0, Math.min(win.screen.height - root.currentHeight, root.yPos))
                            }
                            onEntered: TooltipService.show(parent, root.isSquare ? "Switch to wide" : "Switch to square")
                            onExited:  TooltipService.hide()
                        }
                    }

                    // Flip toggle
                    Rectangle {
                        width: 36; height: 36; radius: 18
                        color: root.isFlipped ? Color.mPrimary : Qt.rgba(0, 0, 0, 0.65)
                        NIcon { anchors.centerIn: parent; icon: "flip-horizontal"; color: "white" }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: root.isFlipped = !root.isFlipped
                            onEntered: TooltipService.show(parent, "Flip camera")
                            onExited:  TooltipService.hide()
                        }
                    }

                    // Close
                    Rectangle {
                        width: 36; height: 36; radius: 18
                        color: closeHover.containsMouse ? (Color.mError || "#f44336") : Qt.rgba(0, 0, 0, 0.65)
                        NIcon { anchors.centerIn: parent; icon: "x"; color: "white" }
                        MouseArea {
                            id: closeHover; anchors.fill: parent
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: root.hide()
                            onEntered: TooltipService.show(parent, "Close")
                            onExited:  TooltipService.hide()
                        }
                    }
                }

                // ── Resize handles ──────────────────────
                component ResizeHandle: MouseArea {
                    // mode: 0=BR  1=BL  2=TR  3=TL
                    property int mode: 0
                    width: 20; height: 20
                    hoverEnabled: true
                    preventStealing: true
                    cursorShape: (mode === 0 || mode === 3) ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor
                    z: 4

                    property point startPt: Qt.point(0, 0)
                    property int startW: 0; property int startH: 0
                    property int startX: 0; property int startY: 0

                    onPressed: mouse => {
                        startPt = mapToItem(null, mouse.x, mouse.y)
                        startW = root.currentWidth;  startH = root.currentHeight
                        startX = root.xPos;          startY = root.yPos
                        mouse.accepted = true
                    }
                    onPositionChanged: mouse => {
                        if (!pressed) return
                        var p  = mapToItem(null, mouse.x, mouse.y)
                        var dx = p.x - startPt.x
                        // FIX: track dy for top-corner handles so vertical dragging
                        // also resizes correctly when approaching from above
                        var dy = p.y - startPt.y
                        var nw = startW; var nh = startH
                        var nx = startX; var ny = startY

                        if      (mode === 0) { nw = Math.max(150, startW + dx) }
                        else if (mode === 1) { nw = Math.max(150, startW - dx); nx = startX + (startW - nw) }
                        else if (mode === 2) {
                            // TR: use whichever axis moved more so diagonal drag works naturally
                            var dxAbs = Math.abs(dx), dyAbs = Math.abs(dy)
                            nw = Math.max(150, dxAbs >= dyAbs ? startW + dx : startW - dy)
                        }
                        else if (mode === 3) {
                            // TL: same — pick dominant axis
                            var dxAbs = Math.abs(dx), dyAbs = Math.abs(dy)
                            nw = Math.max(150, dxAbs >= dyAbs ? startW - dx : startW - dy)
                            nx = startX + (startW - nw)
                        }

                        nh = root.isSquare ? nw : Math.round(nw * startH / Math.max(startW, 1))
                        if (mode === 2 || mode === 3) ny = startY + (startH - nh)

                        root.currentWidth  = nw; root.currentHeight = nh
                        root.xPos = Math.max(0, nx); root.yPos = Math.max(0, ny)
                    }

                    Rectangle {
                        anchors.centerIn: parent; width: 8; height: 8; radius: 4
                        color: Color.mPrimary
                        opacity: parent.containsMouse || parent.pressed ? 1.0 : 0.4
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                    }
                }

                ResizeHandle { id: resizeBR; mode: 0; anchors.bottom: parent.bottom; anchors.right: parent.right }
                ResizeHandle { id: resizeBL; mode: 1; anchors.bottom: parent.bottom; anchors.left:  parent.left  }
                ResizeHandle { id: resizeTR; mode: 2; anchors.top:    parent.top;    anchors.right: parent.right }
                ResizeHandle { id: resizeTL; mode: 3; anchors.top:    parent.top;    anchors.left:  parent.left  }
            }
        }
    }
}
