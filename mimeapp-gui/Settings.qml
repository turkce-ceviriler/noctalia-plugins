import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  property var pluginApi: null
  property bool showOnlyConflicts: pluginApi?.pluginSettings?.showOnlyConflicts ?? true

  spacing: Style.marginM

  NToggle {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.showOnlyConflicts.label") || "Show only MIME types with multiple handlers"
    description: pluginApi?.tr("settings.showOnlyConflicts.description") || "When disabled, all detected MIME types are listed."
    checked: root.showOnlyConflicts
    onToggled: checked => root.showOnlyConflicts = checked
  }

  function saveSettings() {
    if (!pluginApi) return
    pluginApi.pluginSettings.showOnlyConflicts = root.showOnlyConflicts
    pluginApi.saveSettings()
  }
}
