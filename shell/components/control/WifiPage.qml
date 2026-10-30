import QtQuick
import QtQuick.Layouts
import "../../ui"

ColumnLayout {
	id: root
	required property var network
	signal navigate(string destination)
	spacing: Theme.spaceS
	RowLayout {
		HudText { text: "Wi-Fi"; textStyle: "body"; Layout.fillWidth: true }
		HudButton { text: root.network.wifiEnabled ? "끄기" : "켜기"; enabled: root.network.backendAvailable && root.network.wifiDevices.length > 0; active: root.network.wifiEnabled; onClicked: root.network.toggleWifi() }
		HudButton { text: "검색"; enabled: root.network.wifiEnabled; onClicked: root.network.refresh() }
	}
	HudText {
		Layout.fillWidth: true; wrapMode: Text.WordWrap; maximumLineCount: 3
		text: !root.network.backendAvailable ? "NetworkManager 서비스를 사용할 수 없습니다."
			: root.network.wifiDevices.length === 0 ? "Wi-Fi 장치가 없습니다."
			: root.network.wifiConnected ? "연결됨 · " + root.network.ssid : root.network.wifiEnabled ? "연결할 네트워크를 선택하세요." : "Wi-Fi가 꺼졌거나 하드웨어로 차단되었습니다."
		color: root.network.wifiConnected ? Theme.accentBright : Theme.textSecondary
	}
	Repeater {
		model: root.network.wifiDevices.length > 1 ? root.network.wifiDevices : []
		HudButton {
			required property var modelData
			Layout.fillWidth: true; text: modelData.name; active: root.network.controlDevice === modelData
			onClicked: root.network.selectedDevice = modelData
		}
	}
	HudText { visible: root.network.wiredDevices.length > 0; text: root.network.wiredConnected ? "Ethernet · 연결됨" : "Ethernet · 연결되지 않음"; textStyle: "caption" }
	HudText {
		visible: root.network.error.length > 0; text: root.network.error; color: Theme.danger
		Layout.fillWidth: true; wrapMode: Text.WordWrap; maximumLineCount: 4
	}
	ColumnLayout {
		visible: root.network.needsPassword
		Layout.fillWidth: true
		HudText { text: root.network.pendingNetwork !== null ? root.network.pendingNetwork.name : ""; Layout.fillWidth: true }
		HudInput {
			id: password; objectName: "wifiPassword"; Layout.fillWidth: true; echoMode: TextInput.Password
			placeholderText: "Wi-Fi 비밀번호"; maximumLength: 64
			onAccepted: if (text.length > 0) { root.network.submitPassword(text); clear() }
			Component.onDestruction: clear()
		}
		RowLayout {
			HudButton { text: "연결"; enabled: password.text.length > 0; onClicked: { root.network.submitPassword(password.text); password.clear() } }
			HudButton { text: "취소"; onClicked: { password.clear(); root.network.resetPrompt() } }
		}
	}
	Connections {
		target: root.network
		function onNeedsPasswordChanged() { password.clear(); if (root.network.needsPassword) password.forceActiveFocus() }
	}
	Repeater {
		model: root.network.wifiEnabled ? root.network.networks : []
		HudPanel {
			id: entry
			required property var modelData
			Layout.fillWidth: true; implicitHeight: 60; active: modelData.connected
			RowLayout {
				anchors.fill: parent; anchors.margins: Theme.spaceS
				ColumnLayout {
					Layout.fillWidth: true
					HudText { text: entry.modelData.name; Layout.fillWidth: true; color: entry.modelData.connected ? Theme.accent : Theme.textPrimary }
					HudText { text: Math.round(entry.modelData.signalStrength * 100) + "% · " + (entry.modelData.known ? "저장됨" : "미저장"); textStyle: "caption" }
				}
				HudButton {
					text: entry.modelData.stateChanging ? "진행 중" : entry.modelData.connected ? "해제" : "연결"
					enabled: !entry.modelData.stateChanging && !root.network.busy
					onClicked: { password.clear(); root.network.connectNetwork(entry.modelData) }
				}
			}
		}
	}
	HudText { visible: root.network.wifiEnabled && root.network.networks.length === 0; text: "검색 결과가 없습니다. 잠시 후 다시 검색하세요."; Layout.fillWidth: true; wrapMode: Text.WordWrap; maximumLineCount: 2 }
	HudButton { objectName: "wifiOpenSettings"; text: "네트워크 설정 열기"; Layout.fillWidth: true; onClicked: root.navigate("network-settings") }
	HudButton { text: "기업용 / 숨겨진 네트워크 설정"; Layout.fillWidth: true; onClicked: root.network.openEditor() }
}
