import QtQuick
import "../../ui"

// "Keep these network settings?" Shown in the network page and, when that page is not open, over every screen.
// Waiting it out is safe: NetworkManager's checkpoint restores the previous settings by itself.
FocusScope {
	id: root
	required property var settings
	implicitWidth: 380; implicitHeight: 138
	function focusDefault() { revertButton.forceActiveFocus() }
	Keys.onEscapePressed: event => { root.settings.revert(); event.accepted = true }
	ControlFrame { anchors.fill: parent; cut: 6; fillColor: Theme.floatingSurface; gradientColor: Theme.background; strokeColor: Theme.accent }
	HudText {
		objectName: "networkConfirmTitle"
		x: Theme.spaceL; y: Theme.spaceM; width: parent.width - Theme.spaceL * 2
		text: "변경된 네트워크 설정을 유지하시겠습니까?"; font.pixelSize: 14; font.bold: true; color: Theme.textPrimary
	}
	HudText {
		objectName: "networkConfirmText"
		x: Theme.spaceL; y: 38; width: parent.width - Theme.spaceL * 2; height: 40
		wrapMode: Text.WordWrap; maximumLineCount: 3; verticalAlignment: Text.AlignTop; font.pixelSize: 11; color: Theme.textSecondary
		text: (root.settings.checkpoint && root.settings.checkpoint.name ? "«" + root.settings.checkpoint.name + "» 설정을 적용했습니다.\n" : "새 네트워크 설정을 적용했습니다.\n")
			+ root.settings.remaining + "초 안에 선택하지 않으면 이전 설정으로 자동 복원됩니다."
	}
	Row {
		anchors.right: parent.right; anchors.rightMargin: Theme.spaceL; anchors.bottom: parent.bottom; anchors.bottomMargin: Theme.spaceM
		spacing: Theme.spaceS
		HudButton { id: revertButton; objectName: "networkRevert"; width: 150; text: "이전 설정으로 복원"; enabled: !root.settings.busy; onClicked: root.settings.revert() }
		HudButton { objectName: "networkKeep"; width: 120; text: "변경 사항 유지"; active: true; enabled: !root.settings.busy; onClicked: root.settings.keep() }
	}
}
