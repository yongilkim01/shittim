import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../ui"
import "../services"
import "./dashboard"
import "./control"
import "./launcher"
import "../ui/AssetPaths.js" as AssetPaths

PanelWindow {
    id: window
    screen: DashboardState.targetScreen
    visible: DashboardState.opened && DashboardState.targetScreen !== null
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
    WlrLayershell.keyboardFocus:input.keyboardFocus
    PanelInput { id:input;window:window;session:DashboardState.panelSession }
    onVisibleChanged: if (visible) Qt.callLater(() => content.forceActiveFocus())
    DashboardView {
        id: content; anchors.fill: parent; model: DashboardState.model; page: DashboardState.page
        onNavigate: destination => DashboardState.select(destination)
        onCloseRequested: DashboardState.close()
        detailComponent: DashboardState.page === "apps" ? apps : DashboardState.page === "power" ? powerLock : DashboardState.page === "display" ? display
            : DashboardState.page === "audio" ? audioPage : DashboardState.page === "network" ? networkPage : controls
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
                isPinned: appId => LauncherState.dockFavorites.indexOf(appId)>=0
                onPinRequested: appId => LauncherState.dockAction(LauncherState.dockFavorites.indexOf(appId)>=0 ? "unpin" : "pin",appId)
                onRefreshRequested: LauncherState.refresh()
                onCloseRequested: DashboardState.close()
            }
        }
    }
    Component {
        id: powerLock
        PowerLockPage { policy: PowerPolicyState; wallpaper: AssetPaths.asset(Quickshell.shellDir, "wallpapers/shittim-city.png") }
    }
    Component {
        id: display
        DisplayPage { display: DisplayState; brightness: BrightnessState }
    }
    Component {
        id: audioPage
        AudioSettingsPage { audio: AudioState; microphone: MicrophoneState; iconSource: name => Quickshell.iconPath(name, true) }
    }
    Component {
        id: networkPage
        NetworkSettingsPage { network: NetworkState; settings: NetworkSettingsState; traffic: DashboardState.model }
    }
    Component {
        id: controls
        ControlContent {
            embedded: true
            audio: AudioState; network: NetworkState; battery: BatteryState; bluetooth: BluetoothState; brightness: BrightnessState; power: PowerState; capture: CaptureState; metrics: SystemMetricsState; microphone: MicrophoneState; camera: CameraState; screenShare: ScreenShareState; notifications: NotificationState
            page: DashboardState.page === "network" ? "wifi" : DashboardState.page === "display" ? "brightness" : DashboardState.page
            onNavigate: destination => DashboardState.select(destination === "wifi" ? "network" : destination === "brightness" ? "display" : destination)
            onCloseRequested: DashboardState.close()
        }
    }
}
