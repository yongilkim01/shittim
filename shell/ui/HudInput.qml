import QtQuick
import QtQuick.Controls.Basic as Controls

Controls.TextField {
	id: root
	implicitHeight: 36
	color: Theme.textPrimary
	placeholderTextColor: Theme.textMuted
	// An empty field shows its placeholder in the same font, so a Korean hint needs the Korean font too.
	font.family: /[\u1100-\u11ff\u3130-\u318f\uac00-\ud7af]/.test(text || placeholderText) ? Theme.fontKorean : Theme.fontMono
	font.pixelSize: Theme.textStatus
	selectByMouse: true
	background: Rectangle {
		color: Theme.background
		border.width: Theme.lineWidth
		border.color: root.activeFocus ? Theme.accent : Theme.border
	}
}
