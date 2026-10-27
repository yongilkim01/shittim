import QtQuick
import QtQuick.Layouts
import "../../ui"
import "../../core"

FocusScope {
	id: root
	required property var audio
	required property var network
	required property var battery
	required property var bluetooth
	required property var brightness
	required property var power
	required property var capture
	required property var metrics
	readonly property bool consuming:visible && Window.window!==null && Window.window.visible
	readonly property var currentService:page==="bluetooth" ? bluetooth : page==="brightness" ? brightness : page==="power" ? power : page==="settings" ? metrics : capture
	readonly property string actionError:page==="overview" ? [brightness.error,bluetooth.error,capture.error].filter((text,index,list)=>text && list.indexOf(text)===index).join("\n") : currentService.error
	ServiceLease {service:root.network;active:root.consuming && root.page==="wifi"}
	ServiceLease {service:root.bluetooth;active:root.consuming && ["overview","bluetooth"].indexOf(root.page)>=0}
	ServiceLease {service:root.brightness;active:root.consuming && ["overview","brightness"].indexOf(root.page)>=0}
	ServiceLease {service:root.power;active:root.consuming && root.page==="power"}
	ServiceLease {service:root.capture;active:root.consuming && root.page==="overview"}
	ServiceLease {service:root.metrics;active:root.consuming && root.page==="settings"}
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
			text: root.actionError; visible: text.length > 0; color: Theme.danger
			Layout.fillWidth: true; wrapMode: Text.WordWrap; maximumLineCount: 4
		}
		HudPanel {
			visible: root.bluetooth.prompt !== null; Layout.fillWidth: true
			implicitHeight: promptColumn.implicitHeight + Theme.spaceM * 2; active: true
			ColumnLayout {
				id: promptColumn; anchors.fill: parent; anchors.margins: Theme.spaceM
				HudText { text: "Bluetooth 인증"; color: Theme.accent; textStyle: "section" }
				HudText {
					Layout.fillWidth: true; wrapMode: Text.WordWrap; maximumLineCount: 3
					text: root.bluetooth.prompt === null ? "" : root.bluetooth.prompt.kind === "display"
						? "상대 장치에서 코드를 입력하세요: " + root.bluetooth.prompt.code
						: root.bluetooth.prompt.kind === "confirm" ? "코드가 일치합니까? " + root.bluetooth.prompt.code : "이 장치의 페어링을 허용합니까?"
				}
				HudInput {
					id: pin; Layout.fillWidth: true; maximumLength: 16; echoMode: TextInput.Password; placeholderText: "장치 PIN / 숫자 코드"
					visible: root.bluetooth.prompt !== null && ["pin", "passkey"].indexOf(root.bluetooth.prompt.kind) >= 0
					Component.onDestruction: clear()
				}
				RowLayout {
					HudButton {
						text: "허용"; visible: root.bluetooth.prompt !== null && root.bluetooth.prompt.kind !== "display"
						enabled: !pin.visible || pin.text.length > 0
						onClicked: { root.bluetooth.answerPrompt(true, pin.text); pin.clear() }
					}
					HudButton { text: "취소"; onClicked: { root.bluetooth.cancelPair(); pin.clear() } }
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
	Connections { target: root.bluetooth; function onPromptChanged() { pin.clear(); if (pin.visible) pin.forceActiveFocus() } }
	Component { id: overviewPage; ControlOverview { audio: root.audio; network: root.network; battery: root.battery; bluetooth: root.bluetooth; brightness: root.brightness; capture: root.capture; notifications: root.notifications; onNavigate: destination => root.navigate(destination) } }
	Component { id: wifiPage; WifiPage { network: root.network } }
	Component { id: bluetoothPage; BluetoothPage { bluetooth: root.bluetooth } }
	Component { id: audioPage; AudioPage { audio: root.audio } }
	Component { id: brightnessPage; BrightnessPage { brightness: root.brightness } }
	Component { id: powerPage; PowerPage { battery: root.battery; power: root.power } }
	Component { id: settingsPage; SettingsPage { metrics: root.metrics; onNavigate: destination => root.navigate(destination) } }
}
