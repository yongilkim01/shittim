import QtQuick
import QtQuick.Layouts
import "../../ui"

HudPanel {
	id: root
	property string title: ""
	property string glyph: ""
	property string detail: ""
	property real value: 0
	property bool available: true
	property bool muted: false
	property bool muteButton: false
	property bool deferred: false
	signal changed(real fraction)
	signal muteRequested()
	signal detailsRequested()
	implicitHeight: 92
	ColumnLayout {
		anchors.fill: parent; anchors.margins: Theme.spaceM; spacing: Theme.spaceXS
		RowLayout {
			HudIcon { text: root.glyph; color: root.available ? Theme.accent : Theme.textMuted }
			HudButton { text: root.title; onClicked: root.detailsRequested() }
			HudText { text: root.detail; Layout.fillWidth: true; textStyle: "caption" }
			HudText { text: root.available ? Math.round(slider.value * 100) + "%" : "N/A"; color: Theme.accentBright }
		}
		RowLayout {
			HudSlider {
				id: slider; objectName: "levelSlider"; Layout.fillWidth: true; enabled: root.available
				Binding { target: slider; property: "value"; value: Math.max(0, Math.min(1, root.value)); when: !slider.pressed; restoreMode: Binding.RestoreNone }
				onMoved: if (!root.deferred || !pressed) root.changed(value)
				onPressedChanged: if (!pressed && root.deferred) root.changed(value)
			}
			HudButton {
				visible: root.muteButton; enabled: root.available; active: root.muted
				text: root.muted ? "󰝟" : "󰕾"; onClicked: root.muteRequested()
			}
		}
	}
}
