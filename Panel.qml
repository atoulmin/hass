import QtQuick
import QtQuick.Controls
import Quickshell.Io
import qs.Ui
import qs.Commons
import "Model.js" as Model

// Bar button plus popup panel. Owns the keyboard cursor and the tab selection;
// the service owns the devices and the connection.
Panel {
  id: root
  moduleName: "hass"
  ipcTarget: "hass"
  // We own the target's single IpcHandler, so the methods below can sit
  // alongside the base open/close/toggle.
  manageIpc: false

  readonly property var hass: bar && bar.shell ? bar.shell.serviceFor("hass") : null
  readonly property bool serviceReady: hass !== null
  readonly property string phase: serviceReady ? hass.phase : "idle"

  property string expandedEntityId: ""
  property bool cameraViewerOpen: false
  property string cameraViewerId: ""
  property string cameraViewerTitle: ""
  property string cameraStream: ""

  // One cursor for keyboard and mouse, per the CursorSurface contract.
  // Dormant until a key is pressed.
  property int cursorIndex: 0
  property bool cursorActive: false

  readonly property int rowCount: serviceReady ? hass.rows.count : 0
  readonly property bool hasDevices: serviceReady && hass.hasDevices
  readonly property var tabs: serviceReady ? hass.tabs : []
  readonly property var powerwall: (serviceReady && hass)
    ? hass.powerwall
    : ({ available: false, icon: "", subtitle: "", percentText: "—",
         fraction: 0, charging: false })
  readonly property var cameras: (serviceReady && hass) ? hass.cameraTiles : []
  readonly property bool camerasAvailable: serviceReady && hass && hass.camerasAvailable

  onOpenedChanged: {
    if (root.serviceReady) root.hass.setCameraWatching(opened)
    if (!opened) {
      expandedEntityId = ""
      cursorActive = false
      cursorIndex = 0
      root.closeCameraViewer()
      return
    }
    root.scheduleScrollAssistToEnd()
  }

  Component.onDestruction: {
    if (root.opened && root.serviceReady) root.hass.setCameraWatching(false)
  }

  function cameraSource(entityId) {
    return root.serviceReady ? root.hass.cameraSource(entityId) : ""
  }

  function openCameraViewer(cam) {
    if (!cam || !cam.entityId || !root.serviceReady) return
    var stream = root.hass.cameraStreamUrl(cam.entityId)
    if (!stream) return
    root.cameraViewerId = cam.entityId
    root.cameraViewerTitle = String(cam.title || "").toUpperCase()
    root.cameraStream = stream
    root.cameraViewerOpen = true
  }

  function closeCameraViewer() {
    root.cameraViewerOpen = false
    root.cameraViewerId = ""
    root.cameraViewerTitle = ""
    root.cameraStream = ""
  }

  function submitAssist() {
    if (!root.serviceReady || root.hass.assistBusy) return
    if (root.hass.sendAssist(assistInput.text))
      assistInput.text = ""
    root.scheduleScrollAssistToEnd()
  }

  // Wait a frame so wrapped reply height is known, then ease the thread
  // up to the latest line. The viewport itself is a fixed size.
  property Timer assistScrollSettle: Timer {
    interval: 16
    repeat: false
    onTriggered: root.scrollAssistToEnd()
  }

  property NumberAnimation assistScrollAnim: NumberAnimation {
    target: assistList
    property: "contentY"
    duration: 260
    easing.type: Easing.OutCubic
  }

  function scheduleScrollAssistToEnd() {
    assistScrollSettle.restart()
  }

  function scrollAssistToEnd() {
    if (!assistList) return
    var maxY = Math.max(0, assistList.contentHeight - assistList.height)
    if (Math.abs(assistList.contentY - maxY) < 1) return
    assistScrollAnim.stop()
    assistScrollAnim.from = assistList.contentY
    assistScrollAnim.to = maxY
    assistScrollAnim.start()
  }

  function focusAssistInput() {
    if (assistInput) assistInput.forceActiveFocus()
    root.cursorActive = false
  }

  function focusDevicesFromAssist() {
    assistInput.focus = false
    keyCatcher.forceActiveFocus()
    if (root.rowCount > 0) root.cursorActive = true
  }

  function moveCursor(delta) {
    if (rowCount === 0) return
    cursorIndex = Math.max(0, Math.min(rowCount - 1, cursorIndex + delta))
  }

  function switchTab(delta) {
    if (!serviceReady || tabs.length < 2) return
    var current = 0
    for (var i = 0; i < tabs.length; i++) {
      if (tabs[i].id === hass.effectiveTab) { current = i; break }
    }
    var next = (current + delta + tabs.length) % tabs.length
    hass.setActiveTab(tabs[next].id)
    cursorIndex = 0
    expandedEntityId = ""
  }

  function currentRow() {
    var items = entityRepeater.count
    if (cursorIndex < 0 || cursorIndex >= items) return null
    return entityRepeater.itemAt(cursorIndex)
  }

  function activateCursor() {
    var item = currentRow()
    if (item) item.activate()
  }

  // A separate plugin surface, so it goes through the shell. The popup closes
  // first because the overlay takes exclusive keyboard focus.
  function openSettings(tab) {
    if (!bar || !bar.shell || typeof bar.shell.summon !== "function") return
    close()
    bar.shell.summon("hass", JSON.stringify({ tab: tab || "connection" }))
  }

  function expandCursor() {
    var item = currentRow()
    if (!item || !item.expandable) return
    expandedEntityId = (expandedEntityId === item.entityId) ? "" : item.entityId
  }

  // Colour carries the state, so the button never changes width.
  readonly property string icon: Model.BRAND_ICON

  readonly property color iconColor: {
    var base = bar ? bar.barForeground : Color.foreground
    return phase === "connected" ? base : Qt.darker(base, 1.5)
  }

  // From the bar, as in every built-in panel, not the global defaults.
  readonly property color fg: bar ? bar.foreground : Color.foreground
  readonly property string family: bar ? bar.fontFamily : Style.font.family
  readonly property color dim: Qt.darker(fg, 1.4)
  readonly property color hoverFill: Style.hoverFillFor(fg, Color.accent)
  readonly property color selectedFill: Style.selectedFillFor(fg, Color.accent)

  // The hero says which state; the body below says why. The full error here
  // would duplicate it and truncate at hero width.
  readonly property string heroMeta: {
    if (!serviceReady) return "Service unavailable"
    if (!hass.configured) return "Not connected"
    switch (phase) {
    case "connected":
      return hass.connectionStatus
    case "connecting":
      if (hass.lastError) return "Retrying"
      return hass.activeRoute === "remote" ? "Connecting remotely…" : "Connecting locally…"
    case "error": return "Disconnected"
    default: return "Idle"
    }
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  IpcHandler {
    target: "hass"

    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }

    function status(): string {
      if (!root.serviceReady) return "service: UNREACHABLE"
      return "phase=" + root.hass.phase
        + " configured=" + root.hass.configured
        + " demo=" + root.hass.demoMode
        + " entities=" + Object.keys(root.hass.states).length
        + " rows=" + root.hass.rows.count
        + (root.hass.lastError ? " error=" + root.hass.lastError : "")
    }

    function refresh(): void {
      if (root.serviceReady) root.hass.refresh()
    }

    //   bind = SUPER, L, exec, omarchy-shell hass toggleEntity light.desk
    // Goes through the row's own primary action, so a lock locks and a scene
    // activates rather than being reported as not toggleable.
    function toggleEntity(entityId: string): string {
      if (!root.serviceReady) return "service unavailable"
      if (!root.hass.entityFor(entityId)) return "unknown entity " + entityId
      return root.hass.activateEntity(entityId)
        ? "ok" : (root.hass.lastError || "entity isn't toggleable")
    }

    function activate(entityId: string): string {
      if (!root.serviceReady) return "service unavailable"
      if (!root.hass.entityFor(entityId)) return "unknown entity " + entityId
      return root.hass.activateScene(entityId)
        ? "ok" : (root.hass.lastError || "entity isn't activatable")
    }

    //   bind = SUPER, T, exec, omarchy-shell hass expand climate.hallway
    function expand(entityId: string): string {
      if (!root.serviceReady) return "service unavailable"
      var entity = root.hass.entityFor(entityId)
      if (!entity) return "unknown entity " + entityId
      if (!Model.isExpandable(entity)) return "entity has no expandable controls"
      root.expandedEntityId = entityId
      root.open()
      return "ok"
    }

    function favorite(entityId: string): string {
      if (!root.serviceReady) return "service unavailable"
      if (!root.hass.entityFor(entityId)) return "unknown entity " + entityId
      // Read before the write: the new state lands only after applyConfig.
      var was = root.hass.isFavorite(entityId)
      root.hass.toggleFavorite(entityId)
      return was ? "removed" : "added"
    }

    // Two no-arg calls, not one taking a tab: IpcHandler makes declared
    // arguments mandatory, so `settings` alone would refuse to run.
    function settings(): void { root.openSettings("connection") }
    function devices(): void { root.openSettings("entities") }

    // Attributes are redacted, not dumped whole. A camera carries a live
    // `access_token`, a device_tracker carries GPS coordinates, and
    // `entity_picture` is a signed URL — this output is what people paste
    // into bug reports, so it must not be the easy way to leak any of them.
    function entityState(entityId: string): string {
      if (!root.serviceReady) return "service unavailable"
      var entity = root.hass.entityFor(entityId)
      if (!entity) return "unknown entity " + entityId
      return entity.state + " " + JSON.stringify(Model.redactAttributes(entity))
    }

    function assist(text: string): string {
      if (!root.serviceReady) return "service unavailable"
      root.open()
      return root.hass.sendAssist(text)
        ? "ok" : (root.hass.lastError || "failed")
    }

    function assistClear(): void {
      if (root.serviceReady) root.hass.resetAssist(true)
    }
  }

  Process {
    id: cameraPlayer
    command: [
      "mpv",
      "--no-audio",
      "--mute=yes",
      "--volume=0",
      "--force-window=immediate",
      "--keep-open=no",
      "--osc=no",
      "--osd-level=0",
      "--no-border",
      "--title=omarchy-hass-camera",
      "--hwdec=auto-safe",
      "--profile=low-latency",
      "--untimed=yes",
      "--cache=no",
      "--input-conf=" + (root.serviceReady ? root.hass.pluginDir : "") + "/mpv-preview.conf",
      root.cameraStream
    ]
    running: root.cameraViewerOpen && root.cameraStream !== ""
    onExited: if (root.cameraViewerOpen) root.closeCameraViewer()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.icon
    foreground: root.iconColor
    // `active` paints with the bar's urgent colour.
    active: root.phase === "error"
    onPressed: root.toggle()
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    // Hide the overlay while the stream is open so mpv isn't buried under
    // the layer-shell panel on short screens.
    open: root.opened && !root.cameraViewerOpen
    focusTarget: (root.serviceReady && root.hass && root.hass.connected)
      ? assistInput : keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: assistInput.activeFocus || root.cameraViewerOpen
      onCloseRequested: {
        if (root.cameraViewerOpen) root.closeCameraViewer()
        else root.close()
      }
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onMoveRequested: function(dx, dy) {
        if (dy < 0 && (!root.cursorActive || root.cursorIndex === 0)
            && root.serviceReady && root.hass.connected) {
          root.focusAssistInput()
          return
        }
        // The first key press only wakes the cursor.
        if (!root.cursorActive) { root.cursorActive = true; return }
        if (dy !== 0) root.moveCursor(dy)
        else if (dx !== 0) root.switchTab(dx)
      }
      onActivateRequested: if (root.cursorActive) root.activateCursor()
      onTextKey: function(key) {
        var lower = String(key).toLowerCase()
        if (key === "/" && root.serviceReady && root.hass.connected) {
          root.focusAssistInput()
          return
        }
        if (lower === "r" && root.serviceReady) root.hass.refresh()
        else if (lower === "e" && root.cursorActive) root.expandCursor()
        else if (lower === "s") root.openSettings("connection")
      }

      Column {
        id: column
        anchors.fill: parent
        spacing: Style.spacing.panelGap

        // ---------- hero: mark · title · status ----------
        PanelHero {
          width: parent.width
          title: "Home Assistant"
          meta: root.heroMeta
          foreground: root.fg
          fontFamily: root.family
          iconOpacity: root.phase === "connected" ? 1.0 : 0.55

          iconComponent: Text {
            textFormat: Text.PlainText
            text: Model.BRAND_ICON
            color: root.phase === "error" ? Color.urgent : root.fg
            font.family: root.family
            font.pixelSize: Style.font.display
          }

          trailingControl: Component {
            PanelActionButton {
              iconText: "󰒓"                  // md-cog
              tooltipText: "Settings"
              foreground: Qt.darker(root.fg, 1.4)
              fontFamily: root.family
              onClicked: root.openSettings("connection")
            }
          }
        }

        PanelSeparator { width: parent.width; foreground: root.fg }

        // ---------- Assist ----------
        Column {
          id: assistColumn
          width: parent.width
          visible: root.serviceReady && root.hass.connected
          spacing: Style.spacing.panelGap

          Item {
            width: parent.width
            height: Style.space(50)

            ListView {
              id: assistList
              anchors.fill: parent
              clip: true
              spacing: Style.spacing.lg
              boundsBehavior: Flickable.StopAtBounds
              boundsMovement: Flickable.StopAtBounds
              interactive: true
              model: root.serviceReady ? root.hass.assistMessages : null
              bottomMargin: (root.serviceReady && root.hass.assistBusy)
                ? Style.font.caption + Style.spacing.sm : 0
              onCountChanged: root.scheduleScrollAssistToEnd()
              onContentHeightChanged: root.scheduleScrollAssistToEnd()
              onMovementStarted: assistScrollAnim.stop()

              ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
              }

              delegate: Column {
                required property int index
                required property string speaker
                required property string body

                width: assistList.width
                spacing: Style.spacing.hairline
                opacity: 0

                Component.onCompleted: assistFadeIn.start()

                NumberAnimation on opacity {
                  id: assistFadeIn
                  from: 0
                  to: 1
                  duration: 220
                  easing.type: Easing.OutCubic
                }

                Text {
                  textFormat: Text.PlainText
                  text: speaker === "user" ? "You" : "Assist"
                  color: speaker === "error" ? Color.urgent : root.dim
                  font.family: root.family
                  font.pixelSize: Style.font.caption
                }

                Text {
                  textFormat: Text.PlainText
                  width: parent.width
                  text: body
                  wrapMode: Text.WordWrap
                  color: speaker === "error" ? Color.urgent : root.fg
                  font.family: root.family
                  font.pixelSize: Style.font.bodySmall
                }
              }
            }

            Text {
              id: assistGreeting
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText
              text: "How can I assist you?"
              wrapMode: Text.WordWrap
              color: root.fg
              font.family: root.family
              font.pixelSize: Style.font.bodySmall
              visible: root.opened && root.serviceReady && root.hass.connected
                && assistList.count === 0 && !root.hass.assistBusy
              opacity: 0

              onVisibleChanged: {
                assistGreetingDelay.stop()
                assistGreetingFade.stop()
                opacity = 0
                if (visible) assistGreetingDelay.start()
              }

              Timer {
                id: assistGreetingDelay
                interval: 1000
                repeat: false
                onTriggered: assistGreetingFade.start()
              }

              NumberAnimation {
                id: assistGreetingFade
                target: assistGreeting
                property: "opacity"
                from: 0
                to: 1
                duration: 280
                easing.type: Easing.OutCubic
              }
            }

            Text {
              visible: root.serviceReady && root.hass.assistBusy
              anchors.left: parent.left
              anchors.bottom: parent.bottom
              textFormat: Text.PlainText
              text: "Assist is thinking…"
              color: root.dim
              font.family: root.family
              font.pixelSize: Style.font.caption
            }
          }

          TextField {
            id: assistInput
            width: parent.width
            foreground: root.fg
            placeholderText: "Ask Assist…"
            onAccepted: root.submitAssist()
            Keys.onEscapePressed: root.close()
            Keys.onDownPressed: root.focusDevicesFromAssist()
          }
        }

        PanelSeparator {
          width: parent.width
          visible: assistColumn.visible
          foreground: root.fg
        }

        // ---------- Cameras ----------
        Column {
          id: cameraColumn
          width: parent.width
          visible: root.opened && root.serviceReady && root.hass.connected
            && root.camerasAvailable
          spacing: Style.spacing.panelGap

          PanelSectionHeader {
            width: parent.width
            text: "CAMERAS"
            foreground: root.fg
            fontFamily: root.family
          }

          Row {
            id: cameraRow
            width: parent.width
            spacing: Style.spacing.sm

            Repeater {
              model: root.cameras.length
              delegate: Column {
                required property int index
                readonly property var cam: root.cameras[index] || ({})

                width: (cameraRow.width - cameraRow.spacing * Math.max(0, root.cameras.length - 1))
                  / Math.max(1, root.cameras.length)
                spacing: Style.spacing.xxs

                CameraThumb {
                  width: parent.width
                  height: Math.round(width * 2 / 3)
                  fill: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.08)
                  frame: root.cameraSource(cam.entityId || "")

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openCameraViewer(cam)
                  }
                }

                Text {
                  textFormat: Text.PlainText
                  width: parent.width
                  text: (cam.title || "").toUpperCase()
                  color: root.dim
                  font.family: root.family
                  font.pixelSize: Style.font.caption
                  horizontalAlignment: Text.AlignHCenter
                  elide: Text.ElideRight
                }
              }
            }
          }
        }

        PanelSeparator {
          width: parent.width
          visible: cameraColumn.visible
          foreground: root.fg
        }

        // ---------- Powerwall ----------
        Column {
          id: powerwallColumn
          width: parent.width
          visible: root.serviceReady && root.hass.connected && root.powerwall.available
          spacing: Style.spacing.panelGap

          PanelSectionHeader {
            width: parent.width
            text: "POWERWALL"
            foreground: root.fg
            fontFamily: root.family
          }

          Item {
            width: parent.width
            implicitHeight: Math.max(pwGlyph.implicitHeight, pwLabels.implicitHeight,
                                     pwPercent.implicitHeight)

            Text {
              id: pwGlyph
              textFormat: Text.PlainText
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: root.powerwall.icon
              color: root.fg
              font.family: root.family
              font.pixelSize: Style.font.heading
            }

            Column {
              id: pwLabels
              anchors.left: pwGlyph.right
              anchors.leftMargin: Style.spacing.xl
              anchors.right: pwPercent.left
              anchors.rightMargin: Style.spacing.lg
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.spacing.xxs

              Text {
                textFormat: Text.PlainText
                width: parent.width
                text: "Powerwall"
                color: root.fg
                font.family: root.family
                font.pixelSize: Style.font.body
                elide: Text.ElideRight
              }

              Text {
                textFormat: Text.PlainText
                width: parent.width
                text: root.powerwall.subtitle
                color: root.dim
                font.family: root.family
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
              }
            }

            Text {
              id: pwPercent
              textFormat: Text.PlainText
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: root.powerwall.percentText
              color: root.fg
              font.family: root.family
              font.pixelSize: Style.font.heading
            }
          }
        }

        PanelSeparator {
          width: parent.width
          visible: powerwallColumn.visible
          foreground: root.fg
        }

        // ---------- area tabs ----------
        // ButtonGroup is a Row and does not wrap, so it scrolls instead of
        // pushing chips off the panel edge.
        ScrollView {
          width: parent.width
          visible: root.tabs.length > 1 && root.hasDevices
          implicitHeight: tabGroup.implicitHeight
          clip: true
          ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
          ScrollBar.vertical.policy: ScrollBar.AlwaysOff

        ButtonGroup {
          id: tabGroup
          // The panel owns the cursor, so this is not its own Tab stop.
          focusable: false
          foreground: root.fg
          fontFamily: root.family
          fontSize: Style.font.caption
          options: root.tabs.map(function(tab) {
            return { value: tab.id, label: tab.title }
          })
          value: root.serviceReady ? root.hass.effectiveTab : "favorites"
          onChanged: function(value) {
            if (!root.serviceReady) return
            root.hass.setActiveTab(value)
            root.cursorIndex = 0
            root.expandedEntityId = ""
          }
        }
        }

        // With tabs on screen the group already names the section.
        PanelSectionHeader {
          width: parent.width
          visible: root.tabs.length <= 1 && root.rowCount > 0 && root.hasDevices
          text: "DEVICES"
          foreground: root.fg
          fontFamily: root.family
        }

        // ---------- body ----------
        Column {
          width: parent.width
          visible: !root.serviceReady || !root.hass.configured
          spacing: Style.spacing.xl

          Text {
            textFormat: Text.PlainText
            width: parent.width
            text: !root.serviceReady
              ? "The Home Assistant service did not start."
              : "Connect to your Home Assistant, or try the demo house first."
            wrapMode: Text.WordWrap
            color: root.dim
            font.family: root.family
            font.pixelSize: Style.font.bodySmall
          }

          Button {
            visible: root.serviceReady
            bordered: true
            text: "Open settings"
            foreground: root.fg
            fontFamily: root.family
            onClicked: root.openSettings("connection")
          }
        }

        // Configured but holding nothing. Rendering favorites anyway gives a
        // column of nameless "Unavailable" rows and no way out.
        Column {
          width: parent.width
          visible: root.serviceReady && root.hass.configured && !root.hasDevices
          spacing: Style.spacing.xl

          Text {
            textFormat: Text.PlainText
            width: parent.width
            // The credential layer states the condition; the way out is named
            // here, where settings is somewhere else. The settings overlay
            // shows the same lastError without this, since telling a reader
            // who is already in settings to open settings is noise.
            text: {
              if (root.phase !== "connecting" && root.phase !== "error")
                return "Not connected."
              var reason = root.hass.lastError || "Cannot reach Home Assistant."
              return root.hass.lastErrorKind === "credential"
                ? reason + " Open settings to connect."
                : reason
            }
            wrapMode: Text.WordWrap
            color: root.dim
            font.family: root.family
            font.pixelSize: Style.font.bodySmall
          }

          Row {
            spacing: Style.spacing.lg

            Button {
              bordered: true
              text: "Settings"
              foreground: root.fg
              fontFamily: root.family
              onClicked: root.openSettings("connection")
            }

            Button {
              visible: root.phase === "idle"
              bordered: true
              text: "Retry"
              foreground: root.fg
              fontFamily: root.family
              onClicked: root.hass.retryConnection()
            }
          }
        }

        Column {
          width: parent.width
          visible: root.serviceReady && root.hass.configured
            && root.hasDevices && root.rowCount === 0
          spacing: Style.spacing.xl

          Text {
            textFormat: Text.PlainText
            width: parent.width
            text: "No devices picked yet."
            wrapMode: Text.WordWrap
            color: root.dim
            font.family: root.family
            font.pixelSize: Style.font.bodySmall
          }

          Button {
            bordered: true
            text: "Choose devices"
            foreground: root.fg
            fontFamily: root.family
            onClicked: root.openSettings("entities")
          }
        }

        ScrollView {
          id: listScroller
          visible: root.serviceReady && root.rowCount > 0 && root.hasDevices
          width: parent.width
          implicitHeight: Math.min(rowsColumn.implicitHeight, Style.space(420))
          clip: true
          ScrollBar.vertical.policy: ScrollBar.AsNeeded

          Column {
            id: rowsColumn
            width: listScroller.availableWidth
            spacing: Style.spacing.hairline

            Repeater {
              id: entityRepeater
              model: root.serviceReady ? root.hass.rows : null
              delegate: EntityRow {
                // EntityRow declares required properties, which puts the
                // delegate in required-properties mode: Qt then stops
                // injecting `index` as a context property and it has to be
                // asked for by name. Without this the cursor silently never
                // matches a row — keyboard navigation and hover highlighting
                // both die, with nothing but a log warning to show for it.
                required property int index

                width: rowsColumn.width
                hass: root.hass
                bar: root.bar
                fill: root.hoverFill
                currentFill: root.selectedFill
                showIcon: root.serviceReady ? root.hass.showEntityIcons : true
                reserveExpandSlot: root.serviceReady ? root.hass.rowsHaveExpandable : false
                hasCursor: root.cursorActive && root.cursorIndex === index
                expanded: root.expandedEntityId === entityId
                onCursorRequested: {
                  root.cursorActive = true
                  root.cursorIndex = index
                }
                onExpandToggled: {
                  // One at a time: this is a popup, not a dashboard.
                  root.expandedEntityId = (root.expandedEntityId === entityId)
                    ? "" : entityId
                }
              }
            }
          }
        }
      }
    }
  }
}
