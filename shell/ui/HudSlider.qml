import QtQuick
import QtQuick.Controls.Basic as Controls

// Level slider: dim track, gradient fill, a lit handle that gains a halo while hovered, dragged or focused.
Controls.Slider {
	id: root
	from: 0
	to: 1
	stepSize: 0.01
	property real trackHeight: 4
	property real handleSize: 10
	readonly property bool engaged: enabled && (hovered || pressed || activeFocus)
	implicitHeight: Theme.controlHeight
	implicitWidth: 180
	background: Rectangle {
		x: root.leftPadding
		y: root.topPadding + root.availableHeight / 2 - height / 2
		width: root.availableWidth
		height: root.trackHeight
		radius: height / 2
		color: Theme.trackFill
		Rectangle {
			width: root.visualPosition * parent.width; height: parent.height; radius: parent.radius
			gradient: Gradient {
				orientation: Gradient.Horizontal
				GradientStop { position: 0; color: root.enabled ? Theme.accentDim : Theme.border }
				GradientStop { position: 1; color: root.enabled ? Theme.accent : Theme.textMuted }
			}
		}
	}
	handle: Rectangle {
		x: root.leftPadding + root.visualPosition * (root.availableWidth - width)
		y: root.topPadding + root.availableHeight / 2 - height / 2
		width: root.handleSize; height: root.handleSize; radius: root.handleSize / 2
		color: root.enabled ? Theme.accentBright : Theme.textMuted
		scale: root.pressed ? 1.2 : 1
		Behavior on scale { NumberAnimation { duration: Theme.pressDuration; easing.type: Theme.easing } }
		Rectangle {
			anchors.centerIn: parent; width: parent.width + 8; height: width; radius: width / 2
			color: "transparent"; border.width: 2; border.color: root.activeFocus ? Theme.accent : Theme.accentGlow
			opacity: root.engaged && root.handleSize > 0 ? 1 : 0
			Behavior on opacity { NumberAnimation { duration: Theme.hoverDuration; easing.type: Theme.easing } }
		}
	}
}
