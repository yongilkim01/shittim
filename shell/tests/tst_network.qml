import QtQuick
import QtTest
import "../components/control"
import "../core/NetworkData.js" as NetworkData

TestCase {
	id: testCase
	name: "NetworkSettings"
	width: 640; height: 320; visible: true; when: windowShown

	// Shaped like Quickshell WifiNetwork objects and like scripts/network-service.py output (captured from a
	// NetworkManager 1.58 lab: veth links, DHCP v4, RA v6).
	function wifi(name, strength, connected, known, security) {
		return {name: name, signalStrength: strength, connected: !!connected, known: !!known, stateChanging: false, security: security || "wpa2-psk"}
	}
	readonly property var home: wifi("SHITTIM_HOME", 0.82, true, true)
	readonly property var city: wifi("City_Free_WiFi", 0.55, false, false, "open")
	readonly property var moon: wifi("Moonlight_5G", 0.41, false, true)
	readonly property string homeUuid: "c38186c4-4498-3bc4-8836-bd2fee63e3a8"
	readonly property string wiredUuid: "525abd2c-8122-3555-a319-ea92413e1b66"
	function profile(uuid, name, type, extra) {
		return Object.assign({uuid: uuid, name: name, type: type, interface: "", autoconnect: true, priority: 0, ssid: type === "wifi" ? name : "",
			keyMgmt: type === "wifi" ? "wpa-psk" : "", eap: false, hidden: false,
			ipv4: {method: "auto", addresses: [], gateway: "", dns: [], autoDns: true}, ipv6: {method: "auto", addresses: [], gateway: "", dns: [], autoDns: true},
			proxy: {method: "none", pacUrl: ""}}, extra || {})
	}
	readonly property var wlan: ({interface: "wlan0", type: "wifi", state: 100, hwAddress: "A4:F1:3C:9D:27:B8", driver: "mt7921e",
		connection: {uuid: homeUuid, name: "SHITTIM_HOME", state: 2},
		ip4: {addresses: [{address: "192.168.0.23", prefix: 24}], gateway: "192.168.0.1", dns: ["192.168.0.1"]},
		ip6: {addresses: [{address: "fe80::1", prefix: 64}], gateway: "", dns: []},
		accessPoints: [{ssid: "SHITTIM_HOME", strength: 82, frequency: 5180, band: "5GHz"}, {ssid: "SHITTIM_HOME", strength: 60, frequency: 2437, band: "2.4GHz"},
			{ssid: "Moonlight_5G", strength: 41, frequency: 5745, band: "5GHz"}]})
	readonly property var eth: ({interface: "enp3s0", type: "wired", state: 100, hwAddress: "8A:CF:A9:BA:F2:44", driver: "r8169", carrier: true, speed: 1000,
		connection: {uuid: wiredUuid, name: "Wired connection 1", state: 2},
		ip4: {addresses: [{address: "10.77.0.124", prefix: 24}], gateway: "10.77.0.1", dns: ["10.77.0.1"]}, ip6: {addresses: [], gateway: "", dns: []}})

	QtObject {
		id: networkFixture
		property bool backendAvailable: true
		property bool wifiEnabled: true
		property bool wifiBlocked: false
		property var wifiDevices: [{name: "wlan0", state: 2}]
		property var controlDevice: wifiDevices.length ? wifiDevices[0] : null
		property var networks: [testCase.home, testCase.city, testCase.moon]
		property bool wifiConnected: true
		property string ssid: "SHITTIM_HOME"
		property real signalStrength: 0.82
		property var wifiNetwork: testCase.home
		property string connectivity: "full"
		property bool scanning: true
		property bool busy: false
		property string error: ""
		property bool needsPassword: false
		property var pendingNetwork: null
		property var calls: []
		property var consumers: []
		function retain(c) { consumers = consumers.concat([c]) }
		function release(c) { consumers = consumers.filter(item => item !== c) }
		function securityCode(n) { return n ? n.security : "unknown" }
		function connectNetwork(n) { calls = calls.concat([["connect", n.name]]) }
		function submitPassword(p) { calls = calls.concat([["password", p.length]]) }
		function resetPrompt() { needsPassword = false; pendingNetwork = null; calls = calls.concat([["reset"]]) }
		function toggleWifi() { calls = calls.concat([["toggle"]]) }
		function refresh() { calls = calls.concat([["refresh"]]) }
		function openEditor() { calls = calls.concat([["editor"]]) }
	}
	QtObject {
		id: settingsFixture
		property bool available: true
		property var devices: [testCase.wlan, testCase.eth]
		property var connections: [testCase.profile(testCase.homeUuid, "SHITTIM_HOME", "wifi", {priority: 5}), testCase.profile(testCase.wiredUuid, "Wired connection 1", "wired")]
		property var state: ({checkTarget: "ping.archlinux.org"})
		property string error: ""
		property string notice: ""
		property bool busy: false
		property var checkpoint: null
		readonly property bool waiting: checkpoint !== null
		readonly property int remaining: waiting ? checkpoint.remaining : 0
		property var diagnosis: null
		property var calls: []
		property var shownBy: []
		property var permissions: ({})
		function retain(c) {}
		function release(c) {}
		function showing(c, visible) { shownBy = visible ? shownBy.concat([c]) : shownBy.filter(item => item !== c) }
		function device(name) { return devices.find(item => item.interface === name) || null }
		function profile(uuid) { return connections.find(item => item.uuid === uuid) || null }
		function profileForSsid(ssid) { return connections.find(item => item.type === "wifi" && item.ssid === ssid) || null }
		function needsAuthentication(p) { return permissions[p] === "auth" }
		function isPending(op, target) { return false }
		function activate(uuid, dev) { calls = calls.concat([["activate", uuid, dev]]) }
		function disconnectDevice(dev) { calls = calls.concat([["disconnect", dev]]) }
		function setAutoconnect(uuid, on, priority) { calls = calls.concat([["autoconnect", uuid, on, priority]]) }
		function remove(uuid) { calls = calls.concat([["delete", uuid]]) }
		function apply(uuid, request) { calls = calls.concat([["apply", uuid, request]]) }
		function keep() { calls = calls.concat([["keep"]]) }
		function revert() { calls = calls.concat([["revert"]]) }
		function diagnose(dev) { calls = calls.concat([["diagnose", dev]]) }
		function connectHidden(dev, ssid, sec, pw) { calls = calls.concat([["hidden", dev, ssid, sec, pw.length]]) }
	}
	QtObject {
		id: trafficFixture
		property var snapshot: ({network: {interface: "wlan0", down: 1048576, up: 2048, interfaces: [{name: "wlan0", down: 1048576, up: 2048}, {name: "enp3s0", down: 0, up: 0}]}})
		property var history: ({wlan0: [{time: 1, down: 10, up: 1}, {time: 2, down: 1048576, up: 2048}]})
	}
	Component { id: pageFactory; NetworkSettingsPage { network: networkFixture; settings: settingsFixture; traffic: trafficFixture } }

	function init() {
		networkFixture.calls = []; settingsFixture.calls = []; networkFixture.networks = [home, city, moon]; networkFixture.wifiEnabled = true
		networkFixture.wifiDevices = [{name: "wlan0", state: 2}]; networkFixture.needsPassword = false; networkFixture.pendingNetwork = null
		networkFixture.error = ""; settingsFixture.error = ""; settingsFixture.notice = ""; settingsFixture.checkpoint = null; settingsFixture.diagnosis = null
		settingsFixture.devices = [wlan, eth]; settingsFixture.permissions = ({})
	}
	function page() { const p = createTemporaryObject(pageFactory, testCase, {width: 589, height: 272}); verify(p); wait(0); return p }
	function child(p, name) { let item = null; tryVerify(() => (item = findChild(p, name)) !== null, 1000, name); return item }
	// Buttons low in the details column sit below the fold; scroll there before clicking, as a user would.
	function press(p, name) {
		const item = child(p, name)
		tryVerify(() => item.visible && item.enabled && item.width > 0, 1000, name + " ready")
		wait(20)
		for (const view of ["networkDetailView", "networkListView"]) {
			const v = findChild(p, view)
			let up = item.parent, inside = false
			while (up) { if (up === v.contentItem) { inside = true; break } up = up.parent }
			if (inside) { v.contentY = Math.max(0, Math.min(v.contentHeight - v.height, item.mapToItem(v.contentItem, 0, 0).y - 20)); wait(0) }
		}
		mouseClick(item)
	}

	// ---- Pure data --------------------------------------------------------------------------------------------
	function test_addressParsing() {
		verify(NetworkData.isIPv4("192.168.0.10")); verify(!NetworkData.isIPv4("192.168.0.256")); verify(!NetworkData.isIPv4("01.2.3.4")); verify(!NetworkData.isIPv4("1.2.3"))
		verify(NetworkData.isIPv6("fd77::1")); verify(NetworkData.isIPv6("::1")); verify(NetworkData.isIPv6("2001:db8:0:0:0:0:0:1")); verify(NetworkData.isIPv6("::ffff:192.0.2.1"))
		verify(!NetworkData.isIPv6("2001:db8::1::2")); verify(!NetworkData.isIPv6("12345::1")); verify(!NetworkData.isIPv6("1.2.3.4")); verify(!NetworkData.isIPv6("fe80::1%wlan0"))
		compare(NetworkData.parseIPv6("::ffff:192.0.2.1"), [0, 0, 0, 0, 0, 0xffff, 0xc000, 0x0201])
	}
	function test_validation() {
		const base = NetworkData.formFor(settingsFixture.connections[0])
		compare(base.ipv4Method, "auto"); compare(base.proxyMethod, "none")
		let result = NetworkData.validate(Object.assign({}, base, {ipv4Method: "manual", ipv4Address: "192.168.0.50", ipv4Prefix: "24", ipv4Gateway: "192.168.0.1", ipv4Dns: "1.1.1.1, 9.9.9.9"}))
		verify(result.ok)
		compare(result.request.ipv4, {method: "manual", dns: ["1.1.1.1", "9.9.9.9"], autoDns: false, address: "192.168.0.50", prefix: 24, gateway: "192.168.0.1"})
		result = NetworkData.validate(Object.assign({}, base, {ipv4Method: "manual", ipv4Address: "192.168.0.300", ipv4Prefix: "33", ipv4Gateway: "10.0.0.1"}))
		verify(!result.ok); verify(result.errors.ipv4Address); verify(result.errors.ipv4Prefix)
		result = NetworkData.validate(Object.assign({}, base, {ipv4Method: "manual", ipv4Address: "192.168.0.50", ipv4Prefix: "24", ipv4Gateway: "10.0.0.1"}))
		compare(result.errors.ipv4Gateway, "게이트웨이가 주소/프리픽스와 같은 네트워크에 있지 않습니다.")
		result = NetworkData.validate(Object.assign({}, base, {ipv4Dns: "1.1.1.1 nope", ipv6Dns: "1.1.1.1"}))
		verify(result.errors.ipv4Dns); verify(result.errors.ipv6Dns)
		result = NetworkData.validate(Object.assign({}, base, {ipv4AutoDns: false, ipv4Dns: ""}))
		verify(result.errors.ipv4Dns)
		result = NetworkData.validate(Object.assign({}, base, {proxyMethod: "auto", pacUrl: "javascript:alert(1)"}))
		verify(result.errors.pacUrl)
		result = NetworkData.validate(Object.assign({}, base, {ipv6Method: "manual", ipv6Address: "fd00::10", ipv6Prefix: "64", ipv6Gateway: "fd00::1"}))
		verify(result.ok); compare(result.request.ipv6.address, "fd00::10")
	}
	function test_labels() {
		compare(NetworkData.accessPoints(wlan, "SHITTIM_HOME"), {count: 2, bands: ["2.4GHz", "5GHz"], strongest: wlan.accessPoints[0]})
		compare(NetworkData.accessPoints(null, "x").count, 0)
		compare(NetworkData.deviceStateText({type: "wired", state: 20}), "케이블 연결 안 됨")
		compare(NetworkData.deviceStateText({type: "wifi", state: 70}), "연결 중")
		compare(NetworkData.speedText(1000), "1 Gb/s"); compare(NetworkData.speedText(0), "알 수 없음")
		compare(NetworkData.addressText([{address: "10.0.0.2", prefix: 24}, {address: "fe80::1", prefix: 64}]), "10.0.0.2/24")
		compare(NetworkData.securityLabel("sae"), "WPA3-Personal"); compare(NetworkData.connectivityText("portal"), "로그인 필요(포털)")
		compare(NetworkData.signalLabel(82), "매우 좋음"); compare(NetworkData.qualityText(undefined), "진단 전")
	}
	function test_diagnosisWording() {
		const report = {running: false, quality: "good", steps: {
			gateway: {target: "10.77.0.1", result: {sent: 4, received: 4, loss: 0, latency: 0.4}},
			dns: {target: "ping.archlinux.org", skipped: false, servers: [{server: "10.77.0.1", ok: true, latency: 1}, {server: "fd77::1", ok: false, latency: null}]},
			internet: {target: "ping.archlinux.org", connectivity: "full", result: {sent: 5, received: 5, loss: 0, latency: 12.5}}}}
		compare(NetworkData.diagnosisStep(report, "gateway"), {state: "ok", text: "0.4 ms · 손실 0%"})
		compare(NetworkData.diagnosisStep(report, "dns"), {state: "warn", text: "1/2 응답 · 1 ms"})
		compare(NetworkData.diagnosisStep(report, "internet"), {state: "ok", text: "정상 · 12.5 ms · 손실 0%"})
		compare(NetworkData.diagnosisStep({running: true, steps: {}}, "dns").state, "wait")
		compare(NetworkData.diagnosisStep({steps: {gateway: {target: "", result: null}}}, "gateway").state, "skip")
		compare(NetworkData.errorText("PermissionDenied"), "권한이 없거나 관리자 인증이 취소되었습니다.")
	}

	// ---- Page ---------------------------------------------------------------------------------------------------
	function test_wifiListAndJoin() {
		const p = page()
		verify(settingsFixture.shownBy.indexOf(p) >= 0)
		verify(networkFixture.consumers.indexOf(networkFixture.consumers[0]) >= 0)
		compare(child(p, "networkRow-0").title, "SHITTIM_HOME")
		compare(child(p, "networkRow-0").detail, "연결됨 · 2.4GHz · 5GHz · AP 2개")
		verify(child(p, "networkRow-0").selected)
		compare(child(p, "networkRow-1").locked, false)
		mouseClick(child(p, "networkRow-1"))
		compare(networkFixture.calls, [["connect", "City_Free_WiFi"]])
		const search = child(p, "networkSearch")
		search.text = "moon"; wait(0)
		compare(child(p, "networkRow-0").title, "Moonlight_5G")
		verify(findChild(p, "networkRow-1") === null)
		search.text = "zzz"; wait(0)
		verify(findChild(p, "networkRow-0") === null)
		mouseClick(child(p, "networkRefresh"))
		compare(networkFixture.calls[networkFixture.calls.length - 1], ["refresh"])
	}
	function test_connectedDetailsComeFromTheDevice() {
		const p = page()
		const details = child(p, "networkDetails")
		const texts = []
		const walk = item => { for (const c of item.children) { if (c.text !== undefined && c.visible) texts.push(String(c.text)); walk(c) } }
		walk(details)
		verify(texts.indexOf("192.168.0.23/24") >= 0, texts.join("|"))
		verify(texts.indexOf("192.168.0.1") >= 0)
		verify(texts.indexOf("A4:F1:3C:9D:27:B8") >= 0)
		verify(texts.indexOf("wlan0 (mt7921e)") >= 0)
		compare(child(p, "networkDown").text, "1.0 MiB/s")
		compare(child(p, "networkTrafficGraph").samples.length, 2)
		compare(child(p, "networkPriority").text, "5")
		press(p, "networkPriorityUp")
		compare(settingsFixture.calls, [["autoconnect", homeUuid, true, 6]])
	}
	function test_editorValidatesBeforeApplying() {
		const p = page()
		press(p, "networkEditIp")
		verify(child(p, "networkEditor").visible)
		mouseClick(child(p, "networkMethod4-manual"))
		const address = child(p, "networkAddress4")
		address.text = "192.168.0.300"; address.textEdited()
		mouseClick(child(p, "networkEditorApply"))
		compare(settingsFixture.calls, [])
		verify(child(p, "networkEditor").visible)
		address.text = "192.168.0.50"; address.textEdited()
		const gateway = child(p, "networkGateway4")
		gateway.text = "192.168.0.1"; gateway.textEdited()
		mouseClick(child(p, "networkEditorApply"))
		compare(settingsFixture.calls.length, 1)
		compare(settingsFixture.calls[0][0], "apply"); compare(settingsFixture.calls[0][1], homeUuid)
		compare(settingsFixture.calls[0][2].ipv4.address, "192.168.0.50"); compare(settingsFixture.calls[0][2].ipv4.prefix, 24)
		verify(!child(p, "networkEditor").visible)
	}
	function test_keepOrRestore() {
		const p = page()
		settingsFixture.checkpoint = {name: "SHITTIM_HOME", uuid: homeUuid, remaining: 27}
		const card = child(p, "networkConfirmInPage")
		tryVerify(() => card.visible)
		verify(child(p, "networkConfirmText").text.indexOf("27초") >= 0)
		mouseClick(child(p, "networkKeep"))
		mouseClick(child(p, "networkRevert"))
		compare(settingsFixture.calls, [["keep"], ["revert"]])
	}
	function test_deleteNamesTheProfile() {
		const p = page()
		p.tab = "saved"; wait(0)
		compare(child(p, "networkProfile-0").title, "SHITTIM_HOME")
		mouseClick(child(p, "networkProfile-1"))
		press(p, "networkDelete")
		const dialog = child(p, "networkDeleteDialog")
		verify(dialog.visible)
		mouseClick(child(p, "networkDeleteConfirm"))
		compare(settingsFixture.calls, [["delete", wiredUuid]])
	}
	function test_wiredTabAndEmptyStates() {
		const p = page()
		p.tab = "wired"; wait(0)
		compare(child(p, "networkWired-0").title, "enp3s0 · Wired connection 1")
		compare(child(p, "networkWired-0").detail, "연결됨 · 1 Gb/s")
		press(p, "networkConnect")
		compare(settingsFixture.calls, [["disconnect", "enp3s0"]])
		settingsFixture.devices = [wlan]; wait(0)
		verify(findChild(p, "networkWired-0") === null)
		p.tab = "wifi"; networkFixture.wifiDevices = []; wait(0)
		compare(child(p, "networkWifiState").text, "Wi-Fi 장치가 없습니다. 유선 탭을 사용하세요.")
		verify(!child(p, "networkWifiToggle").enabled)
	}
	function test_passwordDialog() {
		const p = page()
		networkFixture.pendingNetwork = moon; networkFixture.needsPassword = true
		const dialog = child(p, "networkPasswordDialog")
		tryVerify(() => dialog.visible)
		const field = child(p, "networkPassword")
		compare(field.echoMode, TextInput.Password)
		mouseClick(child(p, "networkReveal"))
		compare(field.echoMode, TextInput.Normal)
		field.text = "short"; wait(0)
		verify(!child(p, "networkPasswordConnect").enabled)
		field.text = "correct horse"; wait(0)
		mouseClick(child(p, "networkPasswordConnect"))
		compare(networkFixture.calls, [["password", 13]])
		compare(field.text, "")
	}
	function test_diagnosisIsOnDemand() {
		const p = page()
		compare(settingsFixture.calls, [])
		press(p, "networkDiagnose")
		compare(settingsFixture.calls, [["diagnose", "wlan0"]])
		settingsFixture.diagnosis = {running: true, steps: {}}
		tryVerify(() => child(p, "networkDiagnose").text === "진단 중…")
		verify(!child(p, "networkDiagnose").enabled)
	}
	function test_wifiToggleAndBlocked() {
		const p = page()
		mouseClick(child(p, "networkWifiToggle"))
		compare(networkFixture.calls, [["toggle"]])
		networkFixture.wifiBlocked = true; wait(0)
		compare(child(p, "networkWifiState").text, "하드웨어 스위치(비행기 모드)로 꺼져 있습니다.")
		verify(!child(p, "networkWifiToggle").enabled)
		networkFixture.wifiBlocked = false
	}
}
