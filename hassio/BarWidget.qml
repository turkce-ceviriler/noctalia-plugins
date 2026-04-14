import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

NIconButton {
    id: root

    property var pluginApi: null
    property ShellScreen screen
    property string widgetId: ""
    property string section: ""
    property int sectionWidgetIndex: -1
    property int sectionWidgetsCount: 0

    property var main: pluginApi?.mainInstance ?? null

    readonly property string _status: {
        if (!!(root.main && !root.main.connected && !root.main.authFailed && root.main.haToken !== ""))
            return "Disconnected";
        if (!!(root.main && (root.main.authFailed || root.main.haToken === "")))
            return "Connecting";
        return "Connected";
    }

    readonly property string _statusLabel: {
        if (root._status === "Disconnected")
            return pluginApi?.tr("widget.status_disconnected");
        if (root._status === "Connecting")
            return pluginApi?.tr("widget.status_connecting");
        return pluginApi?.tr("widget.status_connected");
    }

    icon: "smart-home"
    colorFg: {
        switch (root._status) {
        case "Connected":
            return Color.mPrimary;
        case "Disconnected":
            return Color.mError;
        case "Connecting":
            return Color.mOnError;
        default:
            return Color.mError;
        }
    }

    colorBg: Color.mSurfaceVariant
    colorBgHover: Color.mHover
    colorFgHover: Color.mOnHover
    colorBorder: "transparent"
    colorBorderHover: "transparent"

    onClicked: pluginApi.togglePanel(root.screen, this)

    tooltipText: pluginApi?.tr("widget.tooltip", {
        status: root._statusLabel
    })

    implicitHeight: Style.barHeight

    // Pulse animation while connecting
    SequentialAnimation on opacity {
        running: root._status === "Connecting"
        loops: Animation.Infinite
        NumberAnimation {
            to: 0.3
            duration: 600
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            to: 1.0
            duration: 600
            easing.type: Easing.InOutSine
        }
    }

    // Snap back to full opacity when done
    opacity: root._status !== "Connecting" ? 1.0 : opacity
}
