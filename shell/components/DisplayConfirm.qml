import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../ui"
import "../services"
import "./control"

// Keep-or-restore question over every screen while a display change waits and the display page is not showing it
// (dashboard closed, its screen moved, or the shell restarted mid-change). Only the focused screen takes the keyboard.
// Nobody answering is safe: the guard restores the old layout on its own.
Variants {
	model: Quickshell.screens
	PanelWindow {
		id: window
		required property var modelData
		readonly property bool focusedScreen: Hyprland.focusedMonitor !== null && modelData.name === Hyprland.focusedMonitor.name
		screen: modelData
		visible: DisplayState.waiting && !DisplayState.active
		implicitWidth: card.implicitWidth; implicitHeight: card.implicitHeight
		color: Theme.transparent; exclusionMode: ExclusionMode.Ignore
		WlrLayershell.namespace: "shittim-display-confirm"
		WlrLayershell.layer: WlrLayer.Overlay
		WlrLayershell.keyboardFocus: focusedScreen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
		DisplayConfirmCard { id: card; anchors.fill: parent; display: DisplayState }
		onVisibleChanged: if (visible && focusedScreen) Qt.callLater(card.focusDefault)
	}
}
