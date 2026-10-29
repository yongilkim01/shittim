import QtQuick

// Choices of a HudSelect, drawn by the page that owns the field (fill the page with it; it covers the page only while
// open). options: [{label, glyph, detail, selected, enabled}]. Arrow keys move, Return/Space choose, Escape closes,
// and a click outside closes; focus goes back to the field either way.
Item {
	id: root
	property var options: []
	property int highlighted: -1
	property Item field: null
	property real rowHeight: 26
	readonly property bool opened: field !== null
	signal chosen(int index)
	visible: opened
	z: 10

	function open(target, choices) {
		options = choices
		field = target
		highlighted = Math.max(0, choices.findIndex(option => option.selected))
		const below = target.mapToItem(root, 0, target.height).y + 2, top = target.mapToItem(root, 0, 0).y
		const height = list.height
		list.x = Math.max(0, Math.min(root.width - list.width, target.mapToItem(root, 0, 0).x))
		list.y = below + height <= root.height ? below : Math.max(0, top - height - 2)
		list.forceActiveFocus()
		view.positionViewAtIndex(highlighted, ListView.Contain)
	}
	function close() {
		const target = field
		field = null
		if (target) target.forceActiveFocus()
	}
	function choose(index) {
		const option = options[index]
		if (!option || option.enabled === false) return
		close()
		chosen(index)
	}
	function step(direction) {
		let next = highlighted
		for (let i = 0; i < options.length; ++i) {
			next = Math.max(0, Math.min(options.length - 1, next + direction))
			if (options[next].enabled !== false) break
		}
		highlighted = next
		view.positionViewAtIndex(highlighted, ListView.Contain)
	}

	MouseArea { anchors.fill: parent; onClicked: root.close() }
	HudFrame {
		id: list; objectName: "hudOptions"
		width: root.field ? Math.min(root.width, Math.max(root.field.width, 260)) : 0
		height: Math.min(root.options.length, 7) * root.rowHeight + 8
		level: "card"; glow: true
		fillColor: Theme.floatingSurface; strokeColor: Theme.accentDim
		Keys.onPressed: event => {
			if (event.key === Qt.Key_Down) root.step(1)
			else if (event.key === Qt.Key_Up) root.step(-1)
			else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) root.choose(root.highlighted)
			else if (event.key === Qt.Key_Escape || event.key === Qt.Key_Tab) root.close()
			else return
			event.accepted = true
		}
		ListView {
			id: view
			x: 4; y: 4; width: parent.width - 8; height: parent.height - 8
			clip: true; model: root.options; boundsBehavior: Flickable.StopAtBounds
			delegate: Rectangle {
				required property var modelData
				required property int index
				readonly property bool usable: modelData.enabled !== false
				objectName: "hudOption-" + index
				width: view.width; height: root.rowHeight
				color: index === root.highlighted && usable ? Theme.selectedFill : Theme.transparent
				Rectangle { visible: modelData.selected === true; width: Theme.sectionBarWidth; height: parent.height; color: Theme.accent }
				HudIcon {
					id: optionGlyph; visible: !!modelData.glyph; x: Theme.spaceS; anchors.verticalCenter: parent.verticalCenter; width: 16
					text: modelData.glyph || ""; font.pixelSize: 13; color: parent.usable ? Theme.accent : Theme.textMuted
				}
				HudText {
					x: optionGlyph.visible ? Theme.spaceS + 22 : Theme.spaceS; anchors.verticalCenter: parent.verticalCenter
					width: parent.width - x - optionDetail.implicitWidth - Theme.spaceL - 14; elide: Text.ElideRight
					text: modelData.label; font.pixelSize: 11
					color: !parent.usable ? Theme.textMuted : modelData.selected ? Theme.accentBright : Theme.textPrimary
				}
				HudText {
					id: optionDetail; anchors.right: check.left; anchors.rightMargin: Theme.spaceXS; anchors.verticalCenter: parent.verticalCenter
					text: modelData.detail || ""; font.pixelSize: 9; color: Theme.textMuted
				}
				HudIcon {
					id: check; anchors.right: parent.right; anchors.rightMargin: Theme.spaceS; anchors.verticalCenter: parent.verticalCenter
					width: 14; visible: modelData.selected === true; text: "󰄬"; font.pixelSize: 12; color: Theme.accentBright
				}
				MouseArea {
					anchors.fill: parent; hoverEnabled: true; enabled: parent.usable; cursorShape: Qt.PointingHandCursor
					onEntered: root.highlighted = index; onClicked: root.choose(index)
				}
			}
		}
	}
}
