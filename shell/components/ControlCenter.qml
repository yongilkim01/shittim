import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../ui"
import "../services"
import "./control"

PanelWindow {
	id: window
	screen: ControlState.anchorWindow !== null ? ControlState.anchorWindow.screen : null
	visible: ControlState.opened && screen !== null
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
	ControlFrame {
		anchors.fill: parent; strokeColor: Theme.accentDim
		fillColor: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.97)
		ControlContent {
			id: content; anchors.fill: parent
			audio: AudioState; network: NetworkState; battery: BatteryState; bluetooth: BluetoothState; brightness: BrightnessState; power: PowerState; capture: CaptureState; metrics: SystemMetricsState
			notifications: NotificationState
			page: ControlState.page
			onNavigate: destination => ControlState.page = destination
			onCloseRequested: ControlState.close()
		}
	}
}
