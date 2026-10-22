import QtQuick

Rectangle {
	id: root
	property bool active: false
	property bool corners: true
	color: Theme.surface
	border.width: Theme.lineWidth
	border.color: active ? Theme.borderActive : Theme.border
	radius: Theme.cornerRadius

	Repeater {
		model: root.corners ? 4 : 0
		delegate: Item {
			required property int index
			readonly property bool rightCorner: index % 2 === 1
			readonly property bool bottomCorner: index >= 2
			x: rightCorner ? root.width - width : 0
			y: bottomCorner ? root.height - height : 0
			width: Math.min(Theme.cornerLength, root.width / 2)
			height: Math.min(Theme.cornerLength, root.height / 2)
			Rectangle {
				width: parent.width
				height: Theme.lineWidth
				y: parent.bottomCorner ? parent.height - height : 0
				color: root.active ? Theme.accent : Theme.accentDim
			}
			Rectangle {
				width: Theme.lineWidth
				height: parent.height
				x: parent.rightCorner ? parent.width - width : 0
				color: root.active ? Theme.accent : Theme.accentDim
			}
		}
	}
}
