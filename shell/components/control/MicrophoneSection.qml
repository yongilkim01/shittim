import QtQuick
import QtQuick.Layouts
import "../../ui"

// Input level, mute and device choice. Depends only on the microphone service contract.
ColumnLayout {
	id: root
	property var microphone: null
	readonly property bool ready: microphone !== null
	spacing: Theme.spaceS
	HudText { text: "입력 장치 (마이크)"; textStyle: "section"; color: Theme.accent }
	LevelControl {
		objectName: "microphoneLevel"
		Layout.fillWidth: true; title: "마이크"; glyph: root.ready && root.microphone.muted ? "󰍭" : "󰍬"
		detail: !root.ready ? "" : root.microphone.muted ? root.microphone.deviceName + " · 음소거" : root.microphone.deviceName
		available: root.ready && root.microphone.validVolume
		value: root.ready && root.microphone.available ? root.microphone.source.audio.volume : 0
		muted: root.ready && root.microphone.muted; muteButton: true
		onChanged: fraction => root.microphone.setVolume(fraction); onMuteRequested: root.microphone.toggleMute()
	}
	HudText {
		visible: root.ready && root.microphone.inUse; Layout.fillWidth: true; wrapMode: Text.WordWrap; maximumLineCount: 2
		text: root.ready ? "사용 중: " + root.microphone.applications.join(", ") : ""
		color: root.ready && root.microphone.muted ? Theme.danger : Theme.warning
	}
	Repeater {
		model: root.ready ? root.microphone.inputs : []
		HudButton {
			required property var modelData
			Layout.fillWidth: true; Layout.minimumWidth: 0
			text: modelData.description || modelData.nickname || modelData.name
			active: root.microphone.source === modelData
			onClicked: root.microphone.selectInput(modelData)
		}
	}
	HudText {
		visible: root.ready && root.microphone.inputs.length === 0; Layout.fillWidth: true; wrapMode: Text.WordWrap; maximumLineCount: 2
		text: "마이크 장치가 없습니다. USB·Bluetooth 마이크를 연결하면 자동으로 표시됩니다."; color: Theme.textMuted
	}
}
