import QtQuick
import Quickshell
import "../ui"

// HUD card under a bar item. A popup, so it is not clipped by the bar's height.
PopupWindow {
	id: root
	property Item target: null
	// {glyph, title, rows} as HudInfoCard takes it; null hides the popup.
	property var card: null
	property bool shown: false
	visible: shown && card !== null && target !== null
	onTargetChanged: {
		shown = false
		if (target !== null) delay.restart(); else delay.stop()
	}
	Timer { id: delay; interval: 300; onTriggered: { root.anchor.updateAnchor(); root.shown = true } }
	anchor.item: target
	anchor.edges: Edges.Bottom
	anchor.gravity: Edges.Bottom
	implicitWidth: info.implicitWidth
	implicitHeight: info.implicitHeight
	color: Theme.transparent
	mask: Region {}
	HudInfoCard {
		id: info; anchors.fill: parent; arrow: "top"
		glyph: root.card ? root.card.glyph : ""; title: root.card ? root.card.title : ""; rows: root.card ? root.card.rows : []
		minimumWidth: 240
	}
}
