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
		id: microphoneFixture
		property bool available: false
		property bool validVolume: false
		property bool muted: false
		property bool inUse: false
		property string deviceName: "입력 장치 없음"
		property var source: null
		property var inputs: []
		property var applications: []
		function setVolume(value) {}
		function toggleMute() { muted = !muted }
		function selectInput(node) { source = node }
	}
	QtObject {
		id: cameraFixture
		property bool ready: true
		property bool present: cameras.length > 0
		property bool inUse: cameras.some(camera => camera.users.length > 0)
		property string error: ""
		property var cameras: []
		property int restarted: 0
		function restart() { restarted += 1 }
	}
	QtObject {
		id: shareFixture
		property int count: 0
		property bool active: count > 0
	}
	QtObject {
		id: networkFixture
        function retain(consumer) {}
        function release(consumer) {}
        function openEditor() {}
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
		id: notificationsFixture
		property bool available: true
		property bool dnd: false
		function toggleDnd() { dnd = !dnd }
	}
	QtObject {
		id: systemFixture
        function retain(consumer) {}
        function release(consumer) {}
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
			audio: audioFixture; network: networkFixture; battery: batteryFixture; bluetooth: systemFixture; brightness: systemFixture; power: systemFixture; capture: systemFixture; metrics: systemFixture
			onNavigate: destination => page = destination
		}
	}
	Component {
		id: meetingFactory
		ControlContent {
			width: 440; height: 720
			audio: audioFixture; network: networkFixture; battery: batteryFixture; bluetooth: systemFixture; brightness: systemFixture; power: systemFixture; capture: systemFixture; metrics: systemFixture
			microphone: microphoneFixture; camera: cameraFixture; screenShare: shareFixture
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
		microphoneFixture.available = false; microphoneFixture.validVolume = false; microphoneFixture.muted = false; microphoneFixture.inUse = false
		microphoneFixture.source = null; microphoneFixture.inputs = []; microphoneFixture.applications = []
		cameraFixture.ready = true; cameraFixture.cameras = []; cameraFixture.error = ""; cameraFixture.restarted = 0; shareFixture.count = 0
	}
	function meetingFixtures() {
		microphoneFixture.inputs = [{name: "test-mic", description: "검사용 마이크", nickname: "", ready: true, audio: {volume: 0.6, muted: false}}]
		microphoneFixture.source = microphoneFixture.inputs[0]; microphoneFixture.available = true; microphoneFixture.validVolume = true
		microphoneFixture.deviceName = "검사용 마이크"; microphoneFixture.inUse = true; microphoneFixture.applications = ["Google Chrome"]
		cameraFixture.cameras = [{node: "video0", name: "검사용 카메라", users: ["chrome"], error: ""}]
		shareFixture.count = 1
	}
	function test_meetingPages_data() {
		return ["overview", "audio", "devices"].map(page => ({tag: page, page: page}))
	}
	function test_meetingPages(data) {
		for (const populated of [false, true]) {
			if (populated) meetingFixtures()
			const content = createTemporaryObject(meetingFactory, testCase, {page: data.page})
			verify(content !== null)
			wait(20)
		}
	}
	function test_devicesPageReportsObservedStateOnly() {
		const content = createTemporaryObject(meetingFactory, testCase, {page: "devices"})
		compare(findChild(content, "devicesMicrophoneStatus").text, "입력 장치 없음")
		compare(findChild(content, "devicesCameraEmpty").visible, true)
		compare(findChild(content, "devicesShareStatus").text, "공유하지 않음")
		cameraFixture.ready = false
		compare(findChild(content, "devicesCameraEmpty").visible, false)
		meetingFixtures()
		verify(findChild(content, "devicesMicrophoneStatus").text.indexOf("사용 중") === 0)
		verify(findChild(content, "devicesMicrophoneStatus").text.indexOf("Google Chrome") > 0)
		compare(findChild(content, "devicesShareStatus").text, "공유 중")
		microphoneFixture.muted = true
		verify(findChild(content, "devicesMicrophoneStatus").text.indexOf("음소거") === 0)
	}
	function test_meetingTileOpensDevicesAndShowsActivity() {
		const content = createTemporaryObject(meetingFactory, testCase, {width: 337, height: 293})
		const tile = findChild(content, "quick-devices")
		compare(tile.active, false)
		shareFixture.count = 1
		compare(tile.active, true)
		compare(tile.info.title, "회의 장치")
		compare(tile.info.rows.map(row => row.status), ["사용 안 함", "사용 안 함", "사용 중"])
		microphoneFixture.inUse = true; microphoneFixture.muted = true
		compare(tile.info.rows[0].status, "음소거")
		// The detailed card replaces the default Qt tooltip and appears on hover.
		mouseMove(tile, tile.width / 2, tile.height / 2)
		const tip = findChild(tile, "tileTip")
		tryVerify(() => tip.visible, 2000)
		mouseClick(tile, tile.width / 2, tile.height / 2)
		compare(content.page, "devices")
	}
	function test_audioPageMicrophoneControls() {
		meetingFixtures()
		const content = createTemporaryObject(meetingFactory, testCase, {page: "audio"})
		const level = findChild(content, "microphoneLevel")
		verify(level !== null)
		compare(level.available, true)
		compare(level.muted, false)
		microphoneFixture.toggleMute()
		compare(level.muted, true)
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
		const meeting = findChild(content, "quick-devices")
		const settings = findChild(content, "quick-settings")
		verify(meeting !== null && settings !== null)
		compare(meeting.x, 18); compare(meeting.y, 173)
		compare(settings.x, 230); compare(settings.y, 232)
		compare(meeting.interactive, true)
		compare(findChild(content, "quick-dnd").interactive, false)
		compare(findChild(content, "quick-dark").interactive, false)
		compare(findChild(content, "overviewVolume").width, 217)
	}
	function test_narrow_overview_preserves_text_target_sizes_without_scaling(){
		const content=createTemporaryObject(contentFactory,testCase,{width:300,height:180})
		const tile=findChild(content,"quick-settings"),slider=findChild(content,"overviewVolume")
		compare(tile.scale,1);compare(slider.scale,1);verify(tile.width>=70);verify(slider.height>=24)
		const viewport=findChild(content,"controlViewport");verify(viewport.contentHeight>viewport.height)
	}
	function test_sharedDndToggleKeepsReferenceGrid() {
		const content = createTemporaryObject(contentFactory, testCase, {width: 337, height: 293, notifications: notificationsFixture})
		const tile = findChild(content, "quick-dnd")
		compare(tile.x, 124); compare(tile.y, 173); compare(tile.interactive, true)
		notificationsFixture.dnd = false; compare(tile.active, false)
		mouseClick(tile, tile.width / 2, tile.height / 2)
		compare(notificationsFixture.dnd, true); compare(tile.active, true)
		notificationsFixture.dnd = false; compare(tile.active, false)
		notificationsFixture.available = false; compare(tile.interactive, false)
		notificationsFixture.available = true
	}
	function test_dashboardEmbeddedControlsKeepBrightnessAndEscape() {
		populatedFixtures()
		const content = createTemporaryObject(contentFactory, testCase, {page: "brightness", embedded: true, width: 589, height: 272})
		compare(findChild(content, "controlHeader").visible, false)
		compare(findChild(content, "levelSlider").enabled, true)
		closeSpy.target = content
		content.forceActiveFocus(); keyClick(Qt.Key_Escape); compare(closeSpy.count, 1)
		content.embedded = false; compare(findChild(content, "controlHeader").visible, true)
	}
}
