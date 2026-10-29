pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../core/AudioData.js" as Audio

// Default output, every output device and the applications playing sound. The top bar, the control center and the
// audio page all bind to these same PipeWire objects, so a change from any of them (or from another program) shows
// everywhere. Moving an application to another output is the one thing Quickshell cannot do; scripts/audio-route.py
// does it through WirePlumber's metadata.
Scope {
	id: root
	readonly property string script: Quickshell.shellDir + "/../scripts/audio-route.py"
	readonly property PwNode sink: Pipewire.defaultAudioSink
	readonly property bool available: sink !== null && sink.ready && sink.audio !== null
	readonly property bool validVolume: available && isFinite(sink.audio.volume) && sink.audio.volume >= 0
	readonly property int percentage: validVolume ? Math.round(sink.audio.volume * 100) : 0
	readonly property bool muted: available && sink.audio.muted
	readonly property string deviceName: available ? (sink.description || sink.nickname || sink.name) : "출력 장치 없음"
	readonly property var outputs: Pipewire.nodes.values.filter(node => node.isSink && !node.isStream && node.audio !== null)
	readonly property var streams: Pipewire.nodes.values.filter(node => node.isSink && node.isStream && node.audio !== null)
	// Output each playback stream is linked to right now (WirePlumber may still be linking a new stream).
	readonly property var targets: {
		const map = {}
		for (const group of Pipewire.linkGroups.values)
			if (group.source && group.target && group.source.isStream && group.source.isSink && !group.target.isStream) map[group.source.id] = group.target
		return map
	}
	readonly property var applications: Audio.applications(streams, targets)
	readonly property var leftChannels: available ? channelIndexes([PwAudioChannel.FrontLeft, PwAudioChannel.SideLeft, PwAudioChannel.RearLeft]) : []
	readonly property var rightChannels: available ? channelIndexes([PwAudioChannel.FrontRight, PwAudioChannel.SideRight, PwAudioChannel.RearRight]) : []
	readonly property var balance: available ? Audio.balance(sink.audio.volumes, leftChannels, rightChannels) : null
	property string error: ""
	property bool routing: false
	property var pendingOutput: null
	property var routeQueue: []
	PwObjectTracker { objects: [root.sink].concat(root.outputs, root.streams).filter((node, index, nodes) => node !== null && nodes.indexOf(node) === index) }

	function channelIndexes(kinds) {
		const result = [], channels = sink.audio.channels
		for (let i = 0; i < channels.length; ++i) if (kinds.indexOf(channels[i]) >= 0) result.push(i)
		return result
	}
	function setVolume(fraction) {
		if (available && isFinite(fraction)) sink.audio.volume = Math.max(0, Math.min(1, fraction))
	}
	function toggleMute() { if (available) sink.audio.muted = !sink.audio.muted }
	function adjustVolume(steps) { if (validVolume) setVolume(sink.audio.volume + steps * 0.05) }
	function setBalance(value) {
		if (balance === null || !isFinite(value)) return
		sink.audio.volumes = Audio.balanced(sink.audio.volumes, leftChannels, rightChannels, value)
	}
	function selectOutput(node) {
		if (outputs.indexOf(node) < 0) return
		error = ""
		pendingOutput = node
		Pipewire.preferredDefaultAudioSink = node
		outputCheck.restart()
	}
	// One volume and mute for the whole application; every stream it opened follows.
	function setApplicationVolume(app, fraction) {
		if (!app || !isFinite(fraction)) return
		for (const stream of app.streams) if (stream.audio) stream.audio.volume = Math.max(0, Math.min(1, fraction))
	}
	function toggleApplicationMute(app) {
		if (!app || !app.available) return
		for (const stream of app.streams) if (stream.audio) stream.audio.muted = !app.muted
	}
	// `node` null sends the application back to whatever the default output is.
	function moveApplication(app, node) {
		if (!app || node !== null && outputs.indexOf(node) < 0) return
		const serial = node === null ? "default" : String(node.properties["object.serial"] || "")
		if (serial === "") { error = Audio.errorText("TargetNotFound"); return }
		error = ""
		routeQueue = routeQueue.concat(app.streams.map(stream => [String(stream.id), serial]))
		nextRoute()
	}
	function nextRoute() {
		if (router.running || routeQueue.length === 0) { routing = router.running; return }
		const request = routeQueue[0]
		routeQueue = routeQueue.slice(1)
		routing = true
		router.command = ["python3", root.script, "move", request[0], request[1]]
		router.running = true
	}
	function clearError() { error = "" }

	Process {
		id: router
		stderr: SplitParser { onRead: data => root.error = Audio.errorText(data) }
		onExited: code => {
			if (code !== 0 && !root.error) root.error = Audio.errorText("")
			if (code !== 0) root.routeQueue = []
			root.nextRoute()
		}
	}
	// The default only changes once WirePlumber accepts the choice; say so if it never does.
	Timer {
		id: outputCheck; interval: 2000
		onTriggered: {
			if (root.pendingOutput !== null && root.sink !== root.pendingOutput) root.error = "기본 출력 장치를 바꾸지 못했습니다. 장치 연결을 확인하세요."
			root.pendingOutput = null
		}
	}
	onSinkChanged: if (sink !== null && sink === pendingOutput) { pendingOutput = null; outputCheck.stop() }
}
