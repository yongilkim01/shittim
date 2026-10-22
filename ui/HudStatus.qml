import QtQuick

Item {
	id: root
	property string glyph: ""
	property string text: ""
	property color color: Theme.textPrimary
	property real maximumTextWidth: Number.POSITIVE_INFINITY
	property bool hovered: false
	implicitWidth: content.implicitWidth + Theme.spaceS
	implicitHeight: Math.max(Theme.controlHeight, content.implicitHeight)

	Rectangle {
		anchors.fill: parent
		color: root.hovered ? Theme.surfaceElevated : Theme.transparent
		radius: Theme.cornerRadius
		Behavior on color { ColorAnimation { duration: Theme.hoverDuration; easing.type: Theme.easing } }
	}

	Row {
		id: content
		anchors.centerIn: parent
		spacing: Theme.spaceXS
		HudIcon {
			visible: root.glyph.length > 0
			text: root.glyph
			color: root.color
			anchors.verticalCenter: parent.verticalCenter
		}
		HudText {
			text: root.text
			color: root.color
			width: Math.min(implicitWidth, root.maximumTextWidth)
			anchors.verticalCenter: parent.verticalCenter
		}
	}
}
