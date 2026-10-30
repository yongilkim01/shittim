import QtQuick
import Quickshell.Networking as Net
import "../ui"
import "../services"
import "../core/NetworkData.js" as NetworkData

Row {
	id: root
	property bool compact: false
	spacing: Theme.spaceXS

	readonly property bool backendAvailable: NetworkState.backendAvailable
	readonly property var devices: NetworkState.devices
	readonly property var wifiDevices: NetworkState.wifiDevices
	readonly property var wiredDevices: NetworkState.wiredDevices
	readonly property bool wiredConnected: NetworkState.wiredConnected
	readonly property var wifiDevice: NetworkState.wifiDevice
	readonly property bool wifiEnabled: NetworkState.wifiEnabled
	readonly property bool wifiConnected: NetworkState.wifiConnected
	readonly property var wifiNetwork: NetworkState.wifiNetwork
	readonly property string ssid: NetworkState.ssid
	readonly property real signalStrength: NetworkState.signalStrength
	readonly property string wifiIcon: {
		if (!wifiEnabled) return "󰤮"
		if (!wifiConnected || wifiNetwork === null) return "󰤯"
		if (signalStrength >= 0.75) return compact ? "\uf1eb" : "󰤨"
		if (signalStrength >= 0.50) return "󰤥"
		if (signalStrength >= 0.25) return "󰤢"
		return "󰤟"
	}
	readonly property string wifiStatus: {
		if (!Net.Networking.wifiHardwareEnabled) return "Wi-Fi blocked"
		if (!Net.Networking.wifiEnabled) return "Wi-Fi off"
		if (wifiConnected) return ssid.length > 0 ? ssid : "Wi-Fi connected"
		if (wifiDevice !== null && wifiDevice.state === Net.ConnectionState.Connecting)
			return "Wi-Fi connecting"
		if (wifiDevice !== null && wifiDevice.state === Net.ConnectionState.Disconnecting)
			return "Wi-Fi disconnecting"
		return "Wi-Fi disconnected"
	}

	// Hover card for BarTooltip: which network, signal, and whether the internet is actually reachable.
	readonly property bool internetLimited: NetworkState.internetLimited
	readonly property Item hoveredItem: wifiItem.visible && wifiItem.hovered ? wifiItem : wiredItem.visible && wiredItem.hovered ? wiredItem : null
	readonly property var card: hoveredItem === null ? null : hoveredItem === wifiItem ? {
		glyph: wifiIcon, title: wifiConnected ? ssid : wifiStatusKorean,
		rows: (wifiConnected ? [{glyph: "󰤨", text: "신호 " + Math.round(signalStrength * 100) + "% · " + NetworkData.signalLabel(signalStrength * 100)}] : [])
			.concat([{glyph: "", text: NetworkData.connectivityText(NetworkState.connectivity)}, {glyph: "󰒓", text: "클릭: 빠른 설정 · 대시보드 › 네트워크에서 자세히"}])
	} : {
		glyph: wiredConnected ? "󰈀" : "󰌙", title: wiredConnected ? "유선 연결됨" : "유선 연결 안 됨",
		rows: [{glyph: "", text: NetworkData.connectivityText(NetworkState.connectivity)}]
	}
	readonly property string wifiStatusKorean: !Net.Networking.wifiHardwareEnabled ? "Wi-Fi 하드웨어 차단" : !Net.Networking.wifiEnabled ? "Wi-Fi 꺼짐"
		: wifiDevice !== null && wifiDevice.state === Net.ConnectionState.Connecting ? "Wi-Fi 연결 중" : "Wi-Fi 연결 안 됨"

	HudStatus {
		id: wiredItem
		compact: root.compact
		iconOnly: compact
		visible: root.backendAvailable && root.wiredDevices.length > 0
			&& (root.wiredConnected || root.wifiDevices.length === 0)
		glyph: root.wiredConnected ? "󰈀" : "󰌙"
		text: root.wiredConnected ? "LAN" : "LAN disconnected"
		color: root.wiredConnected && root.internetLimited ? Theme.warning : root.wiredConnected ? (compact ? Theme.accentBright : Theme.success) : Theme.danger
		anchors.verticalCenter: parent.verticalCenter
	}

	HudStatus {
		id: wifiItem
		compact: root.compact
		iconOnly: compact
		visible: root.backendAvailable && root.wifiDevices.length > 0
		glyph: root.wifiIcon
		text: root.wifiStatus
		maximumTextWidth: Theme.networkTextWidth
		color: root.wifiConnected && root.internetLimited ? Theme.warning
			: root.wifiConnected ? (compact ? Theme.accentBright : Theme.success)
			: (root.wifiDevice !== null && root.wifiEnabled
				&& root.wifiDevice.state === Net.ConnectionState.Connecting ? Theme.warning : Theme.danger)
		anchors.verticalCenter: parent.verticalCenter
	}

	HudStatus {
		compact: root.compact
		iconOnly: compact
		visible: !root.backendAvailable || root.devices.length === 0
		glyph: "󰤮"
		text: root.backendAvailable ? "No network device" : "Network unavailable"
		color: Theme.textMuted
		anchors.verticalCenter: parent.verticalCenter
	}
}
