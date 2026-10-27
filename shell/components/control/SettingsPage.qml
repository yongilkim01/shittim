import QtQuick
import QtQuick.Layouts
import "../../ui"

ColumnLayout {
	id: root
	required property var metrics
	signal navigate(string page)
	spacing: Theme.spaceS
	Repeater {
		model: [{name: "Wi-Fi", page: "wifi"}, {name: "Bluetooth", page: "bluetooth"},
			{name: "오디오", page: "audio"}, {name: "밝기", page: "brightness"}, {name: "배터리 / 전원", page: "power"}]
		HudButton {
			required property var modelData
			Layout.fillWidth: true; text: modelData.name; onClicked: root.navigate(modelData.page)
		}
	}
	HudText { text: "SYSTEM"; textStyle: "section"; color: Theme.accent; Layout.topMargin: Theme.spaceM }
	HudText { text: "CPU  " + (root.metrics.cpu >= 0 ? root.metrics.cpu + "%" : "N/A") }
	HudText { text: "RAM  " + (root.metrics.memory >= 0 ? root.metrics.memory + "%" : "N/A") }
	HudText { text: "UP   " + Math.floor(root.metrics.uptime / 3600) + "h " + Math.floor(root.metrics.uptime % 3600 / 60) + "m" }
	HudButton { text: "상태 새로고침"; enabled: root.metrics.ready; onClicked: root.metrics.refresh() }
}
