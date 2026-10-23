import QtQuick
import QtTest
import "../components/control"
import "../ui"

TestCase {
	id: testCase
	name: "ControlCenterView"
	width: 500; height: 780; visible: true; when: windowShown
	// View-only fixtures. Production passes the real Quickshell services.
	QtObject {
		id: audioFixture
		property bool available: false
		property bool validVolume: false
		property bool muted: false
		property string deviceName: "출력 장치 없음"
		property var sink: null
		property var outputs: []
		property var streams: []
		property real lastValue: -1
		function setVolume(value) { lastValue = value }
		function toggleMute() { muted = !muted }
		function selectOutput(node) { sink = node }
	}
	QtObject {
		id: networkFixture
		property bool backendAvailable: false
		property bool wifiEnabled: false
		property bool wifiConnected: false
		property bool wiredConnected: false
		property bool needsPassword: false
		property string ssid: ""
		property string error: ""
		property var wifiDevices: []
		property var wiredDevices: []
		property var networks: []
		property var pendingNetwork: null
		property var controlDevice: null
		property var selectedDevice: null
		function toggleWifi() { wifiEnabled = !wifiEnabled }
		function refresh() {}
		function submitPassword(value) { needsPassword = false }
		function resetPrompt() { needsPassword = false; pendingNetwork = null }
		function connectNetwork(value) { pendingNetwork = value }
	}
	QtObject {
		id: batteryFixture
		property bool available: false
		property bool validPercentage: false
		property bool lowBattery: false
		property bool charging: false
		property bool fullyCharged: false
		property int percentage: 0
		property string status: "N/A"
		property var battery: null
	}
	QtObject {
		id: systemFixture
		property string error: ""
		property bool ready: true
		property bool busy: false
		property bool bluetoothReady: false
		property var adapter: null
		property var adapters: []
		property var devices: []
		property var backlight: null
		property var backlights: []
		property var profiles: []
		property string profile: ""
		property var prompt: null
		property int cpu: -1
		property int memory: -1
		property int uptime: 0
		property bool screenshotAvailable: false
		function takeScreenshot() {}
		function toggleBluetooth() {}
		function searchBluetooth() {}
		function stopDiscovery() {}
		function deviceAction(device) {}
		function answerPrompt(accept, value) { prompt = null }
		function cancelPair() { prompt = null }
		function setBrightness(value) {}
		function setProfile(value) { profile = value }
		function refresh() {}
		function openNetworkEditor() {}
	}
	Component {
		id: contentFactory
		ControlContent {
			width: 440; height: 720
			audio: audioFixture; network: networkFixture; battery: batteryFixture; system: systemFixture
			onNavigate: destination => page = destination
		}
	}
	Component { id: levelFactory; LevelControl { width: 380; value: 0.5 } }
	SignalSpy { id: closeSpy; signalName: "closeRequested" }
	function init() { failOnWarning(/.*/) }
	function cleanup() {
		networkFixture.needsPassword = false; networkFixture.pendingNetwork = null; networkFixture.networks = []; networkFixture.wifiDevices = []
		audioFixture.available = false; audioFixture.validVolume = false; audioFixture.outputs = []; audioFixture.streams = []; audioFixture.sink = null
		systemFixture.adapter = null; systemFixture.adapters = []; systemFixture.devices = []; systemFixture.backlight = null; systemFixture.backlights = []; systemFixture.profiles = []
		systemFixture.prompt = null; systemFixture.error = ""; systemFixture.busy = false; closeSpy.target = null; closeSpy.clear()
	}
	function populatedFixtures() {
		audioFixture.outputs = [{name: "test-output", description: "검사용 출력 장치", nickname: "", ready: true, audio: {volume: 0.7, muted: false}}]
		audioFixture.sink = audioFixture.outputs[0]; audioFixture.available = true; audioFixture.validVolume = true
		audioFixture.streams = [{name: "test-stream", description: "검사용 재생 스트림", ready: true, audio: {volume: 0.4, muted: false}}]
		networkFixture.wifiEnabled = true; networkFixture.backendAvailable = true
		networkFixture.wifiDevices = [{name: "test-wifi"}]
		networkFixture.networks = [{name: "공백 <태그> & 긴 한글 SSID", known: true, signalStrength: 0.7, connected: true, stateChanging: false}]
		systemFixture.adapter = {name: "test-adapter", enabled: true, discovering: false}
		systemFixture.devices = [{name: "검사용 Bluetooth 장치", paired: true, connected: true, pairing: false, batteryAvailable: true, battery: 0.8}]
		systemFixture.backlights = [{name: "test-backlight", value: 0.6, writable: true}]; systemFixture.backlight = systemFixture.backlights[0]
		systemFixture.profiles = ["power-saver", "balanced", "performance"]; systemFixture.profile = "balanced"
	}
	function test_populatedPages_data() { return test_pagesWithoutHardware_data() }
	function test_populatedPages(data) {
		populatedFixtures()
		const content = createTemporaryObject(contentFactory, testCase, {page: data.page, width: 320, height: 440})
		verify(content !== null)
		wait(20)
	}
	function test_pagesWithoutHardware_data() {
		return ["overview", "wifi", "bluetooth", "audio", "brightness", "power", "settings"].map(page => ({tag: page, page: page}))
	}
	function test_pagesWithoutHardware(data) {
		const content = createTemporaryObject(contentFactory, testCase, {page: data.page})
		verify(content !== null)
		wait(20)
		const viewport = findChild(content, "controlViewport")
		verify(viewport.width > 0)
		verify(viewport.contentWidth <= viewport.width)
		verify(viewport.contentHeight > 0)
	}
	function test_smallScreenScrollAndEscape() {
		const content = createTemporaryObject(contentFactory, testCase, {width: 320, height: 180})
		closeSpy.target = content
		const viewport = findChild(content, "controlViewport")
		wait(20)
		verify(viewport.contentHeight > viewport.height)
		compare(viewport.contentWidth, viewport.width)
		content.forceActiveFocus()
		keyClick(Qt.Key_Escape)
		compare(closeSpy.count, 1)
	}
	function test_passwordClearedWhenPromptCloses() {
		networkFixture.pendingNetwork = {name: "한글 <SSID> 공백 & 특수문자"}
		networkFixture.needsPassword = true
		const content = createTemporaryObject(contentFactory, testCase, {page: "wifi"})
		const field = findChild(content, "wifiPassword")
		verify(field !== null)
		compare(field.echoMode, TextInput.Password)
		field.text = "fixture-value"
		networkFixture.needsPassword = false
		tryCompare(field, "text", "")
	}
	function test_sliderFollowsExternalChanges() {
		const level = createTemporaryObject(levelFactory, testCase)
		const slider = findChild(level, "levelSlider")
		verify(slider !== null)
		compare(slider.value, 0.5)
		level.value = 0.8
		tryCompare(slider, "value", 0.8)
		level.value = 5
		tryCompare(slider, "value", 1)
	}
	function test_brightnessRemainsInteractiveWhileRequestIsPending_data() {
		return [{tag: "overview", page: "overview", slider: "overviewBrightness"},
			{tag: "detail", page: "brightness", slider: "levelSlider"}]
	}
	function test_brightnessRemainsInteractiveWhileRequestIsPending(data) {
		populatedFixtures()
		const content = createTemporaryObject(contentFactory, testCase, {page: data.page})
		const slider = findChild(content, data.slider)
		verify(slider !== null)
		compare(slider.enabled, true)
		systemFixture.busy = true
		compare(slider.enabled, true)
		systemFixture.backlight = {name: "test-backlight", value: 0.32, writable: false}
		compare(slider.enabled, false)
	}
	function test_referenceGridAndUnavailableControls() {
		const content = createTemporaryObject(contentFactory, testCase, {width: 337, height: 293})
		const cast = findChild(content, "quick-cast")
		const settings = findChild(content, "quick-settings")
		verify(cast !== null && settings !== null)
		compare(cast.x, 18); compare(cast.y, 173)
		compare(settings.x, 230); compare(settings.y, 232)
		compare(cast.interactive, false)
		compare(findChild(content, "quick-dnd").interactive, false)
		compare(findChild(content, "quick-dark").interactive, false)
		compare(findChild(content, "overviewVolume").width, 217)
	}
}
