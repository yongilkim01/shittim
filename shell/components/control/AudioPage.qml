import QtQuick
import QtQuick.Layouts
import "../../ui"

ColumnLayout {
	id: root
	required property var audio
	property var microphone: null
	spacing: Theme.spaceS
	LevelControl {
		Layout.fillWidth: true; title: "볼륨"; glyph: "\uf028"; detail: root.audio.deviceName
		available: root.audio.validVolume; value: root.audio.available ? root.audio.sink.audio.volume : 0
		muted: root.audio.muted; muteButton: true
		onChanged: fraction => root.audio.setVolume(fraction); onMuteRequested: root.audio.toggleMute()
	}
	HudText { text: "출력 장치"; textStyle: "section"; color: Theme.accent }
	Repeater {
		model: root.audio.outputs
		HudButton {
			required property var modelData
			Layout.fillWidth: true; Layout.minimumWidth: 0
			text: modelData.description || modelData.nickname || modelData.name
			active: root.audio.sink === modelData
			onClicked: root.audio.selectOutput(modelData)
		}
	}
	HudText { visible: root.audio.outputs.length === 0; text: "사용 가능한 출력 장치가 없습니다."; color: Theme.textMuted }
	MicrophoneSection { microphone: root.microphone; visible: root.microphone !== null; Layout.fillWidth: true; Layout.topMargin: Theme.spaceM }
	HudText { text: "애플리케이션"; textStyle: "section"; color: Theme.accent; Layout.topMargin: Theme.spaceM }
	Repeater {
		model: root.audio.streams
		LevelControl {
			required property var modelData
			Layout.fillWidth: true
			title: modelData.description || modelData.name
			available: modelData.ready && modelData.audio !== null
			value: available ? modelData.audio.volume : 0
			muted: available && modelData.audio.muted; muteButton: true
			onChanged: fraction => { if (available) modelData.audio.volume = Math.max(0, Math.min(1, fraction)) }
			onMuteRequested: { if (available) modelData.audio.muted = !modelData.audio.muted }
		}
	}
	HudText { visible: root.audio.streams.length === 0; text: "현재 재생 중인 애플리케이션이 없습니다."; Layout.fillWidth: true; wrapMode: Text.WordWrap; maximumLineCount: 2; color: Theme.textMuted }
}
