pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth

Scope {
	id: root
	readonly property string helperPath: Quickshell.shellDir + "/../scripts/control-service.py"
	property bool ready: false
	property string error: ""
	property var backlights: []
	property string selectedBacklight: ""
	readonly property var backlight: backlights.find(device => device.name === selectedBacklight) || backlights[0] || null
	property var profiles: []
	property string profile: ""
	property int cpu: -1
	property int memory: -1
	property int uptime: 0
	property bool screenshotAvailable: false
	property string screenshotError: ""
	property var selectedAdapter: null
	readonly property var adapters: Bluetooth.adapters.values
	readonly property var adapter: adapters.indexOf(selectedAdapter) >= 0 ? selectedAdapter : Bluetooth.defaultAdapter
	readonly property var devices: adapter === null ? [] : adapter.devices.values.slice().sort((a, b) =>
		Number(b.connected) - Number(a.connected) || Number(b.paired) - Number(a.paired) || a.name.localeCompare(b.name))
	property bool bluetoothReady: false
	property var prompt: null
	property var pending: ({})
	property var queuedBrightness: null
	property int sequence: 0
	property var scanAdapter: null
	readonly property bool busy: Object.keys(pending).length > 0
	readonly property bool active: ControlState.opened || DashboardState.controlsActive
	function syncConsumer() {
		if (!active) { stopDiscovery(); prompt = null; queuedBrightness = null; error = "" }
		else error = screenshotError
	}
	function errorText(code) {
		if (code === "BrightnessPermissionDenied") return "밝기 제어 권한이 없습니다. 세션 권한을 확인한 뒤 새로고침하세요."
		if (code === "BrightnessSessionUnavailable") return "밝기를 조절할 현재 사용자의 활성 로컬 세션을 찾지 못했습니다."
		if (code === "BrightnessCommandFailed" || code === "BrightnessLogindFailed") return "밝기 변경 명령이 실패했습니다. 장치 상태를 확인하고 다시 시도하세요."
		if (code === "BrightnessToolUnavailable") return "brightnessctl이 없고 세션 밝기 제어도 사용할 수 없습니다."
		if (code === "BrightnessTimeout") return "밝기 변경 응답 시간이 초과되었습니다."
		if (code === "DBusDependencyUnavailable") return "D-Bus 보조 서비스를 시작하지 못했습니다. python-dbus-next 설치를 확인하세요."
		if (code === "AuthenticationRejected" || code === "AuthenticationFailed") return "Bluetooth 인증이 거부되었거나 실패했습니다."
		if (code === "NotReady") return "어댑터 전원 또는 하드웨어 차단 상태를 확인하세요."
		if (code === "TimeoutError") return "요청 시간이 초과되었습니다. 장치 상태를 확인하세요."
		return "시스템 요청 실패: " + code
	}
	function send(message) {
		if (!ready || !bridge.running) { error = "보조 서비스 준비 중이거나 실행할 수 없습니다."; return }
		message.id = ++sequence
		const next = Object.assign({}, pending)
		next[message.id] = {action: message.action, device: message.device || ""}
		pending = next
		bridge.write(JSON.stringify(message) + "\n")
	}
	function setBrightness(value) {
		if (!ready || backlight === null || !backlight.writable) return
		const message = {action: "brightness", device: backlight.name, value: value}
		if (Object.values(pending).some(request => request.action === "brightness")) { queuedBrightness = message; return }
		error = ""
		send(message)
	}
	function setProfile(value) { if (profiles.indexOf(value) >= 0 && !busy) send({action: "profile", profile: value}) }
	function refresh() { error = ""; send({action: "refresh"}) }
	function toggleBluetooth() {
		if (adapter !== null) { error = ""; adapter.enabled = !adapter.enabled }
	}
	function searchBluetooth() {
		if (adapter === null || !adapter.enabled) return
		if (scanAdapter !== null) scanAdapter.discovering = false
		if (!adapter.discovering) { scanAdapter = adapter; adapter.discovering = true }
		scanTimeout.restart()
	}
	function stopDiscovery() {
		scanTimeout.stop()
		if (scanAdapter !== null) scanAdapter.discovering = false
		scanAdapter = null
	}
	function deviceAction(device) {
		if (!ready || !bluetoothReady || busy || device === null) return
		error = ""
		send({action: device.connected ? "disconnect" : device.paired ? "connect" : "pair", device: device.dbusPath})
	}
	function cancelPair() {
		const current = prompt
		if (current && current.request !== undefined) answerPrompt(false, "")
		if (current && current.device) send({action: "cancel-pair", device: current.device})
		prompt = null
	}
	function answerPrompt(accept, value) {
		if (prompt === null || !ready) return
		bridge.write(JSON.stringify({action: "reply", request: prompt.request, accept: accept, value: value}) + "\n")
		prompt = null
	}
	function receive(message) {
		if (message.event === "ready") { ready = true; return }
		if (message.event === "notice") { error = errorText(message.error); return }
		if (message.event === "prompt") { prompt = message; return }
		if (message.event === "prompt-clear") { prompt = null; return }
		if (message.event === "state") {
			backlights = message.backlights
			profiles = message.profiles
			profile = message.profile
			bluetoothReady = message.bluetooth
			cpu = message.cpu === undefined ? -1 : message.cpu
			memory = message.memory === undefined ? -1 : message.memory
			uptime = message.uptime || 0
			screenshotAvailable = message.screenshotAvailable === true
			return
		}
		if (message.event === "result") {
			const request = pending[message.id]
			const next = Object.assign({}, pending)
			delete next[message.id]
			pending = next
			if (!message.ok) error = errorText(message.error)
			else if (request && request.action === "pair") send({action: "connect", device: request.device})
			if (request && request.action === "brightness") {
				const queued = queuedBrightness
				queuedBrightness = null
				if (message.ok && queued !== null && backlight !== null && queued.device === backlight.name) send(queued)
			}
		}
	}
	Connections {
		target: ControlState
		function onOpenedChanged() {
			root.syncConsumer()
		}
	}
	Connections { target: DashboardState; function onControlsActiveChanged() { root.syncConsumer() } }
	Timer { id: scanTimeout; interval: 45000; onTriggered: root.stopDiscovery() }
	Process {
		id: bridge
		command: ["python3", "-u", root.helperPath]
		running: root.active
		stdinEnabled: true
		onStarted: { root.ready = false; root.error = root.screenshotError }
		stdout: SplitParser {
			onRead: data => {
				try { root.receive(JSON.parse(data)) }
				catch (_) { root.error = "보조 서비스 응답을 처리하지 못했습니다." }
			}
		}
		// Never forward raw helper output into the shell journal.
		stderr: SplitParser { onRead: data => { root.error = "보조 서비스 실행 오류가 발생했습니다." } }
		onExited: {
			root.ready = false
			root.pending = ({})
			root.queuedBrightness = null
			root.prompt = null
			if (root.active) root.error = "보조 서비스가 종료되었습니다. 패널을 닫았다 다시 열어 주세요."
		}
	}
	Process { id: editor; command: ["nm-connection-editor"] }
	function openNetworkEditor() { editor.startDetached(); ControlState.close(); DashboardState.close() }
	Process {
		id: screenshot
		command: ["python3", "-u", root.helperPath, "--screenshot"]
		onExited: (code, status) => { if (code !== 0) { root.screenshotError = "스크린샷을 저장하지 못했습니다."; root.error = root.screenshotError } }
	}
	function takeScreenshot() {
		if (!screenshotAvailable || screenshot.running) return
		screenshotError = ""
		ControlState.close()
		screenshot.running = true
	}
}
