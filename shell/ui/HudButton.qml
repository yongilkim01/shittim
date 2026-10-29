import QtQuick

// Text button. State priority: disabled > pressed > selected (active) > focus/hover > rest.
// `compact` is the top-bar workspace chip: a small filled pill instead of a frame.
Item {
	id: root
	property alias text: label.text
	property bool active: false
	property bool compact: false
	Keys.forwardTo:[input]
	readonly property bool hovered: input.hovered
	readonly property bool pressed: input.pressed
	readonly property color fillColor: !enabled ? Theme.disabledFill : pressed ? Theme.pressedFill : active ? Theme.selectedFill
		: hovered ? Theme.hoverFill : Theme.surface
	readonly property color strokeColor: !enabled ? Theme.border : (active || pressed || input.focused) ? Theme.borderActive
		: hovered ? Theme.accentDim : Theme.border
	signal clicked()
	implicitWidth: compact ? Math.max(Theme.barWorkspaceWidth, label.implicitWidth + Theme.spaceXS)
		: Math.max(Theme.workspaceWidth, label.implicitWidth + Theme.spaceL)
	implicitHeight: compact ? Theme.barWorkspaceHeight : Theme.controlHeight

	Rectangle {
		visible: root.compact
		anchors.fill: parent
		radius: Theme.barWorkspaceRadius
		color: root.enabled && root.active ? Theme.accentBright : (root.enabled && (root.hovered || root.pressed) ? Theme.surfaceElevated : Theme.transparent)
		border.width: input.focused ? Theme.lineWidth : 0
		border.color: Theme.borderActive
		Behavior on color { ColorAnimation { duration: Theme.hoverDuration; easing.type: Theme.easing } }
	}
	HudFrame {
		visible: !root.compact
		anchors.fill: parent
		level: "control"
		cutTopLeft: 0; cutTopRight: 0; cutBottomLeft: 0; cutBottomRight: Theme.controlCut
		fillColor: root.fillColor
		strokeColor: root.strokeColor
		Behavior on fillColor { ColorAnimation { duration: root.pressed ? Theme.pressDuration : Theme.hoverDuration; easing.type: Theme.easing } }
		// Selected marker: a bright bar along the bottom edge, short of the cut corner.
		Rectangle {
			x: Theme.spaceXS; y: parent.height - height - Theme.lineWidth
			width: Math.max(0, parent.width - Theme.spaceXS * 2 - Theme.controlCut); height: Theme.accentLineWidth
			color: Theme.accent
			opacity: root.active && root.enabled ? 1 : 0
			Behavior on opacity { NumberAnimation { duration: Theme.stateDuration; easing.type: Theme.easing } }
		}
	}
	HudText {
		id: label
		anchors.centerIn: parent
		width: Math.min(implicitWidth, Math.max(0, root.width - (root.compact ? Theme.spaceXS : Theme.spaceS)))
		font.bold: root.active
		color: !root.enabled ? Theme.textMuted
			: root.compact ? (root.active ? Theme.background : (root.hovered ? Theme.accentBright : Theme.accentDim))
			: (root.active || root.hovered || root.pressed ? Theme.accentBright : Theme.textSecondary)
		Behavior on color { ColorAnimation { duration: Theme.hoverDuration; easing.type: Theme.easing } }
	}
	ActionInput {id:input;label:String(root.text);onTriggered:root.clicked()}
}
