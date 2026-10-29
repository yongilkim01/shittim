import QtQuick

// Drop-down field. It only shows the current choice and asks to be opened; the page that owns it shows the choices
// in a HudOptionList, so the list stays inside the surface and is never clipped by it.
Item {
	id: root
	property string glyph: ""
	property string text: ""
	property string detail: ""
	property bool open: false
	readonly property bool hovered: mouse.containsMouse
	signal activated()
	implicitWidth: 200
	implicitHeight: Theme.controlHeight
	activeFocusOnTab: enabled
	Accessible.role: Accessible.ComboBox
	Accessible.name: text
	Keys.onReturnPressed: if (enabled) activated()
	Keys.onSpacePressed: if (enabled) activated()
	Keys.onDownPressed: if (enabled) activated()
	HudFrame {
		anchors.fill: parent
		level: "control"
		cutTopLeft: 0; cutTopRight: 0; cutBottomLeft: 0; cutBottomRight: Theme.controlCut
		active: root.open || root.activeFocus
		fillColor: !root.enabled ? Theme.disabledFill : root.open ? Theme.selectedFill : root.hovered ? Theme.hoverFill : Theme.surface
		strokeColor: !root.enabled ? Theme.border : root.open || root.activeFocus ? Theme.accent : root.hovered ? Theme.accentDim : Theme.border
	}
	HudIcon {
		id: icon
		visible: root.glyph.length > 0
		x: Theme.spaceS; anchors.verticalCenter: parent.verticalCenter; width: 16
		text: root.glyph; font.pixelSize: 13; color: root.enabled ? Theme.accent : Theme.textMuted
	}
	HudText {
		x: icon.visible ? Theme.spaceS + 22 : Theme.spaceS
		anchors.verticalCenter: parent.verticalCenter
		width: Math.max(0, chevron.x - x - (detailText.visible ? detailText.implicitWidth + Theme.spaceS : 0) - Theme.spaceXS)
		text: root.text; font.pixelSize: 11; elide: Text.ElideRight
		color: !root.enabled ? Theme.textMuted : Theme.textPrimary
	}
	HudText {
		id: detailText
		visible: root.detail.length > 0 && root.width > 160
		anchors.right: chevron.left; anchors.rightMargin: Theme.spaceXS; anchors.verticalCenter: parent.verticalCenter
		text: root.detail; font.pixelSize: 9; color: Theme.textMuted
	}
	HudIcon {
		id: chevron
		anchors.right: parent.right; anchors.rightMargin: Theme.spaceS; anchors.verticalCenter: parent.verticalCenter
		text: root.open ? "󰅃" : "󰅀"; font.pixelSize: 13
		color: !root.enabled ? Theme.textMuted : root.open || root.hovered ? Theme.accentBright : Theme.textSecondary
	}
	MouseArea {
		id: mouse; anchors.fill: parent; hoverEnabled: true; enabled: root.enabled
		cursorShape: Qt.PointingHandCursor
		onClicked: { root.forceActiveFocus(); root.activated() }
	}
}
