import QtQuick
import QtQuick.Controls.Basic as Controls
import "../../ui"
import "../../core"
import "../dashboard"
import "../dashboard/Format.js" as Format
import "../../core/NetworkData.js" as NetworkData

// Dashboard "네트워크" page. Wi-Fi on/off, scanning and joining go through NetworkState (the same objects the bar and
// the Control Center use); profiles, IP/DNS, keep-or-restore and diagnostics through NetworkSettingsState; traffic
// comes from the dashboard's single collector. The page reads and calls those contracts only, never a command.
FocusScope {
	id: root
	required property var network
	required property var settings
	// DashboardModel (snapshot.network.interfaces, history); null shows no traffic.
	property var traffic: null
	property string tab: "wifi"
	// wifi: SSID, wired: interface, saved: profile uuid.
	property string selectedKey: ""
	property string search: ""
	// "" | "password" | "hidden" | "editor" | "delete"
	property string dialog: network.needsPassword ? "password" : localDialog
	property string localDialog: ""
	property var editing: null
	property var form: ({})
	property var formErrors: ({})
	property string joining: ""
	property bool revealPassword: false
	implicitWidth: 589; implicitHeight: 272

	ServiceLease { service: root.network; active: root.visible && root.tab === "wifi" }
	ServiceLease { service: root.settings; active: root.visible }
	onVisibleChanged: settings.showing(root, visible)
	Component.onCompleted: { settings.showing(root, visible); selectedKey = defaultKey() }
	Component.onDestruction: settings.showing(root, false)

	// ---- What is selected, from both sources -------------------------------------------------------------------
	readonly property var wifiDevice: network.controlDevice
	readonly property var wifiAdapterDevice: wifiDevice ? settings.device(wifiDevice.name) : null
	readonly property var visibleNetworks: network.wifiEnabled ? network.networks.filter(item => item.name.length > 0
		&& (search.length === 0 || item.name.toLowerCase().indexOf(search.toLowerCase()) >= 0)) : []
	readonly property var wiredDevices: settings.devices.filter(item => item.type === "wired")
	readonly property var savedProfiles: settings.connections
	readonly property var selectedNetwork: tab === "wifi" ? (network.networks.find(item => item.name === selectedKey) || null) : null
	readonly property var selectedDevice: {
		if (tab === "wifi") return wifiAdapterDevice
		if (tab === "wired") return settings.device(selectedKey) || wiredDevices[0] || null
		return settings.devices.find(item => item.connection && item.connection.uuid === selectedKey) || null
	}
	readonly property var selectedProfile: {
		if (tab === "saved") return settings.profile(selectedKey) || savedProfiles[0] || null
		if (tab === "wired") return selectedDevice && selectedDevice.connection ? settings.profile(selectedDevice.connection.uuid) : null
		if (!selectedKey) return null
		if (selectedNetwork && selectedNetwork.connected && wifiAdapterDevice && wifiAdapterDevice.connection) return settings.profile(wifiAdapterDevice.connection.uuid)
		return settings.profileForSsid(selectedKey)
	}
	// Addresses belong to the device only while this selection is what it is connected to.
	readonly property bool selectionActive: selectedDevice !== null && selectedDevice.connection !== null
		&& (tab === "wired" || (tab === "wifi" ? selectedNetwork !== null && selectedNetwork.connected : selectedProfile !== null && selectedDevice.connection.uuid === selectedProfile.uuid))
	readonly property string trafficInterface: selectionActive ? selectedDevice.interface : (traffic && traffic.snapshot ? traffic.snapshot.network.interface : "")
	readonly property var trafficSample: traffic && traffic.snapshot ? (traffic.snapshot.network.interfaces || []).find(item => item.name === trafficInterface) || null : null
	readonly property string message: settings.error || network.error || settings.notice

	onTabChanged: { selectedKey = defaultKey(); search = "" }
	function defaultKey() {
		if (tab === "wifi") return network.wifiConnected ? network.ssid : ""
		if (tab === "wired") return wiredDevices.length ? wiredDevices[0].interface : ""
		return savedProfiles.length ? savedProfiles[0].uuid : ""
	}
	Connections {
		target: root.network
		function onSsidChanged() {
			if (root.tab === "wifi" && root.selectedKey === "") root.selectedKey = root.network.ssid
			if (root.joining && root.network.ssid === root.joining && root.network.wifiConnected) { root.settings.notice = "«" + root.joining + "»에 연결되었습니다."; root.joining = "" }
		}
	}

	function choose(item) {
		selectedKey = item.name
		if (!item.connected && !item.stateChanging && !network.busy) { joining = item.name; network.connectNetwork(item) }
	}
	function openEditor(profile) {
		if (!profile) return
		editing = profile; form = NetworkData.formFor(profile); formErrors = ({}); localDialog = "editor"
	}
	function setField(key, value) { const next = Object.assign({}, form); next[key] = value; form = next; formErrors = ({}) }
	function applyEditor() {
		const result = NetworkData.validate(form)
		formErrors = result.errors
		if (!result.ok || !editing) return
		settings.apply(editing.uuid, result.request)
		localDialog = ""
	}
	function closeDialog() { if (dialog === "password") network.resetPrompt(); localDialog = ""; revealPassword = false }
	function colorFor(key) { return key === "success" ? Theme.success : key === "warning" ? Theme.warning : key === "danger" ? Theme.danger : Theme.textMuted }

	// ---- Building blocks -----------------------------------------------------------------------------------------
	component InfoRow: Item {
		property string label: ""
		property string value: ""
		property color valueColor: Theme.textPrimary
		width: parent ? parent.width : 0; height: 19
		HudText { width: 78; height: parent.height; verticalAlignment: Text.AlignVCenter; text: parent.label; font.pixelSize: 10; color: Theme.textSecondary }
		HudText { x: 82; width: parent.width - 82; height: parent.height; verticalAlignment: Text.AlignVCenter; text: parent.value || "—"; font.pixelSize: 10; color: parent.valueColor; elide: Text.ElideRight }
		Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.frameLine }
	}
	component Tab: HudFrame {
		id: tabItem
		property string key: ""
		property string glyph: ""
		property string label: ""
		objectName: "networkTab-" + key
		width: 96; height: 26; level: "control"
		cutTopLeft: 0; cutBottomRight: 0; cutTopRight: 6; cutBottomLeft: 6
		active: root.tab === key
		hovered: tabMouse.containsMouse || activeFocus
		fillColor: active ? Theme.selectedFill : hovered ? Theme.hoverFill : Theme.transparent
		strokeColor: active ? Theme.accent : hovered ? Theme.accentDim : Theme.border
		activeFocusOnTab: true
		Keys.onReturnPressed: root.tab = key
		Keys.onSpacePressed: root.tab = key
		Row {
			anchors.centerIn: parent; spacing: 6
			HudIcon { text: tabItem.glyph; font.pixelSize: 12; color: tabItem.active ? Theme.accent : Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
			HudText { text: tabItem.label; font.pixelSize: 11; font.bold: tabItem.active; color: tabItem.active ? Theme.textPrimary : Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
		}
		MouseArea { id: tabMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.tab = tabItem.key }
		Accessible.role: Accessible.PageTab; Accessible.name: label
	}
	component ListRow: Item {
		id: row
		property string glyph: ""
		property string title: ""
		property string detail: ""
		property color detailColor: Theme.textMuted
		property string trailing: ""
		property bool selected: false
		property bool locked: false
		signal clicked()
		signal details()
		width: parent ? parent.width : 0; height: 34
		activeFocusOnTab: true
		Keys.onReturnPressed: row.clicked()
		Keys.onSpacePressed: row.clicked()
		Keys.onRightPressed: row.details()
		HudFrame {
			anchors.fill: parent; level: "control"; cutTopLeft: 0; cutBottomRight: 0; cutTopRight: 0; cutBottomLeft: 0
			active: row.selected; hovered: rowMouse.containsMouse || row.activeFocus
			fillColor: row.selected ? Theme.selectedFill : hovered ? Theme.hoverFill : Theme.transparent
			strokeColor: row.selected ? Theme.accent : hovered ? Theme.accentDim : Theme.transparent
			Rectangle { visible: row.selected; width: Theme.sectionBarWidth; height: parent.height; color: Theme.accent }
		}
		HudIcon { x: 10; width: 18; height: parent.height; verticalAlignment: Text.AlignVCenter; text: row.glyph; font.pixelSize: 14; color: row.selected ? Theme.accent : Theme.textSecondary }
		Column {
			x: 34; width: parent.width - 34 - 82; anchors.verticalCenter: parent.verticalCenter
			HudText { width: parent.width; text: row.title; font.pixelSize: 11; color: Theme.textPrimary; elide: Text.ElideRight }
			HudText { visible: row.detail.length > 0; width: parent.width; text: row.detail; font.pixelSize: 9; color: row.detailColor; elide: Text.ElideRight }
		}
		HudIcon { x: parent.width - 80; width: 14; height: parent.height; verticalAlignment: Text.AlignVCenter; visible: row.locked; text: ""; font.pixelSize: 10; color: Theme.textSecondary }
		HudText { x: parent.width - 62; width: 34; height: parent.height; verticalAlignment: Text.AlignVCenter; horizontalAlignment: Text.AlignRight; text: row.trailing; font.pixelSize: 10; color: Theme.accentBright }
		MouseArea { id: rowMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: row.clicked() }
		HudButton { x: parent.width - 26; y: 5; width: 24; height: 24; compact: true; text: ""; onClicked: row.details(); Accessible.name: row.title + " 정보" }
	}
	component FieldLabel: HudText { width: 74; height: 26; verticalAlignment: Text.AlignVCenter; font.pixelSize: 10; color: Theme.textSecondary }
	component ErrorText: HudText { property string key: ""; visible: text.length > 0; text: root.formErrors[key] || ""; font.pixelSize: 9; color: Theme.danger; width: parent ? parent.width : 0; wrapMode: Text.WordWrap }
	component Choice: HudButton {
		property string field: ""
		property string value: ""
		height: 24; compact: true; active: root.form[field] === value; onClicked: root.setField(field, value)
	}

	// ---- Header: title and tabs ----------------------------------------------------------------------------------
	HudText { x: 0; y: 0; height: 24; text: "네트워크"; font.pixelSize: 18; font.bold: true; color: Theme.textPrimary }
	HudText {
		objectName: "networkConnectivity"; x: 200; y: 0; width: parent.width - 200; height: 24; horizontalAlignment: Text.AlignRight; verticalAlignment: Text.AlignVCenter
		text: "  " + NetworkData.connectivityText(root.network.connectivity); font.pixelSize: 10
		color: root.colorFor(NetworkData.connectivityColorKey(root.network.connectivity))
	}
	Rectangle { x: 0; y: 29; width: 384; height: 1; color: Theme.border }
	Rectangle { x: 0; y: 28; width: 64; height: 2; color: Theme.accent }
	Row {
		x: 0; y: 36; spacing: Theme.spaceS
		Tab { key: "wifi"; glyph: "󰤨"; label: "Wi-Fi" }
		Tab { key: "wired"; glyph: "󰈀"; label: "유선" }
		Tab { key: "saved"; glyph: ""; label: "저장된 연결" }
	}

	// ---- Left: devices and lists ---------------------------------------------------------------------------------
	Flickable {
		id: listView; objectName: "networkListView"
		x: 0; y: 68; width: 300; height: root.message ? 182 : 204
		contentWidth: width; contentHeight: listContent.height; clip: true; boundsBehavior: Flickable.StopAtBounds
		interactive: root.dialog === ""
		Controls.ScrollBar.vertical: Controls.ScrollBar { policy: Controls.ScrollBar.AsNeeded; width: 3; contentItem: Rectangle { implicitWidth: 3; color: Theme.accentDim } background: Item {} }
		Column {
			id: listContent; width: listView.width - 6; spacing: Theme.spaceS

			// Wi-Fi status card
			HudFrame {
				objectName: "networkWifiCard"; visible: root.tab === "wifi"; width: parent.width; height: root.network.wifiConnected ? 92 : 50; level: "panel"; glow: root.network.wifiConnected
				HudIcon { x: 12; y: 9; text: root.network.wifiEnabled ? "󰤨" : "󰤮"; font.pixelSize: 20; color: root.network.wifiEnabled ? Theme.accent : Theme.textMuted }
				HudText { x: 44; y: 6; text: "Wi-Fi"; font.pixelSize: 13; font.bold: true; color: Theme.textPrimary }
				HudText {
					objectName: "networkWifiState"; x: 44; y: 24; width: parent.width - 44 - 70; font.pixelSize: 9; elide: Text.ElideRight
					color: root.network.wifiBlocked ? Theme.warning : Theme.textSecondary
					text: !root.network.backendAvailable ? "NetworkManager를 사용할 수 없습니다."
						: root.network.wifiDevices.length === 0 ? "Wi-Fi 장치가 없습니다. 유선 탭을 사용하세요."
						: root.network.wifiBlocked ? "하드웨어 스위치(비행기 모드)로 꺼져 있습니다."
						: !root.network.wifiEnabled ? "꺼져 있습니다."
						: root.wifiDevice && root.wifiDevice.state === 1 ? "연결하는 중…"
						: root.network.wifiConnected ? "무선 네트워크에 연결되어 있습니다." : "연결할 네트워크를 선택하세요."
				}
				HudText { x: parent.width - 72; y: 14; text: root.network.wifiEnabled ? "켬" : "끔"; font.pixelSize: 10; color: Theme.textSecondary }
				HudToggle {
					objectName: "networkWifiToggle"; x: parent.width - 54; y: 10; label: "Wi-Fi"; checked: root.network.wifiEnabled
					enabled: root.network.backendAvailable && root.network.wifiDevices.length > 0 && !root.network.wifiBlocked
					onToggled: root.network.toggleWifi()
				}
				Rectangle { visible: root.network.wifiConnected; x: 12; y: 44; width: parent.width - 24; height: 1; color: Theme.frameLine }
				Item {
					visible: root.network.wifiConnected; x: 12; y: 50; width: parent.width - 24; height: 38
					HudText { id: currentName; x: 0; y: 0; width: Math.min(implicitWidth, parent.width - 60); text: root.network.ssid; font.pixelSize: 12; font.bold: true; color: Theme.textPrimary; elide: Text.ElideRight }
					HudFrame {
						x: currentName.width + 8; y: 1; width: 44; height: 16; level: "control"; active: true; fillColor: Theme.selectedFill
						HudText { anchors.centerIn: parent; text: "연결됨"; font.pixelSize: 9; color: Theme.accent }
					}
					Row {
						y: 20; spacing: 12
						HudText { text: NetworkData.signalGlyph(root.network.signalStrength * 100) + " " + NetworkData.signalLabel(root.network.signalStrength * 100) + " (" + Math.round(root.network.signalStrength * 100) + "%)"; font.pixelSize: 9; color: Theme.textSecondary }
						HudText { text: " " + NetworkData.securityLabel(root.network.securityCode(root.network.wifiNetwork)); font.pixelSize: 9; color: Theme.textSecondary }
						HudText { text: NetworkData.connectivityText(root.network.connectivity); font.pixelSize: 9; color: root.colorFor(NetworkData.connectivityColorKey(root.network.connectivity)) }
					}
				}
			}

			// Nearby networks
			Item {
				visible: root.tab === "wifi" && root.network.wifiEnabled; width: parent.width; height: 26
				HudText { y: 0; height: 26; verticalAlignment: Text.AlignVCenter; text: "주변 네트워크"; font.pixelSize: 11; font.bold: true; color: Theme.textPrimary }
				HudButton { objectName: "networkRefresh"; x: 80; y: 1; width: 78; height: 24; compact: true; text: " 새로 고침"; enabled: root.network.wifiEnabled; onClicked: root.network.refresh() }
				HudInput {
					objectName: "networkSearch"; x: 164; y: 1; width: parent.width - 164; implicitHeight: 24; font.pixelSize: 10
					placeholderText: " 네트워크 검색"; text: root.search; onTextChanged: root.search = text
					Accessible.name: "네트워크 검색"
				}
			}
			HudText {
				visible: root.tab === "wifi" && root.network.wifiEnabled && root.visibleNetworks.length === 0; width: parent.width; wrapMode: Text.WordWrap
				text: root.search ? "«" + root.search + "»와 일치하는 네트워크가 없습니다." : root.network.scanning ? "주변 네트워크를 검색하는 중입니다…" : "검색된 네트워크가 없습니다. 새로 고침을 누르세요."
				font.pixelSize: 10; color: Theme.textMuted
			}
			Repeater {
				model: root.tab === "wifi" ? root.visibleNetworks : []
				ListRow {
					required property var modelData
					required property int index
					objectName: "networkRow-" + index
					readonly property var points: NetworkData.accessPoints(root.wifiAdapterDevice, modelData.name)
					glyph: NetworkData.signalGlyph(modelData.signalStrength * 100)
					title: modelData.name
					detail: (modelData.connected ? "연결됨" : modelData.stateChanging ? "연결 중…" : modelData.known ? "저장됨" : "")
						+ (points.bands.length ? (modelData.connected || modelData.known || modelData.stateChanging ? " · " : "") + points.bands.join(" · ") : "")
						+ (points.count > 1 ? " · AP " + points.count + "개" : "")
					detailColor: modelData.connected ? Theme.accent : Theme.textMuted
					locked: root.network.securityCode(modelData) !== "open"
					trailing: Math.round(modelData.signalStrength * 100) + "%"
					selected: root.selectedKey === modelData.name
					onClicked: root.choose(modelData)
					onDetails: root.selectedKey = modelData.name
				}
			}
			Row {
				visible: root.tab === "wifi" && root.network.wifiEnabled; spacing: Theme.spaceS
				HudButton { objectName: "networkHidden"; width: 140; height: 24; compact: true; text: "숨겨진 네트워크 연결"; enabled: root.wifiDevice !== null && root.settings.available; onClicked: { root.form = ({hiddenSsid: "", hiddenSecurity: "wpa-psk", hiddenPassword: ""}); root.localDialog = "hidden" } }
				HudButton { width: 148; height: 24; compact: true; text: "기업용(802.1X) 설정 편집기"; onClicked: root.network.openEditor() }
			}

			// Wired devices
			HudText {
				visible: root.tab === "wired" && root.wiredDevices.length === 0; width: parent.width; wrapMode: Text.WordWrap; font.pixelSize: 11; color: Theme.textMuted
				text: !root.settings.available ? "네트워크 설정 서비스에 연결하는 중입니다…" : "유선 네트워크 장치가 없습니다. 이더넷 어댑터를 연결하면 자동으로 표시됩니다."
			}
			Repeater {
				model: root.tab === "wired" ? root.wiredDevices : []
				ListRow {
					required property var modelData
					required property int index
					objectName: "networkWired-" + index
					glyph: modelData.state === 100 ? "󰈀" : "󰌙"
					title: modelData.interface + (modelData.connection ? " · " + modelData.connection.name : "")
					detail: NetworkData.deviceStateText(modelData) + (modelData.carrier ? " · " + NetworkData.speedText(modelData.speed) : modelData.state === 20 ? "" : " · 케이블 없음")
					detailColor: modelData.state === 100 ? Theme.accent : Theme.textMuted
					selected: root.selectedDevice === modelData
					onClicked: root.selectedKey = modelData.interface
					onDetails: root.selectedKey = modelData.interface
				}
			}

			// Saved profiles
			HudText {
				visible: root.tab === "saved" && root.savedProfiles.length === 0; width: parent.width; wrapMode: Text.WordWrap; font.pixelSize: 11; color: Theme.textMuted
				text: !root.settings.available ? "네트워크 설정 서비스에 연결하는 중입니다…" : "저장된 Wi-Fi·유선 연결이 없습니다."
			}
			Repeater {
				model: root.tab === "saved" ? root.savedProfiles : []
				ListRow {
					required property var modelData
					required property int index
					objectName: "networkProfile-" + index
					readonly property bool inUse: root.settings.devices.some(item => item.connection && item.connection.uuid === modelData.uuid)
					glyph: modelData.type === "wifi" ? "󰤨" : "󰈀"
					title: modelData.name
					detail: (inUse ? "사용 중 · " : "") + (modelData.autoconnect ? "자동 연결 · 우선순위 " + modelData.priority : "수동 연결")
					detailColor: inUse ? Theme.accent : Theme.textMuted
					locked: modelData.type === "wifi" && modelData.keyMgmt !== "none"
					selected: root.selectedProfile === modelData
					onClicked: root.selectedKey = modelData.uuid
					onDetails: root.selectedKey = modelData.uuid
				}
			}
		}
	}

	// ---- Right: details, traffic, status -------------------------------------------------------------------------
	Flickable {
		id: detailView; objectName: "networkDetailView"
		x: 308; y: 36; width: parent.width - 308; height: root.message ? 214 : 236
		contentWidth: width; contentHeight: detailContent.height; clip: true; boundsBehavior: Flickable.StopAtBounds
		interactive: root.dialog === ""
		Controls.ScrollBar.vertical: Controls.ScrollBar { policy: Controls.ScrollBar.AsNeeded; width: 3; contentItem: Rectangle { implicitWidth: 3; color: Theme.accentDim } background: Item {} }
		Column {
			id: detailContent; width: detailView.width - 6; spacing: Theme.spaceS

			HudFrame {
				objectName: "networkDetails"; width: parent.width; height: detailColumn.height + 36; level: "panel"
				HudSectionHeader {
					x: 12; y: 6; width: parent.width - 24; height: 20; glyph: ""; title: "선택한 네트워크 정보"
					detail: root.selectionActive ? NetworkData.deviceStateText(root.selectedDevice) : ""
				}
				Column {
					id: detailColumn; x: 12; y: 30; width: parent.width - 24
					HudText {
						visible: root.selectedProfile === null && root.selectedNetwork === null && root.selectedDevice === null; width: parent.width; height: 40; wrapMode: Text.WordWrap
						text: "왼쪽 목록에서 네트워크를 선택하면 정보가 표시됩니다."; font.pixelSize: 10; color: Theme.textMuted
					}
					InfoRow { visible: root.tab === "wifi" && root.selectedKey !== ""; label: "SSID"; value: root.selectedKey }
					InfoRow { visible: root.selectedProfile !== null; label: "연결 이름"; value: root.selectedProfile ? root.selectedProfile.name : "" }
					InfoRow {
						visible: root.selectedNetwork !== null; label: "보안"
						value: root.selectedNetwork ? NetworkData.securityLabel(root.network.securityCode(root.selectedNetwork)) : ""
					}
					InfoRow {
						visible: root.selectedNetwork !== null; label: "신호 · 대역"
						readonly property var points: NetworkData.accessPoints(root.wifiAdapterDevice, root.selectedKey)
						value: root.selectedNetwork ? NetworkData.signalLabel(root.selectedNetwork.signalStrength * 100) + " (" + Math.round(root.selectedNetwork.signalStrength * 100) + "%)"
							+ (points.bands.length ? " · " + points.bands.join(", ") : "") + (points.strongest ? " · " + points.strongest.frequency + " MHz" : "") : ""
					}
					InfoRow { visible: root.selectionActive; label: "IPv4 주소"; value: root.selectionActive ? NetworkData.addressText(root.selectedDevice.ip4.addresses) : "" }
					InfoRow { visible: root.selectionActive; label: "게이트웨이"; value: root.selectionActive ? root.selectedDevice.ip4.gateway || root.selectedDevice.ip6.gateway : "" }
					InfoRow { visible: root.selectionActive; label: "DNS 서버"; value: root.selectionActive ? root.selectedDevice.ip4.dns.concat(root.selectedDevice.ip6.dns).join(", ") : "" }
					InfoRow { visible: root.selectionActive; label: "IPv6 주소"; value: root.selectionActive ? NetworkData.addressText(root.selectedDevice.ip6.addresses) : "" }
					InfoRow { visible: root.selectedDevice !== null; label: "인터페이스"; value: root.selectedDevice ? root.selectedDevice.interface + (root.selectedDevice.driver ? " (" + root.selectedDevice.driver + ")" : "") : "" }
					InfoRow { visible: root.selectedDevice !== null; label: "MAC 주소"; value: root.selectedDevice ? root.selectedDevice.hwAddress : "" }
					InfoRow { visible: root.selectedDevice !== null && root.selectedDevice.type === "wired"; label: "링크"; value: root.selectedDevice ? (root.selectedDevice.carrier ? "연결됨 · " + NetworkData.speedText(root.selectedDevice.speed) : "케이블 연결 안 됨") : "" }
					InfoRow {
						visible: root.selectedProfile !== null; label: "IP 설정"
						value: root.selectedProfile ? "IPv4 " + NetworkData.methodLabel(root.selectedProfile.ipv4.method, 4) + " · IPv6 " + NetworkData.methodLabel(root.selectedProfile.ipv6.method, 6)
							+ (root.selectedProfile.ipv4.autoDns ? "" : " · DNS 지정") : ""
					}
					InfoRow { visible: root.selectedProfile !== null; label: "프록시"; value: root.selectedProfile ? (root.selectedProfile.proxy.method === "auto" ? "자동(PAC)" : "사용 안 함") : "" }
					HudText {
						visible: root.tab === "wifi" && root.selectedNetwork !== null && root.selectedProfile === null; width: parent.width; wrapMode: Text.WordWrap; topPadding: 4
						text: "저장되지 않은 네트워크입니다. 연결하면 설정이 저장되고 IP·DNS를 바꿀 수 있습니다."; font.pixelSize: 9; color: Theme.textMuted
					}
					Item {
						visible: root.selectedProfile !== null; width: parent.width; height: 28
						HudText { width: 78; height: parent.height; verticalAlignment: Text.AlignVCenter; text: "자동 연결"; font.pixelSize: 10; color: Theme.textSecondary }
						HudToggle {
							objectName: "networkAutoconnect"; x: 82; y: 4; label: "자동 연결"
							checked: root.selectedProfile ? root.selectedProfile.autoconnect : false
							enabled: !root.settings.isPending("autoconnect", root.selectedProfile ? root.selectedProfile.uuid : "")
							onToggled: on => root.settings.setAutoconnect(root.selectedProfile.uuid, on)
						}
						HudText { x: 140; width: 50; height: parent.height; verticalAlignment: Text.AlignVCenter; text: "우선순위"; font.pixelSize: 10; color: Theme.textSecondary }
						HudButton { objectName: "networkPriorityDown"; x: parent.width - 86; y: 3; width: 22; height: 22; compact: true; text: "−"; enabled: root.selectedProfile !== null && root.selectedProfile.priority > -999; onClicked: root.settings.setAutoconnect(root.selectedProfile.uuid, root.selectedProfile.autoconnect, root.selectedProfile.priority - 1) }
						HudText { objectName: "networkPriority"; x: parent.width - 62; width: 38; height: parent.height; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; text: root.selectedProfile ? String(root.selectedProfile.priority) : ""; font.pixelSize: 10; color: Theme.accentBright }
						HudButton { objectName: "networkPriorityUp"; x: parent.width - 22; y: 3; width: 22; height: 22; compact: true; text: "+"; enabled: root.selectedProfile !== null && root.selectedProfile.priority < 999; onClicked: root.settings.setAutoconnect(root.selectedProfile.uuid, root.selectedProfile.autoconnect, root.selectedProfile.priority + 1) }
					}
					Flow {
						width: parent.width; spacing: Theme.spaceS; topPadding: 4
						HudButton {
							objectName: "networkConnect"; height: 24; compact: true; width: 72
							visible: root.selectedProfile !== null || root.selectedNetwork !== null || (root.tab === "wired" && root.selectedDevice !== null)
							readonly property bool connected: root.tab === "wifi" ? root.selectedNetwork !== null && root.selectedNetwork.connected : root.selectionActive
							text: connected ? "연결 해제" : "연결"
							enabled: !root.settings.busy && !root.network.busy
							onClicked: {
								if (root.tab === "wifi" && root.selectedNetwork) { if (!connected) root.joining = root.selectedNetwork.name; root.network.connectNetwork(root.selectedNetwork) }
								else if (connected) root.settings.disconnectDevice(root.selectedDevice.interface)
								else if (root.selectedProfile) root.settings.activate(root.selectedProfile.uuid, root.selectedProfile.type === "wired" && root.selectedDevice ? root.selectedDevice.interface : "")
								else if (root.selectedDevice) root.settings.activate(wiredProfileFor(root.selectedDevice), root.selectedDevice.interface)
							}
							function wiredProfileFor(device) { const match = root.savedProfiles.find(item => item.type === "wired" && (!item.interface || item.interface === device.interface)); return match ? match.uuid : "" }
						}
						HudButton {
							objectName: "networkEditIp"; height: 24; compact: true; width: 92; visible: root.selectedProfile !== null; text: "IP·DNS 설정"
							enabled: !root.settings.waiting; onClicked: root.openEditor(root.selectedProfile)
						}
						HudButton {
							objectName: "networkDelete"; height: 24; compact: true; width: 92; visible: root.selectedProfile !== null; text: " 이 연결 삭제"
							onClicked: { root.editing = root.selectedProfile; root.localDialog = "delete" }
						}
					}
				}
			}

			// Traffic from the dashboard collector (/proc/net/dev), for the interface of the selection.
			HudFrame {
				objectName: "networkTraffic"; width: parent.width; height: 112; level: "card"
				HudSectionHeader { x: 12; y: 6; width: parent.width - 24; height: 20; glyph: ""; title: "실시간 트래픽"; detail: root.trafficInterface || "N/A" }
				NetworkGraph {
					objectName: "networkTrafficGraph"; x: 12; y: 30; width: parent.width - 24; height: 46
					samples: root.traffic && root.trafficInterface ? root.traffic.history[root.trafficInterface] || [] : []
				}
				Row {
					x: 12; y: 82; spacing: 18
					Column {
						HudText { text: " 다운로드"; font.pixelSize: 9; color: Theme.textSecondary }
						HudText { objectName: "networkDown"; text: Format.rate(root.trafficSample ? root.trafficSample.down : null); font.pixelSize: 12; font.bold: true; color: Theme.accentBright }
					}
					Column {
						HudText { text: " 업로드"; font.pixelSize: 9; color: Theme.textSecondary }
						HudText { objectName: "networkUp"; text: Format.rate(root.trafficSample ? root.trafficSample.up : null); font.pixelSize: 12; font.bold: true; color: Theme.textPrimary }
					}
				}
			}

			// Status and on-demand diagnosis.
			HudFrame {
				objectName: "networkStatus"; width: parent.width; height: statusColumn.height + 40; level: "card"
				readonly property var report: root.settings.diagnosis
				HudSectionHeader { x: 12; y: 6; width: parent.width - 24; height: 20; glyph: ""; title: "네트워크 상태"; detail: NetworkData.connectivityText(root.network.connectivity) }
				Column {
					id: statusColumn; x: 12; y: 32; width: parent.width - 24; spacing: 2
					readonly property var report: parent.report
					InfoRow { label: "연결 품질"; value: statusColumn.report && !statusColumn.report.running ? NetworkData.qualityText(statusColumn.report.quality) : "진단 전"; valueColor: Theme.accentBright }
					InfoRow { label: "게이트웨이"; value: NetworkData.diagnosisStep(statusColumn.report, "gateway").text }
					InfoRow { label: "DNS 조회"; value: NetworkData.diagnosisStep(statusColumn.report, "dns").text }
					InfoRow { label: "인터넷"; value: NetworkData.diagnosisStep(statusColumn.report, "internet").text }
					Item {
						width: parent.width; height: 30
						HudText {
							width: parent.width - 84; height: parent.height; verticalAlignment: Text.AlignVCenter; wrapMode: Text.WordWrap; maximumLineCount: 2; font.pixelSize: 8; color: Theme.textMuted
							text: "누를 때만 실행 · 대상: 게이트웨이, DNS 서버, " + (root.settings.state.checkTarget || "ping.archlinux.org")
						}
						HudButton {
							objectName: "networkDiagnose"; x: parent.width - 78; y: 3; width: 78; height: 24; compact: true
							text: statusColumn.report && statusColumn.report.running ? "진단 중…" : " 진단 실행"
							// Only a finished connection has the gateway and DNS servers the steps test.
							enabled: root.selectedDevice !== null && root.selectionActive && root.selectedDevice.state === 100 && !(statusColumn.report && statusColumn.report.running)
							onClicked: root.settings.diagnose(root.selectedDevice.interface)
						}
					}
				}
			}
		}
	}

	HudText {
		objectName: "networkMessage"; visible: root.message.length > 0
		x: 0; y: 252; width: parent.width; height: 20; elide: Text.ElideRight; font.pixelSize: 11
		text: (root.settings.error || root.network.error ? "󰀦  " : "  ") + root.message
		color: root.settings.error || root.network.error ? Theme.warning : Theme.success
	}

	// ---- Overlays ------------------------------------------------------------------------------------------------
	Rectangle {
		anchors.fill: parent; visible: root.dialog !== "" || root.settings.waiting; color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.72)
		MouseArea { anchors.fill: parent; hoverEnabled: true; onWheel: wheel => wheel.accepted = true }
	}

	// Password for a protected network (NetworkManager asked for secrets).
	FocusScope {
		id: passwordDialog; objectName: "networkPasswordDialog"
		visible: root.dialog === "password" && !root.settings.waiting
		anchors.centerIn: parent; width: 340; height: 150
		onVisibleChanged: if (visible) { password.clear(); root.revealPassword = false; password.forceActiveFocus() }
		Keys.onEscapePressed: root.closeDialog()
		HudFrame { anchors.fill: parent; level: "panel"; glow: true; fillColor: Theme.floatingSurface; gradientColor: Theme.background }
		HudText { x: 14; y: 10; width: parent.width - 28; text: "  " + (root.network.pendingNetwork ? root.network.pendingNetwork.name : "") + " 연결"; font.pixelSize: 13; font.bold: true; color: Theme.textPrimary; elide: Text.ElideRight }
		HudText { x: 14; y: 32; width: parent.width - 28; text: NetworkData.securityLabel(root.network.securityCode(root.network.pendingNetwork)) + " · 비밀번호를 입력하세요."; font.pixelSize: 10; color: Theme.textSecondary }
		HudInput {
			id: password; objectName: "networkPassword"; x: 14; y: 52; width: parent.width - 28 - 36; implicitHeight: 30
			echoMode: root.revealPassword ? TextInput.Normal : TextInput.Password; maximumLength: 64; placeholderText: "Wi-Fi 비밀번호"
			Accessible.name: "Wi-Fi 비밀번호"
			onAccepted: if (text.length >= 8) { root.joining = root.network.pendingNetwork ? root.network.pendingNetwork.name : ""; root.network.submitPassword(text); clear() }
			Component.onDestruction: clear()
		}
		HudButton { objectName: "networkReveal"; x: parent.width - 46; y: 52; width: 32; height: 30; text: root.revealPassword ? "" : ""; active: root.revealPassword; onClicked: root.revealPassword = !root.revealPassword; Accessible.name: root.revealPassword ? "비밀번호 숨기기" : "비밀번호 표시" }
		HudText {
			x: 14; y: 86; width: parent.width - 28; font.pixelSize: 9; elide: Text.ElideRight
			text: root.network.busy ? "연결하는 중…" : root.network.error || (password.text.length > 0 && password.text.length < 8 ? "WPA 비밀번호는 8자 이상입니다." : "")
			color: root.network.busy ? Theme.accentBright : Theme.warning
		}
		Row {
			anchors.right: parent.right; anchors.rightMargin: 14; anchors.bottom: parent.bottom; anchors.bottomMargin: 10; spacing: Theme.spaceS
			HudButton { width: 70; text: "취소"; onClicked: { password.clear(); root.closeDialog() } }
			HudButton {
				objectName: "networkPasswordConnect"; width: 70; text: "연결"; active: true; enabled: password.text.length >= 8 && !root.network.busy
				onClicked: { root.joining = root.network.pendingNetwork ? root.network.pendingNetwork.name : ""; root.network.submitPassword(password.text); password.clear() }
			}
		}
	}

	// Hidden network: SSID, security, password.
	FocusScope {
		objectName: "networkHiddenDialog"; visible: root.dialog === "hidden" && !root.settings.waiting
		anchors.centerIn: parent; width: 360; height: 182
		onVisibleChanged: if (visible) { hiddenSsid.text = ""; hiddenPassword.text = ""; hiddenSsid.forceActiveFocus() }
		Keys.onEscapePressed: root.closeDialog()
		HudFrame { anchors.fill: parent; level: "panel"; glow: true; fillColor: Theme.floatingSurface; gradientColor: Theme.background }
		HudText { x: 14; y: 10; text: "숨겨진 네트워크에 연결"; font.pixelSize: 13; font.bold: true; color: Theme.textPrimary }
		Column {
			x: 14; y: 34; width: parent.width - 28; spacing: 4
			Row { spacing: 6; FieldLabel { text: "네트워크 이름" } HudInput { id: hiddenSsid; objectName: "networkHiddenSsid"; width: 258; implicitHeight: 26; maximumLength: 32; placeholderText: "SSID"; Accessible.name: "숨겨진 네트워크 이름" } }
			Row {
				spacing: 6; FieldLabel { text: "보안" }
				Choice { field: "hiddenSecurity"; value: "none"; width: 60; text: "없음" }
				Choice { field: "hiddenSecurity"; value: "wpa-psk"; width: 96; text: "WPA/WPA2" }
				Choice { field: "hiddenSecurity"; value: "sae"; width: 96; text: "WPA3" }
			}
			Row {
				spacing: 6; visible: root.form.hiddenSecurity !== "none"; FieldLabel { text: "비밀번호" }
				HudInput { id: hiddenPassword; objectName: "networkHiddenPassword"; width: 222; implicitHeight: 26; maximumLength: 64; echoMode: root.revealPassword ? TextInput.Normal : TextInput.Password; Accessible.name: "숨겨진 네트워크 비밀번호"; Component.onDestruction: clear() }
				HudButton { width: 30; height: 26; text: root.revealPassword ? "" : ""; onClicked: root.revealPassword = !root.revealPassword; Accessible.name: "비밀번호 표시" }
			}
		}
		Row {
			anchors.right: parent.right; anchors.rightMargin: 14; anchors.bottom: parent.bottom; anchors.bottomMargin: 10; spacing: Theme.spaceS
			HudButton { width: 70; text: "취소"; onClicked: { hiddenPassword.clear(); root.closeDialog() } }
			HudButton {
				objectName: "networkHiddenConnect"; width: 70; text: "연결"; active: true
				enabled: hiddenSsid.text.length > 0 && (root.form.hiddenSecurity === "none" || hiddenPassword.text.length >= 8) && root.wifiDevice !== null
				onClicked: {
					root.joining = hiddenSsid.text
					root.settings.connectHidden(root.wifiDevice.name, hiddenSsid.text, root.form.hiddenSecurity, hiddenPassword.text)
					hiddenPassword.clear(); root.closeDialog()
				}
			}
		}
	}

	// IP / DNS / proxy editor.
	FocusScope {
		id: editorDialog; objectName: "networkEditor"; visible: root.dialog === "editor" && !root.settings.waiting
		anchors.fill: parent
		Keys.onEscapePressed: root.closeDialog()
		onVisibleChanged: if (visible) Qt.callLater(() => editorDialog.forceActiveFocus())
		HudFrame { anchors.fill: parent; level: "panel"; fillColor: Theme.floatingSurface; gradientColor: Theme.background }
		HudText { x: 14; y: 8; width: parent.width - 28; text: "IP·DNS 설정 · " + (root.editing ? root.editing.name : ""); font.pixelSize: 13; font.bold: true; color: Theme.textPrimary; elide: Text.ElideRight }
		Flickable {
			id: editorView; x: 14; y: 32; width: parent.width - 28; height: parent.height - 32 - 64
			contentWidth: width; contentHeight: editorColumn.height; clip: true; boundsBehavior: Flickable.StopAtBounds
			Controls.ScrollBar.vertical: Controls.ScrollBar { policy: Controls.ScrollBar.AsNeeded; width: 3; contentItem: Rectangle { implicitWidth: 3; color: Theme.accentDim } background: Item {} }
			Column {
				id: editorColumn; width: editorView.width - 8; spacing: 4
				Repeater {
					model: [4, 6]
					Column {
						id: family
						required property int modelData
						readonly property string key: "ipv" + modelData
						width: editorColumn.width; spacing: 4
						HudSectionHeader { width: parent.width; height: 20; glyph: ""; title: "IPv" + family.modelData }
						Row {
							spacing: 6; FieldLabel { text: "방식" }
							Choice { objectName: "networkMethod" + family.modelData + "-auto"; field: family.key + "Method"; value: "auto"; width: 96; text: NetworkData.methodLabel("auto", family.modelData) }
							Choice { objectName: "networkMethod" + family.modelData + "-manual"; field: family.key + "Method"; value: "manual"; width: 60; text: "수동" }
							Choice { field: family.key + "Method"; value: family.modelData === 4 ? "disabled" : "ignore"; width: 74; text: "사용 안 함" }
						}
						Row {
							visible: root.form[family.key + "Method"] === "manual"; spacing: 6
							FieldLabel { text: "주소/프리픽스"; width: 84 }
							HudInput { objectName: "networkAddress" + family.modelData; width: 180; implicitHeight: 26; text: root.form[family.key + "Address"] || ""; onTextEdited: root.setField(family.key + "Address", text); placeholderText: family.modelData === 4 ? "192.168.0.10" : "fd00::10"; Accessible.name: "IPv" + family.modelData + " 주소" }
							HudText { height: 26; verticalAlignment: Text.AlignVCenter; text: "/"; color: Theme.textMuted }
							HudInput { objectName: "networkPrefix" + family.modelData; width: 46; implicitHeight: 26; text: root.form[family.key + "Prefix"] || ""; onTextEdited: root.setField(family.key + "Prefix", text); Accessible.name: "IPv" + family.modelData + " 프리픽스" }
						}
						ErrorText { key: family.key + "Address" }
						ErrorText { key: family.key + "Prefix" }
						Row {
							visible: root.form[family.key + "Method"] === "manual"; spacing: 6
							FieldLabel { text: "게이트웨이" }
							HudInput { objectName: "networkGateway" + family.modelData; width: 252; implicitHeight: 26; text: root.form[family.key + "Gateway"] || ""; onTextEdited: root.setField(family.key + "Gateway", text); placeholderText: "비워 두면 기본 경로 없음"; Accessible.name: "IPv" + family.modelData + " 게이트웨이" }
						}
						ErrorText { key: family.key + "Gateway" }
						Row {
							visible: root.form[family.key + "Method"] !== "disabled" && root.form[family.key + "Method"] !== "ignore"; spacing: 6
							FieldLabel { text: "DNS" }
							HudToggle {
								objectName: "networkAutoDns" + family.modelData; anchors.verticalCenter: parent.verticalCenter; label: "자동 DNS"
								visible: root.form[family.key + "Method"] !== "manual"
								checked: root.form[family.key + "AutoDns"] !== false; onToggled: on => root.setField(family.key + "AutoDns", on)
							}
							HudText { visible: root.form[family.key + "Method"] !== "manual"; height: 26; verticalAlignment: Text.AlignVCenter; text: "자동"; font.pixelSize: 10; color: Theme.textSecondary }
							HudInput {
								objectName: "networkDns" + family.modelData; width: root.form[family.key + "Method"] === "manual" ? 252 : 178; implicitHeight: 26
								text: root.form[family.key + "Dns"] || ""; onTextEdited: root.setField(family.key + "Dns", text)
								placeholderText: root.form[family.key + "AutoDns"] !== false && root.form[family.key + "Method"] !== "manual" ? "추가 DNS (쉼표로 구분)" : "DNS 서버 (쉼표로 구분)"
								Accessible.name: "IPv" + family.modelData + " DNS 서버"
							}
						}
						ErrorText { key: family.key + "Dns" }
					}
				}
				HudSectionHeader { width: parent.width; height: 20; glyph: ""; title: "프록시" }
				Row {
					spacing: 6; FieldLabel { text: "방식" }
					Choice { field: "proxyMethod"; value: "none"; width: 74; text: "사용 안 함" }
					Choice { field: "proxyMethod"; value: "auto"; width: 74; text: "자동(PAC)" }
				}
				Row {
					visible: root.form.proxyMethod === "auto"; spacing: 6; FieldLabel { text: "PAC 주소" }
					HudInput { objectName: "networkPac"; width: 252; implicitHeight: 26; text: root.form.pacUrl || ""; onTextEdited: root.setField("pacUrl", text); placeholderText: "비워 두면 WPAD 자동 검색"; Accessible.name: "PAC 주소" }
				}
				ErrorText { key: "pacUrl" }
			}
		}
		HudText {
			x: 14; y: parent.height - 58; width: parent.width - 28; height: 24; wrapMode: Text.WordWrap; maximumLineCount: 2; font.pixelSize: 9; color: Theme.textMuted
			readonly property bool inUse: root.editing !== null && root.settings.devices.some(item => item.connection && item.connection.uuid === root.editing.uuid)
			text: inUse ? "사용 중인 연결입니다. 적용 후 30초 안에 유지를 선택하지 않으면 NetworkManager가 이전 설정으로 되돌립니다."
				+ (root.settings.needsAuthentication("checkpoint-rollback") ? " 관리자 인증 창이 뜰 수 있습니다." : "")
				: "지금 사용하지 않는 연결이라 저장만 하고, 다음 연결부터 적용됩니다."
		}
		Row {
			anchors.right: parent.right; anchors.rightMargin: 14; anchors.bottom: parent.bottom; anchors.bottomMargin: 8; spacing: Theme.spaceS
			HudButton { objectName: "networkEditorCancel"; width: 70; text: "취소"; onClicked: root.closeDialog() }
			HudButton { objectName: "networkEditorApply"; width: 70; text: "적용"; active: true; enabled: !root.settings.busy; onClicked: root.applyEditor() }
		}
	}

	// Delete a saved profile: the target is named, and the question says what goes with it.
	FocusScope {
		objectName: "networkDeleteDialog"; visible: root.dialog === "delete" && !root.settings.waiting
		anchors.centerIn: parent; width: 340; height: 124
		onVisibleChanged: if (visible) deleteCancel.forceActiveFocus()
		Keys.onEscapePressed: root.closeDialog()
		HudFrame { anchors.fill: parent; level: "panel"; glow: true; fillColor: Theme.floatingSurface; gradientColor: Theme.background; strokeColor: Theme.danger }
		HudText { x: 14; y: 10; width: parent.width - 28; text: "«" + (root.editing ? root.editing.name : "") + "» 연결을 삭제할까요?"; font.pixelSize: 13; font.bold: true; color: Theme.textPrimary; elide: Text.ElideRight }
		HudText {
			x: 14; y: 34; width: parent.width - 28; wrapMode: Text.WordWrap; font.pixelSize: 10; color: Theme.textSecondary
			text: "저장된 비밀번호와 IP·DNS 설정이 함께 지워집니다." + (root.editing && root.settings.devices.some(item => item.connection && item.connection.uuid === root.editing.uuid) ? " 지금 이 연결을 사용 중이라 연결이 끊어집니다." : "")
		}
		Row {
			anchors.right: parent.right; anchors.rightMargin: 14; anchors.bottom: parent.bottom; anchors.bottomMargin: 10; spacing: Theme.spaceS
			HudButton { id: deleteCancel; width: 70; text: "취소"; onClicked: root.closeDialog() }
			HudButton { objectName: "networkDeleteConfirm"; width: 70; text: "삭제"; onClicked: { root.settings.remove(root.editing.uuid); root.closeDialog() } }
		}
	}

	NetworkConfirmCard {
		objectName: "networkConfirmInPage"; visible: root.settings.waiting
		anchors.centerIn: parent; settings: root.settings
		onVisibleChanged: if (visible) Qt.callLater(focusDefault)
	}
}
