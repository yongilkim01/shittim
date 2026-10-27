pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Lock, idle and lid preferences. scripts/power-policy.py is the only writer of shittim/power.json and
// scripts/idle-service.py reports what it actually applied; the UI shows both, never assuming a save was applied.
Scope {
	id: root
	readonly property string scripts: Quickshell.shellDir + "/../scripts/"
	readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || ""
	readonly property string configDir: Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")
	property var defaults: null
	property var personal: null
	readonly property var settings: personal || defaults
	property var status: null
	property real now: Date.now()
	property string error: ""
	property bool saving: false
	property bool keepAwake: false
	readonly property bool fresh: status !== null && now / 1000 - status.time < 10
	readonly property string currentSource: fresh ? status.source : "ac"
	readonly property bool hasBattery: fresh ? status.hasBattery : false
	readonly property bool hasLid: fresh && status.lid ? status.lid.present : false
	readonly property var systemLid: fresh && status.lid ? status.lid.system : ({})
	readonly property string applyState: !fresh ? "stopped" : status.idle === "external" ? "external" : status.idle !== "running" ? "failed"
		: settings && JSON.stringify(settings[status.source]) !== JSON.stringify(status.applied) ? "pending"
		: status.lid && status.lid.error ? "lid" : status.settingsError ? "invalid" : "applied"

	function parse(view) { try { return JSON.parse(view.text()) } catch (_) { return null } }
	function setValue(source, key, value) {
		if (saving) return
		error = ""; saving = true
		writer.command = ["python3", root.scripts + "power-policy.py", "set", source, key, String(value)]
		writer.running = true
	}
	function lock() { Quickshell.execDetached(["/usr/bin/bash", root.scripts + "power-action.sh", "lock"]) }
	function suspend() { Quickshell.execDetached(["/usr/bin/bash", root.scripts + "power-action.sh", "suspend"]) }

	FileView { id: defaultsFile; path: Quickshell.shellDir + "/../config/power.json"; printErrors: false; onLoaded: root.defaults = root.parse(defaultsFile) }
	FileView {
		id: personalFile; path: root.configDir + "/shittim/power.json"; printErrors: false
		onLoaded: root.personal = root.parse(personalFile)
		onLoadFailed: root.personal = null
	}
	// The service replaces this file atomically, so it is polled instead of watched.
	FileView {
		id: statusFile; path: root.runtimeDir ? root.runtimeDir + "/shittim/power-status.json" : ""; printErrors: false
		onLoaded: root.status = root.parse(statusFile)
		onLoadFailed: root.status = null
	}
	Timer { interval: 2000; running: true; repeat: true; onTriggered: { root.now = Date.now(); statusFile.reload(); personalFile.reload() } }
	Process {
		id: writer
		stderr: SplitParser { onRead: data => root.error = data === "PowerConfigInvalid" || data === "InvalidRequest" ? "설정 값을 저장하지 못했습니다." : "설정 파일을 쓰지 못했습니다." }
		onExited: code => { root.saving = false; if (code !== 0 && !root.error) root.error = "설정을 저장하지 못했습니다."; personalFile.reload() }
	}
	// Manual keep-awake: a logind idle inhibitor that hypridle honours. It ends with the shell, so it never sticks.
	Process {
		running: root.keepAwake
		command: ["systemd-inhibit", "--what=idle", "--who=Shittim", "--why=사용자가 절전 방지를 켬", "--mode=block", "sleep", "infinity"]
		onExited: if (root.keepAwake) root.keepAwake = false
	}
	IpcHandler {
		target: "power"
		function lock(): void { root.lock() }
		function toggleKeepAwake(): void { root.keepAwake = !root.keepAwake }
		function status(): string { return JSON.stringify({applyState: root.applyState, keepAwake: root.keepAwake, source: root.currentSource}) }
	}
}
