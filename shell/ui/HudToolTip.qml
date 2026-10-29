import QtQuick
import QtQuick.Controls.Basic as Controls

// In-window hint drawn as a HUD card. Bar items use BarTooltip (a popup window) instead.
Controls.ToolTip {
	id: root
	delay: Theme.tooltipDelay
	padding: 0
	background: null
	contentItem: HudInfoCard { arrow: "none"; title: root.text }
	enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.hoverDuration; easing.type: Theme.easing } }
	exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Theme.hoverDuration; easing.type: Theme.easing } }
}
