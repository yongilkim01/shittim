import QtQuick

Rectangle {
	id: root
	property real value: 0
	property color fillColor: Theme.accent
	readonly property real fraction: isFinite(value) ? Math.max(0, Math.min(1, value)) : 0
	implicitWidth: Theme.spaceXL * 4
	implicitHeight: Theme.progressHeight
	color: Theme.border
	Rectangle {
		width: parent.width * root.fraction
		height: parent.height
		color: root.fillColor
		Behavior on width { NumberAnimation { duration: Theme.stateDuration; easing.type: Theme.easing } }
		Behavior on color { ColorAnimation { duration: Theme.stateDuration; easing.type: Theme.easing } }
	}
}
