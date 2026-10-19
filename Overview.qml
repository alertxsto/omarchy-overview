import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "OverviewLogic.js" as Logic

Item {
  id: root
  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null
  property bool opened: false
  property var monitor: null
  property var targetScreen: null
  property int firstWorkspace: 1
  property int cursorWorkspace: 1
  readonly property int rows: 2
  readonly property int columns: 5
  readonly property int workspacesShown: rows * columns
  readonly property int gap: Style.space(6)
  readonly property int padding: Style.space(14)
  readonly property real screenW: targetScreen ? targetScreen.width : 1920
  readonly property real screenH: targetScreen ? targetScreen.height : 1080
  readonly property real cardWidth: Math.min(screenW * 0.9, screenW - Style.gapsOut * 4)
  readonly property real cellWidth: (cardWidth - padding * 2 - gap * (columns - 1)) / columns
  readonly property real cellHeight: Math.min(cellWidth * screenH / screenW,
    (screenH - padding * 4 - gap * (rows - 1)) / rows)
  readonly property real cardHeight: padding * 2 + cellHeight * rows + gap * (rows - 1)
  readonly property int activeWorkspaceId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1
  readonly property color foreground: Color.menu.text
  readonly property color activeBorder: Color.menu.selectedText
  readonly property var borderSpec: Border.surfaceSpec("menu", "border", Color.menu.border, Math.max(1, Style.normalBorderWidth))
  readonly property var fullscreenByWorkspace: {
    var result = ({})
    if (!opened) return result
    var values = Hyprland.toplevels.values
    for (var i = 0; i < values.length; i++) {
      var window = values[i]
      var ipc = window.lastIpcObject
      if (!window.workspace || !ipc || ipc.fullscreen !== 2 || ipc.hidden || ipc.mapped === false) continue
      var key = String(window.workspace.id)
      var previous = result[key]
      if (!previous || ipc.focusHistoryID < previous.lastIpcObject.focusHistoryID) result[key] = window
    }
    return result
  }

  property string dragAddress: ""
  property int dragSourceWorkspace: -1
  property int dropWorkspace: -1
  property point dragPoint: Qt.point(0, 0)
  property point dragOrigin: Qt.point(0, 0)
  property point dragGrab: Qt.point(0, 0)
  property bool dragMoved: false

  function resetDrag() {
    dragAddress = ""
    dragSourceWorkspace = -1
    dropWorkspace = -1
    dragMoved = false
  }

  function open(payloadJson) {
    if (opened) return
    monitor = Hyprland.focusedMonitor
    var screens = Quickshell.screens
    targetScreen = screens.find(function(screen) { return monitor && screen.name === monitor.name }) || screens[0]
    firstWorkspace = Math.max(0, Math.floor((Math.max(1, activeWorkspaceId) - 1) / workspacesShown)) * workspacesShown + 1
    cursorWorkspace = Math.max(firstWorkspace, Math.min(firstWorkspace + workspacesShown - 1, activeWorkspaceId))
    resetDrag()
    Hyprland.refreshMonitors()
    Hyprland.refreshToplevels()
    opened = true
  }

  function close() {
    opened = false
    refreshTimer.stop()
    resetDrag()
  }

  function dismiss() {
    close()
    if (shell && typeof shell.hide === "function")
      shell.hide((manifest && manifest.id) || "alertxsto.overview")
  }

  function focusWorkspace(ws) {
    dismiss()
    Hyprland.dispatch('hl.dsp.focus({ workspace = ' + ws + ' })')
  }

  function focusWindow(address) {
    dismiss()
    Hyprland.dispatch('hl.dsp.focus({ window = "address:' + address + '" })')
  }

  function moveToWorkspace(arg) {
    var parts = String(arg || "").split(",")
    if (parts.length !== 2) return "expected address,workspace"
    var address = parts[0].trim()
    var ws = parseInt(parts[1], 10)
    if (!address || !isFinite(ws)) return "expected address,workspace"
    moveWindowToWorkspace(address, ws)
    return "ok"
  }

  function moveWindowToWorkspace(address, ws) {
    Hyprland.dispatch('hl.dsp.window.move({ workspace = ' + ws + ', follow = false, window = "address:' + address + '" })')
    // The move event updates typed workspace membership. Its trailing refresh
    // fetches the new layout; rereading lastIpcObject does not fetch geometry.
  }

  function moveCursor(dx, dy) {
    var slot = cursorWorkspace - firstWorkspace
    var col = Math.max(0, Math.min(columns - 1, slot % columns + dx))
    var row = Math.max(0, Math.min(rows - 1, Math.floor(slot / columns) + dy))
    cursorWorkspace = firstWorkspace + row * columns + col
  }

  function workspaceAtPoint(x, y) {
    return Logic.workspaceAtPoint(x, y, cellWidth, cellHeight, gap, columns, rows, firstWorkspace)
  }

  // Coalesce compositor layout events, not frame-by-frame snapshot polling.
  Connections {
    target: Hyprland
    enabled: root.opened
    function onRawEvent(event) {
      switch (event.name) {
      case "openwindow": case "closewindow": case "movewindowv2":
      case "fullscreen": case "changefloatingmode": case "moveactive":
      case "resizeactive": case "configreloaded": case "monitoradded":
      case "monitorremoved": case "moveworkspacev2":
        refreshTimer.restart()
        break
      }
    }
  }

  Timer {
    id: refreshTimer
    interval: 32
    onTriggered: {
      if (!root.opened) return
      Hyprland.refreshMonitors()
      Hyprland.refreshToplevels()
    }
  }

  // Keep only this small controller mounted. Closing destroys the window,
  // delegates, capture swapchains and scenegraph texture owners together.
  Loader {
    id: surface
    active: root.opened
    sourceComponent: Component {
      PanelWindow {
        id: panel
        screen: root.targetScreen
        visible: true
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        WlrLayershell.namespace: "omarchy-overview"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        exclusionMode: ExclusionMode.Ignore

        Rectangle {
          anchors.fill: parent
          color: Color.menu.scrim
          MouseArea { anchors.fill: parent; onClicked: root.dismiss() }
        }

        BorderSurface {
          anchors.centerIn: parent
          width: root.cardWidth
          height: root.cardHeight
          radius: Style.cornerRadius
          color: Color.menu.background
          borderSpec: root.borderSpec
          MouseArea { anchors.fill: parent }

          Item {
            id: grid
            anchors.fill: parent
            anchors.margins: root.padding
            focus: true
            Component.onCompleted: Qt.callLater(function() { if (root.opened) grid.forceActiveFocus() })

            Keys.onPressed: function(event) {
              event.accepted = true
              if (event.key === Qt.Key_Escape) root.dismiss()
              else if (event.key === Qt.Key_Left) root.moveCursor(-1, 0)
              else if (event.key === Qt.Key_Right) root.moveCursor(1, 0)
              else if (event.key === Qt.Key_Up) root.moveCursor(0, -1)
              else if (event.key === Qt.Key_Down) root.moveCursor(0, 1)
              else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.focusWorkspace(root.cursorWorkspace)
              else {
                var ws = Logic.workspaceForDigit(event.text || "", root.firstWorkspace, root.workspacesShown)
                if (ws > 0) root.focusWorkspace(ws)
                else event.accepted = false
              }
            }

            Repeater {
              model: root.workspacesShown
              Rectangle {
                required property int index
                readonly property int wsId: root.firstWorkspace + index
                x: (index % root.columns) * (root.cellWidth + root.gap)
                y: Math.floor(index / root.columns) * (root.cellHeight + root.gap)
                width: root.cellWidth
                height: root.cellHeight
                radius: Math.min(Style.cornerRadius + Style.space(2), 18)
                color: Util.alpha(root.foreground, root.dropWorkspace === wsId ? 0.13 : 0.06)
                border.width: wsId === root.activeWorkspaceId || wsId === root.cursorWorkspace || wsId === root.dropWorkspace ? Math.max(1, Style.normalBorderWidth) : 0
                border.color: wsId === root.activeWorkspaceId || wsId === root.dropWorkspace ? root.activeBorder : Color.menu.border
                Text {
                  anchors.centerIn: parent
                  text: parent.wsId
                  font.family: Style.font.menuFamily
                  font.pixelSize: Math.round(parent.height * 0.62)
                  font.weight: Font.DemiBold
                  color: Util.alpha(root.foreground, 0.13)
                  textFormat: Text.PlainText
                }
              }
            }

            // Native ObjectModel keeps a delegate and capture stream stable
            // across workspace moves; geometry is a per-object binding.
            Repeater {
              id: windows
              model: Hyprland.toplevels
              Item {
                id: slot
                required property var modelData
                readonly property var ipc: modelData.lastIpcObject || ({})
                readonly property int wsId: modelData.workspace ? modelData.workspace.id : -1
                readonly property string address: "0x" + modelData.address
                readonly property bool eligible: wsId >= root.firstWorkspace && wsId < root.firstWorkspace + root.workspacesShown
                  && ipc.mapped !== false && ipc.hidden !== true
                readonly property var coveringWindow: root.fullscreenByWorkspace[String(wsId)]
                readonly property bool occluded: !!coveringWindow && coveringWindow !== modelData && !Logic.visibleOverFullscreen(ipc)
                readonly property var sourceMonitor: modelData.monitor ? modelData.monitor.lastIpcObject
                  : (root.monitor ? root.monitor.lastIpcObject : ({ width: root.screenW, height: root.screenH }))
                readonly property var rect: Logic.windowRect(ipc, sourceMonitor, root.cellWidth, root.cellHeight)
                readonly property bool dragging: root.dragAddress === address
                readonly property real restX: x + rect.x
                readonly property real restY: y + rect.y
                readonly property int stacking: Logic.stacking(ipc, modelData === Hyprland.activeToplevel)
                x: ((wsId - root.firstWorkspace) % root.columns) * (root.cellWidth + root.gap)
                y: Math.floor((wsId - root.firstWorkspace) / root.columns) * (root.cellHeight + root.gap)
                width: root.cellWidth
                height: root.cellHeight
                visible: eligible && !occluded
                clip: !dragging
                z: dragging ? 100 : stacking
                Component.onDestruction: { if (root.dragAddress === address) root.resetDrag() }

                Item {
                  x: slot.dragging && root.dragMoved ? root.dragPoint.x - slot.x - root.dragGrab.x : slot.rect.x
                  y: slot.dragging && root.dragMoved ? root.dragPoint.y - slot.y - root.dragGrab.y : slot.rect.y
                  width: slot.rect.width
                  height: slot.rect.height
                  Rectangle {
                    anchors.fill: parent
                    color: Color.background
                    border.width: Math.max(1, Style.normalBorderWidth)
                    border.color: slot.dragging ? root.activeBorder : (pointer.hoveredWindow === slot ? Color.menu.border : Util.alpha(root.foreground, 0.22))
                  }
                  Loader {
                    anchors.fill: parent
                    active: root.opened && slot.visible && width > 0 && height > 0
                    sourceComponent: ScreencopyView {
                      captureSource: root.opened && slot.visible ? slot.modelData.wayland : null
                      live: true
                      paintCursor: false
                      Image {
                        anchors.centerIn: parent
                        width: Math.min(parent.width, parent.height) * 0.42
                        height: width
                        source: Quickshell.iconPath(slot.ipc.class || "", true)
                        sourceSize: Qt.size(width, height)
                        visible: !parent.hasContent && source.toString().length > 0
                        asynchronous: true
                        fillMode: Image.PreserveAspectFit
                      }
                    }
                  }
                }
              }
            }

            // One stationary input surface: moving a thumbnail never changes
            // the coordinate system used to measure pointer movement.
            MouseArea {
              id: pointer
              anchors.fill: parent
              z: 200
              acceptedButtons: Qt.LeftButton | Qt.MiddleButton
              preventStealing: true
              hoverEnabled: true
              cursorShape: hoveredWindow ? Qt.PointingHandCursor : Qt.ArrowCursor
              property var hoveredWindow: null
              property bool pressedOnWindow: false
              property var pressedWindow: null

              function windowAt(px, py) {
                var best = null
                var bestZ = -1
                for (var i = 0; i < windows.count; i++) {
                  var item = windows.itemAt(i)
                  if (!item || !item.visible || root.workspaceAtPoint(px, py) !== item.wsId) continue
                  if (px >= item.restX && py >= item.restY && px < item.restX + item.rect.width && py < item.restY + item.rect.height && item.stacking >= bestZ) {
                    best = item
                    bestZ = item.stacking
                  }
                }
                return best
              }

              onPressed: function(event) {
                root.resetDrag()
                pressedWindow = windowAt(event.x, event.y)
                pressedOnWindow = pressedWindow !== null
                root.dragOrigin = Qt.point(event.x, event.y)
                root.dragPoint = root.dragOrigin
                if (pressedWindow && event.button === Qt.LeftButton) {
                  root.dragGrab = Qt.point(event.x - pressedWindow.restX, event.y - pressedWindow.restY)
                  root.dragSourceWorkspace = pressedWindow.wsId
                  root.dragAddress = pressedWindow.address
                }
              }
              onPositionChanged: function(event) {
                hoveredWindow = windowAt(event.x, event.y)
                if (!pressed || root.dragAddress === "") return
                if (!root.dragMoved && Math.hypot(event.x - root.dragOrigin.x, event.y - root.dragOrigin.y) < 6) return
                root.dragMoved = true
                root.dragPoint = Qt.point(event.x, event.y)
                root.dropWorkspace = root.workspaceAtPoint(event.x, event.y)
              }
              onReleased: function(event) {
                var address = root.dragAddress
                var source = root.dragSourceWorkspace
                var moved = root.dragMoved
                var target = root.workspaceAtPoint(event.x, event.y)
                var hit = windowAt(event.x, event.y)
                if (moved) {
                  if (target > 0 && target !== source) root.moveWindowToWorkspace(address, target)
                } else if (hit && hit === pressedWindow) {
                  if (event.button === Qt.MiddleButton)
                    Hyprland.dispatch('hl.dsp.window.close({ window = "address:' + hit.address + '" })')
                  else root.focusWindow(hit.address)
                } else if (!pressedOnWindow && event.button === Qt.LeftButton && target > 0
                           && target === root.workspaceAtPoint(root.dragOrigin.x, root.dragOrigin.y)) root.focusWorkspace(target)
                pressedWindow = null
                root.resetDrag()
              }
              onCanceled: { pressedWindow = null; root.resetDrag() }
              onExited: hoveredWindow = null
              PanelToolTip {
                visible: pointer.hoveredWindow !== null && root.dragAddress === ""
                text: pointer.hoveredWindow ? pointer.hoveredWindow.modelData.title : ""
              }
            }
          }
        }
      }
    }
  }
}
