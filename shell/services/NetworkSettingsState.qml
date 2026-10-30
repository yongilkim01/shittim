pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../core"
import "../core/NetworkData.js" as NetworkData

// What Quickshell.Networking does not offer: IP/DNS details, saved profiles, keep-or-restore of changes
// (NetworkManager checkpoints) and diagnostics, through scripts/network-service.py. Wi-Fi on/off, scanning and
// joining networks stay in NetworkState, which the bar and the Control Center share.
// The helper runs only while the settings page is open, a request is in flight or a change waits for an answer.
Scope {
	id: root
	readonly property string helperPath: Quickshell.shellDir + "/../scripts/network-service.py"
	property bool ready: false
	property var state: empty()
	property var diagnosis: null
	property string error: ""
	property string notice: ""
	readonly property bool busy: ledger.busy
	readonly property var pending: ledger.entries
	readonly property bool available: ready && state.available === true
	readonly property var devices: state.devices || []
	readonly property var connections: state.connections || []
	readonly property var checkpoint: state.checkpoint || null
	readonly property bool waiting: checkpoint !== null && !checkpoint.applying
	readonly property int remaining: waiting ? checkpoint.remaining : 0
	// The settings page shows the keep/restore question itself; otherwise NetworkConfirm puts it over the screen.
	readonly property bool shownInPage: viewers.active
	readonly property bool wanted: consumers.active || checkpoint !== null || busy
	ConsumerSet { id: consumers }
	ConsumerSet { id: viewers }
	function retain(consumer) { consumers.retain(consumer) }
	function release(consumer) { consumers.release(consumer); viewers.release(consumer) }
	function showing(consumer, visible) { visible ? viewers.retain(consumer) : viewers.release(consumer) }
	function empty() { return {available: false, devices: [], connections: [], permissions: {}, checkpoint: null, connectivity: "unknown", checkTarget: ""} }

	function device(name) { return devices.find(item => item.interface === name) || null }
	function profile(uuid) { return connections.find(item => item.uuid === uuid) || null }
	function profileForSsid(ssid) { return connections.find(item => item.type === "wifi" && item.ssid === ssid) || null }
	// "auth" means NetworkManager will ask polkit for an administrator password.
	function needsAuthentication(permission) { return (state.permissions || {})[permission] === "auth" }
	function isPending(operation, target) { return Object.values(ledger.entries).some(entry => entry.operation === operation && (!target || entry.target === target)) }

	function send(message, timeout, target) {
		if (!ready || !bridge.running) { error = NetworkData.errorText("BackendUnavailable"); return 0 }
		const id = ledger.begin(message.action, timeout || 20000, target || "")
		if (!id) { error = NetworkData.errorText("QueueFull"); return 0 }
		error = ""; notice = ""
		bridge.write(JSON.stringify(Object.assign({}, message, {id: id})) + "\n")
		return id
	}
	function refresh() { if (bridge.running && ready) send({action: "refresh"}); else sync() }
	function activate(uuid, deviceName) { return send({action: "activate", uuid: uuid, device: deviceName || ""}, 130000, uuid) }
	function disconnectDevice(deviceName) { return send({action: "disconnect", device: deviceName}, 130000, deviceName) }
	function setAutoconnect(uuid, enabled, priority) {
		const message = {action: "autoconnect", uuid: uuid, enabled: enabled}
		if (typeof priority === "number") message.priority = Math.max(-999, Math.min(999, Math.round(priority)))
		return send(message, 130000, uuid)
	}
	function remove(uuid) { return send({action: "delete", uuid: uuid}, 130000, uuid) }
	function apply(uuid, request) { return send(Object.assign({action: "apply", uuid: uuid}, request), 200000, uuid) }
	function keep() { if (waiting) send({action: "keep"}, 130000) }
	function revert() { if (checkpoint !== null) send({action: "revert"}, 40000) }
	function diagnose(deviceName) { if (!isPending("diagnose")) { diagnosis = null; send({action: "diagnose", device: deviceName}, 90000, deviceName) } }
	// The password goes to the helper's stdin and on to NetworkManager; nothing here keeps or prints it.
	function connectHidden(deviceName, ssid, security, password) {
		return send({action: "connect-hidden", device: deviceName, ssid: ssid, security: security, password: password || ""}, 130000, deviceName)
	}
	function clearMessages() { error = ""; notice = "" }

	function sync() {
		if (wanted && !bridge.running) { error = ""; ready = false; startup.restart(); bridge.running = true }
		else if (!wanted && bridge.running) bridge.running = false
	}
	onWantedChanged: Qt.callLater(sync)
	function receive(message) {
		if (message.event === "ready") { ready = true; startup.stop(); return }
		if (message.event === "state") { state = message; consumers.release(resume); return }
		if (message.event === "diagnosis") { diagnosis = message; return }
		if (message.event === "notice") { error = NetworkData.errorText(message.error); return }
		if (message.event === "result") ledger.complete(message.id, message.ok, message.error, false, {applied: message.applied || ""})
	}
	RequestLedger {
		id: ledger
		onFinished: result => {
			if (!result.ok) { if (result.status !== "cancelled" || root.error === "") root.error = NetworkData.errorText(result.code); return }
			if (result.operation === "apply") root.notice = result.applied === "saved" ? "설정을 저장했습니다. 다음 연결부터 적용됩니다." : ""
			else if (result.operation === "keep") root.notice = "변경한 네트워크 설정을 유지합니다."
			else if (result.operation === "revert") root.notice = "이전 네트워크 설정으로 복원했습니다."
			else if (result.operation === "delete") root.notice = "연결 프로필을 삭제했습니다."
			else if (result.operation === "autoconnect") root.notice = "자동 연결 설정을 저장했습니다."
		}
	}
	// After a shell restart in the middle of a change, ask the helper once whether that change still waits for an answer.
	QtObject { id: resume }
	FileView {
		path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/shittim/network-checkpoint"
		// Usually absent (nothing waiting); that is not worth a journal line.
		printErrors: false
		onLoaded: { consumers.retain(resume); resumeEnd.restart() }
	}
	Timer { id: resumeEnd; interval: 15000; onTriggered: consumers.release(resume) }
	Timer { id: startup; interval: 10000; onTriggered: { root.error = NetworkData.errorText("BackendUnavailable"); bridge.running = false } }
	Process {
		id: bridge; stdinEnabled: true
		command: ["python3", "-u", root.helperPath]
		onStarted: { root.ready = false; startup.restart() }
		stdout: SplitParser {
			splitMarker: "\n"
			onRead: data => { try { root.receive(JSON.parse(data)) } catch (_) { root.error = NetworkData.errorText("BackendUnavailable"); ledger.cancelAll("BackendUnavailable") } }
		}
		// Never forward raw helper output into the shell journal.
		stderr: SplitParser { onRead: data => root.error = NetworkData.errorText("BackendUnavailable") }
		onExited: {
			startup.stop(); root.ready = false; ledger.cancelAll("BackendExited")
			// A pending checkpoint is NetworkManager's: it still restores on its own when nobody answers.
			if (consumers.active) root.error = NetworkData.errorText("BackendExited")
			root.state = root.empty(); root.diagnosis = null
		}
	}
}
