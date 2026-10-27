import QtQuick
import QtQuick.Layouts
import "../../ui"

ColumnLayout {
	id: root
	required property var battery
	required property var power
	// PowerPolicyState; optional so views that predate lock and suspend keep working.
	property var session: null
	signal navigate(string page)
	signal closeRequested()
	spacing: Theme.spaceM
	HudText { text: root.battery.validPercentage ? root.battery.percentage + "%" : "N/A"; textStyle: "value"; color: root.battery.lowBattery ? Theme.danger : Theme.accentBright }
	HudText { text: root.battery.available ? root.battery.status : "배터리가 없는 환경입니다."; Layout.fillWidth: true }
	HudProgress { Layout.fillWidth: true; value: root.battery.validPercentage ? root.battery.battery.percentage : 0 }
	HudText {
		readonly property real seconds: root.battery.available ? (root.battery.charging ? root.battery.battery.timeToFull : root.battery.battery.timeToEmpty) : 0
		visible: seconds > 0 && !root.battery.fullyCharged
		text: (root.battery.charging ? "완충까지 " : "남은 시간 ") + Math.floor(seconds / 3600) + "h " + Math.floor(seconds % 3600 / 60) + "m"
		color: Theme.textSecondary
	}
	HudText { text: "전원 프로필"; textStyle: "section"; color: Theme.accent }
	Repeater {
		model: root.power.profiles
		HudButton {
			required property string modelData
			Layout.fillWidth: true; text: modelData === "power-saver" ? "절전" : modelData === "balanced" ? "균형" : modelData === "performance" ? "성능" : modelData
			active: root.power.profile === modelData; enabled: root.power.ready && !root.power.busy
			onClicked: root.power.setProfile(modelData)
		}
	}
	HudText {
		visible: root.power.profiles.length === 0
		text: "전원 프로필 서비스를 사용할 수 없습니다. 배터리 표시는 계속 동작합니다."
		Layout.fillWidth: true; wrapMode: Text.WordWrap; maximumLineCount: 4; color: Theme.textMuted
	}
	HudText { visible: root.session !== null; text: "잠금 · 절전"; textStyle: "section"; color: Theme.accent }
	RowLayout {
		visible: root.session !== null; Layout.fillWidth: true; spacing: Theme.spaceS
		HudButton { objectName: "lockButton"; Layout.fillWidth: true; text: "󰌾  잠금"; onClicked: { root.closeRequested(); root.session.lock() } }
		HudButton {
			id: suspendButton; objectName: "suspendButton"; Layout.fillWidth: true
			// Two presses: a stray click must not put the machine to sleep.
			property bool confirming: false
			active: confirming; text: confirming ? "한 번 더 눌러 절전" : "󰤄  절전"
			onClicked: {
				if (!confirming) { confirming = true; confirmTimer.restart(); return }
				confirming = false; root.closeRequested(); root.session.suspend()
			}
			Timer { id: confirmTimer; interval: 4000; onTriggered: suspendButton.confirming = false }
		}
	}
	HudButton {
		objectName: "keepAwakeButton"; visible: root.session !== null; Layout.fillWidth: true
		active: root.session !== null && root.session.keepAwake
		text: active ? "󰅶  절전 방지 켜짐" : "󰅶  절전 방지"
		onClicked: root.session.keepAwake = !root.session.keepAwake
	}
	HudText {
		visible: root.session !== null; Layout.fillWidth: true; wrapMode: Text.WordWrap; maximumLineCount: 3; color: Theme.textMuted
		text: "절전 방지는 자동 잠금·화면 끄기·자동 절전을 멈춥니다. 직접 잠그거나 절전하는 것은 그대로 됩니다."
	}
	HudButton { objectName: "powerSettingsButton"; visible: root.session !== null; Layout.fillWidth: true; text: "전원 및 잠금 설정"; onClicked: root.navigate("power-settings") }
}
