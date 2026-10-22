import QtQuick
import Quickshell.Networking as Net
import "../ui"

Row {
	id: root
	spacing: Theme.spaceXS

	readonly property bool backendAvailable: Net.Networking.backend !== Net.NetworkBackendType.None
	readonly property var devices: Net.Networking.devices.values.filter(device =>
		(device.type === Net.DeviceType.Wifi || device.type === Net.DeviceType.Wired)
		&& device.name !== "lo" && !device.name.startsWith("p2p-dev-"))
	readonly property var wifiDevices: devices.filter(device => device.type === Net.DeviceType.Wifi)
	readonly property var wiredDevices: devices.filter(device => device.type === Net.DeviceType.Wired)
	readonly property bool wiredConnected: wiredDevices.some(device => device.connected)
	readonly property var wifiDevice: wifiDevices.find(device => device.connected)
		|| wifiDevices.find(device => device.state === Net.ConnectionState.Connecting)
		|| wifiDevices[0] || null
	readonly property bool wifiEnabled: Net.Networking.wifiEnabled && Net.Networking.wifiHardwareEnabled
	readonly property bool wifiConnected: wifiEnabled && wifiDevice !== null && wifiDevice.connected
	readonly property var wifiNetwork: {
		if (!wifiConnected) return null
		return wifiDevice.networks.values.find(network => network.connected) || null
	}
	// WifiNetwork.name is the SSID; nmSettings contains connection profile names.
	readonly property string ssid: wifiNetwork !== null ? wifiNetwork.name : ""
	readonly property real signalStrength: wifiNetwork !== null && isFinite(wifiNetwork.signalStrength)
		? Math.max(0, Math.min(1, wifiNetwork.signalStrength)) : 0
	readonly property string wifiIcon: {
		if (!wifiEnabled) return "󰤮"
		if (!wifiConnected || wifiNetwork === null) return "󰤯"
		if (signalStrength >= 0.75) return "󰤨"
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

	HudStatus {
		visible: root.backendAvailable && root.wiredDevices.length > 0
			&& (root.wiredConnected || root.wifiDevices.length === 0)
		glyph: root.wiredConnected ? "󰈀" : "󰌙"
		text: root.wiredConnected ? "LAN" : "LAN disconnected"
		color: root.wiredConnected ? Theme.success : Theme.danger
		anchors.verticalCenter: parent.verticalCenter
	}

	HudStatus {
		visible: root.backendAvailable && root.wifiDevices.length > 0
		glyph: root.wifiIcon
		text: root.wifiStatus
		maximumTextWidth: Theme.networkTextWidth
		color: root.wifiConnected ? Theme.success
			: (root.wifiDevice !== null && root.wifiEnabled
				&& root.wifiDevice.state === Net.ConnectionState.Connecting ? Theme.warning : Theme.danger)
		anchors.verticalCenter: parent.verticalCenter
	}

	HudStatus {
		visible: !root.backendAvailable || root.devices.length === 0
		text: root.backendAvailable ? "No network device" : "Network unavailable"
		color: Theme.textMuted
		anchors.verticalCenter: parent.verticalCenter
	}
}
