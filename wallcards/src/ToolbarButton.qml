import QtQuick
import qs.Commons

Rectangle {
  id: root

  property string icon: ""
  property string label: ""
  property string hotkey: ""
  property bool active: false
  property color accentColor: active ? Color.mOnSurface : Color.mOnSurfaceVariant

  default property alias customContent: customLoader.sourceComponent
  property bool hasCustomContent: customLoader.sourceComponent !== null

  signal clicked

  width: contentRow.width + 14
  height: 24
  radius: 6
  color: active ? Qt.alpha(accentColor, 0.15) : Qt.alpha(Color.mOnSurface, 0.06)
  border.width: 1
  border.color: active ? Qt.alpha(accentColor, 0.5) : Qt.alpha(Color.mOutline, 0.3)

  Row {
    id: contentRow
    anchors.centerIn: parent
    spacing: 4

    Text {
      visible: !root.hasCustomContent && root.icon !== ""
      anchors.verticalCenter: parent.verticalCenter
      text: root.icon
      color: root.accentColor
      font.family: "Material Symbols Outlined"
      font.pixelSize: 12
    }

    Text {
      visible: !root.hasCustomContent && root.label !== ""
      anchors.verticalCenter: parent.verticalCenter
      text: root.label
      color: root.accentColor
      font.family: Settings.data.ui.fontDefault
      font.pixelSize: 10
    }

    Loader {
      id: customLoader
      anchors.verticalCenter: parent.verticalCenter
      sourceComponent: null
    }

    Rectangle {
      visible: root.hotkey !== ""
      width: 14
      height: 14
      radius: 3
      anchors.verticalCenter: parent.verticalCenter
      color: Qt.alpha(root.accentColor, root.active ? 0.2 : 0.06)

      Text {
        anchors.centerIn: parent
        text: root.hotkey
        color: Qt.alpha(root.accentColor, root.active ? 1 : 0.7)
        font {
          family: Settings.data.ui.fontDefault
          pixelSize: 8
          bold: true
        }
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }

  Behavior on color {
    ColorAnimation {
      duration: 200
    }
  }
  Behavior on border.color {
    ColorAnimation {
      duration: 200
    }
  }
}
