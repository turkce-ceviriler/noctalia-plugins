import QtQuick
import QtQuick.Layouts
import Quickshell.Wayland
import qs.Commons
import qs.Widgets

Item {
    id: overlay
    property var host: null

    anchors.fill: parent

    ScreencopyView {
        anchors.fill: parent
        live: false
        captureSource: host?.screen
    }

    Repeater {
        model: host?.windowRegions ?? []
        delegate: NBox {
            required property var modelData
            z: 1
            x: modelData.x
            y: modelData.y
            width: modelData.width
            height: modelData.height
            color: targeted ? Color.mPrimaryContainer : "transparent"
            border.color: targeted ? Color.mPrimary : Color.mOnSurfaceVariant
            border.width: targeted ? Math.max(2, Math.round(3 * (host?.uiScale ?? 1))) : Math.max(1, Math.round(host?.uiScale ?? 1))
            visible: !(host?.dragging ?? false) && (host?.mouseOnThisScreen ?? false)

            readonly property bool targeted:
                host?.hoveredWindow !== null && host?.hoveredWindow?.address === modelData.address

            Behavior on border.width { NumberAnimation { duration: 80 } }
            Behavior on color { ColorAnimation { duration: 80 } }
        }
    }

    NBox {
        id: darkenOverlay
        z: 1
        anchors {
            left: parent.left
            top: parent.top
            leftMargin: (host?.regionX ?? 0) - border.width
            topMargin: (host?.regionY ?? 0) - border.width
        }
        width: (host?.regionWidth ?? 0) + border.width * 2
        height: (host?.regionHeight ?? 0) + border.width * 2
        color: "transparent"
        border.color: Color.mErrorContainer
        border.width: Math.max(parent.width, parent.height)
        visible: (host?.dragging ?? false) && (host?.mouseOnThisScreen ?? false)
    }

    NBox {
        z: 2
        x: host?.regionX ?? 0
        y: host?.regionY ?? 0
        width: host?.regionWidth ?? 0
        height: host?.regionHeight ?? 0
        color: "transparent"
        border.color: Color.mOnSurface
        border.width: Math.max(1, Math.round(2 * (host?.uiScale ?? 1)))
        visible: (host?.dragging ?? false) && (host?.mouseOnThisScreen ?? false)
    }

    NLabel {
        z: 3
        x: (host?.regionX ?? 0) + (host?.regionWidth ?? 0) - width - (8 * (host?.uiScale ?? 1))
        y: (host?.regionY ?? 0) + (host?.regionHeight ?? 0) + (8 * (host?.uiScale ?? 1))
        text: (host?.dragging ?? false) ? `${Math.round(host?.regionWidth ?? 0)} x ${Math.round(host?.regionHeight ?? 0)}` : ""
        color: Color.mOnSurface
        font.pixelSize: Math.max(10, Math.round(13 * (host?.uiScale ?? 1)))
        visible: (host?.dragging ?? false) && (host?.mouseOnThisScreen ?? false)
    }

    NBox {
        visible: (host?.mouseInside ?? false) && (host?.enableCross ?? false) && (host?.mouseOnThisScreen ?? false)
        opacity: 0.4
        z: 2
        x: host?.mouseX ?? 0
        anchors { top: parent.top; bottom: parent.bottom }
        width: Math.max(1, Math.round(host?.uiScale ?? 1))
        color: Color.mOnSurface
    }
    NBox {
        visible: (host?.mouseInside ?? false) && (host?.enableCross ?? false) && (host?.mouseOnThisScreen ?? false)
        opacity: 0.4
        z: 2
        y: host?.mouseY ?? 0
        anchors { left: parent.left; right: parent.right }
        height: Math.max(1, Math.round(host?.uiScale ?? 1))
        color: Color.mOnSurface
    }

    NBox {
        anchors.fill: parent
        color: Color.mErrorContainer
        visible: !(host?.dragging ?? false) && (host?.mouseOnThisScreen ?? false)
        z: 0
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: (host?.enableCross ?? false) ? Qt.CrossCursor : Qt.ArrowCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        z: 10

        onPositionChanged: (mouse) => {
            host.mouseOnThisScreen = true
            host.mouseX = mouse.x
            host.mouseY = mouse.y
            host.mouseInside = true
            if (host.dragging) {
                host.draggingX = mouse.x
                host.draggingY = mouse.y
            } else if (typeof host.findWindowAt === "function") {
                host.hoveredWindow = host.findWindowAt(mouse.x, mouse.y)
            }
        }
        onEntered: {
            host.mouseOnThisScreen = true
            host.mouseInside = true
        }
        onExited: {
            host.mouseInside = false
            host.mouseOnThisScreen = false
            if (host.hoveredWindow !== undefined) {
                host.hoveredWindow = null
            }
        }
        onPressed: (mouse) => {
            host.dragStartX = mouse.x
            host.dragStartY = mouse.y
            host.draggingX = mouse.x
            host.draggingY = mouse.y
            host.dragging = true
            host.mouseButton = mouse.button
        }
        onReleased: (mouse) => {
            host.dragging = false
            host.finish()
        }
    }

    NBox {
        id: rowBackground
        color: Color.mPrimary
        radius: Style.radiusM
        width: rowLayout.implicitWidth + Style.marginL * 2
        height: rowLayout.implicitHeight + Style.marginM * 2
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Style.marginM
        z: 20
        visible: host?.mouseOnThisScreen ?? false
        opacity: (host?.mouseOnThisScreen ?? false) ? 1 : 0

        RowLayout {
            z: 20
            id: rowLayout
            anchors.fill: parent
            anchors.margins: Style.marginM
            spacing: Style.marginM

            NIcon {
                icon: host?.targetMeta?.iconForTarget(host?.target)
                color: Color.mOnPrimary
            }

            NText {
                text: host?.targetMeta?.labelForTarget(host?.pluginApi, host?.target)
                color: Color.mOnPrimary
            }

            NButton {
                z: 20
                icon: "close"
                backgroundColor: Color.mError
                textColor: Color.mOnError
                onClicked: {
                    host?.closeSelector()
                }
            }
        }

        Behavior on opacity { NumberAnimation { duration: Style.animationNormal; easing.type: Easing.OutQuad } }
    }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) {
                event.accepted = true
                host?.closeSelector()
            }
        }

        Component.onCompleted: {
            forceActiveFocus()
        }
    }
}
