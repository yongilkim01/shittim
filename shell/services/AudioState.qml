pragma Singleton
import Quickshell
import Quickshell.Services.Pipewire

Scope {
	id: root
	readonly property PwNode sink: Pipewire.defaultAudioSink
	readonly property bool available: sink !== null && sink.ready && sink.audio !== null
	readonly property bool validVolume: available && isFinite(sink.audio.volume) && sink.audio.volume >= 0
	readonly property int percentage: validVolume ? Math.round(sink.audio.volume * 100) : 0
	readonly property bool muted: available && sink.audio.muted
	readonly property string deviceName: available ? (sink.description || sink.nickname || sink.name) : "출력 장치 없음"
	readonly property var outputs: Pipewire.nodes.values.filter(node => node.isSink && !node.isStream && node.audio !== null)
	readonly property var streams: Pipewire.nodes.values.filter(node => node.isSink && node.isStream && node.audio !== null)
	PwObjectTracker { objects: [root.sink].concat(root.outputs, root.streams).filter((node, index, nodes) => node !== null && nodes.indexOf(node) === index) }
	function setVolume(fraction) {
		if (available && isFinite(fraction)) sink.audio.volume = Math.max(0, Math.min(1, fraction))
	}
	function toggleMute() { if (available) sink.audio.muted = !sink.audio.muted }
	function adjustVolume(steps) { if (validVolume) setVolume(sink.audio.volume + steps * 0.05) }
	function selectOutput(node) { if (outputs.indexOf(node) >= 0) Pipewire.preferredDefaultAudioSink = node }
}
