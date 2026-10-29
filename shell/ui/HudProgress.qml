import QtQuick

// Linear meter: dim track, accent fill fading in from the left, a bright cap at the current value.
Rectangle {
	id: root
	property real value: 0
	property color fillColor: Theme.accent
	readonly property real fraction: isFinite(value) ? Math.max(0, Math.min(1, value)) : 0
	implicitWidth: Theme.spaceXL * 4
	implicitHeight: Theme.progressHeight
	radius: height > 3 ? height / 2 : 0
	color: Theme.trackFill
	Rectangle {
		width: parent.width * root.fraction
		height: parent.height
		radius: parent.radius
		gradient: Gradient {
			orientation: Gradient.Horizontal
			GradientStop { position: 0; color: Qt.rgba(root.fillColor.r, root.fillColor.g, root.fillColor.b, 0.55) }
			GradientStop { position: 1; color: root.fillColor }
		}
		Behavior on width { NumberAnimation { duration: Theme.stateDuration; easing.type: Theme.easing } }
		Rectangle {
			visible: root.height > 3 && root.fraction > 0
			anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
			width: 2; height: parent.height + 2; color: Theme.textPrimary; opacity: 0.8
		}
	}
}
