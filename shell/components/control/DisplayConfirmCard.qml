import QtQuick
import "../../ui"

// "Keep these display settings?" Shown in the display page and, when that page is not open, over every screen.
// Waiting it out is safe: the guard restores the old layout by itself.
FocusScope {
	id: root
	required property var display
	implicitWidth: 380; implicitHeight: 138
	function focusDefault() { revertButton.forceActiveFocus() }
	Keys.onEscapePressed: event => { root.display.revert(); event.accepted = true }
	ControlFrame { anchors.fill: parent; cut: 6; fillColor: Theme.floatingSurface; gradientColor: Theme.background; strokeColor: Theme.accent }
	HudText {
		objectName: "displayConfirmTitle"
		x: Theme.spaceL; y: Theme.spaceM; width: parent.width - Theme.spaceL * 2
		text: "디스플레이 설정을 유지하시겠습니까?"; font.pixelSize: 14; font.bold: true; color: Theme.textPrimary
	}
	HudText {
		objectName: "displayConfirmText"
		x: Theme.spaceL; y: 38; width: parent.width - Theme.spaceL * 2; height: 40
		wrapMode: Text.WordWrap; maximumLineCount: 3; verticalAlignment: Text.AlignTop; font.pixelSize: 11
		color: root.display.stale ? Theme.warning : Theme.textSecondary
		text: root.display.stale ? "자동 복구가 응답하지 않습니다. 이전 설정으로 복원을 눌러 지금 되돌리세요."
			: "새로운 디스플레이 설정이 적용되었습니다.\n" + root.display.remaining + "초 이내에 확인하지 않으면 이전 설정으로 복원됩니다."
	}
	Row {
		anchors.right: parent.right; anchors.rightMargin: Theme.spaceL; anchors.bottom: parent.bottom; anchors.bottomMargin: Theme.spaceM
		spacing: Theme.spaceS
		HudButton { id: revertButton; objectName: "displayRevert"; width: 150; text: "이전 설정으로 복원"; onClicked: root.display.revert() }
		HudButton { objectName: "displayKeep"; width: 120; text: "변경 사항 유지"; active: true; enabled: !root.display.stale; onClicked: root.display.keep() }
	}
}
