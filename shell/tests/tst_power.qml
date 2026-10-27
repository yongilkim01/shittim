import QtQuick
import QtTest
import "../components"
import "../components/control"
import "../core/PowerText.js" as PowerText

TestCase {
	id: testCase
	name: "PowerAndLock"
	width: 640; height: 320; visible: true; when: windowShown

	QtObject {
		id: policyFixture
		property var settings: ({version: 1, battery: {lock: 5, screenOff: 10, suspend: 0, lid: "system"}, ac: {lock: 5, screenOff: 15, suspend: 0, lid: "system"}})
		property string currentSource: "battery"
		property bool hasBattery: true
		property bool hasLid: true
		property var systemLid: ({battery: "suspend", ac: "ignore", docked: "ignore"})
		property string applyState: "applied"
		property bool saving: false
		property string error: ""
		property bool keepAwake: false
		property var calls: []
		property int locks: 0
		property int suspends: 0
		function setValue(source, key, value) { calls = calls.concat([[source, key, value]]) }
		function lock() { locks += 1 }
		function suspend() { suspends += 1 }
	}
	QtObject { id: batteryFixture; property bool available: true; property bool validPercentage: true; property int percentage: 80; property bool lowBattery: false; property string status: "방전 중"; property bool charging: false; property bool fullyCharged: false; property var battery: ({percentage: 0.8, timeToFull: 0, timeToEmpty: 0}) }
	QtObject { id: powerFixture; property var profiles: []; property string profile: ""; property bool ready: true; property bool busy: false; function setProfile(value) {} }
	Component { id: pageFactory; PowerLockPage { policy: policyFixture; wallpaper: Qt.resolvedUrl("../../assets/wallpapers/shittim-city.png") } }
	Component { id: menuFactory; PowerPage { width: 320; battery: batteryFixture; power: powerFixture; session: policyFixture } }
	Component { id: activityFactory; DeviceActivity { idle: policyFixture } }

	function init() {
		policyFixture.calls = []; policyFixture.locks = 0; policyFixture.suspends = 0; policyFixture.keepAwake = false
		policyFixture.hasBattery = true; policyFixture.hasLid = true; policyFixture.applyState = "applied"; policyFixture.currentSource = "battery"
		policyFixture.error = ""; policyFixture.saving = false
	}

	function test_labels_match_service_choices() {
		compare(PowerText.duration(0), "사용 안 함")
		compare(PowerText.duration(5), "5분")
		compare(PowerText.duration(120), "2시간")
		compare(PowerText.lid("system", "suspend"), "시스템 설정 (절전)")
		compare(PowerText.lid("screen-off"), "잠그고 화면 끄기")
		compare(PowerText.options("suspend").map(option => option.value), [0, 10, 15, 20, 30, 45, 60, 120])
		compare(PowerText.options("lid").length, 4)
		verify(PowerText.status("stopped", "ac").indexOf("적용되지 않았습니다") >= 0)
		verify(PowerText.status("applied", "battery").indexOf("배터리 사용 시") >= 0)
	}

	function test_page_shows_current_source_values() {
		const page = createTemporaryObject(pageFactory, testCase)
		compare(page.source, "battery")
		compare(findChild(page, "powerValue-lock").text, "5분")
		compare(findChild(page, "powerValue-screenOff").text, "10분")
		compare(findChild(page, "powerValue-suspend").text, "사용 안 함")
		compare(findChild(page, "powerValue-lid").text, "시스템 설정 (절전)")
		mouseClick(findChild(page, "powerSource-ac"))
		compare(page.source, "ac")
		compare(findChild(page, "powerValue-screenOff").text, "15분")
		compare(findChild(page, "powerValue-lid").text, "시스템 설정 (아무것도 안 함)")
	}

	function test_choosing_an_option_calls_setValue_once() {
		const page = createTemporaryObject(pageFactory, testCase)
		mouseClick(findChild(page, "powerRow-suspend"))
		compare(page.openKey, "suspend")
		const list = findChild(page, "powerOptions")
		verify(list.visible)
		verify(list.y + list.height <= page.height)
		tryVerify(() => findChild(page, "powerOption-30").y > 0)
		mouseClick(findChild(page, "powerOption-30"))
		compare(policyFixture.calls, [["battery", "suspend", 30]])
		compare(page.openKey, "")
		mouseClick(findChild(page, "powerRow-lock"))
		tryVerify(() => findChild(page, "powerOption-5").y > 0)
		mouseClick(findChild(page, "powerOption-5"))
		compare(policyFixture.calls.length, 1)
	}

	function test_keyboard_only_change() {
		const page = createTemporaryObject(pageFactory, testCase)
		const row = findChild(page, "powerRow-lock")
		row.forceActiveFocus()
		keyClick(Qt.Key_Return)
		compare(page.openKey, "lock")
		keyClick(Qt.Key_Down)
		keyClick(Qt.Key_Return)
		compare(policyFixture.calls, [["battery", "lock", 10]])
		verify(row.activeFocus)
		keyClick(Qt.Key_Return)
		keyClick(Qt.Key_Escape)
		compare(page.openKey, "")
		verify(row.activeFocus)
	}

	function test_desktop_without_battery_or_lid() {
		policyFixture.hasBattery = false; policyFixture.hasLid = false; policyFixture.currentSource = "ac"
		const page = createTemporaryObject(pageFactory, testCase)
		compare(page.source, "ac")
		compare(findChild(page, "powerRow-lid"), null)
		mouseClick(findChild(page, "powerSource-battery"))
		compare(page.source, "ac")
	}

	function test_status_line_never_claims_unapplied_settings() {
		policyFixture.applyState = "stopped"
		const page = createTemporaryObject(pageFactory, testCase)
		const status = findChild(page, "powerStatus")
		verify(status.text.indexOf("적용되지 않았습니다") >= 0)
		policyFixture.applyState = "pending"
		compare(status.text, "저장됨 · 적용 중…")
		policyFixture.error = "설정을 저장하지 못했습니다."
		compare(status.text, "설정을 저장하지 못했습니다.")
	}

	function test_power_menu_locks_and_confirms_suspend() {
		const menu = createTemporaryObject(menuFactory, testCase)
		const closed = createTemporaryObject(signalSpyFactory, testCase, {target: menu, signalName: "closeRequested"})
		mouseClick(findChild(menu, "lockButton"))
		compare(policyFixture.locks, 1)
		compare(closed.count, 1)
		const suspend = findChild(menu, "suspendButton")
		mouseClick(suspend)
		compare(policyFixture.suspends, 0)
		verify(suspend.text.indexOf("한 번 더") >= 0)
		mouseClick(suspend)
		compare(policyFixture.suspends, 1)
		mouseClick(findChild(menu, "keepAwakeButton"))
		compare(policyFixture.keepAwake, true)
	}

	function test_keep_awake_indicator_and_card() {
		const activity = createTemporaryObject(activityFactory, testCase)
		compare(activity.visible, false)
		policyFixture.keepAwake = true
		compare(activity.visible, true)
		compare(activity.cardFor("awake").title, "절전 방지 켜짐")
		const icon = findChild(activity, "activityAwake")
		tryVerify(() => icon.width > 0)
		mouseClick(icon)
		compare(policyFixture.keepAwake, false)
	}

	Component { id: signalSpyFactory; SignalSpy {} }
}
