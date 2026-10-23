import QtQuick
import QtQuick.Layouts
import "../../ui"

FocusScope {
	id: root
	required property var audio
	required property var network
	required property var battery
	required property var system
	property var notifications: null
	property bool embedded: false
	property string page: "overview"
	signal navigate(string destination)
	signal closeRequested()
	Keys.onEscapePressed: event => { root.closeRequested(); event.accepted = true }
	ColumnLayout {
		anchors.fill: parent; anchors.margins: root.page === "overview" ? 0 : Theme.spaceL; spacing: root.page === "overview" ? 0 : Theme.spaceM
		RowLayout {
			objectName: "controlHeader"
			visible: root.page !== "overview" && !root.embedded
			HudButton { visible: root.page !== "overview"; text: "󰁍"; onClicked: root.navigate("overview") }
			HudText { text: "CONTROL CENTER"; textStyle: "section"; color: Theme.accent; Layout.fillWidth: true }
			HudButton { text: "󰅖"; onClicked: root.closeRequested() }
		}
		HudDivider { visible: root.page !== "overview" && !root.embedded; vertical: false; Layout.fillWidth: true }
		HudText {
			text: root.system.error; visible: root.page !== "overview" && text.length > 0; color: Theme.danger
			Layout.fillWidth: true; wrapMode: Text.WordWrap; maximumLineCount: 4
		}
		HudPanel {
			visible: root.system.prompt !== null; Layout.fillWidth: true
			implicitHeight: promptColumn.implicitHeight + Theme.spaceM * 2; active: true
			ColumnLayout {
				id: promptColumn; anchors.fill: parent; anchors.margins: Theme.spaceM
				HudText { text: "Bluetooth 인증"; color: Theme.accent; textStyle: "section" }
				HudText {
					Layout.fillWidth: true; wrapMode: Text.WordWrap; maximumLineCount: 3
					text: root.system.prompt === null ? "" : root.system.prompt.kind === "display"
						? "상대 장치에서 코드를 입력하세요: " + root.system.prompt.code
						: root.system.prompt.kind === "confirm" ? "코드가 일치합니까? " + root.system.prompt.code : "이 장치의 페어링을 허용합니까?"
				}
				HudInput {
					id: pin; Layout.fillWidth: true; maximumLength: 16; echoMode: TextInput.Password; placeholderText: "장치 PIN / 숫자 코드"
					visible: root.system.prompt !== null && ["pin", "passkey"].indexOf(root.system.prompt.kind) >= 0
					Component.onDestruction: clear()
				}
				RowLayout {
					HudButton {
						text: "허용"; visible: root.system.prompt !== null && root.system.prompt.kind !== "display"
						enabled: !pin.visible || pin.text.length > 0
						onClicked: { root.system.answerPrompt(true, pin.text); pin.clear() }
					}
					HudButton { text: "취소"; onClicked: { root.system.cancelPair(); pin.clear() } }
				}
			}
		}
		Flickable {
			id: viewport; objectName: "controlViewport"; Layout.fillWidth: true; Layout.fillHeight: true
			clip: true; contentWidth: width; contentHeight: pageLoader.item ? pageLoader.item.implicitHeight : 0
			boundsBehavior: Flickable.StopAtBounds; flickableDirection: Flickable.VerticalFlick
			Loader {
				id: pageLoader; width: viewport.width
				sourceComponent: root.page === "wifi" ? wifiPage : root.page === "bluetooth" ? bluetoothPage
					: root.page === "audio" ? audioPage : root.page === "brightness" ? brightnessPage
					: root.page === "power" ? powerPage : root.page === "settings" ? settingsPage : overviewPage
				onLoaded: viewport.contentY = 0
			}
		}
	}
	Connections { target: root.system; function onPromptChanged() { pin.clear(); if (pin.visible) pin.forceActiveFocus() } }
	Component { id: overviewPage; ControlOverview { audio: root.audio; network: root.network; battery: root.battery; system: root.system; notifications: root.notifications; onNavigate: destination => root.navigate(destination) } }
	Component { id: wifiPage; WifiPage { network: root.network; system: root.system } }
	Component { id: bluetoothPage; BluetoothPage { system: root.system } }
	Component { id: audioPage; AudioPage { audio: root.audio } }
	Component { id: brightnessPage; BrightnessPage { system: root.system } }
	Component { id: powerPage; PowerPage { battery: root.battery; system: root.system } }
	Component { id: settingsPage; SettingsPage { system: root.system; onNavigate: destination => root.navigate(destination) } }
}
