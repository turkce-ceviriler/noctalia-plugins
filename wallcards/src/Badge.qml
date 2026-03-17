import QtQuick
import qs.Commons

Rectangle {
  id: root

  property string text: ""
  property string icon: ""
  property bool boldText: false
  property color textColor: Color.mOnSurface
  property color iconColor: Color.mPrimary
  property color backgroundColor: Color.mSurface
  property real fontSize: 12

  width: badgeRow.implicitWidth + 12
  height: badgeRow.implicitHeight + 8
  color: root.backgroundColor
  radius: 8
  z: 10

  Row {
    id: badgeRow
    anchors.centerIn: parent
    spacing: 5
    Text {
      visible: root.icon !== ""
      anchors.verticalCenter: parent.verticalCenter
      text: root.icon
      color: root.iconColor
      font.family: "Material Symbols Outlined"
      font.pixelSize: root.fontSize
    }
    Text {
      visible: root.text !== ""
      anchors.verticalCenter: parent.verticalCenter
      text: root.text
      color: root.textColor
      font.family: Settings.data.ui.fontDefault
      font.pixelSize: root.fontSize
      font.bold: root.boldText
      font.letterSpacing: 0.5
    }
  }
}
