import QtQuick
import QtTest
import "../components/control"
import "../core/AudioData.js" as Audio

TestCase {
	id: testCase
	name: "AudioSettings"
	width: 640; height: 320; visible: true; when: windowShown

	function node(id, name, description, props, volume, muted) {
		return {id: id, name: name, description: description, properties: props || {}, ready: true,
			audio: {volume: volume === undefined ? 0.5 : volume, muted: !!muted, volumes: [0.5, 0.5], channels: [3, 4]}}
	}
	// Device nodes shaped like real PipeWire nodes: ALSA speaker, HDMI, USB headset and Bluetooth.
	readonly property var speaker: node(40, "alsa_output.pci-0000_00_1f.3.analog-stereo", "내장 스피커", {"object.serial": "40"})
	readonly property var hdmi: node(41, "alsa_output.pci-0000_00_1f.3.hdmi-stereo", "HDMI 출력", {"object.serial": "41"})
	readonly property var headset: node(42, "alsa_output.usb-Logitech_G435-00.analog-stereo", "G435", {"object.serial": "42", "device.bus": "usb"})
	readonly property var buds: node(43, "bluez_output.AA_BB.1", "Galaxy Buds", {"object.serial": "43", "device.api": "bluez5"})
	readonly property var mic: node(50, "alsa_input.pci-0000_00_1f.3.analog-stereo", "내장 마이크", {})

	QtObject {
		id: audioFixture
		property var outputs: [testCase.speaker, testCase.headset]
		property var sink: testCase.speaker
		property bool available: true
		property bool validVolume: true
		property bool muted: false
		property string deviceName: "내장 스피커"
		property var balance: 0
		property bool routing: false
		property string error: ""
		property var applications: []
		property var calls: []
		function selectOutput(node) { calls = calls.concat([["output", node.id]]) }
		function setVolume(v) { calls = calls.concat([["volume", v]]) }
		function toggleMute() { calls = calls.concat([["mute"]]) }
		function setBalance(v) { calls = calls.concat([["balance", v]]) }
		function setApplicationVolume(app, v) { calls = calls.concat([["appVolume", app.key, v]]) }
		function toggleApplicationMute(app) { calls = calls.concat([["appMute", app.key]]) }
		function moveApplication(app, node) { calls = calls.concat([["move", app.key, node === null ? "default" : node.id]]) }
	}
	QtObject {
		id: micFixture
		property var inputs: [testCase.mic]
		property var source: testCase.mic
		property bool available: true
		property bool validVolume: true
		property bool muted: false
		property string deviceName: "내장 마이크"
		property bool inUse: false
		property var applications: []
		property real level: 0
		property bool levelActive: watchers.length > 0
		property var watchers: []
		property string error: ""
		property var calls: []
		function watchLevel(c) { if (watchers.indexOf(c) < 0) watchers = watchers.concat([c]) }
		function unwatchLevel(c) { watchers = watchers.filter(item => item !== c) }
		function selectInput(node) { calls = calls.concat([["input", node.id]]) }
		function setVolume(v) { calls = calls.concat([["volume", v]]) }
		function toggleMute() { calls = calls.concat([["mute"]]) }
	}
	Component { id: pageFactory; AudioSettingsPage { audio: audioFixture; microphone: micFixture } }
	// ListView makes its rows after layout; wait for the one asked for.
	function option(page, index) {
		let row = null
		tryVerify(() => (row = findChild(page, "hudOption-" + index)) !== null, 1000)
		return row
	}
	function scrollTo(page, item) {
		const viewport = findChild(page, "audioViewport")
		viewport.contentY = Math.min(viewport.contentHeight - viewport.height, Math.max(0, item.mapToItem(viewport.contentItem, 0, 0).y - 20))
		wait(0)
	}

	function init() {
		audioFixture.calls = []; micFixture.calls = []; micFixture.watchers = []; audioFixture.error = ""
		audioFixture.outputs = [speaker, headset]; audioFixture.applications = []; micFixture.inUse = false; micFixture.level = 0
	}

	function test_deviceKindsFromRealProperties() {
		compare(Audio.kind(speaker, false).label, "스피커")
		compare(Audio.kind(hdmi, false).label, "HDMI·DisplayPort")
		compare(Audio.kind(headset, false).label, "USB")
		compare(Audio.kind(buds, false).label, "Bluetooth")
		compare(Audio.kind(mic, true).label, "마이크")
		compare(Audio.kind(node(1, "x", "y", {"device.form-factor": "headset"}), false).label, "헤드셋")
	}
	function test_balanceKeepsTheLouderSide() {
		compare(Audio.balance([0.8, 0.8], [0], [1]), 0)
		compare(Audio.balance([0.4, 0.8], [0], [1]), 0.5)
		compare(Audio.balance([0.5], [], [0]), null)
		compare(Audio.balanced([0.8, 0.8], [0], [1], 0.5), [0.4, 0.8])
		compare(Audio.balanced([0.4, 0.8], [0], [1], -1), [0.8, 0])
		compare(Audio.balanceLabel(0), "가운데"); compare(Audio.balanceLabel(-0.2), "왼쪽 20%"); compare(Audio.balanceLabel(null), "지원 안 함")
	}
	function test_streamsGroupPerApplication() {
		const chrome1 = node(60, "Chromium", "Chrome", {"application.name": "Google Chrome", "application.process.binary": "chrome", "media.name": "YouTube"}, 0.3)
		const chrome2 = node(61, "Chromium", "Chrome", {"application.name": "Google Chrome", "application.process.binary": "chrome", "media.name": "Meet"}, 0.7, true)
		const anon = node(62, "stream-62", "", {}, 0.5, true)
		const apps = Audio.applications([chrome1, chrome2, anon], {60: speaker, 61: headset, 62: speaker})
		compare(apps.length, 2)
		const chrome = apps.find(app => app.key === "chrome")
		compare(chrome.name, "Google Chrome"); compare(chrome.icon, "chrome"); compare(chrome.streams.length, 2)
		compare(chrome.volume, 0.7); compare(chrome.muted, false); compare(chrome.target, null); compare(chrome.mixed, true)
		compare(chrome.detail, "스트림 2개")
		const unknown = apps.find(app => app.key === "stream-62")
		compare(unknown.name, "stream-62"); compare(unknown.muted, true); compare(unknown.target.id, 40)
		const pending = Audio.applications([chrome1], {})
		compare(pending[0].target, null); compare(pending[0].mixed, false)
	}
	function test_meterUsesDecibels() {
		compare(Audio.meter(0, 24), 0); compare(Audio.meter(NaN, 24), 0)
		compare(Audio.meter(1, 24), 24); compare(Audio.meter(0.001, 24), 0)
		compare(Audio.meter(0.1, 24), 16)
		compare(Audio.errorText("TargetNotFound\n"), "선택한 출력 장치가 연결 해제되었습니다.")
	}
	function test_outputDeviceChoiceByMouseAndKeyboard() {
		const page = createTemporaryObject(pageFactory, testCase)
		const field = findChild(page, "audioOutputDevice")
		mouseClick(field)
		const list = findChild(page, "hudOptions")
		verify(list.visible)
		mouseClick(option(page, 1))
		compare(audioFixture.calls[0], ["output", 42])
		verify(!list.visible)
		field.forceActiveFocus(); keyClick(Qt.Key_Return)
		verify(list.visible)
		keyClick(Qt.Key_Down); keyClick(Qt.Key_Return)
		compare(audioFixture.calls[1], ["output", 42])
		keyClick(Qt.Key_Return); keyClick(Qt.Key_Escape)
		verify(!list.visible); verify(field.activeFocus)
	}
	function test_volumeMuteAndEmptyStates() {
		const page = createTemporaryObject(pageFactory, testCase)
		const output = findChild(page, "audioOutputLevel")
		mouseClick(output.children[0])
		compare(audioFixture.calls[0], ["mute"])
		const slider = findChild(output, "audioSlider-출력 볼륨")
		mouseClick(slider, slider.width * 0.8, slider.height / 2)
		verify(audioFixture.calls[1][0] === "volume" && Math.abs(audioFixture.calls[1][1] - 0.8) < 0.06)
		audioFixture.outputs = []
		compare(findChild(page, "audioOutputDevice").enabled, false)
		compare(findChild(page, "audioOutputDevice").text, "연결된 출력 장치가 없습니다")
		audioFixture.error = "선택한 출력 장치가 연결 해제되었습니다."
		verify(findChild(page, "audioMessage").visible)
	}
	function test_levelIsMeasuredOnlyWhileAskedAndShown() {
		const page = createTemporaryObject(pageFactory, testCase)
		compare(micFixture.watchers.length, 0)
		const toggle = findChild(page, "audioLevelToggle")
		toggle.forceActiveFocus(); keyClick(Qt.Key_Space)
		compare(micFixture.watchers.length, 1)
		micFixture.level = 0.1
		compare(findChild(page, "audioInputMeter").lit, 16)
		page.visible = false
		compare(micFixture.watchers.length, 0)
		page.visible = true
		compare(micFixture.watchers.length, 1)
		page.destroy(); wait(0)
		compare(micFixture.watchers.length, 0)
	}
	function test_applicationRowsControlEveryStream() {
		const app = {key: "discord", name: "Discord", icon: "discord", detail: "", streams: [node(70, "d", "Discord", {})], volume: 0.4, muted: false, available: true, target: speaker, mixed: false}
		audioFixture.applications = [app]
		const page = createTemporaryObject(pageFactory, testCase)
		const output = findChild(page, "audioAppOutput-0")
		compare(output.text, "내장 스피커")
		scrollTo(page, output)
		mouseClick(output)
		mouseClick(option(page, 2))
		compare(audioFixture.calls[0], ["move", "discord", 42])
		mouseClick(output); mouseClick(option(page, 0))
		compare(audioFixture.calls[1], ["move", "discord", "default"])
		audioFixture.outputs = [speaker]
		compare(output.enabled, false)
	}
	function test_microphoneUseIsNotItsMute() {
		micFixture.inUse = true; micFixture.applications = ["Discord"]; micFixture.muted = true
		const page = createTemporaryObject(pageFactory, testCase)
		const header = findChild(page, "audioInput").children[1]
		compare(header.detail, "사용 중: Discord")
		micFixture.muted = false
	}
}
