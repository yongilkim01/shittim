import QtQuick
import Quickshell.Services.Pipewire
import "../ui"
import "../services"

HudStatus {
	id: root

	readonly property PwNode sink: AudioState.sink
	readonly property bool available: AudioState.available
	readonly property bool validVolume: AudioState.validVolume
	readonly property int percentage: AudioState.percentage
	readonly property bool muted: AudioState.muted
	readonly property string icon: {
		if (!available || muted) return "\uf026"
		if (!validVolume || percentage === 0) return "\uf026"
		if (percentage <= 50) return "\uf027"
		return "\uf028"
	}
	property int wheelRemainder: 0

	onSinkChanged: wheelRemainder = 0

	signal controlCenterRequested()
	function toggleMute(): void { AudioState.toggleMute() }
	function adjustVolume(steps: int): void { AudioState.adjustVolume(steps) }

	glyph: icon
	text: !available ? "N/A"
		: (validVolume ? percentage + "%" : "--%") + (muted && (!compact || hovered) ? " MUTE" : "")
	color: muted ? Theme.danger : (available ? (compact ? Theme.accentBright : Theme.textPrimary) : Theme.textMuted)
	hovered: mouse.containsMouse && available
	HudProgress {
		anchors.left: parent.left
		anchors.right: parent.right
		anchors.bottom: parent.bottom
		anchors.leftMargin: Theme.spaceXS
		anchors.rightMargin: Theme.spaceXS
		visible: root.hovered && root.validVolume
		value: root.validVolume ? root.sink.audio.volume : 0
		fillColor: root.muted ? Theme.danger : Theme.accent
	}

	MouseArea {
		id: mouse
		anchors.fill: parent
		enabled: root.available
		acceptedButtons: Qt.LeftButton | Qt.RightButton
		cursorShape: Qt.PointingHandCursor
		hoverEnabled: true

		onClicked: event => {
			if (event.button === Qt.RightButton) root.controlCenterRequested()
			else root.toggleMute()
		}
		onWheel: wheel => {
			if (!root.validVolume || wheel.angleDelta.y === 0) {
				wheel.accepted = false
				return
			}
			// A standard wheel notch is 120 angle units; retain partial notches.
			root.wheelRemainder += wheel.angleDelta.y
			const steps = Math.trunc(root.wheelRemainder / 120)
			if (steps !== 0) {
				root.wheelRemainder -= steps * 120
				root.adjustVolume(steps)
			}
			wheel.accepted = true
		}
	}
}
