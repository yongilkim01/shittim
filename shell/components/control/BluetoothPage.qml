import QtQuick
import QtQuick.Layouts
import "../../ui"

ColumnLayout {
	id: root
	required property var bluetooth
	spacing: Theme.spaceS
	RowLayout {
		HudText { text: "Bluetooth"; Layout.fillWidth: true; textStyle: "body" }
		HudButton { text: root.bluetooth.adapter !== null && root.bluetooth.adapter.enabled ? "끄기" : "켜기"; enabled: root.bluetooth.adapter !== null; onClicked: root.bluetooth.toggleBluetooth() }
		HudButton { text: root.bluetooth.adapter !== null && root.bluetooth.adapter.discovering ? "검색 중" : "검색"; enabled: root.bluetooth.adapter !== null && root.bluetooth.adapter.enabled; onClicked: root.bluetooth.searchBluetooth() }
	}
	HudText {
		Layout.fillWidth: true; wrapMode: Text.WordWrap; maximumLineCount: 3
		text: root.bluetooth.adapter === null ? "Bluetooth 어댑터가 없습니다."
			: !root.bluetooth.bluetoothReady ? "Bluetooth 서비스를 확인 중입니다."
			: root.bluetooth.adapter.enabled ? "장치를 페어링 모드로 전환하고 검색하세요." : "Bluetooth가 꺼져 있습니다."
	}
	Repeater {
		model: root.bluetooth.adapters.length > 1 ? root.bluetooth.adapters : []
		HudButton {
			required property var modelData
			Layout.fillWidth: true; text: modelData.name; active: root.bluetooth.adapter === modelData
			onClicked: { root.bluetooth.stopDiscovery(); root.bluetooth.selectedAdapter = modelData }
		}
	}
	Repeater {
		model: root.bluetooth.adapter !== null && root.bluetooth.adapter.enabled ? root.bluetooth.devices : []
		HudPanel {
			id: entry
			required property var modelData
			Layout.fillWidth: true; implicitHeight: 66; active: modelData.connected
			RowLayout {
				anchors.fill: parent; anchors.margins: Theme.spaceS
				ColumnLayout {
					Layout.fillWidth: true
					HudText { text: entry.modelData.name || entry.modelData.address; Layout.fillWidth: true }
					HudText {
						text: (entry.modelData.connected ? "연결됨" : entry.modelData.paired ? "페어링됨" : "검색된 장치")
							+ (entry.modelData.batteryAvailable ? " · " + Math.round(entry.modelData.battery * 100) + "%" : "")
						textStyle: "caption"
					}
				}
				HudButton {
					text: entry.modelData.pairing ? "페어링 중" : entry.modelData.connected ? "해제" : entry.modelData.paired ? "연결" : "페어링"
					enabled: root.bluetooth.ready && root.bluetooth.bluetoothReady && !root.bluetooth.busy && !entry.modelData.pairing
					onClicked: root.bluetooth.deviceAction(entry.modelData)
				}
			}
		}
	}
	HudText { visible: root.bluetooth.devices.length === 0; text: "표시할 장치가 없습니다."; color: Theme.textMuted }
}
