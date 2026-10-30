import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../ui"
import "../services"
import "./control"

// Keep-or-restore question over every screen while a network change waits and the network page is not showing it
// (dashboard closed for a polkit prompt, or the shell restarted mid-change). Only the focused screen takes the keyboard.
// Nobody answering is safe: NetworkManager restores the previous settings on its own.
Variants {
	model: Quickshell.screens
	PanelWindow {
		id: window
		required property var modelData
		readonly property bool focusedScreen: Hyprland.focusedMonitor !== null && modelData.name === Hyprland.focusedMonitor.name
		screen: modelData
		visible: NetworkSettingsState.waiting && !NetworkSettingsState.shownInPage
		implicitWidth: card.implicitWidth; implicitHeight: card.implicitHeight
		color: Theme.transparent; exclusionMode: ExclusionMode.Ignore
		WlrLayershell.namespace: "shittim-network-confirm"
		WlrLayershell.layer: WlrLayer.Overlay
		WlrLayershell.keyboardFocus: focusedScreen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
		NetworkConfirmCard { id: card; anchors.fill: parent; settings: NetworkSettingsState }
		onVisibleChanged: if (visible && focusedScreen) Qt.callLater(card.focusDefault)
	}
}
