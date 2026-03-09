import Quickshell
import qs.Commons
import qs.Widgets

NIconButton {
  id: root

  property var pluginApi: null
  property ShellScreen screen
  property string widgetId: ""
  property string section: ""

  readonly property string screenName: screen?.name ?? ""

  baseSize: Style.getCapsuleHeightForScreen(screenName)
  applyUiScale: false
  customRadius: Style.radiusL
  icon: "file-text"
  tooltipText: pluginApi?.tr("bar.tooltip") || "MIME App Defaults"

  onClicked: {
    pluginApi?.openPanel(root.screen, root)
  }
}
