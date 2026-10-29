import QtQuick

// On/off switch. The thumb slides and lights up; off is an outlined track, on is an accent-filled one.
Item {
	id: root
	property bool checked: false
	property string label: ""
	Keys.forwardTo: [input]
	readonly property bool hovered: input.hovered
	signal toggled(bool checked)
	implicitWidth: Theme.toggleWidth
	implicitHeight: Math.max(Theme.toggleHeight, Theme.minimumTarget)
	Rectangle {
		id: track
		anchors.verticalCenter: parent.verticalCenter
		width: Theme.toggleWidth; height: Theme.toggleHeight; radius: height / 2
		color: !root.enabled ? Theme.disabledFill : root.checked ? Theme.selectedFill : Theme.trackFill
		border.width: Theme.lineWidth
		border.color: !root.enabled ? Theme.border : root.checked || input.focused ? Theme.accent : root.hovered ? Theme.accentDim : Theme.border
		Behavior on color { ColorAnimation { duration: Theme.toggleDuration; easing.type: Theme.easing } }
		Behavior on border.color { ColorAnimation { duration: Theme.hoverDuration; easing.type: Theme.easing } }
		Rectangle {
			id: thumb
			readonly property real travel: track.width - width - 6
			x: 3 + (root.checked ? travel : 0); anchors.verticalCenter: parent.verticalCenter
			width: track.height - 6; height: width; radius: width / 2
			color: !root.enabled ? Theme.textMuted : root.checked ? Theme.accentBright : Theme.accentDim
			Behavior on x { NumberAnimation { duration: Theme.toggleDuration; easing.type: Theme.easing } }
			Behavior on color { ColorAnimation { duration: Theme.toggleDuration; easing.type: Theme.easing } }
			// Halo on the lit thumb: the one place a toggle glows.
			Rectangle {
				anchors.centerIn: parent; width: parent.width + 6; height: width; radius: width / 2
				color: "transparent"; border.width: 2; border.color: Theme.accentGlow
				opacity: root.checked && root.enabled ? 1 : 0
				Behavior on opacity { NumberAnimation { duration: Theme.toggleDuration; easing.type: Theme.easing } }
			}
		}
	}
	ActionInput { id: input; label: root.label; onTriggered: { root.checked = !root.checked; root.toggled(root.checked) } }
}
