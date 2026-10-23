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
	implicitHeight: Math.max(1, Math.min(ControlState.page === "overview" ? Theme.controlPanelHeight * implicitWidth / Theme.controlPanelWidth : Theme.controlDetailHeight,
		(screen ? screen.height : 0) - margins.top - Theme.spaceS))
	exclusionMode: ExclusionMode.Ignore
	color: Theme.transparent
	WlrLayershell.namespace: "shittim-control-center"
	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
	HyprlandFocusGrab {
		active: window.visible
		windows: ControlState.anchorWindow !== null ? [window, ControlState.anchorWindow] : [window]
		onCleared: if (ControlState.opened) ControlState.close()
	}
	onVisibleChanged: if (visible) Qt.callLater(() => content.forceActiveFocus())
	Shortcut { sequence: "Escape"; enabled: window.visible; onActivated: ControlState.close() }
	Connections {
		target: Quickshell
		function onScreensChanged() {
			if (ControlState.anchorWindow === null || Quickshell.screens.indexOf(window.screen) < 0) ControlState.close()
		}
	}
	ControlFrame {
		anchors.fill: parent; strokeColor: Theme.accentDim
		fillColor: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.97)
		ControlContent {
			id: content; anchors.fill: parent
			audio: AudioState; network: NetworkState; battery: BatteryState; system: SystemControl
			notifications: NotificationState
			page: ControlState.page
			onNavigate: destination => ControlState.page = destination
			onCloseRequested: ControlState.close()
		}
	}
}
