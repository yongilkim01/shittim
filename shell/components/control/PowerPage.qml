import QtQuick
import QtQuick.Layouts
import "../../ui"

ColumnLayout {
	id: root
	required property var battery
	required property var power
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
}
