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
    visible: MediaState.opened && MediaState.targetScreen !== null
    anchors { bottom: true; right: true }
    margins.bottom: Theme.spaceS; margins.right: Theme.spaceS
    readonly property real panelScale: Math.max(0.01, Math.min(1,
        ((screen ? screen.width : 0) - Theme.spaceS * 2) / Theme.mediaWidth,
        ((screen ? screen.height : 0) - Theme.barHeight - Theme.spaceS * 2) / Theme.mediaHeight))
    implicitWidth: Theme.mediaWidth * panelScale; implicitHeight: Theme.mediaHeight * panelScale
    color: Theme.transparent; exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "shittim-media"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus:input.keyboardFocus
    PanelInput { id:input;window:window;session:MediaState.panelSession }
    onVisibleChanged: if (visible) Qt.callLater(() => view.forceActiveFocus())
    MediaView {
        id: view; anchors.fill: parent; active: window.visible; model: MediaState.model; apps: ApplicationsState.apps
        ready: LauncherState.ready; launching: LauncherState.launching
        iconSource: LauncherState.iconSource; isRunning: app => ApplicationsState.running(app)
        isActiveApp: app => ApplicationsState.matches(app).some(window => window.activated)
        error: ApplicationsState.error || LauncherState.dockError || (!LauncherState.ready ? LauncherState.error : "")
        onAppRequested: app => ApplicationsState.activate(app)
        onAppWindowsRequested: app => {
            const matches = ApplicationsState.matches(app)
            if (matches.length) WindowState.show(matches.map(window => window.address), 0, window.screen)
        }
        onCloseRequested: MediaState.close()
        onRefreshRequested: LauncherState.refresh()
        onArtworkStateChanged: MediaState.artworkState = artworkState
    }
}
