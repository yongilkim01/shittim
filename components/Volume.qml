import QtQuick
import Quickshell.Services.Pipewire
import "../ui"

HudStatus {
	id: root

	readonly property PwNode sink: Pipewire.defaultAudioSink
	readonly property bool available: sink !== null && sink.ready && sink.audio !== null
	readonly property bool validVolume: available && isFinite(sink.audio.volume) && sink.audio.volume >= 0
	readonly property int percentage: validVolume ? Math.round(sink.audio.volume * 100) : 0
	readonly property bool muted: available && sink.audio.muted
	readonly property string icon: {
		if (!available || muted) return "\uf026"
		if (!validVolume || percentage === 0) return "\uf026"
		if (percentage <= 50) return "\uf027"
		return "\uf028"
	}
	property int wheelRemainder: 0

	onSinkChanged: wheelRemainder = 0

	function toggleMute(): void {
		if (!available) return
		sink.audio.muted = !sink.audio.muted
	}

	function adjustVolume(steps: int): void {
		if (!validVolume) return
		sink.audio.volume = Math.max(0, Math.min(1, sink.audio.volume + steps * 0.05))
	}

	PwObjectTracker {
		objects: [root.sink]
	}

	glyph: icon
	text: !available ? "N/A"
		: (validVolume ? percentage + "%" : "--%") + (muted ? " MUTE" : "")
	color: muted ? Theme.danger : (available ? Theme.textPrimary : Theme.textMuted)
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
		acceptedButtons: Qt.LeftButton
		cursorShape: Qt.PointingHandCursor
		hoverEnabled: true

		onClicked: root.toggleMute()
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
