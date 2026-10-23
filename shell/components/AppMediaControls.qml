import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../ui"
import "../services"
import "./media"

PanelWindow {
    id: window
    screen: MediaState.targetScreen
    visible: MediaState.opened && screen !== null
    anchors { bottom: true; right: true }
    margins.bottom: Theme.spaceS; margins.right: Theme.spaceS
    readonly property real panelScale: Math.max(0.01, Math.min(1,
        ((screen ? screen.width : 0) - Theme.spaceS * 2) / Theme.mediaWidth,
        ((screen ? screen.height : 0) - Theme.barHeight - Theme.spaceS * 2) / Theme.mediaHeight))
    implicitWidth: Theme.mediaWidth * panelScale; implicitHeight: Theme.mediaHeight * panelScale
    color: Theme.transparent; exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "shittim-media"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    HyprlandFocusGrab {
        active: window.visible
        windows: MediaState.anchorWindow !== null ? [window, MediaState.anchorWindow] : [window]
        onCleared: MediaState.close()
    }
    onVisibleChanged: if (visible) Qt.callLater(() => view.forceActiveFocus())
    Shortcut { sequence: "Escape"; enabled: window.visible; onActivated: MediaState.close() }
    MediaView {
        id: view; anchors.fill: parent; active: window.visible; model: MediaState.model; apps: MediaState.apps
        ready: LauncherState.ready; launching: LauncherState.launching
        iconSource: LauncherState.iconSource; isRunning: app => MediaState.running(app)
        error: MediaState.error || LauncherState.dockError || (!LauncherState.ready ? LauncherState.error : "")
        onAppRequested: app => MediaState.activate(app)
        onCloseRequested: MediaState.close()
        onRefreshRequested: LauncherState.refresh()
        onArtworkStateChanged: MediaState.artworkState = artworkState
    }
}
