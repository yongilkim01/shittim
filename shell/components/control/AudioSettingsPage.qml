import QtQuick
import QtQuick.Controls.Basic as Controls
import "../../ui"
import "../../core/AudioData.js" as Audio

// Dashboard "오디오" page: output, input and per-application volume. Reads and changes only the AudioState and
// MicrophoneState contracts (or test fixtures with the same members); it never runs a command itself.
FocusScope {
	id: root
	required property var audio
	required property var microphone
	// Icon name -> image URL; the dashboard passes Quickshell.iconPath. Empty means the fallback glyph.
	property var iconSource: name => ""
	property bool levelOn: false
	readonly property bool watching: levelOn && visible && microphone !== null
	readonly property int levelBars: 24
	readonly property string message: audio.error || (microphone ? microphone.error : "")
	property var chooser: null
	implicitWidth: 589; implicitHeight: 272

	// The input level stream exists only while the user asked for it and the page is on screen.
	onWatchingChanged: watching ? microphone.watchLevel(root) : microphone.unwatchLevel(root)
	Component.onDestruction: if (microphone) microphone.unwatchLevel(root)

	function deviceOptions(nodes, current, input) {
		return nodes.map(node => ({label: Audio.label(node), glyph: Audio.kind(node, input).glyph, detail: Audio.kind(node, input).label,
			selected: node === current, node: node}))
	}
	function openOutputs(field) {
		chooser = option => root.audio.selectOutput(option.node)
		options.open(field, deviceOptions(audio.outputs, audio.sink, false))
	}
	function openInputs(field) {
		chooser = option => root.microphone.selectInput(option.node)
		options.open(field, deviceOptions(microphone.inputs, microphone.source, true))
	}
	function openAppOutputs(field, app) {
		const choices = [{label: "기본 출력 따라가기", glyph: "󰑓", detail: Audio.label(audio.sink), selected: false, node: null}]
		chooser = option => root.audio.moveApplication(app, option.node)
		options.open(field, choices.concat(deviceOptions(audio.outputs, app.target, false)))
	}

	component SettingLabel: HudText { width: 92; font.pixelSize: 11; color: Theme.textSecondary }
	component LevelRow: Row {
		id: level
		property real value: 0
		property bool available: true
		property bool muted: false
		property string label: ""
		signal changed(real fraction)
		signal muteRequested()
		spacing: Theme.spaceS
		HudButton {
			width: 30; enabled: level.available; active: level.muted
			text: level.muted ? "󰝟" : "󰕾"; onClicked: level.muteRequested()
		}
		HudSlider {
			id: slider; objectName: "audioSlider-" + level.label
			width: level.width - 30 - 44 - Theme.spaceS * 2; height: Theme.controlHeight; padding: 0; trackHeight: 4
			enabled: level.available
			Binding { target: slider; property: "value"; value: Math.max(0, Math.min(1, level.value)); when: !slider.pressed; restoreMode: Binding.RestoreNone }
			onMoved: level.changed(value)
			Accessible.name: level.label
		}
		HudText {
			width: 44; height: Theme.controlHeight; horizontalAlignment: Text.AlignRight; font.pixelSize: 11
			text: !level.available ? "N/A" : level.muted ? "음소거" : Math.round(slider.value * 100) + "%"
			color: !level.available ? Theme.textMuted : level.muted ? Theme.danger : Theme.accentBright
		}
	}

	HudText { x: 0; y: 0; height: 24; text: "오디오"; font.pixelSize: 18; font.bold: true; color: Theme.textPrimary }
	Rectangle { x: 0; y: 29; width: 384; height: 1; color: Theme.border }
	Rectangle { x: 0; y: 28; width: 64; height: 2; color: Theme.accent }

	Flickable {
		id: viewport; objectName: "audioViewport"
		x: 0; y: 36; width: parent.width; height: root.message ? 210 : 236
		contentWidth: width; contentHeight: content.height; clip: true; boundsBehavior: Flickable.StopAtBounds
		interactive: !options.opened
		Controls.ScrollBar.vertical: Controls.ScrollBar { policy: Controls.ScrollBar.AsNeeded; width: 3; contentItem: Rectangle { implicitWidth: 3; color: Theme.accentDim } background: Item {} }
		Column {
			id: content
			width: viewport.width - 8; spacing: Theme.spaceS

			// Output: device, level, balance.
			HudFrame {
				objectName: "audioOutput"; width: parent.width; height: 132; level: "panel"
				HudSectionHeader { x: 14; y: 6; width: parent.width - 28; height: 20; glyph: "󰓃"; title: "출력"; detail: root.audio.available ? Audio.kind(root.audio.sink, false).label : "" }
				Column {
					x: 14; y: 32; width: parent.width - 28; spacing: 4
					Row {
						spacing: Theme.spaceS
						SettingLabel { text: "장치"; height: Theme.controlHeight; verticalAlignment: Text.AlignVCenter }
						HudSelect {
							id: outputSelect; objectName: "audioOutputDevice"
							width: parent.parent.width - 92 - Theme.spaceS
							enabled: root.audio.outputs.length > 0
							glyph: root.audio.available ? Audio.kind(root.audio.sink, false).glyph : "󰓄"
							text: root.audio.outputs.length === 0 ? "연결된 출력 장치가 없습니다" : root.audio.deviceName
							detail: root.audio.available ? "기본 출력" : ""
							open: options.field === outputSelect
							onActivated: root.openOutputs(outputSelect)
						}
					}
					Row {
						spacing: Theme.spaceS
						SettingLabel { text: "볼륨"; height: Theme.controlHeight; verticalAlignment: Text.AlignVCenter }
						LevelRow {
							objectName: "audioOutputLevel"; label: "출력 볼륨"; width: parent.parent.width - 92 - Theme.spaceS
							available: root.audio.validVolume; muted: root.audio.muted
							value: root.audio.available ? root.audio.sink.audio.volume : 0
							onChanged: fraction => root.audio.setVolume(fraction); onMuteRequested: root.audio.toggleMute()
						}
					}
					Row {
						spacing: Theme.spaceS
						SettingLabel { text: "좌우 밸런스"; height: Theme.controlHeight; verticalAlignment: Text.AlignVCenter }
						HudText { width: 30; height: Theme.controlHeight; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; text: "L"; font.pixelSize: 11; color: Theme.textMuted }
						Item {
							width: parent.parent.width - 92 - 30 - 30 - 64 - Theme.spaceS * 4; height: Theme.controlHeight
							Rectangle { x: parent.width / 2; y: 4; width: 1; height: parent.height - 8; color: Theme.border }
							HudSlider {
								id: balance; objectName: "audioBalance"; anchors.fill: parent; padding: 0; trackHeight: 3
								from: -1; to: 1; stepSize: 0.05; enabled: root.audio.balance !== null
								Binding { target: balance; property: "value"; value: root.audio.balance === null ? 0 : root.audio.balance; when: !balance.pressed; restoreMode: Binding.RestoreNone }
								onMoved: root.audio.setBalance(value)
								Accessible.name: "좌우 밸런스"
							}
						}
						HudText { width: 30; height: Theme.controlHeight; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; text: "R"; font.pixelSize: 11; color: Theme.textMuted }
						HudText {
							objectName: "audioBalanceValue"; width: 64; height: Theme.controlHeight; horizontalAlignment: Text.AlignRight; verticalAlignment: Text.AlignVCenter; font.pixelSize: 10
							text: Audio.balanceLabel(root.audio.balance === null ? null : balance.value); color: root.audio.balance === null ? Theme.textMuted : Theme.textSecondary
						}
					}
				}
			}

			// Input: device, level, measured input meter.
			HudFrame {
				objectName: "audioInput"; width: parent.width; height: 158; level: "panel"
				HudSectionHeader {
					x: 14; y: 6; width: parent.width - 28; height: 20; glyph: "󰍬"; title: "입력"
					// Whether an application records right now is separate from the device's own mute.
					detail: !root.microphone.inUse ? "사용하는 앱 없음" : "사용 중: " + root.microphone.applications.join(", ")
				}
				Column {
					x: 14; y: 32; width: parent.width - 28; spacing: 4
					Row {
						spacing: Theme.spaceS
						SettingLabel { text: "장치"; height: Theme.controlHeight; verticalAlignment: Text.AlignVCenter }
						HudSelect {
							id: inputSelect; objectName: "audioInputDevice"
							width: parent.parent.width - 92 - Theme.spaceS
							enabled: root.microphone.inputs.length > 0
							glyph: root.microphone.available ? Audio.kind(root.microphone.source, true).glyph : "󰍭"
							text: root.microphone.inputs.length === 0 ? "마이크가 없습니다. 연결하면 자동으로 표시됩니다" : root.microphone.deviceName
							detail: root.microphone.available ? "기본 입력" : ""
							open: options.field === inputSelect
							onActivated: root.openInputs(inputSelect)
						}
					}
					Row {
						spacing: Theme.spaceS
						SettingLabel { text: "입력 볼륨"; height: Theme.controlHeight; verticalAlignment: Text.AlignVCenter }
						LevelRow {
							objectName: "audioInputLevel"; label: "입력 볼륨"; width: parent.parent.width - 92 - Theme.spaceS
							available: root.microphone.validVolume; muted: root.microphone.muted
							value: root.microphone.available ? root.microphone.source.audio.volume : 0
							onChanged: fraction => root.microphone.setVolume(fraction); onMuteRequested: root.microphone.toggleMute()
						}
					}
					Row {
						spacing: Theme.spaceS
						SettingLabel { text: "입력 레벨"; height: Theme.controlHeight; verticalAlignment: Text.AlignVCenter }
						HudLevelMeter {
							objectName: "audioInputMeter"; anchors.verticalCenter: parent.verticalCenter
							bars: root.levelBars; active: root.microphone.levelActive
							lit: Audio.meter(root.microphone.level, root.levelBars)
						}
						Item { width: Theme.spaceS; height: 1 }
						HudToggle {
							objectName: "audioLevelToggle"; anchors.verticalCenter: parent.verticalCenter
							label: "입력 확인"; checked: root.levelOn; enabled: root.microphone.source !== null
							onToggled: on => root.levelOn = on
						}
						HudText { anchors.verticalCenter: parent.verticalCenter; text: "입력 확인"; font.pixelSize: 10; color: Theme.textSecondary }
					}
					HudText {
						x: 92 + Theme.spaceS; width: parent.width - x; font.pixelSize: 9; color: Theme.textMuted; elide: Text.ElideRight
						text: root.microphone.levelActive ? "마이크 신호의 크기만 읽습니다. 녹음하거나 저장하지 않습니다."
							: "켜면 이 화면이 열려 있는 동안만 마이크 크기를 측정합니다."
					}
				}
			}

			// Applications: one row per program, however many streams it has.
			HudFrame {
				objectName: "audioApplications"; width: parent.width; height: 34 + Math.max(1, root.audio.applications.length) * 40 + 6; level: "card"
				HudSectionHeader { x: 14; y: 6; width: parent.width - 28; height: 20; glyph: "󰕾"; title: "앱별 볼륨"; detail: "전체 볼륨과 별도로 적용" }
				HudText {
					visible: root.audio.applications.length === 0; x: 14; y: 38; width: parent.width - 28
					text: "지금 소리를 내는 앱이 없습니다."; font.pixelSize: 11; color: Theme.textMuted
				}
				Column {
					x: 14; y: 32; width: parent.width - 28
					Repeater {
						model: root.audio.applications
						Item {
							id: app
							required property var modelData
							required property int index
							objectName: "audioApp-" + index
							width: parent.width; height: 40
							Rectangle { visible: app.index > 0; width: parent.width; height: 1; color: Theme.frameLine }
							Item {
								x: 0; y: 8; width: 24; height: 24
								Image {
									id: appIcon; anchors.fill: parent; sourceSize.width: 48; sourceSize.height: 48
									source: app.modelData.icon ? root.iconSource(app.modelData.icon) : ""; asynchronous: true
								}
								HudIcon { anchors.centerIn: parent; visible: appIcon.status !== Image.Ready; text: "󰎆"; font.pixelSize: 16; color: Theme.textSecondary }
							}
							Column {
								x: 32; y: 6; width: 110
								HudText { width: parent.width; text: app.modelData.name; font.pixelSize: 11; color: Theme.textPrimary; elide: Text.ElideRight }
								HudText { width: parent.width; text: app.modelData.detail; font.pixelSize: 9; color: Theme.textMuted; elide: Text.ElideRight }
							}
							LevelRow {
								x: 148; y: 6; width: parent.width - 148 - 150 - Theme.spaceS; label: app.modelData.name + " 볼륨"
								available: app.modelData.available; muted: app.modelData.muted; value: app.modelData.volume
								onChanged: fraction => root.audio.setApplicationVolume(app.modelData, fraction)
								onMuteRequested: root.audio.toggleApplicationMute(app.modelData)
							}
							HudSelect {
								id: appOutput; objectName: "audioAppOutput-" + app.index
								x: parent.width - 150; y: 6; width: 150
								enabled: root.audio.outputs.length > 1 && !root.audio.routing
								glyph: app.modelData.target ? Audio.kind(app.modelData.target, false).glyph : "󰓃"
								text: app.modelData.target ? Audio.label(app.modelData.target) : app.modelData.mixed ? "여러 장치" : "연결 중"
								open: options.field === appOutput
								onActivated: root.openAppOutputs(appOutput, app.modelData)
								HudToolTip { visible: appOutput.hovered && !appOutput.enabled; text: root.audio.outputs.length <= 1 ? "다른 출력 장치가 없습니다." : "출력 장치를 바꾸는 중입니다." }
							}
						}
					}
				}
			}
		}
	}
	HudText {
		objectName: "audioMessage"; visible: root.message.length > 0
		x: 0; y: 250; width: parent.width; height: 20; elide: Text.ElideRight
		text: "󰀦  " + root.message; font.pixelSize: 11; color: Theme.warning
	}
	HudOptionList {
		id: options; anchors.fill: parent
		onChosen: index => { if (root.chooser) root.chooser(options.options[index]) }
	}
}
