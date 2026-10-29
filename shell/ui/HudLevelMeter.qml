import QtQuick

// Segmented level meter: `lit` of `bars` segments on; the top sixth turns warning to show clipping risk.
// It draws only what it is given; callers pass a measured level, never an animation.
Row {
	id: root
	property int bars: 24
	property int lit: 0
	property bool active: true
	property real barWidth: 4
	property real barHeight: 12
	spacing: 2
	Repeater {
		model: root.bars
		Rectangle {
			required property int index
			readonly property bool on: root.active && index < root.lit
			width: root.barWidth; height: root.barHeight
			color: !on ? Theme.trackFill : index >= root.bars - Math.ceil(root.bars / 6) ? Theme.warning : Theme.accent
			opacity: on ? 1 : root.active ? 0.9 : 0.5
		}
	}
}
