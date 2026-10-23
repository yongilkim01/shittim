pragma Singleton
import QtQuick
import QtQml.Models
import Quickshell
import Quickshell.Networking as Net

Scope {
	id: root
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
	property var selectedDevice: null
	readonly property var controlDevice: wifiDevices.indexOf(selectedDevice) >= 0 ? selectedDevice : wifiDevice
	property bool scanning: false
	property var pendingNetwork: null
	property bool needsPassword: false
	onPendingNetworkChanged: if (pendingNetwork === null) needsPassword = false
	property string error: ""
	readonly property var networks: controlDevice === null ? [] : controlDevice.networks.values.slice().sort((a, b) =>
		Number(b.connected) - Number(a.connected) || b.signalStrength - a.signalStrength)
	function supportsPsk(network) {
		return network !== null && [Net.WifiSecurityType.WpaPsk, Net.WifiSecurityType.Wpa2Psk, Net.WifiSecurityType.Sae].indexOf(network.security) >= 0
	}
	function toggleWifi() {
		if (backendAvailable && Net.Networking.wifiHardwareEnabled) {
			error = ""
			Net.Networking.wifiEnabled = !Net.Networking.wifiEnabled
		}
	}
	function resetPrompt() { needsPassword = false; pendingNetwork = null; connectionTimeout.stop() }
	function connectNetwork(network) {
		if (!wifiEnabled || network === null || network.stateChanging) return
		resetPrompt()
		error = ""
		pendingNetwork = network
		if (network.connected) network.disconnect()
		else { network.connect(); connectionTimeout.restart() }
	}
	function submitPassword(psk) {
		if (!supportsPsk(pendingNetwork) || !wifiEnabled) return
		needsPassword = false
		error = ""
		pendingNetwork.connectWithPsk(psk)
		connectionTimeout.restart()
	}
	function refresh() { scanning = false; Qt.callLater(() => { if (ControlState.opened) scanning = true }) }
	onControlDeviceChanged: { resetPrompt(); error = "" }
	onWifiEnabledChanged: if (!wifiEnabled) resetPrompt()
	Connections {
		target: ControlState
		function onOpenedChanged() {
			root.scanning = ControlState.opened
			if (!ControlState.opened) root.resetPrompt()
		}
	}
	Instantiator {
		model: root.wifiDevices
		delegate: Binding {
			required property var modelData
			target: modelData
			property: "scannerEnabled"
			value: root.scanning && root.wifiEnabled
			restoreMode: Binding.RestoreBindingOrValue
		}
	}
	Connections {
		target: root.pendingNetwork
		function onConnectionFailed(reason) {
			connectionTimeout.stop()
			if (reason === Net.ConnectionFailReason.NoSecrets && root.supportsPsk(root.pendingNetwork)) {
				root.needsPassword = ControlState.opened
				root.error = "Wi-Fi 비밀번호가 필요하거나 올바르지 않습니다."
			} else if (reason === Net.ConnectionFailReason.NoSecrets) {
				root.error = "기업용/WEP 인증 설정은 네트워크 편집기에서 구성하세요."
			} else root.error = Net.ConnectionFailReason.toString(reason)
		}
		function onStateChanged() {
			if (root.pendingNetwork && root.pendingNetwork.connected) {
				connectionTimeout.stop(); root.error = ""; root.needsPassword = false
			}
		}
	}
	Timer {
		id: connectionTimeout
		interval: 35000
		onTriggered: root.error = "네트워크 요청이 완료되지 않았습니다. 연결 상태와 인증 설정을 확인하세요."
	}

}
