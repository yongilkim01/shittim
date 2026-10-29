import QtQuick
import QtQuick.Controls.Basic as Controls
import "../../ui"

ControlFrame {
	id: root
	property string title: ""
	property string detail: ""
	property string glyph: ""
	property bool large: false
	property bool glyphDisc: large && active
	property bool interactive: true
	property string hint: ""
	signal clicked()
	signal detailsRequested()
	cut: 6
	// State priority: unavailable > pressed > on > hover > rest. Only an "on" tile earns corner accents.
	hovered: interactive && mouse.containsMouse
	fillColor: !interactive ? Theme.disabledFill : mouse.pressed ? Theme.pressedFill : active ? Theme.selectedFill : hovered ? Theme.hoverFill : Theme.surface
	gradientColor: !interactive ? Theme.background : active ? Theme.transparent : Theme.background
	strokeColor: !interactive ? Qt.rgba(Theme.border.r, Theme.border.g, Theme.border.b, 0.5) : active || mouse.pressed ? Theme.accent : hovered ? Theme.accentDim : Theme.border
	accentLength: active && interactive ? Theme.cardAccent : 0
	accentColor: Theme.accentBright
	Behavior on fillColor { ColorAnimation { duration: mouse.pressed ? Theme.pressDuration : Theme.hoverDuration; easing.type: Theme.easing } }
	Column {
		width: root.width - 8
		anchors.centerIn: parent
		spacing: root.large ? 2 : 3
		Item {
			anchors.horizontalCenter: parent.horizontalCenter
			width: root.large ? 28 : 22; height: width
			Rectangle { anchors.fill: parent; visible: root.glyphDisc; radius: width / 2; color: Theme.accent }
			HudIcon {
				anchors.centerIn: parent; width: parent.width; text: root.glyph; font.pixelSize: root.large ? 30 : 28
				color: !root.interactive ? Theme.textMuted : root.glyphDisc ? Theme.background : Theme.accentBright
			}
		}
		HudText { text: root.title; font.pixelSize: 10; width: parent.width; horizontalAlignment: Text.AlignHCenter; color: root.interactive ? Theme.textPrimary : Theme.textMuted }
		HudText { visible: root.large; text: root.detail; font.pixelSize: Theme.textCaption; color: Theme.accentDim; width: Math.min(implicitWidth, root.width - 8); horizontalAlignment: Text.AlignHCenter; anchors.horizontalCenter: parent.horizontalCenter }
	}
	MouseArea {
		id: mouse; anchors.fill: parent; hoverEnabled: true
		acceptedButtons: Qt.LeftButton | Qt.RightButton
		cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
		onClicked: event => {
			if (!root.interactive) return
			if (event.button === Qt.RightButton) root.detailsRequested()
			else root.clicked()
		}
	}
	// Optional detailed card {glyph, title, rows}; otherwise the hint is a one-line card.
	property var info: null
	Controls.ToolTip {
		id: tip; objectName: "tileTip"
		visible: mouse.containsMouse && (root.info !== null || root.hint.length > 0)
		delay: 500; padding: 0; margins: 0
		background: null
		// Above the tile, or below it when the panel has no room above.
		readonly property bool below: root.mapToItem(null, 0, 0).y < implicitHeight + Theme.spaceS
		x: (root.width - implicitWidth) / 2
		y: below ? root.height + Theme.spaceXS : -implicitHeight - Theme.spaceXS
		onAboutToShow: card.arrow = below ? "top" : "bottom"
		contentItem: HudInfoCard {
			id: card; arrow: "bottom"
			glyph: root.info ? root.info.glyph : ""; title: root.info ? root.info.title : root.hint; rows: root.info ? root.info.rows : []
		}
	}
	Keys.onReturnPressed: if (interactive) clicked()
	Keys.onSpacePressed: if (interactive) clicked()
	activeFocusOnTab: interactive
}
