import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets
import qs.Services.UI

Item {
  id: root
  implicitWidth: 600
  implicitHeight: 500
  property var pluginApi: null

  readonly property var cs: pluginApi?.pluginSettings?.claude || ({})

  function set(key, value) {
    if (!pluginApi) { return; }
    if (!pluginApi.pluginSettings.claude) { pluginApi.pluginSettings.claude = {}; }
    pluginApi.pluginSettings.claude[key] = value;
    pluginApi.saveSettings();
  }

  function setTop(key, value) {
    if (!pluginApi) { return; }
    pluginApi.pluginSettings[key] = value;
    pluginApi.saveSettings();
  }

  function parseList(raw) {
    if (!raw) { return []; }
    return String(raw).split(/[,\n]/).map(function (s) { return s.trim(); }).filter(function (s) { return s !== ""; });
  }

  ScrollView {
    id: scroller
    anchors.fill: parent
    contentWidth: availableWidth
    clip: true

    ColumnLayout {
      width: root.width
      spacing: Style.marginL

      // ===== GENERAL =====
      NText { text: pluginApi?.tr("settings.sectionGeneral"); font.weight: Font.Bold; pointSize: Style.fontSizeL }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NText { text: pluginApi?.tr("settings.binary") }
        NTextInput {
          Layout.fillWidth: true
          text: cs.binary || "claude"
          onEditingFinished: set("binary", text)
        }

        NText { text: pluginApi?.tr("settings.workingDir") }
        NTextInput {
          Layout.fillWidth: true
          text: cs.workingDir || ""
          placeholderText: "/home/you/project"
          onEditingFinished: set("workingDir", text)
        }
        NText {
          text: pluginApi?.tr("settings.workingDirHelp")
          pointSize: Style.fontSizeXS
          color: Color.mOnSurfaceVariant
          Layout.fillWidth: true
          wrapMode: Text.Wrap
        }
      }

      // ===== PERMISSIONS =====
      NText { text: pluginApi?.tr("settings.sectionPermissions"); font.weight: Font.Bold; pointSize: Style.fontSizeL }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NText { text: pluginApi?.tr("settings.permissionMode") }
        ComboBox {
          Layout.fillWidth: true
          textRole: "label"
          valueRole: "value"
          model: [
            { label: pluginApi?.tr("settings.permModeDefault"), value: "default" },
            { label: pluginApi?.tr("settings.permModeAccept"), value: "acceptEdits" },
            { label: pluginApi?.tr("settings.permModePlan"), value: "plan" },
            { label: pluginApi?.tr("settings.permModeBypass"), value: "bypassPermissions" }
          ]
          currentIndex: {
            var v = cs.permissionMode || "default";
            if (v === "acceptEdits") return 1;
            if (v === "plan") return 2;
            if (v === "bypassPermissions") return 3;
            return 0;
          }
          onActivated: function (index) {
            var v = model[index].value;
            if (v === "bypassPermissions" && (cs.requireConfirmBypass !== false)) {
              bypassConfirm.open();
            } else {
              set("permissionMode", v);
            }
          }
        }

        NText { text: pluginApi?.tr("settings.allowedTools") }
        NTextInput {
          Layout.fillWidth: true
          text: (cs.allowedTools || []).join(",")
          placeholderText: "Read,Edit,Bash(git:*),WebFetch"
          onEditingFinished: set("allowedTools", parseList(text))
        }
        NText {
          text: pluginApi?.tr("settings.allowedToolsHelp")
          pointSize: Style.fontSizeXS
          color: Color.mOnSurfaceVariant
          Layout.fillWidth: true
          wrapMode: Text.Wrap
        }

        NText { text: pluginApi?.tr("settings.disallowedTools") }
        NTextInput {
          Layout.fillWidth: true
          text: (cs.disallowedTools || []).join(",")
          placeholderText: "Bash(rm:*),WebFetch"
          onEditingFinished: set("disallowedTools", parseList(text))
        }

        NText { text: pluginApi?.tr("settings.additionalDirs") }
        TextArea {
          Layout.fillWidth: true
          Layout.preferredHeight: 72
          text: (cs.additionalDirs || []).join("\n")
          placeholderText: "/home/you/notes\n/tmp/scratch"
          onEditingFinished: set("additionalDirs", parseList(text))
        }
        NText {
          text: pluginApi?.tr("settings.additionalDirsHelp")
          pointSize: Style.fontSizeXS
          color: Color.mOnSurfaceVariant
          Layout.fillWidth: true
          wrapMode: Text.Wrap
        }

        // Dangerously-skip toggle — always last, visually separated
        Rectangle {
          Layout.fillWidth: true
          color: cs.dangerouslySkipPermissions ? Qt.rgba(0.9, 0.2, 0.2, 0.15) : "transparent"
          border.color: cs.dangerouslySkipPermissions ? (Color.mError || "#c0392b") : Color.mOutline
          border.width: Style.borderS
          radius: Style.radiusM
          implicitHeight: dangerousCol.implicitHeight + Style.marginS * 2

          ColumnLayout {
            id: dangerousCol
            anchors.fill: parent
            anchors.margins: Style.marginS
            spacing: Style.marginXS

            RowLayout {
              Layout.fillWidth: true
              CheckBox {
                checked: cs.dangerouslySkipPermissions === true
                text: pluginApi?.tr("settings.dangerouslySkip")
                onToggled: {
                  if (checked) { bypassConfirm.forSkip = true; bypassConfirm.open(); checked = false; }
                  else         { set("dangerouslySkipPermissions", false); }
                }
              }
            }
            NText {
              Layout.fillWidth: true
              text: pluginApi?.tr("settings.dangerouslySkipHelp")
              wrapMode: Text.Wrap
              pointSize: Style.fontSizeXS
              color: Color.mOnSurfaceVariant
            }
            CheckBox {
              checked: cs.requireConfirmBypass !== false
              text: pluginApi?.tr("settings.confirmBypass")
              onToggled: set("requireConfirmBypass", checked)
            }
          }
        }
      }

      // ===== SESSION & MODEL =====
      NText { text: pluginApi?.tr("settings.sectionSession"); font.weight: Font.Bold; pointSize: Style.fontSizeL }
      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NText { text: pluginApi?.tr("settings.model") }
        NTextInput {
          Layout.fillWidth: true
          text: cs.model || ""
          placeholderText: "claude-opus-4-7"
          onEditingFinished: set("model", text)
        }
        NText {
          text: pluginApi?.tr("settings.modelHelp")
          pointSize: Style.fontSizeXS
          color: Color.mOnSurfaceVariant
          Layout.fillWidth: true
          wrapMode: Text.Wrap
        }

        NText { text: pluginApi?.tr("settings.fallbackModel") }
        NTextInput {
          Layout.fillWidth: true
          text: cs.fallbackModel || ""
          placeholderText: "claude-sonnet-4-6"
          onEditingFinished: set("fallbackModel", text)
        }

        CheckBox {
          text: pluginApi?.tr("settings.autoResume")
          checked: cs.autoResume !== false
          onToggled: set("autoResume", checked)
        }

        NText { text: pluginApi?.tr("settings.maxTurns") }
        SpinBox {
          from: 0; to: 9999
          value: cs.maxTurns || 0
          onValueModified: set("maxTurns", value)
        }

        CheckBox {
          text: pluginApi?.tr("settings.includePartialMessages")
          checked: cs.includePartialMessages === true
          onToggled: set("includePartialMessages", checked)
        }

        CheckBox {
          text: pluginApi?.tr("settings.injectNoctaliaContext")
          checked: cs.injectNoctaliaContext !== false
          onToggled: set("injectNoctaliaContext", checked)
        }
        NText {
          text: pluginApi?.tr("settings.injectNoctaliaContextHelp")
          pointSize: Style.fontSizeXS
          color: Color.mOnSurfaceVariant
          Layout.fillWidth: true
          wrapMode: Text.Wrap
        }

        NText { text: pluginApi?.tr("settings.appendSystemPrompt") }
        TextArea {
          Layout.fillWidth: true
          Layout.preferredHeight: 72
          text: cs.appendSystemPrompt || ""
          onEditingFinished: set("appendSystemPrompt", text)
        }
      }

      // ===== MCP =====
      NText { text: pluginApi?.tr("settings.sectionMcp"); font.weight: Font.Bold; pointSize: Style.fontSizeL }
      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NText { text: pluginApi?.tr("settings.mcpConfigPath") }
        NTextInput {
          Layout.fillWidth: true
          text: cs.mcpConfigPath || ""
          placeholderText: "/home/you/.config/claude/mcp.json"
          onEditingFinished: set("mcpConfigPath", text)
        }
        CheckBox {
          text: pluginApi?.tr("settings.mcpStrict")
          checked: cs.strictMcpConfig === true
          onToggled: set("strictMcpConfig", checked)
        }
      }

      // ===== PANEL =====
      NText { text: pluginApi?.tr("settings.sectionPanel"); font.weight: Font.Bold; pointSize: Style.fontSizeL }
      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NText { text: pluginApi?.tr("settings.panelPosition") }
        ComboBox {
          Layout.fillWidth: true
          model: ["right", "left", "center", "top", "bottom"]
          currentIndex: Math.max(0, model.indexOf(pluginApi?.pluginSettings?.panelPosition || "right"))
          onActivated: function (i) { setTop("panelPosition", model[i]); }
        }

        CheckBox {
          text: pluginApi?.tr("settings.panelDetached")
          checked: pluginApi?.pluginSettings?.panelDetached ?? true
          onToggled: setTop("panelDetached", checked)
        }

        NText { text: pluginApi?.tr("settings.panelWidth") }
        SpinBox {
          from: 320; to: 1600
          value: pluginApi?.pluginSettings?.panelWidth ?? 620
          onValueModified: setTop("panelWidth", value)
        }

        NText { text: pluginApi?.tr("settings.panelHeightRatio") }
        SpinBox {
          from: 30; to: 100
          value: Math.round((pluginApi?.pluginSettings?.panelHeightRatio ?? 0.9) * 100)
          onValueModified: setTop("panelHeightRatio", value / 100)
        }
      }
    }
  }

  // ----- Bypass confirmation dialog -----
  Dialog {
    id: bypassConfirm
    modal: true
    title: "Confirm"
    width: 420
    property bool forSkip: false

    contentItem: ColumnLayout {
      spacing: Style.marginS
      NText {
        text: bypassConfirm.forSkip
              ? "You are about to enable --dangerously-skip-permissions.\nClaude will run every tool (including Bash) without prompting.\nUse only in a throwaway sandbox."
              : "You are about to set permission mode to bypassPermissions.\nClaude will run every tool without prompting."
        wrapMode: Text.Wrap
        Layout.fillWidth: true
        color: Color.mError || "#c0392b"
      }
      NText {
        text: pluginApi?.tr("dialog.proceed")
        font.weight: Font.Bold
      }
    }

    standardButtons: Dialog.Ok | Dialog.Cancel
    onAccepted: {
      if (forSkip) {
        set("dangerouslySkipPermissions", true);
        ToastService.showError(pluginApi?.tr("toast.bypassEnabled"));
      } else {
        set("permissionMode", "bypassPermissions");
        ToastService.showError(pluginApi?.tr("toast.bypassEnabled"));
      }
      forSkip = false;
    }
    onRejected: {
      ToastService.showNotice(pluginApi?.tr("toast.bypassCancelled"));
      forSkip = false;
    }
  }
}
