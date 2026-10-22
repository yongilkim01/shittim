import QtQuick
import Quickshell.Services.Pipewire

Text {
	id: root

	readonly property PwNode sink: Pipewire.defaultAudioSink
	readonly property bool available: sink !== null && sink.ready && sink.audio !== null
	readonly property bool validVolume: available && isFinite(sink.audio.volume) && sink.audio.volume >= 0
	readonly property int percentage: validVolume ? Math.round(sink.audio.volume * 100) : 0
	readonly property bool muted: available && sink.audio.muted
	readonly property string icon: {
		if (!available || muted) return "\uf6a9"
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

	text: !available ? icon + " N/A"
		: icon + " " + (validVolume ? percentage + "%" : "--%") + (muted ? " MUTE" : "")
	color: muted ? "#f38ba8" : "#cdd6f4"
	font.pixelSize: 14
	font.family: "Hack Nerd Font Mono"

	MouseArea {
		anchors.fill: parent
		enabled: root.available
		acceptedButtons: Qt.LeftButton
		cursorShape: Qt.PointingHandCursor

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
