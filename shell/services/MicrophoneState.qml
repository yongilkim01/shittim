pragma Singleton
import Quickshell
import Quickshell.Services.Pipewire
import "../core/DeviceData.js" as Devices

// Default PipeWire input and applications currently recording from it.
Scope {
	id: root
	readonly property PwNode source: Pipewire.defaultAudioSource
	readonly property bool available: source !== null && source.ready && source.audio !== null
	readonly property bool validVolume: available && isFinite(source.audio.volume) && source.audio.volume >= 0
	readonly property int percentage: validVolume ? Math.round(source.audio.volume * 100) : 0
	readonly property bool muted: available && source.audio.muted
	readonly property string deviceName: available ? Devices.label(source) : "입력 장치 없음"
	readonly property var inputs: Pipewire.nodes.values.filter(node => Devices.isMicrophone(node))
	readonly property var recorders: Pipewire.nodes.values.filter(node => Devices.isRecording(node))
	readonly property bool inUse: recorders.length > 0
	readonly property var applications: Devices.applicationNames(recorders)
	PwObjectTracker { objects: [root.source].concat(root.inputs, root.recorders).filter((node, index, nodes) => node !== null && nodes.indexOf(node) === index) }
	function setVolume(fraction) {
		if (available && isFinite(fraction)) source.audio.volume = Math.max(0, Math.min(1, fraction))
	}
	function toggleMute() { if (available) source.audio.muted = !source.audio.muted }
	function adjustVolume(steps) { if (validVolume) setVolume(source.audio.volume + steps * 0.05) }
	function selectInput(node) { if (inputs.indexOf(node) >= 0) Pipewire.preferredDefaultAudioSource = node }
}
