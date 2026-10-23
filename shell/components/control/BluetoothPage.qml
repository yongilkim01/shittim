import QtQuick
import QtQuick.Layouts
import "../../ui"

ColumnLayout {
	id: root
	required property var system
	spacing: Theme.spaceS
	RowLayout {
		HudText { text: "Bluetooth"; Layout.fillWidth: true; textStyle: "body" }
		HudButton { text: root.system.adapter !== null && root.system.adapter.enabled ? "끄기" : "켜기"; enabled: root.system.adapter !== null; onClicked: root.system.toggleBluetooth() }
		HudButton { text: root.system.adapter !== null && root.system.adapter.discovering ? "검색 중" : "검색"; enabled: root.system.adapter !== null && root.system.adapter.enabled; onClicked: root.system.searchBluetooth() }
	}
	HudText {
		Layout.fillWidth: true; wrapMode: Text.WordWrap; maximumLineCount: 3
		text: root.system.adapter === null ? "Bluetooth 어댑터가 없습니다."
			: !root.system.bluetoothReady ? "Bluetooth 서비스를 확인 중입니다."
			: root.system.adapter.enabled ? "장치를 페어링 모드로 전환하고 검색하세요." : "Bluetooth가 꺼져 있습니다."
	}
	Repeater {
		model: root.system.adapters.length > 1 ? root.system.adapters : []
		HudButton {
			required property var modelData
			Layout.fillWidth: true; text: modelData.name; active: root.system.adapter === modelData
			onClicked: { root.system.stopDiscovery(); root.system.selectedAdapter = modelData }
		}
	}
	Repeater {
		model: root.system.adapter !== null && root.system.adapter.enabled ? root.system.devices : []
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
					enabled: root.system.ready && root.system.bluetoothReady && !root.system.busy && !entry.modelData.pairing
					onClicked: root.system.deviceAction(entry.modelData)
				}
			}
		}
	}
	HudText { visible: root.system.devices.length === 0; text: "표시할 장치가 없습니다."; color: Theme.textMuted }
}
