import QtQuick
import "../ui"

// Bar indicator for capture that the system can observe. Hidden when nothing is capturing,
// so the idle bar layout is unchanged. Each icon has its own card (`hoveredItem`/`card`) for BarTooltip.
Item {
	id: root
	property var microphone: null
	property var camera: null
	property var screenShare: null
	// Optional app name -> icon URL; the bar passes a desktop-entry lookup.
	property var iconFor: null
	readonly property bool micActive: microphone !== null && microphone.inUse
	readonly property bool cameraActive: camera !== null && camera.inUse
	readonly property bool shareActive: screenShare !== null && screenShare.active
	readonly property string hoveredKind: micMouse.containsMouse ? "microphone" : cameraMouse.containsMouse ? "camera" : shareMouse.containsMouse ? "share" : ""
	readonly property Item hoveredItem: hoveredKind === "microphone" ? micIcon : hoveredKind === "camera" ? cameraIcon : hoveredKind === "share" ? shareIcon : null
	readonly property var card: cardFor(hoveredKind)
	readonly property string summary: ["microphone", "camera", "share"].map(kind => cardFor(kind)).filter(entry => entry !== null)
		.map(entry => entry.title + (entry.rows.length && entry.rows[0].text ? " · " + entry.rows.map(row => row.text).join(", ") : "")).join("\n")
	signal detailsRequested()

	function appRows(names) {
		return names.map(name => ({text: name, glyph: "󰖯", image: typeof iconFor === "function" ? iconFor(name) || "" : ""}))
	}
	function cardFor(kind) {
		if (kind === "microphone" && micActive)
			return {glyph: microphone.muted ? "󰍭" : "󰍬", title: microphone.muted ? "마이크 사용 중 (음소거)" : "마이크 사용 중", rows: appRows(microphone.applications)}
		if (kind === "camera" && cameraActive)
			return {glyph: "󰕧", title: "카메라 사용 중", rows: appRows(camera.applications)}
		if (kind === "share" && shareActive)
			return {glyph: "󰍹", title: "화면 공유 중", rows: [{glyph: "󰋽", text: "중지는 회의 앱의 «공유 중지»"}]}
		return null
	}

	visible: micActive || cameraActive || shareActive
	implicitWidth: visible ? icons.implicitWidth : 0
	implicitHeight: Theme.barIconSize
	Row {
		id: icons; anchors.verticalCenter: parent.verticalCenter; spacing: Theme.spaceM
		HudIcon {
			id: micIcon; objectName: "activityMicrophone"; visible: root.micActive
			text: root.micActive && root.microphone.muted ? "󰍭" : "󰍬"; font.pixelSize: Theme.barIconSize; width: Theme.barIconSize
			color: root.micActive && root.microphone.muted ? Theme.danger : micMouse.containsMouse ? Theme.accentBright : Theme.accent
			MouseArea { id: micMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.detailsRequested() }
		}
		HudIcon {
			id: cameraIcon; objectName: "activityCamera"; visible: root.cameraActive; text: "󰕧"
			font.pixelSize: Theme.barIconSize; width: Theme.barIconSize; color: cameraMouse.containsMouse ? Theme.accentBright : Theme.accent
			MouseArea { id: cameraMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.detailsRequested() }
		}
		HudIcon {
			id: shareIcon; objectName: "activityShare"; visible: root.shareActive; text: "󰍹"
			font.pixelSize: Theme.barIconSize; width: Theme.barIconSize; color: shareMouse.containsMouse ? Theme.accentBright : Theme.accent
			MouseArea { id: shareMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.detailsRequested() }
		}
	}
	Accessible.role: Accessible.Button
	Accessible.name: summary
}
