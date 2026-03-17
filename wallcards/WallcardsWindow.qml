import "src"

import qs.Commons
import qs.Services.UI

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Qt.labs.folderlistmodel
import Qt5Compat.GraphicalEffects
import QtMultimedia

PanelWindow {
  id: root

  aboveWindows: true
  color: "transparent"
  exclusionMode: "Ignore"
  exclusiveZone: 0
  implicitHeight: screen.height
  implicitWidth: screen.width
  onSelectedFilterChanged: rebuildFilteredItems()
  screen: pluginApi.panelOpenScreen
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
  WlrLayershell.layer: WlrLayer.Overlay

  property var pluginApi: null

  //
  // ── Configuration ──
  //

  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  property int animationDuration: cfg.animation_duration || defaults.animation_duration
  property color backgroundColor: cfg.background_color || defaults.background_color
  property real backgroundOpacity: cfg.background_opacity || defaults.background_opacity
  property string cacheDir: Settings.cacheDir + "/thumbnails/"
  property int contentHeight2: cfg.card_height || defaults.card_height
  property int cardSpacing: cfg.card_spacing || defaults.card_spacing
  property int cardStripWidth: cfg.card_strip_width || defaults.card_strip_width
  property int cardRadius: cfg.card_radius || defaults.card_radius
  property int cardsShown: cfg.cards_shown || defaults.cards_shown
  property var filterImages: cfg.filter_images || defaults.filter_images
  property var filterVideos: cfg.filter_videos || defaults.filter_videos
  property bool livePreview: cfg.live_preview || defaults.live_preview
  property string selectedFilter: cfg.selected_filter || defaults.selected_filter
  property var shearFactor: cfg.shear_factor || defaults.shear_factor
  property var topBarHeight: cfg.top_bar_height || defaults.top_bar_height
  property var topBarRadius: cfg.top_bar_radius || defaults.top_bar_radius
  property string wallpaperDir: Settings.data.wallpaper.directory

  property bool loading: true
  property string loadingMessage
  property int pendingProcesses: 0
  property int thumbnailRevision: 0
  property var filteredItems: []
  property int filteredCount: filteredItems.length

  //
  // ── File model ──
  //

  property Utils utils: Utils {
    filterImages: root.filterImages
    filterVideos: root.filterVideos
  }

  function rebuildFilteredItems() {
    var items = [];
    for (var i = 0; i < folderModel.count; i++) {
      var fn = folderModel.get(i, "fileName");
      var fp = folderModel.get(i, "filePath");
      if (utils.matchesFilter(fn, selectedFilter))
        items.push({
          "fileName": fn,
          "filePath": fp
        });
    }
    filteredItems = items;
    if (cardStack.currentIndex >= filteredCount)
      cardStack.currentIndex = 0;
  }

  function getFileName(idx) {
    return filteredItems.length === 0 ? "" : filteredItems[idx].fileName;
  }

  function getFilePath(idx) {
    return filteredItems.length === 0 ? "" : filteredItems[idx].filePath;
  }

  function createThumbnails() {
    var proc = processComponent.createObject(null, {
      "command": ["mkdir", "-p", cacheDir]
    });
    proc.running = true;

    for (var i = 0; i < folderModel.count; i++) {
      (function (idx) {
          var filePath = folderModel.get(idx, "filePath");
          var fileName = folderModel.get(idx, "fileName");
          var thumbName = utils.thumbnailName(fileName);
          var thumbnail = cacheDir + "/" + thumbName;

          var cmd;
          if (utils.isVideo(fileName))
            cmd = "[ -f '" + thumbnail + "' ] || ffmpeg -y -i '" + filePath + "' -vf 'select=eq(n\\,0),scale=-1:500' -frames:v 1 -q:v 2 '" + thumbnail + "' </dev/null 2>/dev/null";
          else
            cmd = "[ -f '" + thumbnail + "' ] || magick '" + filePath + "' -resize x500 -quality 95 '" + thumbnail + "'";

          root.pendingProcesses++;
          var proc = processComponent.createObject(null, {
            "command": ["bash", "-c", cmd]
          });

          proc.exited.connect(function () {
            root.pendingProcesses--;
            root.thumbnailRevision++;

            if (root.pendingProcesses === 0)
              root.loading = false;
            else
              root.loadingMessage = `Generating thumbnails… ${root.pendingProcesses} remaining`;

            proc.destroy();
          });

          proc.running = true;
        })(i);
    }
  }

  function applyCard(filePath, quit) {
    var fileName = filePath.substring(filePath.lastIndexOf("/") + 1);

    if (utils.isVideo(fileName))
      console.log("Not implemented yet. Maybye use video wallpaper plugin?");
    else
    // proc = processComponent.createObject(null, {
    //   "command": ["bash", "-c", "pkill -x mpvpaper 2>/dev/null || true; sleep 0.2; for m in $(hyprctl monitors | awk '/^Monitor /{print $2}'); do setsid -f mpvpaper -p -f -o '--loop-file=inf' \"$m\" '" + filePath + "' >/dev/null 2>&1 & done"]
    // });
    {
      var screen = Settings.data.wallpaper.setWallpaperOnAllMonitors ? undefined : targetScreen.name;
      WallpaperService.changeWallpaper(filePath, screen);
      WallpaperService.applyFavoriteTheme(path, screen);
    }
  }

  FolderListModel {
    id: folderModel

    folder: Qt.resolvedUrl("file://" + wallpaperDir)
    showDirs: false
    nameFilters: utils.nameFilters()
    sortField: FolderListModel.Name
    onStatusChanged: {
      if (status === FolderListModel.Ready) {
        createThumbnails();
        rebuildFilteredItems();

        var rnd = Math.floor(Math.random() * root.filteredCount);
        cardStack.currentIndex = rnd;
        cardStack.runningIndex = rnd;
        cardStack.animationIndex = rnd;
      }
    }
  }

  Component {
    id: processComponent
    Process {}
  }

  //
  // ── Dimmed background ──
  //

  Rectangle {
    anchors.fill: parent
    color: root.backgroundColor
    opacity: 0.0

    Component.onCompleted: {
      opacity = root.backgroundOpacity;
    }

    Behavior on opacity {
      NumberAnimation {
        duration: root.animationDuration
        easing.type: Easing.OutCubic
      }
    }
  }

  //
  // ── Loading indicator ──
  //

  Rectangle {
    id: loadingIndicator

    anchors.top: contentArea.bottom
    anchors.horizontalCenter: parent.horizontalCenter
    z: 200
    visible: root.loading
    width: loadingRow.width + 24
    height: loadingRow.height + 12
    radius: 8
    color: Qt.alpha(Color.mSurface, 0.9)

    Row {
      id: loadingRow

      anchors.centerIn: parent
      spacing: 10

      Item {
        width: 16
        height: 16
        anchors.verticalCenter: parent.verticalCenter

        Repeater {
          model: 3

          Rectangle {
            property real angle: index * (2 * Math.PI / 3)

            width: 4
            height: 4
            radius: 2
            color: Color.mPrimary
            x: 6 + 5 * Math.cos(angle + spinAnimation.value)
            y: 6 + 5 * Math.sin(angle + spinAnimation.value)

            NumberAnimation on opacity {
              from: 0.3
              to: 1
              duration: 600
              loops: Animation.Infinite
              running: root.loading
            }
          }
        }

        NumberAnimation {
          id: spinAnimation

          property real value: 0

          target: spinAnimation
          property: "value"
          from: 0
          to: 2 * Math.PI
          duration: 1200
          loops: Animation.Infinite
          running: root.loading
        }
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.loadingMessage
        color: Color.mOnSurface
        font.family: Settings.data.ui.fontDefault
        font.pixelSize: 16
      }
    }
  }

  //
  // ── Content area ──
  //

  Item {
    id: contentArea

    anchors.horizontalCenter: parent.horizontalCenter
    y: (parent.height - contentHeight2) / 2
    width: parent.width
    height: contentHeight2

    // ── Top bar ──
    Rectangle {
      id: topBar

      property int sideCount: Math.floor(cardsShown / 2) - 1
      property real centerWidth: contentArea.width / 3
      property real centerX: centerWidth + contentHeight2 * shearFactor * -0.1
      property real stripWidth: cardStripWidth
      property real stripGap: cardSpacing
      property real leftEdge: centerX - stripGap - sideCount * stripWidth - (sideCount - 1) * stripGap
      property real rightEdge: centerX + centerWidth + stripGap + (sideCount - 1) * (stripWidth + stripGap) + stripWidth

      property real entryOffset: parent.width / 2

      Component.onCompleted: {
        entryOffset = 0;
      }

      Behavior on entryOffset {
        NumberAnimation {
          duration: root.animationDuration
          easing.type: Easing.OutBack
          easing.overshoot: 1.0
        }
      }

      anchors.top: parent.top
      color: Color.mSurface
      opacity: .90
      x: leftEdge + entryOffset
      width: rightEdge - leftEdge
      height: topBarHeight
      radius: topBarRadius || 10

      // Left
      Text {
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        text: `${cardStack.currentIndex + 1} / ${root.filteredCount}`
        color: Color.mPrimary
        font {
          family: Settings.data.ui.fontDefault
          pixelSize: 13
          letterSpacing: 0.5
        }
      }

      // Center
      Row {
        anchors.centerIn: parent
        spacing: 3

        Repeater {
          model: [
            {
              key: "all",
              label: "All",
              icon: "\ue5c3",
              hotkey: "A"
            },
            {
              key: "images",
              label: "Images",
              icon: "\ue3f4",
              hotkey: "I"
            },
            {
              key: "videos",
              label: "Videos",
              icon: "\ue04b",
              hotkey: "V"
            }
          ]

          ToolbarButton {
            required property var modelData
            icon: modelData.icon
            label: modelData.label
            hotkey: modelData.hotkey
            active: root.selectedFilter === modelData.key
            onClicked: root.selectedFilter = modelData.key
          }
        }
      }

      // Right
      Row {
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        ToolbarButton {
          icon: "\ue043"
          label: "Shuffle"
          hotkey: "R"
          onClicked: cardStack.randomJump()
        }

        ToolbarButton {
          id: liveBtn
          active: root.livePreview
          accentColor: root.livePreview ? Color.mTertiary : Color.mOnSurfaceVariant
          hotkey: "P"
          onClicked: root.livePreview = !root.livePreview

          Component {
            Row {
              spacing: 5
              PulsingDot {
                pulsing: root.livePreview
              }
              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Live"
                color: liveBtn.accentColor
                font {
                  family: Settings.data.ui.fontDefault
                  pixelSize: 10
                }
              }
            }
          }
        }
      }

      transform: Shear {
        xFactor: shearFactor
      }
    }

    // ── Cards ──

    CardStack {
      id: cardStack

      anchors.fill: parent
      anchors.top: topBar.bottom
      anchors.topMargin: 50

      filteredCount: root.filteredCount
      cardsShown: root.cardsShown
      contentHeight2: root.contentHeight2
      topBarHeight: root.topBarHeight
      cardStripWidth: root.cardStripWidth
      cardSpacing: root.cardSpacing
      shearFactor: root.shearFactor
      livePreview: root.livePreview

      onApplyRequested: (filePath, quit) => root.applyCard(filePath, quit)
      onQuitRequested: root.destroy()
      onFilterChanged: filter => root.selectedFilter = filter
      onLivePreviewToggled: root.livePreview = !root.livePreview

      Repeater {
        id: cardRepeater

        model: root.filteredCount > 0 ? cardStack.visibleCount : 0

        delegate: Item {
          id: cardDelegate

          property int offset: index - cardStack.halfVisible
          property real fractionalSlot: offset + (cardStack.runningIndex - cardStack.animationIndex)
          property int modelIndex: cardStack.wrappedIndex(Math.round(cardStack.runningIndex) + offset)
          property string currentFileName: root.getFileName(modelIndex)
          property bool isVideoFile: root.utils.isVideo(currentFileName)
          property bool isCenter: offset === 0
          property string targetSource: baseSource

          // INFO: Trigger auto updating cards, when thumbnails are created. Otherwise images are not shown until cards
          // are moved.
          property string baseSource: root.filteredCount > 0 ? `file://${cacheDir}/${utils.thumbnailName(currentFileName)}` : ""
          property int lastRevision: -1

          function tryLoadThumbnail() {
            if (img.status === Image.Error || img.status === Image.Null) {
              if (root.thumbnailRevision !== lastRevision) {
                lastRevision = root.thumbnailRevision;
                targetSource = "";
                targetSource = baseSource;
              }
            }
          }

          Component.onCompleted: tryLoadThumbnail()

          Connections {
            target: root
            function onThumbnailRevisionChanged() {
              cardDelegate.tryLoadThumbnail();
            }
          }

          // TODO: Needed for smooth transition, but I am not sure if it could be done without.
          onTargetSourceChanged: {
            if (img.source.toString() !== "" && img.source.toString() !== targetSource) {
              imgOld.source = img.source;
              imgOld.opacity = 1;
              crossfade.restart();
            }
            img.source = targetSource;
          }

          visible: (x + width) > 0 && x < cardStack.width
          width: cardStack.slotToWidth(fractionalSlot)
          height: cardStack.contentHeight
          x: cardStack.slotToX(fractionalSlot)
          y: 0
          z: isCenter ? 100 : cardStack.visibleCount - Math.abs(offset)

          opacity: Math.max(0, Math.min(1, cardStack.halfVisible - Math.abs(fractionalSlot)))

          Item {
            id: imageFrame

            anchors.fill: parent
            clip: true

            // ── Image type ──

            Item {
              id: imgComposite

              width: cardStack.centerWidth
              height: imageFrame.height
              x: (imageFrame.width - cardStack.centerWidth) / 2
              visible: false

              Image {
                id: imgOld

                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                cache: true
                smooth: true
                asynchronous: true
                sourceSize.width: cardStack.centerWidth
                sourceSize.height: parent.height
              }

              Image {
                id: img

                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                cache: true
                smooth: true
                asynchronous: true
                sourceSize.width: cardStack.centerWidth
                sourceSize.height: parent.height
              }
            }

            NumberAnimation {
              id: crossfade

              target: imgOld
              property: "opacity"
              from: 1
              to: 0
              duration: 300
              easing.type: Easing.OutCubic
            }

            Rectangle {
              id: mask

              anchors.fill: parent
              radius: cardRadius
              visible: false
            }

            OpacityMask {
              anchors.fill: parent
              maskSource: mask

              source: ShaderEffectSource {
                sourceItem: imgComposite
                sourceRect: Qt.rect(-imgComposite.x, 0, imageFrame.width, imageFrame.height)
              }
            }

            // ── Video type ──

            Loader {
              id: videoLoader

              property string videoPath: isCenter && cardDelegate.isVideoFile ? root.getFilePath(cardDelegate.modelIndex) : ""
              property bool shouldLoad: false

              anchors.fill: parent
              active: shouldLoad && cardDelegate.currentFileName !== ""
              z: 5

              onVideoPathChanged: {
                shouldLoad = false;
                if (videoPath !== "")
                  videoDelayTimer.restart();
                else
                  videoDelayTimer.stop();
              }

              Timer {
                id: videoDelayTimer
                interval: root.animationDuration
                onTriggered: videoLoader.shouldLoad = true
              }

              sourceComponent: Component {
                Item {
                  id: videoContainer
                  anchors.fill: parent
                  layer.enabled: true
                  opacity: 0

                  MediaPlayer {
                    id: mediaPlayer
                    source: "file://" + videoLoader.videoPath
                    videoOutput: videoOutput
                    loops: MediaPlayer.Infinite
                    Component.onCompleted: play()
                    onPlayingChanged: {
                      if (playing)
                        videoFadeIn.start();
                    }

                    audioOutput: AudioOutput {
                      volume: 0
                    }
                  }

                  VideoOutput {
                    id: videoOutput
                    anchors.fill: parent
                    fillMode: VideoOutput.PreserveAspectCrop
                  }

                  NumberAnimation {
                    id: videoFadeIn
                    target: videoContainer
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: 300
                    easing.type: Easing.OutCubic
                  }

                  layer.effect: OpacityMask {
                    maskSource: Rectangle {
                      width: videoContainer.width
                      height: videoContainer.height
                      radius: cardRadius
                    }
                  }
                }
              }
            }

            Rectangle {
              id: border

              property int trackedModel: cardDelegate.modelIndex

              anchors.fill: parent
              radius: cardRadius
              color: "transparent"
              border.width: isCenter ? 2 : 1
              border.color: isCenter ? Color.mOutline : Color.mSurface
              z: 20
              opacity: 1
              onTrackedModelChanged: {
                if (isCenter)
                  borderFadeIn.restart();
              }

              NumberAnimation {
                id: borderFadeIn

                target: border
                property: "opacity"
                from: 0
                to: 1
                duration: 1000
                easing.type: Easing.OutCubic
              }
            }
          }

          Badge {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 8
            anchors.rightMargin: 8
            visible: cardDelegate.currentFileName !== ""
            icon: cardDelegate.isVideoFile ? "videocam" : "insert_drive_file"
            text: cardDelegate.currentFileName.split('.').pop().toUpperCase()
          }

          Badge {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.topMargin: 8
            anchors.leftMargin: 8
            visible: isCenter
            text: cardDelegate.currentFileName.substring(0, cardDelegate.currentFileName.lastIndexOf('.'))
          }

          Badge {
            anchors.top: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: 10
            textColor: Color.mError
            visible: isCenter && cardDelegate.isVideoFile
            icon: "stop_circle"
            text: "Video wallpaper are comming soon."
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: isCenter ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: {
              if (isCenter)
                applyCard(root.getFilePath(cardDelegate.modelIndex), true);
            }
            onWheel: function (wheel) {
              if (wheel.angleDelta.y > 0)
                cardStack.navigateTo(cardStack.currentIndex - 1);
              else if (wheel.angleDelta.y < 0)
                cardStack.navigateTo(cardStack.currentIndex + 1);
            }
          }
        }
      }

      Behavior on animationIndex {
        NumberAnimation {
          duration: root.animationDuration
          easing.type: Easing.OutBack
          easing.overshoot: 1
        }
      }

      transform: Shear {
        xFactor: shearFactor
      }
    }
  }
}
