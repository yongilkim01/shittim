import QtQuick
import QtQuick.Controls.Basic as Controls

Controls.Slider {
	id: root
	from: 0
	to: 1
	stepSize: 0.01
	property real trackHeight: 4
	property real handleSize: 8
	implicitHeight: Theme.controlHeight
	implicitWidth: 180
	background: Rectangle {
		x: root.leftPadding
		y: root.topPadding + root.availableHeight / 2 - height / 2
		width: root.availableWidth
		height: root.trackHeight
		color: Theme.border
		Rectangle { width: root.visualPosition * parent.width; height: parent.height; color: root.enabled ? Theme.accent : Theme.textMuted }
	}
	handle: Rectangle {
		x: root.leftPadding + root.visualPosition * (root.availableWidth - width)
		y: root.topPadding + root.availableHeight / 2 - height / 2
		width: root.handleSize; height: root.handleSize; radius: root.handleSize / 2
		color: root.enabled ? Theme.accentBright : Theme.textMuted
		border.width: root.activeFocus ? Theme.lineWidth : 0
		border.color: Theme.textPrimary
	}
}
