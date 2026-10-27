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
	cut: 4
	fillColor: active ? Theme.surfaceElevated : Theme.surface
	gradientColor: active ? Theme.surface : Theme.background
	strokeColor: active ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.75) : Qt.rgba(Theme.border.r, Theme.border.g, Theme.border.b, 0.55)
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
	Controls.ToolTip.visible: mouse.containsMouse && hint.length > 0
	Controls.ToolTip.text: hint
	Controls.ToolTip.delay: 500
	Keys.onReturnPressed: if (interactive) clicked()
	Keys.onSpacePressed: if (interactive) clicked()
	activeFocusOnTab: interactive
}
