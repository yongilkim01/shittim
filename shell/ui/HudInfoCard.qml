import QtQuick
import QtQuick.Layouts

// Tooltip card: header (glyph + title), divider, rows of {glyph | image, text, status, active}.
// Without rows it is a plain one-line hint.
HudCallout {
	id: root
	property string glyph: ""
	property string title: ""
	property var rows: []
	property real minimumWidth: rows.length > 0 ? 260 : 0
	padding: rows.length > 0 ? Theme.spaceL : Theme.spaceM
	ColumnLayout {
		width: Math.max(root.minimumWidth - root.padding * 2, implicitWidth); spacing: Theme.spaceS
		RowLayout {
			spacing: Theme.spaceM
			HudIcon { visible: root.glyph.length > 0; text: root.glyph; font.pixelSize: 26; color: Theme.accent }
			HudText {
				objectName: "infoTitle"; text: root.title; Layout.maximumWidth: 320; wrapMode: Text.WordWrap
				font.pixelSize: root.rows.length > 0 ? Theme.textTitle : Theme.textStatus; font.bold: root.rows.length > 0; color: Theme.textPrimary
			}
		}
		Rectangle { visible: root.rows.length > 0; Layout.fillWidth: true; height: Theme.lineWidth; color: Theme.border }
		Repeater {
			model: root.rows
			RowLayout {
				required property var modelData
				Layout.fillWidth: true; spacing: Theme.spaceM
				Item {
					implicitWidth: 26; implicitHeight: 26
					Image { anchors.fill: parent; visible: !!modelData.image; source: modelData.image || ""; sourceSize.width: 26; sourceSize.height: 26 }
					HudIcon { anchors.centerIn: parent; visible: !modelData.image; text: modelData.glyph || ""; font.pixelSize: 20; color: modelData.active ? Theme.accent : Theme.textSecondary }
				}
				HudText { text: modelData.text; Layout.fillWidth: true; elide: Text.ElideRight; color: Theme.textPrimary }
				HudText {
					visible: !!modelData.status; text: modelData.status || ""
					font.bold: !!modelData.active; color: modelData.active ? Theme.accentBright : Theme.textMuted
				}
			}
		}
	}
}
