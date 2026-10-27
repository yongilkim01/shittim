import QtQuick
import "../../ui"

// Thumbnail frame for a share target: preview (when available), selection glow and check badge.
Rectangle {
	id: root
	property string kind: ""
	property var target: null
	property Component component: null
	property bool picked: false
	property bool highlighted: false
	property bool badge: true
	property string placeholder: ""
	radius: 4; clip: true
	color: Theme.background
	border.width: picked ? 2 : Theme.lineWidth
	border.color: picked || highlighted ? Theme.accent : Theme.border
	// Restrained glow around the picked target.
	Rectangle {
		visible: root.picked; z: -1
		anchors.fill: parent; anchors.margins: -4; radius: root.radius + 4
		color: Theme.transparent; border.width: 4; border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25)
	}
	Loader {
		id: preview; anchors.fill: parent; anchors.margins: root.border.width
		active: root.component !== null && root.target !== null
		sourceComponent: root.component
		onLoaded: { item.kind = root.kind; item.target = root.target }
	}
	HudIcon {
		anchors.centerIn: parent; font.pixelSize: Math.min(40, root.height / 2); color: Theme.accentDim; text: root.placeholder
		visible: preview.item === null || !preview.item.hasContent
	}
	Rectangle {
		visible: root.picked && root.badge
		anchors.right: parent.right; anchors.top: parent.top; anchors.margins: Theme.spaceS
		width: 26; height: 26; radius: 13; color: Theme.accent
		HudIcon { anchors.centerIn: parent; text: "󰄬"; font.pixelSize: 18; color: Theme.background }
	}
}
