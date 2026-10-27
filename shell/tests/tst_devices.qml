import QtQuick
import QtTest
import "../components"
import "../core/DeviceData.js" as Devices

TestCase {
	id: testCase
	name: "MeetingDevices"
	width: 300; height: 60; visible: true; when: windowShown
	readonly property var audio: ({volume: 0.5, muted: false})
	function node(fields) {
		return Object.assign({name: "", description: "", nickname: "", isSink: false, isStream: false, audio: null, properties: ({})}, fields)
	}
	QtObject { id: micFixture; property bool inUse: false; property bool muted: false; property var applications: [] }
	QtObject { id: cameraFixture; property bool inUse: false; property var applications: [] }
	QtObject { id: shareFixture; property bool active: false }
	Component { id: activityFactory; DeviceActivity { microphone: micFixture; camera: cameraFixture; screenShare: shareFixture } }
	function init() { failOnWarning(/.*/) }
	function cleanup() { micFixture.inUse = false; micFixture.muted = false; cameraFixture.inUse = false; shareFixture.active = false }

	function test_microphonesAreAudioSourcesOnly() {
		verify(Devices.isMicrophone(node({name: "alsa_input.usb", audio: audio})))
		verify(!Devices.isMicrophone(node({name: "alsa_output.pci", isSink: true, audio: audio})))
		verify(!Devices.isMicrophone(node({name: "chrome-input", isStream: true, audio: audio})))
		verify(!Devices.isMicrophone(node({name: "v4l2_input.camera"})))
		verify(!Devices.isMicrophone(null))
	}
	function test_recordingExcludesPeakMetersAndSinkMonitors() {
		const chrome = node({isStream: true, audio: audio, properties: {"application.name": "Google Chrome"}})
		verify(Devices.isRecording(chrome))
		compare(Devices.applicationName(chrome), "Google Chrome")
		verify(!Devices.isRecording(node({isStream: true, audio: audio, properties: {"stream.monitor": "true"}})))
		verify(!Devices.isRecording(node({isStream: true, audio: audio, properties: {"stream.capture.sink": "true"}})))
		verify(!Devices.isRecording(node({isStream: true, isSink: true, audio: audio})))
		compare(Devices.applicationNames([chrome, chrome, node({isStream: true, audio: audio, description: "OBS"})]), ["Google Chrome", "OBS"])
	}
	function test_screenCastMatchesPortalStreamsOnly() {
		verify(Devices.isScreenCast(node({name: "xdph-streaming-aB3dE"})))
		verify(!Devices.isScreenCast(node({name: "v4l2_input.pci-0000_00_14.0-usb-0_6_1.0"})))
		verify(!Devices.isScreenCast(node({name: "xdph-streaming-x", isStream: true})))
		verify(!Devices.isScreenCast(node({name: undefined})))
	}
	function test_activityIndicatorHiddenWhenIdle() {
		const activity = createTemporaryObject(activityFactory, testCase)
		compare(activity.visible, false)
		compare(activity.implicitWidth, 0)
		micFixture.applications = ["Google Chrome"]; micFixture.inUse = true
		compare(activity.visible, true)
		compare(findChild(activity, "activityMicrophone").visible, true)
		compare(findChild(activity, "activityCamera").visible, false)
		compare(activity.summary, "마이크 사용 중: Google Chrome")
		micFixture.muted = true; shareFixture.active = true
		compare(activity.summary, "마이크 사용 중(음소거): Google Chrome\n화면 공유 중")
		tryVerify(() => activity.implicitWidth > 0)
	}
}
