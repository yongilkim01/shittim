pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../core"
import "../core/DisplayLayout.js" as Layout

// Monitor layout state for the display page: what Hyprland reports (`current`), what the user is preparing (`draft`)
// and the running change. scripts/display-config.py is the only thing that reads or changes monitors; this object
// never builds Hyprland commands. The rollback lives in that script's own systemd unit, not here.
Scope {
	id: root
	readonly property string script: Quickshell.shellDir + "/../scripts/display-config.py"
	readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || ""
	property var monitors: []
	readonly property var editable: monitors.filter(monitor => !monitor.disabled && !monitor.mirrored).sort((a, b) => a.id - b.id)
	readonly property var inactive: monitors.filter(monitor => monitor.disabled || monitor.mirrored)
	property var current: []
	property var draft: []
	property string savedPrimary: ""
	property string primary: ""
	property bool linked: true
	property bool guardAvailable: true
	property bool ready: false
	property bool loading: false
	property bool requesting: false
	property string error: ""
	property string notice: ""
	property string outcome: ""
	property string selected: ""
	property var status: ({})
	property string followed: ""
	property real now: Date.now()
	readonly property bool waiting: status.state === "waiting"
	readonly property bool applying: requesting || status.state === "starting" || status.state === "applying"
	readonly property int remaining: waiting ? Math.max(0, Math.ceil(status.deadline - now / 1000)) : 0
	// The guard answers within a second of its deadline; long after it, the guard is gone.
	readonly property bool stale: waiting && now / 1000 > status.deadline + 5
	readonly property bool dirty: ready && (!Layout.sameLayout(draft, current) || primary !== savedPrimary)
	readonly property string problem: Layout.problem(draft)
	readonly property bool canApply: dirty && problem === "" && !applying && !waiting
	readonly property var selectedMonitor: editable.find(monitor => monitor.name === selected) || null
	readonly property var selectedItem: draft.find(item => item.name === selected) || null
	readonly property var selectedCurrent: current.find(item => item.name === selected) || null
	readonly property bool active: consumers.active
	ConsumerSet { id: consumers }
	function retain(consumer) { consumers.retain(consumer); refresh() }
	function release(consumer) { consumers.release(consumer) }

	function number(name) { return editable.findIndex(monitor => monitor.name === name) + 1 }
	function itemOf(monitor) {
		return {name: monitor.name, width: monitor.width, height: monitor.height, refresh: monitor.refresh, scale: monitor.scale,
			transform: monitor.transform, x: monitor.x, y: monitor.y}
	}
	function refresh() {
		if (lister.running) { refreshAgain.restart(); return }
		loading = true
		lister.running = true
	}
	function receive(data) {
		const wasDirty = dirty
		const before = current.map(item => item.name).sort().join(",")
		monitors = data.monitors || []
		savedPrimary = data.primary || ""
		linked = data.linked !== false
		guardAvailable = data.guard !== false
		const next = editable.map(itemOf)
		const changedSet = ready && before !== next.map(item => item.name).sort().join(",")
		current = next
		if (!wasDirty || changedSet) { draft = Layout.copy(next); primary = savedPrimary }
		if (changedSet) notice = wasDirty ? "모니터 연결이 바뀌어 적용 전 변경 내용을 초기화했습니다." : "모니터 연결이 바뀌어 목록을 새로 읽었습니다."
		if (!selectedMonitor) {
			const focused = editable.find(monitor => monitor.focused)
			selected = focused ? focused.name : editable.length ? editable[0].name : ""
		}
		ready = true
	}

	function select(name) { if (editable.some(monitor => monitor.name === name)) selected = name }
	function update(changes) {
		const before = selectedItem
		if (!before || applying || waiting) return
		const items = Layout.copy(draft)
		Object.assign(items.find(item => item.name === before.name), changes)
		draft = Layout.reflow(items, before.name, before)
		outcome = ""; error = ""; notice = ""
	}
	function setResolution(width, height) {
		const monitor = selectedMonitor, item = selectedItem
		if (!monitor || !item) return
		const options = Layout.scaleOptions(width, height, 0)
		const scale = Layout.clean(width, height, item.scale) ? item.scale
			: options.reduce((best, option) => Math.abs(option.value - item.scale) < Math.abs(best - item.scale) ? option.value : best, 1)
		update({width: width, height: height, refresh: Layout.closestRefresh(monitor.modes, width, height, item.refresh), scale: scale})
	}
	function setRefresh(value) { update({refresh: value}) }
	function setScale(value) { update({scale: value}) }
	function setTransform(value) { update({transform: value}) }
	function move(name, x, y) {
		if (applying || waiting) return
		const spot = Layout.snap(draft, name, x, y)
		if (!spot) return
		const items = Layout.copy(draft)
		Object.assign(items.find(item => item.name === name), spot)
		draft = items
		outcome = ""; error = ""; notice = ""
	}
	function place(name, direction) {
		const spot = Layout.place(draft, name, direction)
		if (spot) move(name, spot.x, spot.y)
	}
	function setPrimary(enabled) {
		if (applying || waiting || !selected) return
		primary = enabled ? selected : primary === selected ? "" : primary
		outcome = ""
	}
	function cancel() {
		if (applying || waiting) return
		draft = Layout.copy(current); primary = savedPrimary
		error = ""; outcome = ""; notice = ""
	}
	function apply() {
		if (!canApply) return
		const plan = {monitors: draft.map(item => ({name: item.name, width: item.width, height: item.height, refresh: item.refresh,
			scale: item.scale, transform: item.transform, x: item.x, y: item.y})), primary: primary}
		error = ""; outcome = ""; notice = ""
		requesting = true
		applier.command = ["python3", root.script, "apply", JSON.stringify(plan)]
		applier.running = true
	}
	function answer(decision) {
		if (answerer.running) return
		answerer.command = ["python3", root.script, decision]
		answerer.running = true
	}
	function keep() { if (waiting) answer("keep") }
	function revert() { if (waiting) answer(stale ? "restore" : "revert") }
	function readStatus(view) {
		let data = {}
		try { data = JSON.parse(view.text()) || {} } catch (_) { data = {} }
		const active = ["starting", "applying", "waiting"].indexOf(data.state) >= 0
		if (active) followed = data.id
		// A final state is reported once, for the change this shell started or watched.
		if (!active && data.id && data.id === followed && status.state !== data.state) {
			followed = ""
			outcome = Layout.outcomeText(data, data.linked)
			if (data.state === "restore-failed") error = outcome
			refresh()
		}
		status = data
	}

	Process {
		id: lister
		command: ["python3", root.script, "list"]
		stdout: SplitParser {
			onRead: data => {
				try { root.receive(JSON.parse(data)); root.error = root.error === Layout.errorText("HyprctlFailed") ? "" : root.error }
				catch (_) { root.error = "모니터 정보를 해석하지 못했습니다." }
			}
		}
		stderr: SplitParser { onRead: data => root.error = Layout.errorText(data) }
		onExited: code => { root.loading = false; if (code !== 0 && !root.error) root.error = "모니터 정보를 읽지 못했습니다." }
	}
	Timer { id: refreshAgain; interval: 300; onTriggered: root.refresh() }
	Process {
		id: applier
		stdout: SplitParser {
			onRead: data => {
				let result = {}
				try { result = JSON.parse(data) } catch (_) {}
				if (result.state === "starting") root.followed = result.id
				else if (result.state === "kept") { root.outcome = "주 디스플레이를 저장했습니다. 다음 로그인부터 적용됩니다."; root.refresh() }
			}
		}
		stderr: SplitParser {
			onRead: data => {
				root.error = Layout.errorText(data)
				if (["MonitorNotConnected", "MonitorSetChanged"].indexOf(data) >= 0) root.refresh()
			}
		}
		onExited: code => { root.requesting = false; statusFile.reload(); if (code !== 0 && !root.error) root.error = Layout.errorText("") }
	}
	Process {
		id: answerer
		stderr: SplitParser { onRead: data => root.error = Layout.errorText(data) }
		onExited: statusFile.reload()
	}
	// The guard replaces this file atomically, so it is polled; quickly only while a change is open.
	FileView {
		id: statusFile; path: root.runtimeDir ? root.runtimeDir + "/shittim/display-status.json" : ""; printErrors: false
		onLoaded: root.readStatus(statusFile)
		onLoadFailed: root.status = ({})
	}
	Timer {
		interval: root.applying || root.waiting ? 250 : 2000; running: true; repeat: true
		onTriggered: { root.now = Date.now(); statusFile.reload() }
	}
	Connections {
		target: Hyprland
		function onRawEvent(event) {
			if ((root.active || root.waiting) && ["monitoradded", "monitoraddedv2", "monitorremoved", "monitorremovedv2", "configreloaded"].indexOf(event.name) >= 0)
				refreshAgain.restart()
		}
	}
	IpcHandler {
		target: "display"
		function status(): string {
			return JSON.stringify({ready: root.ready, monitors: root.editable.map(monitor => monitor.name), dirty: root.dirty, problem: root.problem,
				state: root.status.state || "", remaining: root.remaining, linked: root.linked, error: root.error})
		}
		function refresh(): void { root.refresh() }
	}
}
