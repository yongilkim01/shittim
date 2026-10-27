import QtQuick
import QtQuick.Layouts
import "../../ui"

// App icon with name and one detail line.
RowLayout {
	id: root
	property string icon: ""
	property string title: ""
	property string detail: ""
	property bool picked: false
	spacing: Theme.spaceS
	Image {
		visible: root.icon.length > 0; source: root.icon
		sourceSize.width: 28; sourceSize.height: 28; Layout.preferredWidth: 28; Layout.preferredHeight: 28
	}
	HudIcon { visible: root.icon.length === 0; text: "󰖯"; font.pixelSize: 24; color: root.picked ? Theme.accentBright : Theme.accent }
	ColumnLayout {
		Layout.fillWidth: true; spacing: 2
		HudText { text: root.title; Layout.fillWidth: true; elide: Text.ElideRight; font.bold: root.picked; color: root.picked ? Theme.accentBright : Theme.textPrimary }
		HudText { text: root.detail; Layout.fillWidth: true; elide: Text.ElideRight; textStyle: "caption"; color: Theme.textSecondary }
	}
}
