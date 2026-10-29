import QtQuick
import QtTest
import "../components/control"
import "../core/DisplayLayout.js" as Layout

TestCase {
	id: testCase
	name: "Display"
	width: 640; height: 320; visible: true; when: windowShown

	// Same members as DisplayState; records what the page asks for instead of running anything.
	QtObject {
		id: fixture
		property var monitors: [
			{name: "eDP-1", id: 0, description: "BOE 0x0BCA", make: "BOE", model: "0x0BCA", internal: true, width: 1920, height: 1080, refresh: 60, x: 0, y: 0,
				scale: 1, transform: 0, disabled: false, mirrored: false, focused: true,
				modes: [{width: 1920, height: 1080, refresh: 144, text: "1920x1080@144.00"}, {width: 1920, height: 1080, refresh: 60, text: "1920x1080@60.00"},
					{width: 1280, height: 720, refresh: 60, text: "1280x720@60.00"}]},
			{name: "HDMI-A-1", id: 1, description: "Dell U2720Q", make: "Dell", model: "U2720Q", internal: false, width: 2560, height: 1440, refresh: 59.95,
				x: 1920, y: 0, scale: 1, transform: 0, disabled: false, mirrored: false, focused: false,
				modes: [{width: 2560, height: 1440, refresh: 59.95, text: "2560x1440@59.95"}]}]
		readonly property var editable: monitors
		property var inactive: []
		property var current: monitors.map(m => ({name: m.name, width: m.width, height: m.height, refresh: m.refresh, scale: m.scale, transform: m.transform, x: m.x, y: m.y}))
		property var draft: Layout.copy(current)
		property string selected: "eDP-1"
		property string primary: ""
		property string savedPrimary: ""
		property bool ready: true
		property bool loading: false
		property bool requesting: false
		property bool waiting: false
		property bool stale: false
		property int remaining: 12
		property string error: ""
		property string notice: ""
		property string outcome: ""
		property bool guardAvailable: true
		readonly property bool applying: requesting
		readonly property bool dirty: !Layout.sameLayout(draft, current) || primary !== savedPrimary
		readonly property string problem: Layout.problem(draft)
		readonly property bool canApply: dirty && problem === "" && !applying && !waiting
		readonly property var selectedMonitor: monitors.find(m => m.name === selected) || null
		readonly property var selectedItem: draft.find(i => i.name === selected) || null
		readonly property var selectedCurrent: current.find(i => i.name === selected) || null
		property var calls: []
		function retain(consumer) {}
		function release(consumer) {}
		function number(name) { return monitors.findIndex(m => m.name === name) + 1 }
		function select(name) { selected = name }
		function edit(changes) { const items = Layout.copy(draft); Object.assign(items.find(i => i.name === selected), changes); draft = items }
		function setResolution(w, h) { calls = calls.concat([["resolution", w, h]]); edit({width: w, height: h}) }
		function setRefresh(value) { calls = calls.concat([["refresh", value]]); edit({refresh: value}) }
		function setScale(value) { calls = calls.concat([["scale", value]]); edit({scale: value}) }
		function setTransform(value) { calls = calls.concat([["transform", value]]); edit({transform: value}) }
		function move(name, x, y) { calls = calls.concat([["move", name, x, y]]) }
		function place(name, direction) { calls = calls.concat([["place", name, direction]]) }
		function setPrimary(on) { primary = on ? selected : "" }
		function cancel() { draft = Layout.copy(current); primary = savedPrimary; calls = calls.concat([["cancel"]]) }
		function apply() { calls = calls.concat([["apply"]]) }
		function keep() { calls = calls.concat([["keep"]]) }
		function revert() { calls = calls.concat([["revert"]]) }
	}
	Component { id: pageFactory; DisplayPage { display: fixture } }

	function init() {
		fixture.draft = Layout.copy(fixture.current); fixture.selected = "eDP-1"; fixture.primary = ""; fixture.calls = []
		fixture.waiting = false; fixture.stale = false; fixture.error = ""; fixture.requesting = false
	}

	function test_scale_choices_are_only_the_ones_hyprland_keeps() {
		const labels = Layout.scaleOptions(1920, 1080, 0).map(option => option.label)
		compare(labels, ["100%", "125%", "150%", "160%", "200%", "250%", "300%"])
		verify(Layout.scaleOptions(2560, 1600, 0).every(option => Layout.clean(2560, 1600, option.value)))
		verify(!Layout.clean(1920, 1080, 1.75))
	}

	function test_layout_rules_match_the_backend() {
		const a = {name: "a", width: 1920, height: 1080, scale: 1, transform: 0, x: 0, y: 0, refresh: 60}
		compare(Layout.problem([a, Object.assign({}, a, {name: "b", x: 1920})]), "")
		verify(Layout.problem([a, Object.assign({}, a, {name: "b", x: 1000})]).indexOf("겹칩니다") >= 0)
		verify(Layout.problem([a, Object.assign({}, a, {name: "b", x: 2000})]).indexOf("맞닿아야") >= 0)
		compare(Layout.logical(Object.assign({}, a, {transform: 1, scale: 1.5})), {width: 720, height: 1280})
	}

	function test_snap_puts_a_dropped_screen_against_an_edge_without_overlap() {
		const items = [{name: "a", width: 1920, height: 1080, scale: 1, transform: 0, x: 0, y: 0, refresh: 60},
			{name: "b", width: 1920, height: 1080, scale: 1, transform: 0, x: 1920, y: 0, refresh: 60}]
		compare(Layout.snap(items, "b", 1500, 40), {x: 1920, y: 0})
		compare(Layout.snap(items, "b", 60, 900), {x: 0, y: 1080})
		compare(Layout.snap(items, "b", -1700, 500), {x: -1920, y: 500})
		compare(Layout.place(items, "b", "up"), {x: 0, y: -1080})
	}

	function test_resized_screen_keeps_its_neighbour_attached() {
		const before = {name: "a", width: 1920, height: 1080, scale: 1, transform: 0, x: 0, y: 0, refresh: 60}
		const items = [Object.assign({}, before, {scale: 1.5}), {name: "b", width: 1920, height: 1080, scale: 1, transform: 0, x: 1920, y: 0, refresh: 60}]
		const result = Layout.reflow(items, "a", before)
		compare(result[1].x, 1280)
		compare(Layout.problem(result), "")
	}

	function test_page_shows_the_selected_monitor_like_the_mockup() {
		const page = createTemporaryObject(pageFactory, testCase)
		compare(findChild(page, "displayValue-monitor").text, "1 — 내장 디스플레이")
		compare(findChild(page, "displayValue-resolution").text, "1920 × 1080")
		compare(findChild(page, "displayValue-refresh").text, "60 Hz")
		compare(findChild(page, "displayValue-scale").text, "100%")
		compare(findChild(page, "displayValue-transform").text, "가로")
		verify(findChild(page, "displayCard-eDP-1") !== null)
		verify(findChild(page, "displayCard-HDMI-A-1") !== null)
		verify(!findChild(page, "displayApply").enabled)
		verify(!findChild(page, "displayCancel").enabled)
	}

	function test_options_are_the_monitors_real_modes_and_choosing_one_only_edits_the_draft() {
		const page = createTemporaryObject(pageFactory, testCase)
		const row = findChild(page, "displayRow-refresh")
		mouseClick(row, row.width - 20, row.height / 2)
		compare(page.openKey, "refresh")
		compare(page.options.map(option => option.label), ["144 Hz", "60 Hz"])
		keyClick(Qt.Key_Up); keyClick(Qt.Key_Return)
		compare(fixture.calls, [["refresh", 144]])
		compare(page.openKey, "")
		verify(findChild(page, "displayApply").enabled)
		compare(findChild(page, "displayValue-refresh").text, "144 Hz")
		fixture.select("HDMI-A-1")
		page.open("resolution", findChild(page, "displayRow-resolution"))
		compare(page.options.map(option => option.label), ["2560 × 1440"])
		keyClick(Qt.Key_Escape)
		compare(page.openKey, "")
	}

	function test_apply_and_cancel_buttons_follow_the_draft() {
		const page = createTemporaryObject(pageFactory, testCase)
		fixture.setRefresh(144)
		const apply = findChild(page, "displayApply"), cancel = findChild(page, "displayCancel")
		verify(apply.enabled && cancel.enabled)
		mouseClick(apply)
		compare(fixture.calls[fixture.calls.length - 1], ["apply"])
		fixture.edit({x: 1000})
		verify(!apply.enabled)
		verify(findChild(page, "displayMessage").text.indexOf("겹칩니다") >= 0)
		mouseClick(cancel)
		verify(!apply.enabled)
	}

	function test_waiting_change_asks_and_defaults_to_restore() {
		const page = createTemporaryObject(pageFactory, testCase)
		fixture.waiting = true
		wait(50)
		verify(findChild(page, "displayConfirmText").text.indexOf("12초") >= 0)
		keyClick(Qt.Key_Return)
		compare(fixture.calls, [["revert"]])
		mouseClick(findChild(page, "displayKeep"))
		compare(fixture.calls[1], ["keep"])
		keyClick(Qt.Key_Escape)
		compare(fixture.calls[2], ["revert"])
		fixture.stale = true
		verify(!findChild(page, "displayKeep").enabled)
		page.open("scale", findChild(page, "displayRow-scale"))
		compare(page.openKey, "")
	}

	function test_cards_move_by_drag_and_arrow_keys() {
		const page = createTemporaryObject(pageFactory, testCase)
		const card = findChild(page, "displayCard-HDMI-A-1")
		mouseDrag(card, card.width / 2, card.height / 2, -card.width - 20, card.height / 2)
		compare(fixture.selected, "HDMI-A-1")
		const move = fixture.calls.find(call => call[0] === "move")
		verify(move !== undefined && move[1] === "HDMI-A-1")
		card.forceActiveFocus()
		keyClick(Qt.Key_Left)
		compare(fixture.calls[fixture.calls.length - 1], ["place", "HDMI-A-1", "left"])
	}

	function test_primary_checkbox_is_a_draft_change() {
		const page = createTemporaryObject(pageFactory, testCase)
		const row = findChild(page, "displayPrimary"), viewport = findChild(page, "displayViewport")
		// Below the five rows, so it is reached by scrolling like in the dashboard.
		viewport.contentY = row.y - 20
		mouseClick(row, 8, row.height / 2)
		compare(fixture.primary, "eDP-1")
		verify(findChild(page, "displayApply").enabled)
	}

	function test_outcome_words() {
		verify(Layout.outcomeText({state: "reverted", reason: "timeout"}).indexOf("15초") >= 0)
		verify(Layout.outcomeText({state: "kept"}, false).indexOf("install.sh") >= 0)
		verify(Layout.outcomeText({state: "restore-failed"}).indexOf("display-config.py restore") >= 0)
		verify(Layout.errorText("GuardUnavailable").indexOf("바꾸지 않았습니다") >= 0)
	}
}
