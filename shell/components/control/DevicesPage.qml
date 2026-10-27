import QtQuick
import QtQuick.Layouts
import "../../ui"

// Meeting device overview: microphone, camera and screen sharing as observed by the system.
// Permissions stay with the browser and the portal picker; nothing here grants or starts capture.
ColumnLayout {
	id: root
	property var microphone: null
	property var camera: null
	property var screenShare: null
	signal navigate(string destination)
	spacing: Theme.spaceS

	HudText { text: "마이크"; textStyle: "section"; color: Theme.accent }
	HudPanel {
		Layout.fillWidth: true; implicitHeight: micRow.implicitHeight + Theme.spaceM * 2
		active: root.microphone !== null && root.microphone.inUse
		RowLayout {
			id: micRow; anchors.fill: parent; anchors.margins: Theme.spaceM
			HudIcon { text: root.microphone !== null && root.microphone.muted ? "󰍭" : "󰍬"; color: root.microphone !== null && root.microphone.muted ? Theme.danger : Theme.accent }
			HudText {
				objectName: "devicesMicrophoneStatus"
				Layout.fillWidth: true; wrapMode: Text.WordWrap; maximumLineCount: 3
				text: root.microphone === null || !root.microphone.available ? "입력 장치 없음"
					: (root.microphone.muted ? "음소거 · " : root.microphone.inUse ? "사용 중 · " : "대기 · ") + root.microphone.deviceName
					+ (root.microphone.inUse ? "\n" + root.microphone.applications.join(", ") : "")
			}
			HudButton {
				visible: root.microphone !== null; enabled: root.microphone !== null && root.microphone.available
				text: root.microphone !== null && root.microphone.muted ? "음소거 해제" : "음소거"
				active: root.microphone !== null && root.microphone.muted
				onClicked: root.microphone.toggleMute()
			}
		}
	}
	HudButton { text: "입력·출력 장치 선택"; Layout.fillWidth: true; onClicked: root.navigate("audio") }

	HudText { text: "카메라"; textStyle: "section"; color: Theme.accent; Layout.topMargin: Theme.spaceM }
	Repeater {
		model: root.camera !== null ? root.camera.cameras : []
		HudPanel {
			required property var modelData
			Layout.fillWidth: true; implicitHeight: cameraRow.implicitHeight + Theme.spaceM * 2
			active: modelData.users && modelData.users.length > 0
			RowLayout {
				id: cameraRow; anchors.fill: parent; anchors.margins: Theme.spaceM
				HudIcon { text: "󰄀"; color: modelData.error ? Theme.warning : Theme.accent }
				HudText {
					Layout.fillWidth: true; wrapMode: Text.WordWrap; maximumLineCount: 3
					text: modelData.name + "\n" + (modelData.error === "permission" ? "접근 권한 없음 · 다시 로그인한 뒤 확인하세요"
						: modelData.error ? "장치 상태를 읽지 못함"
						: modelData.users.length > 0 ? "사용 중 · " + modelData.users.join(", ") : "사용 가능")
					color: modelData.error ? Theme.warning : Theme.textPrimary
				}
			}
		}
	}
	HudText {
		objectName: "devicesCameraEmpty"
		visible: root.camera !== null && root.camera.ready && !root.camera.present; Layout.fillWidth: true; wrapMode: Text.WordWrap; maximumLineCount: 2
		text: "카메라 장치 없음. USB 웹캠을 연결하면 자동으로 표시됩니다."; color: Theme.textMuted
	}
	RowLayout {
		visible: root.camera !== null && root.camera.error.length > 0; Layout.fillWidth: true
		HudText { text: root.camera !== null ? root.camera.error : ""; Layout.fillWidth: true; wrapMode: Text.WordWrap; maximumLineCount: 3; color: Theme.danger }
		HudButton { text: "다시 연결"; onClicked: root.camera.restart() }
	}

	HudText { text: "화면 공유"; textStyle: "section"; color: Theme.accent; Layout.topMargin: Theme.spaceM }
	HudPanel {
		Layout.fillWidth: true; implicitHeight: shareColumn.implicitHeight + Theme.spaceM * 2
		active: root.screenShare !== null && root.screenShare.active
		ColumnLayout {
			id: shareColumn; anchors.fill: parent; anchors.margins: Theme.spaceM; spacing: Theme.spaceXS
			HudText {
				objectName: "devicesShareStatus"
				text: root.screenShare !== null && root.screenShare.active
					? "공유 중" + (root.screenShare.count > 1 ? " · 스트림 " + root.screenShare.count + "개" : "") : "공유하지 않음"
				color: root.screenShare !== null && root.screenShare.active ? Theme.warning : Theme.textPrimary
			}
			HudText {
				Layout.fillWidth: true; wrapMode: Text.WordWrap; maximumLineCount: 4; textStyle: "caption"
				text: "회의 앱에서 화면 공유를 누르면 모니터·창 선택 창이 열립니다. 공유는 그 선택 후에만 시작되며, 중지는 회의 앱의 '공유 중지' 버튼으로 합니다."
			}
		}
	}
}
