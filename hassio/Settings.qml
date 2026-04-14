import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root
    property var pluginApi: null

    // Local state
    property string editUrl:   pluginApi?.pluginSettings?.haUrl   ?? ""
    property string editToken: pluginApi?.pluginSettings?.haToken ?? ""

    spacing: Style.marginM

    NTextInput {
        Layout.fillWidth: true
        label: "Home Assistant URL"
        placeholderText: "http://homeassistant.local:8123"
        text: root.editUrl
        onTextChanged: root.editUrl = text
    }

    NTextInput {
        Layout.fillWidth: true
        label: "Long-Lived Access Token"
        placeholderText: "Paste your token here"
        text: root.editToken
        onTextChanged: root.editToken = text
    }

    function saveSettings() {
        pluginApi.pluginSettings.haUrl   = root.editUrl
        pluginApi.pluginSettings.haToken = root.editToken
        pluginApi.saveSettings()
    }
}