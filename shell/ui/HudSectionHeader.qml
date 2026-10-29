import QtQuick

// Section title: accent bar (or glyph), title, optional right-hand detail, and the "⋯" marker of a panel header.
Item {
	id: root
	property string title: ""
	property string glyph: ""
	property string detail: ""
	property bool marker: true
	property color color: Theme.accent
	implicitWidth: 200
	implicitHeight: 22
	Rectangle {
		visible: root.glyph.length === 0
		x: 0; anchors.verticalCenter: parent.verticalCenter
		width: Theme.sectionBarWidth; height: Math.round(parent.height * 0.7)
		color: root.color
	}
	HudIcon {
		id: icon
		visible: root.glyph.length > 0
		x: 0; anchors.verticalCenter: parent.verticalCenter
		width: 18; height: 18
		text: root.glyph; font.pixelSize: 15; color: root.color
	}
	HudText {
		id: label
		x: root.glyph.length > 0 ? 26 : Theme.sectionBarWidth + Theme.spaceS
		anchors.verticalCenter: parent.verticalCenter
		width: Math.max(0, root.width - x - detailText.implicitWidth - dots.width - Theme.spaceM)
		text: root.title; font.pixelSize: Theme.textBody; font.bold: true; color: root.color
		elide: Text.ElideRight
	}
	HudText {
		id: detailText
		anchors.right: dots.left; anchors.rightMargin: root.marker ? Theme.spaceS : 0
		anchors.verticalCenter: parent.verticalCenter
		text: root.detail; font.pixelSize: Theme.textCaption; color: Theme.textSecondary
	}
	Row {
		id: dots
		visible: root.marker
		width: root.marker ? implicitWidth : 0
		anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
		spacing: 3
		Repeater { model: 3; Rectangle { width: 2; height: 2; color: Theme.textMuted } }
	}
}
