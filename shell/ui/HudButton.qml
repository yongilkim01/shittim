import QtQuick

Rectangle {
	id: root
	property alias text: label.text
	property bool active: false
	property bool compact: false
	Keys.forwardTo:[input]
	readonly property bool hovered: input.hovered
	signal clicked()
	implicitWidth: compact ? Math.max(Theme.barWorkspaceWidth, label.implicitWidth + Theme.spaceXS)
		: Math.max(Theme.workspaceWidth, label.implicitWidth + Theme.spaceL)
	implicitHeight: compact ? Theme.barWorkspaceHeight : Theme.controlHeight
	radius: compact ? Theme.barWorkspaceRadius : Theme.cornerRadius
	color: compact ? (enabled && active ? Theme.accentBright
		: (enabled && (hovered || input.pressed) ? Theme.surfaceElevated : Theme.transparent))
		: !enabled ? Theme.background
		: (active || hovered || input.pressed ? Theme.surfaceElevated : Theme.surface)
	border.width: compact && !input.focused ? 0 : Theme.lineWidth
	border.color: enabled && (active || hovered || input.focused) ? Theme.borderActive : Theme.border

	HudText {
		id: label
		anchors.centerIn: parent
		width: Math.min(implicitWidth, Math.max(0, root.width - (root.compact ? Theme.spaceXS : Theme.spaceS)))
		font.bold: root.active
		color: !root.enabled ? Theme.textMuted
			: root.compact ? (root.active ? Theme.background : (root.hovered ? Theme.accentBright : Theme.accentDim))
			: (root.active || root.hovered ? Theme.accentBright : Theme.textSecondary)
	}
	Rectangle {
		visible: !root.compact
		anchors.left: parent.left
		anchors.right: parent.right
		anchors.bottom: parent.bottom
		height: Theme.lineWidth
		color: root.active ? Theme.accent : Theme.transparent
	}
	ActionInput {id:input;label:String(root.text);onTriggered:root.clicked()}
	Behavior on color { ColorAnimation { duration: Theme.hoverDuration; easing.type: Theme.easing } }
	Behavior on border.color { ColorAnimation { duration: Theme.hoverDuration; easing.type: Theme.easing } }
}
