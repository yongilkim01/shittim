pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../core/ActionErrors.js" as Errors

// Camera presence and use reported by scripts/camera-service.py. Read-only: never opens a camera stream.
Scope {
	id: root
	property bool ready: false
	property var cameras: []
	property string error: ""
	property int restarts: 0
	readonly property bool present: cameras.length > 0
	readonly property var activeCameras: cameras.filter(camera => camera.users && camera.users.length > 0)
	readonly property bool inUse: activeCameras.length > 0
	readonly property var applications: activeCameras.reduce((names, camera) => names.concat(camera.users.filter(name => names.indexOf(name) < 0)), [])
	function receive(message) {
		if (message.event !== "state" || !Array.isArray(message.cameras)) throw new Error("invalid")
		cameras = message.cameras; ready = true; error = ""; restarts = 0
	}
	function restart() { restarts = 0; error = ""; helper.running = false; helper.running = true }
	Process {
		id: helper; running: true
		command: ["python3", "-u", Quickshell.shellDir + "/../scripts/camera-service.py"]
		stdout: SplitParser { onRead: data => { try { root.receive(JSON.parse(data)) } catch (_) { root.error = Errors.message("InvalidResponse") } } }
		// Never forward raw helper output into the shell journal.
		stderr: SplitParser { onRead: data => root.error = Errors.message("CameraServiceUnavailable") }
		onExited: {
			root.ready = false; root.cameras = []
			root.error = Errors.message("CameraServiceUnavailable")
			// Bounded automatic reconnect; the Control Center offers a manual retry afterwards.
			if (root.restarts < 3) { root.restarts += 1; retry.restart() }
		}
	}
	Timer { id: retry; interval: 2000 * root.restarts; onTriggered: helper.running = true }
}
