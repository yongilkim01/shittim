import QtQuick
import "../../ui"
import "../../core/DisplayLayout.js" as Layout

// Monitor cards in Hyprland layout coordinates, fitted to the box. Dragging only reports where a card was dropped;
// the owner snaps it and decides. Outlines show where a changed screen is now.
Item {
	id: root
	property var items: []
	property var current: []
	property string selected: ""
	property bool locked: false
	property var numberOf: name => 0
	property var frozen: null
	property bool keyboardActive: false
	readonly property var view: frozen || fit(width, height, items, current)
	signal selectRequested(string name)
	signal moveRequested(string name, int x, int y)
	signal placeRequested(string name, string direction)

	function fit(width, height, items, current) {
		const rects = items.map(Layout.rect).concat(current.map(Layout.rect))
		if (!rects.length || width <= 0 || height <= 0) return {scale: 1, x: 0, y: 0}
		const left = Math.min(...rects.map(r => r.x)), top = Math.min(...rects.map(r => r.y))
		const right = Math.max(...rects.map(r => r.x + r.width)), bottom = Math.max(...rects.map(r => r.y + r.height))
		const pad = Theme.spaceM
		const scale = Math.min((width - pad * 2) / Math.max(1, right - left), (height - pad * 2) / Math.max(1, bottom - top))
		return {scale: scale, x: (width - (right - left) * scale) / 2 - left * scale, y: (height - (bottom - top) * scale) / 2 - top * scale}
	}
	function focusSelected() {
		for (let i = 0; i < cards.count; ++i)
			if (cards.itemAt(i) && cards.itemAt(i).modelData.name === selected) { cards.itemAt(i).forceActiveFocus(); return }
	}

	Repeater {
		model: root.current
		Rectangle {
			required property var modelData
			readonly property var r: Layout.rect(modelData)
			readonly property var next: root.items.find(item => item.name === modelData.name)
			readonly property var nextRect: next ? Layout.rect(next) : null
			objectName: "displayPrevious-" + modelData.name
			visible: nextRect !== null && (nextRect.x !== r.x || nextRect.y !== r.y || nextRect.width !== r.width || nextRect.height !== r.height)
			x: root.view.x + r.x * root.view.scale; y: root.view.y + r.y * root.view.scale
			width: r.width * root.view.scale; height: r.height * root.view.scale
			color: Theme.transparent; border.width: Theme.lineWidth; border.color: Theme.textMuted; opacity: 0.6
		}
	}

	Repeater {
		id: cards
		model: root.items
		Item {
			id: card
			required property var modelData
			readonly property var r: Layout.rect(modelData)
			readonly property bool chosen: modelData.name === root.selected
			objectName: "displayCard-" + modelData.name
			x: root.view.x + r.x * root.view.scale; y: root.view.y + r.y * root.view.scale
			width: r.width * root.view.scale; height: r.height * root.view.scale
			z: mouse.drag.active ? 3 : chosen ? 2 : 1
			activeFocusOnTab: true
			onActiveFocusChanged: root.keyboardActive = activeFocus
			Accessible.role: Accessible.Button
			Accessible.name: "모니터 " + root.numberOf(modelData.name)
			ControlFrame {
				anchors.fill: parent; cut: 3
				fillColor: card.chosen ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2) : Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.92)
				gradientColor: Theme.background
				strokeColor: card.chosen || card.activeFocus ? Theme.accent : Theme.border
			}
			// The selected card gets a second line, so it reads as selected without colour alone.
			Rectangle {
				anchors.fill: parent; anchors.margins: 1; visible: card.chosen
				color: Theme.transparent; border.width: Theme.lineWidth; border.color: Theme.accentBright
			}
			HudText {
				anchors.centerIn: parent; text: root.numberOf(card.modelData.name)
				font.pixelSize: Math.max(11, Math.min(26, card.height * 0.42)); font.bold: card.chosen
				color: card.chosen ? Theme.textPrimary : Theme.textSecondary
			}
			MouseArea {
				id: mouse
				anchors.fill: parent; hoverEnabled: true
				drag.target: root.locked ? null : card; drag.threshold: 3
				cursorShape: root.locked ? Qt.PointingHandCursor : drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
				onPressed: { root.frozen = root.view; root.selectRequested(card.modelData.name); card.forceActiveFocus() }
				onReleased: {
					if (drag.active || card.x !== root.view.x + card.r.x * root.view.scale)
						root.moveRequested(card.modelData.name, Math.round((card.x - root.view.x) / root.view.scale), Math.round((card.y - root.view.y) / root.view.scale))
					root.frozen = null
					card.x = Qt.binding(() => root.view.x + card.r.x * root.view.scale)
					card.y = Qt.binding(() => root.view.y + card.r.y * root.view.scale)
				}
				onCanceled: { root.frozen = null; card.x = Qt.binding(() => root.view.x + card.r.x * root.view.scale); card.y = Qt.binding(() => root.view.y + card.r.y * root.view.scale) }
			}
			Keys.onPressed: event => {
				const direction = {[Qt.Key_Left]: "left", [Qt.Key_Right]: "right", [Qt.Key_Up]: "up", [Qt.Key_Down]: "down"}[event.key]
				if (direction && !root.locked) { root.selectRequested(card.modelData.name); root.placeRequested(card.modelData.name, direction) }
				else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) root.selectRequested(card.modelData.name)
				else return
				event.accepted = true
			}
		}
	}
}
