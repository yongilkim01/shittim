pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import "../core"
import "../core/DeviceData.js" as Devices

// Default PipeWire input and applications currently recording from it.
// The input level is measured only while a consumer (the audio page with "입력 확인" on) asks for it: Quickshell's
// peak monitor then opens a monitor stream (stream.monitor=true, so it never counts as an app using the microphone),
// keeps only the peak value in memory and closes the stream when the last consumer lets go.
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
	readonly property bool levelActive: peaks.enabled
	readonly property real level: peaks.enabled ? peaks.peak : 0
	property string error: ""
	property var pendingInput: null
	PwObjectTracker { objects: [root.source].concat(root.inputs, root.recorders).filter((node, index, nodes) => node !== null && nodes.indexOf(node) === index) }
	ConsumerSet { id: levelConsumers }
	// Measuring needs only the node, not its volume controls.
	PwNodePeakMonitor { id: peaks; node: root.source; enabled: levelConsumers.active && root.source !== null && root.source.ready }
	function watchLevel(consumer) { levelConsumers.retain(consumer) }
	function unwatchLevel(consumer) { levelConsumers.release(consumer) }
	function setVolume(fraction) {
		if (available && isFinite(fraction)) source.audio.volume = Math.max(0, Math.min(1, fraction))
	}
	function toggleMute() { if (available) source.audio.muted = !source.audio.muted }
	function adjustVolume(steps) { if (validVolume) setVolume(source.audio.volume + steps * 0.05) }
	function selectInput(node) {
		if (inputs.indexOf(node) < 0) return
		error = ""
		pendingInput = node
		Pipewire.preferredDefaultAudioSource = node
		inputCheck.restart()
	}
	Timer {
		id: inputCheck; interval: 2000
		onTriggered: {
			if (root.pendingInput !== null && root.source !== root.pendingInput) root.error = "기본 입력 장치를 바꾸지 못했습니다. 장치 연결을 확인하세요."
			root.pendingInput = null
		}
	}
	onSourceChanged: if (source !== null && source === pendingInput) { pendingInput = null; inputCheck.stop() }
}
