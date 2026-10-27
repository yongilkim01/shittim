import QtQuick
import QtQuick.Layouts
import "../../ui"

ColumnLayout {
	id: root
	required property var brightness
	spacing: Theme.spaceS
	LevelControl {
		Layout.fillWidth: true; title: "밝기"; glyph: "󰃠"
		available: root.brightness.backlight !== null && root.brightness.backlight.writable && root.brightness.ready
		value: root.brightness.backlight !== null ? root.brightness.backlight.value : 0
		detail: root.brightness.backlight !== null ? root.brightness.backlight.name : "백라이트 장치 없음"
		deferred: true; onChanged: fraction => root.brightness.setBrightness(fraction)
	}
	HudText { text: "백라이트 장치"; color: Theme.accent; textStyle: "section" }
	Repeater {
		model: root.brightness.backlights
		HudButton {
			required property var modelData
			Layout.fillWidth: true; text: modelData.name
			active: root.brightness.backlight !== null && root.brightness.backlight.name === modelData.name
			onClicked: root.brightness.selectedBacklight = modelData.name
		}
	}
	HudText {
		text: "백라이트는 모니터 위치와 별개로 장치 이름으로 선택합니다. DDC/CI 및 주변광 자동 밝기는 지원하지 않습니다."
		Layout.fillWidth: true; wrapMode: Text.WordWrap; maximumLineCount: 5; color: Theme.textSecondary
	}
	HudButton { text: "장치 / 권한 다시 확인"; enabled: root.brightness.ready; onClicked: root.brightness.refresh() }
}
