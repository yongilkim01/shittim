import QtQuick
import QtQuick.Controls.Basic as Controls
import "../ui"

// Bar indicator for capture that the system can observe. Hidden when nothing is capturing,
// so the idle bar layout is unchanged.
Item {
	id: root
	property var microphone: null
	property var camera: null
	property var screenShare: null
	readonly property bool micActive: microphone !== null && microphone.inUse
	readonly property bool cameraActive: camera !== null && camera.inUse
	readonly property bool shareActive: screenShare !== null && screenShare.active
	readonly property string summary: [
		micActive ? (microphone.muted ? "마이크 사용 중(음소거): " : "마이크 사용 중: ") + microphone.applications.join(", ") : "",
		cameraActive ? "카메라 사용 중: " + camera.applications.join(", ") : "",
		shareActive ? "화면 공유 중" : ""].filter(text => text.length > 0).join("\n")
	signal detailsRequested()
	visible: micActive || cameraActive || shareActive
	implicitWidth: visible ? icons.implicitWidth : 0
	implicitHeight: Theme.barIconSize
	Row {
		id: icons; anchors.verticalCenter: parent.verticalCenter; spacing: Theme.spaceXS
		HudIcon {
			objectName: "activityMicrophone"; visible: root.micActive
			text: root.micActive && root.microphone.muted ? "󰍭" : "󰍬"; font.pixelSize: Theme.barIconSize; width: Theme.barIconSize
			color: root.micActive && root.microphone.muted ? Theme.danger : Theme.warning
		}
		HudIcon { objectName: "activityCamera"; visible: root.cameraActive; text: "󰄀"; font.pixelSize: Theme.barIconSize; width: Theme.barIconSize; color: Theme.warning }
		HudIcon { objectName: "activityShare"; visible: root.shareActive; text: "󰍹"; font.pixelSize: Theme.barIconSize; width: Theme.barIconSize; color: Theme.warning }
	}
	MouseArea {
		id: mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
		onClicked: root.detailsRequested()
	}
	Accessible.role: Accessible.Button
	Accessible.name: summary
	Controls.ToolTip.visible: mouse.containsMouse
	Controls.ToolTip.text: summary + "\n클릭: 회의 장치"
	Controls.ToolTip.delay: 300
}
