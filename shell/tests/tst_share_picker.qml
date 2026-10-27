import QtQuick
import QtTest
import "../components/sharepicker"
import "../components/sharepicker/PickerData.js" as PickerData

TestCase {
	id: testCase
	name: "SharePicker"
	width: 800; height: 560; visible: true; when: windowShown
	Component { id: viewFactory; SharePickerView { width: 760; height: 520; focus: true } }
	SignalSpy { id: chosenSpy; signalName: "chosen" }
	SignalSpy { id: cancelSpy; signalName: "cancelled" }
	function init() { failOnWarning(/.*/) }
	function cleanup() { chosenSpy.clear(); cancelSpy.clear() }

	function test_windowListProtocol() {
		const list = "93[HC>]google-chrome[HT>]Meet - abc[HE>]94367253418[HA>]17[HC>]kitty[HT>][HE>]0[HA>]x[HC>]bad[HT>]t[HE>]1[HA>]"
		compare(PickerData.parseWindows(list), [
			{id: "93", appClass: "google-chrome", title: "Meet - abc", address: "94367253418"},
			{id: "17", appClass: "kitty", title: "", address: "0"}])
		compare(PickerData.parseWindows(""), [])
		compare(PickerData.parseWindows(undefined), [])
	}
	function test_outputListProtocol() {
		compare(PickerData.parseOutputs("5:eDP-1:0:0:1280:720;8:HDMI-A-1:1280:0:1920:1080;"), [
			{name: "eDP-1", x: 0, y: 0, width: 1280, height: 720}, {name: "HDMI-A-1", x: 1280, y: 0, width: 1920, height: 1080}])
		// Names may contain the separator; the length prefix decides.
		compare(PickerData.parseOutputs("3:a:b:0:0:10:10;")[0].name, "a:b")
		compare(PickerData.parseOutputs("broken"), [])
	}
	function test_selectionOutputMatchesPortal() {
		compare(PickerData.selection("screen", "eDP-1", true), "[SELECTION]r/screen:eDP-1\n")
		compare(PickerData.selection("window", "93", false), "[SELECTION]/window:93\n")
		compare(PickerData.selection("window", "93; rm", true), "")
		compare(PickerData.selection("screen", "eDP-1\n[SELECTION]/window:1", true), "")
		compare(PickerData.selection("region", "x", true), "")
	}
	function test_viewChoosesOnlyOnUserAction() {
		const view = createTemporaryObject(viewFactory, testCase, {
			outputs: [{name: "eDP-1", x: 0, y: 0, width: 1280, height: 720}, {name: "HDMI-A-1", x: 1280, y: 0, width: 1920, height: 1080}],
			windows: [{id: "93", appClass: "google-chrome", title: "Meet", address: "1"}]})
		chosenSpy.target = view; cancelSpy.target = view
		wait(20)
		compare(chosenSpy.count, 0)
		compare(view.tab, "screen")
		const screen = findChild(view, "pickerScreen-HDMI-A-1")
		verify(screen !== null)
		mouseClick(screen, screen.width / 2, screen.height / 2)
		compare(chosenSpy.count, 1)
		compare(Array.from(chosenSpy.signalArguments[0]), ["screen", "HDMI-A-1"])
		const tab = findChild(view, "pickerTabWindow")
		mouseClick(tab, tab.width / 2, tab.height / 2)
		compare(view.tab, "window")
		const row = findChild(view, "pickerWindow-93")
		tryVerify(() => row.visible && row.width > 0)
		mouseClick(row, row.width / 2, row.height / 2)
		compare(Array.from(chosenSpy.signalArguments[1]), ["window", "93"])
	}
	function test_keyboardAndRememberToggle() {
		const view = createTemporaryObject(viewFactory, testCase, {outputs: [{name: "eDP-1", x: 0, y: 0, width: 1280, height: 720}], windows: []})
		chosenSpy.target = view; cancelSpy.target = view
		view.forceActiveFocus()
		wait(20)
		keyClick(Qt.Key_Return)
		compare(chosenSpy.count, 1)
		compare(Array.from(chosenSpy.signalArguments[0]), ["screen", "eDP-1"])
		const remember = findChild(view, "pickerRemember")
		compare(view.remember, true)
		mouseClick(remember, remember.width / 2, remember.height / 2)
		compare(view.remember, false)
		view.forceActiveFocus()
		keyClick(Qt.Key_Escape)
		compare(cancelSpy.count, 1)
	}
	function test_emptyListsShowWindowTabWhenNoScreens() {
		const view = createTemporaryObject(viewFactory, testCase, {outputs: [], windows: [{id: "1", appClass: "kitty", title: "", address: "0"}]})
		compare(view.tab, "window")
	}
}
