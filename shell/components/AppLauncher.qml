import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../ui"
import "../services"
import "./launcher"

PanelWindow {
    id: window
    screen: LauncherState.targetScreen
    visible: LauncherState.opened && LauncherState.targetScreen !== null
    implicitWidth: Math.max(1, Math.min(Theme.launcherWidth, (screen ? screen.width : 0) - Theme.spaceL * 2))
    implicitHeight: Math.max(1, Math.min(Theme.launcherHeight * implicitWidth / Theme.launcherWidth, (screen ? screen.height : 0) - Theme.spaceL * 2))
    exclusionMode: ExclusionMode.Ignore
    color: Theme.transparent
    WlrLayershell.namespace: "shittim-launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus:input.keyboardFocus
    PanelInput { id:input;window:window;session:LauncherState.panelSession }
    onVisibleChanged: if (visible) Qt.callLater(() => view.focusSearch())
    LauncherView {
        id: view; anchors.fill: parent
        model: LauncherState.model; ready: LauncherState.ready
        launching: LauncherState.launching; error: LauncherState.error
        iconSource: app => LauncherState.iconSource(app)
        onLaunchRequested: appId => LauncherState.launch(appId)
        isPinned: appId => LauncherState.dockFavorites.indexOf(appId)>=0
        onPinRequested: appId => LauncherState.dockAction(LauncherState.dockFavorites.indexOf(appId)>=0 ? "unpin" : "pin",appId)
        onCloseRequested: LauncherState.close()
        onRefreshRequested: LauncherState.refresh()
    }
}
