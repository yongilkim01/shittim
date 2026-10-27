import QtQuick
import QtTest
import "../components/sharepicker"
import "../components/sharepicker/PickerData.js" as PickerData

TestCase {
	id: testCase
	name: "SharePicker"
	width: 1000; height: 640; visible: true; when: windowShown
	Component { id: viewFactory; SharePickerView { width: 980; height: 620; focus: true } }
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
	function click(item) { mouseClick(item, item.width / 2, item.height / 2) }
	readonly property var twoScreens: [{name: "eDP-1", x: 0, y: 0, width: 1280, height: 720}, {name: "HDMI-A-1", x: 1280, y: 0, width: 1920, height: 1200}]
	readonly property var twoWindows: [{id: "93", appClass: "google-chrome", title: "Meet", address: "1"}, {id: "94", appClass: "google-chrome", title: "Docs", address: "2"},
		{id: "17", appClass: "kitty", title: "~/shittim", address: "3"}]
	function test_selectThenShare() {
		const view = createTemporaryObject(viewFactory, testCase, {focusedOutput: "HDMI-A-1", outputs: twoScreens, windows: twoWindows})
		chosenSpy.target = view; cancelSpy.target = view
		wait(20)
		compare(view.tab, "screen")
		compare(findChild(view, "pickerInfo").text, "공유할 화면이나 창을 선택하세요.")
		const share = findChild(view, "pickerShare")
		compare(share.enabled, false)
		const screen = findChild(view, "pickerScreen-HDMI-A-1")
		verify(screen !== null)
		compare(view.screenTitle(view.outputs[1], 1), "모니터 2")
		compare(view.screenDetail(view.outputs[0]), "1280 × 720 (16:9)")
		compare(view.screenDetail(view.outputs[1]), "1920 × 1200 (16:10)")
		click(screen)
		// Picking only selects; nothing is shared until the user confirms.
		compare(chosenSpy.count, 0)
		compare(screen.picked, true)
		compare(share.enabled, true)
		compare(findChild(view, "pickerInfo").text, "선택한 화면만 공유됩니다.")
		// The window list beside the monitors picks a window without leaving the tab.
		const row = findChild(view, "pickerWindowRow-17")
		click(row)
		compare(view.tab, "screen")
		compare(row.picked, true); compare(screen.picked, false)
		compare(findChild(view, "pickerInfo").text, "선택한 창만 공유됩니다. 다른 창은 보이지 않습니다.")
		click(screen)
		click(share)
		compare(chosenSpy.count, 1)
		compare(Array.from(chosenSpy.signalArguments[0]), ["screen", "HDMI-A-1"])
		click(findChild(view, "pickerTabWindow"))
		compare(view.tab, "window")
	}
	function test_windowNamesUseDesktopEntries() {
		const view = createTemporaryObject(viewFactory, testCase, {outputs: twoScreens, windows: twoWindows,
			appInfo: appClass => appClass === "kitty" ? {name: "Kitty", genericName: "터미널", icon: ""}
				: appClass === "google-chrome" ? {name: "Google Chrome", genericName: "웹 브라우저", icon: ""} : null})
		compare(view.windowTitle(twoWindows[2]), "Kitty")
		compare(view.windowDetail(twoWindows[2]), "터미널")
		// Two Chrome windows: the window title tells them apart.
		compare(view.windowTitle(twoWindows[0]), "Google Chrome")
		compare(view.windowDetail(twoWindows[0]), "Meet")
		compare(view.windowTitle({id: "5", appClass: "unknown", title: "x", address: "4"}), "unknown")
	}
	function test_doubleActivationShares() {
		const view = createTemporaryObject(viewFactory, testCase, {outputs: [], windows: twoWindows})
		chosenSpy.target = view
		compare(view.tab, "window")
		const card = findChild(view, "pickerWindow-93")
		tryVerify(() => card.visible && card.width > 0)
		mouseDoubleClickSequence(card, card.width / 2, card.height / 2)
		compare(chosenSpy.count, 1)
		compare(Array.from(chosenSpy.signalArguments[0]), ["window", "93"])
	}
	function test_keyboardShareAndEscape() {
		const view = createTemporaryObject(viewFactory, testCase, {outputs: [twoScreens[0]], windows: []})
		chosenSpy.target = view; cancelSpy.target = view
		view.forceActiveFocus()
		wait(20)
		keyClick(Qt.Key_Return)
		compare(chosenSpy.count, 0)
		compare(view.selectedValue, "eDP-1")
		keyClick(Qt.Key_Return)
		compare(chosenSpy.count, 1)
		compare(Array.from(chosenSpy.signalArguments[0]), ["screen", "eDP-1"])
		view.forceActiveFocus()
		keyClick(Qt.Key_Escape)
		compare(cancelSpy.count, 1)
	}
	function test_emptyListsShowWindowTabWhenNoScreens() {
		const view = createTemporaryObject(viewFactory, testCase, {outputs: [], windows: [{id: "1", appClass: "kitty", title: "", address: "0"}]})
		compare(view.tab, "window")
		click(findChild(view, "pickerTabScreen"))
		compare(findChild(view, "pickerEmpty").visible, true)
	}
}
