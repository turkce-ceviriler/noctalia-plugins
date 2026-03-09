import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Widgets

Item {
  id: root

  property var pluginApi: null
  readonly property var mainInstance: pluginApi?.mainInstance ?? null
  readonly property var geometryPlaceholder: panelContainer
  property real contentPreferredWidth: 900 * Style.uiScaleRatio
  property real contentPreferredHeight: 700 * Style.uiScaleRatio
  readonly property bool allowAttach: true
  anchors.fill: parent

  property string backendPath: ""
  readonly property bool showOnlyConflicts: pluginApi?.pluginSettings?.showOnlyConflicts ?? true

  property bool loading: false
  property bool applying: false
  property string statusMessage: ""
  property int pendingApplyIndex: -1
  property int selectedGroupIndex: 0
  property var commonMimeTypes: [
    "inode/directory",
    "text/plain",
    "text/html",
    "application/pdf",
    "x-scheme-handler/http",
    "x-scheme-handler/https",
    "x-scheme-handler/mailto",
    "image/png",
    "image/jpeg",
    "image/gif",
    "video/mp4",
    "video/x-matroska",
    "audio/mpeg",
    "audio/flac",
    "application/zip",
    "application/x-tar",
    "application/gzip",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    "application/vnd.openxmlformats-officedocument.presentationml.presentation"
  ]
  property var groupTabs: [
    { "key": "all", "name": "All", "count": 0 }
  ]

  property ListModel entriesModel: ListModel {}
  property ListModel filteredEntriesModel: ListModel {}

  function updateBackendPath() {
    if (!pluginApi || !pluginApi.pluginDir) {
      backendPath = ""
      return
    }
    backendPath = pluginApi.pluginDir + "/mimeapps_backend.py"
  }

  function refreshList() {
    if (loading) return
    if (backendPath === "") {
      statusMessage = "Backend path not ready yet."
      return
    }
    statusMessage = ""
    loading = true

    var args = ["python3", backendPath, "scan"]
    if (!showOnlyConflicts) {
      args.push("--all")
    }

    scanProcess.command = args
    scanProcess.running = true
  }

  function mimeGroupFromType(mimeType) {
    var text = String(mimeType || "")
    var slash = text.indexOf("/")
    if (slash <= 0) return "other"
    return text.substring(0, slash)
  }

  function selectedGroupKey() {
    if (!groupTabs || selectedGroupIndex < 0 || selectedGroupIndex >= groupTabs.length) {
      return "all"
    }
    return groupTabs[selectedGroupIndex].key || "all"
  }

  function rebuildGroupTabs() {
    var counts = {}
    var order = []
    var commonCount = 0

    for (var i = 0; i < entriesModel.count; i++) {
      var mimeType = entriesModel.get(i).mimeType
      if (commonMimeTypes.indexOf(mimeType) !== -1) {
        commonCount += 1
      }

      var group = mimeGroupFromType(entriesModel.get(i).mimeType)
      if (counts[group] === undefined) {
        counts[group] = 0
        order.push(group)
      }
      counts[group] += 1
    }

    order.sort()

    var tabs = [{ "key": "all", "name": "All", "count": entriesModel.count }]
    tabs.push({ "key": "common", "name": "Common", "count": commonCount })
    for (var j = 0; j < order.length; j++) {
      var key = order[j]
      tabs.push({
        "key": key,
        "name": key,
        "count": counts[key]
      })
    }

    groupTabs = tabs

    if (selectedGroupIndex >= groupTabs.length) {
      selectedGroupIndex = 0
    }
  }

  function rebuildFilteredEntries() {
    filteredEntriesModel.clear()

    var group = selectedGroupKey()
    for (var i = 0; i < entriesModel.count; i++) {
      var row = entriesModel.get(i)
      var include = group === "all"
        || (group === "common" && commonMimeTypes.indexOf(row.mimeType) !== -1)
        || mimeGroupFromType(row.mimeType) === group
      if (!include) continue

      filteredEntriesModel.append({
        sourceIndex: i,
        mimeType: row.mimeType,
        handlers: row.handlers,
        currentDefault: row.currentDefault,
        currentDefaultName: row.currentDefaultName,
        defaultSource: row.defaultSource,
        selectedDesktop: row.selectedDesktop,
        applying: row.applying,
        applyError: row.applyError
      })
    }
  }

  function syncFilteredRowFromSource(sourceIndex) {
    for (var i = 0; i < filteredEntriesModel.count; i++) {
      var item = filteredEntriesModel.get(i)
      if (item.sourceIndex !== sourceIndex) continue

      var src = entriesModel.get(sourceIndex)
      filteredEntriesModel.setProperty(i, "handlers", src.handlers)
      filteredEntriesModel.setProperty(i, "currentDefault", src.currentDefault)
      filteredEntriesModel.setProperty(i, "currentDefaultName", src.currentDefaultName)
      filteredEntriesModel.setProperty(i, "defaultSource", src.defaultSource)
      filteredEntriesModel.setProperty(i, "selectedDesktop", src.selectedDesktop)
      filteredEntriesModel.setProperty(i, "applying", src.applying)
      filteredEntriesModel.setProperty(i, "applyError", src.applyError)
      return
    }
  }

  function handlerNameFor(index, desktopId) {
    var row = entriesModel.get(index)
    var handlers = row.handlers || []
    for (var i = 0; i < handlers.length; i++) {
      if (handlers[i].key === desktopId) {
        return handlers[i].name
      }
    }
    return desktopId
  }

  function applyDefault(sourceIndex) {
    if (applying || sourceIndex < 0 || sourceIndex >= entriesModel.count) return

    var row = entriesModel.get(sourceIndex)
    var selectedDesktop = row.selectedDesktop || ""
    if (!selectedDesktop) return

    pendingApplyIndex = sourceIndex
    applying = true
    statusMessage = ""

    entriesModel.setProperty(sourceIndex, "applyError", "")
    entriesModel.setProperty(sourceIndex, "applying", true)
    syncFilteredRowFromSource(sourceIndex)

    setProcess.command = [
      "python3",
      backendPath,
      "set-default",
      "--mime",
      row.mimeType,
      "--desktop",
      selectedDesktop
    ]
    setProcess.running = true
  }

  onPluginApiChanged: {
    updateBackendPath()
    if (backendPath !== "") {
      refreshList()
    }
  }

  Component.onCompleted: {
    updateBackendPath()
    if (backendPath !== "") {
      refreshList()
    }
  }

  Process {
    id: scanProcess
    running: false
    command: []

    stdout: StdioCollector {
      id: scanStdout
    }

    stderr: StdioCollector {
      id: scanStderr
    }

    onExited: (exitCode) => {
      root.loading = false

      if (exitCode !== 0) {
        root.statusMessage = scanStderr.text.trim() || "Failed to scan MIME handlers. Ensure python3 is installed and available in PATH."
        return
      }

      try {
        var payload = JSON.parse(scanStdout.text)
        if (!payload.ok) {
          root.statusMessage = payload.error || "Scan failed."
          return
        }

        root.entriesModel.clear()
        root.filteredEntriesModel.clear()

        var rows = payload.entries || []
        for (var i = 0; i < rows.length; i++) {
          var row = rows[i]
          var handlers = row.handlers || []
          var selectedDesktop = row.currentDefault || (handlers.length > 0 ? handlers[0].key : "")

          root.entriesModel.append({
            mimeType: row.mimeType || "",
            handlers: handlers,
            currentDefault: row.currentDefault || "",
            currentDefaultName: row.currentDefaultName || "",
            defaultSource: row.defaultSource || "",
            selectedDesktop: selectedDesktop,
            applying: false,
            applyError: ""
          })
        }

        root.rebuildGroupTabs()
        root.rebuildFilteredEntries()

        if (root.filteredEntriesModel.count === 0) {
          root.statusMessage = root.showOnlyConflicts
            ? "No MIME types with multiple handlers were found."
            : "No MIME handlers were found from installed desktop files."
        }
      } catch (e) {
        root.statusMessage = "Failed to parse scan result: " + e
      }
    }
  }

  Process {
    id: setProcess
    running: false
    command: []

    stdout: StdioCollector {
      id: setStdout
    }

    stderr: StdioCollector {
      id: setStderr
    }

    onExited: (exitCode) => {
      var index = root.pendingApplyIndex
      root.pendingApplyIndex = -1
      root.applying = false

      if (index >= 0 && index < root.entriesModel.count) {
        root.entriesModel.setProperty(index, "applying", false)
        root.syncFilteredRowFromSource(index)
      }

      if (exitCode !== 0) {
        var message = setStderr.text.trim() || "Failed to save default application. Ensure python3 is installed and available in PATH."
        root.statusMessage = message
        if (index >= 0 && index < root.entriesModel.count) {
          root.entriesModel.setProperty(index, "applyError", message)
          root.syncFilteredRowFromSource(index)
        }
        return
      }

      try {
        var payload = JSON.parse(setStdout.text)
        if (!payload.ok) {
          var error = payload.error || "Failed to save default application."
          root.statusMessage = error
          if (index >= 0 && index < root.entriesModel.count) {
            root.entriesModel.setProperty(index, "applyError", error)
            root.syncFilteredRowFromSource(index)
          }
          return
        }

        if (index >= 0 && index < root.entriesModel.count) {
          var selected = root.entriesModel.get(index).selectedDesktop || ""
          root.entriesModel.setProperty(index, "currentDefault", selected)
          root.entriesModel.setProperty(index, "currentDefaultName", root.handlerNameFor(index, selected))
          root.entriesModel.setProperty(index, "defaultSource", payload.file || "")
          root.entriesModel.setProperty(index, "applyError", "")
          root.syncFilteredRowFromSource(index)
        }

        root.statusMessage = "Updated default for " + (payload.mimeType || "selected MIME type") + "."
      } catch (e) {
        root.statusMessage = "Default updated, but response parsing failed: " + e
      }
    }
  }

  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color: "transparent"

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.marginL
      spacing: Style.marginM

      RowLayout {
        Layout.fillWidth: true

        NText {
          text: pluginApi?.tr("panel.title") || "MimeApp GUI"
          pointSize: Style.fontSizeL
          font.weight: Font.DemiBold
          color: Color.mOnSurface
        }

        Item { Layout.fillWidth: true }

        NButton {
          text: pluginApi?.tr("panel.refresh") || "Refresh"
          icon: "refresh"
          enabled: !root.loading && !root.applying
          onClicked: root.refreshList()
        }
      }

      NText {
        Layout.fillWidth: true
        text: pluginApi?.tr("panel.subtitle") || "Select a default application for each MIME type. Changes are written to ~/.config/mimeapps.list."
        pointSize: Style.fontSizeS
        color: Color.mOnSurfaceVariant
        wrapMode: Text.WordWrap
      }

      RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Style.marginM

        Rectangle {
          Layout.preferredWidth: 220 * Style.uiScaleRatio
          Layout.fillHeight: true
          radius: Style.radiusM
          color: Color.mSurfaceVariant
          visible: root.groupTabs.length > 1

          ScrollView {
            anchors.fill: parent
            anchors.margins: Style.marginS
            clip: true

            ListView {
              id: groupListView
              model: root.groupTabs
              spacing: Style.marginS
              boundsBehavior: Flickable.StopAtBounds

              delegate: Rectangle {
                required property var modelData
                required property int index

                width: groupListView.width
                radius: Style.radiusS
                color: index === root.selectedGroupIndex ? Color.mPrimary : Color.mSurface
                implicitHeight: groupText.implicitHeight + (Style.marginS * 2)

                NText {
                  id: groupText
                  anchors.fill: parent
                  anchors.margins: Style.marginS
                  text: modelData.name + " (" + modelData.count + ")"
                  color: index === root.selectedGroupIndex ? Color.mOnPrimary : Color.mOnSurface
                  pointSize: Style.fontSizeS
                  font.weight: index === root.selectedGroupIndex ? Font.Medium : Font.Normal
                  wrapMode: Text.WordWrap
                }

                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.selectedGroupIndex = index
                    root.rebuildFilteredEntries()
                  }
                }
              }
            }
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          Layout.fillHeight: true
          spacing: Style.marginM

          NText {
            Layout.fillWidth: true
            visible: root.loading
            text: pluginApi?.tr("panel.loading") || "Scanning desktop entries..."
            pointSize: Style.fontSizeS
            color: Color.mOnSurfaceVariant
          }

          NText {
            Layout.fillWidth: true
            visible: root.statusMessage !== ""
            text: root.statusMessage
            pointSize: Style.fontSizeS
            color: root.statusMessage.toLowerCase().indexOf("failed") !== -1 ? Color.mError : Color.mOnSurfaceVariant
            wrapMode: Text.WordWrap
          }

          ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ListView {
              id: listView
              model: root.filteredEntriesModel
              spacing: Style.marginS
              boundsBehavior: Flickable.StopAtBounds

              delegate: Rectangle {
                required property int index
                required property int sourceIndex
                required property string mimeType
                required property var handlers
                required property string currentDefault
                required property string currentDefaultName
                required property string defaultSource
                required property string selectedDesktop
                required property bool applying
                required property string applyError

                width: listView.width
                color: Color.mSurfaceVariant
                radius: Style.radiusM
                implicitHeight: cardLayout.implicitHeight + (Style.marginM * 2)

                ColumnLayout {
                  id: cardLayout
                  anchors.fill: parent
                  anchors.margins: Style.marginM
                  spacing: Style.marginS

                  NText {
                    Layout.fillWidth: true
                    text: mimeType
                    pointSize: Style.fontSizeM
                    font.weight: Font.Medium
                    color: Color.mOnSurface
                    wrapMode: Text.WordWrap
                  }

                  NText {
                    Layout.fillWidth: true
                    text: "Current: " + (currentDefaultName || currentDefault || "(none)")
                    pointSize: Style.fontSizeS
                    color: Color.mOnSurfaceVariant
                    wrapMode: Text.WordWrap
                  }

                  NText {
                    Layout.fillWidth: true
                    visible: defaultSource !== ""
                    text: "Source: " + defaultSource
                    pointSize: Style.fontSizeS
                    color: Color.mOnSurfaceVariant
                    wrapMode: Text.WordWrap
                  }

                  RowLayout {
                    Layout.fillWidth: true
                    spacing: Style.marginS

                    NComboBox {
                      Layout.fillWidth: true
                      label: pluginApi?.tr("panel.handler.label") || "Handler"
                      description: pluginApi?.tr("panel.handler.description") || "Choose the preferred desktop app"
                      model: handlers
                      currentKey: selectedDesktop
                      enabled: !applying && !root.loading && !root.applying
                      onSelected: key => {
                        root.entriesModel.setProperty(sourceIndex, "selectedDesktop", key)
                        root.filteredEntriesModel.setProperty(index, "selectedDesktop", key)
                        root.entriesModel.setProperty(sourceIndex, "applyError", "")
                        root.syncFilteredRowFromSource(sourceIndex)
                      }
                    }

                    NButton {
                      text: applying ? (pluginApi?.tr("panel.apply.saving") || "Saving...") : (pluginApi?.tr("panel.apply.button") || "Apply")
                      icon: "check"
                      enabled: !applying && !root.loading && !root.applying && selectedDesktop !== "" && selectedDesktop !== currentDefault
                      onClicked: root.applyDefault(sourceIndex)
                    }
                  }

                  NText {
                    Layout.fillWidth: true
                    visible: applyError !== ""
                    text: applyError
                    pointSize: Style.fontSizeS
                    color: Color.mError
                    wrapMode: Text.WordWrap
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
