import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../ui"
import "../services"
import "./control"

PanelWindow {
	id: window
	screen: ControlState.targetScreen
	visible: ControlState.opened && ControlState.targetScreen !== null
	anchors { top: true; right: true }
	margins.top: Math.min(Theme.barHeight + Theme.spaceS, Math.max(0, (screen ? screen.height : 0) - 120))
	margins.right: Theme.spaceS
	implicitWidth: Math.max(1, Math.min(Theme.controlPanelWidth, (screen ? screen.width : 0) - Theme.spaceS * 2))
	implicitHeight: Math.max(1, Math.min(ControlState.page === "overview" ? Theme.controlPanelHeight : Theme.controlDetailHeight,
		(screen ? screen.height : 0) - margins.top - Theme.spaceS))
	exclusionMode: ExclusionMode.Ignore
	color: Theme.transparent
	WlrLayershell.namespace: "shittim-control-center"
	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.keyboardFocus:input.keyboardFocus
	PanelInput { id:input;window:window;session:ControlState.panelSession }
	onVisibleChanged: if (visible) Qt.callLater(() => content.forceActiveFocus())
	HudFrame {
		anchors.fill: parent; level: "window"
		fillColor: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.97)
		ControlContent {
			id: content; anchors.fill: parent
			audio: AudioState; network: NetworkState; battery: BatteryState; bluetooth: BluetoothState; brightness: BrightnessState; power: PowerState; capture: CaptureState; metrics: SystemMetricsState; microphone: MicrophoneState; camera: CameraState; screenShare: ScreenShareState
			notifications: NotificationState; session: PowerPolicyState
			page: ControlState.page
			onNavigate: destination => {
				if (destination !== "power-settings") { ControlState.page = destination; return }
				ControlState.close(); DashboardState.show(null); DashboardState.select("power")
			}
			onCloseRequested: ControlState.close()
		}
	}
}
