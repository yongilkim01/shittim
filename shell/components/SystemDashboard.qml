import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../ui"
import "../services"
import "./dashboard"
import "./control"
import "./launcher"

PanelWindow {
    id: window
    screen: DashboardState.targetScreen
    visible: DashboardState.opened && screen !== null
    anchors { top: true; left: true }
    margins.top: Math.min(Theme.barHeight + Theme.spaceS, Math.max(0, (screen ? screen.height : 0) - 80))
    margins.left: Theme.spaceS
    readonly property real panelScale: Math.max(0.01, Math.min(1, ((screen ? screen.width : 0) - Theme.spaceS * 2) / Theme.dashboardWidth,
        ((screen ? screen.height : 0) - margins.top - Theme.spaceS) / Theme.dashboardHeight))
    implicitWidth: Theme.dashboardWidth * panelScale
    implicitHeight: Theme.dashboardHeight * panelScale
    color: Theme.transparent; exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "shittim-dashboard"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    HyprlandFocusGrab {
        active: window.visible
        windows: DashboardState.anchorWindow !== null ? [window, DashboardState.anchorWindow] : [window]
        onCleared: DashboardState.close()
    }
    onVisibleChanged: if (visible) Qt.callLater(() => content.forceActiveFocus())
    Shortcut { sequence: "Escape"; enabled: window.visible; onActivated: DashboardState.close() }
    DashboardView {
        id: content; anchors.fill: parent; model: DashboardState.model; page: DashboardState.page
        onNavigate: destination => DashboardState.select(destination)
        onCloseRequested: DashboardState.close()
        detailComponent: DashboardState.page === "apps" ? apps : controls
    }
    Component {
        id: apps
        Item {
            LauncherView {
                anchors.centerIn: parent; width: Math.min(Theme.launcherWidth, parent.width); height: Theme.launcherHeight
                model: LauncherState.model; ready: LauncherState.ready; launching: LauncherState.launching; error: LauncherState.error
                iconSource: LauncherState.iconSource
                Component.onCompleted: Qt.callLater(focusSearch)
                onLaunchRequested: appId => LauncherState.launch(appId)
                onRefreshRequested: LauncherState.refresh()
                onCloseRequested: DashboardState.close()
            }
        }
    }
    Component {
        id: controls
        ControlContent {
            embedded: true
            audio: AudioState; network: NetworkState; battery: BatteryState; system: SystemControl; notifications: NotificationState
            page: DashboardState.page === "network" ? "wifi" : DashboardState.page === "display" ? "brightness" : DashboardState.page
            onNavigate: destination => DashboardState.select(destination === "wifi" ? "network" : destination === "brightness" ? "display" : destination)
            onCloseRequested: DashboardState.close()
        }
    }
}
