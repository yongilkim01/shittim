import QtQuick

Rectangle {
	id: root
	property alias text: label.text
	property bool active: false
	readonly property bool hovered: mouse.containsMouse
	signal clicked()
	implicitWidth: Math.max(Theme.workspaceWidth, label.implicitWidth + Theme.spaceL)
	implicitHeight: Theme.controlHeight
	radius: Theme.cornerRadius
	color: !enabled ? Theme.background
		: (active || hovered || mouse.pressed ? Theme.surfaceElevated : Theme.surface)
	border.width: Theme.lineWidth
	border.color: enabled && (active || hovered || activeFocus) ? Theme.borderActive : Theme.border
	activeFocusOnTab: true

	HudText {
		id: label
		anchors.centerIn: parent
		width: Math.min(implicitWidth, Math.max(0, root.width - Theme.spaceS))
		font.bold: root.active
		color: !root.enabled ? Theme.textMuted
			: (root.active || root.hovered ? Theme.accentBright : Theme.textSecondary)
	}
	Rectangle {
		anchors.left: parent.left
		anchors.right: parent.right
		anchors.bottom: parent.bottom
		height: Theme.lineWidth
		color: root.active ? Theme.accent : Theme.transparent
	}
	MouseArea {
		id: mouse
		anchors.fill: parent
		hoverEnabled: true
		acceptedButtons: Qt.LeftButton
		cursorShape: Qt.PointingHandCursor
		onClicked: root.clicked()
	}
	Keys.onSpacePressed: event => { if (enabled) { clicked(); event.accepted = true } }
	Keys.onReturnPressed: event => { if (enabled) { clicked(); event.accepted = true } }
	Behavior on color { ColorAnimation { duration: Theme.hoverDuration; easing.type: Theme.easing } }
	Behavior on border.color { ColorAnimation { duration: Theme.hoverDuration; easing.type: Theme.easing } }
}
