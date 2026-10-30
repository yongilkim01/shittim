pragma Singleton
import QtQuick
import QtQml.Models
import Quickshell
import Quickshell.Networking as Net
import Quickshell.Io
import "../core"
import "../core/ActionErrors.js" as Errors

Scope {
	id: root
	signal editorOpening()
	Process { id:editor;command:["nm-connection-editor"] }
	function openEditor(){editorOpening();editor.startDetached()}
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
	// Radio switched off by a hardware key or rfkill: software cannot turn it back on.
	readonly property bool wifiBlocked: backendAvailable && !Net.Networking.wifiHardwareEnabled
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
	property int request:0
	property string operation:""
	readonly property bool busy:requests.busy
	RequestLedger {
		id:requests
		onFinished:result=>{
			if(result.id!==root.request)return
			root.request=0
			if(result.status==="timeout"){root.needsPassword=false;root.error=Errors.message(result.code)}
		}
	}
	property bool needsPassword: false
	onPendingNetworkChanged: if (pendingNetwork === null) needsPassword = false
	property string error: ""
	readonly property bool interactive: consumers.active
	ConsumerSet { id:consumers;onActiveChanged:root.syncConsumer() }
	function retain(consumer){consumers.retain(consumer)}
	function release(consumer){consumers.release(consumer)}
	function syncConsumer() { scanning = interactive; if (!interactive) { needsPassword=false;if(!busy)pendingNetwork=null } }
	readonly property var networks: controlDevice === null ? [] : controlDevice.networks.values.slice().sort((a, b) =>
		Number(b.connected) - Number(a.connected) || b.signalStrength - a.signalStrength)
	// NetworkManager's own internet check (Arch: ping.archlinux.org). Being connected is not the same as reaching the internet.
	readonly property string connectivity: !backendAvailable ? "unknown"
		: ["unknown", "none", "portal", "limited", "full"][Net.Networking.connectivity] || "unknown"
	readonly property bool connected: wifiConnected || wiredConnected
	readonly property bool internetLimited: connected && (connectivity === "limited" || connectivity === "portal")
	// Same codes as scripts/network-service.py so the settings page has one wording for both sources.
	function securityCode(network) {
		if (network === null) return "unknown"
		switch (network.security) {
		case Net.WifiSecurityType.Open: return "open"
		case Net.WifiSecurityType.Owe: return "owe"
		case Net.WifiSecurityType.StaticWep: case Net.WifiSecurityType.DynamicWep: return "wep"
		case Net.WifiSecurityType.WpaPsk: return "wpa-psk"
		case Net.WifiSecurityType.Wpa2Psk: return "wpa2-psk"
		case Net.WifiSecurityType.Sae: return "sae"
		case Net.WifiSecurityType.WpaEap: case Net.WifiSecurityType.Wpa2Eap: case Net.WifiSecurityType.Wpa3SuiteB192: case Net.WifiSecurityType.Leap: return "wpa-eap"
		}
		return "unknown"
	}
	function supportsPsk(network) {
		return network !== null && [Net.WifiSecurityType.WpaPsk, Net.WifiSecurityType.Wpa2Psk, Net.WifiSecurityType.Sae].indexOf(network.security) >= 0
	}
	function toggleWifi() {
		if (backendAvailable && Net.Networking.wifiHardwareEnabled) {
			error = ""
			Net.Networking.wifiEnabled = !Net.Networking.wifiEnabled
		}
	}
	function resetPrompt() { needsPassword = false;if(request)requests.settle(request,"cancelled","Cancelled",false);pendingNetwork = null }
	function connectNetwork(network) {
		if (!wifiEnabled || busy || network === null || network.stateChanging) return
		resetPrompt()
		error = ""
		pendingNetwork = network
		operation=network.connected ? "disconnect" : "connect"
		request=requests.begin(operation,35000,controlDevice ? controlDevice.name : "")
		if (network.connected) network.disconnect()
		else network.connect()
	}
	function submitPassword(psk) {
		if (!supportsPsk(pendingNetwork) || !wifiEnabled || busy) return
		needsPassword = false
		error = ""
		operation="connect";request=requests.begin(operation,35000,controlDevice ? controlDevice.name : "")
		pendingNetwork.connectWithPsk(psk)
	}
	function refresh() { scanning = false; Qt.callLater(() => { if (root.interactive) scanning = true }) }
	onControlDeviceChanged: { resetPrompt(); error = "" }
	onWifiEnabledChanged: if (!wifiEnabled) resetPrompt()
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
			if(!root.request)return
			requests.complete(root.request,false,"NetworkConnectionFailed",false)
			if (reason === Net.ConnectionFailReason.NoSecrets && root.supportsPsk(root.pendingNetwork)) {
				root.needsPassword = root.interactive
				root.error = "Wi-Fi 비밀번호가 필요하거나 올바르지 않습니다."
			} else if (reason === Net.ConnectionFailReason.NoSecrets) {
				root.error = "기업용/WEP 인증 설정은 네트워크 편집기에서 구성하세요."
			} else root.error = Net.ConnectionFailReason.toString(reason)
		}
		function onStateChanged() {
			if (root.request && root.pendingNetwork && root.pendingNetwork.connected===(root.operation==="connect")) {
				requests.complete(root.request,true);root.error = ""; root.needsPassword = false
			}
		}
	}
}
