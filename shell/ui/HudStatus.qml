import QtQuick

Item {
	id: root
	property string glyph: ""
	property string text: ""
	property color color: Theme.textPrimary
	property real maximumTextWidth: Number.POSITIVE_INFINITY
	property bool compact: false
	property bool iconOnly: false
	property bool hovered: hover.hovered
	implicitWidth: content.implicitWidth + Theme.spaceS
	implicitHeight: Math.max(Theme.controlHeight, content.implicitHeight)
	HoverHandler { id: hover }

	Rectangle {
		anchors.fill: parent
		color: root.hovered ? Theme.surfaceElevated : Theme.transparent
		radius: Theme.cornerRadius
		Behavior on color { ColorAnimation { duration: Theme.hoverDuration; easing.type: Theme.easing } }
	}

	Row {
		id: content
		anchors.centerIn: parent
		spacing: root.compact ? Theme.spaceS : Theme.spaceXS
		HudIcon {
			visible: root.glyph.length > 0
			font.pixelSize: root.compact ? Theme.barIconSize : Theme.iconSize
			text: root.glyph
			color: root.color
			anchors.verticalCenter: parent.verticalCenter
		}
		HudText {
			visible: root.text.length > 0 && (!root.iconOnly || root.hovered)
			font.pixelSize: root.compact ? Theme.barTextSize : Theme.textStatus
			text: root.text
			color: root.color
			width: Math.min(implicitWidth, root.maximumTextWidth)
			anchors.verticalCenter: parent.verticalCenter
		}
	}
}
