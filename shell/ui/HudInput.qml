import QtQuick
import QtQuick.Controls.Basic as Controls

Controls.TextField {
	id: root
	implicitHeight: 36
	color: Theme.textPrimary
	placeholderTextColor: Theme.textMuted
	font.family: /[\u1100-\u11ff\u3130-\u318f\uac00-\ud7af]/.test(text) ? Theme.fontKorean : Theme.fontMono
	font.pixelSize: Theme.textStatus
	selectByMouse: true
	background: Rectangle {
		color: Theme.background
		border.width: Theme.lineWidth
		border.color: root.activeFocus ? Theme.accent : Theme.border
	}
}
